import UIKit
import SnapKit
import Kingfisher
import ESPullToRefresh

/// 搜索页：热词 + 历史 → 搜索帖子（双列瀑布流，复用广场样式）
final class SearchViewController: BaseViewController {

    // MARK: - 状态

    private enum State {
        case idle          // 默认态（热词 + 历史）
        case searching     // 请求中
        case result        // 有结果
        case empty         // 无结果
    }

    private var state: State = .idle
    private var posts: [PostItem] = []
    private var hotKeywords: [String] = []
    private var currentPage = 1
    private var hasMore = true
    private var isLoading = false

    // MARK: - UI

    private let searchTextField = UITextField()
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // 默认态
    private let hotSectionLabel = UILabel()
    private let hotTagFlow = TagFlowView()
    private let historySectionLabel = UILabel()
    private let clearHistoryButton = UIButton(type: .system)
    private let historyTagFlow = TagFlowView()

    // 结果态（瀑布流）
    private let waterfallLayout = WaterfallLayout()
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: waterfallLayout)

    // 空态
    private let emptyView = EmptyStateView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        setupNavBar()
        setupScrollView()
        setupIdleView()
        setupCollectionView()
        setupEmptyView()
        loadHotKeywords()
        reloadIdleView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if state == .idle {
            searchTextField.becomeFirstResponder()
        }
    }

    // MARK: - 导航栏（返回 + 搜索框药丸）

    private func setupNavBar() {
        let backBtn = UIButton(type: .system)
        backBtn.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backBtn.tintColor = Theme.Color.ink
        backBtn.addTarget(self, action: #selector(didTapBack), for: .touchUpInside)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backBtn)

        // 搜索药丸：自定义 titleView，intrinsicContentSize 返回大宽度让 UIKit 拉伸填满
        let pill = SearchPillView()
        pill.backgroundColor = Theme.Color.surfaceAlt
        pill.layer.cornerRadius = 20

        let searchIcon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        searchIcon.tintColor = Theme.Color.muted
        searchIcon.contentMode = .scaleAspectFit
        pill.addSubview(searchIcon)
        searchIcon.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(12)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(16)
        }

        searchTextField.placeholder = "搜索帖子内容、话题"
        searchTextField.font = .appBody(14)
        searchTextField.textColor = Theme.Color.ink
        searchTextField.returnKeyType = .search
        searchTextField.clearButtonMode = .whileEditing
        searchTextField.delegate = self
        pill.addSubview(searchTextField)
        searchTextField.snp.makeConstraints {
            $0.leading.equalTo(searchIcon.snp.trailing).offset(8)
            $0.trailing.equalToSuperview().offset(-8)
            $0.centerY.equalToSuperview()
            $0.height.equalTo(30)
        }

        navigationItem.titleView = pill
    }

    // MARK: - 滚动容器（默认态）

    private func setupScrollView() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints { $0.edges.equalToSuperview(); $0.width.equalToSuperview() }
    }

    // MARK: - 默认态（热词 + 历史）

    private func setupIdleView() {
        hotSectionLabel.text = "🔥 热门搜索"
        hotSectionLabel.font = .appSection(16)
        hotSectionLabel.textColor = Theme.Color.ink
        contentView.addSubview(hotSectionLabel)
        hotSectionLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.equalToSuperview().offset(Theme.Spacing.m)
        }

        contentView.addSubview(hotTagFlow)
        hotTagFlow.snp.makeConstraints {
            $0.top.equalTo(hotSectionLabel.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }

        historySectionLabel.text = "🕐 搜索历史"
        historySectionLabel.font = .appSection(16)
        historySectionLabel.textColor = Theme.Color.ink
        contentView.addSubview(historySectionLabel)
        historySectionLabel.snp.makeConstraints {
            $0.top.equalTo(hotTagFlow.snp.bottom).offset(Theme.Spacing.xl)
            $0.leading.equalToSuperview().offset(Theme.Spacing.m)
        }

        clearHistoryButton.setTitle("清空", for: .normal)
        clearHistoryButton.titleLabel?.font = .appLabel(13)
        clearHistoryButton.setTitleColor(Theme.Color.muted, for: .normal)
        clearHistoryButton.addTarget(self, action: #selector(didTapClearHistory), for: .touchUpInside)
        contentView.addSubview(clearHistoryButton)
        clearHistoryButton.snp.makeConstraints {
            $0.centerY.equalTo(historySectionLabel)
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.m)
        }

        contentView.addSubview(historyTagFlow)
        historyTagFlow.snp.makeConstraints {
            $0.top.equalTo(historySectionLabel.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.xxl)
        }
    }

    // MARK: - 结果态（双列瀑布流）

    private func setupCollectionView() {
        waterfallLayout.columns = 2
        waterfallLayout.spacing = Theme.Spacing.m
        waterfallLayout.padding = Theme.Spacing.m
        waterfallLayout.delegate = self

        collectionView.backgroundColor = Theme.Color.bg
        collectionView.alwaysBounceVertical = true
        collectionView.register(WorkCell.self, forCellWithReuseIdentifier: "WorkCell")
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isHidden = true

        // 下拉刷新
        collectionView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            guard let self, let kw = self.searchTextField.text, !kw.isEmpty else { return }
            self.loadPosts(keyword: kw, page: 1)
        }

        view.addSubview(collectionView)
        collectionView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            $0.leading.trailing.bottom.equalToSuperview()
        }
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 120, right: 0)
    }

    // MARK: - 空态

    private func setupEmptyView() {
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(120)
            $0.leading.trailing.bottom.equalToSuperview()
        }
        emptyView.isHidden = true
    }

    // MARK: - 数据加载

    private func loadHotKeywords() {
        SearchService.shared.fetchHotKeywords { [weak self] result in
            guard let self else { return }
            if case .success(let keywords) = result {
                self.hotKeywords = keywords
                self.reloadIdleView()
            }
        }
    }

    private func reloadIdleView() {
        hotTagFlow.configure(tags: hotKeywords, style: .hot) { [weak self] keyword in
            self?.doSearch(keyword)
        }

        let history = SearchHistoryManager.shared.history
        historyTagFlow.configure(tags: history, style: .history) { [weak self] keyword in
            self?.doSearch(keyword)
        }
        historySectionLabel.isHidden = history.isEmpty
        clearHistoryButton.isHidden = history.isEmpty
    }

    // MARK: - 搜索执行

    private func doSearch(_ keyword: String) {
        let kw = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kw.isEmpty else {
            switchToIdle()
            return
        }

        searchTextField.text = kw
        searchTextField.resignFirstResponder()
        SearchHistoryManager.shared.add(kw)

        state = .searching
        currentPage = 1
        hasMore = true
        posts = []
        isLoading = false
        switchToResultUI()

        loadPosts(keyword: kw, page: 1)
    }

    private func loadPosts(keyword: String, page: Int) {
        guard !isLoading else { return }
        isLoading = true

        SearchService.shared.searchPosts(keyword: keyword, page: page) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            self.collectionView.es.stopPullToRefresh()

            switch result {
            case .success(let list):
                if page == 1 {
                    self.posts = list
                } else {
                    self.posts.append(contentsOf: list)
                }
                self.hasMore = list.count >= 20
                self.currentPage = page

                if self.posts.isEmpty {
                    self.state = .empty
                    self.emptyView.show(style: .empty("未找到相关帖子"))
                    self.emptyView.isHidden = false
                    self.collectionView.isHidden = true
                } else {
                    self.state = .result
                    self.emptyView.isHidden = true
                    self.collectionView.isHidden = false
                    self.collectionView.reloadData()
                }
                self.reloadIdleView()
            case .failure(let error):
                self.state = .idle
                self.showToast("搜索失败：\(error.localizedDescription)")
            }
        }
    }

    // MARK: - UI 状态切换

    private func switchToIdle() {
        state = .idle
        searchTextField.text = ""
        scrollView.isHidden = false
        hotSectionLabel.isHidden = false
        hotTagFlow.isHidden = false
        historySectionLabel.isHidden = SearchHistoryManager.shared.history.isEmpty
        clearHistoryButton.isHidden = SearchHistoryManager.shared.history.isEmpty
        historyTagFlow.isHidden = false
        collectionView.isHidden = true
        emptyView.isHidden = true
        reloadIdleView()
    }

    private func switchToResultUI() {
        scrollView.isHidden = true
        collectionView.isHidden = true
        emptyView.isHidden = true
    }

    // MARK: - Actions

    @objc private func didTapBack() {
        searchTextField.resignFirstResponder()
        navigationController?.popViewController(animated: true)
    }

    @objc private func didTapClearHistory() {
        SearchHistoryManager.shared.clear()
        reloadIdleView()
    }
}

