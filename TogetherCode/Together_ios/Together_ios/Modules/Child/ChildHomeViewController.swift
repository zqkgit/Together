import UIKit
import SnapKit
import Kingfisher
import ESPullToRefresh

/// 孩子主页（PR 图2/3/4）：深绿头部 + 统计 + 作品/课程/动态三 tab
final class ChildHomeViewController: BaseViewController {

    let child: ChildItem

    // 头部
    private let headerView = ChildHeaderView()

    // 分段
    private let segmentControl = UISegmentedControl(items: ["作品", "课程", "动态"])

    // 作品网格
    private var worksCollectionView: UICollectionView!
    private var works: [ChildWorkItem] = []
    private var workPage = 1
    private var hasMoreWorks = true
    private var isLoadingWorks = false

    // 课程列表
    private var coursesTableView: UITableView!
    private var courses: [ChildCourseAggregate] = []

    // 动态列表
    private var dynamicsTableView: UITableView!
    private var dynamics: [ChildGrowthEvent] = []
    private var growthPage = 1
    private var hasMoreGrowth = true
    private var isLoadingGrowth = false

    private let worksEmpty: EmptyStateView = {
        let view = EmptyStateView()
        view.show(style: .empty("还没有作品\n老师的课堂作品会自动归入这里"))
        return view
    }()
    private let dynamicsEmpty: EmptyStateView = {
        let view = EmptyStateView()
        view.show(style: .empty("还没有动态\n上课消课记录会展示在这里"))
        return view
    }()

