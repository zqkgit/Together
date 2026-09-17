import UIKit
import SnapKit

/// 我的学生：班级/状态筛选 + 待处理请假卡 + 学生列表（参考 PR：#myStudents）
final class MyStudentsViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {

    private enum StatusFilter: Int, CaseIterable {
        case all = 0, lowLessons, today, leaving
        var title: String {
            switch self {
            case .all: return "全部"
            case .lowLessons: return "课时不足"
            case .today: return "今日上课"
            case .leaving: return "请假中"
            }
        }
    }

    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let classChipRow = TagChipRow(chips: ["全部班级"])
    private let statusChipRow = TagChipRow(chips: StatusFilter.allCases.map { $0.title })

    private var classes: [TeacherStudentClassSummary] = []
    private var allStudents: [TeacherStudentRow] = []
    private var leaves: [TeacherLeaveItem] = []
    private var selectedClassIndex = 0
    private var selectedStatusIndex = 0
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
        if !allStudents.isEmpty { loadData() }
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
            self?.selectedClassIndex = index
            self?.tableView.reloadData()
        }
        filterWrap.addSubview(classChipRow)
        classChipRow.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(34)
        }

        statusChipRow.onSelect = { [weak self] index in
            self?.selectedStatusIndex = index
            self?.tableView.reloadData()
        }
        filterWrap.addSubview(statusChipRow)
        statusChipRow.snp.makeConstraints {
            $0.top.equalTo(classChipRow.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(34)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.s)
        }

        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.register(LeaveRequestCell.self, forCellReuseIdentifier: LeaveRequestCell.reuseID)
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

    private func loadData() {
        guard !loading else { return }
        loading = true
        let group = DispatchGroup()
        var studentsData: TeacherStudentListData?
        var leaveData: [TeacherLeaveItem] = []

        group.enter()
        TeacherService.fetchStudents { result in
            defer { group.leave() }
            if case .success(let data) = result { studentsData = data }
        }
        group.enter()
        TeacherService.fetchPendingLeaves { result in
            defer { group.leave() }
            if case .success(let list) = result { leaveData = list }
        }
        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.loading = false
            self.classes = studentsData?.classes ?? []
            self.allStudents = studentsData?.list ?? []
            self.leaves = leaveData
            var classChips = ["全部班级"]
            classChips += self.classes.map { $0.name ?? "班级" }
            self.classChipRow.update(chips: classChips, selectedIndex: self.selectedClassIndex)
            self.tableView.reloadData()
        }
    }

    // MARK: - 过滤

    private var filteredStudents: [TeacherStudentRow] {
        var list = allStudents
        if selectedClassIndex > 0 {
            let classId = classes[selectedClassIndex - 1].class_id
            list = list.filter { $0.primaryCourse?.class_id == classId }
        }
        switch StatusFilter(rawValue: selectedStatusIndex) ?? .all {
        case .all:
            break
        case .lowLessons:
            list = list.filter { $0.lowLessons }
        case .today:
            list = list.filter { $0.todayScheduled }
        case .leaving:
            list = list.filter { $0.isLeaving }
        }
        return list
    }

    // MARK: - TableView

    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? leaves.count : filteredStudents.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard section == 0, !leaves.isEmpty else { return nil }
        let label = UILabel()
        label.font = .appSection(14)
        label.textColor = Theme.Color.ink
        label.text = "请假申请"
        label.frame = CGRect(x: Theme.Spacing.l, y: 8, width: 300, height: 24)
        let wrap = UIView()
        wrap.backgroundColor = .clear
        wrap.addSubview(label)
        return wrap
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 && !leaves.isEmpty ? 40 : (section == 1 ? 8 : 0)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: LeaveRequestCell.reuseID, for: indexPath) as! LeaveRequestCell
            let leave = leaves[indexPath.row]
            cell.configure(leave)
            cell.onAgree = { [weak self] in self?.review(leave, action: "agree", title: "同意请假", message: "同意后该节次保留课时，不再消课。") }
            cell.onReject = { [weak self] in self?.review(leave, action: "reject", title: "婉拒请假", message: "婉拒后该节次按正常出勤处理（如需消课请到课表操作）。") }
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: StudentRowCell.reuseID, for: indexPath) as! StudentRowCell
        cell.configure(filteredStudents[indexPath.row])
        return cell
    }

    // MARK: - 审批

    private func review(_ leave: TeacherLeaveItem, action: String, title: String, message: String) {
        ThemeAlertView.show(
            title: title,
            message: message,
            confirmTitle: "确认",
            onConfirm: { [weak self] in
                guard let self, let leaveId = leave.leave_id else { return }
                self.showLoading()
                TeacherService.reviewLeave(leaveId: leaveId, action: action) { [weak self] result in
                    guard let self else { return }
                    self.hideLoading()
                    switch result {
                    case .success:
                        self.showToast(action == "agree" ? "已同意，课时保留" : "已婉拒")
                        self.loadData()
                    case .failure(let error):
                        self.showToast(error.message ?? "操作失败")
                    }
                }
            }
        )
    }
}

