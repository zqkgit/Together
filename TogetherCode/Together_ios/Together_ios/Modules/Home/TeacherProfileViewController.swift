import UIKit
import SnapKit
import Kingfisher
import ESPullToRefresh

/// 老师主页（家长视角，公开接口）
/// 参考孩子主页 UI 风格：深绿渐变头部 + 统计卡 + 作品/工作室/评价三 tab
final class TeacherProfileViewController: BaseViewController {

    // MARK: - Data

    private let teacherId: String
    private var data: TeacherProfileData?
    private var profile: TeacherProfileInfo? { data?.profile }
    private var studios: [TeacherProfileStudio] { data?.studios ?? [] }
    private var worksList: [TeacherProfileWork] = []
    private var workTotal: Int { data?.works?.total ?? 0 }
    private var workPage = 1
    private var hasMoreWorks = true

    private var studentWorksList: [TeacherProfileWork] = []
    private var studentWorkTotal: Int { data?.student_works?.total ?? 0 }
    private var studentWorkPage = 1
    private var hasMoreStudentWorks = true
    private var isLoadingStudentWorks = false

    private var reviews: [TeacherProfileReview] = []
    private var reviewTotal = 0
    private var reviewAverage: Double = 0
    private var reviewPage = 1
    private var hasMoreReviews = true

    // MARK: - UI

    private let headerView = TeacherHeaderView()
    private let segmentControl = UISegmentedControl(items: ["作品", "学员作品", "工作室", "评价"])

    // 作品列表
    private var worksTableView: UITableView!
    private let worksEmpty: EmptyStateView = {
        let view = EmptyStateView()
        view.show(style: .empty("还没有作品\n老师发布作品后会展示在这里"))
        return view
    }()

    // 工作室列表
    private var studiosTableView: UITableView!
    private let studiosEmpty: EmptyStateView = {
        let view = EmptyStateView()
        view.show(style: .empty("暂无工作室"))
        return view
    }()

    // 学员作品列表
    private var studentWorksTableView: UITableView!
    private let studentWorksEmpty: EmptyStateView = {
        let view = EmptyStateView()
        view.show(style: .empty("暂无学员作品\n老师发布学员作品后会展示在这里"))
        return view
    }()

    // 评价列表
    private var reviewsTableView: UITableView!
    private let reviewsEmpty: EmptyStateView = {
        let view = EmptyStateView()
        view.show(style: .empty("暂无评价\n家长评价后会展示在这里"))
        return view
    }()

    private var hasLoaded = false
    private var isLoadingWorks = false
    private var isLoadingReviews = false

    // MARK: - Init

