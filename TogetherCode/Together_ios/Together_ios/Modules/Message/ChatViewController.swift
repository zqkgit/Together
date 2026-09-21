import UIKit
import SnapKit
import Kingfisher
import MBProgressHUD
import HXPhotoPicker
import SwiftyJSON

/// 聊天展示项：时间行 / 消息行
enum ChatDisplayItem {
    case time(String)
    case message(ChatMessage)
}

/// 会话详情（聊天页）
/// 对齐 PR 设计图：自己=右侧品牌绿渐变气泡（右下小圆角），对方=左侧头像+白气泡（左下小圆角）
/// 复用：BaseViewController 沉浸式导航 / MessageService / MessageSocketService / ImagePreviewViewController
final class ChatViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {

    // MARK: - 数据

    private let conversation: ConversationItem
    private var serverMessages: [ChatMessage] = []   // 服务端顺序（index 0 最新）
    private var displayItems: [ChatDisplayItem] = []
    private var page = 1
    private var hasMore = true
    private var isLoading = false
    private var isSending = false
    private var shouldScrollToBottom = true

    private var keyboardHeight: CGFloat = 0
    private var didInitialLoad = false
    private var isUploading = false

    // MARK: - UI

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let inputBar = UIView()
    /// 底部安全区（home indicator 区域）填充，颜色与输入栏一致
    private let bottomSafeFill = UIView()
    private let photoButton = UIButton(type: .system)
    private let inputField = UITextField()
    private let sendButton = UIButton(type: .system)
    private let emptyView = EmptyStateView()
    private var inputBarBottomConstraint: Constraint?

    /// 会话对方
    private var peer: ConversationPeer? { conversation.peer }

    // MARK: - Init

    init(conversation: ConversationItem) {
        self.conversation = conversation
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @MainActor
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        setupNav()
        // 先构建输入栏（tableView 的 bottom 约束引用它）
        setupInputBar()
        setupTableView()
        setupEmptyView()
        registerNotifications()
        loadMessages(reset: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: peer?.nickname ?? "聊天")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
        restoreSystemNav()
    }

    /// 沉浸式透明导航：tableView 区域本身从导航下方开始（见 setupTableView），无需内容边距避让

    // MARK: - UI 构建

    private func setupNav() {
        // 沉浸式导航（返回按钮统一帖子详情样式，标题=对方昵称）
        configureImmersiveNav(title: peer?.nickname ?? "聊天")
    }

