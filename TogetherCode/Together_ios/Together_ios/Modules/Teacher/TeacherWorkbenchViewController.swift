import UIKit
import SnapKit

/// 老师工作台（对齐 PR：#teacherWorkbench）
/// 顶部数据卡（今日待消课 / 在读学生 / 本月出勤）+ 今日课程列表（学员勾选 → 一键点名消课）
final class TeacherWorkbenchViewController: BaseViewController {

    // MARK: - 状态

    private var workbench: TeacherWorkbench?
    /// 每节课已勾选的学员（child_id 集合）
    private var selectedBySchedule: [String: Set<String>] = [:]
    private var submitting = false

    // MARK: - UI

    private let statsView = WorkbenchStatsView()
    private let listHeaderView = UIView()
    private let listTitleLabel = UILabel()
    private let timetableButton = UIButton(type: .system)
    private let tableView = UITableView(frame: .zero, style: .plain)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "工作台"
        view.backgroundColor = Theme.Color.bg
        setupUI()
        loadData()
    }

    private func setupUI() {
        view.addSubview(statsView)
        statsView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }

        // 「今日课程」标题 + 右侧「课表」入口（对齐 PR #teacherWorkbench）
        listTitleLabel.font = .appBody(17)
        listTitleLabel.textColor = Theme.Color.ink
        listTitleLabel.text = "今日课程"
        listHeaderView.addSubview(listTitleLabel)
        listTitleLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
        }

        timetableButton.titleLabel?.font = .appBody(13)
        timetableButton.setTitle("课表", for: .normal)
        timetableButton.setTitleColor(Theme.Color.brand, for: .normal)
        let chevron = UIImage(
            systemName: "chevron.right",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        )
        timetableButton.setImage(chevron, for: .normal)
        timetableButton.tintColor = Theme.Color.brand
        timetableButton.semanticContentAttribute = .forceRightToLeft
        timetableButton.addTarget(self, action: #selector(didTapTimetable), for: .touchUpInside)
        listHeaderView.addSubview(timetableButton)
        timetableButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
        }

        view.addSubview(listHeaderView)
        listHeaderView.snp.makeConstraints {
            $0.top.equalTo(statsView.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(40)
        }

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(WorkbenchScheduleCell.self, forCellReuseIdentifier: "ScheduleCell")
        tableView.register(WorkbenchEmptyCell.self, forCellReuseIdentifier: "EmptyCell")
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(listHeaderView.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    // MARK: - 数据

    private func loadData() {
        showLoading()
        TeacherService.fetchWorkbench { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success(let data):
                self.workbench = data
                self.selectedBySchedule = [:]
                self.statsView.configure(data.stats)
                self.tableView.reloadData()
            case .failure(let error):
                self.showToast(error.message)
            }
        }
    }

    @objc private func didTapTimetable() {
        navigationController?.pushViewController(TeacherTimetableViewController(), animated: true)
    }

    // MARK: - 点名

    private func schedules() -> [TeacherWorkbenchSchedule] {
        workbench?.today ?? []
    }

    private func selectedIds(for scheduleId: String) -> Set<String> {
        selectedBySchedule[scheduleId] ?? []
    }

    private func toggleStudent(scheduleId: String, childId: String) {
        var set = selectedBySchedule[scheduleId] ?? []
        if set.contains(childId) {
            set.remove(childId)
        } else {
            set.insert(childId)
        }
        selectedBySchedule[scheduleId] = set
        if let index = schedules().firstIndex(where: { $0.schedule_id == scheduleId }) {
            tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
        }
    }

    private func submitAttendance(schedule: TeacherWorkbenchSchedule) {
        let ids = Array(selectedIds(for: schedule.schedule_id))
        guard !ids.isEmpty, !submitting else { return }
        submitting = true
        TeacherService.submitAttendance(
            scheduleId: schedule.schedule_id,
            childIds: ids,
            note: "老师工作台点名消课"
        ) { [weak self] result in
            guard let self else { return }
            self.submitting = false
            switch result {
            case .success:
                self.showToast("已消课 \(ids.count) 名学员")
                self.loadData()
            case .failure(let error):
                self.showToast(error.message)
            }
        }
    }
}

// MARK: - TableView

