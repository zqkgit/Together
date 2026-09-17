import UIKit
import SnapKit
import Kingfisher
import ESPullToRefresh

/// 作品管理（家长端）
/// PR 图：顶部「作品管理」+ 返回；分类标签（全部N / 公开N / 未公开N）；两列作品卡片
/// 卡片：封面 + 标题 + 时间·点赞 + 公开状态标签 + 话题；右下角圆形 + 发布入口
final class WorkManagementViewController: BaseViewController {

    // MARK: - 分类

    private enum Category: Int, CaseIterable {
        case all = 0, publicWork, privateWork

        var title: String { ["全部", "公开", "未公开"][rawValue] }
        var statusParam: String { ["all", "public", "private"][rawValue] }
    }

    // MARK: - 状态

    private var currentCategory: Category = .all
    private var works: [PostItem] = []
    private var counts: [Int] = [0, 0, 0]
    private var page = 1
    private var hasMore = true
    private var isLoading = false
    private var footerSpinner: UIActivityIndicatorView?

    // MARK: - UI

    private let chipRow = TagChipRow(chips: ["全部0", "公开0", "未公开0"])
    private var collectionView: UICollectionView!
    private let fabButton = UIButton(type: .system)
    private let emptyView = UIView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        setupChipHeader()
        setupCollectionView()
        setupFAB()
        loadData(reset: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "作品管理")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    // MARK: - UI 构建

    private func setupChipHeader() {
        // 分类 chips 对齐广场筛选：固定在导航栏下方、左右 12、高 34；顶部留 8pt 呼吸
        view.addSubview(chipRow)
        chipRow.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.height.equalTo(34)
        }
        chipRow.onSelect = { [weak self] index in
            guard let self else { return }
            if let category = Category(rawValue: index), category != self.currentCategory {
                self.currentCategory = category
                self.loadData(reset: true)
            }
        }
    }

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = Theme.Spacing.m
        layout.minimumLineSpacing = Theme.Spacing.m
        let side = (UIScreen.main.bounds.width - Theme.Spacing.l * 2 - Theme.Spacing.m) / 2
        layout.itemSize = CGSize(width: side, height: side * 1.28)
        // 顶部间距已由 collectionView 与 chipRow 的 8pt 控制，section 顶部不再叠加
        layout.sectionInset = UIEdgeInsets(top: 0, left: Theme.Spacing.l, bottom: 108, right: Theme.Spacing.l)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = Theme.Color.bg
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.alwaysBounceVertical = true
        collectionView.register(WorksManageCell.self, forCellWithReuseIdentifier: WorksManageCell.reuseId)
        // 对齐广场：品牌下拉刷新 + 底部加载指示
        collectionView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.loadData(reset: true)
        }
        let footer = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        let spin = UIActivityIndicatorView(style: .medium)
        spin.color = Theme.Color.brand
        footer.addSubview(spin)
        spin.snp.makeConstraints { $0.center.equalToSuperview() }
        footerSpinner = spin
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.top.equalTo(chipRow.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        setupEmptyView()
    }

    private func setupEmptyView() {
        emptyView.isHidden = true
        let label = UILabel()
        label.text = "还没有作品，点击右下角发布吧"
        label.font = .appBody(14)
        label.textColor = Theme.Color.sub
        label.textAlignment = .center
        emptyView.addSubview(label)
        label.snp.makeConstraints { $0.center.equalToSuperview() }
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints {
            $0.top.equalTo(chipRow.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func setupFAB() {
        fabButton.setImage(UIImage(systemName: "plus"), for: .normal)
        fabButton.tintColor = .white
        fabButton.backgroundColor = Theme.Color.brand
        fabButton.layer.cornerRadius = 28
        fabButton.clipsToBounds = true
        fabButton.addShadow()
        fabButton.addTarget(self, action: #selector(didTapPublish), for: .touchUpInside)
        view.addSubview(fabButton)
        fabButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.l)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-Theme.Spacing.l)
            $0.width.height.equalTo(56)
        }
    }

    private func setupEmptyViewIfNeeded() {
        emptyView.isHidden = !works.isEmpty
    }

    // MARK: - 分类 chips

    private func refreshCategoryBar() {
        let titles = Category.allCases.enumerated().map { index, category in
            let count = index < counts.count ? counts[index] : 0
            return "\(category.title)\(count)"
        }
        chipRow.update(chips: titles, selectedIndex: currentCategory.rawValue)
    }

    // MARK: - 数据

    private func loadData(reset: Bool) {
        guard !isLoading else { return }
        isLoading = true
        if reset {
            page = 1
            hasMore = true
        } else {
            footerSpinner?.startAnimating()
        }
        PostService.fetchMyWorks(page: page, size: 20, status: currentCategory.statusParam) { [weak self] list, counts, hasMore, error in
            guard let self else { return }
            self.isLoading = false
            self.collectionView.es.stopPullToRefresh()
            self.footerSpinner?.stopAnimating()
            if let list {
                self.works = reset ? list : self.works + list
                self.hasMore = hasMore
                if reset { self.page = 1 } else { self.page += 1 }
                if let counts, counts.count == 3 {
                    self.counts = counts
                }
                self.refreshCategoryBar()
                self.collectionView.reloadData()
                self.setupEmptyViewIfNeeded()
            } else if let error {
                self.showToast(error)
            }
        }
    }

    private func loadMoreIfNeeded() {
        guard hasMore, !isLoading, !works.isEmpty else { return }
        loadData(reset: false)
    }

    @objc private func didTapPublish() {
        let vc = BaseNavigationController(rootViewController: ParentPostCreateViewController())
        vc.modalPresentationStyle = .fullScreen
        present(vc, animated: true)
    }
}

