import UIKit
import SnapKit
import Kingfisher
import ESPullToRefresh

/// 工作室 App 端 · 老师合作申请
///
/// 分段筛选（待处理 / 已通过 / 已驳回 / 全部，带计数）+ 申请卡片；
/// 待处理的卡片可在 App 内直接「通过」或「驳回并留言」，与 Web 后台「合作申请」tab 同源
/// 数据来源 GET/PUT /v1/studio/teachers/applications
final class StudioTeacherApplicationViewController: BaseViewController {

    /// 审批完成后回调列表页刷新（待审角标）
    var onReviewed: (() -> Void)?

    private var currentFilter: StudioTeacherApplicationFilter = .all
    private var summary: StudioTeacherApplicationSummary = .empty
    private var applications: [StudioTeacherApplication] = []
    private var firstLoad = true

    private let filterBar = StudioTeacherApplicationFilterBar()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyView = EmptyStateView()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "合作申请")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    // MARK: - 布局

    private func setupUI() {
        view.backgroundColor = Theme.Color.bg

        filterBar.onSelect = { [weak self] index in
            guard let self,
                  let filter = StudioTeacherApplicationFilter.allCases[safe: index] else { return }
            self.currentFilter = filter
            self.loadData()
        }
        view.addSubview(filterBar)
        filterBar.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(43)
        }

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(StudioTeacherApplicationCell.self, forCellReuseIdentifier: StudioTeacherApplicationCell.reuseID)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.loadData()
        }
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(filterBar.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        emptyView.isHidden = true
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints {
            $0.centerX.equalTo(tableView)
            $0.centerY.equalTo(tableView).offset(-30)
        }
    }

    // MARK: - 数据

    private func loadData() {
        if firstLoad { emptyView.show(style: .loading) }
        StudioService.fetchTeacherApplications(status: currentFilter.apiValue) { [weak self] result in
            guard let self else { return }
            self.firstLoad = false
            self.tableView.es.stopPullToRefresh()
            switch result {
            case .success(let page):
                self.summary = page.summary ?? .empty
                self.applications = page.list ?? []
                self.filterBar.update(summary: self.summary)
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

    private func applyEmptyState() {
        if applications.isEmpty {
            emptyView.isHidden = false
            emptyView.show(style: .empty(currentFilter.emptyText))
        } else {
            emptyView.isHidden = true
        }
    }

    // MARK: - 审批

    private func approve(_ application: StudioTeacherApplication) {
        ThemeAlertView.show(
            title: "通过合作申请",
            message: "通过后「\(application.displayName)」加入本工作室，可被指派到班级并开始排课。",
            confirmTitle: "确认通过",
            cancelTitle: "再想想",
            onConfirm: { [weak self] in
                self?.submit(application, action: "approve")
            }
        )
    }

    private func reject(_ application: StudioTeacherApplication) {
        ThemeInputAlertView.show(
            title: "驳回并留言",
            placeholder: "请填写驳回原因（老师可见）",
            maxCount: 100,
            confirmTitle: "确认驳回",
            onConfirm: { [weak self] reason in
                self?.submit(application, action: "reject", reason: reason)
            }
        )
    }

    private func submit(_ application: StudioTeacherApplication, action: String, reason: String? = nil) {
        showLoading()
        StudioService.reviewTeacherApplication(id: application.id, action: action, reason: reason) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success:
                self.showToast(action == "approve" ? "已通过，老师已加入工作室" : "已驳回申请")
                self.onReviewed?()
                self.loadData()
            case .failure(let error):
                self.showToast(error.message ?? "操作失败")
            }
        }
    }
}

// MARK: - 列表

extension StudioTeacherApplicationViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        applications.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: StudioTeacherApplicationCell.reuseID,
            for: indexPath
        ) as! StudioTeacherApplicationCell
        let application = applications[indexPath.row]
        cell.configure(application)
        cell.onApprove = { [weak self] in self?.approve(application) }
        cell.onReject = { [weak self] in self?.reject(application) }
        return cell
    }
}

// MARK: - 分段筛选条（待处理 / 已通过 / 已驳回 / 全部）

/// 白色圆角卡片内四段等分：选中态浅绿胶囊 + 深色字，未选态透明底 + 棕色字
private final class StudioTeacherApplicationFilterBar: UIView {

    var onSelect: ((Int) -> Void)?

