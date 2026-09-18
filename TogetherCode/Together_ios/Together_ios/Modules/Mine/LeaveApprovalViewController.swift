import UIKit
import SnapKit

/// 请假审批：待审批请假（同意/婉拒）+ 补课管理（已同意请假安排/放弃补课）
final class LeaveApprovalViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .grouped)

    private var leaves: [TeacherLeaveItem] = []
    private var approvedLeaves: [TeacherLeaveItem] = []
    private var studioOptions: [(id: String, name: String)] = []
    private let studioChipRow = TagChipRow(chips: ["全部工作室"])
    private var loading = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        configureImmersiveNav(title: "请假审批")
        setupUI()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "请假审批")
        if !leaves.isEmpty || !approvedLeaves.isEmpty { loadData() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    private func setupUI() {
        // 工作室筛选（固定在导航下）
        let filterWrap = UIView()
        filterWrap.backgroundColor = Theme.Color.bg
        view.addSubview(filterWrap)
        filterWrap.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
        }

        studioChipRow.onSelect = { [weak self] index in
            guard let self else { return }
            self.loadData(studioId: self.selectedStudioId(at: index))
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
        tableView.register(LeaveRequestCell.self, forCellReuseIdentifier: LeaveRequestCell.reuseID)
        tableView.register(TeacherMakeupCell.self, forCellReuseIdentifier: TeacherMakeupCell.reuseID)
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

    private func selectedStudioId(at index: Int) -> String? {
        guard index > 0, index - 1 < studioOptions.count else { return nil }
        return studioOptions[index - 1].id
    }

    private func loadData(studioId: String? = nil) {
        guard !loading else { return }
        loading = true
        let group = DispatchGroup()
        var leaveData: [TeacherLeaveItem] = []
        var approvedData: [TeacherLeaveItem] = []

        group.enter()
        TeacherService.fetchPendingLeaves(studioId: studioId) { result in
            defer { group.leave() }
            if case .success(let list) = result { leaveData = list }
        }
        group.enter()
        TeacherService.fetchApprovedLeaves(studioId: studioId) { result in
            defer { group.leave() }
            if case .success(let list) = result { approvedData = list }
        }
        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.loading = false
            self.leaves = leaveData
            self.approvedLeaves = approvedData
            if studioId == nil {
                // 全量时构建工作室筛选 chips（按出现顺序去重）
                var seen: [(id: String, name: String)] = []
                for item in leaveData + approvedData {
                    guard let sid = item.studio_id, let studio = item.studio_name,
                          !studio.isEmpty,
                          !seen.contains(where: { $0.name == studio }) else { continue }
                    seen.append((id: sid, name: studio))
                }
                self.studioOptions = seen
                var chips = ["全部工作室"]
                chips += seen.map { $0.name }
                self.studioChipRow.update(chips: chips, selectedIndex: 0)
            }
            self.tableView.reloadData()
        }
    }

    // MARK: - TableView

    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? leaves.count : approvedLeaves.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let title: String
        switch section {
        case 0:
            guard !leaves.isEmpty else { return nil }
            title = "请假申请"
        default:
            guard !approvedLeaves.isEmpty else { return nil }
            title = "补课管理"
        }
        let label = UILabel()
        label.font = .appSection(14)
        label.textColor = Theme.Color.ink
        label.text = title
        label.frame = CGRect(x: Theme.Spacing.l, y: 8, width: 300, height: 24)
        let wrap = UIView()
        wrap.backgroundColor = .clear
        wrap.addSubview(label)
        return wrap
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? (leaves.isEmpty ? 0 : 40) : (approvedLeaves.isEmpty ? 0 : 40)
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
        let cell = tableView.dequeueReusableCell(withIdentifier: TeacherMakeupCell.reuseID, for: indexPath) as! TeacherMakeupCell
        let leave = approvedLeaves[indexPath.row]
        cell.configure(leave)
        cell.onArrange = { [weak self] in self?.arrangeMakeup(leave) }
        cell.onAbandon = { [weak self] in self?.abandonMakeup(leave) }
        cell.onComplete = { [weak self] in self?.completeMakeup(leave) }
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

    // MARK: - 补课管理

    private func arrangeMakeup(_ leave: TeacherLeaveItem) {
        guard let leaveId = leave.leave_id else { return }
        showLoading()
        TeacherService.fetchMakeupCandidates(leaveId: leaveId) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success(let candidates):
                guard !candidates.isEmpty else {
                    self.showToast("暂无可用补课课次")
                    return
                }
                let sheet = ThemeActionSheet(title: "选择补课课次", actions: candidates.map { ($0.displayText, false) })
                sheet.onSelect = { [weak self] index in
                    guard let self, index < candidates.count, let sid = candidates[index].schedule_id else { return }
                    self.submitMakeup(leave: leave, scheduleId: sid)
                }
                self.present(sheet, animated: false)
            case .failure(let error):
                self.showToast(error.message ?? "获取补课课次失败")
            }
        }
    }

    private func submitMakeup(leave: TeacherLeaveItem, scheduleId: String) {
        guard let leaveId = leave.leave_id else { return }
        showLoading()
        TeacherService.updateMakeup(leaveId: leaveId, makeupScheduleId: scheduleId) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success:
                self.showToast("补课已安排")
                self.loadData()
            case .failure(let error):
                self.showToast(error.message ?? "操作失败")
            }
        }
    }

    private func completeMakeup(_ leave: TeacherLeaveItem) {
        guard let leaveId = leave.leave_id,
              let makeupScheduleId = leave.makeup_schedule_id,
              let childId = leave.child?.child_id else { return }
        ThemeAlertView.show(
            title: "完成补课",
            message: "确认完成补课？将消耗「\(leave.child?.nickname ?? "孩子")」一节课时，并通知家长。",
            confirmTitle: "确认完成",
            onConfirm: { [weak self] in
                guard let self else { return }
                self.showLoading()
                TeacherService.submitAttendance(scheduleId: makeupScheduleId, childIds: [childId]) { [weak self] result in
                    guard let self else { return }
                    self.hideLoading()
                    switch result {
                    case .success:
                        self.showToast("补课已完成，课时已消耗")
                        self.loadData()
                    case .failure(let error):
                        self.showToast(error.message ?? "操作失败")
                    }
                }
            }
        )
    }

    private func abandonMakeup(_ leave: TeacherLeaveItem) {
        ThemeAlertView.show(
            title: "放弃补课",
            message: "放弃后该请假单不再安排补课，如需补课可重新安排。",
            confirmTitle: "放弃补课",
            onConfirm: { [weak self] in
                guard let self, let leaveId = leave.leave_id else { return }
                self.showLoading()
                TeacherService.updateMakeup(leaveId: leaveId, abandon: true) { [weak self] result in
                    guard let self else { return }
                    self.hideLoading()
                    switch result {
                    case .success:
                        self.showToast("已放弃补课")
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

// MARK: - 补课管理卡（已同意请假 + 安排/放弃补课）

final class TeacherMakeupCell: UITableViewCell {

    static let reuseID = "TeacherMakeupCell"
    var onArrange: (() -> Void)?
    var onAbandon: (() -> Void)?
    var onComplete: (() -> Void)?

    private let container = UIView()
    private let titleLabel = UILabel()
    private let infoLabel = UILabel()
    private let makeupLabel = UILabel()
    private let actionStack = UIStackView()
    private let arrangeButton = UIButton(type: .system)
    private let abandonButton = UIButton(type: .system)
    private var actionStackHeight: Constraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.bg
        selectionStyle = .none

        container.backgroundColor = Theme.Color.surface
        container.layer.cornerRadius = Theme.Radius.card
        container.layer.borderWidth = 1
        container.layer.borderColor = Theme.Color.line.cgColor
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

        makeupLabel.font = .appBody(13)
        makeupLabel.numberOfLines = 2
        container.addSubview(makeupLabel)
        makeupLabel.snp.makeConstraints {
            $0.top.equalTo(infoLabel.snp.bottom).offset(8)
            $0.leading.trailing.equalTo(titleLabel)
        }

        actionStack.axis = .horizontal
        actionStack.spacing = Theme.Spacing.m
        actionStack.distribution = .fillEqually
        container.addSubview(actionStack)
        actionStack.snp.makeConstraints {
            $0.top.equalTo(makeupLabel.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalTo(titleLabel)
            actionStackHeight = $0.height.equalTo(34).constraint
            $0.bottom.equalToSuperview().inset(Theme.Spacing.m)
        }

        for button in [arrangeButton, abandonButton] {
            button.titleLabel?.font = .appBody(13)
            button.layer.cornerRadius = 17
            actionStack.addArrangedSubview(button)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ leave: TeacherLeaveItem) {
        titleLabel.text = "\(leave.child?.nickname ?? "孩子") 请假已同意"
        infoLabel.text = leave.infoText

        if let text = leave.makeupText {
            makeupLabel.text = text
            makeupLabel.isHidden = false
            switch leave.makeup_status {
            case 1:
                makeupLabel.textColor = Theme.Color.brand
            case 2:
                makeupLabel.textColor = Theme.Color.sub
            default:
                makeupLabel.textColor = leave.hasPendingMakeup ? Theme.Color.clay : Theme.Color.sub
            }
        } else {
            makeupLabel.isHidden = true
        }

        let hasAction = leave.hasPendingMakeup || leave.canArrangeMakeup
        actionStack.isHidden = !hasAction
        actionStackHeight?.update(offset: hasAction ? 34 : 0)
        guard hasAction else { return }

        if leave.hasPendingMakeup {
            // 待补：补课完成（实心）+ 放弃补课（描边）
            arrangeButton.setTitle("补课完成", for: .normal)
            arrangeButton.setTitleColor(.white, for: .normal)
            arrangeButton.backgroundColor = Theme.Color.brand
            arrangeButton.layer.borderWidth = 0
            arrangeButton.removeTarget(nil, action: nil, for: .touchUpInside)
            arrangeButton.addTarget(self, action: #selector(didTapComplete), for: .touchUpInside)

            abandonButton.setTitle("放弃补课", for: .normal)
            abandonButton.setTitleColor(Theme.Color.clay, for: .normal)
            abandonButton.backgroundColor = .clear
            abandonButton.layer.borderWidth = 1
            abandonButton.layer.borderColor = Theme.Color.clay.cgColor
            abandonButton.removeTarget(nil, action: nil, for: .touchUpInside)
            abandonButton.addTarget(self, action: #selector(didTapAbandon), for: .touchUpInside)
            abandonButton.isHidden = false
        } else {
            // 未安排 / 已放弃：安排补课
            arrangeButton.setTitle("安排补课", for: .normal)
            arrangeButton.setTitleColor(.white, for: .normal)
            arrangeButton.backgroundColor = Theme.Color.brand
            arrangeButton.layer.borderWidth = 0
            arrangeButton.removeTarget(nil, action: nil, for: .touchUpInside)
            arrangeButton.addTarget(self, action: #selector(didTapArrange), for: .touchUpInside)
            abandonButton.isHidden = true
        }
    }

    @objc private func didTapArrange() { onArrange?() }
    @objc private func didTapAbandon() { onAbandon?() }
    @objc private func didTapComplete() { onComplete?() }
}