extension TeacherWorkbenchViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let list = schedules()
        return list.isEmpty ? 1 : list.count
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if schedules().isEmpty { return 180 }
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let list = schedules()
        if list.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: "EmptyCell", for: indexPath) as! WorkbenchEmptyCell
            return cell
        }
        let schedule = list[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "ScheduleCell", for: indexPath) as! WorkbenchScheduleCell
        cell.configure(
            schedule: schedule,
            selectedIds: selectedIds(for: schedule.schedule_id),
            onToggleStudent: { [weak self] childId in
                self?.toggleStudent(scheduleId: schedule.schedule_id, childId: childId)
            },
            onUndoStudent: { [weak self] childId in
                self?.confirmUndo(schedule: schedule, childId: childId)
            },
            onSubmit: { [weak self] in
                self?.submitAttendance(schedule: schedule)
            }
        )
        return cell
    }

    // MARK: - 撤销点名

    private func confirmUndo(schedule: TeacherWorkbenchSchedule, childId: String) {
        let student = (schedule.students ?? []).first { $0.child_id == childId }
        let name = student?.name ?? "该学员"
        let isPostSource = student?.consumeSource == 1
        let message = isPostSource
            ? "\(name) 是通过老师发帖自动消课的。撤销将退还课时，并同步取消帖子中的消课记录，确认撤销？"
            : "撤销 \(name) 的本节消课？课时将自动退还。"
        ThemeAlertView.show(
            title: "撤销消课",
            message: message,
            confirmTitle: "撤销",
            onConfirm: { [weak self] in
                self?.undoAttendance(schedule: schedule, childId: childId, isPostSource: isPostSource)
            }
        )
    }

    private func undoAttendance(schedule: TeacherWorkbenchSchedule, childId: String, isPostSource: Bool) {
        showLoading()
        TeacherService.undoAttendance(scheduleId: schedule.schedule_id, childIds: [childId]) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success:
                self.showToast(isPostSource ? "已撤销，课时已退还，帖子消课记录已取消" : "已撤销消课，课时已退还")
                self.loadData()
            case .failure(let error):
                self.showToast(error.message)
            }
        }
    }
}

// MARK: - 顶部数据卡

final class WorkbenchStatsView: UIView {

