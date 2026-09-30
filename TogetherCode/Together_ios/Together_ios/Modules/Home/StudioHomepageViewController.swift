import UIKit
import SnapKit
import Kingfisher
import ESPullToRefresh

/// 工作室主页详情（家长视角，公开接口）
/// 参考老师主页 UI 风格：深绿渐变头部 + 统计卡 + 课程/老师/介绍三 tab
final class StudioHomepageViewController: BaseViewController {

    // MARK: - Data

    private let studioId: String
    private var studio: StudioHomepageInfo?
    private var teachers: [StudioHomepageTeacher] = []
    private var courses: [StudioHomepageCourse] = []
    private var courseTotal = 0
    private var coursePage = 1
    private var hasMoreCourses = true
    private var isLoadingCourses = false
    private var photos: [String] = []
    private var hasLoaded = false

    // 学员作品
    private var studentWorksList: [StudioHomepageStudentWork] = []
    private var studentWorkTotal = 0
    private var studentWorkPage = 1
    private var hasMoreStudentWorks = true
    private var isLoadingStudentWorks = false

    // MARK: - UI

    private let headerView = StudioHeaderView()
    private let segmentControl = UISegmentedControl(items: ["课程", "学员作品", "老师", "介绍"])

    // 课程列表
    private var coursesTableView: UITableView!
    private let coursesEmpty: EmptyStateView = {
        let view = EmptyStateView()
        view.show(style: .empty("暂无课程\n工作室发布课程后会展示在这里"))
        return view
    }()

    // 老师列表
    private var teachersTableView: UITableView!
    private let teachersEmpty: EmptyStateView = {
        let view = EmptyStateView()
        view.show(style: .empty("暂无老师"))
        return view
    }()

    // 学员作品列表
    private var studentWorksTableView: UITableView!
    private let studentWorksEmpty: EmptyStateView = {
        let view = EmptyStateView()
        view.show(style: .empty("暂无学员作品\n老师发布学员作品后会展示在这里"))
        return view
    }()

    // 介绍列表
    private var introTableView: UITableView!

    private let bottomBar = UIView()
    private let callButton = UIButton(type: .system)

    // MARK: - Init

    init(studioId: String) {
        self.studioId = studioId
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

        // 底部联系栏
        setupBottomBar()

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

        // 课程列表
        coursesTableView = UITableView(frame: .zero, style: .plain)
        coursesTableView.backgroundColor = .clear
        coursesTableView.separatorStyle = .none
        coursesTableView.dataSource = self
        coursesTableView.delegate = self
        coursesTableView.register(StudioCourseCardCell.self, forCellReuseIdentifier: "StudioCourseCardCell")
        coursesTableView.rowHeight = UITableView.automaticDimension
        coursesTableView.estimatedRowHeight = 96
        coursesTableView.alwaysBounceVertical = true
        coursesTableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.refreshAll()
        }
        coursesTableView.es.addInfiniteScrolling { [weak self] in
            self?.loadMoreCourses()
        }
        view.addSubview(coursesTableView)
        coursesTableView.snp.makeConstraints {
            $0.top.equalTo(segmentControl.snp.bottom)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(bottomBar.snp.top)
        }