    private let stack = UIStackView()
    private var buttons: [UIButton] = []
    private var summary: StudioTeacherApplicationSummary = .empty
    private var selectedIndex = StudioTeacherApplicationFilter.allCases.count - 1   // 默认「全部」

    init() {
        super.init(frame: .zero)
        backgroundColor = Theme.Color.surface
        layer.cornerRadius = Theme.Radius.card
        layer.shadowColor = UIColor(hex: 0x2B2621).cgColor
        layer.shadowOpacity = 0.04
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 3)

        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 0
        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(4) }

        for (index, _) in StudioTeacherApplicationFilter.allCases.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.layer.cornerRadius = 13
            button.addTarget(self, action: #selector(didTap(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
            buttons.append(button)
        }
        applySelection()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(summary: StudioTeacherApplicationSummary) {
        self.summary = summary
        applySelection()
    }

    @objc private func didTap(_ sender: UIButton) {
        guard sender.tag != selectedIndex else { return }
        selectedIndex = sender.tag
        applySelection()
        onSelect?(sender.tag)
    }

    private func applySelection() {
        for (index, button) in buttons.enumerated() {
            let filter = StudioTeacherApplicationFilter.allCases[index]
            let selected = index == selectedIndex
            button.backgroundColor = selected ? Theme.Color.brandSoft : .clear
            button.setAttributedTitle(attributedTitle(filter: filter, selected: selected), for: .normal)
        }
    }

    /// 「待处理 2」：文案 + 空格 + 数字，选中加粗
    private func attributedTitle(filter: StudioTeacherApplicationFilter, selected: Bool) -> NSAttributedString {
        let text = "\(filter.title) \(summary.count(for: filter))"
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        return NSAttributedString(
            string: text,
            attributes: [
                .font: selected ? UIFont.appSection(13) : UIFont.appBody(13),
                .foregroundColor: selected ? Theme.Color.ink : Theme.Color.sub,
                .paragraphStyle: paragraph
            ]
        )
    }
}

// MARK: - 申请卡片

private final class StudioTeacherApplicationCell: UITableViewCell {

    static let reuseID = "StudioTeacherApplicationCell"

    var onApprove: (() -> Void)?
    var onReject: (() -> Void)?

