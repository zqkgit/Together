import UIKit
import SnapKit
import Kingfisher

/// 课程浏览页（首页"全部"入口）：标签横向筛选 + 课程卡片列表，无搜索栏
/// 对齐小程序 packageCourses/pages/courses/index.tsx
final class CourseBrowseViewController: BaseViewController {

    // MARK: - 状态

    private var tags: [TagItem] = []
    private var selectedTagId: String = ""
    private var courses: [CourseItem] = []
    private var currentPage = 1
    private var hasMore = true
    private var isLoading = false

    // MARK: - UI

    private let brandBackgroundView = UIView()

    // 标签栏
    private let tagScrollView = UIScrollView()
    private let tagStack = UIStackView()

    // 列表
    private let tableView = UITableView(frame: .zero, style: .plain)

    // 空态
    private let emptyView = EmptyStateView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = "课程列表"
        view.backgroundColor = Theme.Color.bg

        setupBrandBackground()
        setupTagBar()
        setupTableView()
        setupEmptyView()

        loadTags()
        loadCourses(page: 1)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "课程列表", titleColor: .white, backTint: .white)
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
            $0.height.equalTo(100)
        }
    }

    // MARK: - 标签栏

    private func setupTagBar() {
        tagScrollView.backgroundColor = Theme.Color.brand
        tagScrollView.showsHorizontalScrollIndicator = false
        tagScrollView.showsVerticalScrollIndicator = false
        tagScrollView.contentInset = UIEdgeInsets(top: 0, left: Theme.Spacing.m, bottom: 0, right: Theme.Spacing.m)
        view.addSubview(tagScrollView)
        tagScrollView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(44)
        }

        tagStack.axis = .horizontal
        tagStack.spacing = Theme.Spacing.s
        tagStack.alignment = .center
        tagScrollView.addSubview(tagStack)
        tagStack.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.height.equalToSuperview()
        }

        // 默认"全部"标签
        addTagButton("全部", isSelected: true)
    }

    private func addTagButton(_ title: String, isSelected: Bool = false) {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
        config.cornerStyle = .capsule

        let btn = UIButton(type: .custom)
        btn.configuration = config
        btn.tag = tagStack.arrangedSubviews.count
        btn.addTarget(self, action: #selector(didTapTag(_:)), for: .touchUpInside)
        updateTagStyle(btn, selected: isSelected)
        tagStack.addArrangedSubview(btn)
    }

    private func updateTagStyle(_ btn: UIButton, selected: Bool) {
        guard var config = btn.configuration else { return }
        if selected {
            btn.backgroundColor = .white
            config.baseForegroundColor = Theme.Color.brand
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = .appHero(13)
                return outgoing
            }
        } else {
            btn.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            config.baseForegroundColor = .white
            config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
                var outgoing = incoming
                outgoing.font = .appLabel(13)
                return outgoing
            }
        }
        btn.configuration = config
    }

    @objc private func didTapTag(_ sender: UIButton) {
        let index = sender.tag
        let tagId: String
        if index == 0 {
            tagId = "" // "全部"
        } else if index <= tags.count {
            tagId = tags[index - 1].tagId
        } else {
            return
        }

        guard tagId != selectedTagId else { return }
        selectedTagId = tagId

        // 更新样式
        for (i, view) in tagStack.arrangedSubviews.enumerated() {
            guard let btn = view as? UIButton else { continue }
            updateTagStyle(btn, selected: i == index)
        }

        // 重新加载
        currentPage = 1
        hasMore = true
        courses = []
        loadCourses(page: 1)
    }

    // MARK: - 列表

    private func setupTableView() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.register(SearchCourseCell.self, forCellReuseIdentifier: "SearchCourseCell")
        tableView.dataSource = self
        tableView.delegate = self
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
        SearchService.shared.fetchTags { [weak self] result in
            guard let self else { return }
            if case .success(let list) = result {
                self.tags = list
                // 在"全部"之后追加标签按钮
                for item in list {
                    self.addTagButton(item.name)
                }
            }
        }
    }

    private func loadCourses(page: Int) {
        guard !isLoading else { return }
        isLoading = true

        SearchService.shared.searchCourses(keyword: "", tag: selectedTagId, page: page) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            switch result {
            case .success(let list):
                if page == 1 { self.courses = list } else { self.courses.append(contentsOf: list) }
                self.hasMore = list.count >= 20
                self.currentPage = page
                self.updateStateAfterLoad()
            case .failure(let error):
                self.showToast("加载失败：\(error.localizedDescription)")
            }
        }
    }

    private func updateStateAfterLoad() {
        if courses.isEmpty {
            emptyView.show(style: .empty("暂无课程"))
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

extension CourseBrowseViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        courses.count
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
            loadCourses(page: currentPage)
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        131
    }
}