    private func setupTableView() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.keyboardDismissMode = .interactive
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        tableView.register(ChatTextCell.self, forCellReuseIdentifier: ChatTextCell.reuseId)
        tableView.register(ChatImageCell.self, forCellReuseIdentifier: ChatImageCell.reuseId)
        tableView.register(ChatTimeCell.self, forCellReuseIdentifier: ChatTimeCell.reuseId)
        tableView.dataSource = self
        tableView.delegate = self
        // 透明沉浸式导航栏下，safeArea.top 已为导航栏底边；tableView 从导航栏正下方开始（紧贴，不额外留白）
        // 底部留输入栏上方间隔
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: Theme.Spacing.m, right: 0)

        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(inputBar.snp.top)
        }
    }

    private func setupInputBar() {
        inputBar.backgroundColor = Theme.Color.surface
        view.addSubview(inputBar)
        // 底部安全区（home indicator 区域）填充为输入栏同色，避免露出背景底色
        bottomSafeFill.backgroundColor = Theme.Color.surface
        view.insertSubview(bottomSafeFill, belowSubview: inputBar)
        bottomSafeFill.snp.makeConstraints {
            $0.top.equalTo(inputBar.snp.bottom)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalToSuperview()
        }
        inputBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            // 底部对齐安全区域底边：留出 home indicator 等底部安全区，不被遮挡
            inputBarBottomConstraint = make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).constraint
        }

        // 顶部分隔线
        let divider = UIView()
        divider.backgroundColor = Theme.Color.line
        inputBar.addSubview(divider)
        divider.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(0.5)
        }

        // 三个控件先全部加入 inputBar（交叉约束需要共同祖先，否则 anchor 激活崩溃）
        photoButton.setImage(UIImage(systemName: "photo"), for: .normal)
        photoButton.tintColor = Theme.Color.brand
        photoButton.addTarget(self, action: #selector(didTapPhoto), for: .touchUpInside)
        inputBar.addSubview(photoButton)

        // 输入框（圆角胶囊）
        inputField.placeholder = "发消息…"
        inputField.font = .appBody(14)
        inputField.textColor = Theme.Color.ink
        inputField.backgroundColor = Theme.Color.bg
        inputField.layer.cornerRadius = 20
        inputField.clipsToBounds = true
        inputField.returnKeyType = .send
        inputField.delegate = self
        let padding = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        inputField.leftView = padding
        inputField.leftViewMode = .always
        inputBar.addSubview(inputField)

        // 发送按钮（品牌绿、圆角=高度一半）
        sendButton.setTitle("发送", for: .normal)
        sendButton.titleLabel?.font = .appBody(15)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.backgroundColor = Theme.Color.brand
        sendButton.layer.cornerRadius = 20
        sendButton.clipsToBounds = true
        sendButton.addTarget(self, action: #selector(didTapSend), for: .touchUpInside)
        inputBar.addSubview(sendButton)

        // 统一约束（三个控件已在同一层级）
        photoButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.m)
            $0.centerY.equalTo(inputField)
            $0.width.height.equalTo(40)
        }
        inputField.snp.makeConstraints {
            $0.top.equalToSuperview().offset(10)
            $0.leading.equalTo(photoButton.snp.trailing).offset(8)
            $0.height.equalTo(40)
            $0.bottom.equalToSuperview().offset(-10).priority(.high)
        }
        sendButton.snp.makeConstraints {
            $0.leading.equalTo(inputField.snp.trailing).offset(Theme.Spacing.m)
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.m)
            $0.centerY.equalTo(inputField)
            $0.width.equalTo(64)
            $0.height.equalTo(40)
        }
    }

    private func setupEmptyView() {
        emptyView.show(style: .empty("打个招呼，开始聊天吧"))
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints {
            $0.top.equalTo(tableView.snp.top)
            $0.leading.trailing.bottom.equalToSuperview()
        }
        emptyView.isHidden = true
    }

    private func registerNotifications() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(didReceiveChatMessage(_:)),
            name: .chatMessageReceived, object: nil
        )
    }

    // MARK: - 数据加载

    private func loadMessages(reset: Bool) {
        guard !isLoading else { return }
        if reset {
            page = 1
            hasMore = true
            shouldScrollToBottom = true
            serverMessages = []
            displayItems = []
            tableView.reloadData()
            emptyView.isHidden = false
        }
        guard hasMore else { return }
        isLoading = true
        MessageService.fetchMessages(conversationId: conversation.conversationId, page: page) { [weak self] list, total, error in
            guard let self else { return }
            self.isLoading = false
            if let error {
                self.showToast(error)
                return
            }
            let messages = list ?? []
            if messages.isEmpty {
                self.hasMore = false
            } else {
                // 服务端倒序（最新在前），追加到末尾
                self.serverMessages.append(contentsOf: messages)
                self.page += 1
                self.hasMore = self.serverMessages.count < total
            }
            self.rebuildDisplay(scrollToBottom: self.shouldScrollToBottom)
            self.emptyView.isHidden = !self.serverMessages.isEmpty
            self.shouldScrollToBottom = false
            self.didInitialLoad = true
        }
    }

    /// 由 serverMessages 构建展示数组（旧→新，相邻间隔>5min 或跨天插时间行）
    private func rebuildDisplay(scrollToBottom: Bool) {
        let messages = serverMessages.reversed()
        var items: [ChatDisplayItem] = []
        var lastDate: Date?
        for msg in messages {
            if let date = MessageTimeFormatter.date(from: msg.createdAt) {
                if let last = lastDate {
                    if date.timeIntervalSince(last) > 300 || !Calendar.current.isDate(date, inSameDayAs: last) {
                        items.append(.time(ChatTimeFormatter.display(msg.createdAt)))
                    }
                } else {
                    items.append(.time(ChatTimeFormatter.display(msg.createdAt)))
                }
                lastDate = date
            }
            items.append(.message(msg))
        }
        displayItems = items
        tableView.reloadData()
        if scrollToBottom, !displayItems.isEmpty {
            // tableView 区域已在导航下方，无顶部遮挡；内容超一屏时滚到底部（布局完成后取准确高度）
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let contentH = self.tableView.contentSize.height
                let frameH = self.tableView.bounds.height
                let maxOffset = max(0, contentH - frameH + self.tableView.contentInset.bottom)
                self.tableView.setContentOffset(CGPoint(x: 0, y: maxOffset), animated: false)
            }
        }
    }

    // MARK: - 发送

    @objc private func didTapSend() {
        send(content: inputField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        send(content: inputField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
        return true
    }

    private func send(content: String, type: Int = 1) {
        guard !isSending else { return }
        guard !content.isEmpty else {
            if type == 1 { showToast("请输入内容") }
            return
        }
        isSending = true

        // 乐观插入：先把消息显示出来（临时 id），收到服务端回包/WS 回包再对齐
        let tempId = "local-\(UUID().uuidString)"
        let optimistic = ChatMessage(
            messageId: tempId,
            conversationId: conversation.conversationId,
            senderId: TokenManager.shared.userId,
            type: type,
            content: content,
            readAt: nil,
            createdAt: Self.nowString(),
            sender: nil
        )
        serverMessages.insert(optimistic, at: 0)
        rebuildDisplay(scrollToBottom: true)
        emptyView.isHidden = true
        inputField.text = ""

        MessageService.sendMessage(conversationId: conversation.conversationId, content: content, type: type) { [weak self] message, error in
            guard let self else { return }
            self.isSending = false
            if let error {
                // 发送失败：移除临时消息、还原输入框内容
                self.serverMessages.removeAll { $0.messageId == tempId }
                self.rebuildDisplay(scrollToBottom: true)
                self.inputField.text = content
                self.showToast(error)
                return
            }
            // 服务端回包带回真实消息：用真实消息替换临时消息（去重，避免重复气泡）
            if let message {
                self.replaceTemp(tempId: tempId, with: message)
            }
            // 若后端未回传消息体（message 为 nil），保留临时消息，等待 WS 回包对齐
            // 发送成功同步会话列表未读角标
            NotificationCenter.default.post(name: .messageUnreadChanged, object: nil)
        }
    }

    /// 用服务端真实消息替换本地临时消息（避免重复气泡）
    private func replaceTemp(tempId: String, with message: ChatMessage) {
        serverMessages.removeAll { $0.messageId == tempId }
        if !serverMessages.contains(where: { $0.messageId == message.messageId }) {
            serverMessages.insert(message, at: 0)
        }
        rebuildDisplay(scrollToBottom: true)
        emptyView.isHidden = true
    }

    /// 当前时间字符串（MySQL 格式，对齐 MessageTimeFormatter 解析）
    private static func nowString() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: Date())
    }

    // MARK: - 图片消息

    @objc private func didTapPhoto() {
        view.endEditing(true)
        var config = PickerConfiguration()
        config.selectOptions = [.photo]
        config.maximumSelectedCount = 1
        let picker = PhotoPickerController(config: config)
        picker.finishHandler = { [weak self] result, _ in
            guard let self, let asset = result.photoAssets.first else { return }
            // 聊天图片压缩到长边 1080 内
            result.getImage(targetSize: CGSize(width: 1080, height: 1080)) { images in
                guard let image = images.first else { return }
                self.uploadAndSendImage(image)
            }
        }
        present(picker, animated: true)
    }

    private func uploadAndSendImage(_ image: UIImage) {
        guard !isUploading else { return }
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            showToast("图片处理失败")
            return
        }
        isUploading = true
        showLoading("发送中...")
        APIClient.shared.upload(files: [data], folder: "chat") { [weak self] result in
            guard let self else { return }
            self.isUploading = false
            self.hideLoading()
            switch result {
            case .success(let json):
                let url = self.extractUploadedURL(from: json)
                guard let url else {
                    self.showToast("图片上传失败")
                    return
                }
                self.send(content: url, type: 2)
            case .failure(let error):
                self.showToast(error.message)
            }
        }
    }

    /// 兼容上传接口两种返回：{"urls":["..."]} 或 [{"url":"..."}]
    private func extractUploadedURL(from json: JSON) -> String? {
        if let first = json["urls"].array?.first?.string { return first }
        if let first = json.array?.first?["url"].string { return first }
        return nil
    }

    // MARK: - WS 新消息

    @objc private func didReceiveChatMessage(_ notification: Notification) {
        guard let userInfo = notification.object as? [String: Any],
              let conversationId = userInfo["conversation_id"] as? String,
              conversationId == conversation.conversationId,
              let message = userInfo["message"] as? ChatMessage else { return }
        // 同 id 已存在则跳过（接口回包已插入）
        if serverMessages.contains(where: { $0.messageId == message.messageId }) { return }
        // 自己刚发的消息经 WS 回包（本地仍有临时消息）：直接替换临时消息，避免重复气泡
        if isMyMessage(message),
           let idx = serverMessages.firstIndex(where: { $0.messageId.hasPrefix("local-") }) {
            serverMessages[idx] = message
            rebuildDisplay(scrollToBottom: true)
            emptyView.isHidden = true
            return
        }
        serverMessages.insert(message, at: 0)
        rebuildDisplay(scrollToBottom: true)
        emptyView.isHidden = true
    }

    // MARK: - 键盘

    @objc private func keyboardWillChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let endFrame = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let duration = (info[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue else { return }
        let visibleHeight = view.window?.bounds.height ?? 0
        keyboardHeight = max(0, visibleHeight - endFrame.minY)
        // 键盘弹起时：把安全区底距（home indicator 区域）也减掉，输入栏紧贴键盘顶部不露空隙；
        // 键盘收起时：offset 归 0，输入栏停在安全区底边，正常避让 home indicator
        let safeBottom = view.safeAreaInsets.bottom
        let offset = keyboardHeight > 0 ? (safeBottom - keyboardHeight) : 0
        inputBarBottomConstraint?.update(offset: offset)
        UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseInOut]) {
            self.view.layoutIfNeeded()
        }
        // 键盘弹起时滚到底部
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, !self.displayItems.isEmpty else { return }
            let last = IndexPath(row: self.displayItems.count - 1, section: 0)
            self.tableView.scrollToRow(at: last, at: .bottom, animated: true)
        }
    }

    // MARK: - UITableViewDataSource

    /// 判断消息是否自己发送：优先 userId 精确匹配；旧登录态 userId 为空时按 1v1 会话 peer 反推
    private func isMyMessage(_ message: ChatMessage) -> Bool {
        if let uid = TokenManager.shared.userId, !uid.isEmpty {
            return message.senderUserId == uid
        }
        if let peerId = peer?.userId, !peerId.isEmpty {
            return message.senderUserId != peerId
        }
        return false
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        displayItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch displayItems[indexPath.row] {
        case .time(let text):
            let cell = tableView.dequeueReusableCell(withIdentifier: ChatTimeCell.reuseId, for: indexPath) as! ChatTimeCell
            cell.configure(text: text)
            return cell
        case .message(let message):
            let peerAvatar = isMyMessage(message) ? TokenManager.shared.avatar : peer?.avatar
            if message.isImage {
                let cell = tableView.dequeueReusableCell(withIdentifier: ChatImageCell.reuseId, for: indexPath) as! ChatImageCell
                cell.configure(message: message, isMine: isMyMessage(message), peerAvatar: peerAvatar)
                cell.onImageTap = { [weak self] url in
                    let vc = ImagePreviewViewController(images: [url], startIndex: 0)
                    self?.present(vc, animated: true)
                }
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: ChatTextCell.reuseId, for: indexPath) as! ChatTextCell
                cell.configure(message: message, isMine: isMyMessage(message), peerAvatar: peerAvatar)
                return cell
            }
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        view.endEditing(true)
    }

    // MARK: - 分页（加载更早）

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // 仅用户手势滚动到顶时加载更早消息（程序滚动/初始位置不触发）
        guard didInitialLoad, scrollView.isDragging || scrollView.isDecelerating else { return }
        let offsetY = scrollView.contentOffset.y
        if offsetY < 60, hasMore, !isLoading {
            loadMessages(reset: false)
        }
    }
}

