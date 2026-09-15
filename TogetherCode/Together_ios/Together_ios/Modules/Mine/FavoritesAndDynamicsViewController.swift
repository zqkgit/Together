import UIKit
import SnapKit
import Kingfisher
import ESPullToRefresh

/// 收藏与动态（对齐 PR 设计图）：顶部「收藏作品 / 孩子动态」两段
/// 收藏作品 = 我收藏的他人作品（两列网格）；孩子动态 = 我孩子相关的帖子流（竖排卡片）
final class FavoritesAndDynamicsViewController: BaseViewController {

    private enum Tab: Int, CaseIterable {
        case favorites
        case childFeed
        var title: String {
            switch self {
            case .favorites: return "收藏作品"
            case .childFeed: return "孩子动态"
            }
        }
    }

    // 分段栏
    private let segmentView = UIView()
    private var tabButtons: [UIButton] = []
    private let indicatorView = UIView()
    private var currentTab: Tab = .favorites

    // 收藏作品：两列网格
    private let favLayout = UICollectionViewFlowLayout()
    private lazy var favCollectionView = UICollectionView(frame: .zero, collectionViewLayout: favLayout)
    private var favorites: [FavoriteItem] = []
    private var favPage = 1
    private var favHasMore = true
    private var favLoading = false

    // 孩子动态：列表流
    private lazy var feedTableView = UITableView(frame: .zero, style: .plain)
    private var feeds: [PostItem] = []
    private var feedPage = 1
    private var feedHasMore = true
    private var feedLoading = false

    private var footerSpinner: UIActivityIndicatorView?
    private let emptyView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        setupSegment()
        setupCollections()
        setupEmptyView()
        loadFavorites(reset: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "收藏与动态")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    // MARK: - 分段栏（收藏作品 | 孩子动态）

    private func setupSegment() {
        segmentView.backgroundColor = Theme.Color.surface
        view.addSubview(segmentView)
        segmentView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(46)
        }

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        segmentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        for tab in Tab.allCases {
            let button = UIButton(type: .system)
            button.tag = tab.rawValue
            button.setTitle(tab.title, for: .normal)
            button.titleLabel?.font = .appBody(15)
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
            tabButtons.append(button)
        }

