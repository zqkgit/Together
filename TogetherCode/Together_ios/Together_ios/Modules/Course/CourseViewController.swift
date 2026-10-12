import UIKit
import SnapKit
import Kingfisher

/// 课程更多页：搜索栏 + 标签横滑 + 热词/历史面板 + 课程card行列表 + 分页
/// 对齐小程序 packageCourses/pages/courses/index.tsx
final class CourseViewController: BaseViewController {

    // MARK: - 状态

    private enum State {
        case idle          // 默认态（热词 + 历史）
        case searching     // 请求中
        case result        // 有结果
        case empty         // 无结果
    }

    private var state: State = .idle
    private var currentKeyword: String = ""
    private var currentTag: String = ""
    private var selectedTagIndex: Int = -1  // -1 = 全部

    private var courses: [CourseItem] = []
    private var tags: [TagItem] = []
    private var hotKeywords: [String] = []

    private var currentPage = 1
    private var hasMore = true
    private var isLoading = false

    // MARK: - UI

    private let brandBackgroundView = UIView()
    private let searchHeaderView = UIView()
    private let searchBarContainer = UIView()
    private let searchTextField = UITextField()
    private let searchButton = UIButton(type: .custom)
    private let clearButton = UIButton(type: .custom)

    // 标签横滑
    private let tagScrollView = UIScrollView()
    private let tagStack = UIStackView()
    private var tagButtons: [UIButton] = []

    // 默认态
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let hotCardView = UIView()
    private let hotSectionLabel = UILabel()
    private let hotTagFlow = TagFlowView()
    private let historyCardView = UIView()
    private let historySectionLabel = UILabel()
    private let clearHistoryButton = UIButton(type: .system)
    private let historyTagFlow = TagFlowView()

    // 结果态
    private let tableView = UITableView(frame: .zero, style: .plain)

    // 空态
    private let emptyView = EmptyStateView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "全部课程"
        view.backgroundColor = Theme.Color.bg

        setupBrandBackground()
        setupSearchHeader()
        setupTagScroll()
        setupScrollView()
        setupIdleView()
        setupTableView()
        setupEmptyView()
        loadTags()
        loadHotKeywords()
        reloadIdleView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(titleColor: .white, backTint: .white)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    // MARK: - 品牌色背景