        // 老师列表
        teachersTableView = UITableView(frame: .zero, style: .plain)
        teachersTableView.backgroundColor = .clear
        teachersTableView.separatorStyle = .none
        teachersTableView.dataSource = self
        teachersTableView.delegate = self
        teachersTableView.register(StudioTeacherCardCell.self, forCellReuseIdentifier: "StudioTeacherCardCell")
        teachersTableView.rowHeight = UITableView.automaticDimension
        teachersTableView.estimatedRowHeight = 80
        teachersTableView.isHidden = true
        teachersTableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.refreshAll()
        }
        view.addSubview(teachersTableView)
        teachersTableView.snp.makeConstraints {
            $0.top.equalTo(segmentControl.snp.bottom)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(bottomBar.snp.top)
        }

        // 学员作品列表
        studentWorksTableView = UITableView(frame: .zero, style: .plain)
        studentWorksTableView.backgroundColor = .clear
        studentWorksTableView.separatorStyle = .none
        studentWorksTableView.dataSource = self
        studentWorksTableView.delegate = self
        studentWorksTableView.register(StudioStudentWorkCell.self, forCellReuseIdentifier: "StudioStudentWorkCell")
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
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(bottomBar.snp.top)
        }

        // 介绍列表
        introTableView = UITableView(frame: .zero, style: .plain)
        introTableView.backgroundColor = .clear
        introTableView.separatorStyle = .none
        introTableView.dataSource = self
        introTableView.delegate = self
        introTableView.register(StudioIntroTextCell.self, forCellReuseIdentifier: "StudioIntroTextCell")
        introTableView.register(StudioDetailInfoCell.self, forCellReuseIdentifier: "StudioDetailInfoCell")
        introTableView.register(StudioPhotoSectionCell.self, forCellReuseIdentifier: "StudioPhotoSectionCell")
        introTableView.rowHeight = UITableView.automaticDimension
        introTableView.estimatedRowHeight = 60
        introTableView.isHidden = true
        introTableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.refreshAll()
        }
        view.addSubview(introTableView)
        introTableView.snp.makeConstraints {
            $0.top.equalTo(segmentControl.snp.bottom)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(bottomBar.snp.top)
        }
    }

    private func setupBottomBar() {
        bottomBar.backgroundColor = Theme.Color.surface
        bottomBar.layer.shadowColor = UIColor.black.cgColor
        bottomBar.layer.shadowOpacity = 0.06
        bottomBar.layer.shadowOffset = CGSize(width: 0, height: -2)
        bottomBar.layer.shadowRadius = 8

        view.addSubview(bottomBar)
        bottomBar.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
        }

        callButton.setTitle("📞 联系工作室", for: .normal)
        callButton.titleLabel?.font = .appLabel(16)
        callButton.setTitleColor(.white, for: .normal)
        callButton.backgroundColor = Theme.Color.brand
        callButton.layer.cornerRadius = 23
        callButton.clipsToBounds = true
        callButton.addTarget(self, action: #selector(didTapCall), for: .touchUpInside)
        bottomBar.addSubview(callButton)
        callButton.snp.makeConstraints {
            $0.top.equalToSuperview().inset(10)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(10)
            $0.centerX.equalToSuperview()
            $0.width.equalTo(240)
            $0.height.equalTo(46)
        }
    }

    // MARK: - Data

    private func loadData() {
        StudioHomepageService.shared.fetchHomepage(studioId: studioId) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let data):
                self.studio = data.studio
                self.teachers = data.teachers ?? []
                self.courses = data.courses?.list ?? []
                self.courseTotal = data.courses?.total ?? 0
                self.coursePage = 1
                self.hasMoreCourses = self.courses.count < self.courseTotal
                self.photos = data.studio?.photos ?? []
                // 首页自带学员作品首页数据
                self.studentWorksList = data.student_works?.list ?? []
                self.studentWorkTotal = data.student_works?.total ?? 0
                self.studentWorkPage = 1
                self.hasMoreStudentWorks = self.studentWorksList.count < self.studentWorkTotal
                self.hasLoaded = true

                self.headerView.configure(studio: data.studio)
                self.coursesTableView.reloadData()
                self.coursesTableView.backgroundView = self.courses.isEmpty ? self.coursesEmpty : nil
                self.teachersTableView.reloadData()
                self.teachersTableView.backgroundView = self.teachers.isEmpty ? self.teachersEmpty : nil
                self.studentWorksTableView.reloadData()
                self.studentWorksTableView.backgroundView = self.studentWorksList.isEmpty ? self.studentWorksEmpty : nil
                self.introTableView.reloadData()
                self.updateBottomBar()
            case .failure(let error):
                self.showToast(error.message)
            }
            self.stopAllRefresh()
        }
    }

    private func refreshAll() {
        coursePage = 1
        studentWorkPage = 1
        loadData()
    }

    private func loadMoreCourses() {
        guard hasMoreCourses, !isLoadingCourses else {
            coursesTableView.es.stopLoadingMore()
            return
        }
        isLoadingCourses = true
        coursePage += 1
        StudioHomepageService.shared.fetchHomepage(studioId: studioId, page: coursePage) { [weak self] result in
            guard let self else { return }
            self.isLoadingCourses = false
            self.coursesTableView.es.stopLoadingMore()
            switch result {
            case .success(let data):
                let newCourses = data.courses?.list ?? []
                self.courses.append(contentsOf: newCourses)
                self.hasMoreCourses = self.courses.count < self.courseTotal
                self.coursesTableView.reloadData()
            case .failure:
                self.coursePage -= 1
            }
        }
    }

    /// 加载学员作品数据
    private func loadStudentWorks(reset: Bool) {
        if reset { studentWorkPage = 1 }
        guard !isLoadingStudentWorks else { return }
        isLoadingStudentWorks = true
        StudioHomepageService.shared.fetchStudentWorks(studioId: studioId, page: studentWorkPage) { [weak self] result in
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

    private func stopAllRefresh() {
        coursesTableView.es.stopPullToRefresh()
        teachersTableView.es.stopPullToRefresh()
        studentWorksTableView.es.stopPullToRefresh()
        introTableView.es.stopPullToRefresh()
    }

    private func updateBottomBar() {
        bottomBar.isHidden = !(studio?.hasPhone ?? false)
    }

    // MARK: - Actions

    @objc private func segmentChanged() {
        let index = segmentControl.selectedSegmentIndex
        coursesTableView.isHidden = index != 0
        studentWorksTableView.isHidden = index != 1
        teachersTableView.isHidden = index != 2
        introTableView.isHidden = index != 3
    }

    @objc private func didTapCall() {
        guard let phone = studio?.phone, !phone.isEmpty, let url = URL(string: "tel://\(phone)") else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - UITableViewDataSource

extension StudioHomepageViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == coursesTableView { return courses.count }
        if tableView == studentWorksTableView { return studentWorksList.count }
        if tableView == teachersTableView { return teachers.count }
        if tableView == introTableView { return introRowCount }
        return 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == coursesTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "StudioCourseCardCell", for: indexPath) as! StudioCourseCardCell
            cell.configure(course: courses[indexPath.row])
            cell.onTap = { [weak self] in
                let c = self?.courses[indexPath.row]
                guard let self, let courseId = c?.course_id else { return }
                let vc = CourseDetailViewController(courseId: courseId)
                self.navigationController?.pushViewController(vc, animated: true)
            }
            return cell
        }
        if tableView == studentWorksTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "StudioStudentWorkCell", for: indexPath) as! StudioStudentWorkCell
            cell.configure(work: studentWorksList[indexPath.row])
            cell.onTap = { [weak self] in
                let item = self?.studentWorksList[indexPath.row]
                guard let self, let postId = item?.post_id else { return }
                let vc = PostDetailViewController(postId: postId)
                self.navigationController?.pushViewController(vc, animated: true)
            }
            return cell
        }
        if tableView == teachersTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "StudioTeacherCardCell", for: indexPath) as! StudioTeacherCardCell
            cell.configure(teacher: teachers[indexPath.row])
            return cell
        }
        if tableView == introTableView {
            return configureIntroCell(tableView: tableView, indexPath: indexPath)
        }
        return UITableViewCell()
    }

    // MARK: - Intro rows

    private var introRowCount: Int {
        var count = 0
        // 介绍
        if let intro = studio?.intro, !intro.isEmpty { count += 1 }
        // 详情信息（地址/营业时间/城市/类型，至少有一项）
        if studio?.address != nil || studio?.hours != nil || studio?.city != nil || studio?.business_type != nil { count += 1 }
        // 环境照片
        if !photos.isEmpty { count += 1 }
        return count
    }

    private func configureIntroCell(tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        var row = 0
        // 介绍
        if let intro = studio?.intro, !intro.isEmpty {
            if row == indexPath.row {
                let cell = tableView.dequeueReusableCell(withIdentifier: "StudioIntroTextCell", for: indexPath) as! StudioIntroTextCell
                cell.configure(text: intro)
                return cell
            }
            row += 1
        }
        // 详情信息
        if studio?.address != nil || studio?.hours != nil || studio?.city != nil || studio?.business_type != nil {
            if row == indexPath.row {
                let cell = tableView.dequeueReusableCell(withIdentifier: "StudioDetailInfoCell", for: indexPath) as! StudioDetailInfoCell
                cell.configure(studio: studio)
                return cell
            }
            row += 1
        }
        // 环境照片
        if !photos.isEmpty {
            if row == indexPath.row {
                let cell = tableView.dequeueReusableCell(withIdentifier: "StudioPhotoSectionCell", for: indexPath) as! StudioPhotoSectionCell
                cell.configure(urls: photos)
                return cell
            }
        }
        return UITableViewCell()
    }
}

