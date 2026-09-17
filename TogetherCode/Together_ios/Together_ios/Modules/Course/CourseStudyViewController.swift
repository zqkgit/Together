import UIKit
import SnapKit

/// 课程学习（课时进度详情）
/// PR 设计：课程头（名称/机构·老师/已学节数）+ 课时列表（第X课·名称 + 日期 + 时间 + 已上/今天/待上）
final class CourseStudyViewController: BaseViewController {

    private let childId: String
    private let courseId: String
    private let initialTitle: String

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var summary: CourseScheduleSummary?
    private var schedules: [CourseScheduleItem] = []
    private let emptyView = EmptyStateView()

    init(childId: String, courseId: String, courseTitle: String) {
        self.childId = childId
        self.courseId = courseId
        self.initialTitle = courseTitle
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureImmersiveNav(title: "课程学习")
        setupUI()
        loadData()
    }

    private func setupUI() {
        view.backgroundColor = Theme.Color.bg
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(CourseStudyCell.self, forCellReuseIdentifier: "CourseStudyCell")
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 84
        view.addSubview(tableView)
        tableView.snp.makeConstraints { $0.edges.equalTo(view.safeAreaLayoutGuide) }

        emptyView.isHidden = true
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints { $0.center.equalToSuperview() }
    }

    private func loadData() {
        emptyView.show(style: .loading)
        CourseService.fetchCourseSchedules(childId: childId, courseId: courseId) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let summary):
                self.summary = summary
                self.schedules = summary.list ?? []
                self.tableView.reloadData()
                self.emptyView.isHidden = true
                if self.schedules.isEmpty {
                    self.emptyView.show(style: .empty("暂无课时安排"))
                }
            case .failure(let error):
                self.emptyView.show(style: .error(error.message) { [weak self] in
                    self?.loadData()
                })
            }
        }
    }
}

extension CourseStudyViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        schedules.isEmpty ? 0 : 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? 1 : schedules.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CourseStudyCell", for: indexPath) as! CourseStudyCell
        if indexPath.section == 0 {
            cell.configureHeader(summary, fallbackTitle: initialTitle)
        } else {
            let item = schedules[indexPath.row]
            cell.configure(item) { [weak self] in
                self?.askLeave(item)
            }
        }
        return cell
    }

    // MARK: - 请假

    private func askLeave(_ item: CourseScheduleItem) {
        // 优先取该课次所属班级，回退课程课包班级
        let classId = item.class_id ?? summary?.class_id
        guard let classId, !classId.isEmpty else {
            showToast("未找到班级信息，暂时无法请假")
            return
        }
        ThemeInputAlertView.show(
            title: "请假申请",
            placeholder: "请输入请假事由",
            maxCount: 100
        ) { [weak self] reason in
            self?.submitLeave(item, classId: classId, reason: reason)
        }
    }

    private func submitLeave(_ item: CourseScheduleItem, classId: String, reason: String) {
        showLoading()
        CourseService.submitLeave(
            classId: classId,
            childId: childId,
            scheduleId: item.schedule_id,
            reason: reason
        ) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success:
                self.showToast("请假已提交，等待老师审批")
                self.loadData()
            case .failure(let error):
                self.showToast(error.message ?? "提交失败")
            }
        }
    }
}

// MARK: - 课程学习 Cell（头部卡 + 课时行复用）

final class CourseStudyCell: UITableViewCell {

    enum Style {
        case header
        case lesson
    }

