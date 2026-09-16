import UIKit
import SnapKit
import Kingfisher

/// 课程详情（对齐 PR 设计图 #courseDetail）
/// 结构：封面 → 标签行/标题/副标题 → 机构卡 → 课程介绍 → 家长评价 → 底部「¥xx / N节 + 立即报名」
final class CourseDetailViewController: BaseViewController {

    private let courseId: String
    private var course: CourseDetail?
    private var reviews: [CourseReviewItem] = []

    private lazy var tableView = UITableView(frame: .zero, style: .plain)
    private let bottomBar = UIView()
    private let priceLabel = UILabel()
    private let enrollButton = UIButton(type: .system)

    init(courseId: String) {
        self.courseId = courseId
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        setupBottomBar()
        setupTableView()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "课程详情")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    // MARK: - UI

    private func setupTableView() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.alwaysBounceVertical = true
        tableView.estimatedRowHeight = 120
        tableView.rowHeight = UITableView.automaticDimension
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(CourseCoverCell.self, forCellReuseIdentifier: CourseCoverCell.reuseID)
        tableView.register(CourseDetailInfoCell.self, forCellReuseIdentifier: CourseDetailInfoCell.reuseID)
        tableView.register(CourseDetailCardCell.self, forCellReuseIdentifier: CourseDetailCardCell.reuseID)
        tableView.register(CourseIntroCell.self, forCellReuseIdentifier: CourseIntroCell.reuseID)
        tableView.register(CourseReviewCell.self, forCellReuseIdentifier: CourseReviewCell.reuseID)

        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
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

        priceLabel.font = .appTitle(18)
        priceLabel.textColor = Theme.Color.clay
        bottomBar.addSubview(priceLabel)
        priceLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
        }

        enrollButton.setTitle("立即报名", for: .normal)
        enrollButton.setTitleColor(.white, for: .normal)
        enrollButton.titleLabel?.font = .appLabel(16)
        enrollButton.backgroundColor = Theme.Color.brand
        enrollButton.layer.cornerRadius = Theme.Radius.button
        enrollButton.addTarget(self, action: #selector(didTapEnroll), for: .touchUpInside)
        bottomBar.addSubview(enrollButton)
        enrollButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.top.equalToSuperview().inset(10)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(10)
            $0.width.equalTo(140)
            $0.height.equalTo(46)
        }
    }

    // MARK: - Data

    private func loadData() {
        showLoading()
        let group = DispatchGroup()
        var detailError: String?

        group.enter()
        CourseService.fetchDetail(courseId: courseId) { [weak self] course, error in
            self?.course = course
            detailError = error
            group.leave()
        }

        group.enter()
        CourseService.fetchReviews(courseId: courseId) { [weak self] reviews, _ in
            self?.reviews = reviews
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.hideLoading()
            if let detailError { self.showToast(detailError) }
            self.tableView.reloadData()
            self.refreshBottomBar()
        }
    }

    private func refreshBottomBar() {
        guard let course else { return }
        if let lessons = course.total_lessons, lessons > 0 {
            priceLabel.text = "\(course.priceText)/\(lessons)节"
        } else {
            priceLabel.text = course.priceText
        }
    }

    @objc private func didTapEnroll() {
        guard course != nil else { return }
        let vc = CourseEnrollViewController(courseId: courseId)
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - Sections

extension CourseDetailViewController {

    enum Section {
        case cover
        case info
        case institution
        case intro
        case reviews
    }

    private var sections: [Section] {
        guard let course else { return [] }
        var result: [Section] = [.cover, .info]
        if course.studio != nil || teacherVisible { result.append(.institution) }
        if let intro = course.intro, !intro.isEmpty { result.append(.intro) }
        if !reviews.isEmpty { result.append(.reviews) }
        return result
    }

    private var teacherVisible: Bool {
        guard let name = course?.teacher?.real_name, !name.isEmpty else { return false }
        return true
    }
}

// MARK: - UITableViewDataSource / Delegate

extension CourseDetailViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section] == .reviews ? min(reviews.count, 2) : 1
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        sections[section] == .cover ? 12 : 24
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? { UIView() }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 0.01 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .cover:
            let cell = tableView.dequeueReusableCell(withIdentifier: CourseCoverCell.reuseID, for: indexPath) as! CourseCoverCell
            cell.configure(course: course)
            return cell
        case .info:
            let cell = tableView.dequeueReusableCell(withIdentifier: CourseDetailInfoCell.reuseID, for: indexPath) as! CourseDetailInfoCell
            cell.configure(course: course)
            return cell
        case .institution:
            let cell = tableView.dequeueReusableCell(withIdentifier: CourseDetailCardCell.reuseID, for: indexPath) as! CourseDetailCardCell
            cell.configureInstitution(course: course)
            return cell
        case .intro:
            let cell = tableView.dequeueReusableCell(withIdentifier: CourseIntroCell.reuseID, for: indexPath) as! CourseIntroCell
            cell.configure(course: course)
            return cell
        case .reviews:
            let cell = tableView.dequeueReusableCell(withIdentifier: CourseReviewCell.reuseID, for: indexPath) as! CourseReviewCell
            cell.configure(review: reviews[indexPath.row])
            return cell
        }
    }
}

