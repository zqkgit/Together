import UIKit
import SnapKit
import Kingfisher
import ESPullToRefresh

/// 工作室 App 端 · 课程管理
/// 分段：在售(1) / 审核中(0) / 已下架(2)；卡片操作：编辑、上架/下架、预览；右下加号新建。
final class StudioCourseListViewController: BaseViewController {

    private struct Tab {
        let title: String
        let status: Int
        let empty: String
    }

    private let tabs: [Tab] = [
        Tab(title: "在售", status: 1, empty: "暂无在售课程"),
        Tab(title: "审核中", status: 0, empty: "暂无审核中的课程"),
        Tab(title: "已下架", status: 2, empty: "暂无已下架课程")
    ]

    private var currentStatus: Int = 1
    private var courses: [StudioCourseItem] = []
    private var chipRow: TagChipRow?
    private var firstLoad = true

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyView = EmptyStateView()
    private let fab = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "课程管理")
        if !firstLoad { loadData() }   // 从预览/编辑返回刷新状态
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    private func setupUI() {
        view.backgroundColor = Theme.Color.bg

        let chipRow = TagChipRow(chips: tabs.map(\.title), selectedIndex: 0)
        chipRow.onSelect = { [weak self] index in
            guard let self else { return }
            self.currentStatus = self.tabs[index].status
            self.loadData()
        }
        view.addSubview(chipRow)
        chipRow.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.height.equalTo(34)
        }
        self.chipRow = chipRow

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(StudioCourseCell.self, forCellReuseIdentifier: StudioCourseCell.reuseID)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 210
        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.loadData()
        }
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(chipRow.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            $0.bottom.equalToSuperview()
        }

        emptyView.isHidden = true
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints { $0.center.equalTo(tableView) }

        // 新建课程 FAB
        fab.backgroundColor = Theme.Color.brand
        fab.layer.cornerRadius = 28
        fab.setImage(UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold)), for: .normal)
        fab.tintColor = .white
        fab.layer.shadowColor = Theme.Color.brand.cgColor
        fab.layer.shadowOpacity = 0.35
        fab.layer.shadowOffset = CGSize(width: 0, height: 6)
        fab.layer.shadowRadius = 12
        fab.addTarget(self, action: #selector(tapCreate), for: .touchUpInside)
        view.addSubview(fab)
        fab.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-Theme.Spacing.xl)
            $0.width.height.equalTo(56)
        }
    }

    private func currentTab() -> Tab {
        tabs.first { $0.status == currentStatus } ?? tabs[0]
    }

    private func loadData() {
        if firstLoad { emptyView.show(style: .loading) }
        StudioService.fetchCourses(status: currentStatus) { [weak self] result in
            guard let self else { return }
            self.firstLoad = false
            self.tableView.es.stopPullToRefresh()
            switch result {
            case .success(let list):
                self.courses = list
                self.tableView.reloadData()
                let isEmpty = list.isEmpty
                self.emptyView.isHidden = !isEmpty
                if isEmpty { self.emptyView.show(style: .empty(self.currentTab().empty)) }
            case .failure(let error):
                self.emptyView.isHidden = false
                self.emptyView.show(style: .error(error.message ?? "加载失败") { [weak self] in self?.loadData() })
            }
        }
    }

    // MARK: - 操作

    @objc private func tapCreate() {
        showToast("课程创建请在 Web 工作室后台操作，App 端即将开放")
    }

    private func edit(_ course: StudioCourseItem) {
        showToast("课程编辑请在 Web 工作室后台操作，App 端即将开放")
    }

    private func preview(_ course: StudioCourseItem) {
        navigationController?.pushViewController(CourseDetailViewController(courseId: course.course_id), animated: true)
    }

    private func toggleStatus(_ course: StudioCourseItem) {
        let status = course.status ?? 1
        if status == 1 {
            // 在售 → 下架
            ThemeAlertView.show(
                title: "下架课程",
                message: "下架「\(course.title ?? "")」后，家长端将不再展示该课程，已有订单不受影响。确认下架？",
                confirmTitle: "确认下架",
                cancelTitle: "再想想",
                onConfirm: { [weak self] in self?.submitStatus(course, status: 2) }
            )
        } else if status == 2 {
            // 已下架 → 上架
            ThemeAlertView.show(
                title: "重新上架",
                message: "确认将「\(course.title ?? "")」重新上架？上架后家长端可正常浏览报名。",
                confirmTitle: "确认上架",
                cancelTitle: "取消",
                onConfirm: { [weak self] in self?.submitStatus(course, status: 1) }
            )
        }
    }

    private func submitStatus(_ course: StudioCourseItem, status: Int) {
        showLoading()
        StudioService.setCourseStatus(courseId: course.course_id, status: status) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success:
                self.showToast(status == 2 ? "已下架" : "已上架")
                self.loadData()
            case .failure(let error):
                self.showToast(error.message ?? "操作失败")
            }
        }
    }
}