// MARK: - 时间行

/// 聊天时间显示：今天 → "HH:mm"；昨天 → "昨天 HH:mm"；同年更早 → "MM-dd HH:mm"；跨年 → "yyyy-MM-dd HH:mm"
enum ChatTimeFormatter {
    static func display(_ dateString: String) -> String {
        guard let date = MessageTimeFormatter.date(from: dateString) else { return dateString }
        let calendar = Calendar.current
        let formatter = DateFormatter()
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'昨天' HH:mm"
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: Date()) {
            formatter.dateFormat = "MM-dd HH:mm"
        } else {
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
        }
        return formatter.string(from: date)
    }
}

final class ChatTimeCell: UITableViewCell {
    static let reuseId = "ChatTimeCell"
    private let timeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        timeLabel.font = .systemFont(ofSize: 11)
        timeLabel.textColor = Theme.Color.muted
        timeLabel.textAlignment = .center
        contentView.addSubview(timeLabel)
        timeLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(4)
            $0.bottom.equalToSuperview().offset(-4)
            $0.centerX.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(text: String) {
        timeLabel.text = text
    }
}

// MARK: - 文字消息 Cell

/// 文字聊天气泡（自己右侧绿渐变 / 对方左侧白底+头像），最大宽度 72%
final class ChatTextCell: UITableViewCell {
    static let reuseId = "ChatTextCell"