    init(teacherId: String) {
        self.teacherId = teacherId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(titleColor: .white, backBackground: UIColor.black.withAlphaComponent(0.28), backTint: .white)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    // MARK: - UI Setup

    private func setupUI() {
        view.backgroundColor = Theme.Color.bg

        // 头部
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

        // 作品列表
        worksTableView = UITableView(frame: .zero, style: .plain)
        worksTableView.backgroundColor = .clear
        worksTableView.separatorStyle = .none
        worksTableView.dataSource = self
        worksTableView.delegate = self
        worksTableView.register(TeacherWorkListCell.self, forCellReuseIdentifier: "TeacherWorkListCell")
        worksTableView.rowHeight = UITableView.automaticDimension
        worksTableView.estimatedRowHeight = 80
        worksTableView.alwaysBounceVertical = true
        worksTableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.refreshAll()
        }
        worksTableView.es.addInfiniteScrolling { [weak self] in
            self?.loadMoreWorks()
        }
        view.addSubview(worksTableView)
        worksTableView.snp.makeConstraints {
            $0.top.equalTo(segmentControl.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        // 工作室列表
        studiosTableView = UITableView(frame: .zero, style: .plain)
        studiosTableView.backgroundColor = .clear
        studiosTableView.separatorStyle = .none
        studiosTableView.dataSource = self
        studiosTableView.delegate = self
        studiosTableView.register(TeacherStudioListCell.self, forCellReuseIdentifier: "TeacherStudioListCell")
        studiosTableView.rowHeight = UITableView.automaticDimension
        studiosTableView.estimatedRowHeight = 88
        studiosTableView.isHidden = true
        studiosTableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.refreshAll()
        }
        view.addSubview(studiosTableView)
        studiosTableView.snp.makeConstraints {
            $0.top.equalTo(segmentControl.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        // 学员作品列表
        studentWorksTableView = UITableView(frame: .zero, style: .plain)
        studentWorksTableView.backgroundColor = .clear
        studentWorksTableView.separatorStyle = .none
        studentWorksTableView.dataSource = self
        studentWorksTableView.delegate = self
        studentWorksTableView.register(TeacherWorkListCell.self, forCellReuseIdentifier: "StudentWorkListCell")
        studentWorksTableView.rowHeight = UITableView.automaticDimension
        studentWorksTableView.estimatedRowHeight = 80
        studentWorksTableView.alwaysBounceVertical = true
        studentWorksTableView.isHidden = true
        studentWorksTableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.refreshAll()
        }
        studentWorksTableView.es.addInfiniteScrolling { [weak self] in
            self?.loadMoreStudentWorks()
        }
        view.addSubview(studentWorksTableView)
        studentWorksTableView.snp.makeConstraints {
            $0.top.equalTo(segmentControl.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        // 评价列表
        reviewsTableView = UITableView(frame: .zero, style: .plain)
        reviewsTableView.backgroundColor = .clear
        reviewsTableView.separatorStyle = .none
        reviewsTableView.dataSource = self
        reviewsTableView.delegate = self
        reviewsTableView.register(TeacherReviewCell.self, forCellReuseIdentifier: "TeacherReviewCell")
        reviewsTableView.rowHeight = UITableView.automaticDimension
        reviewsTableView.estimatedRowHeight = 120
        reviewsTableView.isHidden = true
        reviewsTableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.refreshAll()
        }
        reviewsTableView.es.addInfiniteScrolling { [weak self] in
            self?.loadMoreReviews()
        }
        view.addSubview(reviewsTableView)
        reviewsTableView.snp.makeConstraints {
            $0.top.equalTo(segmentControl.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }
    }

    // MARK: - Data

    private func loadData() {
        loadHomepage(reset: true)
        loadStudentWorks(reset: true)
        loadReviews(reset: true)
    }

    // MARK: - 咨询按钮

    /// 非本人时显示导航栏右侧「咨询」按钮
    private func setupChatButton() {
        let myUserId = TokenManager.shared.userId
        guard let userId = data?.user?.user_id, !userId.isEmpty, userId != myUserId else { return }
        let btn = UIButton(type: .system)
        btn.setTitle("咨询", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .appLabel(15)
        btn.backgroundColor = Theme.Color.brand.withAlphaComponent(0.6)
        btn.layer.cornerRadius = 14
        btn.clipsToBounds = true
        btn.addTarget(self, action: #selector(didTapChat), for: .touchUpInside)
        btn.snp.makeConstraints { $0.width.equalTo(56); $0.height.equalTo(28) }
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: btn)
    }

    @objc private func didTapChat() {
        guard let userId = data?.user?.user_id, !userId.isEmpty else {
            showToast("无法获取老师信息")
            return
        }
        guard TokenManager.shared.isLoggedIn else {
            showToast("请先登录")
            return
        }
        showLoading()
        MessageService.createConversation(peerUserId: userId) { [weak self] conversation, error in
            guard let self else { return }
            self.hideLoading()
            if let error {
                self.showToast(error)
                return
            }
            guard let conversation else {
                self.showToast("创建会话失败")
                return
            }
            let vc = ChatViewController(conversation: conversation)
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }

    /// 下拉刷新：重置所有分页
    private func refreshAll() {
        workPage = 1
        studentWorkPage = 1
        reviewPage = 1
        loadHomepage(reset: true)
        loadStudentWorks(reset: true)
        loadReviews(reset: true)
    }

    /// 加载主页数据（作品+工作室+个人信息）
    private func loadHomepage(reset: Bool) {
        if reset { workPage = 1 }
        guard !isLoadingWorks else { return }
        isLoadingWorks = true
        TeacherProfileService.shared.fetchHomepage(teacherId: teacherId, page: workPage) { [weak self] result in
            guard let self else { return }
            self.isLoadingWorks = false
            self.worksTableView.es.stopPullToRefresh()
            self.worksTableView.es.stopLoadingMore()
            self.studiosTableView.es.stopPullToRefresh()
            switch result {
            case .success(let data):
                self.data = data
                self.hasLoaded = true
                if reset || self.workPage <= 1 {
                    self.worksList = data.works?.list ?? []
                } else {
                    self.worksList.append(contentsOf: data.works?.list ?? [])
                }
                self.hasMoreWorks = self.worksList.count < (data.works?.total ?? 0)
                // 首页自带学员作品首页数据
                if reset || self.studentWorkPage <= 1 {
                    self.studentWorksList = data.student_works?.list ?? []
                }
                self.hasMoreStudentWorks = self.studentWorksList.count < (data.student_works?.total ?? 0)
                self.headerView.configure(user: data.user, profile: data.profile)
                self.headerView.updateStats(
                    studentCount: data.profile?.student_count ?? 0,
                    workCount: data.works?.total ?? 0,
                    rating: data.profile?.rating ?? 0
                )
                self.setupChatButton()
                self.worksTableView.reloadData()
                self.worksTableView.backgroundView = self.worksList.isEmpty ? self.worksEmpty : nil
                self.studentWorksTableView.reloadData()
                self.studentWorksTableView.backgroundView = self.studentWorksList.isEmpty ? self.studentWorksEmpty : nil
                self.studiosTableView.reloadData()
                self.studiosTableView.backgroundView = self.studios.isEmpty ? self.studiosEmpty : nil
            case .failure:
                if !self.hasLoaded {
                    self.worksTableView.backgroundView = self.worksEmpty
                }
            }
        }
    }

    /// 加载评价数据
    private func loadReviews(reset: Bool) {
        if reset { reviewPage = 1 }
        guard !isLoadingReviews else { return }
        isLoadingReviews = true
        TeacherProfileService.shared.fetchReviews(teacherId: teacherId, page: reviewPage) { [weak self] result in
            guard let self else { return }
            self.isLoadingReviews = false
            self.reviewsTableView.es.stopPullToRefresh()
            self.reviewsTableView.es.stopLoadingMore()
            switch result {
            case .success(let data):
                self.reviewTotal = data.total ?? 0
                self.reviewAverage = data.average ?? 0
                if reset || self.reviewPage <= 1 {
                    self.reviews = data.list ?? []
                } else {
                    self.reviews.append(contentsOf: data.list ?? [])
                }
                self.hasMoreReviews = self.reviews.count < (data.total ?? 0)
                self.reviewsTableView.reloadData()
                self.reviewsTableView.backgroundView = self.reviews.isEmpty ? self.reviewsEmpty : nil
            case .failure:
                self.reviewsTableView.backgroundView = self.reviewsEmpty
            }
        }
    }

    /// 上拉加载更多作品
    private func loadMoreWorks() {
        guard hasMoreWorks, !isLoadingWorks else {
            worksTableView.es.stopLoadingMore()
            return
        }
        workPage += 1
        loadHomepage(reset: false)
    }

    /// 上拉加载更多评价
    private func loadMoreReviews() {
        guard hasMoreReviews, !isLoadingReviews else {
            reviewsTableView.es.stopLoadingMore()
            return
        }
        reviewPage += 1
        loadReviews(reset: false)
    }

    /// 加载学员作品数据
    private func loadStudentWorks(reset: Bool) {
        if reset { studentWorkPage = 1 }
        guard !isLoadingStudentWorks else { return }
        isLoadingStudentWorks = true
        TeacherProfileService.shared.fetchStudentWorks(teacherId: teacherId, page: studentWorkPage) { [weak self] result in
            guard let self else { return }
            self.isLoadingStudentWorks = false
            self.studentWorksTableView.es.stopPullToRefresh()
            self.studentWorksTableView.es.stopLoadingMore()
            switch result {
            case .success(let page):
                if reset || self.studentWorkPage <= 1 {
                    self.studentWorksList = page.list ?? []
                } else {
                    self.studentWorksList.append(contentsOf: page.list ?? [])
                }
                self.hasMoreStudentWorks = self.studentWorksList.count < (page.total ?? 0)
                self.studentWorksTableView.reloadData()
                self.studentWorksTableView.backgroundView = self.studentWorksList.isEmpty ? self.studentWorksEmpty : nil
            case .failure:
                if !self.hasLoaded {
                    self.studentWorksTableView.backgroundView = self.studentWorksEmpty
                }
            }
        }
    }

    /// 上拉加载更多学员作品
    private func loadMoreStudentWorks() {
        guard hasMoreStudentWorks, !isLoadingStudentWorks else {
            studentWorksTableView.es.stopLoadingMore()
            return
        }
        studentWorkPage += 1
        loadStudentWorks(reset: false)
    }

    @objc private func segmentChanged() {
        let index = segmentControl.selectedSegmentIndex
        worksTableView.isHidden = index != 0
        studentWorksTableView.isHidden = index != 1
        studiosTableView.isHidden = index != 2
        reviewsTableView.isHidden = index != 3
    }
}

// MARK: - UITableViewDataSource

extension TeacherProfileViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == worksTableView { return worksList.count }
        if tableView == studentWorksTableView { return studentWorksList.count }
        if tableView == studiosTableView { return studios.count }
        if tableView == reviewsTableView { return reviews.count }
        return 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == worksTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TeacherWorkListCell", for: indexPath) as! TeacherWorkListCell
            cell.configure(work: worksList[indexPath.row])
            cell.onTap = { [weak self] in
                let item = self?.worksList[indexPath.row]
                guard let self, let postId = item?.post_id else { return }
                let vc = PostDetailViewController(postId: postId)
                self.navigationController?.pushViewController(vc, animated: true)
            }
            return cell
        }
        if tableView == studentWorksTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "StudentWorkListCell", for: indexPath) as! TeacherWorkListCell
            cell.configure(work: studentWorksList[indexPath.row])
            cell.onTap = { [weak self] in
                let item = self?.studentWorksList[indexPath.row]
                guard let self, let postId = item?.post_id else { return }
                let vc = PostDetailViewController(postId: postId)
                self.navigationController?.pushViewController(vc, animated: true)
            }
            return cell
        }
        if tableView == studiosTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TeacherStudioListCell", for: indexPath) as! TeacherStudioListCell
            cell.configure(studio: studios[indexPath.row])
            return cell
        }
        if tableView == reviewsTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TeacherReviewCell", for: indexPath) as! TeacherReviewCell
            cell.configure(review: reviews[indexPath.row])
            return cell
        }
        return UITableViewCell()
    }
}