extension StudioCourseListViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        courses.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: StudioCourseCell.reuseID, for: indexPath) as! StudioCourseCell
        let course = courses[indexPath.row]
        cell.configure(course)
        cell.onEdit = { [weak self] in self?.edit(course) }
        cell.onToggle = { [weak self] in self?.toggleStatus(course) }
        cell.onPreview = { [weak self] in self?.preview(course) }
        return cell
    }
}

// MARK: - 课程卡片

private final class StudioCourseCell: UITableViewCell {
    static let reuseID = "StudioCourseCell"

    var onEdit: (() -> Void)?
    var onToggle: (() -> Void)?
    var onPreview: (() -> Void)?

    private let card = UIView()
    private let coverView = UIView()
    private let coverIcon = UIImageView()
    private let coverImage = UIImageView()
    private let titleLabel = UILabel()
    private let subLabel = UILabel()
    private let priceLabel = UILabel()
    private let statusPill = PaddingLabel()
    private let divider = UIView()
    private let buttonRow = UIStackView()
    private let editBtn = StudioCourseCell.makeButton(title: "编辑", style: .plain)
    private let toggleBtn = StudioCourseCell.makeButton(title: "下架", style: .danger)
    private let previewBtn = StudioCourseCell.makeButton(title: "预览", style: .plain)

