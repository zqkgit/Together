import UIKit
import SnapKit

/// 我教的课程：顶部工作室筛选 + 课程卡片（班级人数 + 进度 + 查看课表/查看班级/发作品消课）
final class MyTeachingCoursesViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let studioChipRow = TagChipRow(chips: ["全部工作室"])

    private var allItems: [TeacherCourseItem] = []
    private var filteredItems: [TeacherCourseItem] = []
    private var studios: [(id: String, name: String)] = []
    private var selectedStudioIndex = 0
    private var loading = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        configureImmersiveNav(title: "我教的课程")
        setupLayout()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "我教的课程")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    private func setupLayout() {
        // 工作室筛选区
        let filterWrap = UIView()
        filterWrap.backgroundColor = Theme.Color.bg
        view.addSubview(filterWrap)
        filterWrap.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
        }

        studioChipRow.onSelect = { [weak self] index in
            guard let self else { return }
            self.selectedStudioIndex = index
            self.applyFilter()
        }
        filterWrap.addSubview(studioChipRow)
        studioChipRow.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.s)
            $0.leading.equalToSuperview().offset(Theme.Spacing.m)
            $0.trailing.equalToSuperview()
            $0.height.equalTo(34)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.xs)
        }

        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.register(MyTeachingCourseCell.self, forCellReuseIdentifier: "MyTeachingCourseCell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 180
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(filterWrap.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func loadData() {
        guard !loading else { return }
        loading = true
        TeacherService.fetchCourses { [weak self] result in
            guard let self else { return }
            self.loading = false
            switch result {
            case .success(let list):
                self.allItems = list
                self.buildStudioChips()
                self.applyFilter()
            case .failure(let error):
                self.showToast(error.message ?? "加载失败")
            }
        }
    }

    /// 从课程数据中提取去重的工作室列表
    private func buildStudioChips() {
        var seen = [String: String]()  // id -> name
        for item in allItems {
            if let sid = item.studio_id, !sid.isEmpty, let name = item.studio_name, !name.isEmpty {
                seen[sid] = name
            }
        }
        studios = seen.map { (id: $0.key, name: $0.value) }
        studios.sort { $0.name < $1.name }

        var chips = ["全部工作室"]
        chips += studios.map { $0.name }
        studioChipRow.update(chips: chips, selectedIndex: 0)
        selectedStudioIndex = 0
    }

    private var selectedStudioId: String? {
        guard selectedStudioIndex > 0, selectedStudioIndex - 1 < studios.count else { return nil }
        return studios[selectedStudioIndex - 1].id
    }

    private func applyFilter() {
        if let sid = selectedStudioId {
            filteredItems = allItems.filter { $0.studio_id == sid }
        } else {
            filteredItems = allItems
        }
        tableView.reloadData()
    }

    // MARK: - TableView

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filteredItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MyTeachingCourseCell", for: indexPath) as! MyTeachingCourseCell
        let item = filteredItems[indexPath.row]
        cell.configure(item)
        cell.onViewTimetable = { [weak self] in
            self?.navigationController?.pushViewController(TeacherTimetableViewController(), animated: true)
        }
        cell.onViewStudents = { [weak self] in
            self?.openClassStudents(item)
        }
        cell.onPublishConsume = { [weak self] in
            self?.openPublishConsume(item)
        }
        return cell
    }

    // MARK: - 操作

    /// 查看班级：进入班级列表，班级下有学生
    private func openClassStudents(_ item: TeacherCourseItem) {
        guard let classes = item.classes, !classes.isEmpty else {
            showToast("暂无班级")
            return
        }
        let vc = ClassListViewController(courseTitle: item.title ?? "", classes: classes)
        navigationController?.pushViewController(vc, animated: true)
    }

    /// 发作品消课：进入老师发布（孩子作品类型）
    private func openPublishConsume(_ item: TeacherCourseItem) {
        let vc = TeacherPostCreateViewController(postType: 2)
        let publish = BaseNavigationController(rootViewController: vc)
        publish.modalPresentationStyle = .fullScreen
        present(publish, animated: true)
    }
}