    private let card = UIView()
    private let titleLabel = UILabel()
    private let leaveButton = UIButton(type: .system)
    private let subtitleLabel = UILabel()
    private let timeLabel = UILabel()
    private let statusButton = UIButton(type: .system)
    private var subtitleLeadingTitle: Constraint?
    private var subtitleLeadingLeave: Constraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(card)
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        card.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.xs)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.xs)
        }

        titleLabel.font = .appSection(16)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        card.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.trailing.lessThanOrEqualToSuperview().inset(84)
        }

        // 请假入口（第二行最左；仅可请假课次显示，隐藏时宽度收为 0，日期自动左移）
        // 注意：必须先加入视图层并建立约束，后续 subtitle 才能引用它的 trailing
        leaveButton.setTitle("请假", for: .normal)
        leaveButton.titleLabel?.font = .appLabel(12)
        leaveButton.setTitleColor(Theme.Color.clay, for: .normal)
        leaveButton.backgroundColor = Theme.Color.warnTint
        leaveButton.layer.cornerRadius = 12
        leaveButton.layer.masksToBounds = true
        leaveButton.addTarget(self, action: #selector(didTapLeave), for: .touchUpInside)
        leaveButton.isHidden = true
        card.addSubview(leaveButton)
        leaveButton.snp.makeConstraints {
            $0.leading.equalTo(titleLabel)
            $0.width.equalTo(0)
            $0.height.equalTo(24)
        }

        subtitleLabel.font = .appLabel(13)
        subtitleLabel.textColor = Theme.Color.sub
        subtitleLabel.numberOfLines = 1
        card.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(5)
            make.bottom.equalToSuperview().inset(Theme.Spacing.l)
            // 日期默认从标题列开始；显示请假按钮时切到按钮右侧
            subtitleLeadingTitle = make.leading.equalTo(titleLabel).constraint
            subtitleLeadingLeave = make.leading.equalTo(leaveButton.snp.trailing).offset(Theme.Spacing.s).constraint
        }
        // 两个 leading 互斥：默认只激活标题对齐，避免约束冲突崩溃
        subtitleLeadingLeave?.deactivate()
        leaveButton.snp.makeConstraints {
            $0.centerY.equalTo(subtitleLabel)
        }

        timeLabel.font = .appLabel(13)
        timeLabel.textColor = Theme.Color.sub
        timeLabel.numberOfLines = 1
        card.addSubview(timeLabel)
        timeLabel.snp.makeConstraints {
            $0.centerY.equalTo(subtitleLabel)
            $0.leading.equalTo(subtitleLabel.snp.trailing).offset(Theme.Spacing.s)
            $0.trailing.lessThanOrEqualToSuperview().inset(84)
        }

        statusButton.titleLabel?.font = .appLabel(12)
        statusButton.setTitleColor(Theme.Color.sub, for: .normal)
        statusButton.layer.cornerRadius = 11
        statusButton.layer.masksToBounds = true
        statusButton.setContentHuggingPriority(.required, for: .horizontal)
        statusButton.isUserInteractionEnabled = false
        card.addSubview(statusButton)
        statusButton.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.width.equalTo(48)
            $0.height.equalTo(22)
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 头部：课程名 + 机构·老师 + 已学节数
    func configureHeader(_ summary: CourseScheduleSummary?, fallbackTitle: String) {
        titleLabel.font = .appSection(18)
        titleLabel.text = summary?.course_title ?? fallbackTitle
        subtitleLabel.text = summary?.studioTeacherText
        timeLabel.text = nil
        statusButton.isHidden = false
        statusButton.isUserInteractionEnabled = false
        leaveButton.isHidden = true
        leaveButton.snp.updateConstraints {
            $0.width.equalTo(0)
        }
        subtitleLeadingLeave?.deactivate()
        subtitleLeadingTitle?.activate()
        let consumed = summary?.consumed_lessons ?? 0
        let total = summary?.total_lessons ?? 0
        statusButton.setTitle("已学\(consumed)/\(total)节", for: .normal)
        statusButton.setTitleColor(Theme.Color.brand, for: .normal)
        statusButton.backgroundColor = Theme.Color.brandSoft
        statusButton.snp.updateConstraints {
            $0.width.equalTo(76)
        }
        titleLabel.snp.updateConstraints {
            $0.trailing.lessThanOrEqualToSuperview().inset(84)
        }
    }

    /// 课时：第X课·名称 + 日期时间 + 右侧状态（可请假时左侧显示「请假」按钮）
    func configure(_ item: CourseScheduleItem, onLeave: (() -> Void)? = nil) {
        titleLabel.font = .appSection(15)
        let no = item.lesson_no ?? 0
        titleLabel.text = "第\(no)课·\(item.lesson_title ?? "课程")"
        subtitleLabel.text = item.lesson_date?.mmddText
        timeLabel.text = item.start_time ?? ""
        statusButton.isHidden = false
        statusButton.snp.updateConstraints {
            $0.width.equalTo(48)
        }

        let leaveStatus = item.leave_status ?? 0
        // 请假中 / 已请假：右侧展示状态，不显示请假入口
        if leaveStatus == 1 {
            statusButton.setTitle("请假中", for: .normal)
            statusButton.setTitleColor(Theme.Color.clay, for: .normal)
            statusButton.backgroundColor = Theme.Color.warnTint
            statusButton.isUserInteractionEnabled = false
        } else if leaveStatus == 2 {
            statusButton.setTitle("已请假", for: .normal)
            statusButton.setTitleColor(Theme.Color.brand, for: .normal)
            statusButton.backgroundColor = Theme.Color.brandSoft
            statusButton.isUserInteractionEnabled = false
        } else {
            switch item.status {
            case 1:
                statusButton.setTitle("已上", for: .normal)
                statusButton.setTitleColor(Theme.Color.brand, for: .normal)
                statusButton.backgroundColor = Theme.Color.brandSoft
            case 2:
                statusButton.setTitle("今天", for: .normal)
                statusButton.setTitleColor(Theme.Color.brandDark, for: .normal)
                statusButton.backgroundColor = Theme.Color.brandSoft
            default:
                statusButton.setTitle("待上", for: .normal)
                statusButton.setTitleColor(Theme.Color.sub, for: .normal)
                statusButton.backgroundColor = Theme.Color.surfaceAlt
            }
            statusButton.isUserInteractionEnabled = false
        }

        // 请假入口：待上/今天 且未请假（含婉拒）→ 左侧显示
        let canLeave = (item.status == 0 || item.status == 2) && (leaveStatus == 0 || leaveStatus == 3)
        leaveButton.isHidden = !canLeave
        leaveButton.snp.updateConstraints {
            $0.width.equalTo(canLeave ? 44 : 0)
        }
        if canLeave {
            subtitleLeadingTitle?.deactivate()
            subtitleLeadingLeave?.activate()
        } else {
            subtitleLeadingLeave?.deactivate()
            subtitleLeadingTitle?.activate()
        }
        self.onLeave = canLeave ? onLeave : nil

        titleLabel.snp.updateConstraints {
            $0.trailing.lessThanOrEqualToSuperview().inset(84)
        }
    }

    private var onLeave: (() -> Void)?

    @objc private func didTapLeave() { onLeave?() }
}