    private let pendingCard = StatsCardView()
    private let studentsCard = StatsCardView()
    private let rateCard = StatsCardView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        let row = UIStackView(arrangedSubviews: [pendingCard, studentsCard, rateCard])
        row.axis = .horizontal
        row.spacing = Theme.Spacing.m
        row.distribution = .fillEqually
        addSubview(row)
        row.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    func configure(_ stats: TeacherWorkbenchStats?) {
        pendingCard.configure(value: "\(stats?.todayPending ?? 0)", title: "今日待消课", accent: Theme.Color.clay)
        studentsCard.configure(value: "\(stats?.activeStudents ?? 0)", title: "在读学生", accent: Theme.Color.brand)
        rateCard.configure(value: "\(stats?.attendanceRate ?? 0)%", title: "本月出勤", accent: Theme.Color.wood)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class StatsCardView: UIView {

    private let valueLabel = UILabel()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.Color.surface
        layer.cornerRadius = Theme.Radius.card
        layer.shadowColor = Theme.Shadow.card.color.cgColor
        layer.shadowOffset = Theme.Shadow.card.offset
        layer.shadowRadius = Theme.Shadow.card.radius
        layer.shadowOpacity = Theme.Shadow.card.opacity

        valueLabel.font = .appHero(26)
        valueLabel.textColor = Theme.Color.ink
        addSubview(valueLabel)
        valueLabel.snp.makeConstraints {
            $0.top.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerX.equalToSuperview()
        }

        titleLabel.font = .appLabel(12)
        titleLabel.textColor = Theme.Color.muted
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(valueLabel.snp.bottom).offset(Theme.Spacing.xs)
            $0.centerX.equalToSuperview()
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    func configure(value: String, title: String, accent: UIColor) {
        valueLabel.text = value
        valueLabel.textColor = accent
        titleLabel.text = title
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 今日课程卡（含学员点名）

final class WorkbenchScheduleCell: UITableViewCell {

    private let container = UIView()
    private let timeLabel = UILabel()
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let lineView = UIView()
    private let studentsStack = UIStackView()
    private let submitButton = UIButton(type: .system)

    private var studentRows: [WorkbenchStudentRowView] = []
    private var onSubmit: (() -> Void)?
    private var onUndoStudent: ((String) -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        container.backgroundColor = Theme.Color.surface
        container.layer.cornerRadius = Theme.Radius.card
        container.layer.shadowColor = Theme.Shadow.card.color.cgColor
        container.layer.shadowOffset = Theme.Shadow.card.offset
        container.layer.shadowRadius = Theme.Shadow.card.radius
        container.layer.shadowOpacity = Theme.Shadow.card.opacity
        contentView.addSubview(container)
        container.snp.makeConstraints {
            $0.top.equalToSuperview().inset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.s)
        }

        timeLabel.font = .appBody(13)
        timeLabel.textColor = Theme.Color.clay
        container.addSubview(timeLabel)
        timeLabel.snp.makeConstraints {
            $0.top.equalToSuperview().inset(Theme.Spacing.m)
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
        }

        titleLabel.font = .appBody(15)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 2
        container.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(timeLabel.snp.bottom).offset(Theme.Spacing.xs)
            $0.leading.equalTo(timeLabel)
            $0.trailing.lessThanOrEqualToSuperview().inset(96)
        }

        statusLabel.font = .appLabel(11)
        statusLabel.textColor = Theme.Color.clay
        statusLabel.layer.cornerRadius = 8
        statusLabel.layer.masksToBounds = true
        statusLabel.textAlignment = .center
        container.addSubview(statusLabel)
        statusLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalTo(titleLabel)
            $0.width.greaterThanOrEqualTo(52)
            $0.height.equalTo(22)
        }

        lineView.backgroundColor = Theme.Color.line
        container.addSubview(lineView)
        lineView.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(1)
        }

        studentsStack.axis = .vertical
        studentsStack.spacing = 0
        container.addSubview(studentsStack)
        studentsStack.snp.makeConstraints {
            $0.top.equalTo(lineView.snp.bottom)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        submitButton.titleLabel?.font = .appBody(14)
        submitButton.backgroundColor = Theme.Color.brand
        submitButton.layer.cornerRadius = Theme.Radius.button
        submitButton.addTarget(self, action: #selector(didTapSubmit), for: .touchUpInside)
        container.addSubview(submitButton)
        submitButton.snp.makeConstraints {
            $0.top.equalTo(studentsStack.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.m)
            $0.height.equalTo(40)
        }
    }

    func configure(
        schedule: TeacherWorkbenchSchedule,
        selectedIds: Set<String>,
        onToggleStudent: @escaping (String) -> Void,
        onUndoStudent: @escaping (String) -> Void,
        onSubmit: @escaping () -> Void
    ) {
        self.onSubmit = onSubmit
        self.onUndoStudent = onUndoStudent
        timeLabel.text = [schedule.start_time, schedule.end_time]
            .compactMap { $0 }
            .joined(separator: " - ")
        let className = schedule.class?.name ?? "班级"
        let courseTitle = schedule.course?.title ?? "课程"
        titleLabel.text = "\(courseTitle) · \(className)"
        if let location = schedule.location, !location.isEmpty {
            titleLabel.text = (titleLabel.text ?? "") + "  \(location)"
        }

        statusLabel.text = schedule.statusText
        switch schedule.consume_status {
        case "completed":
            statusLabel.textColor = Theme.Color.success
            statusLabel.backgroundColor = Theme.Color.successTint
        case "partial":
            statusLabel.textColor = Theme.Color.brand
            statusLabel.backgroundColor = Theme.Color.brandSoft
        default:
            statusLabel.textColor = Theme.Color.clay
            statusLabel.backgroundColor = Theme.Color.warnTint
        }

        // 学员行
        studentRows.forEach { $0.removeFromSuperview() }
        studentRows.removeAll()
        let students = schedule.students ?? []
        for (index, student) in students.enumerated() {
            let row = WorkbenchStudentRowView()
            let isSelected = selectedIds.contains(student.child_id)
            row.configure(
                student: student,
                selected: isSelected,
                showDivider: index < students.count - 1
            )
            row.onTap = {
                guard !student.isLeave else { return }
                if student.isConsumed {
                    onUndoStudent(student.child_id)
                } else {
                    onToggleStudent(student.child_id)
                }
            }
            studentsStack.addArrangedSubview(row)
            studentRows.append(row)
        }

        let count = selectedIds.count
        if schedule.isCompleted {
            submitButton.isHidden = false
            submitButton.isEnabled = false
            submitButton.setTitle("已消课", for: .normal)
            submitButton.setTitleColor(Theme.Color.muted, for: .normal)
            submitButton.backgroundColor = Theme.Color.surfaceAlt
        } else {
            submitButton.isHidden = false
            submitButton.isEnabled = true
            submitButton.setTitle(count > 0 ? "一键点名消课（已选 \(count) 人）" : "一键点名消课", for: .normal)
            submitButton.setTitleColor(count > 0 ? .white : Theme.Color.muted, for: .normal)
            submitButton.backgroundColor = count > 0 ? Theme.Color.brand : Theme.Color.surfaceAlt
        }
    }

    @objc private func didTapSubmit() {
        onSubmit?()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 学员行

final class WorkbenchStudentRowView: UIView {

    private let avatarLabel = UILabel()
    private let nameLabel = UILabel()
    private let stateLabel = UILabel()
    private let checkView = UIImageView()
    private let divider = UIView()
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)

        avatarLabel.font = .appBody(14)
        avatarLabel.textColor = .white
        avatarLabel.textAlignment = .center
        avatarLabel.backgroundColor = Theme.Color.wood
        avatarLabel.layer.cornerRadius = Theme.Radius.avatar
        avatarLabel.layer.masksToBounds = true
        addSubview(avatarLabel)
        avatarLabel.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(34)
        }

        nameLabel.font = .appBody(14)
        nameLabel.textColor = Theme.Color.ink
        addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarLabel.snp.trailing).offset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
        }

