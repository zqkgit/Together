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
            cell.configure(schedules[indexPath.row])
        }
        return cell
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
    private let subtitleLabel = UILabel()
    private let timeLabel = UILabel()
    private let statusLabel = UILabel()

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

        subtitleLabel.font = .appLabel(13)
        subtitleLabel.textColor = Theme.Color.sub
        subtitleLabel.numberOfLines = 1
        card.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(5)
            $0.leading.equalTo(titleLabel)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }

        timeLabel.font = .appLabel(13)
        timeLabel.textColor = Theme.Color.sub
        timeLabel.numberOfLines = 1
        card.addSubview(timeLabel)
        timeLabel.snp.makeConstraints {
            $0.centerY.equalTo(subtitleLabel)
            $0.leading.equalTo(subtitleLabel.snp.trailing).offset(Theme.Spacing.m)
            $0.trailing.lessThanOrEqualToSuperview().inset(84)
        }

        statusLabel.font = .appLabel(12)
        statusLabel.textAlignment = .center
        statusLabel.layer.cornerRadius = 11
        statusLabel.layer.masksToBounds = true
        statusLabel.setContentHuggingPriority(.required, for: .horizontal)
        card.addSubview(statusLabel)
        statusLabel.snp.makeConstraints {
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
        statusLabel.isHidden = false
        let consumed = summary?.consumed_lessons ?? 0
        let total = summary?.total_lessons ?? 0
        statusLabel.text = "已学\(consumed)/\(total)节"
        statusLabel.textColor = Theme.Color.brand
        statusLabel.backgroundColor = Theme.Color.brandSoft
        statusLabel.snp.updateConstraints {
            $0.width.equalTo(76)
        }
        titleLabel.snp.updateConstraints {
            $0.trailing.lessThanOrEqualToSuperview().inset(84)
        }
    }

    /// 课时：第X课·名称 + 日期 + 时间 + 状态
    func configure(_ item: CourseScheduleItem) {
        titleLabel.font = .appSection(15)
        let no = item.lesson_no ?? 0
        titleLabel.text = "第\(no)课·\(item.lesson_title ?? "课程")"
        subtitleLabel.text = item.lesson_date?.mmddText
        timeLabel.text = item.start_time ?? ""
        statusLabel.isHidden = false
        statusLabel.snp.updateConstraints {
            $0.width.equalTo(48)
        }
        switch item.status {
        case 1:
            statusLabel.text = "已上"
            statusLabel.textColor = Theme.Color.brand
            statusLabel.backgroundColor = Theme.Color.brandSoft
        case 2:
            statusLabel.text = "今天"
            statusLabel.textColor = Theme.Color.brandDark
            statusLabel.backgroundColor = Theme.Color.brandSoft
        default:
            statusLabel.text = "待上"
            statusLabel.textColor = Theme.Color.sub
            statusLabel.backgroundColor = Theme.Color.surfaceAlt
        }
        titleLabel.snp.updateConstraints {
            $0.trailing.lessThanOrEqualToSuperview().inset(84)
        }
    }
}
