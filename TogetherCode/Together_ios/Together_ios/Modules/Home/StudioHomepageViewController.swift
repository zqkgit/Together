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

    // MARK: - UI

    private let headerView = StudioHeaderView()
    private let segmentControl = UISegmentedControl(items: ["课程", "老师", "介绍"])

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

    // 介绍列表
    private var introTableView: UITableView!

    private let bottomBar = UIView()
    private let callButton = UIButton(type: .system)

    // MARK: - Init

    init(studioId: String) {
        self.studioId = studioId
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
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

        // 介绍列表
        introTableView = UITableView(frame: .zero, style: .plain)
        introTableView.backgroundColor = .clear
        introTableView.separatorStyle = .none
        introTableView.dataSource = self
        introTableView.delegate = self
        introTableView.register(StudioIntroTextCell.self, forCellReuseIdentifier: "StudioIntroTextCell")
        introTableView.register(StudioAddressInfoCell.self, forCellReuseIdentifier: "StudioAddressInfoCell")
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
                self.hasLoaded = true

                self.headerView.configure(studio: data.studio)
                self.coursesTableView.reloadData()
                self.coursesTableView.backgroundView = self.courses.isEmpty ? self.coursesEmpty : nil
                self.teachersTableView.reloadData()
                self.teachersTableView.backgroundView = self.teachers.isEmpty ? self.teachersEmpty : nil
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

    private func stopAllRefresh() {
        coursesTableView.es.stopPullToRefresh()
        teachersTableView.es.stopPullToRefresh()
        introTableView.es.stopPullToRefresh()
    }

    private func updateBottomBar() {
        bottomBar.isHidden = !(studio?.hasPhone ?? false)
    }

    // MARK: - Actions

    @objc private func segmentChanged() {
        let index = segmentControl.selectedSegmentIndex
        coursesTableView.isHidden = index != 0
        teachersTableView.isHidden = index != 1
        introTableView.isHidden = index != 2
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
        if studio?.intro != nil, !(studio?.intro ?? "").isEmpty { count += 1 }
        if studio?.address != nil || studio?.hours != nil { count += 1 }
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
        // 地址 + 营业时间
        if studio?.address != nil || studio?.hours != nil {
            if row == indexPath.row {
                let cell = tableView.dequeueReusableCell(withIdentifier: "StudioAddressInfoCell", for: indexPath) as! StudioAddressInfoCell
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
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
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
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
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
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
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
            $0.trailing.equalToSuperview().inset(Theme.Spacing.xl)
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
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
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
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
        }

        introLabel.font = .appBody(14)
        introLabel.textColor = Theme.Color.sub
        introLabel.numberOfLines = 0
        card.addSubview(introLabel)
        introLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(text: String) {
        introLabel.text = text
    }
}

// MARK: - StudioAddressInfoCell（地址 + 营业时间）

final class StudioAddressInfoCell: UITableViewCell {

    private let card = UIView()
    private let addressIcon = UIImageView()
    private let addressLabel = UILabel()
    private let hoursIcon = UIImageView()
    private let hoursLabel = UILabel()

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

        addressIcon.image = UIImage(systemName: "location.fill")
        addressIcon.tintColor = Theme.Color.brand
        addressIcon.snp.makeConstraints { $0.width.height.equalTo(16) }
        card.addSubview(addressIcon)
        addressIcon.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
        }

        addressLabel.font = .appBody(14)
        addressLabel.textColor = Theme.Color.ink
        addressLabel.numberOfLines = 2
        card.addSubview(addressLabel)
        addressLabel.snp.makeConstraints {
            $0.centerY.equalTo(addressIcon)
            $0.leading.equalTo(addressIcon.snp.trailing).offset(8)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        hoursIcon.image = UIImage(systemName: "clock.fill")
        hoursIcon.tintColor = Theme.Color.brand
        hoursIcon.snp.makeConstraints { $0.width.height.equalTo(16) }
        card.addSubview(hoursIcon)
        hoursIcon.snp.makeConstraints {
            $0.top.equalTo(addressIcon.snp.bottom).offset(12)
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
        }

        hoursLabel.font = .appBody(14)
        hoursLabel.textColor = Theme.Color.sub
        card.addSubview(hoursLabel)
        hoursLabel.snp.makeConstraints {
            $0.centerY.equalTo(hoursIcon)
            $0.leading.equalTo(hoursIcon.snp.trailing).offset(8)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(studio: StudioHomepageInfo?) {
        guard let studio else { return }
        addressLabel.text = studio.address ?? ""
        addressIcon.isHidden = studio.address == nil
        addressLabel.isHidden = studio.address == nil
        hoursLabel.text = studio.hours ?? ""
        hoursIcon.isHidden = studio.hours == nil
        hoursLabel.isHidden = studio.hours == nil
    }
}

// MARK: - StudioPhotoSectionCell（环境照片横滑）

final class StudioPhotoSectionCell: UITableViewCell {

    private let card = UIView()
    private let titleLabel = UILabel()
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
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
        }

        scrollView.showsHorizontalScrollIndicator = false
        card.addSubview(scrollView)
        scrollView.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(140)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.m)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(urls: [String]) {
        scrollView.subviews.forEach { $0.removeFromSuperview() }
        var offsetX: CGFloat = Theme.Spacing.l
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
                $0.width.equalTo(200)
                $0.height.equalTo(130)
            }
            offsetX += 200 + 8
        }
        scrollView.contentSize = CGSize(width: offsetX + Theme.Spacing.l, height: 140)
    }
}