        checkView.image = UIImage(systemName: "checkmark.circle.fill")
        checkView.tintColor = Theme.Color.brand
        checkView.isHidden = true
        addSubview(checkView)
        checkView.snp.makeConstraints {
            $0.trailing.equalToSuperview()
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(22)
        }

        stateLabel.font = .appLabel(11)
        stateLabel.textColor = Theme.Color.muted
        addSubview(stateLabel)
        stateLabel.snp.makeConstraints {
            $0.trailing.equalTo(checkView.snp.leading).offset(-Theme.Spacing.m)
            $0.centerY.equalToSuperview()
        }

        divider.backgroundColor = Theme.Color.line
        addSubview(divider)
        divider.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(0.5)
        }

        snp.makeConstraints { $0.height.equalTo(52) }
    }

    func configure(student: TeacherWorkbenchStudent, selected: Bool, showDivider: Bool) {
        avatarLabel.text = String(student.name.prefix(1))
        nameLabel.text = student.name
        divider.isHidden = !showDivider

        if student.isLeave {
            nameLabel.textColor = Theme.Color.muted
            stateLabel.text = "请假"
            stateLabel.textColor = Theme.Color.warn
            checkView.isHidden = true
        } else if student.isConsumed {
            nameLabel.textColor = Theme.Color.muted
            stateLabel.text = "已消课"
            stateLabel.textColor = Theme.Color.muted
            checkView.image = UIImage(systemName: "checkmark.circle.fill")
            checkView.tintColor = Theme.Color.successTint
            checkView.isHidden = false
        } else {
            nameLabel.textColor = Theme.Color.ink
            stateLabel.text = "剩余 \(student.remaining) 节"
            stateLabel.textColor = Theme.Color.muted
            checkView.image = selected
                ? UIImage(systemName: "checkmark.circle.fill")
                : UIImage(systemName: "circle")
            checkView.tintColor = selected ? Theme.Color.brand : Theme.Color.line
            checkView.isHidden = false
        }
    }

    @objc private func handleTap() {
        onTap?()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 空态

final class WorkbenchEmptyCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        let label = UILabel()
        label.text = "今天没有排课，休息一下吧"
        label.font = .appBody(14)
        label.textColor = Theme.Color.muted
        label.textAlignment = .center
        contentView.addSubview(label)
        label.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
