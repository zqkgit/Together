import UIKit
import SnapKit
import Kingfisher

/// 课程详情（对齐 PR 设计图 #courseDetail）
/// 结构：封面 → 标签行/标题/副标题 → 机构卡 → 课程介绍 → 家长评价 → 底部「¥xx / N节 + 立即报名」
final class CourseDetailViewController: BaseViewController {

    private let courseId: String
    private var course: CourseDetail?
    private var reviews: [CourseReviewItem] = []
    private var reviewSummary: CourseReviewSummary?

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
        tableView.estimatedRowHeight = 60
        tableView.estimatedSectionHeaderHeight = 0
        tableView.estimatedSectionFooterHeight = 0
        tableView.rowHeight = UITableView.automaticDimension
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(CourseCoverCell.self, forCellReuseIdentifier: CourseCoverCell.reuseID)
        tableView.register(CourseDetailInfoCell.self, forCellReuseIdentifier: CourseDetailInfoCell.reuseID)
        tableView.register(CourseDetailCardCell.self, forCellReuseIdentifier: CourseDetailCardCell.reuseID)
        tableView.register(CourseIntroCell.self, forCellReuseIdentifier: CourseIntroCell.reuseID)
        tableView.register(CourseLessonsCell.self, forCellReuseIdentifier: CourseLessonsCell.reuseID)
        tableView.register(CourseReviewCell.self, forCellReuseIdentifier: CourseReviewCell.reuseID)

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