// MARK: - UITableViewDelegate

extension StudioHomepageViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView == teachersTableView {
            let teacher = teachers[indexPath.row]
            let vc = TeacherProfileViewController(teacherId: teacher.teacher_id)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
}

// MARK: - StudioHeaderView（渐变头部 + 统计卡）

final class StudioHeaderView: UIView {

    private let coverImageView = UIImageView()
    private let nameLabel = UILabel()
    private let tagsLabel = UILabel()
    private let cityLabel = UILabel()
    private let courseValue = UILabel()
    private let teacherValue = UILabel()
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

        // 封面图（圆形，左上角）
        coverImageView.contentMode = .scaleAspectFill
        coverImageView.clipsToBounds = true
        coverImageView.layer.cornerRadius = 28
        coverImageView.layer.masksToBounds = true
        coverImageView.backgroundColor = .white
        addSubview(coverImageView)
        coverImageView.snp.makeConstraints {
            $0.top.equalTo(safeAreaLayoutGuide).offset(Theme.Spacing.s)
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
            $0.width.height.equalTo(56)
        }

        // 名称
        nameLabel.font = .appSection(18)
        nameLabel.textColor = .white
        addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(coverImageView.snp.trailing).offset(Theme.Spacing.m)
            $0.top.equalTo(coverImageView).offset(2)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.xl)
        }

        // 标签
        tagsLabel.font = .appLabel(12)
        tagsLabel.textColor = .white.withAlphaComponent(0.85)
        addSubview(tagsLabel)
        tagsLabel.snp.makeConstraints {
            $0.leading.equalTo(nameLabel)
            $0.top.equalTo(nameLabel.snp.bottom).offset(3)
        }

        // 城市·类型
        cityLabel.font = .appLabel(12)
        cityLabel.textColor = .white.withAlphaComponent(0.7)
        addSubview(cityLabel)
        cityLabel.snp.makeConstraints {
            $0.leading.equalTo(nameLabel)
            $0.top.equalTo(tagsLabel.snp.bottom).offset(2)
        }

        // 统计卡
        let statCard = UIView()
        statCard.backgroundColor = UIColor.white.withAlphaComponent(0.13)
        statCard.layer.cornerRadius = Theme.Radius.card
        addSubview(statCard)
        statCard.snp.makeConstraints {
            $0.top.equalTo(coverImageView.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(68)
        }

        let items: [(UILabel, UILabel, String)] = [
            (courseValue, statLabel("课程数"), "0"),
            (teacherValue, statLabel("老师数"), "0"),
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

        courseValue.font = .appHero(20)
        teacherValue.font = .appHero(20)
        ratingValue.font = .appHero(20)
        for value in [courseValue, teacherValue, ratingValue] {
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

    func configure(studio: StudioHomepageInfo?) {
        guard let studio else { return }
        nameLabel.text = studio.displayName
        tagsLabel.text = studio.tagsText
        tagsLabel.isHidden = studio.tagsText.isEmpty
        cityLabel.text = studio.locationText
        cityLabel.isHidden = studio.locationText.isEmpty

        if let cover = studio.cover, !cover.isEmpty, let url = URL(string: cover) {
            coverImageView.kf.setImage(with: url)
        } else {
            coverImageView.image = UIImage(systemName: "building.2.crop.circle")
            coverImageView.tintColor = Theme.Color.brand.withAlphaComponent(0.5)
        }

        courseValue.text = "\(studio.course_count ?? 0)"
        teacherValue.text = "\(studio.teacher_count ?? 0)"
        ratingValue.text = studio.ratingText
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.sublayers?.first?.frame = bounds
    }
}

// MARK: - StudioCourseCardCell（课程卡片，card 风格）

final class StudioCourseCardCell: UITableViewCell {

    var onTap: (() -> Void)?

    private let card = UIView()
    private let coverView = UIImageView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let priceLabel = UILabel()

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

        coverView.contentMode = .scaleAspectFill
        coverView.clipsToBounds = true
        coverView.layer.cornerRadius = 10
        coverView.backgroundColor = Theme.Color.surfaceAlt
        card.addSubview(coverView)
        coverView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.cardInner)
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.m)
            $0.width.height.equalTo(72)
        }

        titleLabel.font = .appSection(15)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 2
        card.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(coverView).offset(2)
            $0.leading.equalTo(coverView.snp.trailing).offset(12)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.cardInner)
        }

        detailLabel.font = .appLabel(12)
        detailLabel.textColor = Theme.Color.sub
        card.addSubview(detailLabel)
        detailLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(4)
            $0.leading.trailing.equalTo(titleLabel)
        }

        priceLabel.font = .appSection(15)
        priceLabel.textColor = Theme.Color.clay
        card.addSubview(priceLabel)
        priceLabel.snp.makeConstraints {
            $0.top.equalTo(detailLabel.snp.bottom).offset(4)
            $0.leading.equalTo(titleLabel)
            $0.bottom.equalTo(coverView).offset(-2)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func didTap() { onTap?() }

    func configure(course: StudioHomepageCourse) {
        titleLabel.text = course.title
        detailLabel.text = course.detailText
        priceLabel.text = course.priceText
        if let cover = course.cover, let url = URL(string: cover) {
            coverView.kf.setImage(with: url)
        } else {
            coverView.image = UIImage(systemName: "book")
            coverView.tintColor = Theme.Color.muted
        }
    }
}