    private let avatarView = UIImageView()
    private let bubbleView = UIView()
    private let messageLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        // 头像 30pt 圆角
        avatarView.layer.cornerRadius = 15
        avatarView.clipsToBounds = true
        avatarView.contentMode = .scaleAspectFill
        contentView.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(4)
            $0.bottom.lessThanOrEqualToSuperview().offset(-4)
            $0.width.height.equalTo(30)
        }

        // 气泡
        bubbleView.layer.cornerRadius = 14
        bubbleView.clipsToBounds = true
        contentView.addSubview(bubbleView)
        bubbleView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(4)
            $0.bottom.lessThanOrEqualToSuperview().offset(-4)
            $0.width.lessThanOrEqualToSuperview().multipliedBy(0.72)
        }

        // 文本（左右 12 / 上下 5，紧凑贴近微信气泡比例）
        messageLabel.font = .appBody(14)
        messageLabel.textColor = Theme.Color.ink
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        bubbleView.addSubview(messageLabel)
        messageLabel.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(12)
            $0.top.bottom.equalToSuperview().inset(5)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(message: ChatMessage, isMine: Bool, peerAvatar: String?) {
        // 头像
        if let avatar = isMine ? TokenManager.shared.avatar : peerAvatar, let url = URL(string: avatar) {
            avatarView.kf.setImage(with: url, placeholder: UIImage(systemName: "person.crop.circle.fill"))
        } else {
            avatarView.image = UIImage(systemName: "person.crop.circle.fill")
            avatarView.tintColor = Theme.Color.line
        }

        // 气泡左右 + 头像位置
        avatarView.snp.remakeConstraints {
            $0.top.equalToSuperview().offset(4)
            $0.bottom.lessThanOrEqualToSuperview().offset(-4)
            $0.width.height.equalTo(30)
        }
        bubbleView.snp.remakeConstraints {
            $0.top.equalToSuperview().offset(4)
            $0.bottom.lessThanOrEqualToSuperview().offset(-4)
            $0.width.lessThanOrEqualToSuperview().multipliedBy(0.72)
        }
        if isMine {
            avatarView.snp.makeConstraints { $0.trailing.equalToSuperview().offset(-Theme.Spacing.m) }
            bubbleView.snp.makeConstraints { $0.trailing.equalTo(avatarView.snp.leading).offset(-8) }
            bubbleView.backgroundColor = Theme.Color.brand
            messageLabel.textColor = .white
        } else {
            avatarView.snp.makeConstraints { $0.leading.equalToSuperview().offset(Theme.Spacing.m) }
            bubbleView.snp.makeConstraints { $0.leading.equalTo(avatarView.snp.trailing).offset(8) }
            bubbleView.backgroundColor = Theme.Color.surface
            messageLabel.textColor = Theme.Color.ink
        }
        messageLabel.text = message.content
    }
}