// MARK: - UITableViewDelegate

extension TeacherProfileViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView == studiosTableView {
            let studio = studios[indexPath.row]
            let vc = StudioHomepageViewController(studioId: studio.studio_id)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}

// MARK: - TeacherHeaderView（参考 ChildHeaderView 风格）

final class TeacherHeaderView: UIView {

    private let avatarView = UIView()
    private let avatarImageView = UIImageView()
    private let avatarLabel = UILabel()
    private let nameLabel = UILabel()
    private let subjectsLabel = UILabel()
    private let yearsLabel = UILabel()
    private let studentValue = UILabel()
    private let workValue = UILabel()
    private let ratingValue = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        let gradient = CAGradientLayer()
        gradient.colors = [Theme.Color.brand.cgColor, Theme.Color.brandDark.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 0.8, y: 1)
        layer.insertSublayer(gradient, at: 0)
        backgroundColor = Theme.Color.brandDark

        // 装饰圆
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

        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true
        avatarImageView.isHidden = true
        avatarView.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { $0.edges.equalToSuperview() }

        avatarLabel.font = .appTitle(24)
        avatarLabel.textColor = Theme.Color.brand
        avatarLabel.textAlignment = .center
        avatarView.addSubview(avatarLabel)
        avatarLabel.snp.makeConstraints { $0.edges.equalToSuperview() }