// MARK: - StudioTeacherCardCell（老师卡片，card 风格）

final class StudioTeacherCardCell: UITableViewCell {

    private let card = UIView()
    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let subtitleLabel = UILabel()
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

        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 22
        avatarView.backgroundColor = Theme.Color.brandSoft
        card.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.cardInner)
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.m)
            $0.width.height.equalTo(44)
        }

        nameLabel.font = .appSection(15)
        nameLabel.textColor = Theme.Color.ink
        card.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.top.equalTo(avatarView).offset(4)
            $0.leading.equalTo(avatarView.snp.trailing).offset(12)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.cardInner)
        }

        subtitleLabel.font = .appLabel(12)
        subtitleLabel.textColor = Theme.Color.sub
        subtitleLabel.numberOfLines = 2
        card.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints {
            $0.top.equalTo(nameLabel.snp.bottom).offset(4)
            $0.leading.trailing.equalTo(nameLabel)
            $0.bottom.equalTo(avatarView).offset(-4)
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

    func configure(teacher: StudioHomepageTeacher) {
        nameLabel.text = teacher.displayName
        subtitleLabel.text = teacher.subtitle
        if let avatar = teacher.avatar, !avatar.isEmpty, let url = URL(string: avatar) {
            avatarView.kf.setImage(with: url)
        } else {
            avatarView.image = UIImage(systemName: "person.crop.circle")
            avatarView.tintColor = Theme.Color.muted
        }
    }
}

