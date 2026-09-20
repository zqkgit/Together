import UIKit
import SnapKit
import ESPullToRefresh

/// 课程完整评价列表（课程详情「查看全部」进入）
final class CourseReviewsViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {

    private let courseId: String
    private var items: [CourseReviewItem] = []
    private var page = 1
    private var hasMore = true
    private var isLoading = false

    private lazy var tableView = UITableView(frame: .zero, style: .plain)
    private let emptyView = EmptyStateView()
    private var footerSpinner: UIActivityIndicatorView?

    init(courseId: String) {
        self.courseId = courseId
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        setupTableView()
        loadData(reset: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "课程评价")
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
        tableView.estimatedRowHeight = 140
        tableView.rowHeight = UITableView.automaticDimension
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(CourseReviewCell.self, forCellReuseIdentifier: CourseReviewCell.reuseID)
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

        CourseService.fetchCourseReviews(courseId: courseId, page: targetPage) { [weak self] list, more, error in
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
        let cell = tableView.dequeueReusableCell(withIdentifier: CourseReviewCell.reuseID, for: indexPath) as! CourseReviewCell
        cell.configure(review: items[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row == items.count - 3 && hasMore && !isLoading {
            loadData(reset: false)
        }
    }
}