        nameLabel.font = .appSection(18)
        nameLabel.textColor = .white
        addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarView.snp.trailing).offset(Theme.Spacing.m)
            $0.top.equalTo(avatarView).offset(4)
        }

        // 标签和教龄分两行显示
        subjectsLabel.font = .appLabel(12)
        subjectsLabel.textColor = .white.withAlphaComponent(0.85)
        addSubview(subjectsLabel)
        subjectsLabel.snp.makeConstraints {
            $0.leading.equalTo(nameLabel)
            $0.top.equalTo(nameLabel.snp.bottom).offset(3)
        }

        yearsLabel.font = .appLabel(12)
        yearsLabel.textColor = .white.withAlphaComponent(0.7)
        addSubview(yearsLabel)
        yearsLabel.snp.makeConstraints {
            $0.leading.equalTo(nameLabel)
            $0.top.equalTo(subjectsLabel.snp.bottom).offset(2)
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
            (studentValue, statLabel("学员数"), "0"),
            (workValue, statLabel("作品数"), "0"),
            (ratingValue, statLabel("评分"), "—")
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

        studentValue.font = .appHero(20)
        workValue.font = .appHero(20)
        ratingValue.font = .appHero(20)
        for value in [studentValue, workValue, ratingValue] {
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

    func configure(user: TeacherProfileUser?, profile: TeacherProfileInfo?) {
        let name = profile?.displayName ?? "老师"
        nameLabel.text = name
        subjectsLabel.text = profile?.subjectsText ?? ""
        yearsLabel.text = profile?.yearsText ?? ""

        if let avatar = user?.avatar, avatar.hasPrefix("http"), let url = URL(string: avatar) {
            avatarImageView.isHidden = false
            avatarLabel.isHidden = true
            avatarImageView.kf.setImage(with: url)
        } else {
            avatarImageView.isHidden = true
            avatarLabel.isHidden = false
            avatarLabel.text = String(name.prefix(1))
        }
    }

    func updateStats(studentCount: Int, workCount: Int, rating: Double) {
        studentValue.text = "\(studentCount)"
        workValue.text = "\(workCount)"
        ratingValue.text = rating > 0 ? String(format: "%.1f", rating) : "—"
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 更新渐变层 frame
        layer.sublayers?.first?.frame = bounds
    }
}

// MARK: - TeacherWorkListCell（作品列表行）

final class TeacherWorkListCell: UITableViewCell {

    var onTap: (() -> Void)?

    private let card = UIView()
    private let coverView = UIImageView()
    private let contentLabel = UILabel()
    private let dateLabel = UILabel()
    private let statsLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        contentView.addSubview(card)
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        card.addGestureRecognizer(tap)
        card.snp.makeConstraints {
            $0.top.equalToSuperview().offset(6)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().inset(6)
        }
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card

        // 封面图更大
        coverView.contentMode = .scaleAspectFill
        coverView.clipsToBounds = true
        coverView.layer.cornerRadius = 10
        coverView.backgroundColor = Theme.Color.surfaceAlt
        card.addSubview(coverView)
        coverView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.cardInner)
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.m)
            $0.width.height.equalTo(80)
        }

        contentLabel.font = .appBody(14)
        contentLabel.textColor = Theme.Color.ink
        contentLabel.numberOfLines = 2
        card.addSubview(contentLabel)
        contentLabel.snp.makeConstraints {
            $0.top.equalTo(coverView).offset(2)
            $0.leading.equalTo(coverView.snp.trailing).offset(12)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.cardInner)
        }

        dateLabel.font = .appLabel(11)
        dateLabel.textColor = Theme.Color.muted
        card.addSubview(dateLabel)
        dateLabel.snp.makeConstraints {
            $0.top.equalTo(contentLabel.snp.bottom).offset(4)
            $0.leading.equalTo(contentLabel)
        }

        statsLabel.font = .appLabel(11)
        statsLabel.textColor = Theme.Color.sub
        card.addSubview(statsLabel)
        statsLabel.snp.makeConstraints {
            $0.top.equalTo(dateLabel.snp.bottom).offset(2)
            $0.leading.equalTo(contentLabel)
            $0.bottom.equalTo(coverView).offset(-2)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func didTap() { onTap?() }

    func configure(work: TeacherProfileWork) {
        contentLabel.text = work.content ?? "作品"
        dateLabel.text = work.created_at.map { String($0.prefix(10)) } ?? ""
        var statsParts: [String] = []
        if !work.likeText.isEmpty { statsParts.append(work.likeText) }
        if !work.commentText.isEmpty { statsParts.append(work.commentText) }
        statsLabel.text = statsParts.joined(separator: "  ")

        if let img = work.firstImage, let url = URL(string: img) {
            coverView.kf.setImage(with: url)
        } else {
            coverView.image = UIImage(systemName: "photo.on.rectangle")
            coverView.tintColor = Theme.Color.muted
        }
    }
}