// MARK: - StudioStudentWorkCell（学员作品列表行）

final class StudioStudentWorkCell: UITableViewCell {

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

    func configure(work: StudioHomepageStudentWork) {
        contentLabel.text = work.content ?? "学员作品"
        dateLabel.text = work.created_at.map { String($0.prefix(10)) } ?? ""
        var statsParts: [String] = []
        if let c = work.like_count, c > 0 { statsParts.append("❤️ \(c)") }
        if let c = work.comment_count, c > 0 { statsParts.append("💬 \(c)") }
        statsLabel.text = statsParts.joined(separator: "  ")

        if let img = work.firstImage, let url = URL(string: img) {
            coverView.kf.setImage(with: url)
        } else {
            coverView.image = UIImage(systemName: "photo.on.rectangle")
            coverView.tintColor = Theme.Color.muted
        }
    }
}

// MARK: - StudioIntroTextCell（介绍文本）

final class StudioIntroTextCell: UITableViewCell {

    private let card = UIView()
    private let titleLabel = UILabel()
    private let introLabel = UILabel()

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

        titleLabel.text = "工作室介绍"
        titleLabel.font = .appSection(15)
        titleLabel.textColor = Theme.Color.ink
        card.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.equalToSuperview().offset(Theme.Spacing.cardInner)
        }

        introLabel.font = .appBody(14)
        introLabel.textColor = Theme.Color.sub
        introLabel.numberOfLines = 0
        card.addSubview(introLabel)
        introLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.cardInner)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(text: String) {
        introLabel.text = text
    }
}

