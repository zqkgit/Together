import UIKit
import SnapKit
import Kingfisher

/// 课时明细页：课时余额 + 消课记录（对齐小程序 child-balance）
final class ChildBalanceViewController: BaseViewController {

    private let childId: String
    private let childNickname: String

    // 数据
    private var balances: [ChildBalance] = []
    private var logs: [LessonLogItem] = []
    private var loading = true

    // 分段
    private let segmentControl = UISegmentedControl(items: ["课时余额", "消课记录"])
    private var currentTab = 0

    // 余额列表
    private lazy var balanceTableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.dataSource = self
        tv.delegate = self
        tv.register(BalanceCardCell.self, forCellReuseIdentifier: "BalanceCardCell")
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 140
        tv.contentInset = UIEdgeInsets(top: Theme.Spacing.m, left: 0, bottom: 0, right: 0)
        return tv
    }()

    // 消课记录列表
    private lazy var logsTableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.dataSource = self
        tv.delegate = self
        tv.register(LogItemCell.self, forCellReuseIdentifier: "LogItemCell")
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 72
        tv.isHidden = true
        tv.contentInset = UIEdgeInsets(top: Theme.Spacing.m, left: 0, bottom: 0, right: 0)
        return tv
    }()

    private let emptyView = EmptyStateView()

    init(childId: String, nickname: String) {
        self.childId = childId
        self.childNickname = nickname
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "课时明细"
        setupUI()
        loadData()
    }

    private func setupUI() {
        view.backgroundColor = Theme.Color.bg

        // 分段
        segmentControl.selectedSegmentTintColor = Theme.Color.brand
        segmentControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        segmentControl.setTitleTextAttributes([.foregroundColor: Theme.Color.ink], for: .normal)
        segmentControl.addTarget(self, action: #selector(tabChanged), for: .valueChanged)
        segmentControl.selectedSegmentIndex = 0
        view.addSubview(segmentControl)
        segmentControl.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(36)
        }

        view.addSubview(balanceTableView)
        balanceTableView.snp.makeConstraints {
            $0.top.equalTo(segmentControl.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        view.addSubview(logsTableView)
        logsTableView.snp.makeConstraints {
            $0.top.equalTo(segmentControl.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    @objc private func tabChanged() {
        currentTab = segmentControl.selectedSegmentIndex
        balanceTableView.isHidden = currentTab != 0
        logsTableView.isHidden = currentTab != 1
        if currentTab == 1 && logs.isEmpty { loadLogs() }
        updateEmptyState()
    }

    private func loadData() {
        loading = true
        ChildService.fetchChildBalances(childId: childId) { [weak self] result in
            guard let self else { return }
            self.loading = false
            switch result {
            case .success(let list):
                self.balances = list
                self.balanceTableView.reloadData()
            case .failure:
                break
            }
            self.updateEmptyState()
        }
    }

    private func loadLogs() {
        ChildService.fetchLessonLogs(childId: childId) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let list):
                self.logs = list
                self.logsTableView.reloadData()
            case .failure:
                break
            }
            self.updateEmptyState()
        }
    }

    private func updateEmptyState() {
        if currentTab == 0 && !loading && balances.isEmpty {
            emptyView.show(style: .empty("暂无课时包"))
            balanceTableView.backgroundView = emptyView
        } else {
            balanceTableView.backgroundView = nil
        }
        if currentTab == 1 && logs.isEmpty {
            emptyView.show(style: .empty("暂无消课记录"))
            logsTableView.backgroundView = emptyView
        } else {
            logsTableView.backgroundView = nil
        }
    }
}

// MARK: - Table DataSource / Delegate

extension ChildBalanceViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == balanceTableView { return balances.count }
        return logs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == balanceTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "BalanceCardCell", for: indexPath) as! BalanceCardCell
            cell.configure(with: balances[indexPath.row])
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "LogItemCell", for: indexPath) as! LogItemCell
        cell.configure(with: logs[indexPath.row])
        return cell
    }
}

// MARK: - 课时包卡片 Cell

final class BalanceCardCell: UITableViewCell {

