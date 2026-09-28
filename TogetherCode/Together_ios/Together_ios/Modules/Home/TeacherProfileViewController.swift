import UIKit
import SnapKit
import Kingfisher
import ESPullToRefresh

/// 老师主页（家长视角，公开接口）
/// 结构：头像信息卡 → 个人介绍 → 作品集 → 所属工作室 → 在售课程 → 作品动态
final class TeacherProfileViewController: BaseViewController {

    // MARK: - Data

    private let teacherId: String
    private var data: TeacherProfileData?
    private var profile: TeacherProfileInfo? { data?.profile }
    private var studios: [TeacherProfileStudio] { data?.studios ?? [] }
    private var courses: [TeacherProfileCourse] { data?.courses ?? [] }
    private var worksList: [TeacherProfileWork] = []
    private var workTotal: Int { data?.works?.total ?? 0 }
    private var workPage = 1
    private var hasMoreWorks = true

    // MARK: - Row 类型

    private enum Row {
        case header          // 头像 + 姓名 + 擅长 + 统计
        case intro           // 个人介绍
        case portfolio       // 作品集照片横滑
        case studioHeader    // 所属工作室标题
        case studio(TeacherProfileStudio)
        case courseHeader    // 在售课程标题
        case course(TeacherProfileCourse)
        case workHeader      // 作品动态标题
        case work(TeacherProfileWork)
    }

    private var rows: [Row] = []
    private var hasLoaded = false

    // MARK: - UI

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyView = EmptyStateView()

    // MARK: - Init

    init(teacherId: String) {
        self.teacherId = teacherId
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        setupTableView()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "老师主页")
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

        tableView.register(TeacherProfileHeaderCell.self, forCellReuseIdentifier: "TeacherProfileHeaderCell")
        tableView.register(TeacherProfileIntroCell.self, forCellReuseIdentifier: "TeacherProfileIntroCell")
        tableView.register(TeacherProfilePortfolioCell.self, forCellReuseIdentifier: "TeacherProfilePortfolioCell")
        tableView.register(TeacherSectionHeaderCell.self, forCellReuseIdentifier: "TeacherSectionHeaderCell")
        tableView.register(TeacherProfileStudioCell.self, forCellReuseIdentifier: "TeacherProfileStudioCell")
        tableView.register(TeacherProfileCourseCell.self, forCellReuseIdentifier: "TeacherProfileCourseCell")
        tableView.register(TeacherProfileWorkCell.self, forCellReuseIdentifier: "TeacherProfileWorkCell")

        tableView.dataSource = self
        tableView.delegate = self

        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.refresh()
        }

        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        emptyView.show(style: .loading)
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview()
            $0.width.equalToSuperview()
        }
    }

    // MARK: - Data

    private func refresh() {
        workPage = 1
        hasMoreWorks = true
        loadData()
    }

    private func loadData() {
        emptyView.isHidden = hasLoaded
        if !hasLoaded { emptyView.show(style: .loading) }

        TeacherProfileService.shared.fetchHomepage(teacherId: teacherId, page: workPage) { [weak self] result in
            guard let self else { return }
            self.tableView.es.stopPullToRefresh()
            switch result {
            case .success(let data):
                self.data = data
                self.hasLoaded = true
                if workPage <= 1 {
                    self.worksList = data.works?.list ?? []
                }
                self.hasMoreWorks = self.worksList.count < (data.works?.total ?? 0)
                self.buildRows()
                self.tableView.reloadData()
                self.emptyView.isHidden = true
            case .failure(let error):
                if !self.hasLoaded {
                    self.emptyView.show(style: .error(error.message) { [weak self] in
                        self?.loadData()
                    })
                } else {
                    self.showToast(error.message)
                }
            }
        }
    }

    private func buildRows() {
        rows.removeAll()
        guard let profile else { return }

        rows.append(.header)

        if profile.hasIntro { rows.append(.intro) }
        if profile.hasPortfolio { rows.append(.portfolio) }

        if !studios.isEmpty {
            rows.append(.studioHeader)
            studios.forEach { rows.append(.studio($0)) }
        }

        if !courses.isEmpty {
            rows.append(.courseHeader)
            courses.forEach { rows.append(.course($0)) }
        }

        if !worksList.isEmpty || workTotal > 0 {
            rows.append(.workHeader)
            worksList.forEach { rows.append(.work($0)) }
        }
    }
}

// MARK: - UITableViewDataSource