// MARK: - StudioDetailInfoCell（详情信息：地址/营业时间/城市/类型）

final class StudioDetailInfoCell: UITableViewCell {

    private let card = UIView()
    private let stackView = UIStackView()

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

        stackView.axis = .vertical
        stackView.spacing = 12
        card.addSubview(stackView)
        stackView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.cardInner)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(studio: StudioHomepageInfo?) {
        guard let studio else { return }
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        // 地址
        if let address = studio.address, !address.isEmpty {
            stackView.addArrangedSubview(makeRow(icon: "location.fill", text: address))
        }
        // 营业时间
        if let hours = studio.hours, !hours.isEmpty {
            stackView.addArrangedSubview(makeRow(icon: "clock.fill", text: hours))
        }
        // 城市
        if let city = studio.city, !city.isEmpty {
            stackView.addArrangedSubview(makeRow(icon: "building.2", text: city))
        }
        // 经营类型
        if let bt = studio.business_type, !bt.isEmpty {
            stackView.addArrangedSubview(makeRow(icon: "tag.fill", text: bt))
        }
        // 联系电话
        if let phone = studio.phone, !phone.isEmpty {
            stackView.addArrangedSubview(makeRow(icon: "phone.fill", text: phone))
        }
    }

    private func makeRow(icon: String, text: String) -> UIView {
        let row = UIView()
        let iconView = UIImageView()
        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = Theme.Color.brand
        iconView.snp.makeConstraints { $0.width.height.equalTo(16) }
        row.addSubview(iconView)
        iconView.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.centerY.equalToSuperview()
        }

        let label = UILabel()
        label.font = .appBody(14)
        label.textColor = Theme.Color.ink
        label.numberOfLines = 2
        label.text = text
        row.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalTo(iconView.snp.trailing).offset(8)
            $0.top.trailing.bottom.equalToSuperview()
        }
        return row
    }
}

// MARK: - StudioPhotoSectionCell（环境照片横滑）

final class StudioPhotoSectionCell: UITableViewCell {

    private let card = UIView()
    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    private let scrollView = UIScrollView()

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

        titleLabel.text = "环境照片"
        titleLabel.font = .appSection(15)
        titleLabel.textColor = Theme.Color.ink
        card.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.equalToSuperview().offset(Theme.Spacing.cardInner)
        }

        countLabel.font = .appLabel(12)
        countLabel.textColor = Theme.Color.muted
        card.addSubview(countLabel)
        countLabel.snp.makeConstraints {
            $0.centerY.equalTo(titleLabel)
            $0.leading.equalTo(titleLabel.snp.trailing).offset(6)
        }

        scrollView.showsHorizontalScrollIndicator = false
        card.addSubview(scrollView)
        scrollView.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(180)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.m)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(urls: [String]) {
        countLabel.text = "(\(urls.count))"
        scrollView.subviews.forEach { $0.removeFromSuperview() }
        var offsetX: CGFloat = Theme.Spacing.cardInner
        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }
            let img = UIImageView()
            img.contentMode = .scaleAspectFill
            img.clipsToBounds = true
            img.layer.cornerRadius = Theme.Radius.card
            img.kf.setImage(with: url)
            scrollView.addSubview(img)
            img.snp.makeConstraints {
                $0.leading.equalTo(offsetX)
                $0.top.equalToSuperview()
                $0.width.equalTo(240)
                $0.height.equalTo(170)
            }
            offsetX += 240 + 8
        }
        scrollView.contentSize = CGSize(width: offsetX + Theme.Spacing.l, height: 180)
    }
}