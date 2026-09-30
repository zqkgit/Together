import UIKit
import SnapKit
import Kingfisher
import ESPullToRefresh

/// 关注列表（从消息页 "+" 进入，选择关注的人发起聊天）
final class FollowingListViewController: BaseViewController {

    // MARK: - Data

    private var users: [FollowingUser] = []
    private var page = 1
    private var hasMore = true
    private var isLoading = false

    // MARK: - UI

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyView = EmptyStateView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "选择联系人"
        setupUI()
        loadData()
    }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = Theme.Color.bg

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(FollowingUserCell.self, forCellReuseIdentifier: FollowingUserCell.reuseId)
        tableView.rowHeight = 68
        tableView.alwaysBounceVertical = true
        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.refreshData()
        }
        tableView.es.addInfiniteScrolling { [weak self] in
            self?.loadMore()
        }
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        emptyView.show(style: .empty("暂无关注\n关注其他用户后可以在这里发起聊天"))
        tableView.backgroundView = emptyView
    }

    // MARK: - Data

    private func refreshData() {
        page = 1
        hasMore = true
        loadData()
    }

    private func loadMore() {
        guard hasMore, !isLoading else {
            tableView.es.stopLoadingMore()
            return
        }
        page += 1
        loadData()
    }

    private func loadData() {
        guard !isLoading else { return }
        isLoading = true
        PostService.fetchFollowing(page: page) { [weak self] list, total, error in
            guard let self else { return }
            self.isLoading = false
            self.tableView.es.stopPullToRefresh()
            self.tableView.es.stopLoadingMore()
            if let error {
                if self.users.isEmpty {
                    self.showToast(error)
                }
                return
            }
            if self.page <= 1 {
                self.users = list
            } else {
                self.users.append(contentsOf: list)
            }
            self.hasMore = self.users.count < total
            self.tableView.reloadData()
            self.tableView.backgroundView = self.users.isEmpty ? self.emptyView : nil
        }
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension FollowingListViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        users.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FollowingUserCell.reuseId, for: indexPath) as! FollowingUserCell
        cell.configure(with: users[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let user = users[indexPath.row]
        guard TokenManager.shared.isLoggedIn else {
            showToast("请先登录")
            return
        }
        showLoading()
        MessageService.createConversation(peerUserId: user.userId) { [weak self] conversation, error in
            guard let self else { return }
            self.hideLoading()
            if let error {
                self.showToast(error)
                return
            }
            guard let conversation else {
                self.showToast("创建会话失败")
                return
            }
            let vc = ChatViewController(conversation: conversation)
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}

// MARK: - FollowingUserCell

final class FollowingUserCell: UITableViewCell {

    static let reuseId = "FollowingUserCell"

    private let cardView = UIView()
    private let avatarView = UIImageView()
    private let avatarLabel = UILabel()
    private let nameLabel = UILabel()
    private let roleBadge = UILabel()
    private let arrowLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        contentView.addSubview(cardView)
        cardView.backgroundColor = Theme.Color.surface
        cardView.layer.cornerRadius = Theme.Radius.card
        cardView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(4)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().offset(-4)
        }

        // 头像（圆形；无图时主题色块 + 首字）
        avatarView.contentMode = .scaleAspectFill
        avatarView.layer.cornerRadius = 22
        avatarView.clipsToBounds = true
        cardView.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(44)
        }

        avatarLabel.font = .appSection(18)
        avatarLabel.textColor = .white
        avatarLabel.textAlignment = .center
        avatarView.addSubview(avatarLabel)
        avatarLabel.snp.makeConstraints {
            $0.center.equalToSuperview()
        }

        // 昵称
        nameLabel.font = .appSection(15)
        nameLabel.textColor = Theme.Color.ink
        cardView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarView.snp.trailing).offset(12)
            $0.top.equalToSuperview().offset(16)
        }

        // 角色标签
        roleBadge.font = .appLabel(10)
        roleBadge.textColor = .white
        roleBadge.textAlignment = .center
        roleBadge.backgroundColor = Theme.Color.brand
        roleBadge.layer.cornerRadius = 8
        roleBadge.layer.masksToBounds = true
        cardView.addSubview(roleBadge)
        roleBadge.snp.makeConstraints {
            $0.leading.equalTo(nameLabel.snp.trailing).offset(6)
            $0.centerY.equalTo(nameLabel)
            $0.height.equalTo(16)
            $0.width.greaterThanOrEqualTo(28)
        }

        // 箭头
        arrowLabel.text = "›"
        arrowLabel.font = .appTitle(18)
        arrowLabel.textColor = Theme.Color.muted
        cardView.addSubview(arrowLabel)
        arrowLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.cardInner)
            $0.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with user: FollowingUser) {
        nameLabel.text = user.displayName
        roleBadge.text = user.roleText
        roleBadge.isHidden = user.role == nil

        // 头像
        if let avatar = user.avatar, !avatar.isEmpty, let url = URL(string: avatar) {
            avatarView.kf.setImage(with: url, placeholder: placeholder(for: user.displayName))
            avatarLabel.isHidden = true
        } else {
            avatarView.image = placeholder(for: user.displayName)
            avatarLabel.isHidden = false
            avatarLabel.text = String(user.displayName.prefix(1))
        }
    }

    /// 无头像占位：按昵称取主题色 + 首字
    private func placeholder(for name: String) -> UIImage? {
        let colors: [UIColor] = [Theme.Color.brand, Theme.Color.wood, Theme.Color.clay, Theme.Color.info]
        let index = abs(name.hashValue) % colors.count
        let color = colors[index]
        let size = CGSize(width: 44, height: 44)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 22).fill()
        }
    }
}