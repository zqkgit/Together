import UIKit
import SnapKit
import Kingfisher
import ESPullToRefresh

/// 工作室主页详情（家长视角，公开接口）
/// 结构：封面大图 → 基本信息 → 介绍 → 师资团队 → 热门课程 → 环境照片 → 底部联系栏
final class StudioHomepageViewController: BaseViewController {

    // MARK: - Data

    private let studioId: String
    private var studio: StudioHomepageInfo?
    private var teachers: [StudioHomepageTeacher] = []
    private var courses: [StudioHomepageCourse] = []
    private var courseTotal = 0
    private var coursePage = 1
    private var hasMoreCourses = true
    private var photos: [String] = []

    // MARK: - Row 类型

    private enum Row {
        case cover           // 封面大图
        case info            // 名称 + 标签 + 统计
        case address         // 地址 + 营业时间
        case intro           // 工作室介绍
        case teacherHeader   // 师资团队标题
        case teacher(StudioHomepageTeacher)
        case courseHeader    // 热门课程标题
        case course(StudioHomepageCourse)
        case photoHeader     // 环境照片标题
        case photo           // 照片横滑行
    }

    private var rows: [Row] = []
    private var hasLoaded = false

    // MARK: - UI

    private let tableView = UITableView(frame: .zero, style: .plain)
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
        view.backgroundColor = Theme.Color.bg
        setupBottomBar()
        setupTableView()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "工作室详情")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    // MARK: - UI Setup

    private func setupTableView() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.alwaysBounceVertical = true
        tableView.estimatedRowHeight = 60
        tableView.estimatedSectionHeaderHeight = 0
        tableView.estimatedSectionFooterHeight = 0
        tableView.rowHeight = UITableView.automaticDimension
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }

        tableView.register(StudioCoverCell.self, forCellReuseIdentifier: "StudioCoverCell")
        tableView.register(StudioInfoCell.self, forCellReuseIdentifier: "StudioInfoCell")
        tableView.register(StudioAddressCell.self, forCellReuseIdentifier: "StudioAddressCell")
        tableView.register(StudioIntroCell.self, forCellReuseIdentifier: "StudioIntroCell")
        tableView.register(StudioSectionHeaderCell.self, forCellReuseIdentifier: "StudioSectionHeaderCell")
        tableView.register(StudioTeacherRowCell.self, forCellReuseIdentifier: "StudioTeacherRowCell")
        tableView.register(StudioCourseCardCell.self, forCellReuseIdentifier: "StudioCourseCardCell")
        tableView.register(StudioPhotoRowCell.self, forCellReuseIdentifier: "StudioPhotoRowCell")

        tableView.dataSource = self
        tableView.delegate = self

        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.refresh()
        }

        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
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
                self.buildRows()
                self.tableView.reloadData()
                self.updateBottomBar()
            case .failure(let error):
                self.showToast(error.message)
            }
            self.hasLoaded = true
            self.tableView.es.stopPullToRefresh()
        }
    }

    private func refresh() {
        coursePage = 1
        loadData()
    }

    private func loadMoreCourses() {
        guard hasMoreCourses else { return }
        coursePage += 1
        StudioHomepageService.shared.fetchHomepage(studioId: studioId, page: coursePage) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let data):
                let newCourses = data.courses?.list ?? []
                self.courses.append(contentsOf: newCourses)
                self.hasMoreCourses = self.courses.count < self.courseTotal
                self.buildRows()
                self.tableView.reloadData()
            case .failure:
                self.coursePage -= 1
            }
        }
    }

    private func buildRows() {
        rows = []
        guard let studio else { return }

        // 封面
        rows.append(.cover)
        // 基本信息
        rows.append(.info)
        // 地址 + 营业时间
        if studio.address != nil || studio.hours != nil {
            rows.append(.address)
        }
        // 介绍
        if let intro = studio.intro, !intro.isEmpty {
            rows.append(.intro)
        }
        // 师资团队
        if !teachers.isEmpty {
            rows.append(.teacherHeader)
            for t in teachers.prefix(5) {
                rows.append(.teacher(t))
            }
        }
        // 热门课程
        if !courses.isEmpty {
            rows.append(.courseHeader)
            for c in courses {
                rows.append(.course(c))
            }
        }
        // 环境照片
        if !photos.isEmpty {
            rows.append(.photoHeader)
            rows.append(.photo)
        }
    }

    private func updateBottomBar() {
        bottomBar.isHidden = !(studio?.hasPhone ?? false)
    }

    // MARK: - Actions

    @objc private func didTapCall() {
        guard let phone = studio?.phone, !phone.isEmpty, let url = URL(string: "tel://\(phone)") else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - UITableViewDataSource

extension StudioHomepageViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = rows[indexPath.row]
        switch row {
        case .cover:
            let cell = tableView.dequeueReusableCell(withIdentifier: "StudioCoverCell", for: indexPath) as! StudioCoverCell
            cell.configure(studio: studio)
            return cell
        case .info:
            let cell = tableView.dequeueReusableCell(withIdentifier: "StudioInfoCell", for: indexPath) as! StudioInfoCell
            cell.configure(studio: studio)
            return cell
        case .address:
            let cell = tableView.dequeueReusableCell(withIdentifier: "StudioAddressCell", for: indexPath) as! StudioAddressCell
            cell.configure(studio: studio)
            return cell
        case .intro:
            let cell = tableView.dequeueReusableCell(withIdentifier: "StudioIntroCell", for: indexPath) as! StudioIntroCell
            cell.configure(studio: studio)
            return cell
        case .teacherHeader:
            let cell = tableView.dequeueReusableCell(withIdentifier: "StudioSectionHeaderCell", for: indexPath) as! StudioSectionHeaderCell
            cell.configure(title: "师资团队", count: teachers.count)
            return cell
        case .teacher(let t):
            let cell = tableView.dequeueReusableCell(withIdentifier: "StudioTeacherRowCell", for: indexPath) as! StudioTeacherRowCell
            cell.configure(teacher: t)
            return cell
        case .courseHeader:
            let cell = tableView.dequeueReusableCell(withIdentifier: "StudioSectionHeaderCell", for: indexPath) as! StudioSectionHeaderCell
            cell.configure(title: "热门课程", count: courseTotal)
            return cell
        case .course(let c):
            let cell = tableView.dequeueReusableCell(withIdentifier: "StudioCourseCardCell", for: indexPath) as! StudioCourseCardCell
            cell.configure(course: c)
            cell.onTap = { [weak self] in
                let vc = CourseDetailViewController(courseId: c.course_id)
                self?.navigationController?.pushViewController(vc, animated: true)
            }
            return cell
        case .photoHeader:
            let cell = tableView.dequeueReusableCell(withIdentifier: "StudioSectionHeaderCell", for: indexPath) as! StudioSectionHeaderCell
            cell.configure(title: "环境照片", count: nil)
            return cell
        case .photo:
            let cell = tableView.dequeueReusableCell(withIdentifier: "StudioPhotoRowCell", for: indexPath) as! StudioPhotoRowCell
            cell.configure(urls: photos)
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension StudioHomepageViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = rows[indexPath.row]
        switch row {
        case .teacher:
            showToast("老师主页开发中")
        default:
            break
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let row = rows[indexPath.row]
        switch row {
        case .cover: return 220
        case .info: return UITableView.automaticDimension
        case .address: return UITableView.automaticDimension
        case .intro: return UITableView.automaticDimension
        case .teacherHeader, .courseHeader, .photoHeader: return 48
        case .teacher: return 72
        case .course: return 96
        case .photo: return 160
        }
    }
}

// MARK: - StudioCoverCell

/// 封面大图（16:9 宽高比，无图时渐变占位）
final class StudioCoverCell: UITableViewCell {

    private let coverImageView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(coverImageView)
        coverImageView.contentMode = .scaleAspectFill
        coverImageView.clipsToBounds = true
        coverImageView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.height.equalTo(220)
        }
    }

    func configure(studio: StudioHomepageInfo?) {
        if let cover = studio?.cover, let url = URL(string: cover) {
            coverImageView.kf.setImage(with: url)
        } else {
            coverImageView.image = nil
            coverImageView.backgroundColor = Theme.Color.brandSoft
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - StudioInfoCell

/// 工作室名称 + 标签 + 统计
final class StudioInfoCell: UITableViewCell {

    private let nameLabel = UILabel()
    private let tagsLabel = PaddedLabel()
    private let statsLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.surface
        selectionStyle = .none

        nameLabel.font = .appTitle(20)
        nameLabel.textColor = Theme.Color.ink
        nameLabel.numberOfLines = 2
        contentView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        tagsLabel.font = .appLabel(12)
        tagsLabel.textColor = Theme.Color.brand
        tagsLabel.backgroundColor = Theme.Color.brandSoft
        tagsLabel.layer.cornerRadius = 4
        tagsLabel.clipsToBounds = true
        tagsLabel.textAlignment = .center
        tagsLabel.textInsets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        contentView.addSubview(tagsLabel)
        tagsLabel.snp.makeConstraints {
            $0.top.equalTo(nameLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
        }

        statsLabel.font = .appBody(13)
        statsLabel.textColor = Theme.Color.sub
        contentView.addSubview(statsLabel)
        statsLabel.snp.makeConstraints {
            $0.top.equalTo(tagsLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    func configure(studio: StudioHomepageInfo?) {
        guard let studio else { return }
        nameLabel.text = studio.displayName
        tagsLabel.text = studio.tagsText
        tagsLabel.isHidden = studio.tagsText.isEmpty
        statsLabel.text = studio.statsText
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - StudioAddressCell

/// 地址 + 营业时间
final class StudioAddressCell: UITableViewCell {

    private let addressIcon = UIImageView()
    private let addressLabel = UILabel()
    private let hoursIcon = UIImageView()
    private let hoursLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.surface
        selectionStyle = .none

        addressIcon.image = UIImage(systemName: "location.fill")
        addressIcon.tintColor = Theme.Color.muted
        addressIcon.snp.makeConstraints { $0.width.height.equalTo(16) }
        contentView.addSubview(addressIcon)
        addressIcon.snp.makeConstraints {
            $0.top.equalToSuperview().offset(12)
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
        }

        addressLabel.font = .appBody(14)
        addressLabel.textColor = Theme.Color.ink
        addressLabel.numberOfLines = 2
        contentView.addSubview(addressLabel)
        addressLabel.snp.makeConstraints {
            $0.centerY.equalTo(addressIcon)
            $0.leading.equalTo(addressIcon.snp.trailing).offset(6)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        hoursIcon.image = UIImage(systemName: "clock.fill")
        hoursIcon.tintColor = Theme.Color.muted
        hoursIcon.snp.makeConstraints { $0.width.height.equalTo(16) }
        contentView.addSubview(hoursIcon)
        hoursIcon.snp.makeConstraints {
            $0.top.equalTo(addressIcon.snp.bottom).offset(10)
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
        }

        hoursLabel.font = .appBody(14)
        hoursLabel.textColor = Theme.Color.sub
        contentView.addSubview(hoursLabel)
        hoursLabel.snp.makeConstraints {
            $0.centerY.equalTo(hoursIcon)
            $0.leading.equalTo(hoursIcon.snp.trailing).offset(6)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(12)
        }
    }

    func configure(studio: StudioHomepageInfo?) {
        guard let studio else { return }
        addressLabel.text = studio.address ?? ""
        addressIcon.isHidden = studio.address == nil
        addressLabel.isHidden = studio.address == nil
        hoursLabel.text = studio.hours ?? ""
        hoursIcon.isHidden = studio.hours == nil
        hoursLabel.isHidden = studio.hours == nil
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - StudioIntroCell

/// 工作室介绍（可展开）
final class StudioIntroCell: UITableViewCell {

    private let titleLabel = UILabel()
    private let introLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.surface
        selectionStyle = .none

        titleLabel.text = "工作室介绍"
        titleLabel.font = .appSection(15)
        titleLabel.textColor = Theme.Color.ink
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
        }

        introLabel.font = .appBody(14)
        introLabel.textColor = Theme.Color.sub
        introLabel.numberOfLines = 0
        contentView.addSubview(introLabel)
        introLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    func configure(studio: StudioHomepageInfo?) {
        guard let studio else { return }
        introLabel.text = studio.intro ?? ""
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - StudioSectionHeaderCell

/// 分区标题：「师资团队」「热门课程」「环境照片」
final class StudioSectionHeaderCell: UITableViewCell {

    private let titleLabel = UILabel()
    private let countLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.bg
        selectionStyle = .none

        titleLabel.font = .appSection(15)
        titleLabel.textColor = Theme.Color.ink
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
        }

        countLabel.font = .appLabel(12)
        countLabel.textColor = Theme.Color.muted
        contentView.addSubview(countLabel)
        countLabel.snp.makeConstraints {
            $0.leading.equalTo(titleLabel.snp.trailing).offset(6)
            $0.centerY.equalToSuperview()
        }
    }

    func configure(title: String, count: Int?) {
        titleLabel.text = title
        if let count { countLabel.text = "(\(count))" } else { countLabel.text = "" }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - StudioTeacherRowCell

/// 老师行：头像 + 姓名 + 副标题
final class StudioTeacherRowCell: UITableViewCell {

    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.surface
        selectionStyle = .none

        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 20
        contentView.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(40)
        }

        nameLabel.font = .appSection(14)
        nameLabel.textColor = Theme.Color.ink
        contentView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(14)
            $0.leading.equalTo(avatarView.snp.trailing).offset(10)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        subtitleLabel.font = .appLabel(12)
        subtitleLabel.textColor = Theme.Color.sub
        contentView.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints {
            $0.top.equalTo(nameLabel.snp.bottom).offset(2)
            $0.leading.trailing.equalTo(nameLabel)
            $0.bottom.equalToSuperview().inset(14)
        }
    }

    func configure(teacher: StudioHomepageTeacher) {
        nameLabel.text = teacher.displayName
        subtitleLabel.text = teacher.subtitle
        if let avatar = teacher.avatar, let url = URL(string: avatar) {
            avatarView.kf.setImage(with: url)
        } else {
            avatarView.image = nil
            avatarView.backgroundColor = Theme.Color.brandSoft
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - StudioCourseCardCell

/// 课程卡片：封面 + 标题 + 价格行
final class StudioCourseCardCell: UITableViewCell {

    var onTap: (() -> Void)?

    private let coverView = UIImageView()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let priceLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.surface
        selectionStyle = .none

        coverView.contentMode = .scaleAspectFill
        coverView.clipsToBounds = true
        coverView.layer.cornerRadius = Theme.Radius.card
        contentView.addSubview(coverView)
        coverView.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalToSuperview().offset(8)
            $0.bottom.equalToSuperview().inset(8)
            $0.width.equalTo(72)
            $0.height.equalTo(72)
        }

        titleLabel.font = .appSection(14)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 2
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(coverView).offset(2)
            $0.leading.equalTo(coverView.snp.trailing).offset(10)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        detailLabel.font = .appLabel(12)
        detailLabel.textColor = Theme.Color.sub
        contentView.addSubview(detailLabel)
        detailLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(4)
            $0.leading.trailing.equalTo(titleLabel)
        }

        priceLabel.font = .appSection(15)
        priceLabel.textColor = Theme.Color.clay
        contentView.addSubview(priceLabel)
        priceLabel.snp.makeConstraints {
            $0.top.equalTo(detailLabel.snp.bottom).offset(4)
            $0.leading.equalTo(titleLabel)
            $0.bottom.equalTo(coverView).offset(-2)
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        contentView.addGestureRecognizer(tap)
    }

    func configure(course: StudioHomepageCourse) {
        titleLabel.text = course.title
        detailLabel.text = course.detailText
        priceLabel.text = course.priceText
        if let cover = course.cover, let url = URL(string: cover) {
            coverView.kf.setImage(with: url)
        } else {
            coverView.image = nil
            coverView.backgroundColor = Theme.Color.surfaceAlt
        }
    }

    @objc private func didTap() { onTap?() }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - StudioPhotoRowCell

/// 环境照片横滑行
final class StudioPhotoRowCell: UITableViewCell {

    private let scrollView = UIScrollView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.surface
        selectionStyle = .none

        scrollView.showsHorizontalScrollIndicator = false
        contentView.addSubview(scrollView)
        scrollView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.height.equalTo(160)
        }
    }

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
                $0.top.equalToSuperview().offset(8)
                $0.width.equalTo(200)
                $0.height.equalTo(140)
            }
            offsetX += 200 + 8
        }
        scrollView.contentSize = CGSize(width: offsetX + Theme.Spacing.l, height: 160)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - PaddedLabel

private final class PaddedLabel: UILabel {
    var textInsets = UIEdgeInsets.zero
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + textInsets.left + textInsets.right,
                      height: size.height + textInsets.top + textInsets.bottom)
    }
}