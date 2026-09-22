import UIKit
import SnapKit
import Kingfisher
import ESPullToRefresh

/// 工作室 App 端 · 老师管理
///
/// 卡片：彩色圆形头像 + 姓名 + 「擅长方向 · 教龄 N 年」 + 右侧「N 名学生 / 月消课 N 节」
/// 右上白块：老师合作申请入口（待审时带红色角标）；右下悬浮 +：邀请老师（手机号）
/// 点卡片进老师详情
final class StudioTeacherListViewController: BaseViewController {

    // MARK: - 状态

    private var summary: StudioTeacherSummary = .empty
    private var teachers: [StudioTeacherItem] = []
    private var firstLoad = true

    // MARK: - 视图

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyView = EmptyStateView()
    private let applicationButton = UIButton(type: .system)
    private let badgeLabel = UILabel()
    private let fabButton = UIButton(type: .system)
    private lazy var applicationItem = UIBarButtonItem(customView: applicationButton)

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "老师管理")
        navigationItem.rightBarButtonItem = applicationItem
        if !firstLoad { loadData() }   // 审批 / 解除合作返回后刷新
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    // MARK: - 布局

    private func setupUI() {
        view.backgroundColor = Theme.Color.bg

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(StudioTeacherCell.self, forCellReuseIdentifier: StudioTeacherCell.reuseID)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 74
        tableView.contentInset.bottom = 92          // 给悬浮按钮留出空间
        tableView.verticalScrollIndicatorInsets.bottom = 92
        // iOS 15+ plain 样式首个 section 前会凭空多出 22pt → 归零
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.loadData()
        }
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(Theme.Spacing.s)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        emptyView.isHidden = true
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints {
            $0.centerX.equalTo(tableView)
            $0.centerY.equalTo(tableView).offset(-40)
        }

        setupApplicationButton()
        setupFab()
    }

    /// 右上「合作申请」入口：白色圆角方块 + 待审角标
    private func setupApplicationButton() {
        applicationButton.backgroundColor = Theme.Color.surface
        applicationButton.layer.cornerRadius = 12
        applicationButton.layer.shadowColor = UIColor(hex: 0x2B2621).cgColor
        applicationButton.layer.shadowOpacity = 0.05
        applicationButton.layer.shadowRadius = 8
        applicationButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        applicationButton.setImage(
            UIImage(systemName: "person.badge.plus")?.withConfiguration(
                UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            ),
            for: .normal
        )
        applicationButton.tintColor = Theme.Color.ink
        applicationButton.addTarget(self, action: #selector(tapApplications), for: .touchUpInside)
        applicationButton.snp.makeConstraints { $0.width.height.equalTo(36) }

        // 角标：贴按钮右上角（等式定位，避免位置欠定）
        badgeLabel.backgroundColor = Theme.Color.danger
        badgeLabel.textColor = .white
        badgeLabel.font = .appLabel(10)
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 8
        badgeLabel.clipsToBounds = true
        badgeLabel.isHidden = true
        applicationButton.addSubview(badgeLabel)
        badgeLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(-4)
            $0.trailing.equalToSuperview().offset(4)
            $0.height.equalTo(16)
            $0.width.greaterThanOrEqualTo(16)
        }
    }

    /// 右下悬浮「邀请老师」
    private func setupFab() {
        fabButton.backgroundColor = Theme.Color.brand
        fabButton.layer.cornerRadius = 16
        fabButton.layer.shadowColor = Theme.Color.brand.cgColor
        fabButton.layer.shadowOpacity = 0.28
        fabButton.layer.shadowRadius = 12
        fabButton.layer.shadowOffset = CGSize(width: 0, height: 6)
        fabButton.setImage(
            UIImage(systemName: "plus")?.withConfiguration(
                UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)
            ),
            for: .normal
        )
        fabButton.tintColor = .white
        fabButton.addTarget(self, action: #selector(tapInvite), for: .touchUpInside)
        view.addSubview(fabButton)
        fabButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-20)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-20)
            $0.width.height.equalTo(52)
        }
    }

    // MARK: - 数据

    private func loadData() {
        if firstLoad { emptyView.show(style: .loading) }
        StudioService.fetchTeachers { [weak self] result in
            guard let self else { return }
            self.firstLoad = false
            self.tableView.es.stopPullToRefresh()
            switch result {
            case .success(let page):
                self.summary = page.summary ?? .empty
                self.teachers = page.list ?? []
                self.applyBadge()
                self.tableView.reloadData()
                self.applyEmptyState()
            case .failure(let error):
                self.emptyView.isHidden = false
                self.emptyView.show(style: .error(error.message ?? "加载失败") { [weak self] in
                    self?.loadData()
                })
            }
        }
    }

    private func applyBadge() {
        let pending = summary.pendingCount
        badgeLabel.isHidden = pending <= 0
        badgeLabel.text = pending > 99 ? "99+" : "\(pending)"
    }

    private func applyEmptyState() {
        if teachers.isEmpty {
            emptyView.isHidden = false
            emptyView.show(style: .empty("还没有合作老师\n点右下角「+」邀请老师加入"))
        } else {
            emptyView.isHidden = true
        }
    }

    // MARK: - 交互

    @objc private func tapApplications() {
        let vc = StudioTeacherApplicationViewController()
        vc.onReviewed = { [weak self] in self?.loadData() }
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func tapInvite() {
        ThemeInputAlertView.show(
            title: "邀请老师",
            placeholder: "输入对方手机号（需已通过老师认证）",
            maxCount: 11,
            confirmTitle: "发送邀请",
            onConfirm: { [weak self] phone in
                self?.submitInvite(phone)
            }
        )
    }

    private func submitInvite(_ phone: String) {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 11, trimmed.allSatisfy({ $0.isNumber }) else {
            showToast("请输入 11 位手机号")
            return
        }
        showLoading()
        StudioService.inviteTeacher(phone: trimmed) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success(let invite):
                self.showToast("已邀请「\(invite?.teacherName ?? "老师")」加入工作室")
                self.loadData()
            case .failure(let error):
                self.showToast(error.message ?? "邀请失败")
            }
        }
    }

    private func openDetail(_ teacher: StudioTeacherItem) {
        let vc = StudioTeacherDetailViewController(teacherId: teacher.teacher_id, name: teacher.displayName)
        vc.onReleased = { [weak self] in self?.loadData() }
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - 列表

extension StudioTeacherListViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        teachers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: StudioTeacherCell.reuseID,
            for: indexPath
        ) as! StudioTeacherCell
        cell.configure(teachers[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        openDetail(teachers[indexPath.row])
    }
}

