import UIKit
import SnapKit
import ESPullToRefresh

/// 老师课表（周视图，对齐 PR：#timetable）
/// 顶部：周切换（‹ 周一~周日 ›，选中日绿色高亮）
/// 列表：当天排课（时间 / 课程·班级 / 教室·学生数 / 消课状态标签）
/// 仅查看：不提供新增排课入口（新增在工作室 Web 端）
final class TeacherTimetableViewController: BaseViewController {

    // MARK: - 状态

    /// 当前选中日期（YYYY-MM-dd）
    private var selectedDate = Date()
    private var items: [TeacherTimetableItem] = []
    private var loading = false

    // MARK: - UI 组件

    private let headerView = UIView()
    private let weekStack = UIStackView()
    private var dayButtons: [UIButton] = []
    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let emptyLabel = UILabel()

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        setupUI()
        rebuildWeekBar()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "课表与排课")
        // 从排课详情操作（消课/撤销）返回后刷新当天课表状态
        loadData()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    // MARK: - UI

    private func setupUI() {
        // 周切换头部（仅本周周一~周日，无左右翻周箭头）
        headerView.backgroundColor = Theme.Color.bg
        view.addSubview(headerView)
        headerView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(88)
        }

        weekStack.axis = .horizontal
        weekStack.distribution = .fillEqually
        weekStack.alignment = .fill
        headerView.addSubview(weekStack)
        weekStack.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }

        // 列表
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.register(TimetableDayCell.self, forCellReuseIdentifier: "TimetableDayCell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.loadData()
        }
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 24, right: 0)
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(headerView.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        // 空态
        emptyLabel.text = "当天没有排课，休息一下吧"
        emptyLabel.font = .appBody(14)
        emptyLabel.textColor = Theme.Color.muted
        emptyLabel.textAlignment = .center
        view.addSubview(emptyLabel)
        emptyLabel.snp.makeConstraints {
            $0.center.equalTo(tableView)
        }
        emptyLabel.isHidden = true
    }

    /// 重建周栏（周一~周日 7 天 + 选中高亮）
    private func rebuildWeekBar() {
        weekStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        dayButtons = []

        let weekDays = currentWeekDays()
        for (index, day) in weekDays.enumerated() {
            let button = DayButton()
            button.weekdayText = Self.weekdayNames[index]
            button.dayText = String(Calendar.current.component(.day, from: day))
            button.isSelected = Calendar.current.isDate(day, inSameDayAs: selectedDate)
            button.tag = index
            button.addTarget(self, action: #selector(didTapDay(_:)), for: .touchUpInside)
            weekStack.addArrangedSubview(button)
            dayButtons.append(button)
        }
    }

    private static let weekdayNames = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]

    /// 当前周的周一~周日
    private func currentWeekDays() -> [Date] {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today) // 1 周日 ... 7 周六
        let mondayOffset = (weekday + 5) % 7 // 距周一
        let monday = calendar.date(byAdding: .day, value: -mondayOffset, to: today)!
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: monday)
        }
    }

    /// 选中日期对应周偏移的日期
    private func dateForSelectedDay() -> Date {
        let weekDays = currentWeekDays()
        let index = min(max(selectedDayIndex, 0), 6)
        return weekDays[index]
    }

    private var selectedDayIndex: Int {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: selectedDate)
        return (weekday + 5) % 7
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - 动作

    @objc private func didTapDay(_ sender: UIButton) {
        let weekDays = currentWeekDays()
        selectedDate = weekDays[sender.tag]
        rebuildWeekBar()
        loadData()
    }

    // MARK: - 数据

    private func loadData() {
        guard !loading else { return }
        loading = true
        PostService.fetchTeacherTimetable(date: dateString(dateForSelectedDay())) { [weak self] result in
            guard let self else { return }
            self.loading = false
            self.tableView.es.stopPullToRefresh()
            switch result {
            case .success(let list):
                self.items = list
                self.emptyLabel.isHidden = !list.isEmpty
                self.tableView.reloadData()
            case .failure(let error):
                self.items = []
                self.tableView.reloadData()
                self.emptyLabel.isHidden = true
                self.showToast(error.localizedDescription)
            }
        }
    }
}

// MARK: - 周栏日按钮

private final class DayButton: UIButton {
    private let weekdayLabel = UILabel()
    private let dayLabel = UILabel()

    var weekdayText: String = "" {
        didSet { weekdayLabel.text = weekdayText }
    }

    var dayText: String = "" {
        didSet { dayLabel.text = dayText }
    }

