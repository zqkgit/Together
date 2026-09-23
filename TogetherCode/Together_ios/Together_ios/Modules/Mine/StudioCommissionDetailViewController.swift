import UIKit
import SnapKit
import Kingfisher
import ESPullToRefresh

/// 工作室收益详情：按「课程」维度展示——在哪个课程推广、带来多少人报名、挣了多少佣金
/// 数据：GET /distribution/commission/records?studio_id=xx，前端按 course_id 分组
final class StudioCommissionDetailViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {

    /// 按课程聚合
    fileprivate struct CourseGroup {
        let course: CommissionRecordItem.CourseBrief?
        let items: [CommissionRecordItem]
        var count: Int { items.count }
        var total: Double { items.reduce(0) { $0 + ($1.amount ?? 0) } }
    }

    private let group: CommissionSummary.StudioGroup
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var courseGroups: [CourseGroup] = []
    private var hasLoaded = false

    private let bottomBar = UIView()
    private let actionButton = UIButton(type: .system)
    private var bottomTop: Constraint?

    init(group: CommissionSummary.StudioGroup) {
        self.group = group
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBottomBar()
        setupTableView()
        NotificationCenter.default.addObserver(
            self, selector: #selector(reload), name: .commissionUpdated, object: nil
        )
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: group.name ?? "工作室收益")
        loadData(silent: hasLoaded)
        hasLoaded = true
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    // MARK: - 布局

    private func setupTableView() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(StudioSummaryCell.self, forCellReuseIdentifier: StudioSummaryCell.reuseID)
        tableView.register(CourseCommissionCell.self, forCellReuseIdentifier: CourseCommissionCell.reuseID)
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(bottomBar.snp.top)
        }
        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.loadData(silent: true)
        }
    }

    private func setupBottomBar() {
        bottomBar.backgroundColor = Theme.Color.surface
        bottomBar.isHidden = true
        view.addSubview(bottomBar)
        bottomBar.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            self.bottomTop = $0.top.equalTo(view.safeAreaLayoutGuide.snp.bottom).constraint
        }
        let topLine = UIView()
        topLine.backgroundColor = Theme.Color.line
        bottomBar.addSubview(topLine)
        topLine.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(0.5)
        }
        actionButton.titleLabel?.font = .appSection(15)
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.backgroundColor = Theme.Color.brand
        actionButton.layer.cornerRadius = 22
        actionButton.addTarget(self, action: #selector(didTapAction), for: .touchUpInside)
        bottomBar.addSubview(actionButton)
        actionButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-Theme.Spacing.m)
            $0.height.equalTo(44)
        }
        updateBottomBar()
    }

    private func updateBottomBar() {
        let receivable = group.receivable ?? 0
        let show = receivable > 0
        bottomBar.isHidden = !show
        bottomTop?.update(offset: show ? -68 : 0)
        if show {
            actionButton.setTitle("一键领取 \(String(format: "¥%.2f", receivable))", for: .normal)
        }
        view.layoutIfNeeded()
    }

    // MARK: - 数据

    @objc private func reload() { loadData(silent: true) }

    private func loadData(silent: Bool) {
        if !silent { showLoading() }
        CommissionService.fetchRecords(studioId: group.studio_id) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            self.tableView.es.stopPullToRefresh()
            switch result {
            case .success(let records):
                self.buildGroups(records)
                self.tableView.reloadData()
            case .failure(let error):
                if !silent { self.showToast(error.message) }
            }
        }
    }

    private func buildGroups(_ records: [CommissionRecordItem]) {
        var order: [String] = []
        var map: [String: [CommissionRecordItem]] = [:]
        for item in records {
            let cid = item.course?.course_id ?? "unknown"
            if map[cid] == nil {
                map[cid] = []
                order.append(cid)
            }
            map[cid]?.append(item)
        }
        courseGroups = order.map {
            CourseGroup(course: map[$0]?.first?.course, items: map[$0] ?? [])
        }
    }

    // MARK: - TableView

    func numberOfSections(in tableView: UITableView) -> Int {
        1 + max(courseGroups.count, hasLoaded ? 1 : 0)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 1 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: StudioSummaryCell.reuseID, for: indexPath) as! StudioSummaryCell
            cell.configure(with: group)
            return cell
        }
        if courseGroups.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: CourseCommissionCell.reuseID, for: indexPath) as! CourseCommissionCell
            cell.configureEmpty()
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: CourseCommissionCell.reuseID, for: indexPath) as! CourseCommissionCell
        cell.configure(with: courseGroups[indexPath.section - 1])
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        indexPath.section == 0 ? 140 : 160
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 8 }
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        section == numberOfSections(in: tableView) - 1 ? 24 : 8
    }
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? { UIView() }
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { UIView() }

    @objc private func didTapAction() {
        startCommissionWithdraw(studioId: group.studio_id ?? "")
    }
}