// MARK: - TeacherStudioListCell（工作室列表行）

final class TeacherStudioListCell: UITableViewCell {

    private let card = UIView()
    private let coverView = UIImageView()
    private let nameLabel = UILabel()
    private let addressLabel = UILabel()
    private let arrowLabel = UILabel()

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

        // 封面 72pt
        coverView.contentMode = .scaleAspectFill
        coverView.clipsToBounds = true
        coverView.layer.cornerRadius = 12
        coverView.backgroundColor = Theme.Color.surfaceAlt
        card.addSubview(coverView)
        coverView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.cardInner)
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.m)
            $0.width.height.equalTo(72)
        }

        nameLabel.font = .appSection(16)
        nameLabel.textColor = Theme.Color.ink
        card.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.top.equalTo(coverView).offset(4)
            $0.leading.equalTo(coverView.snp.trailing).offset(12)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.xl)
        }

        addressLabel.font = .appLabel(12)
        addressLabel.textColor = Theme.Color.sub
        addressLabel.numberOfLines = 2
        card.addSubview(addressLabel)
        addressLabel.snp.makeConstraints {
            $0.top.equalTo(nameLabel.snp.bottom).offset(6)
            $0.leading.trailing.equalTo(nameLabel)
            $0.bottom.equalTo(coverView).offset(-4)
        }

        arrowLabel.text = "›"
        arrowLabel.font = .appTitle(20)
        arrowLabel.textColor = Theme.Color.muted
        card.addSubview(arrowLabel)
        arrowLabel.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview().inset(Theme.Spacing.cardInner)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(studio: TeacherProfileStudio) {
        nameLabel.text = studio.displayName
        addressLabel.text = studio.address ?? ""
        if let cover = studio.cover, !cover.isEmpty, let url = URL(string: cover) {
            coverView.kf.setImage(with: url)
        } else {
            coverView.image = UIImage(systemName: "building.2.crop.circle")
            coverView.tintColor = Theme.Color.muted
        }
    }
}

