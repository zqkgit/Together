import UIKit
import SnapKit
import Kingfisher

/// 工作室更多页：Tab栏（找画室/找老师）+ 淮索栏 + 列表 + 分页
/// 对齐小程序 packageSocial/pages/studios/index.tsx
final class StudiosViewController: BaseViewController {

    // MARK: - Tab

    private enum StudioTab: Int, CaseIterable {
        case studio = 0
        case teacher = 1

        var title: String {
            switch self {
            case .studio:  return "找画室"
            case .teacher: return "找老师"
            }
        }
    }

    // MARK: - 状态

    private enum State {
        case idle
        case searching
        case result
        case empty
    }

    private var state: State = .idle
    private var currentTab: StudioTab = .studio
    private var currentKeyword: String = ""

    private var studios: [StudioItem] = []
    private var teachers: [TeacherItem] = []

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

    // Tab栏
    private let tabBar = UIView()
    private var tabButtons: [UIButton] = []
    private var tabUnderlines: [UIView] = []

    // 结果态
    private let tableView = UITableView(frame: .zero, style: .plain)

    // 空态
    private let emptyView = EmptyStateView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "工作室"
        view.backgroundColor = Theme.Color.bg

        setupBrandBackground()
        setupSearchHeader()
        setupTabBar()
        setupTableView()
        setupEmptyView()

        // 默认加载工作室列表
        doSearch("")
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
            $0.height.equalTo(200)
        }
    }

    // MARK: - 求索头部

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
            string: "搜索工作室或老师",
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

    // MARK: - Tab栏

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
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }

        for (index, tab) in StudioTab.allCases.enumerated() {
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
            } else {
                btn.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .normal)
                underline.isHidden = true
            }

            stack.addArrangedSubview(container)
            tabButtons.append(btn)
            tabUnderlines.append(underline)
        }
    }

    @objc private func didTapTab(_ sender: UIButton) {
        let index = sender.tag
        guard let tab = StudioTab(rawValue: index), tab != currentTab else { return }
        currentTab = tab
        updateTabStyle()

        // 切换tab重新搜索
        currentKeyword = ""
        searchTextField.text = ""
        clearButton.isHidden = true
        doSearch("")
    }

    private func updateTabStyle() {
        for (index, btn) in tabButtons.enumerated() {
            let isSelected = index == currentTab.rawValue
            btn.setTitleColor(isSelected ? .white : UIColor.white.withAlphaComponent(0.7), for: .normal)
            btn.titleLabel?.font = isSelected ? .appHero(14) : .appSection(14)
            tabUnderlines[index].isHidden = !isSelected
        }
    }

    // MARK: - 结果态（列表）

    private func setupTableView() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.register(SearchStudioCell.self, forCellReuseIdentifier: "SearchStudioCell")
        tableView.register(SearchTeacherCell.self, forCellReuseIdentifier: "SearchTeacherCell")
        tableView.dataSource = self
        tableView.delegate = self
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

    private func doSearch(_ keyword: String) {
        let kw = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        searchTextField.text = kw
        clearButton.isHidden = kw.isEmpty
        searchTextField.resignFirstResponder()

        currentKeyword = kw
        state = .searching
        currentPage = 1
        hasMore = true
        isLoading = false

        switch currentTab {
        case .studio:
            studios = []
            loadStudios(keyword: kw, page: 1)
        case .teacher:
            teachers = []
            loadTeachers(keyword: kw, page: 1)
        }
    }

    private func loadStudios(keyword: String, page: Int) {
        guard !isLoading else { return }
        isLoading = true

        SearchService.shared.searchStudios(keyword: keyword, page: page) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            switch result {
            case .success(let list):
                if page == 1 { self.studios = list } else { self.studios.append(contentsOf: list) }
                self.hasMore = list.count >= 20
                self.currentPage = page
                self.updateStateAfterLoad()
            case .failure(let error):
                self.showToast("加载失败：\(error.localizedDescription)")
            }
        }
    }

    private func loadTeachers(keyword: String, page: Int) {
        guard !isLoading else { return }
        isLoading = true

        SearchService.shared.searchTeachers(keyword: keyword, page: page) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            switch result {
            case .success(let list):
                if page == 1 { self.teachers = list } else { self.teachers.append(contentsOf: list) }
                self.hasMore = list.count >= 20
                self.currentPage = page
                self.updateStateAfterLoad()
            case .failure(let error):
                self.showToast("加载失败：\(error.localizedDescription)")
            }
        }
    }

    private func updateStateAfterLoad() {
        let isEmpty: Bool
        switch currentTab {
        case .studio:  isEmpty = studios.isEmpty
        case .teacher: isEmpty = teachers.isEmpty
        }

        if isEmpty {
            state = .empty
            let msg = currentTab == .studio ? "暂无工作室" : "暂无老师"
            emptyView.show(style: .empty(msg))
            emptyView.isHidden = false
            tableView.isHidden = true
        } else {
            state = .result
            emptyView.isHidden = true
            tableView.isHidden = false
            tableView.reloadData()
        }
    }

    // MARK: - Actions

    @objc private func didTapSearch() {
        let text = searchTextField.text ?? ""
        doSearch(text)
    }

    @objc private func didTapClear() {
        searchTextField.text = ""
        clearButton.isHidden = true
        doSearch("")
    }

    @objc private func textDidChange() {
        let text = searchTextField.text ?? ""
        clearButton.isHidden = text.isEmpty
    }
}

// MARK: - UITextFieldDelegate

extension StudiosViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        let text = textField.text ?? ""
        doSearch(text)
        return true
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension StudiosViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch currentTab {
        case .studio:  return studios.count
        case .teacher: return teachers.count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch currentTab {
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
        case .studio:  count = studios.count
        case .teacher: count = teachers.count
        }

        if indexPath.row == count - 1, hasMore, !isLoading {
            currentPage += 1
            switch currentTab {
            case .studio:  loadStudios(keyword: currentKeyword, page: currentPage)
            case .teacher: loadTeachers(keyword: currentKeyword, page: currentPage)
            }
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch currentTab {
        case .studio:  return 131
        case .teacher: return 131
        }
    }
}