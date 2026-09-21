import UIKit
import SnapKit
import ESPullToRefresh
import CoreLocation

/// 广场（对齐 PR 设计图 #plaza）：排序 chips（最新/热门/附近）+ 双列瀑布流作品卡
/// 复用：TagChipRow / WaterfallLayout / WorkCardView / EmptyStateView / PostService
final class PlazaViewController: BaseViewController {

    private let layout = WaterfallLayout()
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
    private let emptyView = EmptyStateView()

    private var items: [PostItem] = []
    private var page = 1
    private let pageSize = 20
    private var hasMore = true
    private var isLoading = false
    /// 排序：最新 / 热门 / 附近（按距离）
    private let sortChips = TagChipRow(chips: ["最新", "热门", "附近"])
    private var currentSort = "latest"
    private var currentLat: Double?
    private var currentLng: Double?

    private var footerSpinner: UIActivityIndicatorView?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "广场"
        view.backgroundColor = Theme.Color.bg
        setupCollectionView()
        setupEmptyView()
        setupChipHeader()  // chips 最后添加，保证在最上层不被空态/列表遮挡
        reload()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 编辑/删除后返回列表自动刷新
        reload()
    }

    private func setupCollectionView() {
        layout.columns = 2
        layout.spacing = Theme.Spacing.m
        layout.padding = Theme.Spacing.m
        layout.delegate = self

        collectionView.backgroundColor = Theme.Color.bg
        collectionView.alwaysBounceVertical = true
        collectionView.register(WorkCell.self, forCellWithReuseIdentifier: "WorkCell")
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.reload()
        }
        view.addSubview(collectionView)
        // 底部加载指示
        let footer = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        let spin = UIActivityIndicatorView(style: .medium)
        spin.color = Theme.Color.brand
        footer.addSubview(spin)
        spin.snp.makeConstraints { $0.center.equalToSuperview() }
        footerSpinner = spin
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 120, right: 0)
    }

    private func setupChipHeader() {
        // 仅保留排序栏（最新 / 热门 / 附近），固定在导航栏下方，不随内容滚动；左右统一 12pt
        view.addSubview(sortChips)
        sortChips.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.height.equalTo(34)
        }
        sortChips.onSelect = { [weak self] index in
            self?.applySort(index: index)
        }
        collectionView.snp.remakeConstraints {
            $0.top.equalTo(sortChips.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func setupEmptyView() {
        // 空态只覆盖内容区（chips 下方），不遮挡顶部话题标签
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(46)
            $0.leading.trailing.bottom.equalToSuperview()
        }
        emptyView.isHidden = true
    }

    // MARK: - 数据

    func reload() {
        guard !isLoading else {
            collectionView.es.stopPullToRefresh()
            return
        }
        isLoading = true
        showEmpty(.loading)

        PostService.fetchPlaza(page: 1, size: pageSize, sort: currentSort, topic: "", lat: currentLat, lng: currentLng) { [weak self] list, hasMore, error in
            guard let self else { return }
            self.isLoading = false
            self.collectionView.es.stopPullToRefresh()
            self.footerSpinner?.stopAnimating()

            if let error {
                if self.items.isEmpty {
                    self.showEmpty(.error(error, retry: { [weak self] in self?.reload() }))
                } else {
                    self.hideEmpty()
                    self.showToast(error)
                }
                return
            }
            self.items = list ?? []
            self.page = 1
            self.hasMore = hasMore
            self.collectionView.reloadData()
            self.updateEmptyState()
        }
    }

    private func loadNextPage() {
        guard !isLoading, hasMore, !items.isEmpty else { return }
        isLoading = true
        footerSpinner?.startAnimating()

        PostService.fetchPlaza(page: page + 1, size: pageSize, sort: currentSort, topic: "", lat: currentLat, lng: currentLng) { [weak self] list, hasMore, error in
            guard let self else { return }
            self.isLoading = false
            self.footerSpinner?.stopAnimating()

            if let error {
                self.showToast(error)
                return
            }
            self.page += 1
            self.hasMore = hasMore
            self.items.append(contentsOf: list ?? [])
            self.collectionView.reloadData()
            self.updateEmptyState()
        }
    }

    // MARK: - 排序（最新 / 热门 / 附近）

    private func applySort(index: Int) {
        let sorts = ["latest", "hot", "near"]
        guard index >= 0, index < sorts.count else { return }
        let sort = sorts[index]
        if sort == "near" {
            // 附近：先取用户坐标；未授权/失败则退化为最新
            LocationManager.shared.requestCurrentLocation { [weak self] loc in
                guard let self else { return }
                if let loc = loc {
                    self.currentLat = loc.coordinate.latitude
                    self.currentLng = loc.coordinate.longitude
                    self.currentSort = "near"
                } else {
                    self.showToast("未授权定位，已按最新展示")
                    self.sortChips.select(index: 0)
                    self.currentSort = "latest"
                    self.currentLat = nil
                    self.currentLng = nil
                }
                self.reload()
            }
        } else {
            currentSort = sort
            currentLat = nil
            currentLng = nil
            reload()
        }
    }

    private func updateEmptyState() {
        if items.isEmpty {
            showEmpty(.empty("暂无作品"))
        } else {
            hideEmpty()
        }
    }

    private func showEmpty(_ style: EmptyStateView.Style) {
        emptyView.isHidden = false
        emptyView.show(style: style)
    }

    private func hideEmpty() {
        emptyView.isHidden = true
    }
}

// MARK: - WaterfallLayout.Delegate

extension PlazaViewController: WaterfallLayout.Delegate {
    func waterfall(_ layout: WaterfallLayout, heightForItemAt indexPath: IndexPath, itemWidth: CGFloat) -> CGFloat {
        let item = items[indexPath.item]
        let imageHeight = itemWidth * 4.0 / 3.0

        // 信息区动态高度：上8 + 标题(≤2行) + 4 + 作者行 + 4 + 关联课程(有则20) + 下12
        let textWidth = itemWidth - Theme.Spacing.m * 2
        let title = item.content?.isEmpty == false ? item.content! : "作品分享"
        let titleSize = (title as NSString).boundingRect(
            with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: UIFont.appSection(14)],
            context: nil
        )
        let titleHeight = min(ceil(titleSize.height), 40)
        let courseHeight: CGFloat = (item.course?.title?.isEmpty == false) ? 20 : 0

        return imageHeight + Theme.Spacing.s + titleHeight + 4 + 17 + 4 + courseHeight + Theme.Spacing.m
    }
}

// MARK: - UICollectionViewDataSource / Delegate

extension PlazaViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "WorkCell", for: indexPath) as! WorkCell
        cell.configure(item: items[indexPath.item])
        let item = items[indexPath.item]
        cell.onTap = { [weak self] in
            let detail = PostDetailViewController(postId: item.post_id)
            self?.navigationController?.pushViewController(detail, animated: true)
        }
        return cell
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentH = scrollView.contentSize.height
        let frameH = scrollView.frame.size.height
        if contentH > 0, offsetY > contentH - frameH - 200 {
            loadNextPage()
        }
    }
}

/// 瀑布流容器 cell（复用 WorkCardView）
final class WorkCell: UICollectionViewCell {
    var onTap: (() -> Void)?

    private let card = WorkCardView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentView.addSubview(card)
        card.snp.makeConstraints { $0.edges.equalToSuperview() }
        card.onTap = { [weak self] in self?.onTap?() }
    }

    func configure(item: PostItem) { card.configure(item: item) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
