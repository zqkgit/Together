import UIKit
import SnapKit
import Kingfisher

/// 搜索页：三Tab（课程/工作室/老师）+ 热词历史 + 行卡结果列表
/// 参考小程序搜索页设计：品牌色头部 + 下划线Tab + 行卡列表
final class SearchViewController: BaseViewController {

    // MARK: - 搜索Tab

    private enum SearchTab: Int, CaseIterable {
        case course = 0
        case studio = 1
        case teacher = 2

        var title: String {
            switch self {
            case .course:  return "课程"
            case .studio:  return "工作室"
            case .teacher: return "老师"
            }
        }
    }

    // MARK: - 状态

    private enum State {
        case idle          // 默认态（热词 + 历史）
        case searching     // 请求中
        case result        // 有结果
        case empty         // 无结果
    }

    private var state: State = .idle
    private var currentTab: SearchTab = .course
    private var currentKeyword: String = ""

    // 三类结果
    private var courses: [CourseItem] = []
    private var studios: [StudioItem] = []
    private var teachers: [TeacherItem] = []

    private var hotKeywords: [String] = []
    private var currentPage = 1
    private var hasMore = true
    private var isLoading = false

    // MARK: - UI

    // 品牌色背景（覆盖导航栏 + 搜索头部 + Tab栏区域）
    private let brandBackgroundView = UIView()
    private let searchHeaderView = UIView()
    private let searchBarContainer = UIView()
    private let searchTextField = UITextField()
    private let searchButton = UIButton(type: .custom)
    private let clearButton = UIButton(type: .custom)

    // Tab栏
    private let tabBar = UIView()
    private var tabButtons: [UIButton] = []
    private var tabUnderline: UIView?

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

    // 结果态（列表）
    private let tableView = UITableView(frame: .zero, style: .plain)

    // 空态
    private let emptyView = EmptyStateView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "搜索"
        view.backgroundColor = Theme.Color.bg