// MARK: - TeacherReviewCell（评价列表行）

final class TeacherReviewCell: UITableViewCell {

    private let card = UIView()
    private let avatarView = UIView()
    private let avatarLabel = UILabel()
    private let nameLabel = UILabel()
    private let ratingLabel = UILabel()
    private let dateLabel = UILabel()
    private let contentLabel = UILabel()
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

        // 头像
        avatarView.backgroundColor = Theme.Color.brandSoft
        avatarView.layer.cornerRadius = 18
        avatarView.layer.masksToBounds = true
        card.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.equalToSuperview().offset(Theme.Spacing.cardInner)
            $0.width.height.equalTo(36)
        }

        avatarLabel.font = .appBody(14)
        avatarLabel.textColor = Theme.Color.brand
        avatarLabel.textAlignment = .center
        avatarView.addSubview(avatarLabel)
        avatarLabel.snp.makeConstraints { $0.edges.equalToSuperview() }

        // 名字
        nameLabel.font = .appBody(14)
        nameLabel.textColor = Theme.Color.ink
        card.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarView.snp.trailing).offset(Theme.Spacing.s)
            $0.top.equalTo(avatarView).offset(1)
        }

        // 评分（星星可视化）
        ratingLabel.font = .appLabel(12)
        ratingLabel.textColor = Theme.Color.clay
        card.addSubview(ratingLabel)
        ratingLabel.snp.makeConstraints {
            $0.leading.equalTo(nameLabel.snp.trailing).offset(6)
            $0.centerY.equalTo(nameLabel)
        }

        // 日期
        dateLabel.font = .appLabel(11)
        dateLabel.textColor = Theme.Color.muted
        card.addSubview(dateLabel)
        dateLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.cardInner)
            $0.centerY.equalTo(nameLabel)
        }

        // 评价内容（最多5行，展示更多文字）
        contentLabel.font = .appBody(14)
        contentLabel.textColor = Theme.Color.ink
        contentLabel.numberOfLines = 5
        card.addSubview(contentLabel)
        contentLabel.snp.makeConstraints {
            $0.top.equalTo(avatarView.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.cardInner)
        }

        // 关联课程标签
        courseTag.backgroundColor = Theme.Color.brandSoft
        courseTag.layer.cornerRadius = 11
        card.addSubview(courseTag)
        courseTag.snp.makeConstraints {
            $0.top.equalTo(contentLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.equalTo(contentLabel)
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

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(review: TeacherProfileReview) {
        let name = review.user?.nickname ?? "家长"
        nameLabel.text = name
        avatarLabel.text = String(name.prefix(1))
        // 星级可视化：用 ★/☆ 展示
        let r = review.rating ?? 0
        ratingLabel.text = String(repeating: "★", count: r) + String(repeating: "☆", count: 5 - r)
        dateLabel.text = review.dateText
        contentLabel.text = review.content ?? ""

        if let course = review.course, let title = course.title, !title.isEmpty {
            courseTagLabel.text = "关联课程·\(title)"
            courseTag.isHidden = false
        } else {
            courseTag.isHidden = true
        }

        // 如果内容为空，隐藏课程标签的 top 约束需要调整
        if (review.content ?? "").isEmpty {
            courseTag.snp.remakeConstraints {
                $0.top.equalTo(avatarView.snp.bottom).offset(Theme.Spacing.s)
                $0.leading.equalToSuperview().offset(Theme.Spacing.cardInner)
                $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
                $0.height.equalTo(22)
            }
        }
    }
}