// MARK: - CollectionView

extension WorkManagementViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        works.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: WorksManageCell.reuseId, for: indexPath) as! WorksManageCell
        cell.configure(item: works[indexPath.item])
        if indexPath.item == works.count - 1 {
            loadMoreIfNeeded()
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = works[indexPath.item]
        let vc = PostDetailViewController(postId: item.post_id)
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - 作品卡片

final class WorksManageCell: UICollectionViewCell {

    static let reuseId = "WorksManageCell"

    private let coverView = UIImageView()
    private let statusBadge = UILabel()
    private let titleLabel = UILabel()
    private let timeLabel = UILabel()
    private let likeLabel = UILabel()
    private let topicLabel = UILabel()

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
            $0.height.equalTo(contentView.snp.width).multipliedBy(0.78)
        }

        statusBadge.font = .appLabel(10)
        statusBadge.textColor = .white
        statusBadge.textAlignment = .center
        statusBadge.layer.cornerRadius = 9
        statusBadge.clipsToBounds = true
        contentView.addSubview(statusBadge)
        statusBadge.snp.makeConstraints {
            $0.top.equalTo(coverView).offset(8)
            $0.trailing.equalTo(coverView).offset(-8)
            $0.width.greaterThanOrEqualTo(38)
            $0.height.equalTo(18)
        }

        titleLabel.font = .appBody(14)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 2
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(coverView.snp.bottom).offset(Theme.Spacing.s + 2)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }

        timeLabel.font = .appLabel(11)
        timeLabel.textColor = Theme.Color.sub
        contentView.addSubview(timeLabel)
        timeLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(6)
            $0.leading.equalToSuperview().inset(Theme.Spacing.m)
        }

        likeLabel.font = .appLabel(11)
        likeLabel.textColor = Theme.Color.sub
        contentView.addSubview(likeLabel)
        likeLabel.snp.makeConstraints {
            $0.centerY.equalTo(timeLabel)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }

        topicLabel.font = .appLabel(11)
        topicLabel.textColor = Theme.Color.brand
        contentView.addSubview(topicLabel)
        topicLabel.snp.makeConstraints {
            $0.top.equalTo(timeLabel.snp.bottom).offset(4)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.lessThanOrEqualToSuperview().offset(-Theme.Spacing.s)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(item: PostItem) {
        titleLabel.text = item.content?.isEmpty == false ? item.content : "作品分享"
        timeLabel.text = item.timeText
        likeLabel.text = "♥ \(item.like_count ?? 0)"

        // 公开状态
        statusBadge.text = item.visibilityText
        statusBadge.backgroundColor = item.isPublic ? Theme.Color.brand : Theme.Color.sub.withAlphaComponent(0.7)

        // 话题
        if let topic = item.safeTopic {
            topicLabel.text = "#\(topic)"
            topicLabel.isHidden = false
        } else {
            topicLabel.isHidden = true
        }

        // 封面：有图加载，无图/失败按话题色渐变占位
        let colorPair = WorkCardView.palette(for: item.topic)
        if let urlString = item.images?.first, let url = URL(string: urlString) {
            coverView.backgroundColor = colorPair.0
            coverView.kf.setImage(with: url, placeholder: WorkCardView.gradientPlaceholder(colors: [colorPair.0, colorPair.1]))
        } else {
            coverView.backgroundColor = colorPair.0
            coverView.image = WorkCardView.gradientPlaceholder(colors: [colorPair.0, colorPair.1])
        }
    }
}

// MARK: - 阴影

private extension UIView {
    func addShadow() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 4)
    }
}