    override var isSelected: Bool {
        didSet {
            updateStyle()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        weekdayLabel.font = .appBody(12)
        weekdayLabel.textAlignment = .center
        dayLabel.font = .appBody(15)
        dayLabel.textAlignment = .center
        addSubview(weekdayLabel)
        addSubview(dayLabel)
        weekdayLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(10)
            $0.centerX.equalToSuperview()
        }
        dayLabel.snp.makeConstraints {
            $0.top.equalTo(weekdayLabel.snp.bottom).offset(4)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(30)
        }
        updateStyle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func updateStyle() {
        if isSelected {
            weekdayLabel.textColor = Theme.Color.brand
            dayLabel.textColor = .white
            dayLabel.backgroundColor = Theme.Color.brand
            dayLabel.layer.cornerRadius = 15
            dayLabel.clipsToBounds = true
        } else {
            weekdayLabel.textColor = Theme.Color.muted
            dayLabel.textColor = Theme.Color.ink
            dayLabel.backgroundColor = .clear
            dayLabel.layer.cornerRadius = 0
        }
    }
}

// MARK: - 排课 cell

final class TimetableDayCell: UITableViewCell {

    private let container = UIView()
    private let timeLabel = UILabel()
    private let durationLabel = UILabel()
    private let titleLabel = UILabel()
    private let metaLabel = UILabel()
    private let statusView = UIView()
    private let statusLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        // 卡片容器：左右统一 12pt，上下留 8pt 组间距
        container.backgroundColor = Theme.Color.surface
        container.layer.cornerRadius = Theme.Radius.card
        contentView.addSubview(container)
        container.snp.makeConstraints {
            $0.top.equalToSuperview().inset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.s)
        }

        // 左：时间
        timeLabel.font = .appSection(16)
        timeLabel.textColor = Theme.Color.ink
        container.addSubview(timeLabel)
        timeLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.equalToSuperview().offset(Theme.Spacing.m)
        }

        durationLabel.font = .appBody(11)
        durationLabel.textColor = Theme.Color.muted
        container.addSubview(durationLabel)
        durationLabel.snp.makeConstraints {
            $0.top.equalTo(timeLabel.snp.bottom).offset(4)
            $0.leading.equalTo(timeLabel)
        }

        // 右：状态标签
        statusView.layer.cornerRadius = 10
        statusView.clipsToBounds = true
        container.addSubview(statusView)
        statusView.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.m)
            $0.centerY.equalToSuperview()
        }

        statusLabel.font = .appBody(11)
        statusView.addSubview(statusLabel)
        statusLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(3)
            $0.bottom.equalToSuperview().offset(-3)
            $0.leading.equalToSuperview().offset(8)
            $0.trailing.equalToSuperview().offset(-8)
        }

        // 中：课程·班级 / 教室·学生
        titleLabel.font = .appSection(15)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 1
        container.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.equalTo(timeLabel.snp.trailing).offset(Theme.Spacing.m)
            $0.trailing.lessThanOrEqualTo(statusView.snp.leading).offset(-Theme.Spacing.m)
        }

        metaLabel.font = .appBody(11)
        metaLabel.textColor = Theme.Color.sub
        metaLabel.numberOfLines = 1
        container.addSubview(metaLabel)
        metaLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(4)
            $0.leading.equalTo(titleLabel)
            $0.trailing.lessThanOrEqualTo(statusView.snp.leading).offset(-Theme.Spacing.m)
        }

        // 底部留白（容器内最后一行下方）
        metaLabel.snp.makeConstraints {
            $0.bottom.lessThanOrEqualToSuperview().offset(-Theme.Spacing.m).priority(.low)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with item: TeacherTimetableItem) {
        timeLabel.text = item.start_time.map { String($0.prefix(5)) } ?? "--:--"
        let duration = item.course?.duration_min
        durationLabel.text = duration.map { "\($0)分钟" } ?? "60分钟"

        let courseTitle = item.course?.title ?? "课程"
        let className = item.class?.name ?? ""
        titleLabel.text = className.isEmpty ? courseTitle : "\(courseTitle) · \(className)"

        let location = item.location ?? "教室"
        let studentCount = item.student_count ?? 0
        let studio = (item.studio_name?.isEmpty == false) ? "\(item.studio_name!) · " : ""
        metaLabel.text = "\(studio)\(location) · \(studentCount)名学生"

        // 消课状态
        let statusText = item.consumeText ?? "待消课"
        statusLabel.text = statusText
        switch item.consume_status {
        case "completed":
            statusView.backgroundColor = Theme.Color.successTint
            statusLabel.textColor = Theme.Color.success
        case "partial":
            statusView.backgroundColor = Theme.Color.warnTint
            statusLabel.textColor = Theme.Color.warn
        default:
            statusView.backgroundColor = Theme.Color.surfaceAlt
            statusLabel.textColor = Theme.Color.muted
        }
    }
}

// MARK: - UITableView

extension TeacherTimetableViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TimetableDayCell", for: indexPath) as! TimetableDayCell
        cell.selectionStyle = .none
        cell.configure(with: items[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        84
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = items[indexPath.row]
        let detail = ScheduleDetailViewController(schedule: item)
        navigationController?.pushViewController(detail, animated: true)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        nil
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        CGFloat.leastNormalMagnitude
    }
}
