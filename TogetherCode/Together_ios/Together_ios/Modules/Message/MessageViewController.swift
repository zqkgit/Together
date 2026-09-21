import UIKit
import SnapKit
import ESPullToRefresh
import Kingfisher

/// 消息中心（对齐 PR 设计图）：「对话 / 通知」双 Tab + 会话卡片列表
/// 复用：BaseViewController / EmptyStateView / BrandRefreshHeader / MessageService
final class MessageViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {

    // MARK: - 数据

    private var conversations: [ConversationItem] = []
    private var notifications: [NotificationItem] = []

    private var convPage = 1
    private var convHasMore = true
    private var notifPage = 1
    private var notifHasMore = true
    private var isLoading = false

    /// 0=对话 1=通知
    private var currentTab = 0

    private var footerSpinner: UIActivityIndicatorView?

    // MARK: - UI

    private let segmentView = UIView()
    private let chatButton = UIButton(type: .system)
    private let noticeButton = UIButton(type: .system)
    private let selectionView = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyView = EmptyStateView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "消息"
        view.backgroundColor = Theme.Color.bg
        setupNavBar()
        setupTabBar()
        setupTableView()
        setupEmptyView()
        registerSocketObserver()
        reloadCurrent()
    }

    private func registerSocketObserver() {
        // 收到新聊天消息：刷新会话列表（未读数、最后一条实时更新）
        NotificationCenter.default.addObserver(
            self, selector: #selector(socketMessageReceived(_:)),
            name: .chatMessageReceived, object: nil
        )
    }

    @objc private func socketMessageReceived(_ notification: Notification) {
        guard currentTab == 0 else { return }
        loadConversations(page: 1, showLoading: false)
        NotificationCenter.default.post(name: .messageUnreadChanged, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 主动恢复普通不透明导航栏（聊天页返回后 appearance 自洽，不依赖其 restore 时机）
        restoreSystemNav()
        // 每次进入（含从聊天详情返回）刷新会话列表，保证「最后一条消息」与详情一致。
        // 注意：viewWillAppear 时 view 尚未挂到 window，view.window 恒为 nil，
        // 不能用 `if view.window != nil` 包裹，否则返回时列表永不刷新。
        // 列表非空时 showLoading=false 静默刷新，不闪 loading。
        reloadCurrent()
    }

    private func setupNavBar() {
        let addButton = UIButton(type: .system)
        addButton.setImage(UIImage(systemName: "plus"), for: .normal)
        addButton.tintColor = Theme.Color.brand
        addButton.addTarget(self, action: #selector(didTapAdd), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: addButton)
    }

    private func setupTabBar() {
        // 胶囊式切换容器：浅米圆角底
        segmentView.backgroundColor = Theme.Color.surfaceAlt
        segmentView.layer.cornerRadius = 20
        segmentView.clipsToBounds = true
        view.addSubview(segmentView)
        segmentView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.height.equalTo(40)
        }
        // 选中胶囊块（浅绿圆角）——先 addSubview 置于底层，避免遮挡按钮文字
        selectionView.backgroundColor = Theme.Color.brandSoft
        selectionView.layer.cornerRadius = 18
        segmentView.addSubview(selectionView)

        chatButton.setTitle("对话", for: .normal)
        chatButton.titleLabel?.font = .appSection(16)
        chatButton.tag = 0
        chatButton.addTarget(self, action: #selector(didTapSegment(_:)), for: .touchUpInside)
        segmentView.addSubview(chatButton)
        chatButton.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
        }

        noticeButton.setTitle("通知", for: .normal)
        noticeButton.titleLabel?.font = .appSection(16)
        noticeButton.tag = 1
        noticeButton.addTarget(self, action: #selector(didTapSegment(_:)), for: .touchUpInside)
        segmentView.addSubview(noticeButton)
        noticeButton.snp.makeConstraints {
            $0.leading.equalTo(chatButton.snp.trailing)
            $0.trailing.top.bottom.equalToSuperview()
            // 等宽均分（此时两个按钮都已在 segmentView 上，共同祖先成立）
            $0.width.equalTo(chatButton)
        }

        // 胶囊定位（三者均已在 segmentView 上）
        applySegmentSelection(animated: false)

        // Tab 下方细分隔线
        let divider = UIView()
        divider.backgroundColor = Theme.Color.line
        view.addSubview(divider)
        divider.snp.makeConstraints {
            $0.top.equalTo(segmentView.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(0.5)
        }
        divider.tag = 9901
    }

    @objc private func didTapSegment(_ sender: UIButton) {
        let index = sender.tag
        guard index != currentTab else { return }
        currentTab = index
        applySegmentSelection(animated: true)
        reloadCurrent()
    }

    private func applySegmentSelection(animated: Bool) {
        let chatSelected = currentTab == 0
        chatButton.setTitleColor(chatSelected ? Theme.Color.brand : Theme.Color.sub, for: .normal)
        noticeButton.setTitleColor(chatSelected ? Theme.Color.sub : Theme.Color.brand, for: .normal)
        let target = chatSelected ? chatButton : noticeButton
        selectionView.snp.remakeConstraints {
            $0.leading.equalTo(target)
            $0.top.bottom.equalToSuperview().inset(2)
            $0.width.equalTo(target)
        }
        if animated {
            UIView.animate(withDuration: 0.2) { self.segmentView.layoutIfNeeded() }
        } else {
            segmentView.layoutIfNeeded()
        }
    }

    private func setupTableView() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.alwaysBounceHorizontal = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 84
        // 底部 Tab 占位；左右边距由 cell 卡片 inset 12 承担
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 120, right: 0)
        tableView.register(ConversationCell.self, forCellReuseIdentifier: ConversationCell.reuseId)
        tableView.register(NotificationCell.self, forCellReuseIdentifier: NotificationCell.reuseId)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.reloadCurrent()
        }

        view.addSubview(tableView)
        // tableView 从 Tab 下方开始，避免遮挡 segmentView；首个 cell 紧贴 segment（卡片自带 8pt 上边距）
        tableView.snp.makeConstraints {
            $0.top.equalTo(segmentView.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }
        // 底部 Tab 占位；顶部不留额外间距（首个 cell 卡片自带 8pt 上边距）
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 120, right: 0)

        // 底部加载指示
        let footer = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        let spin = UIActivityIndicatorView(style: .medium)
        spin.color = Theme.Color.brand
        footer.addSubview(spin)
        spin.snp.makeConstraints { $0.center.equalToSuperview() }
        footerSpinner = spin
        tableView.tableFooterView = footer
    }

    private func setupEmptyView() {
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints {
            $0.top.equalTo(tableView.snp.top)
            $0.leading.trailing.bottom.equalToSuperview()
        }
        emptyView.isHidden = true
    }

    // MARK: - 数据

    private func reloadCurrent() {
        if currentTab == 0 {
            loadConversations(page: 1, showLoading: conversations.isEmpty)
        } else {
            loadNotifications(page: 1, showLoading: notifications.isEmpty)
        }
    }

    private func loadConversations(page: Int, showLoading: Bool) {
        guard !isLoading else {
            tableView.es.stopPullToRefresh()
            return
        }
        isLoading = true
        if showLoading { showEmpty(.loading) }

        MessageService.fetchConversations(page: page, size: 20) { [weak self] list, total, unread, error in
            guard let self else { return }
            self.isLoading = false
            self.tableView.es.stopPullToRefresh()
            self.footerSpinner?.stopAnimating()

            if let error {
                if self.conversations.isEmpty {
                    self.showEmpty(.error(error, retry: { [weak self] in self?.loadConversations(page: 1, showLoading: true) }))
                } else {
                    self.hideEmpty()
                    self.showToast(error)
                }
                return
            }
            let items = list ?? []
            if page == 1 {
                self.conversations = items
                self.convPage = 1
            } else {
                self.conversations.append(contentsOf: items)
                self.convPage = page
            }
            self.convHasMore = items.count >= 20 && self.conversations.count < total
            self.tableView.reloadData()
            self.updateUnreadBadge(unread)
            self.updateEmptyState()
        }
    }

    private func loadNotifications(page: Int, showLoading: Bool) {
        guard !isLoading else {
            tableView.es.stopPullToRefresh()
            return
        }
        isLoading = true
        if showLoading { showEmpty(.loading) }

        MessageService.fetchNotifications(page: page, size: 20) { [weak self] list, total, unread, error in
            guard let self else { return }
            self.isLoading = false
            self.tableView.es.stopPullToRefresh()
            self.footerSpinner?.stopAnimating()

            if let error {
                if self.notifications.isEmpty {
                    self.showEmpty(.error(error, retry: { [weak self] in self?.loadNotifications(page: 1, showLoading: true) }))
                } else {
                    self.hideEmpty()
                    self.showToast(error)
                }
                return
            }
            let items = list ?? []
            if page == 1 {
                self.notifications = items
                self.notifPage = 1
            } else {
                self.notifications.append(contentsOf: items)
                self.notifPage = page
            }
            self.notifHasMore = items.count >= 20 && self.notifications.count < total
            self.tableView.reloadData()
            self.updateUnreadBadge(unread)
            self.updateEmptyState()
        }
    }

    private func loadNextPage() {
        if currentTab == 0 {
            guard !isLoading, convHasMore, !conversations.isEmpty else { return }
            loadConversations(page: convPage + 1, showLoading: false)
        } else {
            guard !isLoading, notifHasMore, !notifications.isEmpty else { return }
            loadNotifications(page: notifPage + 1, showLoading: false)
        }
    }

    /// 通知未读数 → TabBar 角标
    private func updateUnreadBadge(_ unread: Int) {
        NotificationCenter.default.post(
            name: .messageUnreadChanged,
            object: nil,
            userInfo: ["unread": unread]
        )
    }

    private func updateEmptyState() {
        let listEmpty = currentTab == 0 ? conversations.isEmpty : notifications.isEmpty
        if listEmpty {
            let message = currentTab == 0 ? "暂无会话，去和老师聊聊吧" : "暂无通知"
            showEmpty(.empty(message))
        } else {
            hideEmpty()
        }
    }

    private func showEmpty(_ style: EmptyStateView.Style) {
        emptyView.isHidden = false
        emptyView.show(style: style)
        view.bringSubviewToFront(emptyView)
    }

    private func hideEmpty() {
        emptyView.isHidden = true
    }

    // MARK: - 事件

    @objc private func didTapAdd() {
        showToast("新建会话开发中")
    }

    // MARK: - UITableViewDataSource / Delegate

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        currentTab == 0 ? conversations.count : notifications.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if currentTab == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: ConversationCell.reuseId, for: indexPath) as! ConversationCell
            cell.configure(with: conversations[indexPath.row])
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: NotificationCell.reuseId, for: indexPath) as! NotificationCell
            cell.configure(with: notifications[indexPath.row])
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if currentTab == 0 {
            let item = conversations[indexPath.row]
            print("[Chat] didSelect conversation: \(item.conversationId), nav=\(navigationController != nil)")
            let vc = ChatViewController(conversation: item)
            navigationController?.pushViewController(vc, animated: true)
        } else {
            let item = notifications[indexPath.row]
            guard !item.isRead else { return }
            // 标记已读并本地刷新
            MessageService.markNotificationRead(id: item.notificationId) { [weak self] success, _ in
                guard let self, success else { return }
                if let idx = self.notifications.firstIndex(where: { $0.notificationId == item.notificationId }) {
                    let updated = self.notifications[idx]
                    let newItem = NotificationItem(
                        notificationId: updated.notificationId,
                        type: updated.type,
                        title: updated.title,
                        content: updated.content,
                        refType: updated.refType,
                        refId: updated.refId,
                        isRead: true,
                        createdAt: updated.createdAt
                    )
                    self.notifications[idx] = newItem
                    self.tableView.reloadRows(at: [IndexPath(row: idx, section: 0)], with: .none)
                }
                // 通知详情跳转后续接入（ref_type/ref_id 已具备）
            }
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentH = scrollView.contentSize.height
        let frameH = scrollView.frame.size.height
        if contentH > 0, offsetY > contentH - frameH - 100 {
            loadNextPage()
        }
    }
}

