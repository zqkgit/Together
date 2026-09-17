//
//  ScheduleDetailViewController.swift
//  Together_ios
//
//  课表详情：排课信息 + 班级学员消课管理（勾选消课 / 撤销消课）
//

import UIKit
import SnapKit

final class ScheduleDetailViewController: BaseViewController {

    private let schedule: TeacherTimetableItem
    private var students: [TeacherWorkbenchStudent] = []
    private var selectedIds = Set<String>()
    private var loading = false

    // 内容
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let headerCard = ScheduleHeaderCardView()
    private let studentCard = UIView()
    private let studentTitle = UILabel()
    private let studentStack = UIStackView()
    private var studentRows: [WorkbenchStudentRowView] = []

    // 底部操作栏
    private let actionBar = UIView()
    private let actionLabel = UILabel()
    private let submitButton = UIButton(type: .system)

    init(schedule: TeacherTimetableItem) {
        self.schedule = schedule
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureImmersiveNav(title: "排课详情")
        setupUI()
        loadStudents()
    }

    // MARK: - UI

    private func setupUI() {
        view.backgroundColor = Theme.Color.surfaceAlt

        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalToSuperview()
        }

        contentStack.axis = .vertical
        contentStack.spacing = Theme.Spacing.m
        contentStack.layoutMargins = UIEdgeInsets(
            top: Theme.Spacing.m,
            left: Theme.Spacing.m,
            bottom: Theme.Spacing.m,
            right: Theme.Spacing.m
        )
        contentStack.isLayoutMarginsRelativeArrangement = true
        scrollView.addSubview(contentStack)
        contentStack.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.width.equalTo(scrollView)
        }

        headerCard.configure(with: schedule)
        contentStack.addArrangedSubview(headerCard)

        setupStudentCard()
        contentStack.addArrangedSubview(studentCard)

        setupActionBar()
    }

    private func setupStudentCard() {
        studentCard.backgroundColor = Theme.Color.surface
        studentCard.layer.cornerRadius = Theme.Radius.card

        studentTitle.font = .appSection(15)
        studentTitle.textColor = Theme.Color.ink
        studentTitle.text = "学员消课"
        studentCard.addSubview(studentTitle)
        studentTitle.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }

        studentStack.axis = .vertical
        studentCard.addSubview(studentStack)
        studentStack.snp.makeConstraints {
            $0.top.equalTo(studentTitle.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.s)
        }
    }

    private func setupActionBar() {
        actionBar.backgroundColor = Theme.Color.surface
        actionBar.layer.cornerRadius = Theme.Radius.card
        view.addSubview(actionBar)
        actionBar.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-Theme.Spacing.m)
            $0.height.equalTo(56)
        }

        actionLabel.font = .appBody(13)
        actionLabel.textColor = Theme.Color.sub
        actionLabel.text = "已选 0 人"
        actionBar.addSubview(actionLabel)
        actionLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
        }

        submitButton.titleLabel?.font = .appBody(14)
        submitButton.layer.cornerRadius = Theme.Radius.button
        submitButton.addTarget(self, action: #selector(didTapSubmit), for: .touchUpInside)
        actionBar.addSubview(submitButton)
        submitButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.m)
            $0.centerY.equalToSuperview()
            $0.width.equalTo(120)
            $0.height.equalTo(38)
        }

        // 底部操作栏悬浮：内容底部预留空间
        contentStack.snp.makeConstraints {
            $0.bottom.equalTo(scrollView.contentLayoutGuide).offset(-(56 + Theme.Spacing.xl))
        }
    }

    // MARK: - Data

    private func loadStudents() {
        loading = true
        TeacherService.fetchClassStudents(
            classId: schedule.class?.class_id ?? "",
            scheduleId: schedule.schedule_id
        ) { [weak self] result in
            guard let self else { return }
            self.loading = false
            switch result {
            case .success(let list):
                self.students = list
                self.selectedIds.removeAll()
                self.renderStudents()
            case .failure(let error):
                self.showToast(error.message)
            }
        }
    }

    private func renderStudents() {
        studentRows.forEach { $0.removeFromSuperview() }
        studentRows.removeAll()

        let list = students
        if list.isEmpty {
            studentTitle.text = "学员消课"
            let empty = UILabel()
            empty.font = .appBody(13)
            empty.textColor = Theme.Color.muted
            empty.text = "暂无学员"
            studentStack.addArrangedSubview(empty)
            updateActionBar()
            return
        }

        studentTitle.text = "学员消课（\(list.count)）"
        for (index, student) in list.enumerated() {
            let row = WorkbenchStudentRowView()
            let isSelected = selectedIds.contains(student.child_id)
            row.configure(
                student: student,
                selected: isSelected,
                showDivider: index < list.count - 1
            )
            row.onTap = { [weak self] in
                guard let self else { return }
                guard !student.isLeave else { return }
                if student.isConsumed {
                    self.confirmUndo(student)
                } else {
                    self.toggleStudent(student.child_id)
                }
            }
            studentStack.addArrangedSubview(row)
            studentRows.append(row)
        }
        updateActionBar()
    }

    private func toggleStudent(_ childId: String) {
        if selectedIds.contains(childId) {
            selectedIds.remove(childId)
        } else {
            selectedIds.insert(childId)
        }
        updateActionBar()
        renderStudentSelection()
    }

    private func renderStudentSelection() {
        for row in studentRows.enumerated() {
            let student = students[row.offset]
            row.element.configure(
                student: student,
                selected: selectedIds.contains(student.child_id),
                showDivider: row.offset < students.count - 1
            )
        }
    }

    private func updateActionBar() {
        let count = selectedIds.count
        actionLabel.text = "已选 \(count) 人"
        if count > 0 {
            submitButton.isEnabled = true
            submitButton.setTitle("消课 \(count) 人", for: .normal)
            submitButton.setTitleColor(.white, for: .normal)
            submitButton.backgroundColor = Theme.Color.brand
        } else {
            submitButton.isEnabled = false
            submitButton.setTitle("请选择学员", for: .normal)
            submitButton.setTitleColor(Theme.Color.muted, for: .normal)
            submitButton.backgroundColor = Theme.Color.surfaceAlt
        }
    }

    // MARK: - Actions

    @objc private func didTapSubmit() {
        guard !selectedIds.isEmpty else { return }
        let ids = Array(selectedIds)
        showToast("正在消课...")
        TeacherService.submitAttendance(
            scheduleId: schedule.schedule_id,
            childIds: ids
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.showToast("消课成功")
                self.loadStudents()
            case .failure(let error):
                self.showToast(error.message)
            }
        }
    }

    private func confirmUndo(_ student: TeacherWorkbenchStudent) {
        ThemeAlertView.show(
            title: "撤销消课",
            message: "确认撤销「\(student.name)」的本节课消课？将恢复 1 课时。",
            confirmTitle: "撤销",
            onConfirm: { [weak self] in
                self?.undoStudent(student)
            }
        )
    }

    private func undoStudent(_ student: TeacherWorkbenchStudent) {
        TeacherService.undoAttendance(
            scheduleId: schedule.schedule_id,
            childIds: [student.child_id]
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.showToast("已撤销消课")
                self.loadStudents()
            case .failure(let error):
                self.showToast(error.message)
            }
        }
    }
}

