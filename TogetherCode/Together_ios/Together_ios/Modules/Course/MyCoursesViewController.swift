import UIKit
import SnapKit
import ESPullToRefresh

/// 我的课程（家长端：孩子已购课程 + 进度 + 下一节课）
/// PR 设计：课程卡片列表（名称/机构·老师/下次课/进度条/节数占比）
/// childId 为空时展示所有孩子的课程，顶部可按孩子筛选
final class MyCoursesViewController: BaseViewController {

    private let childId: String?
    private let childName: String?

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var allItems: [MyCourseItem] = []
    private var filteredItems: [MyCourseItem] = []
    private var childBriefs: [ChildBrief] = []
    private var selectedChildId: String?   // nil = 全部

    private var chipRow: TagChipRow?
    private let emptyView = EmptyStateView()

    init(childId: String?, childName: String?) {
        self.childId = childId
        self.childName = childName
        super.init(nibName: nil, bundle: nil)
    }
    convenience init() {
        self.init(childId: nil, childName: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureImmersiveNav(title: "我的课程")
        setupUI()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !allItems.isEmpty { loadData() }
    }

    private func setupUI() {
        view.backgroundColor = Theme.Color.bg
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(MyCourseCell.self, forCellReuseIdentifier: "MyCourseCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 140
        // 参考广场：下拉刷新
        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.reload()
        }

        let isMulti = childId == nil || childId?.isEmpty == true
        if isMulti {
            // 筛选条固定在导航栏下方，不随内容滚动（对齐广场 chipRow）
            let chipRow = TagChipRow(chips: [])
            chipRow.onSelect = { [weak self] index in
                guard let self else { return }
                self.selectedChildId = index == 0 ? nil : self.childBriefs[safe: index - 1]?.id
                self.applyFilter()
                self.tableView.reloadData()
                self.updateEmptyState()
            }
            view.addSubview(chipRow)
            chipRow.snp.makeConstraints {
                $0.top.equalTo(view.safeAreaLayoutGuide).offset(Theme.Spacing.m)
                $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
                $0.height.equalTo(34)
            }
            self.chipRow = chipRow

            view.addSubview(tableView)
            tableView.snp.makeConstraints {
                $0.top.equalTo(chipRow.snp.bottom).offset(Theme.Spacing.s)
                $0.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide)
            }
        } else {
            view.addSubview(tableView)
            tableView.snp.makeConstraints { $0.edges.equalTo(view.safeAreaLayoutGuide) }
        }

        emptyView.isHidden = true
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints { $0.center.equalToSuperview() }
    }

    private func loadData() {
        emptyView.show(style: .loading)
        CourseService.fetchMyCourses(childId: childId) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let (children, items)):
                self.childBriefs = children
                self.allItems = items
                self.fillChipRow()
                self.applyFilter()
                self.tableView.reloadData()
                self.tableView.es.stopPullToRefresh()
                self.updateEmptyState()
            case .failure(let error):
                self.tableView.es.stopPullToRefresh()
                self.emptyView.show(style: .error(error.message) { [weak self] in
                    self?.loadData()
                })
            }
        }
    }

    /// 下拉刷新：重新拉取全部数据（对齐广场 reload）
    private func reload() {
        loadData()
    }

    private func updateEmptyState() {
        let isEmpty = filteredItems.isEmpty
        emptyView.isHidden = !isEmpty
        if isEmpty {
            let name = childName ?? "孩子"
            emptyView.show(style: .empty("\(name)还没有报名课程"))
        }
    }

    // MARK: - 孩子筛选

    private func applyFilter() {
        if let childId, !childId.isEmpty {
            filteredItems = allItems.filter { $0.child_id == childId }
            return
        }
        if let selectedChildId {
            filteredItems = allItems.filter { $0.child_id == selectedChildId }
        } else {
            filteredItems = allItems
        }
    }

    /// 全部孩子的 id 列表（来自后端 children，含无课孩子）
    private var distinctChildIds: [String] {
        childBriefs.map { $0.id }.filter { !$0.isEmpty }
    }

    /// 数据回来后填充筛选 chips（仅多孩子模式）
    private func fillChipRow() {
        guard let chipRow, childId == nil || childId?.isEmpty == true else { return }
        let chips = ["全部"] + childBriefs.filter { !$0.id.isEmpty }.map(\.name)
        chipRow.update(chips: chips, selectedIndex: 0)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension MyCoursesViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MyCourseCell", for: indexPath) as! MyCourseCell
        cell.configure(filteredItems[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = filteredItems[indexPath.row]
        let vc = CourseStudyViewController(
            childId: item.child_id ?? "",
            courseId: item.course_id,
            courseTitle: item.course_title ?? "课程学习"
        )
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - 课程卡片 Cell

final class MyCourseCell: UITableViewCell {

    private let card = UIView()
    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    private let studioLabel = UILabel()
    private let nextLabel = UILabel()
    private let progressTrack = UIView()
    private let progressFill = UIView()
    private let percentLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(card)
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        card.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        card.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.lessThanOrEqualToSuperview().inset(Theme.Spacing.l)
        }

        // 行1：课程名 + 节数
        titleLabel.font = .appSection(17)
        titleLabel.textColor = Theme.Color.ink
        countLabel.font = .appLabel(13)
        countLabel.textColor = Theme.Color.sub
        countLabel.setContentHuggingPriority(.required, for: .horizontal)
        let row1 = UIStackView(arrangedSubviews: [titleLabel, countLabel])
        row1.spacing = Theme.Spacing.m

        studioLabel.font = .appLabel(13)
        studioLabel.textColor = Theme.Color.sub

        nextLabel.font = .appLabel(13)
        nextLabel.textColor = Theme.Color.brand

        [row1, studioLabel, nextLabel].forEach(stack.addArrangedSubview)

        // 行4：进度条 + 百分比（手动约束，避免 stack 压缩导致文字截断）
        progressTrack.backgroundColor = Theme.Color.surfaceAlt
        progressTrack.layer.cornerRadius = 3
        progressTrack.layer.masksToBounds = true
        progressFill.backgroundColor = Theme.Color.brand
        progressFill.layer.cornerRadius = 3
        progressTrack.addSubview(progressFill)
        progressFill.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
            $0.width.equalToSuperview().multipliedBy(0)
        }
        percentLabel.font = .appLabel(12)
        percentLabel.textColor = Theme.Color.sub
        percentLabel.textAlignment = .right
        card.addSubview(percentLabel)
        percentLabel.snp.makeConstraints {
            $0.top.equalTo(nextLabel.snp.bottom).offset(10)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.width.equalTo(64)
            $0.height.equalTo(20)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
        card.addSubview(progressTrack)
        progressTrack.snp.makeConstraints {
            $0.centerY.equalTo(percentLabel)
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.trailing.equalTo(percentLabel.snp.leading).offset(-Theme.Spacing.m)
            $0.height.equalTo(6)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ item: MyCourseItem) {
        titleLabel.text = item.course_title ?? "未命名课程"
        countLabel.text = "\(item.consumed_lessons)/\(item.total_lessons)节"
        studioLabel.text = item.studioTeacherText
        nextLabel.text = item.nextLessonText
        let percent = min(max(item.percent, 0), 100)
        percentLabel.text = "已学\(percent)%"
        progressFill.snp.remakeConstraints {
            $0.leading.top.bottom.equalToSuperview()
            $0.width.equalToSuperview().multipliedBy(Double(percent) / 100.0)
        }
    }
}