        indicatorView.backgroundColor = Theme.Color.brand
        indicatorView.layer.cornerRadius = 2
        segmentView.addSubview(indicatorView)
        refreshSegment()
    }

    private func refreshSegment() {
        let selected = currentTab.rawValue
        for (i, button) in tabButtons.enumerated() {
            let isSelected = i == selected
            button.setTitleColor(isSelected ? Theme.Color.brand : Theme.Color.sub, for: .normal)
            button.titleLabel?.font = .appBody(isSelected ? 15 : 14)
            button.titleLabel?.font = UIFont.systemFont(ofSize: isSelected ? 16 : 15, weight: isSelected ? .bold : .regular)
        }
        indicatorView.snp.remakeConstraints {
            $0.bottom.equalTo(segmentView).offset(-6)
            $0.width.equalTo(44)
            $0.height.equalTo(3)
            $0.centerX.equalTo(tabButtons[selected])
        }
    }

    @objc private func tabTapped(_ sender: UIButton) {
        guard let tab = Tab(rawValue: sender.tag), tab != currentTab else { return }
        currentTab = tab
        refreshSegment()
        let showFav = tab == .favorites
        favCollectionView.isHidden = !showFav
        feedTableView.isHidden = showFav
        if showFav, favorites.isEmpty, !favLoading {
            loadFavorites(reset: true)
        } else if !showFav, feeds.isEmpty, !feedLoading {
            loadChildFeed(reset: true)
        }
        updateEmptyState()
    }

    // MARK: - 列表

    private func setupCollections() {
        favLayout.minimumInteritemSpacing = Theme.Spacing.m
        favLayout.minimumLineSpacing = Theme.Spacing.m
        let side = (UIScreen.main.bounds.width - Theme.Spacing.l * 2 - Theme.Spacing.m) / 2
        favLayout.itemSize = CGSize(width: side, height: side * 1.18)
        favLayout.sectionInset = UIEdgeInsets(top: Theme.Spacing.m, left: Theme.Spacing.l, bottom: 108, right: Theme.Spacing.l)

        favCollectionView.backgroundColor = Theme.Color.bg
        favCollectionView.dataSource = self
        favCollectionView.delegate = self
        favCollectionView.register(FavoriteWorkCell.self, forCellWithReuseIdentifier: FavoriteWorkCell.reuseId)
        favCollectionView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.loadFavorites(reset: true)
        }
        view.addSubview(favCollectionView)
        favCollectionView.snp.makeConstraints {
            $0.top.equalTo(segmentView.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        feedTableView.backgroundColor = Theme.Color.bg
        feedTableView.separatorStyle = .none
        feedTableView.dataSource = self
        feedTableView.delegate = self
        feedTableView.register(FavoriteFeedCell.self, forCellReuseIdentifier: FavoriteFeedCell.reuseId)
        feedTableView.estimatedRowHeight = 300
        feedTableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.loadChildFeed(reset: true)
        }
        feedTableView.isHidden = true
        view.addSubview(feedTableView)
        feedTableView.snp.makeConstraints {
            $0.top.equalTo(segmentView.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        let footer = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        let spin = UIActivityIndicatorView(style: .medium)
        spin.color = Theme.Color.brand
        footer.addSubview(spin)
        spin.snp.makeConstraints { $0.center.equalToSuperview() }
        footerSpinner = spin
    }

    private func setupEmptyView() {
        let label = UILabel()
        label.text = "暂无内容"
        label.font = .appBody(14)
        label.textColor = Theme.Color.sub
        label.textAlignment = .center
        emptyView.addSubview(label)
        label.snp.makeConstraints { $0.center.equalToSuperview() }
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints {
            $0.top.equalTo(segmentView.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }
        emptyView.isHidden = true
    }

    private func updateEmptyState() {
        let empty = currentTab == .favorites ? favorites.isEmpty : feeds.isEmpty
        emptyView.isHidden = !empty
        emptyView.subviews.first?.isHidden = !empty
        if let label = emptyView.subviews.first as? UILabel {
            label.text = currentTab == .favorites ? "还没有收藏的作品" : "暂无孩子动态"
        }
    }

    // MARK: - 数据

    private func loadFavorites(reset: Bool) {
        guard !favLoading else {
            favCollectionView.es.stopPullToRefresh()
            return
        }
        favLoading = true
        if !reset { footerSpinner?.startAnimating() }
        let page = reset ? 1 : favPage + 1
        PostService.fetchFavorites(page: page, size: 20) { [weak self] list, hasMore, error in
            guard let self else { return }
            self.favLoading = false
            self.favCollectionView.es.stopPullToRefresh()
            self.footerSpinner?.stopAnimating()
            if let list {
                self.favorites = reset ? list : self.favorites + list
                self.favHasMore = hasMore
                self.favPage = page
                self.favCollectionView.reloadData()
            } else if let error {
                self.showToast(error)
            }
            self.updateEmptyState()
        }
    }

    private func loadChildFeed(reset: Bool) {
        guard !feedLoading else {
            feedTableView.es.stopPullToRefresh()
            return
        }
        feedLoading = true
        if !reset { footerSpinner?.startAnimating() }
        let page = reset ? 1 : feedPage + 1
        PostService.fetchChildFeed(page: page, size: 20) { [weak self] list, hasMore, error in
            guard let self else { return }
            self.feedLoading = false
            self.feedTableView.es.stopPullToRefresh()
            self.footerSpinner?.stopAnimating()
            if let list {
                self.feeds = reset ? list : self.feeds + list
                self.feedHasMore = hasMore
                self.feedPage = page
                self.feedTableView.reloadData()
            } else if let error {
                self.showToast(error)
            }
            self.updateEmptyState()
        }
    }

    private func loadMoreIfNeeded() {
        if currentTab == .favorites {
            guard favHasMore, !favLoading, !favorites.isEmpty else { return }
            loadFavorites(reset: false)
        } else {
            guard feedHasMore, !feedLoading, !feeds.isEmpty else { return }
            loadChildFeed(reset: false)
        }
    }
}

// MARK: - UICollectionViewDataSource / Delegate

extension FavoritesAndDynamicsViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        favorites.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FavoriteWorkCell.reuseId, for: indexPath) as! FavoriteWorkCell
        cell.configure(item: favorites[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if indexPath.item >= favorites.count - 3 {
            loadMoreIfNeeded()
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = favorites[indexPath.item]
        let detail = PostDetailViewController(postId: item.target_id)
        navigationController?.pushViewController(detail, animated: true)
    }
}

// MARK: - UITableViewDataSource / Delegate

extension FavoritesAndDynamicsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        feeds.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FavoriteFeedCell.reuseId, for: indexPath) as! FavoriteFeedCell
        let item = feeds[indexPath.row]
        cell.configure(item: item)
        cell.onTap = { [weak self] in
            guard let self else { return }
            let detail = PostDetailViewController(postId: item.post_id)
            self.navigationController?.pushViewController(detail, animated: true)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row >= feeds.count - 3 {
            loadMoreIfNeeded()
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = feeds[indexPath.row]
        let detail = PostDetailViewController(postId: item.post_id)
        navigationController?.pushViewController(detail, animated: true)
    }
}

// MARK: - 收藏作品卡片（两列网格：封面 + 标题 + 作者 + 点赞）

final class FavoriteWorkCell: UICollectionViewCell {

    static let reuseId = "FavoriteWorkCell"

    private let coverView = UIImageView()
    private let titleLabel = UILabel()
    private let authorLabel = UILabel()
    private let likeLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = Theme.Color.surface
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true

        coverView.contentMode = .scaleAspectFill
        coverView.clipsToBounds = true
        contentView.addSubview(coverView)
        coverView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(contentView.snp.width).multipliedBy(0.8)
        }

        titleLabel.font = .appBody(14)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 1
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(coverView.snp.bottom).offset(Theme.Spacing.s + 2)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }

        authorLabel.font = .appLabel(11)
        authorLabel.textColor = Theme.Color.sub
        contentView.addSubview(authorLabel)
        authorLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(6)
            $0.leading.equalToSuperview().inset(Theme.Spacing.m)
        }

        likeLabel.font = .appLabel(11)
        likeLabel.textColor = Theme.Color.sub
        contentView.addSubview(likeLabel)
        likeLabel.snp.makeConstraints {
            $0.centerY.equalTo(authorLabel)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(item: FavoriteItem) {
        titleLabel.text = item.title
        authorLabel.text = item.authorName
        let likeCount = item.subtitle?.components(separatedBy: "赞").first?.trimmingCharacters(in: .whitespaces) ?? "0"
        likeLabel.text = "♥ \(likeCount)"

        let colorPair = WorkCardView.palette(for: item.topic)
        if let urlString = item.cover, let url = URL(string: urlString) {
            coverView.kf.setImage(with: url, placeholder: WorkCardView.gradientPlaceholder(colors: [colorPair.0, colorPair.1]))
        } else {
            coverView.image = WorkCardView.gradientPlaceholder(colors: [colorPair.0, colorPair.1])
        }
    }
}

// MARK: - 孩子动态卡片（复用首页老师动态 PostCardView：头像 + 角色 + 时间 + 正文 + 关联课程）

final class FavoriteFeedCell: UITableViewCell {

    static let reuseId = "FavoriteFeedCell"

    var onTap: (() -> Void)?

    private let cardView = PostCardView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(cardView)
        cardView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.s)
        }
        cardView.onTap = { [weak self] in
            self?.onTap?()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(item: PostItem) {
        cardView.configure(item: item)
    }
}