    private func setupBrandBackground() {
        brandBackgroundView.backgroundColor = Theme.Color.brand
        view.addSubview(brandBackgroundView)
        brandBackgroundView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(200) // 覆盖导航栏 + 搜索头 + 标签栏
        }
    }

    // MARK: - 搜索头部

    private func setupSearchHeader() {
        searchHeaderView.backgroundColor = .clear
        view.addSubview(searchHeaderView)
        searchHeaderView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(52)
        }

        searchBarContainer.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        searchBarContainer.layer.cornerRadius = 20

        let searchIcon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        searchIcon.tintColor = UIColor.white.withAlphaComponent(0.6)
        searchIcon.contentMode = .scaleAspectFit

        searchTextField.font = .appBody(14)
        searchTextField.textColor = .white
        searchTextField.attributedPlaceholder = NSAttributedString(
            string: "搜索课程",
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.6), .font: UIFont.appBody(14)]
        )
        searchTextField.returnKeyType = .search
        searchTextField.delegate = self

        clearButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clearButton.tintColor = UIColor.white.withAlphaComponent(0.6)
        clearButton.addTarget(self, action: #selector(didTapClear), for: .touchUpInside)
        clearButton.isHidden = true

        searchBarContainer.addSubview(searchIcon)
        searchBarContainer.addSubview(searchTextField)
        searchBarContainer.addSubview(clearButton)

        searchIcon.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(12)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(16)
        }
        searchTextField.snp.makeConstraints {
            $0.leading.equalTo(searchIcon.snp.trailing).offset(8)
            $0.centerY.equalToSuperview()
            $0.height.equalTo(28)
        }
        clearButton.snp.makeConstraints {
            $0.leading.equalTo(searchTextField.snp.trailing).offset(4)
            $0.trailing.equalToSuperview().offset(-8)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(20)
        }

        searchButton.setTitle("搜索", for: .normal)
        searchButton.titleLabel?.font = .appSection(14)
        searchButton.setTitleColor(Theme.Color.brand, for: .normal)
        searchButton.backgroundColor = .white
        searchButton.layer.cornerRadius = 16
        searchButton.addTarget(self, action: #selector(didTapSearch), for: .touchUpInside)

        searchHeaderView.addSubview(searchBarContainer)
        searchHeaderView.addSubview(searchButton)

        searchBarContainer.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
            $0.height.equalTo(40)
        }
        searchButton.snp.makeConstraints {
            $0.leading.equalTo(searchBarContainer.snp.trailing).offset(Theme.Spacing.s)
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.m)
            $0.centerY.equalToSuperview()
            $0.width.equalTo(56)
            $0.height.equalTo(32)
        }

        searchTextField.addTarget(self, action: #selector(textDidChange), for: .editingChanged)
    }

    // MARK: - 标签横滑

    private func setupTagScroll() {
        tagScrollView.backgroundColor = Theme.Color.brand
        tagScrollView.showsHorizontalScrollIndicator = false
        tagScrollView.contentInset = UIEdgeInsets(top: 0, left: Theme.Spacing.m, bottom: 0, right: Theme.Spacing.m)
        view.addSubview(tagScrollView)
        tagScrollView.snp.makeConstraints {
            $0.top.equalTo(searchHeaderView.snp.bottom)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(40)
        }

        tagStack.axis = .horizontal
        tagStack.spacing = Theme.Spacing.s
        tagStack.alignment = .center
        tagScrollView.addSubview(tagStack)
        tagStack.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.height.equalToSuperview()
        }

        // 默认"全部"按钮
        let allBtn = makeTagButton("全部")
        allBtn.tag = -1
        allBtn.isSelected = true
        allBtn.addTarget(self, action: #selector(didTapTag(_:)), for: .touchUpInside)
        tagStack.addArrangedSubview(allBtn)
        tagButtons.append(allBtn)
    }

    private func makeTagButton(_ title: String) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .appSection(13)
        btn.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .normal)
        btn.setTitleColor(.white, for: .selected)
        btn.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        btn.layer.cornerRadius = 16
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        btn.snp.makeConstraints { $0.height.equalTo(28) }
        return btn
    }

    private func updateTagStyle() {
        for (index, btn) in tagButtons.enumerated() {
            let isSelected = index == selectedTagIndex
            btn.isSelected = isSelected
            btn.titleLabel?.font = isSelected ? .appHero(13) : .appSection(13)
            btn.backgroundColor = isSelected ? .white : UIColor.white.withAlphaComponent(0.15)
            btn.setTitleColor(isSelected ? Theme.Color.brand : UIColor.white.withAlphaComponent(0.7), for: .normal)
        }
    }

    @objc private func didTapTag(_ sender: UIButton) {
        let index = sender.tag
        guard index != selectedTagIndex else { return }
        selectedTagIndex = index

        if index == -1 {
            currentTag = ""
        } else if index >= 0 && index < tags.count {
            currentTag = tags[index].name
        }

        updateTagStyle()
        doSearch(currentKeyword)
    }

    // MARK: - 滚动容器（默认态）

    private func setupScrollView() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints {
            $0.top.equalTo(tagScrollView.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints { $0.edges.equalToSuperview(); $0.width.equalToSuperview() }
    }

    // MARK: - 默认态（热词 + 历史）

    private func setupIdleView() {
        // 热词卡片
        hotCardView.backgroundColor = Theme.Color.surface
        hotCardView.layer.cornerRadius = Theme.Radius.card
        hotCardView.layer.shadowColor = Theme.Shadow.card.color.cgColor
        hotCardView.layer.shadowOpacity = Theme.Shadow.card.opacity
        hotCardView.layer.shadowOffset = Theme.Shadow.card.offset
        hotCardView.layer.shadowRadius = Theme.Shadow.card.radius
        contentView.addSubview(hotCardView)
        hotCardView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }

        hotSectionLabel.text = "🔥 搜索热词"
        hotSectionLabel.font = .appSection(15)
        hotSectionLabel.textColor = Theme.Color.ink
        hotCardView.addSubview(hotSectionLabel)
        hotSectionLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.cardInner)
            $0.leading.equalToSuperview().offset(Theme.Spacing.cardInner)
        }

        hotCardView.addSubview(hotTagFlow)
        hotTagFlow.snp.makeConstraints {
            $0.top.equalTo(hotSectionLabel.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.cardInner)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.cardInner)
        }

        // 历史卡片
        historyCardView.backgroundColor = Theme.Color.surface
        historyCardView.layer.cornerRadius = Theme.Radius.card
        historyCardView.layer.shadowColor = Theme.Shadow.card.color.cgColor
        historyCardView.layer.shadowOpacity = Theme.Shadow.card.opacity
        historyCardView.layer.shadowOffset = Theme.Shadow.card.offset
        historyCardView.layer.shadowRadius = Theme.Shadow.card.radius
        contentView.addSubview(historyCardView)
        historyCardView.snp.makeConstraints {
            $0.top.equalTo(hotCardView.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.xxl)
        }

        historySectionLabel.text = "搜索历史"
        historySectionLabel.font = .appSection(15)
        historySectionLabel.textColor = Theme.Color.ink
        historyCardView.addSubview(historySectionLabel)
        historySectionLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.cardInner)
            $0.leading.equalToSuperview().offset(Theme.Spacing.cardInner)
        }

        clearHistoryButton.setTitle("清空", for: .normal)
        clearHistoryButton.titleLabel?.font = .appLabel(12)
        clearHistoryButton.setTitleColor(Theme.Color.muted, for: .normal)
        clearHistoryButton.addTarget(self, action: #selector(didTapClearHistory), for: .touchUpInside)
        historyCardView.addSubview(clearHistoryButton)
        clearHistoryButton.snp.makeConstraints {
            $0.centerY.equalTo(historySectionLabel)
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.cardInner)
        }

        historyCardView.addSubview(historyTagFlow)
        historyTagFlow.snp.makeConstraints {
            $0.top.equalTo(historySectionLabel.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.cardInner)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.cardInner)
        }
    }

    // MARK: - 结果态（列表）

    private func setupTableView() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.register(SearchCourseCell.self, forCellReuseIdentifier: "SearchCourseCell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.isHidden = true
        tableView.keyboardDismissMode = .onDrag

        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(tagScrollView.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    // MARK: - 空态

    private func setupEmptyView() {
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints {
            $0.top.equalTo(tagScrollView.snp.bottom).offset(120)
            $0.leading.trailing.bottom.equalToSuperview()
        }
        emptyView.isHidden = true
    }

    // MARK: - 数据加载

    private func loadTags() {
        TagService.fetchTags(scope: .common) { [weak self] result in
            guard let self else { return }
            if case .success(let tags) = result {
                self.tags = tags
                self.reloadTagButtons()
            }
        }
    }

    private func reloadTagButtons() {
        // 移除除"全部"外的旧按钮
        for btn in tagButtons.dropFirst() {
            tagStack.removeArrangedSubview(btn)
            btn.removeFromSuperview()
        }
        tagButtons = [tagButtons.first!]

        for (index, tag) in tags.enumerated() {
            let btn = makeTagButton(tag.name)
            btn.tag = index
            btn.addTarget(self, action: #selector(didTapTag(_:)), for: .touchUpInside)
            tagStack.addArrangedSubview(btn)
            tagButtons.append(btn)
        }
    }

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

        searchTextField.text = kw
        clearButton.isHidden = kw.isEmpty
        searchTextField.resignFirstResponder()

        if !kw.isEmpty {
            SearchHistoryManager.shared.add(kw)
        }
        currentKeyword = kw

        state = .searching
        currentPage = 1
        hasMore = true
        isLoading = false
        courses = []
        switchToResultUI()

        loadCourses(keyword: kw, tag: currentTag, page: 1)
    }

    private func loadCourses(keyword: String, tag: String, page: Int) {
        guard !isLoading else { return }
        isLoading = true

        SearchService.shared.searchCourses(keyword: keyword, tag: tag, page: page) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            switch result {
            case .success(let list):
                if page == 1 { self.courses = list } else { self.courses.append(contentsOf: list) }
                self.hasMore = list.count >= 20
                self.currentPage = page
                self.updateStateAfterLoad()
            case .failure(let error):
                self.state = .idle
                self.showToast("加载失败：\(error.localizedDescription)")
            }
        }
    }

    private func updateStateAfterLoad() {
        if courses.isEmpty {
            state = .empty
            emptyView.show(style: .empty("暂无相关课程"))
            emptyView.isHidden = false
            tableView.isHidden = true
        } else {
            state = .result
            emptyView.isHidden = true
            tableView.isHidden = false
            tableView.reloadData()
        }
        reloadIdleView()
    }

    // MARK: - UI 状态切换

    private func switchToIdle() {
        state = .idle
        currentKeyword = ""
        currentTag = ""
        selectedTagIndex = -1
        searchTextField.text = ""
        clearButton.isHidden = true
        updateTagStyle()
        scrollView.isHidden = false
        hotCardView.isHidden = false
        historyCardView.isHidden = false
        tableView.isHidden = true
        emptyView.isHidden = true
        reloadIdleView()
    }

    private func switchToResultUI() {
        scrollView.isHidden = true
        tableView.isHidden = true
        emptyView.isHidden = true
    }

    // MARK: - Actions

    @objc private func didTapSearch() {
        guard let text = searchTextField.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            // 空关键词也搜索（仅标签筛选）
            doSearch("")
            return
        }
        doSearch(text)
    }

    @objc private func didTapClear() {
        searchTextField.text = ""
        clearButton.isHidden = true
        switchToIdle()
    }

    @objc private func textDidChange() {
        let text = searchTextField.text ?? ""
        clearButton.isHidden = text.isEmpty
    }

    @objc private func didTapClearHistory() {
        SearchHistoryManager.shared.clear()
        reloadIdleView()
    }
}

// MARK: - UITextFieldDelegate

extension CourseViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if let text = textField.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            doSearch(text)
        }
        return true
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension CourseViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return courses.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchCourseCell", for: indexPath) as! SearchCourseCell
        cell.configure(with: courses[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let course = courses[indexPath.row]
        let vc = CourseDetailViewController(courseId: course.course_id)
        navigationController?.pushViewController(vc, animated: true)
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row == courses.count - 1, hasMore, !isLoading {
            currentPage += 1
            loadCourses(keyword: currentKeyword, tag: currentTag, page: currentPage)
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 131
    }
}