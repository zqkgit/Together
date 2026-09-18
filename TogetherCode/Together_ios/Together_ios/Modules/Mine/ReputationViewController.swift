import UIKit
import SnapKit

/// 评价与口碑：老师名下课程收到的评价聚合（均分 + 星级分布 + 评价列表）
final class ReputationViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .grouped)
    private let headerView = UIView()
    private let overviewView = ReviewOverviewView()

    private var data: TeacherReviewData?
    private var reviews: [TeacherReviewItem] = []
    private var loading = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        configureImmersiveNav(title: "评价与口碑")
        setupUI()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "评价与口碑")
        if !reviews.isEmpty { loadData() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    private func setupUI() {
        // 固定概览头部（从 safeArea 开始，与课表/我的学生布局一致）
        headerView.backgroundColor = Theme.Color.bg
        view.addSubview(headerView)
        headerView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(120)
        }

        headerView.addSubview(overviewView)
        overviewView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview()
        }

        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.register(ReviewRowCell.self, forCellReuseIdentifier: ReviewRowCell.reuseID)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.estimatedRowHeight = 120
        tableView.rowHeight = UITableView.automaticDimension
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(headerView.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func loadData() {
        guard !loading else { return }
        loading = true
        TeacherService.fetchTeacherReviews { [weak self] result in
            guard let self else { return }
            self.loading = false
            switch result {
            case .success(let data):
                self.data = data
                self.reviews = data.list ?? []
                self.overviewView.configure(data: data, total: data.total)
                self.tableView.reloadData()
            case .failure(let error):
                self.showToast(error.message ?? "加载失败")
            }
        }
    }

    // MARK: - TableView

    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        reviews.isEmpty ? 0 : 36
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !reviews.isEmpty else { return UIView(frame: .zero) }
        let label = UILabel()
        label.font = .appSection(14)
        label.textColor = Theme.Color.ink
        label.text = "全部评价"
        let wrap = UIView()
        wrap.backgroundColor = .clear
        label.frame = CGRect(x: Theme.Spacing.l, y: 12, width: 300, height: 24)
        wrap.addSubview(label)
        return wrap
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(reviews.count, 1)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard !reviews.isEmpty else {
            let cell = UITableViewCell(style: .default, reuseIdentifier: "empty")
            cell.backgroundColor = Theme.Color.bg
            cell.textLabel?.text = "还没有收到评价"
            cell.textLabel?.font = .appBody(14)
            cell.textLabel?.textColor = Theme.Color.muted
            cell.textLabel?.textAlignment = .center
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: ReviewRowCell.reuseID, for: indexPath) as! ReviewRowCell
        cell.configure(reviews[indexPath.row])
        return cell
    }
}

// MARK: - 概览卡（均分 + 星级分布）

private final class ReviewOverviewView: UIView {