// MARK: - 老师卡片

/// 设计稿：卡片高 66、卡间距 8、头像 42（距卡左 12）
private final class StudioTeacherCell: UITableViewCell {

    static let reuseID = "StudioTeacherCell"

    private let card = UIView()
    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let subLabel = UILabel()
    private let valueStack = UIStackView()
    private let studentsLabel = UILabel()
    private let lessonsLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        card.layer.shadowColor = UIColor(hex: 0x2B2621).cgColor
        card.layer.shadowOpacity = 0.04
        card.layer.shadowRadius = 10
        card.layer.shadowOffset = CGSize(width: 0, height: 3)
        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalToSuperview().offset(4)
            $0.bottom.equalToSuperview().offset(-4)   // 卡高 66 + 卡间距 8
        }

        avatarView.layer.cornerRadius = 21
        avatarView.clipsToBounds = true
        avatarView.contentMode = .scaleAspectFill
        avatarView.backgroundColor = Theme.Color.surfaceAlt
        card.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(12)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(42)
        }

        // 右侧：学生数 + 月消课（两行，右对齐，抗压缩 required 免得被长名字挤没）
        studentsLabel.font = .appSection(13)
        studentsLabel.textColor = Theme.Color.brandDark
        studentsLabel.textAlignment = .right
        studentsLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        lessonsLabel.font = .appLabel(11)
        lessonsLabel.textColor = Theme.Color.muted
        lessonsLabel.textAlignment = .right
        lessonsLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueStack.axis = .vertical
        valueStack.alignment = .trailing
        valueStack.spacing = 3
        valueStack.addArrangedSubview(studentsLabel)
        valueStack.addArrangedSubview(lessonsLabel)
        card.addSubview(valueStack)
        valueStack.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-14)
            $0.centerY.equalToSuperview()
        }

        nameLabel.font = .appSection(16)
        nameLabel.textColor = Theme.Color.ink
        nameLabel.numberOfLines = 1
        card.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(12)
            $0.leading.equalTo(avatarView.snp.trailing).offset(12)
            $0.trailing.lessThanOrEqualTo(valueStack.snp.leading).offset(-8)
        }

        subLabel.font = .appLabel(12)
        subLabel.textColor = Theme.Color.muted
        subLabel.numberOfLines = 1
        card.addSubview(subLabel)
        subLabel.snp.makeConstraints {
            $0.top.equalTo(nameLabel.snp.bottom).offset(4)
            $0.leading.equalTo(nameLabel)
            $0.trailing.lessThanOrEqualTo(valueStack.snp.leading).offset(-8)
            $0.bottom.equalToSuperview().offset(-12)
        }
    }

    func configure(_ teacher: StudioTeacherItem) {
        nameLabel.text = teacher.displayName
        subLabel.text = teacher.subtitle
        studentsLabel.text = teacher.studentsText
        lessonsLabel.text = teacher.lessonsText

        if let urlString = teacher.avatar, let url = URL(string: urlString), !urlString.isEmpty {
            avatarView.backgroundColor = Theme.Color.surfaceAlt
            avatarView.kf.setImage(with: url)
        } else {
            avatarView.kf.cancelDownloadTask()
            avatarView.image = nil
            avatarView.backgroundColor = StudioTeacherAvatarTint(teacher.teacher_id)
        }
    }
}

/// 老师头像占位色（设计稿为纯色圆形，按 teacher_id 稳定取色）
private func StudioTeacherAvatarTint(_ id: String) -> UIColor {
    let palette: [UInt32] = [0x7DABC2, 0x8BB270, 0xD4B269, 0xBA96C8, 0xBB96B2, 0x8FBFB0]
    var hash = 0
    for u in id.unicodeScalars { hash = (hash &* 31) &+ Int(u.value) }
    return UIColor(hex: palette[abs(hash) % palette.count])
}
