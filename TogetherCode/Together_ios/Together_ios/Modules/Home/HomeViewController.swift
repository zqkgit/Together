import UIKit
import SnapKit
import ESPullToRefresh

/// 首页：UITableView 实现（对齐 PR 设计图 #parentHome）
/// 分区：顶部(搜索+Hero) / 公告 / 为你推荐 / 附近热门工作室 / 老师动态
final class HomeViewController: BaseViewController {

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let searchBar = HomeSearchBar()
    private var rows: [[HomeRow]] = []
    private var data = HomeService.HomeData()
    private var hasLoaded = false

    /// 首页行类型（按渲染顺序）
    enum HomeRow {
        case hero
        case notice
        case courseHeader
        case courseRow
        case studioHeader
        case studio(StudioItem)
        case postHeader
        case post(PostItem)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "艺启"
        navigationController?.navigationBar.prefersLargeTitles = false
        view.backgroundColor = Theme.Color.bg
        setupTableView()
        loadData()
    }

    // MARK: - UI

    private func setupTableView() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.alwaysBounceHorizontal = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        // 底部 Tab 占位；顶部间距由 Hero cell 承担；左右边距统一由 cell 内容 inset 12 承担，避免表格横向滑动
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 120, right: 0)
        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.refresh()
        }

        tableView.register(HomeHeroCell.self, forCellReuseIdentifier: "HomeHeroCell")
        tableView.register(HomeNoticeCell.self, forCellReuseIdentifier: "HomeNoticeCell")
        tableView.register(HomeSectionCell.self, forCellReuseIdentifier: "HomeSectionCell")
        tableView.register(HomeCourseRowCell.self, forCellReuseIdentifier: "HomeCourseRowCell")
        tableView.register(HomeStudioCell.self, forCellReuseIdentifier: "HomeStudioCell")
        tableView.register(HomePostCell.self, forCellReuseIdentifier: "HomePostCell")

        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        view.addSubview(searchBar)
        // 搜索条固定在导航栏下方（左右 12），不随列表滚动
        searchBar.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }
        searchBar.onTap = { [weak self] in self?.showToast("搜索页开发中") }
        tableView.snp.makeConstraints {
            $0.top.equalTo(searchBar.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    // MARK: - Data

    private func loadData() {
        showLoading()
        HomeService.shared.fetchHome { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            self.tableView.es.stopPullToRefresh()
            switch result {
            case .success(let data):
                self.render(data)
            case .failure(let error):
                if !self.hasLoaded {
                    self.showToast("加载失败：\(error.localizedDescription)")
                }
            }
        }
    }

    @objc private func refresh() {
        HomeService.shared.fetchHome { [weak self] result in
            guard let self else { return }
            self.tableView.es.stopPullToRefresh()
            if case .success(let data) = result {
                self.render(data)
            }
        }
    }

    private func render(_ data: HomeService.HomeData) {
        hasLoaded = true
        self.data = data

        var sections: [[HomeRow]] = [
            [.hero]
        ]

        // 公告（空隐藏）
        sections.append(data.announcements.isEmpty ? [] : [.notice])

        // 为你推荐（空隐藏：header + 横滑行）
        if data.courses.isEmpty {
            sections.append([])
        } else {
            sections.append([.courseHeader, .courseRow])
        }

        // 附近热门工作室（空隐藏：header + 每工作室一行）
        if data.studios.isEmpty {
            sections.append([])
        } else {
            sections.append([.studioHeader] + data.studios.map { .studio($0) })
        }

        // 老师动态（空隐藏：header + 每帖一行）
        if data.posts.isEmpty {
            sections.append([])
        } else {
            sections.append([.postHeader] + data.posts.map { .post($0) })
        }

        rows = sections
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource / Delegate

extension HomeViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { rows.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows[section].count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch rows[indexPath.section][indexPath.row] {
        case .hero:
            let cell = tableView.dequeueReusableCell(withIdentifier: "HomeHeroCell", for: indexPath) as! HomeHeroCell
            cell.reload(children: data.children)
            cell.onAddChild = { [weak self] in self?.showToast("添加孩子开发中") }
            cell.onChildTap = { [weak self] _ in self?.showToast("孩子成长页开发中") }
            return cell
        case .notice:
            let cell = tableView.dequeueReusableCell(withIdentifier: "HomeNoticeCell", for: indexPath) as! HomeNoticeCell
            cell.update(announcements: data.announcements)
            cell.onTap = { [weak self] in self?.showToast("公告列表开发中") }
            return cell
        case .courseHeader:
            let cell = tableView.dequeueReusableCell(withIdentifier: "HomeSectionCell", for: indexPath) as! HomeSectionCell
            cell.configure(title: "为你推荐", more: "全部") { [weak self] in self?.showToast("课程列表开发中") }
            return cell
        case .courseRow:
            let cell = tableView.dequeueReusableCell(withIdentifier: "HomeCourseRowCell", for: indexPath) as! HomeCourseRowCell
            cell.reload(items: data.courses)
            cell.onCourseTap = { [weak self] _ in self?.showToast("课程详情开发中") }
            return cell
        case .studioHeader:
            let cell = tableView.dequeueReusableCell(withIdentifier: "HomeSectionCell", for: indexPath) as! HomeSectionCell
            cell.configure(title: "附近热门工作室", more: "更多") { [weak self] in self?.showToast("工作室列表开发中") }
            return cell
        case .studio(let item):
            let cell = tableView.dequeueReusableCell(withIdentifier: "HomeStudioCell", for: indexPath) as! HomeStudioCell
            cell.configure(item: item)
            cell.onTap = { [weak self] in self?.showToast("工作室主页开发中") }
            return cell
        case .postHeader:
            let cell = tableView.dequeueReusableCell(withIdentifier: "HomeSectionCell", for: indexPath) as! HomeSectionCell
            cell.configure(title: "老师动态", more: "更多") { [weak self] in self?.showToast("广场开发中") }
            return cell
        case .post(let item):
            let cell = tableView.dequeueReusableCell(withIdentifier: "HomePostCell", for: indexPath) as! HomePostCell
            cell.configure(item: item)
            cell.onTap = { [weak self] in self?.showToast("帖子详情开发中") }
            return cell
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // 固定行高 = 组内顶部间距 + 组件高度；帖子卡按内容自动
        switch rows[indexPath.section][indexPath.row] {
        case .hero: return data.children.isEmpty ? 232 : 252   // 12 顶部间距 + Hero 220/240
        case .notice: return 64                                 // 20 顶部间距 + 公告 44
        case .courseHeader, .studioHeader, .postHeader: return 56  // 24 顶部间距 + 标题 32
        case .courseRow: return 244                             // 12 顶部间距 + 卡片 232
        case .studio: return 88                                  // 12 顶部间距 + 行 76
        case .post: return UITableView.automaticDimension
        }
    }
}

// MARK: - Cells（复用既有组件，左右 12pt 由 cell 内容 inset 提供）

/// Hero（问候 + 孩子进度卡）
final class HomeHeroCell: UITableViewCell {
    var onAddChild: (() -> Void)?
    var onChildTap: ((ChildItem) -> Void)?

    private let hero = HomeHeroView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(hero)
        // 顶部 12（与搜索条间距）+ 左右 12 + 底部 0
        hero.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview()
        }
        hero.onAddChild = { [weak self] in self?.onAddChild?() }
        hero.onChildTap = { [weak self] item in self?.onChildTap?(item) }
    }

    func reload(children: [ChildItem]) { hero.reload(children: children) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// 公告条
final class HomeNoticeCell: UITableViewCell {
    var onTap: (() -> Void)?

    private let notice = HomeNoticeCard()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(notice)
        // 顶部 20（与 Hero 间距）+ 左右 12 + 底部 0
        notice.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview()
        }
        notice.onTap = { [weak self] in self?.onTap?() }
    }
    func update(announcements: [AnnouncementItem]) { notice.update(announcements: announcements) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// 区块标题行（SectionHeaderView）
final class HomeSectionCell: UITableViewCell {
    private let header = SectionHeaderView(title: "", more: nil)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(header)
        // 区块标题：顶部 24（与上一区块间距）+ 左右 12 + 底部 0
        header.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.xl)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview()
        }
    }

    func configure(title: String, more: String?, onMore: (() -> Void)?) {
        header.set(title: title, more: more)
        header.onMore = onMore
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// 为你推荐：课程横滑行
final class HomeCourseRowCell: UITableViewCell {
    var onCourseTap: ((CourseItem) -> Void)?

    private var row: HCardRow<CourseItem>!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        row = HCardRow<CourseItem>(items: [], itemSize: CGSize(width: 148, height: 232)) { [weak self] item in
            let card = CourseCardView(item: item)
            card.onTap = { self?.onCourseTap?(item) }
            return card
        }
        contentView.addSubview(row)
        // 顶部 12（与标题间距）+ 左右 12 + 底部 0（高度由 heightForRowAt 固定）
        row.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview()
        }
    }

    func reload(items: [CourseItem]) { row.reload(items: items) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// 附近热门工作室：列表行
final class HomeStudioCell: UITableViewCell {
    var onTap: (() -> Void)?

    private let rowView = StudioRowView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(rowView)
        // 顶部 12（卡片间距）+ 左右 12 + 底部 0
        rowView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview()
        }
        rowView.onTap = { [weak self] in self?.onTap?() }
    }
    func configure(item: StudioItem) { rowView.configure(item: item) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// 老师动态：帖子行
final class HomePostCell: UITableViewCell {
    var onTap: (() -> Void)?

    private let post = PostCardView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(post)
        // 顶部 12（卡片间距）+ 左右 12 + 底部 0
        post.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview()
        }
        post.onTap = { [weak self] in self?.onTap?() }
    }
    func configure(item: PostItem) { post.configure(item: item) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 搜索框

final class HomeSearchBar: UIView {
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: .zero)
        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        icon.tintColor = Theme.Color.muted
        addSubview(icon)
        icon.snp.makeConstraints { $0.leading.equalToSuperview().offset(Theme.Spacing.m); $0.centerY.equalToSuperview(); $0.width.height.equalTo(16) }

        let label = UILabel()
        label.text = "搜索课程、工作室、作品"
        label.font = .appBody(14)
        label.textColor = Theme.Color.muted
        addSubview(label)
        label.snp.makeConstraints { $0.leading.equalTo(icon.snp.trailing).offset(Theme.Spacing.s); $0.centerY.equalToSuperview() }

        backgroundColor = Theme.Color.surface
        layer.cornerRadius = Theme.Radius.input
        layer.borderWidth = 1
        layer.borderColor = Theme.Color.line.cgColor
        snp.makeConstraints { $0.height.equalTo(44) }

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    @objc private func didTap() { onTap?() }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 问候 Hero（深绿渐变卡 + 孩子课程进度卡）

final class HomeHeroView: UIView {

    private let greetingLabel = UILabel()
    private let nameLabel = UILabel()
    private let childStack = UIStackView()
    private let addChildView = HomeAddChildView()

    var onChildTap: ((ChildItem) -> Void)?
    var onAddChild: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: .zero)

        // 渐变背景
        let gradient = CAGradientLayer()
        gradient.colors = [Theme.Color.brand.cgColor, Theme.Color.brandDark.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        layer.insertSublayer(gradient, at: 0)
        layer.cornerRadius = Theme.Radius.card
        layer.masksToBounds = true

        greetingLabel.text = Self.greetingText()
        greetingLabel.font = .appBody(14)
        greetingLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        addSubview(greetingLabel)
        greetingLabel.snp.makeConstraints { $0.top.equalToSuperview().inset(Theme.Spacing.l); $0.leading.equalToSuperview().inset(Theme.Spacing.xl) }

        nameLabel.text = TokenManager.shared.nickname.isEmpty ? "家长" : TokenManager.shared.nickname
        nameLabel.font = .appTitle(24)
        nameLabel.textColor = .white
        addSubview(nameLabel)
        nameLabel.snp.makeConstraints { $0.top.equalTo(greetingLabel.snp.bottom).offset(4); $0.leading.equalTo(greetingLabel) }

        // 孩子课程进度卡（双卡并排）
        childStack.axis = .horizontal
        childStack.spacing = Theme.Spacing.m
        childStack.distribution = .fillEqually
        addSubview(childStack)
        childStack.snp.makeConstraints { $0.top.equalTo(nameLabel.snp.bottom).offset(Theme.Spacing.l); $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.xl); $0.bottom.equalToSuperview().inset(Theme.Spacing.l) }

        addChildView.onTap = { [weak self] in self?.onAddChild?() }
        addSubview(addChildView)
        addChildView.snp.makeConstraints { $0.top.equalTo(nameLabel.snp.bottom).offset(Theme.Spacing.l); $0.leading.equalToSuperview().inset(Theme.Spacing.xl); $0.height.equalTo(104) }
        addChildView.isHidden = true

        snp.makeConstraints { $0.height.equalTo(240) }
    }

    func reload(children: [ChildItem]) {
        childStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if children.isEmpty {
            // 无孩子空态
            childStack.isHidden = true
            addChildView.isHidden = false
            snp.updateConstraints { $0.height.equalTo(220) }
            return
        }

        childStack.isHidden = false
        addChildView.isHidden = true
        // 双卡并排（设计图 2 个；超出显示前 2 个）
        for item in children.prefix(2) {
            let card = ChildProgressCard(item: item)
            card.onTap = { [weak self] in self?.onChildTap?(item) }
            childStack.addArrangedSubview(card)
        }
        // 单孩时另一张卡位用空白占位（保持宽度一致）
        if children.count == 1 {
            let spacer = UIView()
            spacer.backgroundColor = .clear
            childStack.addArrangedSubview(spacer)
        }
        snp.updateConstraints { $0.height.equalTo(240) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.sublayers?.first?.frame = bounds
    }

    private static func greetingText() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "早上好"
        case 12..<18: return "下午好"
        default: return "晚上好"
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// Hero 内「添加孩子」空态卡
final class HomeAddChildView: UIView {
    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: .zero)
        let icon = UIImageView(image: UIImage(systemName: "plus.circle.fill"))
        icon.tintColor = Theme.Color.brand
        addSubview(icon)
        icon.snp.makeConstraints { $0.top.equalToSuperview().inset(Theme.Spacing.l); $0.centerX.equalToSuperview(); $0.width.height.equalTo(28) }

        let label = UILabel()
        label.text = "添加孩子"
        label.font = .appSection(13)
        label.textColor = Theme.Color.ink
        label.textAlignment = .center
        addSubview(label)
        label.snp.makeConstraints { $0.top.equalTo(icon.snp.bottom).offset(Theme.Spacing.s); $0.leading.trailing.equalToSuperview(); $0.bottom.equalToSuperview().offset(-Theme.Spacing.l) }

        backgroundColor = Theme.Color.surface
        layer.cornerRadius = Theme.Radius.card
        layer.borderWidth = 1
        layer.borderColor = Theme.Color.line.cgColor
        snp.makeConstraints { $0.width.equalTo(96) }

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    @objc private func didTap() { onTap?() }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 公告条

final class HomeNoticeCard: UIView {
    var onTap: (() -> Void)?

    private let label = UILabel()
    private let icon = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: .zero)
        icon.image = UIImage(systemName: "megaphone.fill")
        icon.tintColor = Theme.Color.clay
        addSubview(icon)
        icon.snp.makeConstraints { $0.leading.equalToSuperview().inset(Theme.Spacing.l); $0.centerY.equalToSuperview(); $0.width.height.equalTo(16) }

        label.font = .appBody(13)
        label.textColor = Theme.Color.ink
        label.numberOfLines = 1
        addSubview(label)
        label.snp.makeConstraints { $0.leading.equalTo(icon.snp.trailing).offset(Theme.Spacing.m); $0.trailing.equalToSuperview().inset(Theme.Spacing.xxl); $0.centerY.equalToSuperview() }

        let arrow = UIImageView(image: UIImage(systemName: "chevron.right"))
        arrow.tintColor = Theme.Color.muted
        addSubview(arrow)
        arrow.snp.makeConstraints { $0.trailing.equalToSuperview().inset(Theme.Spacing.l); $0.centerY.equalToSuperview(); $0.width.equalTo(8) }

        backgroundColor = Theme.Color.surfaceAlt
        layer.cornerRadius = Theme.Radius.input
        snp.makeConstraints { $0.height.equalTo(44) }

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    func update(announcements: [AnnouncementItem]) {
        label.text = announcements.first?.title ?? ""
    }

    @objc private func didTap() { onTap?() }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
