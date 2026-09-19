import UIKit
import SnapKit
import ESPullToRefresh

/// 课程学习（课时进度详情）
/// PR 设计：课程头（名称/机构·老师/已学节数）+ 课时列表（第X课·名称 + 日期 + 时间 + 已上/今天/待上）
final class CourseStudyViewController: BaseViewController {

    private let childId: String
    private let courseId: String
    private let initialTitle: String

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var summary: CourseScheduleSummary?
    private var schedules: [CourseScheduleItem] = []
    /// schedule_id -> 我的请假单（用于撤销）
    private var leaveMap: [String: CourseService.MyLeaveItem] = [:]
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
        // 与我的课程/广场一致：品牌下拉刷新
        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.loadData()
        }
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
            self.tableView.es.stopPullToRefresh()
        }

        // 并行拉取我的请假单：用于撤销待审批请假
        CourseService.fetchMyLeaves { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let items):
                var map: [String: CourseService.MyLeaveItem] = [:]
                // 状态优先级：0待审批 > 1已同意 > 2已婉拒 > 3已取消
                let rank: [Int] = [0, 1, 2, 3]
                for item in items {
                    guard let sid = item.schedule_id, !sid.isEmpty else { continue }
                    // 只保留当前孩子（同一课次多孩子共享 schedule_id）
                    if let itemChild = item.child_id, itemChild != childId { continue }
                    if let old = map[sid] {
                        let oldRank = rank.firstIndex(of: old.status ?? 9) ?? 9
                        let newRank = rank.firstIndex(of: item.status ?? 9) ?? 9
                        if newRank >= oldRank { continue }
                    }
                    map[sid] = item
                }
                self.leaveMap = map
                self.tableView.reloadData()
            case .failure:
                break // 请假列表拉取失败不影响课时展示
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
            let leave = leaveMap[item.schedule_id ?? ""]
            cell.configure(
                item,
                leaveId: leave?.leave_id,
                leaveStatus: leave?.status.map { $0 + 1 },
                makeupText: Self.makeupText(for: leave),
                onLeave: { [weak self] in
                    self?.askLeave(item)
                },
                onCancelLeave: { [weak self] in
                    self?.cancelLeave(item, leaveId: leave?.leave_id)
                }
            )
        }
        return cell
    }

    // MARK: - 请假

    /// 已同意请假单的补课展示文本（仅审批通过后可能安排补课）
    private static func makeupText(for leave: CourseService.MyLeaveItem?) -> String? {
        guard let leave, leave.status == 1 else { return nil }
        let makeupStatus = leave.makeup_status ?? 0
        if makeupStatus == 1 {
            return "补课已完成 · 课时已消耗"
        }
        if makeupStatus == 2 {
            return "已放弃补课"
        }
        // 0 = 已安排待补课：有补课排课才展示
        guard let ms = leave.makeup_schedule, let date = ms.lesson_date else { return nil }
        let time = [ms.start_time, ms.end_time].compactMap { $0 }.joined(separator: "-")
        let loc = ms.location ?? ""
        var text = "补课：\(date.mmddText)"
        if !time.isEmpty { text += " \(time)" }
        if !loc.isEmpty { text += " · \(loc)" }
        return text
    }

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
            scheduleId: item.schedule_id ?? "",
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

    /// 撤销待审批请假
    private func cancelLeave(_ item: CourseScheduleItem, leaveId: String?) {
        guard let leaveId, !leaveId.isEmpty else {
            showToast("未找到请假记录")
            return
        }
        ThemeAlertView.show(
            title: "撤销请假",
            message: "确定撤销这条请假申请吗？撤销后老师不再审批。",
            confirmTitle: "撤销",
            cancelTitle: "再想想"
        ) { [weak self] in
            guard let self else { return }
            self.showLoading()
            CourseService.cancelLeave(leaveId: leaveId) { [weak self] result in
                guard let self else { return }
                self.hideLoading()
                switch result {
                case .success:
                    self.showToast("请假已撤销")
                    self.loadData()
                case .failure(let error):
                    self.showToast(error.message ?? "撤销失败")
                }
            }
        }
    }
}

// MARK: - 课程学习 Cell（头部卡 + 课时行复用）

final class CourseStudyCell: UITableViewCell {

    enum Style {
        case header
        case lesson
        case pending
    }