// MARK: - 会话 Cell

/// 会话卡片：头像 + 名称 + 预览 + 时间 + 未读角标
final class ConversationCell: UITableViewCell {

    static let reuseId = "ConversationCell"

    private let cardView = UIView()
    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let timeLabel = UILabel()
    private let previewLabel = UILabel()
    private let badgeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(cardView)
        cardView.backgroundColor = Theme.Color.surface
        cardView.layer.cornerRadius = Theme.Radius.card
        cardView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.s)
        }

        // 头像（圆形；无图时主题色块 + 首字）
        avatarView.contentMode = .scaleAspectFill
        avatarView.layer.cornerRadius = 26
        avatarView.clipsToBounds = true
        cardView.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(52)
            // top/bottom 撑起卡片高度（automaticDimension 需要完整约束链）
            $0.top.greaterThanOrEqualToSuperview().offset(Theme.Spacing.s)
            $0.bottom.lessThanOrEqualToSuperview().offset(-Theme.Spacing.s)
        }

        nameLabel.font = .appSection(15)
        nameLabel.textColor = Theme.Color.ink
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        cardView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarView.snp.trailing).offset(Theme.Spacing.m)
            $0.centerY.equalTo(avatarView.snp.centerY).offset(-11)
            $0.trailing.lessThanOrEqualToSuperview().offset(-64)
        }

        timeLabel.font = .appLabel(12)
        timeLabel.textColor = Theme.Color.muted
        timeLabel.textAlignment = .right
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        cardView.addSubview(timeLabel)
        timeLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.m)
            $0.centerY.equalTo(nameLabel)
            $0.leading.greaterThanOrEqualTo(nameLabel.snp.trailing).offset(Theme.Spacing.s)
        }

        previewLabel.font = .appBody(13)
        previewLabel.textColor = Theme.Color.sub
        previewLabel.numberOfLines = 1
        cardView.addSubview(previewLabel)
        previewLabel.snp.makeConstraints {
            $0.leading.equalTo(nameLabel)
            $0.centerY.equalTo(avatarView.snp.centerY).offset(13)
            $0.trailing.equalTo(timeLabel)
        }

        // 未读角标（danger 圆底白字；0 时隐藏）
        badgeLabel.font = .appLabel(11)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = Theme.Color.danger
        badgeLabel.layer.cornerRadius = 10
        badgeLabel.clipsToBounds = true
        badgeLabel.textAlignment = .center
        badgeLabel.isHidden = true
        cardView.addSubview(badgeLabel)
        badgeLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.m)
            $0.centerY.equalTo(previewLabel)
            $0.width.greaterThanOrEqualTo(20)
            $0.height.equalTo(20)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with item: ConversationItem) {
        let peer = item.peer
        nameLabel.text = peer?.nickname ?? "艺启用户"
        // 头像
        if let avatar = peer?.avatar, let url = URL(string: avatar) {
            avatarView.kf.setImage(with: url, placeholder: placeholder(for: nameLabel.text ?? "艺"))
        } else {
            avatarView.image = placeholder(for: nameLabel.text ?? "艺")
        }
        // 预览（孩子上下文：显示"孩子名："前缀）
        var preview = ""
        if let child = item.child, !child.nickname.isEmpty {
            preview = "\(child.nickname)："
        }
        if let last = item.lastMessage {
            preview += (last.type == 2 ? "[图片]" : last.content)
        } else {
            preview += "开始聊天吧"
        }
        previewLabel.text = preview
        timeLabel.text = MessageTimeFormatter.display(item.updatedAt)

        let unread = item.unreadCount
        badgeLabel.isHidden = unread <= 0
        badgeLabel.text = unread > 99 ? "99+" : "\(unread)"
        // 未读时预览加粗偏深
        previewLabel.font = unread > 0 ? .systemFont(ofSize: 13, weight: .medium) : .appBody(13)
        previewLabel.textColor = unread > 0 ? Theme.Color.ink : Theme.Color.sub
    }

    /// 无头像占位：按昵称取主题色 + 首字
    private func placeholder(for name: String) -> UIImage? {
        let colors: [UIColor] = [Theme.Color.brand, Theme.Color.wood, Theme.Color.clay, Theme.Color.info]
        let index = abs(name.hashValue) % colors.count
        let color = colors[index]
        let size = CGSize(width: 52, height: 52)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 26).fill()
            let first = String(name.prefix(1))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.appSection(20),
                .foregroundColor: UIColor.white
            ]
            let strSize = first.size(withAttributes: attrs)
            first.draw(at: CGPoint(x: (size.width - strSize.width) / 2, y: (size.height - strSize.height) / 2), withAttributes: attrs)
        }
    }
}