        setupBrandBackground()
        setupSearchHeader()
        setupTabBar()
        setupScrollView()
        setupIdleView()
        setupTableView()
        setupEmptyView()
        loadHotKeywords()
        reloadIdleView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "搜索", titleColor: .white, backTint: .white)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if state == .idle {
            searchTextField.becomeFirstResponder()
        }
    }

    // MARK: - 哜牌色背景（覆盖导航栏 + Tab栏区域）

    private func setupBrandBackground() {
        brandBackgroundView.backgroundColor = Theme.Color.brand
        view.addSubview(brandBackgroundView)
        brandBackgroundView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(180) // 覆盖导航栏(~44pt状态栏+44pt) + Tab栏(40pt) + 余量
        }
    }

    // MARK: - 搜索头部（导航栏下方独立区域）

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
            string: "搜索课程、工作室、老师",
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

    // MARK: - Tab栏（品牌色背景 + 下划线指示器）

    private func setupTabBar() {
        tabBar.backgroundColor = Theme.Color.brand
        view.addSubview(tabBar)
        tabBar.snp.makeConstraints {
            $0.top.equalTo(searchHeaderView.snp.bottom)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(40)
        }

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        tabBar.addSubview(stack)
        stack.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        for (index, tab) in SearchTab.allCases.enumerated() {
            let container = UIView()
            container.tag = index

            let btn = UIButton(type: .system)
            btn.setTitle(tab.title, for: .normal)
            btn.titleLabel?.font = .appSection(14)
            btn.tag = index
            btn.addTarget(self, action: #selector(didTapTab(_:)), for: .touchUpInside)
            container.addSubview(btn)
            btn.snp.makeConstraints {
                $0.centerX.equalToSuperview()
                $0.top.equalToSuperview().offset(4)
            }

            // 下划线
            let underline = UIView()
            underline.backgroundColor = .white
            underline.layer.cornerRadius = 1.5
            container.addSubview(underline)
            underline.snp.makeConstraints {
                $0.centerX.equalToSuperview()
                $0.top.equalTo(btn.snp.bottom).offset(4)
                $0.width.equalTo(24)
                $0.height.equalTo(3)
                $0.bottom.equalToSuperview().offset(-6)
            }

            if index == 0 {
                btn.setTitleColor(.white, for: .normal)
                btn.titleLabel?.font = .appHero(14)
                underline.isHidden = false
                tabUnderline = underline
            } else {
                btn.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .normal)
                underline.isHidden = true
            }

            tabButtons.append(btn)
            stack.addArrangedSubview(container)

            // 点击整个container区域
            let tap = UITapGestureRecognizer(target: self, action: #selector(didTapTabContainer(_:)))
            container.addGestureRecognizer(tap)
            container.isUserInteractionEnabled = true
        }
    }

    private func updateTabStyle() {
        for (index, btn) in tabButtons.enumerated() {
            let isSelected = index == currentTab.rawValue
            btn.setTitleColor(isSelected ? .white : UIColor.white.withAlphaComponent(0.7), for: .normal)
            btn.titleLabel?.font = isSelected ? .appHero(14) : .appSection(14)

            // 更新下划线
            guard let container = btn.superview else { continue }
            for sub in container.subviews {
                if sub is UIView && sub != btn && sub.backgroundColor == .white {
                    sub.isHidden = !isSelected
                }
            }
        }
    }

    @objc private func didTapTab(_ sender: UIButton) {
        let newTab = SearchTab(rawValue: sender.tag) ?? .course
        guard newTab != currentTab else { return }
        currentTab = newTab
        updateTabStyle()
        if !currentKeyword.isEmpty && state != .idle {
            doSearch(currentKeyword)
        }
    }

    @objc private func didTapTabContainer(_ gesture: UITapGestureRecognizer) {
        guard let container = gesture.view else { return }
        let newTab = SearchTab(rawValue: container.tag) ?? .course
        guard newTab != currentTab else { return }
        currentTab = newTab
        updateTabStyle()
        if !currentKeyword.isEmpty && state != .idle {
            doSearch(currentKeyword)
        }
    }

    // MARK: - 滚动容器（默认态）

    private func setupScrollView() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints {
            $0.top.equalTo(tabBar.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints { $0.edges.equalToSuperview(); $0.width.equalToSuperview() }
    }

    // MARK: - 默认态（热词 + 历史）— 卡片样式

    private func setupIdleView() {
        // ---- 热词卡片 ----
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

        // ---- 历史卡片 ----
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
        tableView.register(SearchStudioCell.self, forCellReuseIdentifier: "SearchStudioCell")
        tableView.register(SearchTeacherCell.self, forCellReuseIdentifier: "SearchTeacherCell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.isHidden = true
        tableView.keyboardDismissMode = .onDrag

        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(tabBar.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    // MARK: - 空态

    private func setupEmptyView() {
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints {
            $0.top.equalTo(tabBar.snp.bottom).offset(120)
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
        clearButton.isHidden = false
        searchTextField.resignFirstResponder()
        SearchHistoryManager.shared.add(kw)
        currentKeyword = kw

        state = .searching
        currentPage = 1
        hasMore = true
        isLoading = false
        clearCurrentResults()
        switchToResultUI()

        loadResults(keyword: kw, page: 1)
    }

    private func clearCurrentResults() {
        switch currentTab {
        case .course:  courses = []
        case .studio:  studios = []
        case .teacher: teachers = []
        }
    }

    private func loadResults(keyword: String, page: Int) {
        guard !isLoading else { return }
        isLoading = true

        switch currentTab {
        case .course:
            SearchService.shared.searchCourses(keyword: keyword, page: page) { [weak self] result in
                self?.handleResult(result, page: page)
            }
        case .studio:
            SearchService.shared.searchStudios(keyword: keyword, page: page) { [weak self] result in
                self?.handleStudioResult(result, page: page)
            }
        case .teacher:
            SearchService.shared.searchTeachers(keyword: keyword, page: page) { [weak self] result in
                self?.handleTeacherResult(result, page: page)
            }
        }
    }

    private func handleResult(_ result: Result<[CourseItem], APIError>, page: Int) {
        isLoading = false
        switch result {
        case .success(let list):
            if page == 1 { courses = list } else { courses.append(contentsOf: list) }
            hasMore = list.count >= 20
            currentPage = page
            updateStateAfterLoad(emptyMsg: "暂无相关课程")
        case .failure(let error):
            state = .idle
            showToast("搜索失败：\(error.localizedDescription)")
        }
    }

    private func handleStudioResult(_ result: Result<[StudioItem], APIError>, page: Int) {
        isLoading = false
        switch result {
        case .success(let list):
            if page == 1 { studios = list } else { studios.append(contentsOf: list) }
            hasMore = list.count >= 20
            currentPage = page
            updateStateAfterLoad(emptyMsg: "暂无相关工作室")
        case .failure(let error):
            state = .idle
            showToast("搜索失败：\(error.localizedDescription)")
        }
    }

    private func handleTeacherResult(_ result: Result<[TeacherItem], APIError>, page: Int) {
        isLoading = false
        switch result {
        case .success(let list):
            if page == 1 { teachers = list } else { teachers.append(contentsOf: list) }
            hasMore = list.count >= 20
            currentPage = page
            updateStateAfterLoad(emptyMsg: "暂无相关老师")
        case .failure(let error):
            state = .idle
            showToast("搜索失败：\(error.localizedDescription)")
        }
    }

    private func updateStateAfterLoad(emptyMsg: String) {
        let itemCount: Int
        switch currentTab {
        case .course:  itemCount = courses.count
        case .studio:  itemCount = studios.count
        case .teacher: itemCount = teachers.count
        }

        if itemCount == 0 {
            state = .empty
            emptyView.show(style: .empty(emptyMsg))
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
        searchTextField.text = ""
        clearButton.isHidden = true
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

    @objc private func didTapBack() {
        searchTextField.resignFirstResponder()
        navigationController?.popViewController(animated: true)
    }

    @objc private func didTapSearch() {
        guard let text = searchTextField.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
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

extension SearchViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // 不在return时搜索，仅收起键盘
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension SearchViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch currentTab {
        case .course:  return courses.count
        case .studio:  return studios.count
        case .teacher: return teachers.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch currentTab {
        case .course:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SearchCourseCell", for: indexPath) as! SearchCourseCell
            cell.configure(with: courses[indexPath.row])
            return cell
        case .studio:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SearchStudioCell", for: indexPath) as! SearchStudioCell
            cell.configure(with: studios[indexPath.row])
            return cell
        case .teacher:
            let cell = tableView.dequeueReusableCell(withIdentifier: "SearchTeacherCell", for: indexPath) as! SearchTeacherCell
            cell.configure(with: teachers[indexPath.row])
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch currentTab {
        case .course:
            let course = courses[indexPath.row]
            let vc = CourseDetailViewController(courseId: course.course_id)
            navigationController?.pushViewController(vc, animated: true)
        case .studio:
            let studio = studios[indexPath.row]
            let vc = StudioHomepageViewController(studioId: studio.studio_id)
            navigationController?.pushViewController(vc, animated: true)
        case .teacher:
            let teacher = teachers[indexPath.row]
            let vc = TeacherProfileViewController(teacherId: teacher.teacher_id)
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let count: Int
        switch currentTab {
        case .course:  count = courses.count
        case .studio:  count = studios.count
        case .teacher: count = teachers.count
        }
        if indexPath.row == count - 1, hasMore, !isLoading {
            currentPage += 1
            loadResults(keyword: currentKeyword, page: currentPage)
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch currentTab {
        case .course:  return 131
        case .studio:  return 131
        case .teacher: return 96
        }
    }
}

// MARK: - 课程行卡 Cell（大封面 + 2行标题 + 标签pill + 红色价格 + 划线原价）

final class SearchCourseCell: UITableViewCell {

    private let coverView = UIImageView()
    private let titleLabel = UILabel()
    private let tagStack = UIStackView()
    private let priceLabel = UILabel()
    private let originalPriceLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        // 卡片容器
        let cardView = UIView()
        cardView.backgroundColor = Theme.Color.surface
        cardView.layer.cornerRadius = Theme.Radius.card
        cardView.layer.shadowColor = Theme.Shadow.card.color.cgColor
        cardView.layer.shadowOpacity = Theme.Shadow.card.opacity
        cardView.layer.shadowOffset = Theme.Shadow.card.offset
        cardView.layer.shadowRadius = Theme.Shadow.card.radius
        contentView.addSubview(cardView)
        cardView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.top.equalToSuperview().offset(Theme.Spacing.s)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.s)
        }

        // 封面（100×75，圆角）
        coverView.contentMode = .scaleAspectFill
        coverView.clipsToBounds = true
        coverView.layer.cornerRadius = Theme.Radius.icon
        cardView.addSubview(coverView)
        coverView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
            $0.width.equalTo(100)
            $0.height.equalTo(75)
        }

        // 右侧信息区
        let infoView = UIView()
        cardView.addSubview(infoView)
        infoView.snp.makeConstraints {
            $0.leading.equalTo(coverView.snp.trailing).offset(Theme.Spacing.m)
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.m)
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.m)
        }

        // 标题（2行）
        titleLabel.font = .appSection(15)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 2
        infoView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.trailing.equalToSuperview()
        }

        // 标签容器
        tagStack.axis = .horizontal
        tagStack.spacing = Theme.Spacing.xs
        infoView.addSubview(tagStack)
        tagStack.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.equalToSuperview()
            $0.height.equalTo(20)
        }

        // 价格行
        let priceStack = UIStackView()
        priceStack.axis = .horizontal
        priceStack.spacing = Theme.Spacing.s
        priceStack.alignment = .firstBaseline
        infoView.addSubview(priceStack)
        priceStack.snp.makeConstraints {
            $0.top.equalTo(tagStack.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.equalToSuperview()
            $0.bottom.equalToSuperview()
        }

        // 现价（红色）
        priceLabel.font = .appHero(16)
        priceLabel.textColor = Theme.Color.danger
        priceStack.addArrangedSubview(priceLabel)

        // 原价（划线灰色）
        originalPriceLabel.font = .appLabel(12)
        originalPriceLabel.textColor = Theme.Color.muted
        priceStack.addArrangedSubview(originalPriceLabel)
    }

    func configure(with item: CourseItem) {
        // 封面
        if let cover = item.cover, let url = URL(string: cover) {
            coverView.kf.setImage(with: url, placeholder: UIImage(systemName: "photo"))
        } else {
            coverView.image = UIImage(systemName: "photo")
        }

        // 标题
        titleLabel.text = item.title

        // 标签pill（显示名称而非 tag_id）
        tagStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let displayTags = item.tagNames.prefix(3)
        for name in displayTags {
            let pill = makeTagPill(name)
            tagStack.addArrangedSubview(pill)
        }
        // 年龄段标签
        if let text = item.ageRangeText {
            let agePill = makeTagPill(text)
            tagStack.addArrangedSubview(agePill)
        }

        // 价格（price 为分，使用 fenToYuanText）
        if item.price > 0 {
            priceLabel.text = item.price.fenToYuanText
        } else {
            priceLabel.text = "免费"
        }

        // 原价
        if let originalText = item.originalPriceText {
            let attrStr = NSAttributedString(
                string: originalText,
                attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue, .foregroundColor: Theme.Color.muted]
            )
            originalPriceLabel.attributedText = attrStr
            originalPriceLabel.isHidden = false
        } else {
            originalPriceLabel.isHidden = true
        }
    }

    private func makeTagPill(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .appLabel(10)
        label.textColor = Theme.Color.brand
        label.textAlignment = .center
        label.backgroundColor = Theme.Color.brandSoft
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        label.snp.makeConstraints { $0.height.equalTo(20) }
        // 内边距
        label.layoutMargins = UIEdgeInsets(top: 2, left: 8, bottom: 2, right: 8)
        return label
    }
}

// MARK: - 工作室行卡 Cell（大封面 + 标签pill + 地址）

final class SearchStudioCell: UITableViewCell {

    private let coverView = UIImageView()
    private let titleLabel = UILabel()
    private let tagStack = UIStackView()
    private let addressLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        // 卡片容器
        let cardView = UIView()
        cardView.backgroundColor = Theme.Color.surface
        cardView.layer.cornerRadius = Theme.Radius.card
        cardView.layer.shadowColor = Theme.Shadow.card.color.cgColor
        cardView.layer.shadowOpacity = Theme.Shadow.card.opacity
        cardView.layer.shadowOffset = Theme.Shadow.card.offset
        cardView.layer.shadowRadius = Theme.Shadow.card.radius
        contentView.addSubview(cardView)
        cardView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.top.equalToSuperview().offset(Theme.Spacing.s)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.s)
        }

        // 封面（100×75）
        coverView.contentMode = .scaleAspectFill
        coverView.clipsToBounds = true
        coverView.layer.cornerRadius = Theme.Radius.icon
        cardView.addSubview(coverView)
        coverView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
            $0.width.equalTo(100)
            $0.height.equalTo(75)
        }

        let infoView = UIView()
        cardView.addSubview(infoView)
        infoView.snp.makeConstraints {
            $0.leading.equalTo(coverView.snp.trailing).offset(Theme.Spacing.m)
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.m)
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.m)
        }

        // 名称
        titleLabel.font = .appSection(15)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 1
        infoView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.trailing.equalToSuperview()
        }

        // 标签
        tagStack.axis = .horizontal
        tagStack.spacing = Theme.Spacing.xs
        infoView.addSubview(tagStack)
        tagStack.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.equalToSuperview()
            $0.height.equalTo(20)
        }

        // 地址
        addressLabel.font = .appLabel(12)
        addressLabel.textColor = Theme.Color.muted
        addressLabel.numberOfLines = 1
        infoView.addSubview(addressLabel)
        addressLabel.snp.makeConstraints {
            $0.top.equalTo(tagStack.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalToSuperview()
        }
    }

    func configure(with item: StudioItem) {
        if let cover = item.cover, let url = URL(string: cover) {
            coverView.kf.setImage(with: url, placeholder: UIImage(systemName: "photo"))
        } else {
            coverView.image = UIImage(systemName: "photo")
        }

        titleLabel.text = item.name

        tagStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let tags = (item.type_tags ?? []).prefix(3)
        for tag in tags {
            let pill = makeTagPill(tag)
            tagStack.addArrangedSubview(pill)
        }

        addressLabel.text = item.rowMetaText
    }

    private func makeTagPill(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .appLabel(10)
        label.textColor = Theme.Color.brand
        label.textAlignment = .center
        label.backgroundColor = Theme.Color.brandSoft
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        label.snp.makeConstraints { $0.height.equalTo(20) }
        return label
    }
}

