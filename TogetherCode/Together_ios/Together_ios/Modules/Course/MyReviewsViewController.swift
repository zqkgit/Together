import UIKit
import SnapKit
import Kingfisher
import ESPullToRefresh

/// 我的评价（对齐小程序「我的评价」）：课程名 + 评分 + 状态标签 + 内容 + 双回复
/// 待审核 / 已驳回 可点击编辑
final class MyReviewsViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {

    private var items: [MyReviewItem] = []
    private var page = 1
    private var hasMore = true
    private var isLoading = false

    private lazy var tableView = UITableView(frame: .zero, style: .plain)
    private let emptyView = EmptyStateView()
    private var footerSpinner: UIActivityIndicatorView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        setupTableView()
        loadData(reset: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "我的评价")
        // 编辑/发布后返回时刷新
        reloadList()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    private func setupTableView() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.alwaysBounceVertical = true
        tableView.estimatedRowHeight = 160
        tableView.rowHeight = UITableView.automaticDimension
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(MyReviewCell.self, forCellReuseIdentifier: MyReviewCell.reuseID)
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.loadData(reset: true)
        }

        let footer = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        let spin = UIActivityIndicatorView(style: .medium)
        spin.color = Theme.Color.muted
        footer.addSubview(spin)
        spin.snp.makeConstraints { $0.center.equalToSuperview() }
        footerSpinner = spin
        tableView.tableFooterView = footer

        view.addSubview(emptyView)
        emptyView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func reloadList() {
        loadData(reset: true)
    }

    // MARK: - Data

    private func loadData(reset: Bool) {
        guard !isLoading else { return }
        isLoading = true
        let targetPage = reset ? 1 : page + 1
        if reset {
            emptyView.show(style: .loading)
            emptyView.isHidden = false
        }
        if !reset { footerSpinner?.startAnimating() }

        MineService.fetchMyReviews(page: targetPage) { [weak self] list, more, error in
            guard let self else { return }
            self.isLoading = false
            self.tableView.es.stopPullToRefresh()
            self.footerSpinner?.stopAnimating()

            if let error {
                self.emptyView.show(style: .error(error) { [weak self] in
                    self?.loadData(reset: true)
                })
                self.emptyView.isHidden = false
                return
            }
            if let list {
                if reset {
                    self.items = list
                    self.page = 1
                } else {
                    self.items.append(contentsOf: list)
                    self.page = targetPage
                }
                self.hasMore = more
            }
            self.emptyView.isHidden = !self.items.isEmpty
            self.tableView.reloadData()
        }
    }

    // MARK: - TableView

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: MyReviewCell.reuseID, for: indexPath) as! MyReviewCell
        cell.configure(item: items[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        // 待审核 / 已驳回可编辑
        if (item.status ?? 0) == 1 { return }
        let vc = ReviewComposeViewController(review: item)
        navigationController?.pushViewController(vc, animated: true)
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row == items.count - 3 && hasMore && !isLoading {
            loadData(reset: false)
        }
    }
}

/// 我的评价卡片（对齐小程序）
final class MyReviewCell: UITableViewCell {
    static let reuseID = "MyReviewCell"

    private let cardView = UIView()
    private let courseLabel = UILabel()
    private let starLabel = UILabel()
    private let statusLabel = UILabel()
    private let contentLabel = UILabel()
    private let replyStack = UIStackView()
    private let studioReplyView = ReviewReplyView(tag: "工作室", tagColor: Theme.Color.info, tintColor: Theme.Color.infoTint)
    private let teacherReplyView = ReviewReplyView(tag: "老师", tagColor: Theme.Color.violet, tintColor: Theme.Color.violetTint)
    private let timeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        cardView.backgroundColor = Theme.Color.surface
        cardView.layer.cornerRadius = Theme.Radius.card
        cardView.clipsToBounds = true
        contentView.addSubview(cardView)
        cardView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.s)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }

        courseLabel.font = .appBody(15)
        courseLabel.textColor = Theme.Color.ink
        courseLabel.numberOfLines = 1
        cardView.addSubview(courseLabel)
        courseLabel.snp.makeConstraints {
            $0.top.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.trailing.lessThanOrEqualToSuperview().inset(Theme.Spacing.l)
        }

        starLabel.font = .appBody(14)
        starLabel.textColor = Theme.Color.clay
        cardView.addSubview(starLabel)
        starLabel.snp.makeConstraints {
            $0.leading.equalTo(courseLabel)
            $0.top.equalTo(courseLabel.snp.bottom).offset(Theme.Spacing.s)
        }

        statusLabel.font = .appLabel(11)
        statusLabel.layer.cornerRadius = 4
        statusLabel.layer.masksToBounds = true
        statusLabel.textAlignment = .center
        cardView.addSubview(statusLabel)
        statusLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalTo(starLabel)
            $0.width.equalTo(52)
            $0.height.equalTo(20)
        }

        contentLabel.font = .appBody(14)
        contentLabel.textColor = Theme.Color.ink
        contentLabel.numberOfLines = 0
        cardView.addSubview(contentLabel)
        contentLabel.snp.makeConstraints {
            $0.top.equalTo(starLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        replyStack.axis = .vertical
        replyStack.spacing = 8
        replyStack.addArrangedSubview(studioReplyView)
        replyStack.addArrangedSubview(teacherReplyView)
        cardView.addSubview(replyStack)
        replyStack.snp.makeConstraints {
            $0.top.equalTo(contentLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        timeLabel.font = .appLabel(11)
        timeLabel.textColor = Theme.Color.muted
        cardView.addSubview(timeLabel)
        timeLabel.snp.makeConstraints {
            $0.top.equalTo(replyStack.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    func configure(item: MyReviewItem) {
        courseLabel.text = item.course?.title ?? "课程评价"
        let rating = item.rating ?? 5
        starLabel.text = String(repeating: "★", count: rating) + String(repeating: "☆", count: 5 - rating)
        contentLabel.text = item.content
        timeLabel.text = item.timeText

        // 状态：1 已通过（绿）/ 0 待审核（橙）/ 2 已驳回（红）
        switch item.status ?? 0 {
        case 1:
            statusLabel.text = "已通过"
            statusLabel.textColor = Theme.Color.success
            statusLabel.backgroundColor = Theme.Color.successTint
        case 2:
            statusLabel.text = "已驳回"
            statusLabel.textColor = Theme.Color.danger
            statusLabel.backgroundColor = Theme.Color.dangerTint
        default:
            statusLabel.text = "待审核"
            statusLabel.textColor = Theme.Color.warn
            statusLabel.backgroundColor = Theme.Color.warnTint
        }

        studioReplyView.isHidden = (item.reply_content ?? "").isEmpty
        studioReplyView.set(text: item.reply_content)
        teacherReplyView.isHidden = (item.teacher_reply_content ?? "").isEmpty
        teacherReplyView.set(text: item.teacher_reply_content)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