// MARK: - 工作室汇总卡

private final class StudioSummaryCell: UITableViewCell {
    static let reuseID = "StudioSummaryCell"

    private let coverView = UIImageView()
    private let nameLabel = UILabel()
    private let statsRow = UIStackView()
    private let receivableCol = StatColumn()
    private let applyingCol = StatColumn()
    private let settledCol = StatColumn()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear

        let card = UIView()
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        card.layer.masksToBounds = true
        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.s)
        }

        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.spacing = Theme.Spacing.m
        card.addSubview(cardStack)
        cardStack.snp.makeConstraints { $0.edges.equalToSuperview().inset(Theme.Spacing.l) }

        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.spacing = Theme.Spacing.m
        headerRow.alignment = .center
        cardStack.addArrangedSubview(headerRow)

        coverView.contentMode = .scaleAspectFill
        coverView.backgroundColor = Theme.Color.brand
        coverView.layer.cornerRadius = 10
        coverView.layer.masksToBounds = true
        coverView.snp.makeConstraints { $0.size.equalTo(40) }
        headerRow.addArrangedSubview(coverView)

        nameLabel.font = .appSection(16)
        nameLabel.textColor = Theme.Color.ink
        headerRow.addArrangedSubview(nameLabel)

        let divider = UIView()
        divider.backgroundColor = Theme.Color.line
        divider.snp.makeConstraints { $0.height.equalTo(0.5) }
        cardStack.addArrangedSubview(divider)

        statsRow.axis = .horizontal
        statsRow.distribution = .fillEqually
        [receivableCol, applyingCol, settledCol].forEach { statsRow.addArrangedSubview($0) }
        cardStack.addArrangedSubview(statsRow)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with group: CommissionSummary.StudioGroup) {
        nameLabel.text = group.name ?? "工作室"
        if let cover = group.cover, let url = URL(string: cover.resolvedImageURL) {
            coverView.kf.setImage(with: url)
            coverView.backgroundColor = Theme.Color.woodSoft
        } else {
            coverView.image = UIImage(
                systemName: "building.2.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
            )
            coverView.tintColor = .white
            coverView.backgroundColor = Theme.Color.brand
        }
        let receivable = group.receivable ?? 0
        receivableCol.configure(value: receivable, title: "待申请", highlight: receivable > 0)
        applyingCol.configure(value: group.applying ?? 0, title: "申请中")
        settledCol.configure(value: group.settled ?? 0, title: "已到账")
    }
}

// MARK: - 课程佣金卡

private final class CourseCommissionCell: UITableViewCell {
    static let reuseID = "CourseCommissionCell"

    private let coverView = UIImageView()
    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    private let totalLabel = UILabel()
    private let recordsStack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.backgroundColor = .clear

