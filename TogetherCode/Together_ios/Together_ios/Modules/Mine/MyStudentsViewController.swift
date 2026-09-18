import UIKit
import SnapKit

/// 我的学生：班级筛选 + 学生列表（参考 PR：#myStudents；请假审批已拆分为 LeaveApprovalViewController）
final class MyStudentsViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let classChipRow = TagChipRow(chips: ["全部班级"])

    private var classes: [TeacherStudentClassSummary] = []
    private var students: [TeacherStudentRow] = []
    private var selectedClassIndex = 0
    private var loading = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        configureImmersiveNav(title: "我的学生")
        setupUI()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "我的学生")
        if !students.isEmpty { loadData(classId: selectedClassId) }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    private func setupUI() {
        // 筛选区（固定在导航下）
        let filterWrap = UIView()
        filterWrap.backgroundColor = Theme.Color.bg
        view.addSubview(filterWrap)
        filterWrap.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
        }

        classChipRow.onSelect = { [weak self] index in
            guard let self else { return }
            self.selectedClassIndex = index
            self.loadData(classId: self.selectedClassId)
        }
        filterWrap.addSubview(classChipRow)
        classChipRow.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(34)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.s)
        }

        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.register(StudentRowCell.self, forCellReuseIdentifier: StudentRowCell.reuseID)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.estimatedRowHeight = 100
        tableView.rowHeight = UITableView.automaticDimension
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(filterWrap.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    private var selectedClassId: String? {
        guard selectedClassIndex > 0, selectedClassIndex - 1 < classes.count else { return nil }
        return classes[selectedClassIndex - 1].class_id
    }

    private func loadData(classId: String? = nil) {
        guard !loading else { return }
        loading = true
        TeacherService.fetchStudents(classId: classId) { [weak self] result in
            guard let self else { return }
            self.loading = false
            switch result {
            case .success(let data):
                self.classes = data.classes ?? []
                self.students = data.list ?? []
                var classChips = ["全部班级"]
                classChips += self.classes.map { $0.displayName }
                self.classChipRow.update(chips: classChips, selectedIndex: self.selectedClassIndex)
                self.tableView.reloadData()
            case .failure(let error):
                self.showToast(error.message ?? "加载失败")
            }
        }
    }

    // MARK: - TableView

    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        students.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: StudentRowCell.reuseID, for: indexPath) as! StudentRowCell
        cell.configure(students[indexPath.row])
        return cell
    }
}

// MARK: - 学生行

private final class StudentRowCell: UITableViewCell {

    static let reuseID = "StudentRowCell"

    private let container = UIView()
    private let avatarView = UIView()
    private let avatarLabel = UILabel()
    private let nameLabel = UILabel()
    private let courseLabel = UILabel()
    private let remainingLabel = UILabel()
    private let badgeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.bg
        selectionStyle = .none

        container.backgroundColor = Theme.Color.surface
        container.layer.cornerRadius = Theme.Radius.card
        contentView.addSubview(container)
        container.snp.makeConstraints {
            $0.top.equalToSuperview().offset(4)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().inset(4)
        }

        avatarView.backgroundColor = Theme.Color.surfaceAlt
        avatarView.layer.cornerRadius = 24
        avatarView.clipsToBounds = true
        container.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(48)
        }

        avatarLabel.font = .appBody(16)
        avatarLabel.textColor = Theme.Color.wood
        avatarLabel.textAlignment = .center
        avatarView.addSubview(avatarLabel)
        avatarLabel.snp.makeConstraints { $0.edges.equalToSuperview() }

        nameLabel.font = .appBody(15)
        nameLabel.textColor = Theme.Color.ink
        container.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarView.snp.trailing).offset(Theme.Spacing.m)
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
        }

        courseLabel.font = .appBody(12)
        courseLabel.textColor = Theme.Color.muted
        courseLabel.numberOfLines = 2
        container.addSubview(courseLabel)
        courseLabel.snp.makeConstraints {
            $0.leading.equalTo(nameLabel)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalTo(nameLabel.snp.bottom).offset(4)
        }

        remainingLabel.font = .appBody(12)
        remainingLabel.textColor = Theme.Color.muted
        container.addSubview(remainingLabel)
        remainingLabel.snp.makeConstraints {
            $0.leading.equalTo(nameLabel)
            $0.top.equalTo(courseLabel.snp.bottom).offset(4)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }

        badgeLabel.font = .appLabel(11)
        badgeLabel.textColor = Theme.Color.brand
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 10
        badgeLabel.clipsToBounds = true
        container.addSubview(badgeLabel)
        badgeLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalTo(container).offset(-8)
            $0.height.equalTo(20)
            $0.width.greaterThanOrEqualTo(44)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ student: TeacherStudentRow) {
        nameLabel.text = student.ageText.isEmpty ? student.name : "\(student.name) \(student.ageText)"
        let course = student.primaryCourse
        courseLabel.text = [course?.title, course?.class_name].compactMap { $0 }.joined(separator: "·")
        let remaining = course?.remaining ?? 0
        remainingLabel.text = "剩余课时\(remaining)节" + (remaining <= 2 ? "·建议提醒续费" : "")

        if student.isLeaving {
            badgeLabel.text = "请假中"
            badgeLabel.textColor = Theme.Color.clay
            badgeLabel.backgroundColor = Theme.Color.warnTint
        } else if student.todayScheduled {
            badgeLabel.text = "今日上课"
            badgeLabel.textColor = .white
            badgeLabel.backgroundColor = Theme.Color.brand
        } else {
            badgeLabel.text = ""
            badgeLabel.backgroundColor = .clear
        }
        avatarLabel.text = String(student.name.prefix(1))
    }
}
