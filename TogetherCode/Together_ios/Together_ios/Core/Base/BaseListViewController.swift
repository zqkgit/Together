import UIKit
import SnapKit
import ESPullToRefresh

/// 通用分页列表基类：下拉刷新 + 上拉分页 + 空态/错误重试
/// 子类继承并实现 fetchPage / reuseIdentifier / configure(cell:item:at:)
class BaseListViewController<Item>: BaseViewController, UITableViewDataSource, UITableViewDelegate {

    let tableView = UITableView(frame: .zero, style: .plain)
    private(set) var items: [Item] = []
    private(set) var page = 1
    let pageSize = 20
    private(set) var hasMore = true
    private(set) var isLoading = false

    private let emptyView = EmptyStateView()
    private var footerSpinner: UIActivityIndicatorView?

    // MARK: - 子类接口

    /// 拉取一页数据；completion: (列表, 是否还有更多, 错误信息)
    func fetchPage(page: Int, completion: @escaping ([Item]?, Bool, String?) -> Void) {
        completion(nil, false, "未实现 fetchPage")
    }

    /// cell 复用标识
    func reuseIdentifier(for item: Item) -> String { "BaseCell" }

    /// 配置 cell 内容
    func configure(cell: UITableViewCell, item: Item, at indexPath: IndexPath) {}

    /// 行高（默认自动）
    func cellHeight(for item: Item, at indexPath: IndexPath) -> CGFloat {
        UITableView.automaticDimension
    }

    /// cell 点击（可选）
    func didSelect(item: Item, at indexPath: IndexPath) {}

    /// 注册 cell
    func registerCell(_ cellClass: UITableViewCell.Type, reuseId: String) {
        tableView.register(cellClass, forCellReuseIdentifier: reuseId)
    }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        reload(showLoading: true)
    }

    private func setupTableView() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.alwaysBounceHorizontal = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        // 底部 Tab 占位；左右边距统一由 cell 内容 inset 12 承担
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 120, right: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.reload(showLoading: false)
        }
        view.addSubview(tableView)
        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }

        // 底部加载指示器
        let footer = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        let spin = UIActivityIndicatorView(style: .medium)
        spin.color = Theme.Color.brand
        footer.addSubview(spin)
        spin.snp.makeConstraints { $0.center.equalToSuperview() }
        footerSpinner = spin
        tableView.tableFooterView = footer

        view.addSubview(emptyView)
        emptyView.snp.makeConstraints { $0.edges.equalToSuperview() }
        emptyView.isHidden = true
    }

    // MARK: - 数据加载

    /// 拉取第一页（下拉刷新复用）
    func reload(showLoading: Bool = true) {
        guard !isLoading else {
            tableView.es.stopPullToRefresh()
            return
        }
        isLoading = true
        if showLoading { showEmpty(.loading) }

        fetchPage(page: 1) { [weak self] list, hasMore, error in
            guard let self else { return }
            self.isLoading = false
            self.tableView.es.stopPullToRefresh()
            self.footerSpinner?.stopAnimating()

            if let error {
                if self.items.isEmpty {
                    self.showEmpty(.error(error, retry: { [weak self] in self?.reload(showLoading: true) }))
                } else {
                    self.hideEmpty()
                    self.showToast(error)
                }
                return
            }
            self.items = list ?? []
            self.page = 1
            self.hasMore = hasMore
            self.tableView.reloadData()
            self.updateEmptyState()
        }
    }

    /// 加载下一页（滚动接近底部触发）
    func loadNextPage() {
        guard !isLoading, hasMore, !items.isEmpty else { return }
        isLoading = true
        footerSpinner?.startAnimating()

        fetchPage(page: page + 1) { [weak self] list, hasMore, error in
            guard let self else { return }
            self.isLoading = false
            self.footerSpinner?.stopAnimating()

            if let error {
                self.showToast(error)
                return
            }
            self.page += 1
            self.hasMore = hasMore
            let newItems = list ?? []
            self.items.append(contentsOf: newItems)
            self.tableView.reloadData()
            self.updateEmptyState()
        }
    }

    private func updateEmptyState() {
        if items.isEmpty {
            showEmpty(.empty("暂无内容"))
        } else {
            hideEmpty()
        }
    }

    private func showEmpty(_ style: EmptyStateView.Style) {
        emptyView.isHidden = false
        emptyView.show(style: style)
        view.bringSubviewToFront(emptyView)
    }

    private func hideEmpty() {
        emptyView.isHidden = true
    }

    // MARK: - UITableViewDataSource / Delegate

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = items[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier(for: item), for: indexPath)
        configure(cell: cell, item: item, at: indexPath)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        cellHeight(for: items[indexPath.row], at: indexPath)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        didSelect(item: items[indexPath.row], at: indexPath)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentH = scrollView.contentSize.height
        let frameH = scrollView.frame.size.height
        if contentH > 0, offsetY > contentH - frameH - 100 {
            loadNextPage()
        }
    }
}