    init(child: ChildItem) {
        self.child = child
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
            }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(titleColor: .white, backBackground: UIColor.black.withAlphaComponent(0.28), backTint: .white)
        if !courses.isEmpty { loadData() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    private func setupUI() {
        view.backgroundColor = Theme.Color.bg

        // 头部
        headerView.configure(with: child)
        view.addSubview(headerView)
        headerView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
        }
        headerView.setContentHuggingPriority(.defaultHigh, for: .vertical)

        // 分段
        segmentControl.selectedSegmentTintColor = Theme.Color.brand
        segmentControl.setTitleTextAttributes([.foregroundColor: UIColor.white], for: .selected)
        segmentControl.setTitleTextAttributes([.foregroundColor: Theme.Color.ink], for: .normal)
        segmentControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        segmentControl.selectedSegmentIndex = 0
        view.addSubview(segmentControl)
        segmentControl.snp.makeConstraints {
            $0.top.equalTo(headerView.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(36)
        }

        // 作品网格
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = Theme.Spacing.m
        layout.minimumLineSpacing = Theme.Spacing.m
        layout.sectionInset = UIEdgeInsets(top: Theme.Spacing.l, left: Theme.Spacing.l, bottom: Theme.Spacing.l, right: Theme.Spacing.l)
        worksCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        worksCollectionView.backgroundColor = .clear
        worksCollectionView.dataSource = self
        worksCollectionView.delegate = self
        worksCollectionView.register(ChildWorkCell.self, forCellWithReuseIdentifier: "ChildWorkCell")
        worksCollectionView.alwaysBounceVertical = true
        worksCollectionView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.refreshAll()
        }
        worksCollectionView.es.addInfiniteScrolling { [weak self] in
            self?.loadMoreWorks()
        }
        view.addSubview(worksCollectionView)
        worksCollectionView.snp.makeConstraints {
            $0.top.equalTo(segmentControl.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        // 课程列表
        coursesTableView = UITableView(frame: .zero, style: .plain)
        coursesTableView.backgroundColor = .clear
        coursesTableView.separatorStyle = .none
        coursesTableView.dataSource = self
        coursesTableView.delegate = self
        coursesTableView.register(ChildCourseCell.self, forCellReuseIdentifier: "ChildCourseCell")
        coursesTableView.rowHeight = UITableView.automaticDimension
        coursesTableView.estimatedRowHeight = 84
        coursesTableView.isHidden = true
        coursesTableView.contentInset = UIEdgeInsets(top: Theme.Spacing.m, left: 0, bottom: 0, right: 0)
        coursesTableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.refreshAll()
        }
        view.addSubview(coursesTableView)
        coursesTableView.snp.makeConstraints {
            $0.top.equalTo(segmentControl.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        // 动态列表
        dynamicsTableView = UITableView(frame: .zero, style: .plain)
        dynamicsTableView.backgroundColor = .clear
        dynamicsTableView.separatorStyle = .none
        dynamicsTableView.dataSource = self
        dynamicsTableView.delegate = self
        dynamicsTableView.register(ChildDynamicCell.self, forCellReuseIdentifier: "ChildDynamicCell")
        dynamicsTableView.rowHeight = UITableView.automaticDimension
        dynamicsTableView.estimatedRowHeight = 120
        dynamicsTableView.isHidden = true
        dynamicsTableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.refreshAll()
        }
        dynamicsTableView.es.addInfiniteScrolling { [weak self] in
            self?.loadMoreGrowth()
        }
        view.addSubview(dynamicsTableView)
        dynamicsTableView.snp.makeConstraints {
            $0.top.equalTo(segmentControl.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    private func loadData() {
        // 课程：来自孩子课包（同课程聚合）
        reloadCourses()

        // 作品
        ChildService.fetchChildWorks(childId: child.child_id) { [weak self] result in
            guard let self else { return }
            self.worksCollectionView.es.stopPullToRefresh()
            self.worksCollectionView.es.stopLoadingMore()
            switch result {
            case .success(let list):
                self.works = list
                self.worksCollectionView.reloadData()
                self.worksCollectionView.backgroundView = list.isEmpty ? self.worksEmpty : nil
                self.headerView.updateWorksCount(list.count)
            case .failure:
                self.worksCollectionView.backgroundView = self.worksEmpty
            }
        }

        // 动态
        ChildService.fetchChildGrowth(childId: child.child_id) { [weak self] result in
            guard let self else { return }
            self.dynamicsTableView.es.stopPullToRefresh()
            self.dynamicsTableView.es.stopLoadingMore()
            switch result {
            case .success(let list):
                self.dynamics = list
                self.hasMoreGrowth = list.count >= 20
                self.dynamicsTableView.reloadData()
                self.dynamicsTableView.backgroundView = list.isEmpty ? self.dynamicsEmpty : nil
            case .failure:
                self.dynamicsTableView.backgroundView = self.dynamicsEmpty
            }
        }
    }

    private func refreshAll() {
        workPage = 1
        growthPage = 1
        loadData()
    }

    private func loadMoreWorks() {
        guard hasMoreWorks, !isLoadingWorks else {
            worksCollectionView.es.stopLoadingMore()
            return
        }
        isLoadingWorks = true
        workPage += 1
        // TODO: 作品分页接口待后端支持，目前一次加载全部
        isLoadingWorks = false
        worksCollectionView.es.stopLoadingMore()
        hasMoreWorks = false
    }

    private func loadMoreGrowth() {
        guard hasMoreGrowth, !isLoadingGrowth else {
            dynamicsTableView.es.stopLoadingMore()
            return
        }
        isLoadingGrowth = true
        growthPage += 1
        // TODO: 成长动态分页接口待后端支持，目前一次加载全部
        isLoadingGrowth = false
        dynamicsTableView.es.stopLoadingMore()
        hasMoreGrowth = false
    }

    private func reloadCourses() {
        var aggregateMap: [String: ChildCourseAggregate] = [:]
        for balance in child.balances ?? [] {
            let key = balance.course_id ?? balance.course_title ?? UUID().uuidString
            var item = aggregateMap[key] ?? ChildCourseAggregate(
                course_id: balance.course_id ?? "",
                course_title: balance.course_title ?? "未命名课程",
                studio_name: balance.studio_name,
                total: 0, consumed: 0, remaining: 0, isRefunded: true
            )
            item.total += balance.total_lessons
            item.consumed += balance.consumed_lessons
            item.remaining += balance.remaining_lessons
            if balance.status != 4 { item.isRefunded = false }
            aggregateMap[key] = item
        }
        courses = aggregateMap.values
            .filter { $0.total > 0 }
            .sorted { $0.course_title < $1.course_title }
        coursesTableView.reloadData()
    }

    @objc private func segmentChanged() {
        let index = segmentControl.selectedSegmentIndex
        worksCollectionView.isHidden = index != 0
        coursesTableView.isHidden = index != 1
        dynamicsTableView.isHidden = index != 2
    }
}

// MARK: - Collection（作品）

extension ChildHomeViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        works.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ChildWorkCell", for: indexPath) as! ChildWorkCell
        cell.configure(with: works[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (view.bounds.width - Theme.Spacing.l * 3) / 2
        return CGSize(width: width, height: width + 40)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let item = works[indexPath.item]
        guard let postId = item.post_id, !postId.isEmpty else {
            showToast("暂无详情")
            return
        }
        let vc = PostDetailViewController(postId: postId)
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - Table（课程/动态）

extension ChildHomeViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == coursesTableView { return courses.count }
        return dynamics.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == coursesTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ChildCourseCell", for: indexPath) as! ChildCourseCell
            let course = courses[indexPath.row]
            cell.configure(with: course)
            cell.onTap = { [weak self] in
                guard let self else { return }
                let vc = CourseStudyViewController(
                    childId: self.child.child_id,
                    courseId: course.course_id,
                    courseTitle: course.course_title
                )
                self.navigationController?.pushViewController(vc, animated: true)
            }
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChildDynamicCell", for: indexPath) as! ChildDynamicCell
        cell.configure(with: dynamics[indexPath.row])
        return cell
    }
}

// MARK: - 头部（孩子信息 + 统计）

final class ChildHeaderView: UIView {

    private let avatarView = UIView()
    private let avatarLabel = UILabel()
    private let nicknameLabel = UILabel()
    private let infoLabel = UILabel()
    private let courseValue = UILabel()
    private let workValue = UILabel()
    private let attendanceValue = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        let gradient = CAGradientLayer()
        gradient.colors = [Theme.Color.brand.cgColor, Theme.Color.brandDark.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 0.8, y: 1)
        layer.insertSublayer(gradient, at: 0)
        backgroundColor = Theme.Color.brandDark

        let orb = UIView()
        orb.backgroundColor = Theme.Color.wood.withAlphaComponent(0.15)
        orb.layer.cornerRadius = 50
        addSubview(orb)
        orb.snp.makeConstraints {
            $0.top.equalToSuperview().offset(8)
            $0.trailing.equalToSuperview().offset(30)
            $0.width.height.equalTo(100)
        }

        // 头像
        avatarView.backgroundColor = .white
        avatarView.layer.cornerRadius = 28
        avatarView.layer.masksToBounds = true
        addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide).offset(Theme.Spacing.s)
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
            $0.width.height.equalTo(56)
        }

        avatarLabel.font = .appTitle(24)
        avatarLabel.textColor = Theme.Color.brand
        avatarLabel.textAlignment = .center
        avatarView.addSubview(avatarLabel)
        avatarLabel.snp.makeConstraints { $0.edges.equalToSuperview() }

        nicknameLabel.font = .appSection(18)
        nicknameLabel.textColor = .white
        addSubview(nicknameLabel)
        nicknameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarView.snp.trailing).offset(Theme.Spacing.m)
            $0.top.equalTo(avatarView).offset(4)
        }

        infoLabel.font = .appLabel(12)
        infoLabel.textColor = .white.withAlphaComponent(0.8)
        addSubview(infoLabel)
        infoLabel.snp.makeConstraints {
            $0.leading.equalTo(nicknameLabel)
            $0.top.equalTo(nicknameLabel.snp.bottom).offset(3)
        }

        // 统计卡
        let statCard = UIView()
        statCard.backgroundColor = UIColor.white.withAlphaComponent(0.13)
        statCard.layer.cornerRadius = Theme.Radius.card
        addSubview(statCard)
        statCard.snp.makeConstraints {
            $0.top.equalTo(avatarView.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(68)
        }

        let items: [(UILabel, UILabel, String)] = [
            (courseValue, statLabel("在学课程"), "0"),
            (workValue, statLabel("作品数"), "0"),
            (attendanceValue, statLabel("出勤率"), "0%")
        ]
        var previous: UIView?
        for (index, item) in items.enumerated() {
            let column = UIStackView(arrangedSubviews: [item.0, item.1])
            column.axis = .vertical
            column.spacing = 4
            column.alignment = .center
            column.distribution = .fill
            statCard.addSubview(column)
            column.snp.makeConstraints { make in
                // 整体垂直居中（不撑满卡片，避免数字/标签被拉伸错位）
                make.centerY.equalToSuperview()
                if let previous {
                    make.leading.equalTo(previous.snp.trailing)
                    make.width.equalTo(previous)
                } else {
                    make.leading.equalToSuperview()
                }
                if index == items.count - 1 { make.trailing.equalToSuperview() }
            }
            if let previous {
                let divider = UIView()
                divider.backgroundColor = UIColor.white.withAlphaComponent(0.16)
                statCard.addSubview(divider)
                divider.snp.makeConstraints {
                    $0.leading.equalTo(previous.snp.trailing)
                    $0.centerY.equalToSuperview()
                    $0.width.equalTo(0.5)
                    $0.height.equalTo(28)
                }
            }
            previous = column
        }

        courseValue.font = .appHero(20)
        workValue.font = .appHero(20)
        attendanceValue.font = .appHero(20)
        for value in [courseValue, workValue, attendanceValue] {
            value.textColor = .white
            value.textAlignment = .center
        }
    }

    private func statLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .appLabel(11)
        label.textColor = .white.withAlphaComponent(0.75)
        label.textAlignment = .center
        return label
    }