extension TeacherProfileViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = rows[indexPath.row]
        switch row {
        case .header:
            let cell = tableView.dequeueReusableCell(withIdentifier: "TeacherProfileHeaderCell", for: indexPath) as! TeacherProfileHeaderCell
            cell.configure(user: data?.user, profile: profile)
            return cell
        case .intro:
            let cell = tableView.dequeueReusableCell(withIdentifier: "TeacherProfileIntroCell", for: indexPath) as! TeacherProfileIntroCell
            cell.configure(text: profile?.intro)
            return cell
        case .portfolio:
            let cell = tableView.dequeueReusableCell(withIdentifier: "TeacherProfilePortfolioCell", for: indexPath) as! TeacherProfilePortfolioCell
            cell.configure(urls: profile?.portfolio ?? [])
            return cell
        case .studioHeader:
            let cell = tableView.dequeueReusableCell(withIdentifier: "TeacherSectionHeaderCell", for: indexPath) as! TeacherSectionHeaderCell
            cell.configure(title: "所属工作室", count: studios.count)
            return cell
        case .studio(let s):
            let cell = tableView.dequeueReusableCell(withIdentifier: "TeacherProfileStudioCell", for: indexPath) as! TeacherProfileStudioCell
            cell.configure(studio: s)
            return cell
        case .courseHeader:
            let cell = tableView.dequeueReusableCell(withIdentifier: "TeacherSectionHeaderCell", for: indexPath) as! TeacherSectionHeaderCell
            cell.configure(title: "在售课程", count: courses.count)
            return cell
        case .course(let c):
            let cell = tableView.dequeueReusableCell(withIdentifier: "TeacherProfileCourseCell", for: indexPath) as! TeacherProfileCourseCell
            cell.configure(course: c)
            cell.onTap = { [weak self] in
                let vc = CourseDetailViewController(courseId: c.course_id)
                self?.navigationController?.pushViewController(vc, animated: true)
            }
            return cell
        case .workHeader:
            let cell = tableView.dequeueReusableCell(withIdentifier: "TeacherSectionHeaderCell", for: indexPath) as! TeacherSectionHeaderCell
            cell.configure(title: "作品动态", count: workTotal)
            return cell
        case .work(let w):
            let cell = tableView.dequeueReusableCell(withIdentifier: "TeacherProfileWorkCell", for: indexPath) as! TeacherProfileWorkCell
            cell.configure(work: w)
            cell.onTap = { [weak self] in
                let vc = PostDetailViewController(postId: w.post_id)
                self?.navigationController?.pushViewController(vc, animated: true)
            }
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension TeacherProfileViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = rows[indexPath.row]
        switch row {
        case .studio(let s):
            let vc = StudioHomepageViewController(studioId: s.studio_id)
            navigationController?.pushViewController(vc, animated: true)
        default:
            break
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let row = rows[indexPath.row]
        switch row {
        case .header: return UITableView.automaticDimension
        case .intro: return UITableView.automaticDimension
        case .portfolio: return 160
        case .studioHeader, .courseHeader, .workHeader: return 48
        case .studio: return 64
        case .course: return 88
        case .work: return UITableView.automaticDimension
        }
    }
}

// MARK: - TeacherProfileHeaderCell