        priceLabel.font = .appTitle(18)
        priceLabel.textColor = Theme.Color.clay
        bottomBar.addSubview(enrollButton)
        bottomBar.addSubview(priceLabel)
        priceLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalTo(enrollButton.snp.centerY)
        }

        enrollButton.setTitle("立即报名", for: .normal)
        enrollButton.setTitleColor(.white, for: .normal)
        enrollButton.titleLabel?.font = .appLabel(16)
        enrollButton.backgroundColor = Theme.Color.brand
        enrollButton.addTarget(self, action: #selector(didTapEnroll), for: .touchUpInside)
        enrollButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.top.equalToSuperview().inset(10)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(10)
            $0.width.equalTo(140)
            $0.height.equalTo(46)
        }
        // 半圆：圆角 = 高度一半
        enrollButton.layer.cornerRadius = 23
        enrollButton.clipsToBounds = true
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
        CourseService.fetchReviews(courseId: courseId) { [weak self] reviews, summary, _ in
            self?.reviews = reviews
            self?.reviewSummary = summary
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
        case lessons
        case reviews
    }

    private var sections: [Section] {
        guard let course else { return [] }
        var result: [Section] = [.cover, .info]
        if course.studio != nil || teacherVisible { result.append(.institution) }
        if let intro = course.intro, !intro.isEmpty { result.append(.intro) }
        if course.lessonTitles != nil { result.append(.lessons) }
        result.append(.reviews)
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
        guard sections[section] == .reviews else { return 1 }
        if reviews.isEmpty { return 1 }
        return min(reviews.count, 2) + (reviews.count > 2 ? 1 : 0)
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch sections[section] {
        case .cover: return 12
        case .reviews:
            return (reviewSummary?.total ?? 0) > 0 ? 150 : 48
        default: return 12
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard sections[section] == .reviews else { return UIView() }
        let header = CourseReviewHeaderView()
        header.configure(summary: reviewSummary)
        header.onWrite = { [weak self] in self?.openReviewCompose() }
        return header
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 0.01 }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { UIView() }

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
        case .lessons:
            let cell = tableView.dequeueReusableCell(withIdentifier: CourseLessonsCell.reuseID, for: indexPath) as! CourseLessonsCell
            cell.configure(titles: course?.lessonTitles ?? [])
            return cell
        case .reviews:
            if reviews.isEmpty {
                let cell = UITableViewCell(style: .default, reuseIdentifier: "reviewEmpty")
                cell.selectionStyle = .none
                cell.backgroundColor = .clear
                cell.textLabel?.text = "暂无评价，快来写下第一条吧"
                cell.textLabel?.textColor = Theme.Color.muted
                cell.textLabel?.font = .appBody(14)
                cell.textLabel?.textAlignment = .center
                return cell
            }
            if indexPath.row < min(reviews.count, 2) {
                let cell = tableView.dequeueReusableCell(withIdentifier: CourseReviewCell.reuseID, for: indexPath) as! CourseReviewCell
                cell.configure(review: reviews[indexPath.row])
                return cell
            }
            let cell = UITableViewCell(style: .default, reuseIdentifier: "reviewMore")
            cell.selectionStyle = .none
            cell.backgroundColor = .clear
            cell.textLabel?.text = "查看全部 \(reviews.count) 条评价 ›"
            cell.textLabel?.textColor = Theme.Color.sub
            cell.textLabel?.font = .appBody(14)
            cell.textLabel?.textAlignment = .center
            return cell
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard sections[indexPath.section] == .reviews,
              indexPath.row >= min(reviews.count, 2) else { return }
        let vc = CourseReviewsViewController(courseId: courseId)
        navigationController?.pushViewController(vc, animated: true)
    }

    private func openReviewCompose() {
        guard TokenManager.shared.isLoggedIn else {
            showToast("请先登录")
            return
        }
        let title = course?.title ?? ""
        let vc = ReviewComposeViewController(courseId: courseId, courseTitle: title)
        navigationController?.pushViewController(vc, animated: true)
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
            $0.top.bottom.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.height.equalTo(coverView.snp.width).multipliedBy(0.78).priority(.high)
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

    override func layoutSubviews() {
        super.layoutSubviews()
        introLabel.preferredMaxLayoutWidth = bounds.width - 16 * 2 - 16 * 2
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 课时安排

final class CourseLessonsCell: UITableViewCell {
    static let reuseID = "CourseLessonsCell"

    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let stack = UIStackView()

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
        titleLabel.text = "课时安排"
        cardView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        stack.axis = .vertical
        stack.spacing = 8
        cardView.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    func configure(titles: [String]) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for text in titles {
            let row = UIView()
            let dot = UIView()
            dot.backgroundColor = Theme.Color.brand
            dot.layer.cornerRadius = 3
            row.addSubview(dot)
            dot.snp.makeConstraints {
                $0.leading.equalToSuperview()
                $0.centerY.equalToSuperview()
                $0.width.height.equalTo(6)
            }

            let label = UILabel()
            label.font = .appBody(14)
            label.textColor = Theme.Color.sub
            label.numberOfLines = 0
            row.addSubview(label)
            label.snp.makeConstraints {
                $0.leading.equalTo(dot.snp.trailing).offset(8)
                $0.top.trailing.bottom.equalToSuperview()
            }
            label.text = text
            stack.addArrangedSubview(row)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 家长评价

final class CourseReviewCell: UITableViewCell {
    static let reuseID = "CourseReviewCell"

    private let cardView = UIView()
    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let timeLabel = UILabel()
    private let bodyStack = UIStackView()
    private let contentLabel = UILabel()
    private let studioReplyView = ReviewReplyView(tag: "工作室", tagColor: Theme.Color.info, tintColor: Theme.Color.infoTint)
    private let teacherReplyView = ReviewReplyView(tag: "老师", tagColor: Theme.Color.violet, tintColor: Theme.Color.violetTint)

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
            $0.top.equalTo(avatarView)
        }

        timeLabel.font = .appLabel(11)
        timeLabel.textColor = Theme.Color.muted
        cardView.addSubview(timeLabel)
        timeLabel.snp.makeConstraints {
            $0.leading.equalTo(nameLabel)
            $0.bottom.equalTo(avatarView)
        }

        contentLabel.font = .appBody(14)
        contentLabel.textColor = Theme.Color.ink
        contentLabel.numberOfLines = 0
        bodyStack.axis = .vertical
        bodyStack.spacing = 8
        bodyStack.addArrangedSubview(contentLabel)
        bodyStack.addArrangedSubview(studioReplyView)
        bodyStack.addArrangedSubview(teacherReplyView)
        cardView.addSubview(bodyStack)
        bodyStack.snp.makeConstraints {
            $0.top.equalTo(avatarView.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentLabel.preferredMaxLayoutWidth = bounds.width - 16 * 2 - 16 * 2 - 32 - 8
    }

    func configure(review: CourseReviewItem) {
        nameLabel.text = review.authorName
        timeLabel.text = review.timeText
        contentLabel.text = review.content
        studioReplyView.isHidden = (review.reply_content ?? "").isEmpty
        studioReplyView.set(text: review.reply_content)
        teacherReplyView.isHidden = (review.teacher_reply_content ?? "").isEmpty
        teacherReplyView.set(text: review.teacher_reply_content)
        if let avatar = review.avatar, let url = URL(string: avatar) {
            avatarView.kf.setImage(with: url, placeholder: UIImage(systemName: "person.fill"))
        } else {
            avatarView.image = UIImage(systemName: "person.fill")
            avatarView.tintColor = Theme.Color.muted
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// 评价回复条（工作室蓝 / 老师紫）
final class ReviewReplyView: UIView {

    private let tagLabel = UILabel()
    private let textLabel = UILabel()

    init(tag: String, tagColor: UIColor, tintColor: UIColor) {
        super.init(frame: .zero)
        backgroundColor = tintColor
        layer.cornerRadius = 6
        clipsToBounds = true

        tagLabel.text = tag
        tagLabel.font = .appLabel(10)
        tagLabel.textColor = tagColor
        tagLabel.textAlignment = .center
        addSubview(tagLabel)
        tagLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(8)
            $0.centerY.equalToSuperview()
            $0.width.equalTo(34)
        }

        textLabel.font = .appLabel(12)
        textLabel.textColor = Theme.Color.sub
        textLabel.numberOfLines = 0
        addSubview(textLabel)
        textLabel.snp.makeConstraints {
            $0.leading.equalTo(tagLabel.snp.trailing).offset(6)
            $0.trailing.equalToSuperview().offset(-8)
            $0.top.equalToSuperview().offset(6)
            $0.bottom.equalToSuperview().offset(-6)
        }
    }

    func set(text: String?) {
        textLabel.text = text
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

        let iconView = UIImageView()
        iconView.image = icon.flatMap { UIImage(systemName: $0) }
        iconView.tintColor = Theme.Color.brand
        iconView.contentMode = .scaleAspectFit
        row.addSubview(iconView)
        iconView.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.top.equalToSuperview().offset(21)
            $0.bottom.equalToSuperview().inset(21)
            $0.width.height.equalTo(20)
        }

        let titleLabel = UILabel()
        titleLabel.font = .appBody(15)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 1
        row.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(iconView.snp.trailing).offset(Theme.Spacing.m)
            $0.centerY.equalTo(iconView)
        }

        let subtitleLabel = UILabel()
        subtitleLabel.font = .appLabel(12)
        subtitleLabel.textColor = Theme.Color.muted
        subtitleLabel.numberOfLines = 1
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        row.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints {
            $0.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(Theme.Spacing.m)
            $0.trailing.equalToSuperview()
            $0.centerY.equalTo(iconView)
        }

        titleLabel.text = title
        subtitleLabel.text = subtitle
        return row
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}


/// 家长评价区头部：标题 + 写评价 + 评分分布条（对齐小程序课程详情）
final class CourseReviewHeaderView: UIView {

    var onWrite: (() -> Void)?

    private let titleLabel = UILabel()
    private let countLabel = UILabel()
    private let writeButton = UIButton(type: .system)
    private let distStack = UIStackView()
    private var fillViews: [Int: UIView] = [:]
    private var numLabels: [Int: UILabel] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        titleLabel.text = "家长评价"
        titleLabel.font = .appTitle(16)
        titleLabel.textColor = Theme.Color.ink
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.equalToSuperview().inset(Theme.Spacing.m)
        }

        countLabel.font = .appLabel(12)
        countLabel.textColor = Theme.Color.muted
        addSubview(countLabel)
        countLabel.snp.makeConstraints {
            $0.leading.equalTo(titleLabel.snp.trailing).offset(Theme.Spacing.s)
            $0.bottom.equalTo(titleLabel).offset(-2)
        }

        writeButton.setTitle("写评价", for: .normal)
        writeButton.setTitleColor(Theme.Color.brand, for: .normal)
        writeButton.titleLabel?.font = .appLabel(13)
        writeButton.backgroundColor = Theme.Color.brandSoft
        writeButton.layer.cornerRadius = 6
        writeButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        writeButton.addTarget(self, action: #selector(didTapWrite), for: .touchUpInside)
        addSubview(writeButton)
        writeButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.centerY.equalTo(titleLabel)
        }

        distStack.axis = .vertical
        distStack.spacing = 4
        addSubview(distStack)
        distStack.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }

        for star in stride(from: 5, through: 1, by: -1) {
            let row = makeDistRow(star: star)
            distStack.addArrangedSubview(row)
        }
    }

    private func makeDistRow(star: Int) -> UIView {
        let row = UIView()
        row.snp.makeConstraints { $0.height.equalTo(14) }

        let label = UILabel()
        label.text = "\(star)★"
        label.font = .appLabel(10)
        label.textColor = Theme.Color.muted
        row.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.centerY.equalToSuperview()
            $0.width.equalTo(26)
        }

        let track = UIView()
        track.backgroundColor = Theme.Color.surfaceAlt
        track.layer.cornerRadius = 3
        track.clipsToBounds = true
        row.addSubview(track)
        track.snp.makeConstraints {
            $0.leading.equalTo(label.snp.trailing).offset(4)
            $0.centerY.equalToSuperview()
            $0.height.equalTo(6)
            $0.trailing.equalToSuperview().offset(-30)
        }

        let fill = UIView()
        fill.backgroundColor = Theme.Color.clay
        fill.layer.cornerRadius = 3
        track.addSubview(fill)
        fill.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
            $0.width.equalTo(0)
        }
        fill.tag = star
        fillViews[star] = fill

        let numLabel = UILabel()
        numLabel.font = .appLabel(10)
        numLabel.textColor = Theme.Color.muted
        row.addSubview(numLabel)
        numLabel.snp.makeConstraints {
            $0.leading.equalTo(track.snp.trailing).offset(4)
            $0.centerY.equalToSuperview()
            $0.trailing.lessThanOrEqualToSuperview()
        }
        numLabels[star] = numLabel
        return row
    }

    func configure(summary: CourseReviewSummary?) {
        let total = summary?.total ?? 0
        countLabel.text = "\(total) 条"
        distStack.isHidden = total <= 0
        for star in 1...5 {
            let count = summary?.count(of: star) ?? 0
            let ratio = total > 0 ? CGFloat(count) / CGFloat(total) : 0
            if let fill = fillViews[star] {
                fill.snp.remakeConstraints {
                    $0.leading.top.bottom.equalToSuperview()
                    $0.width.equalTo(fill.superview!.snp.width).multipliedBy(ratio)
                }
            }
            numLabels[star]?.text = "\(count)"
        }
    }

    @objc private func didTapWrite() {
        onWrite?()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