    func configure(with child: ChildItem) {
        let name = child.nickname
        nicknameLabel.text = name

        if let avatar = child.avatar, avatar.hasPrefix("http") {
            avatarLabel.text = ""
            avatarLabel.isHidden = true
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = avatarView.layer.cornerRadius
            avatarView.addSubview(imageView)
            imageView.snp.makeConstraints { $0.edges.equalToSuperview() }
            if let url = URL(string: avatar) {
                imageView.kf.setImage(with: url)
            }
        } else if let avatar = child.avatar, !avatar.isEmpty {
            avatarLabel.text = avatar
        } else {
            avatarLabel.text = String(name.prefix(1))
        }

        let gender = child.gender == 2 ? "女" : (child.gender == 1 ? "男" : "")
        let age = child.ageText ?? ""
        let courseName = child.balances?.compactMap { $0.course_title }.first ?? ""
        infoLabel.text = [gender, age, courseName].filter { !$0.isEmpty }.joined(separator: "·")

        // 在学课程（课包去重）
        let courseCount = Set(child.balances?.compactMap { $0.course_id } ?? []).count
        courseValue.text = "\(courseCount)"

        // 出勤率 = Σconsumed / Σtotal
        let balances = child.balances ?? []
        let total = balances.reduce(0) { $0 + $1.total_lessons }
        let consumed = balances.reduce(0) { $0 + $1.consumed_lessons }
        if total > 0 {
            attendanceValue.text = "\(Int(Double(consumed) / Double(total) * 100))%"
        } else {
            attendanceValue.text = "—"
        }
    }