/// 头像 + 姓名 + 擅长 + 评分统计
final class TeacherProfileHeaderCell: UITableViewCell {

    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let subjectsLabel = UILabel()
    private let statsLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.surface
        selectionStyle = .none

        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 36
        avatarView.backgroundColor = Theme.Color.brandSoft
        contentView.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.xl)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(72)
        }

        nameLabel.font = .appTitle(20)
        nameLabel.textColor = Theme.Color.ink
        nameLabel.textAlignment = .center
        contentView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.top.equalTo(avatarView.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        subjectsLabel.font = .appLabel(13)
        subjectsLabel.textColor = Theme.Color.brand
        subjectsLabel.textAlignment = .center
        subjectsLabel.numberOfLines = 2
        contentView.addSubview(subjectsLabel)
        subjectsLabel.snp.makeConstraints {
            $0.top.equalTo(nameLabel.snp.bottom).offset(Theme.Spacing.xs)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        statsLabel.font = .appLabel(12)
        statsLabel.textColor = Theme.Color.sub
        statsLabel.textAlignment = .center
        contentView.addSubview(statsLabel)
        statsLabel.snp.makeConstraints {
            $0.top.equalTo(subjectsLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    func configure(user: TeacherProfileUser?, profile: TeacherProfileInfo?) {
        nameLabel.text = profile?.displayName ?? "老师"
        subjectsLabel.text = profile?.subjectsText ?? ""
        statsLabel.text = profile?.statsText ?? ""
        if let avatar = user?.avatar, let url = URL(string: avatar), !avatar.isEmpty {
            avatarView.kf.setImage(with: url)
        } else {
            avatarView.image = nil
            avatarView.backgroundColor = Theme.Color.brandSoft
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - TeacherProfileIntroCell

/// 个人介绍
final class TeacherProfileIntroCell: UITableViewCell {

    private let titleLabel = UILabel()
    private let contentLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.surface
        selectionStyle = .none

        titleLabel.text = "个人介绍"
        titleLabel.font = .appSection(15)
        titleLabel.textColor = Theme.Color.ink
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        contentLabel.font = .appBody(14)
        contentLabel.textColor = Theme.Color.sub
        contentLabel.numberOfLines = 0
        contentView.addSubview(contentLabel)
        contentLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    func configure(text: String?) {
        contentLabel.text = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - TeacherProfilePortfolioCell

/// 作品集照片横滑
final class TeacherProfilePortfolioCell: UITableViewCell {

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

// MARK: - TeacherSectionHeaderCell

/// 分区标题行
final class TeacherSectionHeaderCell: UITableViewCell {

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

// MARK: - TeacherProfileStudioCell

/// 工作室行：封面 + 名称 + 地址
final class TeacherProfileStudioCell: UITableViewCell {

    private let coverView = UIImageView()
    private let nameLabel = UILabel()
    private let addressLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.surface
        selectionStyle = .none
        accessoryType = .disclosureIndicator

        coverView.contentMode = .scaleAspectFill
        coverView.clipsToBounds = true
        coverView.layer.cornerRadius = 8
        coverView.backgroundColor = Theme.Color.surfaceAlt
        contentView.addSubview(coverView)
        coverView.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(40)
        }

        nameLabel.font = .appSection(14)
        nameLabel.textColor = Theme.Color.ink
        contentView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(14)
            $0.leading.equalTo(coverView.snp.trailing).offset(10)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.xl)
        }

        addressLabel.font = .appLabel(12)
        addressLabel.textColor = Theme.Color.sub
        contentView.addSubview(addressLabel)
        addressLabel.snp.makeConstraints {
            $0.top.equalTo(nameLabel.snp.bottom).offset(2)
            $0.leading.trailing.equalTo(nameLabel)
            $0.bottom.equalToSuperview().inset(14)
        }
    }

    func configure(studio: TeacherProfileStudio) {
        nameLabel.text = studio.displayName
        addressLabel.text = studio.address ?? ""
        if let cover = studio.cover, let url = URL(string: cover) {
            coverView.kf.setImage(with: url)
        } else {
            coverView.image = nil
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - TeacherProfileCourseCell

/// 课程卡片：封面 + 标题 + 价格行
final class TeacherProfileCourseCell: UITableViewCell {

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
        coverView.backgroundColor = Theme.Color.surfaceAlt
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

    func configure(course: TeacherProfileCourse) {
        titleLabel.text = course.title
        detailLabel.text = course.detailText
        priceLabel.text = course.priceText
        if let cover = course.cover, let url = URL(string: cover) {
            coverView.kf.setImage(with: url)
        } else {
            coverView.image = nil
        }
    }

    @objc private func didTap() { onTap?() }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - TeacherProfileWorkCell

/// 作品/动态行：封面图 + 内容摘要 + 互动数据
final class TeacherProfileWorkCell: UITableViewCell {

    var onTap: (() -> Void)?

    private let coverView = UIImageView()
    private let contentLabel = UILabel()
    private let statsLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.surface
        selectionStyle = .none

        coverView.contentMode = .scaleAspectFill
        coverView.clipsToBounds = true
        coverView.layer.cornerRadius = 8
        coverView.backgroundColor = Theme.Color.surfaceAlt
        contentView.addSubview(coverView)
        coverView.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalToSuperview().offset(8)
            $0.bottom.equalToSuperview().inset(8)
            $0.width.height.equalTo(56)
        }

        contentLabel.font = .appBody(14)
        contentLabel.textColor = Theme.Color.ink
        contentLabel.numberOfLines = 2
        contentView.addSubview(contentLabel)
        contentLabel.snp.makeConstraints {
            $0.top.equalTo(coverView).offset(2)
            $0.leading.equalTo(coverView.snp.trailing).offset(10)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        statsLabel.font = .appLabel(11)
        statsLabel.textColor = Theme.Color.muted
        contentView.addSubview(statsLabel)
        statsLabel.snp.makeConstraints {
            $0.top.equalTo(contentLabel.snp.bottom).offset(4)
            $0.leading.equalTo(contentLabel)
            $0.bottom.equalTo(coverView).offset(-2)
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        contentView.addGestureRecognizer(tap)
    }

    func configure(work: TeacherProfileWork) {
        contentLabel.text = work.content ?? ""
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

    @objc private func didTap() { onTap?() }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}