// MARK: - 通知 Cell

/// 通知卡片：类型图标 + 标题 + 内容 + 时间 + 未读红点
final class NotificationCell: UITableViewCell {

    static let reuseId = "NotificationCell"

    private let cardView = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let contentLabel = UILabel()
    private let timeLabel = UILabel()
    private let unreadDot = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(cardView)
        cardView.backgroundColor = Theme.Color.surface
        cardView.layer.cornerRadius = Theme.Radius.card
        cardView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.s)
        }

        // 类型图标圆底
        let iconWrap = UIView()
        iconWrap.backgroundColor = Theme.Color.brandSoft
        iconWrap.layer.cornerRadius = 20
        cardView.addSubview(iconWrap)
        iconWrap.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(40)
            // top/bottom 撑起卡片高度（automaticDimension 需要完整约束链）
            $0.top.greaterThanOrEqualToSuperview().offset(Theme.Spacing.s)
            $0.bottom.lessThanOrEqualToSuperview().offset(-Theme.Spacing.s)
        }
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = Theme.Color.brand
        iconWrap.addSubview(iconView)
        iconView.snp.makeConstraints { $0.edges.equalToSuperview().inset(10) }

        titleLabel.font = .appSection(14)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 1
        cardView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(iconWrap.snp.trailing).offset(Theme.Spacing.m)
            $0.top.equalToSuperview().offset(14)
            $0.trailing.lessThanOrEqualToSuperview().offset(-40)
        }

        contentLabel.font = .appBody(13)
        contentLabel.textColor = Theme.Color.sub
        contentLabel.numberOfLines = 2
        cardView.addSubview(contentLabel)
        contentLabel.snp.makeConstraints {
            $0.leading.equalTo(titleLabel)
            $0.top.equalTo(titleLabel.snp.bottom).offset(4)
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.m)
            $0.bottom.lessThanOrEqualToSuperview().offset(-14)
        }

        timeLabel.font = .appLabel(11)
        timeLabel.textColor = Theme.Color.muted
        cardView.addSubview(timeLabel)
        timeLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.m)
            $0.centerY.equalTo(titleLabel)
        }

        unreadDot.backgroundColor = Theme.Color.danger
        unreadDot.layer.cornerRadius = 4
        unreadDot.isHidden = true
        cardView.addSubview(unreadDot)
        unreadDot.snp.makeConstraints {
            $0.width.height.equalTo(8)
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.m)
            $0.centerY.equalTo(contentLabel)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with item: NotificationItem) {
        titleLabel.text = item.title
        contentLabel.text = item.content.isEmpty ? item.title : item.content
        timeLabel.text = MessageTimeFormatter.display(item.createdAt)

        let iconName = Self.iconName(for: item.type)
        iconView.image = UIImage(systemName: iconName)
        unreadDot.isHidden = item.isRead
        // 未读：标题加粗深色；已读：次级色
        titleLabel.font = item.isRead ? .appBody(14) : .appSection(14)
        titleLabel.textColor = item.isRead ? Theme.Color.sub : Theme.Color.ink
        contentLabel.textColor = item.isRead ? Theme.Color.muted : Theme.Color.sub
    }

    /// 通知类型 → SF Symbol
    static func iconName(for type: String) -> String {
        switch type {
        case "comment": return "text.bubble"
        case "like": return "heart"
        case "follow": return "person.badge.plus"
        case "order": return "cart"
        case "refund": return "arrow.uturn.backward"
        case "course", "class": return "book"
        case "growth", "checkin": return "chart.line.uptrend.xyaxis"
        case "leave": return "calendar.badge.checkmark"
        case "commission", "withdraw", "balance": return "yensign.circle"
        case "teacher", "studio": return "person.crop.circle.badge.checkmark"
        case "system": return "megaphone"
        default: return "bell"
        }
    }
}