    func updateWorksCount(_ count: Int) {
        workValue.text = "\(count)"
    }
}



// MARK: - 作品网格 Cell

final class ChildWorkCell: UICollectionViewCell {

    private let imageView = UIImageView()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.Color.surface
        layer.cornerRadius = Theme.Radius.card
        layer.masksToBounds = true

        imageView.contentMode = .scaleAspectFill
        imageView.backgroundColor = Theme.Color.surfaceAlt
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(snp.width)
        }

        titleLabel.font = .appLabel(12)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 1
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(imageView.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.s)
            $0.bottom.lessThanOrEqualToSuperview().inset(Theme.Spacing.s)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with work: ChildWorkItem) {
        titleLabel.text = work.content?.count ?? 0 > 0 ? work.content : (work.course_title ?? "作品")
        if let url = work.images?.first, let imageURL = URL(string: url) {
            imageView.kf.setImage(with: imageURL, placeholder: nil)
        } else {
            imageView.image = nil
            imageView.backgroundColor = Theme.Color.surfaceAlt
        }
    }
}

// MARK: - 课程 Cell

final class ChildCourseCell: UITableViewCell {

    var onTap: (() -> Void)?

    private let card = UIView()
    private let titleLabel = UILabel()
    private let studioLabel = UILabel()
    private let refundTag = UILabel()
    private let progressTrack = UIView()
    private let progressFill = UIView()
    private let progressLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        contentView.addSubview(card)
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapCard))
        card.addGestureRecognizer(tap)
        card.snp.makeConstraints {
            $0.top.equalToSuperview().offset(6)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().inset(6)
        }
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card

        // 退款标签（右对齐）
        refundTag.font = .appLabel(11)
        refundTag.textColor = .white
        refundTag.textAlignment = .center
        refundTag.backgroundColor = Theme.Color.sub
        refundTag.layer.cornerRadius = 4
        refundTag.layer.masksToBounds = true
        refundTag.isHidden = true
        card.addSubview(refundTag)
        refundTag.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m + 2)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.cardInner)
            $0.width.equalTo(38)
            $0.height.equalTo(18)
        }

        // 课程标题
        titleLabel.font = .appSection(15)
        titleLabel.textColor = Theme.Color.ink
        card.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.equalToSuperview().inset(Theme.Spacing.cardInner)
            $0.trailing.equalTo(refundTag.snp.leading).offset(-8)
        }

        // 工作室名
        studioLabel.font = .appLabel(12)
        studioLabel.textColor = Theme.Color.muted
        card.addSubview(studioLabel)
        studioLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(4)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.cardInner)
        }

        // 进度条
        progressTrack.backgroundColor = UIColor(hex: 0xE8E8E8)
        progressTrack.layer.cornerRadius = 3
        card.addSubview(progressTrack)

        progressFill.backgroundColor = Theme.Color.brand
        progressFill.layer.cornerRadius = 3
        progressTrack.addSubview(progressFill)
        progressFill.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
        }

        // 进度文字（先设约束，供 progressTrack 引用）
        progressLabel.font = .appLabel(11)
        progressLabel.textColor = Theme.Color.muted
        card.addSubview(progressLabel)
        progressLabel.snp.makeConstraints {
            $0.centerY.equalTo(progressTrack)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.cardInner)
        }

        // 进度条约束（trailing 连到 progressLabel 左侧，自动填充）
        progressTrack.snp.makeConstraints {
            $0.top.equalTo(studioLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.equalToSuperview().inset(Theme.Spacing.cardInner)
            $0.trailing.equalTo(progressLabel.snp.leading).offset(-8)
            $0.height.equalTo(6)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.m)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func didTapCard() {
        onTap?()
    }

    func configure(with course: ChildCourseAggregate) {
        titleLabel.text = course.course_title
        studioLabel.text = course.studio_name ?? "艺术工坊"

        // 进度
        let total = max(course.total, 1)
        let consumed = min(course.consumed, total)
        let ratio = CGFloat(consumed) / CGFloat(total)
        progressFill.snp.remakeConstraints {
            $0.leading.top.bottom.equalToSuperview()
            $0.width.equalTo(self.progressTrack).multipliedBy(ratio)
        }
        progressLabel.text = "已上\(consumed)/\(course.total)节"

        // 退款状态
        refundTag.text = "已退款"
        refundTag.isHidden = !course.isRefunded
        card.isUserInteractionEnabled = !course.isRefunded
        titleLabel.textColor = course.isRefunded ? Theme.Color.sub : Theme.Color.ink
        progressFill.backgroundColor = course.isRefunded ? Theme.Color.sub : Theme.Color.brand
    }
}