        let card = UIView()
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        card.layer.masksToBounds = true
        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.s)
        }

        let cardStack = UIStackView()
        cardStack.axis = .vertical
        cardStack.spacing = Theme.Spacing.m
        card.addSubview(cardStack)
        cardStack.snp.makeConstraints { $0.edges.equalToSuperview().inset(Theme.Spacing.l) }

        // 课程头部
        let headerRow = UIStackView()
        headerRow.axis = .horizontal
        headerRow.spacing = Theme.Spacing.m
        headerRow.alignment = .center
        cardStack.addArrangedSubview(headerRow)

        coverView.contentMode = .scaleAspectFill
        coverView.backgroundColor = Theme.Color.brandSoft
        coverView.layer.cornerRadius = 10
        coverView.layer.masksToBounds = true
        coverView.snp.makeConstraints { $0.size.equalTo(44) }
        headerRow.addArrangedSubview(coverView)

        let titleBox = UIStackView()
        titleBox.axis = .vertical
        titleBox.spacing = 2
        headerRow.addArrangedSubview(titleBox)

        titleLabel.font = .appSection(15)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 1
        titleBox.addArrangedSubview(titleLabel)

        countLabel.font = .appBody(12)
        countLabel.textColor = Theme.Color.sub
        titleBox.addArrangedSubview(countLabel)

        totalLabel.font = .appHero(17)
        totalLabel.textColor = Theme.Color.clay
        totalLabel.textAlignment = .right
        totalLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        headerRow.addArrangedSubview(totalLabel)

        let divider = UIView()
        divider.backgroundColor = Theme.Color.line
        divider.snp.makeConstraints { $0.height.equalTo(0.5) }
        cardStack.addArrangedSubview(divider)

        // 明细行
        recordsStack.axis = .vertical
        cardStack.addArrangedSubview(recordsStack)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with courseGroup: StudioCommissionDetailViewController.CourseGroup) {
        titleLabel.text = courseGroup.course?.title ?? "未知课程"
        countLabel.text = "带来 \(courseGroup.count) 人报名"
        totalLabel.text = String(format: "¥%.2f", courseGroup.total)
        if let cover = courseGroup.course?.cover, let url = URL(string: cover.resolvedImageURL) {
            coverView.kf.setImage(with: url)
            coverView.backgroundColor = Theme.Color.brandSoft
        } else {
            coverView.image = UIImage(
                systemName: "book.closed.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .medium)
            )
            coverView.tintColor = Theme.Color.brand
            coverView.backgroundColor = Theme.Color.brandSoft
        }
        recordsStack.arrangedSubviews.forEach {
            recordsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        courseGroup.items.forEach { item in
            recordsStack.addArrangedSubview(RecordRow(item: item))
        }
    }

    func configureEmpty() {
        titleLabel.text = "暂无课程推广"
        countLabel.text = ""
        totalLabel.text = ""
        coverView.image = UIImage(
            systemName: "book.closed",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .medium)
        )
        coverView.tintColor = Theme.Color.muted
    }
}

// MARK: - 单笔佣金明细行

private final class RecordRow: UIView {
    init(item: CommissionRecordItem) {
        super.init(frame: .zero)

        let status = item.status ?? 0
        let tail = String((item.order_id ?? "").suffix(6))
        let orderLabel = UILabel()
        orderLabel.font = .appBody(12)
        orderLabel.textColor = Theme.Color.sub
        orderLabel.text = "订单 ****\(tail) · \(Int(item.rate ?? 0))% 返"

        let statusLabel = UILabel()
        statusLabel.font = .appLabel(11)
        statusLabel.textAlignment = .center
        statusLabel.text = item.status_text ?? ""
        switch status {
        case 1: statusLabel.textColor = Theme.Color.clay
        case 3: statusLabel.textColor = Theme.Color.info
        case 2: statusLabel.textColor = Theme.Color.success
        default: statusLabel.textColor = Theme.Color.sub
        }

        let amountLabel = UILabel()
        amountLabel.font = .appSection(14)
        amountLabel.textColor = Theme.Color.ink
        amountLabel.textAlignment = .right
        amountLabel.text = String(format: "¥%.2f", item.amount ?? 0)
        amountLabel.snp.makeConstraints { $0.width.equalTo(72) }

        let row = UIStackView(arrangedSubviews: [orderLabel, statusLabel, amountLabel])
        row.axis = .horizontal
        row.alignment = .center
        addSubview(row)
        row.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.leading.trailing.equalToSuperview()
        }
        snp.makeConstraints { $0.height.equalTo(34) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