// MARK: - 排课信息卡片

private final class ScheduleHeaderCardView: UIView {

    private let dateLabel = UILabel()
    private let timeLabel = UILabel()
    private let statusWrap = UIView()
    private let statusLabel = UILabel()
    private let titleLabel = UILabel()
    private let metaLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.Color.surface
        layer.cornerRadius = Theme.Radius.card

        dateLabel.font = .appSection(15)
        dateLabel.textColor = Theme.Color.ink
        addSubview(dateLabel)
        dateLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.equalToSuperview().offset(Theme.Spacing.m)
        }

        timeLabel.font = .appBody(13)
        timeLabel.textColor = Theme.Color.muted
        addSubview(timeLabel)
        timeLabel.snp.makeConstraints {
            $0.top.equalTo(dateLabel.snp.bottom).offset(4)
            $0.leading.equalTo(dateLabel)
        }

        statusLabel.font = .appBody(11)
        statusLabel.textAlignment = .center
        statusWrap.addSubview(statusLabel)
        statusLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(3)
            $0.bottom.equalToSuperview().offset(-3)
            $0.leading.equalToSuperview().offset(8)
            $0.trailing.equalToSuperview().offset(-8)
        }
        statusWrap.layer.cornerRadius = 10
        statusWrap.clipsToBounds = true
        addSubview(statusWrap)
        statusWrap.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.m)
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
        }

        titleLabel.font = .appSection(15)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 1
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(timeLabel.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.equalTo(dateLabel)
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.m)
        }

        metaLabel.font = .appBody(11)
        metaLabel.textColor = Theme.Color.sub
        metaLabel.numberOfLines = 1
        addSubview(metaLabel)
        metaLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(4)
            $0.leading.equalTo(titleLabel)
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.m)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.m)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with item: TeacherTimetableItem) {
        let dateText = item.lesson_date ?? ""
        dateLabel.text = dateText.isEmpty ? "未排日期" : formatDate(dateText)
        timeLabel.text = [item.start_time, item.end_time]
            .compactMap { $0 }
            .joined(separator: " - ")
        let duration = item.course?.duration_min
        if let duration, !timeLabel.text!.isEmpty {
            timeLabel.text = (timeLabel.text ?? "") + "  ·  \(duration)分钟"
        }

        let statusText = item.consumeText ?? "待消课"
        statusLabel.text = statusText
        switch item.consume_status {
        case "completed":
            statusLabel.textColor = Theme.Color.success
            statusWrap.backgroundColor = Theme.Color.successTint
        case "partial":
            statusLabel.textColor = Theme.Color.brand
            statusWrap.backgroundColor = Theme.Color.brandSoft
        default:
            statusLabel.textColor = Theme.Color.clay
            statusWrap.backgroundColor = Theme.Color.warnTint
        }

        let courseTitle = item.course?.title ?? "课程"
        let className = item.class?.name ?? ""
        titleLabel.text = className.isEmpty ? courseTitle : "\(courseTitle) · \(className)"

        let location = item.location ?? "教室"
        metaLabel.text = "地点：\(location)"
    }

    private func formatDate(_ date: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let dateValue = formatter.date(from: date) else { return date }
        let weekdays = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let weekday = weekdays[Calendar.current.component(.weekday, from: dateValue) - 1]
        formatter.dateFormat = "MM月dd日"
        return "\(formatter.string(from: dateValue)) \(weekday)"
    }
}
