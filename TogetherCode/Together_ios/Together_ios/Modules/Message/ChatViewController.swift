import UIKit
import SnapKit
import Kingfisher
import MBProgressHUD

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

    // MARK: - UI

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let inputBar = UIView()
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
        tableView.register(ChatBubbleCell.self, forCellReuseIdentifier: ChatBubbleCell.reuseId)
        tableView.register(ChatTimeCell.self, forCellReuseIdentifier: ChatTimeCell.reuseId)
        tableView.dataSource = self
        tableView.delegate = self
        // tableView 区域从导航下方开始（safeArea=状态栏 + 导航栏 44），顶部无遮挡
        // 底部留输入栏上方间隔
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: Theme.Spacing.m, right: 0)

        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(44)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(inputBar.snp.top)
        }
    }

    private func setupInputBar() {
        inputBar.backgroundColor = Theme.Color.surface
        view.addSubview(inputBar)
        inputBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            inputBarBottomConstraint = make.bottom.equalToSuperview().constraint
        }

        // 顶部分隔线
        let divider = UIView()
        divider.backgroundColor = Theme.Color.line
        inputBar.addSubview(divider)
        divider.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(0.5)
        }

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
        inputField.snp.makeConstraints {
            $0.top.equalToSuperview().offset(10)
            $0.leading.equalToSuperview().offset(Theme.Spacing.m)
            $0.height.equalTo(40)
            $0.bottom.equalToSuperview().offset(-10).priority(.high)
        }

        // 发送按钮（品牌绿、圆角=高度一半）
        sendButton.setTitle("发送", for: .normal)
        sendButton.titleLabel?.font = .appBody(15)
        sendButton.setTitleColor(.white, for: .normal)
        sendButton.backgroundColor = Theme.Color.brand
        sendButton.layer.cornerRadius = 20
        sendButton.clipsToBounds = true
        sendButton.addTarget(self, action: #selector(didTapSend), for: .touchUpInside)
        inputBar.addSubview(sendButton)
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
        send()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        send()
        return true
    }

    private func send() {
        guard !isSending else { return }
        let content = inputField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !content.isEmpty else {
            showToast("请输入内容")
            return
        }
        isSending = true
        MessageService.sendMessage(conversationId: conversation.conversationId, content: content) { [weak self] message, error in
            guard let self else { return }
            self.isSending = false
            if let error {
                self.showToast(error)
                return
            }
            self.inputField.text = ""
            if let message, !self.serverMessages.contains(where: { $0.messageId == message.messageId }) {
                // 服务端顺序：最新插到头部
                self.serverMessages.insert(message, at: 0)
                self.rebuildDisplay(scrollToBottom: true)
                self.emptyView.isHidden = true
            }
            // 发送成功同步会话列表未读角标
            NotificationCenter.default.post(name: .messageUnreadChanged, object: nil)
        }
    }

    // MARK: - WS 新消息

    @objc private func didReceiveChatMessage(_ notification: Notification) {
        guard let userInfo = notification.object as? [String: Any],
              let conversationId = userInfo["conversation_id"] as? String,
              conversationId == conversation.conversationId,
              let message = userInfo["message"] as? ChatMessage,
              !serverMessages.contains(where: { $0.messageId == message.messageId }) else { return }
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
        inputBarBottomConstraint?.update(offset: -keyboardHeight)
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
            let cell = tableView.dequeueReusableCell(withIdentifier: ChatBubbleCell.reuseId, for: indexPath) as! ChatBubbleCell
            let peerAvatar = isMyMessage(message) ? TokenManager.shared.avatar : peer?.avatar
            cell.configure(message: message, isMine: isMyMessage(message), peerAvatar: peerAvatar)
            cell.onImageTap = { [weak self] url in
                let vc = ImagePreviewViewController(images: [url], startIndex: 0)
                self?.present(vc, animated: true)
            }
            return cell
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
            $0.top.equalToSuperview().offset(10)
            $0.bottom.equalToSuperview().offset(-6)
            $0.centerX.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(text: String) {
        timeLabel.text = text
    }
}

// MARK: - 气泡行

/// 聊天气泡 Cell（自己右侧绿渐变 / 对方左侧白底+头像），最大宽度 84%
final class ChatBubbleCell: UITableViewCell {
    static let reuseId = "ChatBubbleCell"

    var onImageTap: ((String) -> Void)?

    private let avatarView = UIImageView()
    private let bubbleView = UIView()
    private let messageLabel = UILabel()
    private let imageContentView = UIImageView()
    private var isMine = false
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
            $0.top.equalToSuperview().offset(6)
            $0.bottom.lessThanOrEqualToSuperview().offset(-6)
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

        // 文本（上下左右间距统一 12，与气泡边缘对称）
        messageLabel.font = .appBody(14)
        messageLabel.textColor = Theme.Color.ink
        messageLabel.numberOfLines = 0
        messageLabel.lineBreakMode = .byWordWrapping
        bubbleView.addSubview(messageLabel)
        messageLabel.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(12)
        }

        // 图片消息（覆盖在气泡上，默认隐藏）
        imageContentView.contentMode = .scaleAspectFill
        imageContentView.layer.cornerRadius = 12
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
        self.isMine = isMine
        // 头像
        if let avatar = isMine ? TokenManager.shared.avatar : peerAvatar, let url = URL(string: avatar) {
            avatarView.kf.setImage(with: url, placeholder: UIImage(systemName: "person.crop.circle.fill"))
        } else {
            avatarView.image = UIImage(systemName: "person.crop.circle.fill")
            avatarView.tintColor = Theme.Color.line
        }

        // 气泡左右 + 头像位置
        avatarView.snp.remakeConstraints {
            $0.top.equalToSuperview().offset(6)
            $0.bottom.lessThanOrEqualToSuperview().offset(-6)
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

        // 内容：文本 / 图片
        if message.isImage {
            imageURLString = message.content
            messageLabel.isHidden = true
            imageContentView.isHidden = false
            if let url = URL(string: message.content) {
                imageContentView.kf.setImage(with: url, placeholder: UIImage(systemName: "photo"))
            }
        } else {
            imageURLString = nil
            messageLabel.isHidden = false
            imageContentView.isHidden = true
            messageLabel.text = message.content
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 圆角由 bubbleView.cornerRadius + clipsToBounds 处理（不再使用 mask，避免复用 cell bounds=0 时圆角失效）
    }

    @objc private func didTapImage() {
        if !imageContentView.isHidden, let url = imageURLString {
            onImageTap?(url)
        }
    }
}