// MARK: - 老师行卡 Cell（48pt圆形头像 + 姓名 + 工作室名）

final class SearchTeacherCell: UITableViewCell {

    private let cardView = UIView()
    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let studioLabel = UILabel()
    private let subjectLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        // 卡片容器
        cardView.backgroundColor = Theme.Color.surface
        cardView.layer.cornerRadius = Theme.Radius.card
        cardView.layer.shadowColor = Theme.Shadow.card.color.cgColor
        cardView.layer.shadowOpacity = Theme.Shadow.card.opacity
        cardView.layer.shadowOffset = Theme.Shadow.card.offset
        cardView.layer.shadowRadius = Theme.Shadow.card.radius
        contentView.addSubview(cardView)
        cardView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.cardInner)
            $0.top.equalToSuperview().offset(8)
            $0.bottom.equalToSuperview().offset(-8)
        }

        // 头像（48pt圆形）
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 24
        avatarView.backgroundColor = Theme.Color.brandSoft
        cardView.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(48)
        }

        let infoView = UIView()
        cardView.addSubview(infoView)
        infoView.snp.makeConstraints {
            $0.leading.equalTo(avatarView.snp.trailing).offset(Theme.Spacing.m)
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.m)
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.m)
        }

        // 姓名
        nameLabel.font = .appSection(15)
        nameLabel.textColor = Theme.Color.ink
        infoView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.equalToSuperview()
        }

        // 科目标签
        subjectLabel.font = .appLabel(10)
        subjectLabel.textColor = Theme.Color.brand
        subjectLabel.textAlignment = .center
        subjectLabel.backgroundColor = Theme.Color.brandSoft
        subjectLabel.layer.cornerRadius = 10
        subjectLabel.clipsToBounds = true
        infoView.addSubview(subjectLabel)
        subjectLabel.snp.makeConstraints {
            $0.leading.equalTo(nameLabel.snp.trailing).offset(Theme.Spacing.s)
            $0.centerY.equalTo(nameLabel)
            $0.height.equalTo(20)
        }

        // 工作室名
        studioLabel.font = .appLabel(12)
        studioLabel.textColor = Theme.Color.muted
        studioLabel.numberOfLines = 1
        infoView.addSubview(studioLabel)
        studioLabel.snp.makeConstraints {
            $0.top.equalTo(nameLabel.snp.bottom).offset(Theme.Spacing.xs)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalToSuperview()
        }
    }

    func configure(with item: TeacherItem) {
        if let avatar = item.avatar, let url = URL(string: avatar) {
            avatarView.kf.setImage(with: url, placeholder: UIImage(systemName: "person.circle"))
        } else {
            avatarView.image = UIImage(systemName: "person.circle")
        }

        nameLabel.text = item.displayName

        // 科目
        let subjects = (item.subjects ?? []).prefix(2)
        if !subjects.isEmpty {
            subjectLabel.text = subjects.joined(separator: "·")
            subjectLabel.isHidden = false
        } else {
            subjectLabel.isHidden = true
        }

        // 工作室名
        let studioNames = (item.studios ?? []).compactMap(\.name).prefix(2)
        studioLabel.text = studioNames.isEmpty ? "暂无工作室" : studioNames.joined(separator: "·")
    }
}