// MARK: - UITextFieldDelegate

extension SearchViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let text = textField.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        doSearch(text)
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let current = textField.text ?? ""
        let proposed = (current as NSString).replacingCharacters(in: range, with: string)
        if proposed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            DispatchQueue.main.async { self.switchToIdle() }
        }
        return true
    }
}

// MARK: - WaterfallLayout.Delegate

extension SearchViewController: WaterfallLayout.Delegate {
    func waterfall(_ layout: WaterfallLayout, heightForItemAt indexPath: IndexPath, itemWidth: CGFloat) -> CGFloat {
        let item = posts[indexPath.item]
        let imageHeight = itemWidth * 4.0 / 3.0

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

// MARK: - UICollectionViewDataSource / UICollectionViewDelegate

extension SearchViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        posts.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "WorkCell", for: indexPath) as! WorkCell
        let item = posts[indexPath.item]
        cell.configure(item: item)
        cell.onTap = { [weak self] in
            let detail = PostDetailViewController(postId: item.post_id)
            self?.navigationController?.pushViewController(detail, animated: true)
        }
        return cell
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard state == .result, !isLoading, hasMore else { return }
        let offsetY = scrollView.contentOffset.y
        let contentH = scrollView.contentSize.height
        let frameH = scrollView.frame.size.height
        if contentH > 0, offsetY > contentH - frameH - 200 {
            loadPosts(keyword: searchTextField.text ?? "", page: currentPage + 1)
        }
    }
}