// MARK: - 动态 Cell

final class ChildDynamicCell: UITableViewCell {

    private let card = UIView()
    private let avatarView = UIView()
    private let avatarLabel = UILabel()
    private let sourceLabel = UILabel()
    private let timeLabel = UILabel()
    private let eventIconLabel = UILabel()
    private let bodyLabel = UILabel()
    private let courseTag = UIView()
    private let courseTagLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.top.equalToSuperview().offset(6)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().inset(6)
        }
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card

        avatarView.backgroundColor = Theme.Color.woodSoft
        avatarView.layer.cornerRadius = 18
        avatarView.layer.masksToBounds = true
        card.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.equalToSuperview().offset(Theme.Spacing.cardInner)
            $0.width.height.equalTo(36)
        }

        avatarLabel.font = .appBody(14)
        avatarLabel.textColor = Theme.Color.wood
        avatarLabel.textAlignment = .center
        avatarView.addSubview(avatarLabel)
        avatarLabel.snp.makeConstraints { $0.edges.equalToSuperview() }

        sourceLabel.font = .appBody(14)
        sourceLabel.textColor = Theme.Color.ink
        card.addSubview(sourceLabel)
        sourceLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarView.snp.trailing).offset(Theme.Spacing.s)
            $0.top.equalTo(avatarView).offset(1)
        }

        // 事件类型图标（emoji）
        eventIconLabel.font = .appBody(13)
        card.addSubview(eventIconLabel)
        eventIconLabel.snp.makeConstraints {
            $0.leading.equalTo(sourceLabel.snp.trailing).offset(6)
            $0.centerY.equalTo(sourceLabel)
        }

        timeLabel.font = .appLabel(11)
        timeLabel.textColor = Theme.Color.muted
        card.addSubview(timeLabel)
        timeLabel.snp.makeConstraints {
            $0.leading.equalTo(eventIconLabel.snp.trailing).offset(Theme.Spacing.s)
            $0.centerY.equalTo(sourceLabel)
        }

        bodyLabel.font = .appBody(14)
        bodyLabel.textColor = Theme.Color.ink
        bodyLabel.numberOfLines = 5
        card.addSubview(bodyLabel)
        bodyLabel.snp.makeConstraints {
            $0.top.equalTo(avatarView.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.cardInner)
        }

        // 关联课程标签
        courseTag.backgroundColor = Theme.Color.brandSoft
        courseTag.layer.cornerRadius = 11
        card.addSubview(courseTag)
        courseTag.snp.makeConstraints {
            $0.top.equalTo(bodyLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.equalTo(bodyLabel)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(22)
        }

        courseTagLabel.font = .appLabel(10)
        courseTagLabel.textColor = Theme.Color.brand
        courseTag.addSubview(courseTagLabel)
        courseTagLabel.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with event: ChildGrowthEvent) {
        let source = event.sourceName
        sourceLabel.text = source
        avatarLabel.text = String(source.prefix(1))
        bodyLabel.text = event.bodyText

        // 事件类型图标
        eventIconLabel.text = eventTypeIcon(event.event_type)

        // 时间：ISO(Z 结尾转本地) / 本地格式直接用
        if let time = event.occurred_at, time.count >= 16 {
            if time.hasSuffix("Z") {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: time) {
                    let output = DateFormatter()
                    output.dateFormat = "yyyy-MM-dd HH:mm"
                    output.locale = Locale(identifier: "zh_CN")
                    timeLabel.text = output.string(from: date)
                } else {
                    timeLabel.text = String(time.prefix(16))
                }
            } else {
                let datePart = String(time.prefix(10))
                let timePart = time.dropFirst(11).prefix(5)
                timeLabel.text = "\(datePart) \(timePart)"
            }
        } else {
            timeLabel.text = event.occurred_at ?? ""
        }

        if let course = event.course_title, !course.isEmpty {
            courseTagLabel.text = "关联课程·\(course)"
            courseTag.isHidden = false
        } else {
            courseTag.isHidden = true
        }
    }

    /// 根据事件类型返回对应 emoji 图标
    private func eventTypeIcon(_ type: String?) -> String {
        switch type {
        case "consume": return "📖"
        case "refund": return "💰"
        case "post": return "🎨"
        case "enroll": return "✨"
        default: return ""
        }
    }
}


/// 孩子课程聚合（同课程课包合并）
struct ChildCourseAggregate {
    let course_id: String
    let course_title: String
    let studio_name: String?
    var total: Int
    var consumed: Int
    var remaining: Int
    var isRefunded: Bool
}