// MARK: - 封面卡

final class CourseCoverCell: UITableViewCell {
    static let reuseID = "CourseCoverCell"

    private let coverView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        coverView.backgroundColor = Theme.Color.surfaceAlt
        coverView.contentMode = .scaleAspectFill
        coverView.clipsToBounds = true
        coverView.layer.cornerRadius = Theme.Radius.card
        contentView.addSubview(coverView)
        coverView.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview()
            $0.height.equalTo(coverView.snp.width).multipliedBy(0.78)
        }
    }

    func configure(course: CourseDetail?) {
        if let cover = course?.cover, let url = URL(string: cover) {
            coverView.kf.setImage(with: url, placeholder: UIImage(systemName: "photo.fill"))
        } else {
            coverView.image = UIImage(systemName: "photo.fill")
            coverView.tintColor = Theme.Color.muted
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 信息卡（标签行 / 标题 / 副标题）

final class CourseDetailInfoCell: UITableViewCell {
    static let reuseID = "CourseDetailInfoCell"

    private let cardView = UIView()
    private let tagStack = UIStackView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        cardView.backgroundColor = Theme.Color.surface
        cardView.layer.cornerRadius = Theme.Radius.card
        cardView.clipsToBounds = true
        contentView.addSubview(cardView)
        cardView.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }

        tagStack.axis = .horizontal
        tagStack.spacing = Theme.Spacing.s
        cardView.addSubview(tagStack)
        tagStack.snp.makeConstraints {
            $0.top.leading.equalToSuperview().inset(Theme.Spacing.l)
        }

        titleLabel.font = .appTitle(19)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 0
        cardView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(tagStack.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        subtitleLabel.font = .appBody(13)
        subtitleLabel.textColor = Theme.Color.sub
        subtitleLabel.numberOfLines = 0
        cardView.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    func configure(course: CourseDetail?) {
        guard let course else { return }
        tagStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for text in course.tagTexts {
            tagStack.addArrangedSubview(makeTag(text))
        }
        titleLabel.text = course.title ?? "课程"
        subtitleLabel.text = course.subtitleText
    }

    private func makeTag(_ text: String) -> UIView {
        let view = UIView()
        view.backgroundColor = Theme.Color.brandSoft
        view.layer.cornerRadius = 10
        let label = UILabel()
        label.font = .appLabel(11)
        label.textColor = Theme.Color.brand
        label.text = text
        view.addSubview(label)
        label.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8))
        }
        return view
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 课程介绍

final class CourseIntroCell: UITableViewCell {
    static let reuseID = "CourseIntroCell"

    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let introLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        cardView.backgroundColor = Theme.Color.surface
        cardView.layer.cornerRadius = Theme.Radius.card
        cardView.clipsToBounds = true
        contentView.addSubview(cardView)
        cardView.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }

        titleLabel.font = .appTitle(15)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.text = "课程介绍"
        cardView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        introLabel.font = .appBody(14)
        introLabel.textColor = Theme.Color.sub
        introLabel.numberOfLines = 0
        cardView.addSubview(introLabel)
        introLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    func configure(course: CourseDetail?) {
        introLabel.text = course?.intro
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 家长评价

final class CourseReviewCell: UITableViewCell {
    static let reuseID = "CourseReviewCell"

    private let cardView = UIView()
    private let headerStack = UIStackView()
    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let timeLabel = UILabel()
    private let contentLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        cardView.backgroundColor = Theme.Color.surface
        cardView.layer.cornerRadius = Theme.Radius.card
        cardView.clipsToBounds = true
        contentView.addSubview(cardView)
        cardView.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }

        avatarView.backgroundColor = Theme.Color.surfaceAlt
        avatarView.layer.cornerRadius = 16
        avatarView.clipsToBounds = true
        avatarView.contentMode = .scaleAspectFill
        cardView.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.top.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.width.height.equalTo(32)
        }

        nameLabel.font = .appBody(14)
        nameLabel.textColor = Theme.Color.ink
        cardView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarView.snp.trailing).offset(Theme.Spacing.s)
            $0.centerY.equalTo(avatarView).offset(-8)
        }

        timeLabel.font = .appLabel(11)
        timeLabel.textColor = Theme.Color.muted
        cardView.addSubview(timeLabel)
        timeLabel.snp.makeConstraints {
            $0.leading.equalTo(nameLabel)
            $0.centerY.equalTo(avatarView).offset(8)
        }

        contentLabel.font = .appBody(14)
        contentLabel.textColor = Theme.Color.ink
        contentLabel.numberOfLines = 0
        cardView.addSubview(contentLabel)
        contentLabel.snp.makeConstraints {
            $0.top.equalTo(avatarView.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    func configure(review: CourseReviewItem) {
        nameLabel.text = review.authorName
        timeLabel.text = review.timeText
        contentLabel.text = review.content
        if let avatar = review.avatar, let url = URL(string: avatar) {
            avatarView.kf.setImage(with: url, placeholder: UIImage(systemName: "person.fill"))
        } else {
            avatarView.image = UIImage(systemName: "person.fill")
            avatarView.tintColor = Theme.Color.muted
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 机构与老师卡

final class CourseDetailCardCell: UITableViewCell {
    static let reuseID = "CourseDetailCardCell"

    private let cardView = UIView()
    private let stackView = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        cardView.backgroundColor = Theme.Color.surface
        cardView.layer.cornerRadius = Theme.Radius.card
        cardView.clipsToBounds = true
        contentView.addSubview(cardView)
        cardView.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }

        stackView.axis = .vertical
        stackView.spacing = 0
        cardView.addSubview(stackView)
        stackView.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(Theme.Spacing.m)
        }
    }

    func configureInstitution(course: CourseDetail?) {
        clearStack()
        if let studio = course?.studio {
            var subtitleParts: [String] = []
            if let rating = course?.rating, rating > 0 { subtitleParts.append("评分 \(String(format: "%.1f", rating))") }
            if let sales = course?.sales, sales > 0 { subtitleParts.append("\(sales) 人学过") }
            if let address = studio.address, !address.isEmpty { subtitleParts.append(address) }
            let row = makeRow(
                icon: "building.2.fill",
                title: studio.name ?? "未知机构",
                subtitle: subtitleParts.isEmpty ? nil : subtitleParts.joined(separator: " · ")
            )
            stackView.addArrangedSubview(row)
        }
        if let teacher = course?.teacher, let name = teacher.real_name, !name.isEmpty {
            let subtitle = teacher.intro?.isEmpty == false ? teacher.intro : (teacher.rating ?? 0 > 0 ? String(format: "评分 %.1f", teacher.rating!) : nil)
            let row = makeRow(
                icon: "person.fill",
                title: name,
                subtitle: subtitle
            )
            stackView.addArrangedSubview(row)
        }
    }

    private func clearStack() {
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    private func makeRow(icon: String?, title: String, subtitle: String?) -> UIView {
        let row = UIView()
        row.snp.makeConstraints { $0.height.equalTo(62) }

        let iconView = UIImageView()
        iconView.image = icon.flatMap { UIImage(systemName: $0) }
        iconView.tintColor = Theme.Color.brand
        iconView.contentMode = .scaleAspectFit
        row.addSubview(iconView)
        iconView.snp.makeConstraints {
            $0.leading.centerY.equalToSuperview()
            $0.width.height.equalTo(20)
        }

        let titleLabel = UILabel()
        titleLabel.font = .appBody(15)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 1
        row.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(iconView.snp.trailing).offset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
        }

        let subtitleLabel = UILabel()
        subtitleLabel.font = .appLabel(12)
        subtitleLabel.textColor = Theme.Color.muted
        subtitleLabel.numberOfLines = 1
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        row.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints {
            $0.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(Theme.Spacing.m)
            $0.trailing.centerY.equalToSuperview()
        }

        titleLabel.text = title
        subtitleLabel.text = subtitle
        return row
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