    private let cardView = UIView()
    private let coverView = UIImageView()
    private let titleLabel = UILabel()
    private let studioLabel = UILabel()
    private let remainValueLabel = UILabel()
    private let totalValueLabel = UILabel()
    private let consumedValueLabel = UILabel()
    private let validLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        contentView.addSubview(cardView)
        cardView.backgroundColor = Theme.Color.surface
        cardView.layer.cornerRadius = Theme.Radius.card
        cardView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalToSuperview().offset(4)
            $0.bottom.equalToSuperview().offset(-4)
        }

        // 封面
        coverView.contentMode = .scaleAspectFill
        coverView.clipsToBounds = true
        coverView.layer.cornerRadius = Theme.Radius.icon
        coverView.snp.makeConstraints { $0.width.height.equalTo(48) }
        coverView.backgroundColor = Theme.Color.surfaceAlt

        let infoStack = UIStackView(arrangedSubviews: [titleLabel, studioLabel])
        infoStack.axis = .vertical
        infoStack.spacing = 2

        let courseRow = UIStackView(arrangedSubviews: [coverView, infoStack])
        courseRow.axis = .horizontal
        courseRow.spacing = Theme.Spacing.m
        courseRow.alignment = .center

        titleLabel.font = .appSection(15)
        titleLabel.textColor = Theme.Color.ink
        studioLabel.font = .appLabel(12)
        studioLabel.textColor = Theme.Color.sub

        // 三列统计
        func statCol(_ valueLabel: UILabel, _ labelText: String) -> UIStackView {
            valueLabel.font = .appHero(18)
            valueLabel.textAlignment = .center
            let l = UILabel()
            l.text = labelText
            l.font = .appLabel(11)
            l.textColor = Theme.Color.muted
            l.textAlignment = .center
            let stack = UIStackView(arrangedSubviews: [valueLabel, l])
            stack.axis = .vertical
            stack.spacing = 2
            stack.alignment = .center
            return stack
        }

        let statsStack = UIStackView(arrangedSubviews: [
            statCol(remainValueLabel, "剩余"),
            statCol(totalValueLabel, "总课时"),
            statCol(consumedValueLabel, "已消")
        ])
        statsStack.axis = .horizontal
        statsStack.distribution = .fillEqually

        // 有效期
        validLabel.font = .appLabel(11)
        validLabel.textColor = Theme.Color.muted
        validLabel.textAlignment = .left

        let mainStack = UIStackView(arrangedSubviews: [courseRow, statsStack, validLabel])
        mainStack.axis = .vertical
        mainStack.spacing = Theme.Spacing.m

        cardView.addSubview(mainStack)
        mainStack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(Theme.Spacing.cardInner)
        }
    }

    func configure(with b: ChildBalance) {
        titleLabel.text = b.course_title ?? "未命名课程"
        studioLabel.text = b.studio_name ?? ""

        if let cover = b.course_cover, cover.hasPrefix("http") {
            coverView.kf.setImage(with: URL(string: cover))
        } else {
            coverView.image = nil
            coverView.backgroundColor = Theme.Color.surfaceAlt
        }

        // 更新统计数字
        remainValueLabel.text = "\(b.remaining_lessons)"
        remainValueLabel.textColor = Theme.Color.brand
        totalValueLabel.text = "\(b.total_lessons)"
        totalValueLabel.textColor = Theme.Color.ink
        consumedValueLabel.text = "\(b.consumed_lessons)"
        consumedValueLabel.textColor = Theme.Color.ink

        if let validTo = b.valid_to, !validTo.isEmpty {
            let dateStr = String(validTo.prefix(10))
            validLabel.text = "有效期至 \(dateStr)"
            validLabel.isHidden = false
        } else {
            validLabel.isHidden = true
        }
    }
}

// MARK: - 消课记录 Cell

final class LogItemCell: UITableViewCell {

    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let subLabel = UILabel()
    private let deltaLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        contentView.addSubview(cardView)
        cardView.backgroundColor = Theme.Color.surface
        cardView.layer.cornerRadius = Theme.Radius.card
        cardView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalToSuperview().offset(4)
            $0.bottom.equalToSuperview().offset(-4)
        }

        titleLabel.font = .appSection(15)
        titleLabel.textColor = Theme.Color.ink

        subLabel.font = .appLabel(12)
        subLabel.textColor = Theme.Color.sub
        subLabel.numberOfLines = 2

        deltaLabel.font = .appSection(15)
        deltaLabel.textAlignment = .right

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subLabel])
        textStack.axis = .vertical
        textStack.spacing = 3

        let row = UIStackView(arrangedSubviews: [textStack, deltaLabel])
        row.axis = .horizontal
        row.spacing = Theme.Spacing.m
        row.alignment = .center

        cardView.addSubview(row)
        row.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(Theme.Spacing.cardInner)
        }

        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        deltaLabel.setContentHuggingPriority(.required, for: .horizontal)
        deltaLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    func configure(with log: LessonLogItem) {
        titleLabel.text = log.course_title ?? ""
        var parts = [String]()
        if let name = log.child_name, !name.isEmpty { parts.append(name) }
        if let studio = log.studio_name, !studio.isEmpty { parts.append(studio) }
        if let date = log.lesson_date, !date.isEmpty {
            parts.append(date)
            if let time = log.start_time, !time.isEmpty { parts.append(time) }
        }
        if log.is_makeup == true { parts.append("补课") }
        subLabel.text = parts.joined(separator: " · ")

        if let delta = log.delta {
            deltaLabel.text = delta > 0 ? "+\(delta) 课时" : "\(delta) 课时"
            deltaLabel.textColor = delta > 0 ? Theme.Color.brand : Theme.Color.danger
        } else {
            deltaLabel.text = ""
        }
    }
}