// MARK: - 图片消息 Cell

/// 图片聊天气泡（180×180，点击预览）
final class ChatImageCell: UITableViewCell {
    static let reuseId = "ChatImageCell"

    var onImageTap: ((String) -> Void)?

    private let avatarView = UIImageView()
    private let bubbleView = UIView()
    private let imageContentView = UIImageView()
    private var imageURLString: String?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        // 头像 30pt 圆角
        avatarView.layer.cornerRadius = 15
        avatarView.clipsToBounds = true
        avatarView.contentMode = .scaleAspectFill
        contentView.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(4)
            $0.bottom.lessThanOrEqualToSuperview().offset(-4)
            $0.width.height.equalTo(30)
        }

        // 气泡（底色同文字气泡，图片内嵌 4pt 边）
        bubbleView.layer.cornerRadius = 14
        bubbleView.clipsToBounds = true
        contentView.addSubview(bubbleView)
        bubbleView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(4)
            $0.bottom.lessThanOrEqualToSuperview().offset(-4)
        }

        // 图片 180×180
        imageContentView.contentMode = .scaleAspectFill
        imageContentView.layer.cornerRadius = 10
        imageContentView.clipsToBounds = true
        imageContentView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapImage))
        imageContentView.addGestureRecognizer(tap)
        bubbleView.addSubview(imageContentView)
        imageContentView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(4)
            $0.width.equalTo(180)
            $0.height.equalTo(180)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(message: ChatMessage, isMine: Bool, peerAvatar: String?) {
        imageURLString = message.content

        if let avatar = isMine ? TokenManager.shared.avatar : peerAvatar, let url = URL(string: avatar) {
            avatarView.kf.setImage(with: url, placeholder: UIImage(systemName: "person.crop.circle.fill"))
        } else {
            avatarView.image = UIImage(systemName: "person.crop.circle.fill")
            avatarView.tintColor = Theme.Color.line
        }

        avatarView.snp.remakeConstraints {
            $0.top.equalToSuperview().offset(4)
            $0.bottom.lessThanOrEqualToSuperview().offset(-4)
            $0.width.height.equalTo(30)
        }
        bubbleView.snp.remakeConstraints {
            $0.top.equalToSuperview().offset(4)
            $0.bottom.lessThanOrEqualToSuperview().offset(-4)
        }
        if isMine {
            avatarView.snp.makeConstraints { $0.trailing.equalToSuperview().offset(-Theme.Spacing.m) }
            bubbleView.snp.makeConstraints { $0.trailing.equalTo(avatarView.snp.leading).offset(-8) }
            bubbleView.backgroundColor = Theme.Color.brand
        } else {
            avatarView.snp.makeConstraints { $0.leading.equalToSuperview().offset(Theme.Spacing.m) }
            bubbleView.snp.makeConstraints { $0.leading.equalTo(avatarView.snp.trailing).offset(8) }
            bubbleView.backgroundColor = Theme.Color.surface
        }

        if let url = URL(string: message.content) {
            imageContentView.kf.setImage(with: url, placeholder: UIImage(systemName: "photo"))
        }
    }

    @objc private func didTapImage() {
        if let url = imageURLString {
            onImageTap?(url)
        }
    }
}