// MARK: - 标签流视图（自适应换行）

final class TagFlowView: UIView {

    enum TagStyle {
        case hot
        case history
    }

    private let container = UIStackView()
    var onTap: ((String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        container.axis = .vertical
        container.spacing = Theme.Spacing.s
        addSubview(container)
        container.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    func configure(tags: [String], style: TagStyle = .hot, onTap: ((String) -> Void)? = nil) {
        self.onTap = onTap
        container.arrangedSubviews.forEach { $0.removeFromSuperview() }

        var currentRow: UIStackView?
        var currentWidth: CGFloat = 0
        let maxWidth = UIScreen.main.bounds.width - Theme.Spacing.m * 2
        let rowSpacing: CGFloat = 8   // 标签水平间距
        let lineSpacing: CGFloat = 10  // 标签行间距

        for tag in tags {
            let btn = UIButton(type: .system)
            btn.setTitle(tag, for: .normal)
            btn.titleLabel?.font = .appLabel(13)
            btn.layer.cornerRadius = 16
            btn.titleLabel?.adjustsFontSizeToFitWidth = false

            switch style {
            case .hot:
                btn.setTitleColor(Theme.Color.brand, for: .normal)
                btn.backgroundColor = Theme.Color.brandSoft
            case .history:
                btn.setTitleColor(Theme.Color.ink, for: .normal)
                btn.backgroundColor = Theme.Color.surface
                btn.layer.borderWidth = 1
                btn.layer.borderColor = Theme.Color.line.cgColor
            }

            // 自适应宽度：文字 + 左右内边距
            let hPad: CGFloat = 14, vPad: CGFloat = 7
            if #available(iOS 15.0, *) {
                var config = UIButton.Configuration.plain()
                config.contentInsets = NSDirectionalEdgeInsets(top: vPad, leading: hPad, bottom: vPad, trailing: hPad)
                config.titlePadding = 0
                btn.configuration = config
                // Configuration 模式下 intrinsicContentSize 已含 padding
            } else {
                btn.contentEdgeInsets = UIEdgeInsets(top: vPad, left: hPad, bottom: vPad, right: hPad)
            }

            // 强制布局后取准确宽度
            btn.sizeToFit()
            let btnWidth = btn.intrinsicContentSize.width

            btn.addTarget(self, action: #selector(didTapTag(_:)), for: .touchUpInside)

            if currentRow == nil || currentWidth + btnWidth + rowSpacing > maxWidth {
                currentRow = UIStackView()
                currentRow!.axis = .horizontal
                currentRow!.spacing = rowSpacing
                currentRow!.alignment = .leading
                container.addArrangedSubview(currentRow!)
                container.setCustomSpacing(lineSpacing, after: currentRow!)
                currentWidth = 0
            }
            currentRow!.addArrangedSubview(btn)
            currentWidth += btnWidth + rowSpacing
        }
    }

    @objc private func didTapTag(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }
        onTap?(title)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// 搜索药丸容器：重写 intrinsicContentSize 让 UIKit 自动拉伸填满导航栏可用宽度
/// 配合 leftBarButtonItem（返回按钮），实现距离返回按钮 12pt、右侧 12pt
final class SearchPillView: UIView {
    override var intrinsicContentSize: CGSize {
        // 返回超大宽度，UIKit 会将其约束到导航栏可用空间
        CGSize(width: 10000, height: 40)
    }
}