// MARK: - 请假申请卡

final class LeaveRequestCell: UITableViewCell {

    static let reuseID = "LeaveRequestCell"
    var onAgree: (() -> Void)?
    var onReject: (() -> Void)?

    private let container = UIView()
    private let titleLabel = UILabel()
    private let infoLabel = UILabel()
    private let reasonLabel = UILabel()
    private let rejectButton = UIButton(type: .system)
    private let agreeButton = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.bg
        selectionStyle = .none

        container.backgroundColor = Theme.Color.surface
        container.layer.cornerRadius = Theme.Radius.card
        container.layer.borderWidth = 1
        container.layer.borderColor = Theme.Color.warnTint.cgColor
        contentView.addSubview(container)
        container.snp.makeConstraints {
            $0.top.equalToSuperview().offset(4)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().inset(4)
        }

        titleLabel.font = .appBody(14)
        titleLabel.textColor = Theme.Color.ink
        container.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        infoLabel.font = .appBody(12)
        infoLabel.textColor = Theme.Color.muted
        infoLabel.numberOfLines = 2
        container.addSubview(infoLabel)
        infoLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(4)
            $0.leading.trailing.equalTo(titleLabel)
        }

        reasonLabel.font = .appBody(13)
        reasonLabel.textColor = Theme.Color.ink
        reasonLabel.numberOfLines = 3
        container.addSubview(reasonLabel)
        reasonLabel.snp.makeConstraints {
            $0.top.equalTo(infoLabel.snp.bottom).offset(6)
            $0.leading.trailing.equalTo(titleLabel)
        }

        let divider = UIView()
        divider.backgroundColor = Theme.Color.line
        container.addSubview(divider)
        divider.snp.makeConstraints {
            $0.top.equalTo(reasonLabel.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalTo(titleLabel)
            $0.height.equalTo(0.5)
        }

        rejectButton.setTitle("婉拒并私聊", for: .normal)
        rejectButton.titleLabel?.font = .appBody(13)
        rejectButton.setTitleColor(Theme.Color.clay, for: .normal)
        rejectButton.layer.borderWidth = 1
        rejectButton.layer.borderColor = Theme.Color.line.cgColor
        rejectButton.layer.cornerRadius = 17
        rejectButton.addTarget(self, action: #selector(didTapReject), for: .touchUpInside)

        agreeButton.setTitle("同意·课时保留", for: .normal)
        agreeButton.titleLabel?.font = .appBody(13)
        agreeButton.setTitleColor(.white, for: .normal)
        agreeButton.backgroundColor = Theme.Color.brand
        agreeButton.layer.cornerRadius = 17
        agreeButton.addTarget(self, action: #selector(didTapAgree), for: .touchUpInside)

        container.addSubview(rejectButton)
        container.addSubview(agreeButton)
        rejectButton.snp.makeConstraints {
            $0.top.equalTo(divider.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.equalTo(titleLabel)
            $0.width.equalTo(120)
            $0.height.equalTo(34)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.m)
        }
        agreeButton.snp.makeConstraints {
            $0.top.equalTo(rejectButton)
            $0.leading.equalTo(rejectButton.snp.trailing).offset(Theme.Spacing.m)
            $0.width.equalTo(rejectButton)
            $0.height.equalTo(rejectButton)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ leave: TeacherLeaveItem) {
        titleLabel.text = "\(leave.child?.nickname ?? "孩子") 家长申请请假"
        infoLabel.text = leave.infoText
        reasonLabel.text = "“\(leave.reason ?? "")”"
    }

    @objc private func didTapReject() { onReject?() }
    @objc private func didTapAgree() { onAgree?() }
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