    enum BtnStyle { case plain, danger, brand }

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
        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.top.equalToSuperview().offset(6)
            $0.bottom.equalToSuperview().offset(-6)
        }

        // 封面
        coverView.layer.cornerRadius = Theme.Radius.icon
        coverView.clipsToBounds = true
        card.addSubview(coverView)
        coverView.snp.makeConstraints {
            $0.leading.top.equalToSuperview().inset(Theme.Spacing.l)
            $0.width.height.equalTo(78)
        }
        coverImage.contentMode = .scaleAspectFill
        coverImage.clipsToBounds = true
        coverView.addSubview(coverImage)
        coverImage.snp.makeConstraints { $0.edges.equalToSuperview() }
        coverIcon.contentMode = .center
        coverIcon.image = UIImage(systemName: "paintpalette.fill")
        coverIcon.tintColor = .white
        coverView.addSubview(coverIcon)
        coverIcon.snp.makeConstraints { $0.center.equalToSuperview(); $0.width.height.equalTo(30) }

        // 状态 pill（右上）
        statusPill.font = .appLabel(11)
        statusPill.layer.cornerRadius = 10
        statusPill.clipsToBounds = true
        statusPill.textInsets = UIEdgeInsets(top: 3, left: 10, bottom: 3, right: 10)
        card.addSubview(statusPill)
        statusPill.snp.makeConstraints {
            $0.top.equalTo(coverView).offset(0)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        // 标题
        titleLabel.font = .appSection(15)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 2
        card.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(coverView.snp.trailing).offset(Theme.Spacing.m)
            $0.trailing.lessThanOrEqualTo(statusPill.snp.leading).offset(-Theme.Spacing.s)
            $0.top.equalTo(coverView).offset(2)
        }

        // 副标题：老师 · 年龄 · 已售
        subLabel.font = .appLabel(12)
        subLabel.textColor = Theme.Color.muted
        subLabel.numberOfLines = 1
        card.addSubview(subLabel)
        subLabel.snp.makeConstraints {
            $0.leading.equalTo(titleLabel)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalTo(titleLabel.snp.bottom).offset(6)
        }

        // 价格
        priceLabel.font = .appSection(16)
        priceLabel.textColor = Theme.Color.ink
        card.addSubview(priceLabel)
        priceLabel.snp.makeConstraints {
            $0.leading.equalTo(titleLabel)
            $0.bottom.equalTo(coverView).offset(-2)
        }

        // 分隔线
        divider.backgroundColor = Theme.Color.line
        card.addSubview(divider)
        divider.snp.makeConstraints {
            $0.top.equalTo(coverView.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(1)
        }

        // 操作按钮
        buttonRow.axis = .horizontal
        buttonRow.distribution = .fillEqually
        buttonRow.spacing = Theme.Spacing.m
        card.addSubview(buttonRow)
        buttonRow.snp.makeConstraints {
            $0.top.equalTo(divider.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(34)
        }
        editBtn.addTarget(self, action: #selector(tapEdit), for: .touchUpInside)
        toggleBtn.addTarget(self, action: #selector(tapToggle), for: .touchUpInside)
        previewBtn.addTarget(self, action: #selector(tapPreview), for: .touchUpInside)
        buttonRow.addArrangedSubview(editBtn)
        buttonRow.addArrangedSubview(toggleBtn)
        buttonRow.addArrangedSubview(previewBtn)
    }

    func configure(_ course: StudioCourseItem) {
        // 封面
        if let urlString = course.cover, let url = URL(string: urlString) {
            coverImage.kf.setImage(with: url, placeholder: UIImage(named: "course_placeholder"))
            coverImage.isHidden = false
            coverIcon.isHidden = true
            coverView.backgroundColor = Theme.Color.surfaceAlt
        } else {
            coverImage.isHidden = true
            coverIcon.isHidden = false
            let tint = StudioCourseCoverTint(course.course_id)
            coverView.backgroundColor = tint
        }

        titleLabel.text = "\(course.title ?? "未命名课程") · \(course.lessonsText)"
        let teacher = course.hasTeacher ? course.teacherName : "未分配老师"
        subLabel.text = "\(teacher) · \(course.ageText) · \(course.salesText)"
        priceLabel.text = "\(course.priceText) / 全期"

        let status = course.status ?? 1
        switch status {
        case 0:
            statusPill.text = "审核中"
            statusPill.textColor = Theme.Color.warn
            statusPill.backgroundColor = Theme.Color.warnTint
            toggleBtn.isHidden = true
        case 2:
            statusPill.text = "已下架"
            statusPill.textColor = Theme.Color.muted
            statusPill.backgroundColor = Theme.Color.surfaceAlt
            toggleBtn.isHidden = false
            StudioCourseCell.styleButton(toggleBtn, title: "上架", style: .brand)
        default:
            statusPill.text = "在售"
            statusPill.textColor = Theme.Color.brand
            statusPill.backgroundColor = Theme.Color.brandSoft
            toggleBtn.isHidden = false
            StudioCourseCell.styleButton(toggleBtn, title: "下架", style: .danger)
        }
    }

    @objc private func tapEdit() { onEdit?() }
    @objc private func tapToggle() { onToggle?() }
    @objc private func tapPreview() { onPreview?() }

    // MARK: 按钮样式

    private static func makeButton(title: String, style: BtnStyle) -> UIButton {
        let btn = UIButton(type: .system)
        btn.titleLabel?.font = .appBody(13)
        btn.layer.cornerRadius = 17
        btn.clipsToBounds = true
        btn.layer.borderWidth = 1
        styleButton(btn, title: title, style: style)
        return btn
    }

    private static func styleButton(_ btn: UIButton, title: String, style: BtnStyle) {
        btn.setTitle(title, for: .normal)
        switch style {
        case .plain:
            btn.backgroundColor = Theme.Color.surface
            btn.setTitleColor(Theme.Color.sub, for: .normal)
            btn.layer.borderColor = Theme.Color.line.cgColor
        case .danger:
            btn.backgroundColor = Theme.Color.surface
            btn.setTitleColor(Theme.Color.danger, for: .normal)
            btn.layer.borderColor = Theme.Color.danger.cgColor
        case .brand:
            btn.backgroundColor = Theme.Color.surface
            btn.setTitleColor(Theme.Color.brand, for: .normal)
            btn.layer.borderColor = Theme.Color.brand.cgColor
        }
    }
}

/// 无封面时按课程 id 稳定取一个主题色块（绿 / 金 / 蓝）
private func StudioCourseCoverTint(_ id: String) -> UIColor {
    let palette = [Theme.Color.brand, Theme.Color.wood, Theme.Color.clay]
    var hash = 0
    for u in id.unicodeScalars { hash = (hash &* 31) &+ Int(u.value) }
    return palette[abs(hash) % palette.count]
}