    private let card = UIView()
    private let titleLabel = UILabel()
    private let leaveButton = UIButton(type: .system)
    private let subtitleLabel = UILabel()
    private let timeLabel = UILabel()
    private let makeupLabel = UILabel()
    private let statusButton = UIButton(type: .system)
    private var subtitleLeadingTitle: Constraint?
    private var subtitleLeadingLeave: Constraint?
    private var subtitleBottom: Constraint?
    private var makeupBottom: Constraint?
    private var dashLayer: CAShapeLayer?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(card)
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        card.layer.borderWidth = 0
        card.layer.borderColor = nil
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
            subtitleBottom = make.bottom.equalToSuperview().inset(Theme.Spacing.l).constraint
            // 日期默认从标题列开始；显示请假按钮时切到按钮右侧
            subtitleLeadingTitle = make.leading.equalTo(titleLabel).constraint
            subtitleLeadingLeave = make.leading.equalTo(leaveButton.snp.trailing).offset(Theme.Spacing.s).constraint
        }
        // 两个 leading 互斥：默认只激活标题对齐，避免约束冲突崩溃
        subtitleLeadingLeave?.deactivate()

        // 第三行：补课信息（仅已请假且有补课安排时显示，其余情况隐藏并恢复 subtitle 贴底）
        makeupLabel.font = .appLabel(12)
        makeupLabel.textColor = Theme.Color.clay
        makeupLabel.numberOfLines = 1
        makeupLabel.lineBreakMode = .byTruncatingTail
        card.addSubview(makeupLabel)
        makeupLabel.snp.makeConstraints { make in
            make.top.equalTo(subtitleLabel.snp.bottom).offset(4)
            make.leading.equalTo(titleLabel)
            make.trailing.lessThanOrEqualToSuperview().inset(92)
            makeupBottom = make.bottom.equalToSuperview().inset(Theme.Spacing.l).constraint
        }
        makeupBottom?.deactivate()
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
        clearPendingDash()
        titleLabel.font = .appSection(18)
        titleLabel.text = summary?.course_title ?? fallbackTitle
        subtitleLabel.text = summary?.studioTeacherText
        timeLabel.text = nil
        // 头部无补课信息：隐藏补课行并恢复 subtitle 贴底
        makeupLabel.text = nil
        makeupLabel.isHidden = true
        makeupBottom?.deactivate()
        subtitleBottom?.activate()
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
    func configure(
        _ item: CourseScheduleItem,
        leaveId: String? = nil,
        leaveStatus: Int? = nil,
        makeupText: String? = nil,
        onLeave: (() -> Void)? = nil,
        onCancelLeave: (() -> Void)? = nil
    ) {
        clearPendingDash()
        titleLabel.font = .appSection(15)
        let no = item.lesson_no ?? 0
        titleLabel.textColor = Theme.Color.ink
        // 待排课课时（status=3）：灰色虚线卡，仅显示课序号 + 待排课
        if item.status == 3 {
            let title = item.lesson_title ?? ""
            if !title.isEmpty && title != "第\(no)课" {
                titleLabel.text = "第\(no)课·\(title)"
            } else {
                titleLabel.text = "第\(no)课"
            }
            titleLabel.textColor = Theme.Color.sub
            subtitleLabel.text = "待排课"
            subtitleLabel.textColor = Theme.Color.sub
            timeLabel.text = nil
            statusButton.isHidden = true
            leaveButton.isHidden = true
            leaveButton.snp.updateConstraints { $0.width.equalTo(0) }
            subtitleLeadingLeave?.deactivate()
            subtitleLeadingTitle?.activate()
            makeupLabel.text = nil
            makeupLabel.isHidden = true
            makeupBottom?.deactivate()
            subtitleBottom?.activate()
            titleLabel.snp.updateConstraints { $0.trailing.lessThanOrEqualToSuperview().inset(84) }
            card.layer.borderWidth = 1
            card.layer.borderColor = Theme.Color.line.cgColor
            let dash = CAShapeLayer()
            dash.strokeColor = Theme.Color.line.cgColor
            dash.lineWidth = 1
            dash.lineDashPattern = [4, 4]
            dash.fillColor = nil
            dash.frame = card.bounds
            dash.path = UIBezierPath(roundedRect: card.bounds, cornerRadius: Theme.Radius.card).cgPath
            card.layer.addSublayer(dash)
            dashLayer = dash
            self.onLeave = nil
            self.onCancelLeave = nil
            return
        }
        titleLabel.text = "第\(no)课·\(item.lesson_title ?? "课程")"
        subtitleLabel.text = item.lesson_date?.mmddText
        timeLabel.text = item.start_time ?? ""
        statusButton.isHidden = false
        statusButton.snp.updateConstraints {
            $0.width.equalTo(48)
        }

        let leaveStatus = leaveStatus ?? item.leave_status ?? 0
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

        // 左侧操作按钮：
        // 1) 待审批请假 → 撤销请假
        // 2) 待上/今天 且未请假（含婉拒）→ 请假
        let canCancel = leaveStatus == 1 && leaveId != nil && !leaveId!.isEmpty
        let canLeave = !canCancel && (item.status == 0 || item.status == 2) && (leaveStatus == 0 || leaveStatus == 3 || leaveStatus == 4)
        if canCancel {
            leaveButton.setTitle("撤销请假", for: .normal)
            leaveButton.setTitleColor(Theme.Color.clay, for: .normal)
            leaveButton.backgroundColor = Theme.Color.warnTint
        } else if canLeave {
            leaveButton.setTitle("请假", for: .normal)
            leaveButton.setTitleColor(Theme.Color.clay, for: .normal)
            leaveButton.backgroundColor = Theme.Color.warnTint
        }
        leaveButton.isHidden = !(canCancel || canLeave)
        leaveButton.snp.updateConstraints {
            $0.width.equalTo(canCancel || canLeave ? 64 : 0)
        }
        if canCancel || canLeave {
            subtitleLeadingTitle?.deactivate()
            subtitleLeadingLeave?.activate()
        } else {
            subtitleLeadingLeave?.deactivate()
            subtitleLeadingTitle?.activate()
        }
        self.onLeave = canLeave ? onLeave : nil
        self.onCancelLeave = canCancel ? onCancelLeave : nil

        // 补课信息行：已请假（同意）且有补课内容时显示，卡片高度自适应
        if let makeupText, !makeupText.isEmpty {
            makeupLabel.text = makeupText
            makeupLabel.isHidden = false
            subtitleBottom?.deactivate()
            makeupBottom?.activate()
        } else {
            makeupLabel.text = nil
            makeupLabel.isHidden = true
            makeupBottom?.deactivate()
            subtitleBottom?.activate()
        }

        titleLabel.snp.updateConstraints {
            $0.trailing.lessThanOrEqualToSuperview().inset(84)
        }
    }

    /// 待排课占位卡：灰色虚线卡片，提示还有 N 节未安排
    func configurePending(_ count: Int) {
        clearPendingDash()
        titleLabel.font = .appSection(15)
        titleLabel.text = "还有 \(count) 节课待安排"
        titleLabel.textColor = Theme.Color.sub
        subtitleLabel.text = "工作室排课后会显示在这里"
        subtitleLabel.textColor = Theme.Color.sub
        timeLabel.text = nil
        statusButton.isHidden = true
        leaveButton.isHidden = true
        leaveButton.snp.updateConstraints { $0.width.equalTo(0) }
        subtitleLeadingLeave?.deactivate()
        subtitleLeadingTitle?.activate()
        makeupLabel.text = nil
        makeupLabel.isHidden = true
        makeupBottom?.deactivate()
        subtitleBottom?.activate()
        titleLabel.snp.updateConstraints { $0.trailing.lessThanOrEqualToSuperview().inset(84) }

        card.layer.borderWidth = 1
        card.layer.borderColor = Theme.Color.line.cgColor
        let dash = CAShapeLayer()
        dash.strokeColor = Theme.Color.line.cgColor
        dash.lineWidth = 1
        dash.lineDashPattern = [4, 4]
        dash.fillColor = nil
        dash.frame = card.bounds
        dash.path = UIBezierPath(roundedRect: card.bounds, cornerRadius: Theme.Radius.card).cgPath
        card.layer.addSublayer(dash)
        dashLayer = dash
    }

    private func clearPendingDash() {
        dashLayer?.removeFromSuperlayer()
        dashLayer = nil
        card.layer.borderWidth = 0
        card.layer.borderColor = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let dash = dashLayer {
            dash.frame = card.bounds
            dash.path = UIBezierPath(roundedRect: card.bounds, cornerRadius: Theme.Radius.card).cgPath
        }
    }

    private var onLeave: (() -> Void)?
    private var onCancelLeave: (() -> Void)?

    @objc private func didTapLeave() {
        if onCancelLeave != nil {
            onCancelLeave?()
        } else {
            onLeave?()
        }
    }
}