    private let card = UIView()
    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let subLabel = UILabel()
    private let statusLabel = PaddedTagLabel()
    private let introLabel = UILabel()
    private let reasonLabel = UILabel()
    private let actionRow = UIView()
    private let rejectButton = UIButton(type: .system)
    private let approveButton = UIButton(type: .system)

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
            $0.top.equalToSuperview().offset(5)
            $0.bottom.equalToSuperview().offset(-5)
        }

        avatarView.layer.cornerRadius = 21
        avatarView.clipsToBounds = true
        avatarView.contentMode = .scaleAspectFill
        avatarView.backgroundColor = Theme.Color.surfaceAlt
        card.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(14)
            $0.top.equalToSuperview().offset(14)
            $0.width.height.equalTo(42)
        }

        // 状态标签必须先入视图树：nameLabel / subLabel 的右边界依赖它
        statusLabel.font = .appLabel(11)
        statusLabel.textAlignment = .center
        statusLabel.layer.cornerRadius = 8
        statusLabel.clipsToBounds = true
        card.addSubview(statusLabel)
        statusLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-14)
            $0.centerY.equalTo(avatarView)
            $0.height.equalTo(22)
        }

        nameLabel.font = .appSection(15)
        nameLabel.textColor = Theme.Color.ink
        nameLabel.numberOfLines = 1
        card.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarView.snp.trailing).offset(12)
            $0.top.equalTo(avatarView).offset(1)
            $0.trailing.lessThanOrEqualTo(statusLabel.snp.leading).offset(-8)
        }

        subLabel.font = .appLabel(12)
        subLabel.textColor = Theme.Color.muted
        subLabel.numberOfLines = 1
        card.addSubview(subLabel)
        subLabel.snp.makeConstraints {
            $0.leading.equalTo(nameLabel)
            $0.top.equalTo(nameLabel.snp.bottom).offset(4)
            $0.trailing.lessThanOrEqualTo(statusLabel.snp.leading).offset(-8)
        }

        // 简介 / 驳回原因
        introLabel.font = .appLabel(12)
        introLabel.textColor = Theme.Color.sub
        introLabel.numberOfLines = 2
        card.addSubview(introLabel)
        introLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(14)
            $0.trailing.equalToSuperview().offset(-14)
            $0.top.equalTo(avatarView.snp.bottom).offset(12)
        }

        reasonLabel.font = .appLabel(11)
        reasonLabel.textColor = Theme.Color.warn
        reasonLabel.numberOfLines = 2
        card.addSubview(reasonLabel)
        reasonLabel.snp.makeConstraints {
            $0.leading.equalTo(introLabel)
            $0.trailing.equalTo(introLabel)
            $0.top.equalTo(introLabel.snp.bottom).offset(6)
        }

        // 操作按钮（仅待处理显示）
        rejectButton.setTitle("驳回", for: .normal)
        rejectButton.titleLabel?.font = .appBody(14)
        rejectButton.setTitleColor(Theme.Color.sub, for: .normal)
        rejectButton.backgroundColor = Theme.Color.surfaceAlt
        rejectButton.layer.cornerRadius = 10
        rejectButton.addTarget(self, action: #selector(tapReject), for: .touchUpInside)

        approveButton.setTitle("通过申请", for: .normal)
        approveButton.titleLabel?.font = .appBody(14)
        approveButton.setTitleColor(.white, for: .normal)
        approveButton.backgroundColor = Theme.Color.brand
        approveButton.layer.cornerRadius = 10
        approveButton.addTarget(self, action: #selector(tapApprove), for: .touchUpInside)

        card.addSubview(actionRow)
        actionRow.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(14)
            $0.trailing.equalToSuperview().offset(-14)
            $0.top.equalTo(reasonLabel.snp.bottom).offset(12)
            $0.bottom.equalToSuperview().offset(-14)
            $0.height.equalTo(0)
        }

        actionRow.addSubview(rejectButton)
        actionRow.addSubview(approveButton)
        rejectButton.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
            $0.width.equalTo(78)
        }
        approveButton.snp.makeConstraints {
            $0.trailing.top.bottom.equalToSuperview()
            $0.leading.equalTo(rejectButton.snp.trailing).offset(10)
        }
    }

    func configure(_ application: StudioTeacherApplication) {
        nameLabel.text = application.displayName
        subLabel.text = "\(application.subtitle) · 申请 \(application.submittedText)"

        statusLabel.text = application.statusText
        switch application.status {
        case 1:
            statusLabel.textColor = Theme.Color.brand
            statusLabel.backgroundColor = Theme.Color.brandSoft
        case 2:
            statusLabel.textColor = Theme.Color.muted
            statusLabel.backgroundColor = Theme.Color.surfaceAlt
        default:
            statusLabel.textColor = Theme.Color.warn
            statusLabel.backgroundColor = Theme.Color.warnTint
        }

        let intro = (application.intro ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let certText = (application.cert_no?.isEmpty == false) ? "证书 \(application.cert_no!)" : "未上传证书"
        introLabel.text = intro.isEmpty ? certText : "\(intro) · \(certText)"

        let reason = (application.review_reason ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let showReason = application.status == 2 && !reason.isEmpty
        reasonLabel.isHidden = !showReason
        reasonLabel.text = showReason ? "驳回原因：\(reason)" : nil

        // 按钮行高度：待处理 44，其余 0（隐式收起）
        actionRow.isHidden = !application.isPending
        if application.isPending {
            actionRow.snp.updateConstraints { $0.height.equalTo(40) }
        } else {
            actionRow.snp.updateConstraints { $0.height.equalTo(0) }
        }

        if let urlString = application.avatar, let url = URL(string: urlString), !urlString.isEmpty {
            avatarView.backgroundColor = Theme.Color.surfaceAlt
            avatarView.kf.setImage(with: url)
        } else {
            avatarView.kf.cancelDownloadTask()
            avatarView.image = nil
            avatarView.backgroundColor = StudioApplicationAvatarTint(application.id)
        }
    }

    @objc private func tapApprove() { onApprove?() }
    @objc private func tapReject() { onReject?() }
}

/// 带左右内边距的状态小标签
private final class PaddedTagLabel: UILabel {

    private let insets = UIEdgeInsets(top: 0, left: 9, bottom: 0, right: 9)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height)
    }
}

private func StudioApplicationAvatarTint(_ id: String) -> UIColor {
    let palette: [UInt32] = [0x7DABC2, 0x8BB270, 0xD4B269, 0xBA96C8, 0xBB96B2, 0x8FBFB0]
    var hash = 0
    for u in id.unicodeScalars { hash = (hash &* 31) &+ Int(u.value) }
    return UIColor(hex: palette[abs(hash) % palette.count])
}

// MARK: - 便捷下标

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
