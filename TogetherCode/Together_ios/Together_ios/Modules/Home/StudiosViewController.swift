import UIKit
import SnapKit
import Kingfisher

/// 工作室更多页：Tab栏（找画室/找老师）+ 列表 + 分页
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

    private var currentTab: StudioTab = .studio
    private var studios: [StudioItem] = []
    private var teachers: [TeacherItem] = []
    private var currentPage = 1
    private var hasMore = true
    private var isLoading = false

    // MARK: - UI

    private let brandBackgroundView = UIView()

    // Tab栏
    private let tabBar = UIView()
    private var tabButtons: [UIButton] = []
    private var tabUnderlines: [UIView] = []

    // 列表
    private let tableView = UITableView(frame: .zero, style: .plain)

    // 空态
    private let emptyView = EmptyStateView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "工作室"
        view.backgroundColor = Theme.Color.bg

        setupBrandBackground()
        setupTabBar()
        setupTableView()
        setupEmptyView()

        // 默认加载工作室列表
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "工作室", titleColor: .white, backTint: .white)
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
            $0.height.equalTo(140)
        }
    }

    // MARK: - Tab栏

    private func setupTabBar() {
        tabBar.backgroundColor = Theme.Color.brand
        view.addSubview(tabBar)
        tabBar.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(44)
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

        // 切换tab重新加载
        currentPage = 1
        hasMore = true
        loadData()
    }

    private func updateTabStyle() {
        for (index, btn) in tabButtons.enumerated() {
            let isSelected = index == currentTab.rawValue
            btn.setTitleColor(isSelected ? .white : UIColor.white.withAlphaComponent(0.7), for: .normal)
            btn.titleLabel?.font = isSelected ? .appHero(14) : .appSection(14)
            tabUnderlines[index].isHidden = !isSelected
        }
    }

    // MARK: - 列表

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

    private func loadData() {
        switch currentTab {
        case .studio:
            studios = []
            loadStudios(page: 1)
        case .teacher:
            teachers = []
            loadTeachers(page: 1)
        }
    }

    private func loadStudios(page: Int) {
        guard !isLoading else { return }
        isLoading = true

        SearchService.shared.searchStudios(keyword: "", page: page) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            switch result {
            case .success(let list):
                if page == 1 { self.studios = list.sorted { ($0.distance ?? .infinity) < ($1.distance ?? .infinity) } } else {
                    self.studios.append(contentsOf: list)
                    self.studios.sort { ($0.distance ?? .infinity) < ($1.distance ?? .infinity) }
                }
                self.hasMore = list.count >= 20
                self.currentPage = page
                self.updateStateAfterLoad()
            case .failure(let error):
                self.showToast("加载失败：\(error.localizedDescription)")
            }
        }
    }

    private func loadTeachers(page: Int) {
        guard !isLoading else { return }
        isLoading = true

        SearchService.shared.searchTeachers(keyword: "", page: page) { [weak self] result in
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
            let msg = currentTab == .studio ? "暂无工作室" : "暂无老师"
            emptyView.show(style: .empty(msg))
            emptyView.isHidden = false
            tableView.isHidden = true
        } else {
            emptyView.isHidden = true
            tableView.isHidden = false
            tableView.reloadData()
        }
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
            case .studio:  loadStudios(page: currentPage)
            case .teacher: loadTeachers(page: currentPage)
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