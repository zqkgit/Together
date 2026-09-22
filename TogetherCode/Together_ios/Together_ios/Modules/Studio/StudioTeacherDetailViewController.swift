import UIKit
import SnapKit
import Kingfisher

/// 工作室 App 端 · 老师详情
///
/// 四块内容：老师档案（认证 / 评分 / 擅长 / 教龄 / 手机号 / 加入时间）、经营统计、
/// 本工作室带课课程、最近消课流水；底部可解除合作
/// 数据来源 GET /v1/studio/teachers/:id
final class StudioTeacherDetailViewController: BaseViewController {

    private let teacherId: String
    private let name: String

    /// 解除合作成功后回调列表页刷新
    var onReleased: (() -> Void)?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let emptyView = EmptyStateView()

    init(teacherId: String, name: String) {
        self.teacherId = teacherId
        self.name = name
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: name)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    // MARK: - 布局

    private func setupUI() {
        view.backgroundColor = Theme.Color.bg

        contentStack.axis = .vertical
        contentStack.spacing = Theme.Spacing.l
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.bottom.equalToSuperview()
        }
        scrollView.addSubview(contentStack)
        contentStack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.xl)
            $0.width.equalTo(scrollView).offset(-Theme.Spacing.l * 2)
        }

        emptyView.show(style: .loading)
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview()
            $0.width.equalToSuperview()
        }
    }

    // MARK: - 数据

    private func loadData() {
        emptyView.isHidden = false
        emptyView.show(style: .loading)
        StudioService.fetchTeacherDetail(teacherId: teacherId) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let detail):
                self.render(detail)
            case .failure(let error):
                self.clearContent()
                self.emptyView.show(style: .error(error.message ?? "加载失败") { [weak self] in
                    self?.loadData()
                })
            }
        }
    }

    private func clearContent() {
        contentStack.arrangedSubviews.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }

    private func render(_ detail: StudioTeacherDetail) {
        guard let teacher = detail.teacher else {
            clearContent()
            emptyView.show(style: .empty("老师信息不存在"))
            return
        }
        emptyView.isHidden = true
        clearContent()

        contentStack.addArrangedSubview(makeProfileCard(teacher))
        contentStack.addArrangedSubview(makeStatsCard(teacher))

        let courses = detail.courses ?? []
        if !courses.isEmpty {
            contentStack.addArrangedSubview(makeSectionTitle("本工作室带课"))
            contentStack.addArrangedSubview(makeCourseCard(courses))
        }

        contentStack.addArrangedSubview(makeSectionTitle("最近消课流水"))
        contentStack.addArrangedSubview(makeLogCard(detail.logs ?? []))

        let releaseButton = makeReleaseButton()
        contentStack.addArrangedSubview(releaseButton)
    }

    // MARK: - 档案卡

    private func makeProfileCard(_ teacher: StudioTeacherItem) -> UIView {
        let card = makeCard()
        let avatarView = UIImageView()
        avatarView.layer.cornerRadius = 32
        avatarView.clipsToBounds = true
        avatarView.contentMode = .scaleAspectFill
        avatarView.backgroundColor = Theme.Color.surfaceAlt
        if let urlString = teacher.avatar, let url = URL(string: urlString), !urlString.isEmpty {
            avatarView.kf.setImage(with: url)
        } else {
            avatarView.backgroundColor = Style.avatarTint(teacher.teacher_id)
        }
        card.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.width.height.equalTo(64)
        }

        let nameLabel = UILabel()
        nameLabel.text = teacher.displayName
        nameLabel.font = .appTitle(20)
        nameLabel.textColor = Theme.Color.ink
        nameLabel.numberOfLines = 1
        card.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarView.snp.trailing).offset(Theme.Spacing.m)
            $0.top.equalTo(avatarView).offset(4)
            $0.trailing.lessThanOrEqualToSuperview().offset(-Theme.Spacing.l)
        }

        // 认证 + 评分
        let tagStack = UIStackView()
        tagStack.axis = .horizontal
        tagStack.spacing = 6
        tagStack.alignment = .center
        tagStack.addArrangedSubview(makeTag(
            teacher.isCertified ? "已认证" : "未认证",
            textColor: teacher.isCertified ? Theme.Color.brand : Theme.Color.muted,
            background: teacher.isCertified ? Theme.Color.brandSoft : Theme.Color.surfaceAlt
        ))
        tagStack.addArrangedSubview(makeTag(
            "评分 \(teacher.ratingText)",
            textColor: Theme.Color.wood,
            background: Theme.Color.surfaceAlt
        ))
        card.addSubview(tagStack)
        tagStack.snp.makeConstraints {
            $0.leading.equalTo(nameLabel)
            $0.top.equalTo(nameLabel.snp.bottom).offset(8)
        }

        let subjectsLabel = UILabel()
        subjectsLabel.text = teacher.subjectsText
        subjectsLabel.font = .appLabel(12)
        subjectsLabel.textColor = Theme.Color.muted
        subjectsLabel.numberOfLines = 2
        card.addSubview(subjectsLabel)
        subjectsLabel.snp.makeConstraints {
            $0.leading.equalTo(nameLabel)
            $0.top.equalTo(tagStack.snp.bottom).offset(8)
            $0.trailing.lessThanOrEqualToSuperview().offset(-Theme.Spacing.l)
            $0.bottom.lessThanOrEqualTo(avatarView.snp.bottom)
        }

        // 资料行
        let rows = UIStackView()
        rows.axis = .vertical
        rows.spacing = 0
        card.addSubview(rows)
        rows.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalTo(avatarView.snp.bottom).offset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.s)
        }

        let infoRows: [(String, String)] = [
            ("教龄", teacher.yearsText),
            ("手机号", teacher.phone ?? "—"),
            ("加入时间", teacher.joinedText),
            ("证书编号", (teacher.cert_no?.isEmpty == false) ? teacher.cert_no! : "—")
        ]
        for (index, item) in infoRows.enumerated() {
            if index > 0 {
                let divider = makeDivider()
                rows.addArrangedSubview(divider)
                divider.snp.makeConstraints { $0.height.equalTo(1) }
            }
            rows.addArrangedSubview(makeInfoRow(title: item.0, value: item.1))
        }

        let intro = (teacher.intro ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !intro.isEmpty {
            let divider = makeDivider()
            rows.addArrangedSubview(divider)
            divider.snp.makeConstraints { $0.height.equalTo(1) }
            rows.setCustomSpacing(Theme.Spacing.m, after: divider)
            let introLabel = UILabel()
            introLabel.text = intro
            introLabel.font = .appBody(13)
            introLabel.textColor = Theme.Color.sub
            introLabel.numberOfLines = 0
            rows.addArrangedSubview(introLabel)
            rows.setCustomSpacing(Theme.Spacing.m, after: introLabel)
        }

        return card
    }

    // MARK: - 统计卡

    private func makeStatsCard(_ teacher: StudioTeacherItem) -> UIView {
        let card = makeCard()
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        card.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(Theme.Spacing.l) }

        let stats: [(String, String)] = [
            ("\(teacher.student_count ?? 0)", "在读学员"),
            ("\(teacher.month_lessons ?? 0)", "本月消课"),
            ("\(teacher.course_count ?? 0)", "带课")
        ]
        for (index, item) in stats.enumerated() {
            if index > 0 {
                let divider = makeDivider()
                stack.addArrangedSubview(divider)
                divider.snp.makeConstraints { $0.width.equalTo(1) }
            }
            let column = UIView()
            let valueLabel = UILabel()
            valueLabel.text = item.0
            valueLabel.font = .appTitle(22)
            valueLabel.textColor = Theme.Color.brandDark
            valueLabel.textAlignment = .center
            column.addSubview(valueLabel)
            valueLabel.snp.makeConstraints {
                $0.top.leading.trailing.equalToSuperview()
            }
            let captionLabel = UILabel()
            captionLabel.text = item.1
            captionLabel.font = .appLabel(11)
            captionLabel.textColor = Theme.Color.muted
            captionLabel.textAlignment = .center
            column.addSubview(captionLabel)
            captionLabel.snp.makeConstraints {
                $0.top.equalTo(valueLabel.snp.bottom).offset(2)
                $0.leading.trailing.bottom.equalToSuperview()
            }
            stack.addArrangedSubview(column)
        }
        return card
    }

    // MARK: - 带课课程

    private func makeCourseCard(_ courses: [StudioTeacherCourse]) -> UIView {
        let card = makeCard()
        let rows = UIStackView()
        rows.axis = .vertical
        rows.spacing = 0
        card.addSubview(rows)
        rows.snp.makeConstraints { $0.edges.equalToSuperview().inset(Theme.Spacing.l) }

        for (index, course) in courses.enumerated() {
            if index > 0 {
                let divider = makeDivider()
                rows.addArrangedSubview(divider)
                divider.snp.makeConstraints { $0.height.equalTo(1) }
                rows.setCustomSpacing(Theme.Spacing.m, after: divider)
            }

            let row = UIView()
            let titleLabel = UILabel()
            titleLabel.text = course.titleText
            titleLabel.font = .appBody(14)
            titleLabel.textColor = Theme.Color.ink
            titleLabel.numberOfLines = 1
            row.addSubview(titleLabel)
            titleLabel.snp.makeConstraints {
                $0.leading.top.equalToSuperview()
                $0.trailing.lessThanOrEqualToSuperview().inset(64)
            }

            let detailLabel = UILabel()
            detailLabel.text = course.detailText
            detailLabel.font = .appLabel(12)
            detailLabel.textColor = Theme.Color.muted
            row.addSubview(detailLabel)
            detailLabel.snp.makeConstraints {
                $0.leading.equalTo(titleLabel)
                $0.top.equalTo(titleLabel.snp.bottom).offset(4)
                $0.bottom.equalToSuperview()
            }

            let statusLabel = makeTag(
                course.statusText,
                textColor: course.isOnline ? Theme.Color.brand : Theme.Color.muted,
                background: course.isOnline ? Theme.Color.brandSoft : Theme.Color.surfaceAlt
            )
            row.addSubview(statusLabel)
            statusLabel.snp.makeConstraints {
                $0.trailing.equalToSuperview()
                $0.centerY.equalTo(titleLabel)
            }

            rows.addArrangedSubview(row)
            if index < courses.count - 1 {
                rows.setCustomSpacing(Theme.Spacing.m, after: row)
            }
        }
        return card
    }

    // MARK: - 消课流水

    private func makeLogCard(_ logs: [StudioTeacherLog]) -> UIView {
        let card = makeCard()
        let rows = UIStackView()
        rows.axis = .vertical
        rows.spacing = 0
        card.addSubview(rows)
        rows.snp.makeConstraints { $0.edges.equalToSuperview().inset(Theme.Spacing.l) }

        guard !logs.isEmpty else {
            let hint = UILabel()
            hint.text = "暂无消课记录"
            hint.font = .appBody(13)
            hint.textColor = Theme.Color.muted
            hint.textAlignment = .center
            rows.addArrangedSubview(hint)
            return card
        }

        for (index, log) in logs.enumerated() {
            if index > 0 {
                let divider = makeDivider()
                rows.addArrangedSubview(divider)
                divider.snp.makeConstraints { $0.height.equalTo(1) }
                rows.setCustomSpacing(10, after: divider)
            }
            rows.addArrangedSubview(makeLogRow(log))
            if index < logs.count - 1, let last = rows.arrangedSubviews.last {
                rows.setCustomSpacing(10, after: last)
            }
        }
        return card
    }

    private func makeLogRow(_ log: StudioTeacherLog) -> UIView {
        let row = UIView()

        let dateLabel = UILabel()
        dateLabel.text = log.dateText
        dateLabel.font = .appLabel(12)
        dateLabel.textColor = Theme.Color.muted
        dateLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        row.addSubview(dateLabel)
        dateLabel.snp.makeConstraints {
            $0.leading.top.equalToSuperview()
        }

        let titleLabel = UILabel()
        titleLabel.text = log.titleText
        titleLabel.font = .appBody(13)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 1
        row.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(dateLabel.snp.trailing).offset(Theme.Spacing.s)
            $0.top.equalTo(dateLabel)
            $0.trailing.lessThanOrEqualToSuperview().inset(72)
        }

        let detailLabel = UILabel()
        detailLabel.text = log.detailText
        detailLabel.font = .appLabel(11)
        detailLabel.textColor = Theme.Color.muted
        detailLabel.numberOfLines = 1
        row.addSubview(detailLabel)
        detailLabel.snp.makeConstraints {
            $0.leading.equalTo(titleLabel)
            $0.top.equalTo(titleLabel.snp.bottom).offset(3)
            $0.trailing.lessThanOrEqualToSuperview()
            $0.bottom.equalToSuperview()
        }

        let deltaLabel = UILabel()
        deltaLabel.text = log.deltaText
        deltaLabel.font = .appSection(14)
        deltaLabel.textColor = log.isIncrease ? Theme.Color.brand : Theme.Color.warn
        deltaLabel.textAlignment = .right
        deltaLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        row.addSubview(deltaLabel)
        deltaLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview()
            $0.centerY.equalTo(titleLabel)
        }

        return row
    }

    // MARK: - 解除合作

    private func makeReleaseButton() -> UIView {
        let button = UIButton(type: .system)
        button.setTitle("解除合作", for: .normal)
        button.titleLabel?.font = .appBody(15)
        button.setTitleColor(Theme.Color.danger, for: .normal)
        button.backgroundColor = Theme.Color.surface
        button.layer.cornerRadius = Theme.Radius.button
        button.addTarget(self, action: #selector(tapRelease), for: .touchUpInside)
        button.snp.makeConstraints { $0.height.equalTo(48) }
        return button
    }

    @objc private func tapRelease() {
        ThemeAlertView.show(
            title: "解除合作",
            message: "解除与「\(name)」的合作关系？\n解除后该老师不再出现在本工作室在职列表，其档案与其他工作室的绑定不受影响。",
            confirmTitle: "确认解除",
            cancelTitle: "取消",
            onConfirm: { [weak self] in
                self?.submitRelease()
            }
        )
    }

    private func submitRelease() {
        showLoading()
        StudioService.releaseTeacher(teacherId: teacherId) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success:
                self.showToast("已解除合作")
                self.onReleased?()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self.navigationController?.popViewController(animated: true)
                }
            case .failure(let error):
                self.showToast(error.message ?? "解除失败")
            }
        }
    }

    // MARK: - 通用小件

    private func makeSectionTitle(_ text: String) -> UIView {
        let wrap = UIView()
        let label = UILabel()
        label.text = text
        label.font = .appSection(15)
        label.textColor = Theme.Color.ink
        wrap.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.xs)
            $0.top.equalToSuperview().offset(Theme.Spacing.s)
            $0.bottom.trailing.equalToSuperview()
        }
        return wrap
    }

    private func makeCard() -> UIView {
        let card = UIView()
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        card.layer.shadowColor = UIColor(hex: 0x2B2621).cgColor
        card.layer.shadowOpacity = 0.04
        card.layer.shadowRadius = 10
        card.layer.shadowOffset = CGSize(width: 0, height: 3)
        return card
    }

    private func makeDivider() -> UIView {
        let view = UIView()
        view.backgroundColor = Theme.Color.line
        return view
    }

    private func makeTag(_ text: String, textColor: UIColor, background: UIColor) -> UIView {
        let label = TagLabel()
        label.text = text
        label.font = .appLabel(11)
        label.textColor = textColor
        label.textAlignment = .center
        label.backgroundColor = background
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.snp.makeConstraints { $0.height.equalTo(22) }
        return label
    }

    private func makeInfoRow(title: String, value: String) -> UIView {
        let row = UIView()
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .appLabel(13)
        titleLabel.textColor = Theme.Color.muted
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        row.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
            $0.centerY.equalToSuperview()
        }

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = .appBody(14)
        valueLabel.textColor = Theme.Color.ink
        valueLabel.textAlignment = .right
        valueLabel.numberOfLines = 1
        row.addSubview(valueLabel)
        valueLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview()
            $0.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(Theme.Spacing.s)
            $0.top.bottom.equalToSuperview().inset(9)
        }
        return row
    }

    private enum Style {
        static func avatarTint(_ id: String) -> UIColor {
            let palette: [UInt32] = [0x7DABC2, 0x8BB270, 0xD4B269, 0xBA96C8, 0xBB96B2, 0x8FBFB0]
            var hash = 0
            for u in id.unicodeScalars { hash = (hash &* 31) &+ Int(u.value) }
            return UIColor(hex: palette[abs(hash) % palette.count])
        }
    }
}

/// 带左右内边距的小标签（认证 / 评分 / 课程状态）
private final class TagLabel: UILabel {

    private let insets = UIEdgeInsets(top: 0, left: 9, bottom: 0, right: 9)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + insets.left + insets.right, height: size.height)
    }
}
