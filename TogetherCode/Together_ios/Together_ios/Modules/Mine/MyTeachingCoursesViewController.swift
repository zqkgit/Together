import UIKit
import SnapKit

/// 我教的课程：按课程卡片展示（班级人数 + 进度 + 查看课表/班级学生/发作品消课）
final class MyTeachingCoursesViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var items: [TeacherCourseItem] = []
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
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.register(MyTeachingCourseCell.self, forCellReuseIdentifier: "MyTeachingCourseCell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 180
        view.addSubview(tableView)
        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    private func loadData() {
        guard !loading else { return }
        loading = true
        TeacherService.fetchCourses { [weak self] result in
            guard let self else { return }
            self.loading = false
            switch result {
            case .success(let list):
                self.items = list
                self.tableView.reloadData()
            case .failure(let error):
                self.showToast(error.message ?? "加载失败")
            }
        }
    }

    // MARK: - TableView

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MyTeachingCourseCell", for: indexPath) as! MyTeachingCourseCell
        let item = items[indexPath.row]
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

    /// 班级学生：多班弹选择，单班直接进
    private func openClassStudents(_ item: TeacherCourseItem) {
        guard let classes = item.classes, !classes.isEmpty else {
            showToast("暂无班级")
            return
        }
        let go: (TeacherCourseClassItem) -> Void = { [weak self] cls in
            guard let self else { return }
            let vc = ClassStudentsViewController(classId: cls.class_id ?? "", className: cls.name ?? "")
            self.navigationController?.pushViewController(vc, animated: true)
        }
        if classes.count == 1, let cls = classes.first {
            go(cls)
            return
        }
        let sheet = ThemeActionSheet(title: "选择班级", actions: classes.map { ($0.name ?? "班级", false) })
        sheet.onSelect = { [weak self] index in
            guard index < classes.count else { return }
            go(classes[index])
        }
        present(sheet, animated: false)
    }

    /// 发作品消课：进入老师发布（孩子作品类型）
    private func openPublishConsume(_ item: TeacherCourseItem) {
        let vc = TeacherPostCreateViewController(postType: 2)
        let publish = BaseNavigationController(rootViewController: vc)
        publish.modalPresentationStyle = .fullScreen
        present(publish, animated: true)
    }
}
