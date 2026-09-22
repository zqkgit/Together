import UIKit
import SnapKit
import Kingfisher

/// 工作室 App 端 · 学员详情
///
/// 三块内容：学员信息（家长 / 电话 / 报名 / 课时合计）、课程课时（每门课剩余与消耗）、课时流水
/// 数据来源 GET /v1/studio/students/:id，与 Web 后台学员详情抽屉同源
final class StudioStudentDetailViewController: BaseViewController {

    private let childId: String
    private let nickname: String

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let emptyView = EmptyStateView()

    init(childId: String, nickname: String) {
        self.childId = childId
        self.nickname = nickname
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
        configureImmersiveNav(title: "学员详情")
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

        emptyView.isHidden = false
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
        StudioService.fetchStudentDetail(childId: childId) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let detail):
                self.render(detail)
            case .failure(let error):
                self.contentStack.arrangedSubviews.forEach {
                    self.contentStack.removeArrangedSubview($0)
                    $0.removeFromSuperview()
                }
                self.emptyView.show(style: .error(error.message ?? "加载失败") { [weak self] in
                    self?.loadData()
                })
            }
        }
    }

    private func render(_ detail: StudioStudentDetail) {
        emptyView.isHidden = true
        contentStack.arrangedSubviews.forEach {
            contentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        if let student = detail.student {
            contentStack.addArrangedSubview(makeInfoCard(student))
        }

        let balances = detail.balances ?? []
        if !balances.isEmpty {
            contentStack.addArrangedSubview(makeSectionTitle("课程课时"))
            contentStack.addArrangedSubview(makeCourseCard(balances))
        }

        let logs = detail.logs ?? []
        contentStack.addArrangedSubview(makeSectionTitle("课时流水"))
        contentStack.addArrangedSubview(makeLogCard(logs))
    }

    // MARK: - 学员信息

    private func makeInfoCard(_ student: StudioStudentItem) -> UIView {
        let card = makeCard()

        let avatar = UIImageView()
        avatar.layer.cornerRadius = 26
        avatar.clipsToBounds = true
        avatar.contentMode = .scaleAspectFill
        avatar.backgroundColor = Style.avatarTint(student.child_id)
        if let urlString = student.avatar, let url = URL(string: urlString), !urlString.isEmpty {
            avatar.kf.setImage(with: url)
        }
        card.addSubview(avatar)
        avatar.snp.makeConstraints {
            $0.leading.top.equalToSuperview().inset(Theme.Spacing.l)
            $0.width.height.equalTo(52)
        }

        let nameLabel = UILabel()
        nameLabel.text = student.displayName
        nameLabel.font = .appSection(17)
        nameLabel.textColor = Theme.Color.ink
        card.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatar.snp.trailing).offset(Theme.Spacing.m)
            $0.top.equalTo(avatar).offset(2)
        }

        let metaLabel = UILabel()
        let genderText = student.genderText
        let ageText = student.age.map { "\($0) 岁" } ?? "年龄未填"
        metaLabel.text = "\(ageText) · \(genderText)"
        metaLabel.font = .appLabel(12)
        metaLabel.textColor = Theme.Color.muted
        card.addSubview(metaLabel)
        metaLabel.snp.makeConstraints {
            $0.leading.equalTo(nameLabel)
            $0.top.equalTo(nameLabel.snp.bottom).offset(4)
        }

        // 剩余课时（右侧）
        let remainingValue = UILabel()
        remainingValue.text = "\(student.remaining) 节"
        remainingValue.font = .appSection(18)
        remainingValue.textColor = student.isRenew ? Theme.Color.warn : Theme.Color.brandDark
        remainingValue.textAlignment = .right
        card.addSubview(remainingValue)
        remainingValue.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalTo(avatar)
        }

        let caption = UILabel()
        caption.text = student.lessonsCaption
        caption.font = .appLabel(11)
        caption.textColor = student.isRenew ? Theme.Color.warn : Theme.Color.muted
        caption.textAlignment = .right
        card.addSubview(caption)
        caption.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalTo(remainingValue.snp.bottom).offset(2)
        }

        let divider = makeDivider()
        card.addSubview(divider)
        divider.snp.makeConstraints {
            $0.top.equalTo(avatar.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(1)
        }

        let rows = UIStackView()
        rows.axis = .vertical
        rows.spacing = 10
        rows.addArrangedSubview(makeInfoRow(label: "家长", value: student.parent_name ?? "—"))
        rows.addArrangedSubview(makeInfoRow(label: "联系电话", value: student.parent_phone ?? "—"))
        rows.addArrangedSubview(makeInfoRow(label: "报名时间", value: student.enrolledText))
        rows.addArrangedSubview(
            makeInfoRow(label: "课时合计", value: "共 \(student.total_lessons ?? 0) 节 · 已消耗 \(student.consumed_lessons ?? 0) 节")
        )
        card.addSubview(rows)
        rows.snp.makeConstraints {
            $0.top.equalTo(divider.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.l)
        }

        return card
    }

    private func makeInfoRow(label: String, value: String) -> UIView {
        let row = UIView()
        let labelView = UILabel()
        labelView.text = label
        labelView.font = .appLabel(13)
        labelView.textColor = Theme.Color.muted
        row.addSubview(labelView)
        labelView.snp.makeConstraints {
            $0.leading.centerY.equalToSuperview()
            $0.width.equalTo(64)
        }

        let valueView = UILabel()
        valueView.text = value.isEmpty ? "—" : value
        valueView.font = .appBody(13)
        valueView.textColor = Theme.Color.ink
        valueView.numberOfLines = 0
        row.addSubview(valueView)
        valueView.snp.makeConstraints {
            $0.leading.equalTo(labelView.snp.trailing).offset(Theme.Spacing.s)
            $0.trailing.centerY.equalToSuperview()
            $0.top.bottom.equalToSuperview()
        }

        return row
    }

    // MARK: - 课程课时

    private func makeCourseCard(_ balances: [StudioStudentBalance]) -> UIView {
        let card = makeCard()
        let rows = UIStackView()
        rows.axis = .vertical
        rows.spacing = Theme.Spacing.m
        card.addSubview(rows)
        rows.snp.makeConstraints { $0.edges.equalToSuperview().inset(Theme.Spacing.l) }

        for (index, balance) in balances.enumerated() {
            if index > 0 {
                let divider = makeDivider()
                rows.addArrangedSubview(divider)
                divider.snp.makeConstraints { $0.height.equalTo(1) }
            }
            rows.addArrangedSubview(makeCourseRow(balance))
        }

        return card
    }

    private func makeCourseRow(_ balance: StudioStudentBalance) -> UIView {
        let row = UIView()

        let titleLabel = UILabel()
        titleLabel.text = balance.titleText
        titleLabel.font = .appBody(14)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 1
        row.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.top.equalToSuperview()
            $0.trailing.lessThanOrEqualToSuperview().inset(84)
        }

        let detailLabel = UILabel()
        detailLabel.text = balance.detailText
        detailLabel.font = .appLabel(12)
        detailLabel.textColor = Theme.Color.muted
        row.addSubview(detailLabel)
        detailLabel.snp.makeConstraints {
            $0.leading.equalTo(titleLabel)
            $0.top.equalTo(titleLabel.snp.bottom).offset(4)
        }

        let validLabel = UILabel()
        validLabel.text = balance.validityText
        validLabel.font = .appLabel(11)
        validLabel.textColor = Theme.Color.muted
        row.addSubview(validLabel)
        validLabel.snp.makeConstraints {
            $0.leading.equalTo(titleLabel)
            $0.top.equalTo(detailLabel.snp.bottom).offset(2)
            $0.bottom.equalToSuperview()
        }

        let remaining = balance.remaining_lessons ?? 0
        let remainingLabel = UILabel()
        remainingLabel.text = balance.remainingText
        remainingLabel.font = .appSection(17)
        remainingLabel.textColor = remaining <= 3 ? Theme.Color.warn : Theme.Color.brandDark
        remainingLabel.textAlignment = .right
        row.addSubview(remainingLabel)
        remainingLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview()
            $0.centerY.equalTo(row).offset(-6)
        }

        let remainingCaption = UILabel()
        remainingCaption.text = "剩余课时"
        remainingCaption.font = .appLabel(11)
        remainingCaption.textColor = Theme.Color.muted
        remainingCaption.textAlignment = .right
        row.addSubview(remainingCaption)
        remainingCaption.snp.makeConstraints {
            $0.trailing.equalToSuperview()
            $0.top.equalTo(remainingLabel.snp.bottom).offset(2)
        }

        return row
    }

    // MARK: - 课时流水

    private func makeLogCard(_ logs: [StudioStudentLog]) -> UIView {
        let card = makeCard()
        let rows = UIStackView()
        rows.axis = .vertical
        rows.spacing = 12
        card.addSubview(rows)
        rows.snp.makeConstraints { $0.edges.equalToSuperview().inset(Theme.Spacing.l) }

        guard !logs.isEmpty else {
            let hint = UILabel()
            hint.text = "暂无课时流水"
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
            }
            rows.addArrangedSubview(makeLogRow(log))
        }

        return card
    }

    private func makeLogRow(_ log: StudioStudentLog) -> UIView {
        let row = UIView()

        let dateLabel = UILabel()
        dateLabel.text = log.dateText
        dateLabel.font = .appLabel(12)
        dateLabel.textColor = Theme.Color.muted
        row.addSubview(dateLabel)
        dateLabel.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.top.equalToSuperview().offset(1)
            $0.width.equalTo(82)
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

        let noteLabel = UILabel()
        noteLabel.text = "\(log.sourceText) · 剩余 \(log.balance_after ?? 0) 节"
        noteLabel.font = .appLabel(11)
        noteLabel.textColor = Theme.Color.muted
        noteLabel.numberOfLines = 1
        row.addSubview(noteLabel)
        noteLabel.snp.makeConstraints {
            $0.leading.equalTo(titleLabel)
            $0.top.equalTo(titleLabel.snp.bottom).offset(3)
            $0.trailing.lessThanOrEqualToSuperview()
        }

        // 备注单独一行（长文本截断），与「来源 · 剩余」错开，避免挤在一起看不全
        let extraNote = (log.note ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !extraNote.isEmpty {
            let extraLabel = UILabel()
            extraLabel.text = extraNote
            extraLabel.font = .appLabel(11)
            extraLabel.textColor = Theme.Color.muted
            extraLabel.numberOfLines = 1
            row.addSubview(extraLabel)
            extraLabel.snp.makeConstraints {
                $0.leading.equalTo(titleLabel)
                $0.top.equalTo(noteLabel.snp.bottom).offset(2)
                $0.trailing.lessThanOrEqualToSuperview()
                $0.bottom.equalToSuperview()
            }
        } else {
            noteLabel.snp.makeConstraints { $0.bottom.equalToSuperview() }
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

    private enum Style {
        static func avatarTint(_ id: String) -> UIColor {
            let palette: [UInt32] = [0x93B978, 0x87B3C8, 0xD9BA75, 0xBA96C8, 0xBB96B2, 0x8FBFB0]
            var hash = 0
            for u in id.unicodeScalars { hash = (hash &* 31) &+ Int(u.value) }
            return UIColor(hex: palette[abs(hash) % palette.count])
        }
    }
}