    private let container = UIView()
    private let averageLabel = UILabel()
    private let totalLabel = UILabel()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        container.backgroundColor = Theme.Color.surface
        container.layer.cornerRadius = Theme.Radius.card
        addSubview(container)
        container.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        // 左侧：均分
        let leftWrap = UIView()
        container.addSubview(leftWrap)
        leftWrap.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
        }

        averageLabel.font = .systemFont(ofSize: 40, weight: .bold)
        averageLabel.textColor = Theme.Color.brand
        averageLabel.text = "--"
        leftWrap.addSubview(averageLabel)
        averageLabel.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
        }

        totalLabel.font = .appBody(12)
        totalLabel.textColor = Theme.Color.sub
        totalLabel.text = "共 0 条评价"
        leftWrap.addSubview(totalLabel)
        totalLabel.snp.makeConstraints {
            $0.top.equalTo(averageLabel.snp.bottom).offset(6)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        // 右侧：星级分布条
        stack.axis = .vertical
        stack.spacing = 6
        container.addSubview(stack)
        stack.snp.makeConstraints {
            $0.leading.equalTo(leftWrap.snp.trailing).offset(Theme.Spacing.xl)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(data: TeacherReviewData?, total: Int?) {
        guard let data else {
            averageLabel.text = "--"
            totalLabel.text = "共 0 条评价"
            stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for _ in 1...5 {
                let row = DistributionRow()
                row.configure(star: 0, count: 0, total: 0)
                stack.addArrangedSubview(row)
            }
            return
        }
        let avg = data.average ?? 0
        averageLabel.text = String(format: "%.1f", avg)
        totalLabel.text = "共 \(total ?? data.total ?? 0) 条评价"

        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let dist = data.rating_distribution ?? [:]
        let sum = dist.values.reduce(0, +)
        for star in stride(from: 5, through: 1, by: -1) {
            let row = DistributionRow()
            row.configure(star: star, count: dist[String(star)] ?? 0, total: sum)
            stack.addArrangedSubview(row)
        }
    }
}

/// 单行分布：★5 [bar] 1条
private final class DistributionRow: UIView {

    private let starLabel = UILabel()
    private let bar = UIView()
    private let fill = UIView()
    private let countLabel = UILabel()

    init() {
        super.init(frame: .zero)
        snp.makeConstraints { $0.height.equalTo(12) }

        starLabel.font = .appBody(11)
        starLabel.textColor = Theme.Color.wood
        addSubview(starLabel)
        starLabel.snp.makeConstraints {
            $0.leading.centerY.equalToSuperview()
            $0.width.equalTo(18)
        }

        countLabel.font = .appBody(11)
        countLabel.textColor = Theme.Color.sub
        addSubview(countLabel)
        countLabel.snp.makeConstraints {
            $0.trailing.centerY.equalToSuperview()
            $0.width.equalTo(40)
        }

        bar.backgroundColor = Theme.Color.surfaceAlt
        bar.layer.cornerRadius = 3
        bar.clipsToBounds = true
        addSubview(bar)
        bar.snp.makeConstraints {
            $0.leading.equalTo(starLabel.snp.trailing).offset(6)
            $0.trailing.equalTo(countLabel.snp.leading).offset(-6)
            $0.centerY.equalToSuperview()
            $0.height.equalTo(6)
        }

        fill.backgroundColor = Theme.Color.brand
        bar.addSubview(fill)
        fill.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
            $0.width.equalTo(0)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(star: Int, count: Int, total: Int) {
        starLabel.text = "\(star)"
        countLabel.text = "\(count)条"
        let ratio = total > 0 ? CGFloat(count) / CGFloat(total) : 0
        fill.snp.remakeConstraints {
            $0.leading.top.bottom.equalToSuperview()
            $0.width.equalToSuperview().multipliedBy(ratio)
        }
    }
}

// MARK: - 评价卡

private final class ReviewRowCell: UITableViewCell {

    static let reuseID = "ReviewRowCell"

    private let container = UIView()
    private let avatarView = UIView()
    private let avatarLabel = UILabel()
    private let nameLabel = UILabel()
    private let timeLabel = UILabel()
    private let starsLabel = UILabel()
    private let courseLabel = UILabel()
    private let contentLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.bg
        selectionStyle = .none

        container.backgroundColor = Theme.Color.surface
        container.layer.cornerRadius = Theme.Radius.card
        contentView.addSubview(container)
        container.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.s)
        }

        avatarView.backgroundColor = Theme.Color.surfaceAlt
        avatarView.layer.cornerRadius = 18
        avatarView.clipsToBounds = true
        container.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.leading.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.width.height.equalTo(36)
        }

        avatarLabel.font = .appBody(15)
        avatarLabel.textColor = Theme.Color.wood
        avatarLabel.textAlignment = .center
        avatarView.addSubview(avatarLabel)
        avatarLabel.snp.makeConstraints { $0.edges.equalToSuperview() }

        nameLabel.font = .appBody(14)
        nameLabel.textColor = Theme.Color.ink
        container.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarView.snp.trailing).offset(Theme.Spacing.m)
            $0.top.equalTo(avatarView)
            $0.trailing.lessThanOrEqualToSuperview().inset(Theme.Spacing.l)
        }

        timeLabel.font = .appBody(11)
        timeLabel.textColor = Theme.Color.sub
        container.addSubview(timeLabel)
        timeLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalTo(nameLabel)
        }

        starsLabel.font = .appBody(13)
        starsLabel.textColor = Theme.Color.wood
        container.addSubview(starsLabel)
        starsLabel.snp.makeConstraints {
            $0.leading.equalTo(nameLabel)
            $0.top.equalTo(nameLabel.snp.bottom).offset(4)
        }

        courseLabel.font = .appBody(11)
        courseLabel.textColor = Theme.Color.sub
        container.addSubview(courseLabel)
        courseLabel.snp.makeConstraints {
            $0.leading.equalTo(starsLabel.snp.trailing).offset(Theme.Spacing.s)
            $0.centerY.equalTo(starsLabel)
            $0.trailing.lessThanOrEqualToSuperview().inset(Theme.Spacing.l)
        }

        contentLabel.font = .appBody(13)
        contentLabel.textColor = Theme.Color.ink
        contentLabel.numberOfLines = 0
        container.addSubview(contentLabel)
        contentLabel.snp.makeConstraints {
            $0.top.equalTo(starsLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalTo(nameLabel)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ review: TeacherReviewItem) {
        let nickname = review.user?.nickname ?? "家长"
        nameLabel.text = nickname
        avatarLabel.text = String(nickname.prefix(1))
        timeLabel.text = review.timeText
        starsLabel.text = review.starsText
        courseLabel.text = review.course?.title
        contentLabel.text = review.content
    }
}
