import UIKit
import Kingfisher
import SnapKit

/// 渐变占位头像（木色 / 松绿 tint，手作感）
final class AvatarPlaceholderView: UIView {
    private let label = UILabel()

    init(name: String, size: CGFloat, style: Style = .auto) {
        super.init(frame: .zero)
        snp.makeConstraints { $0.width.height.equalTo(size) }

        label.text = String(name.prefix(1))
        label.font = .appSection(size * 0.4)
        label.textColor = .white
        label.textAlignment = .center
        addSubview(label)
        label.snp.makeConstraints { $0.edges.equalToSuperview() }

        let colors: [CGColor]
        switch style {
        case .auto:
            colors = name.unicodeScalars.first?.value.isMultiple(of: 2) == false
                ? [UIColor(hex: 0x9CC07B).cgColor, UIColor(hex: 0x3D7A5E).cgColor]
                : [UIColor(hex: 0xD8B97A).cgColor, UIColor(hex: 0xB9913F).cgColor]
        case .green:
            colors = [UIColor(hex: 0x9CC07B).cgColor, UIColor(hex: 0x3D7A5E).cgColor]
        case .wood:
            colors = [UIColor(hex: 0xD8B97A).cgColor, UIColor(hex: 0xB9913F).cgColor]
        }
        let layer = CAGradientLayer()
        layer.colors = colors
        layer.startPoint = CGPoint(x: 0, y: 0)
        layer.endPoint = CGPoint(x: 1, y: 1)
        layer.cornerRadius = size * 0.28
        layer.masksToBounds = true
        self.layer.insertSublayer(layer, at: 0)
        layer.frame = bounds
        clipsToBounds = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.sublayers?.first?.frame = bounds
    }

    enum Style { case auto, green, wood }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// 课程卡片（封面 + 年龄标签 + 标题 + 工作室 + 价格/节数）
final class CourseCardView: UIView {

    private let cover = UIImageView()
    private let coverPlaceholder = UIView()
    private let titleLabel = UILabel()
    private let studioLabel = UILabel()
    private let priceLabel = UILabel()
    private let originalPriceLabel = UILabel()

    var onTap: (() -> Void)?

    init(item: CourseItem) {
        super.init(frame: .zero)
        snp.makeConstraints { $0.width.equalTo(148) }

        // 封面
        cover.contentMode = .scaleAspectFill
        cover.clipsToBounds = true
        cover.backgroundColor = Theme.Color.surfaceAlt
        cover.layer.cornerRadius = Theme.Radius.card
        cover.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        cover.layer.masksToBounds = true
        addSubview(cover)
        cover.snp.makeConstraints { $0.top.leading.trailing.equalToSuperview().inset(0); $0.height.equalTo(96) }
        if let coverURL = item.cover, let url = URL(string: coverURL) {
            cover.kf.setImage(with: url, placeholder: UIImage(named: "course_placeholder"))
        } else {
            let ph = AvatarPlaceholderView(name: item.title, size: 48, style: .green)
            ph.center = cover.center
            cover.addSubview(ph)
            ph.snp.makeConstraints { $0.center.equalToSuperview(); $0.width.height.equalTo(48) }
        }

        // 年龄标签（左上角盖在封面上）
        if let ageText = item.ageRangeText {
            let ageLabel = UILabel()
            ageLabel.text = ageText
            ageLabel.font = .appLabel(10)
            ageLabel.textColor = .white
            ageLabel.backgroundColor = Theme.Color.brand.withAlphaComponent(0.85)
            ageLabel.layer.cornerRadius = 6
            ageLabel.layer.masksToBounds = true
            ageLabel.textAlignment = .center
            addSubview(ageLabel)
            ageLabel.snp.makeConstraints { $0.top.leading.equalToSuperview().inset(Theme.Spacing.s); $0.height.equalTo(18) }
            ageLabel.snp.makeConstraints { $0.width.greaterThanOrEqualTo(38) }
        }

        // 标题
        titleLabel.text = item.title
        titleLabel.font = .appSection(14)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 1
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints { $0.top.equalTo(cover.snp.bottom).offset(Theme.Spacing.s); $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m) }

        // 工作室
        studioLabel.text = item.studioName
        studioLabel.font = .appLabel(11)
        studioLabel.textColor = Theme.Color.muted
        studioLabel.numberOfLines = 1
        addSubview(studioLabel)
        studioLabel.snp.makeConstraints { $0.top.equalTo(titleLabel.snp.bottom).offset(2); $0.leading.trailing.equalTo(titleLabel) }

        // 价格（含节数）
        priceLabel.text = item.pricePerLessonsText
        priceLabel.font = .appHero(14)
        priceLabel.textColor = Theme.Color.clay
        priceLabel.numberOfLines = 1
        priceLabel.adjustsFontSizeToFitWidth = true
        priceLabel.minimumScaleFactor = 0.7
        addSubview(priceLabel)
        priceLabel.snp.makeConstraints { $0.top.equalTo(studioLabel.snp.bottom).offset(Theme.Spacing.s); $0.leading.equalTo(titleLabel); $0.bottom.equalToSuperview().offset(-Theme.Spacing.m) }

        if let original = item.originalPriceText {
            originalPriceLabel.text = original
            originalPriceLabel.font = .appLabel(10)
            originalPriceLabel.textColor = Theme.Color.muted
            originalPriceLabel.attributedText = NSAttributedString(
                string: original,
                attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
            )
            addSubview(originalPriceLabel)
            originalPriceLabel.snp.makeConstraints { $0.leading.equalTo(priceLabel.snp.trailing).offset(4); $0.bottom.equalTo(priceLabel).offset(-2) }
        }

        // 卡片容器样式（浅色底 + 圆角 + 轻阴影）
        backgroundColor = Theme.Color.surface
        layer.cornerRadius = Theme.Radius.card
        layer.borderWidth = 1
        layer.borderColor = Theme.Color.line.cgColor
        layer.shadowColor = Theme.Shadow.card.color.cgColor
        layer.shadowOffset = Theme.Shadow.card.offset
        layer.shadowRadius = Theme.Shadow.card.radius
        layer.shadowOpacity = Theme.Shadow.card.opacity

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    @objc private func didTap() { onTap?() }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// 工作室卡片（横滑：封面 + 名称 + 评分/课程数）
final class StudioCardView: UIView {

    private let cover = UIImageView()
    private let nameLabel = UILabel()
    private let metaLabel = UILabel()

    var onTap: (() -> Void)?

    init(item: StudioItem) {
        super.init(frame: .zero)
        snp.makeConstraints { $0.width.equalTo(132) }

        cover.contentMode = .scaleAspectFill
        cover.clipsToBounds = true
        cover.backgroundColor = Theme.Color.surfaceAlt
        cover.layer.cornerRadius = Theme.Radius.card
        cover.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        cover.layer.masksToBounds = true
        addSubview(cover)
        cover.snp.makeConstraints { $0.top.leading.trailing.equalToSuperview(); $0.height.equalTo(88) }
        if let coverURL = item.cover, let url = URL(string: coverURL) {
            cover.kf.setImage(with: url, placeholder: UIImage(named: "studio_placeholder"))
        } else {
            let ph = AvatarPlaceholderView(name: item.name, size: 44, style: .auto)
            cover.addSubview(ph)
            ph.snp.makeConstraints { $0.center.equalToSuperview(); $0.width.height.equalTo(44) }
        }

        nameLabel.text = item.name
        nameLabel.font = .appSection(13)
        nameLabel.textColor = Theme.Color.ink
        nameLabel.numberOfLines = 1
        addSubview(nameLabel)
        nameLabel.snp.makeConstraints { $0.top.equalTo(cover.snp.bottom).offset(Theme.Spacing.s); $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.s) }

        metaLabel.text = "⭐ \(item.ratingText) · \(item.course_count) 门课"
        metaLabel.font = .appLabel(11)
        metaLabel.textColor = Theme.Color.muted
        addSubview(metaLabel)
        metaLabel.snp.makeConstraints { $0.top.equalTo(nameLabel.snp.bottom).offset(2); $0.leading.trailing.equalTo(nameLabel); $0.bottom.equalToSuperview().offset(-Theme.Spacing.s) }

        backgroundColor = Theme.Color.surface
        layer.cornerRadius = Theme.Radius.card
        layer.borderWidth = 1
        layer.borderColor = Theme.Color.line.cgColor
        layer.shadowColor = Theme.Shadow.card.color.cgColor
        layer.shadowOffset = Theme.Shadow.card.offset
        layer.shadowRadius = Theme.Shadow.card.radius
        layer.shadowOpacity = Theme.Shadow.card.opacity

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    @objc private func didTap() { onTap?() }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// 老师卡片（横滑：头像 + 姓名 + 评分/擅长）
final class TeacherCardView: UIView {

    private let avatar = UIImageView()
    private let nameLabel = UILabel()
    private let metaLabel = UILabel()

    var onTap: (() -> Void)?

    init(item: TeacherItem) {
        super.init(frame: .zero)
        snp.makeConstraints { $0.width.equalTo(110) }

        avatar.contentMode = .scaleAspectFill
        avatar.clipsToBounds = true
        avatar.backgroundColor = Theme.Color.surfaceAlt
        avatar.layer.cornerRadius = Theme.Radius.avatar
        avatar.layer.masksToBounds = true
        addSubview(avatar)
        avatar.snp.makeConstraints { $0.top.equalToSuperview().inset(Theme.Spacing.m); $0.centerX.equalToSuperview(); $0.width.height.equalTo(56) }
        if let avatarURL = item.avatar, let url = URL(string: avatarURL) {
            avatar.kf.setImage(with: url, placeholder: UIImage(named: "avatar_placeholder"))
        }

        nameLabel.text = item.displayName
        nameLabel.font = .appSection(13)
        nameLabel.textColor = Theme.Color.ink
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 1
        addSubview(nameLabel)
        nameLabel.snp.makeConstraints { $0.top.equalTo(avatar.snp.bottom).offset(Theme.Spacing.s); $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.xs) }

        metaLabel.text = "⭐ \(item.ratingText)"
        metaLabel.font = .appLabel(11)
        metaLabel.textColor = Theme.Color.muted
        metaLabel.textAlignment = .center
        addSubview(metaLabel)
        metaLabel.snp.makeConstraints { $0.top.equalTo(nameLabel.snp.bottom).offset(2); $0.leading.trailing.equalTo(nameLabel); $0.bottom.equalToSuperview().offset(-Theme.Spacing.m) }

        backgroundColor = Theme.Color.surface
        layer.cornerRadius = Theme.Radius.card
        layer.borderWidth = 1
        layer.borderColor = Theme.Color.line.cgColor
        layer.shadowColor = Theme.Shadow.card.color.cgColor
        layer.shadowOffset = Theme.Shadow.card.offset
        layer.shadowRadius = Theme.Shadow.card.radius
        layer.shadowOpacity = Theme.Shadow.card.opacity

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    @objc private func didTap() { onTap?() }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 孩子课程进度卡（Hero 内，设计图双卡并排）

/// 白卡：名字 + 课种 · 等级 + 进度条 + 剩余课时 · 学期%
final class ChildProgressCard: UIView {

    private let nameLabel = UILabel()
    private let courseLabel = UILabel()
    private let progressView = UIProgressView()
    private let metaLabel = UILabel()
    private let emptyLabel = UILabel()

    var onTap: (() -> Void)?

    init(item: ChildItem) {
        super.init(frame: .zero)

        nameLabel.text = item.nickname
        nameLabel.font = .appSection(14)
        nameLabel.textColor = Theme.Color.ink
        addSubview(nameLabel)
        nameLabel.snp.makeConstraints { $0.top.equalToSuperview().inset(Theme.Spacing.m); $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m) }

        // 课种
        courseLabel.font = .appLabel(11)
        courseLabel.textColor = Theme.Color.sub
        courseLabel.numberOfLines = 1
        addSubview(courseLabel)
        courseLabel.snp.makeConstraints { $0.top.equalTo(nameLabel.snp.bottom).offset(Theme.Spacing.xs); $0.leading.trailing.equalTo(nameLabel) }

        // 进度条
        progressView.progressTintColor = Theme.Color.brand
        progressView.trackTintColor = Theme.Color.brandSoft
        progressView.layer.cornerRadius = 3
        progressView.clipsToBounds = true
        addSubview(progressView)
        progressView.snp.makeConstraints { $0.top.equalTo(courseLabel.snp.bottom).offset(Theme.Spacing.s); $0.leading.trailing.equalTo(nameLabel); $0.height.equalTo(6) }

        // 剩余课时 · 学期%
        metaLabel.font = .appLabel(11)
        metaLabel.textColor = Theme.Color.muted
        addSubview(metaLabel)
        metaLabel.snp.makeConstraints { $0.top.equalTo(progressView.snp.bottom).offset(Theme.Spacing.s); $0.leading.trailing.equalTo(nameLabel); $0.bottom.equalToSuperview().offset(-Theme.Spacing.m) }

        // 空态（有孩子无课包）
        emptyLabel.font = .appLabel(11)
        emptyLabel.textColor = Theme.Color.muted
        emptyLabel.text = "暂无课程 · 去报名"
        emptyLabel.isHidden = true
        addSubview(emptyLabel)
        emptyLabel.snp.makeConstraints { $0.top.equalTo(progressView.snp.bottom).offset(Theme.Spacing.s); $0.leading.trailing.equalTo(nameLabel); $0.bottom.equalToSuperview().offset(-Theme.Spacing.m) }

        apply(item)

        backgroundColor = Theme.Color.surface
        layer.cornerRadius = Theme.Radius.card
        layer.borderWidth = 1
        layer.borderColor = Theme.Color.line.cgColor
        layer.shadowColor = Theme.Shadow.card.color.cgColor
        layer.shadowOffset = Theme.Shadow.card.offset
        layer.shadowRadius = Theme.Shadow.card.radius
        layer.shadowOpacity = Theme.Shadow.card.opacity

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    private func apply(_ item: ChildItem) {
        if let balance = item.mainBalance {
            courseLabel.text = balance.courseText
            progressView.progress = Float(balance.progressPercent) / 100.0
            metaLabel.text = "剩余课时 \(balance.remaining_lessons) 节 · 学期 \(balance.progressPercent)%"
            progressView.isHidden = false
            metaLabel.isHidden = false
            emptyLabel.isHidden = true
        } else {
            courseLabel.text = "未报名课程"
            progressView.isHidden = true
            metaLabel.isHidden = true
            emptyLabel.isHidden = false
        }
    }

    @objc private func didTap() { onTap?() }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 工作室列表行（附近热门工作室：头像 + 名称 + 课程·距离 + 进店）

final class StudioRowView: UIView {

    private let nameLabel = UILabel()
    private let metaLabel = UILabel()
    private let enterButton = UIButton(type: .system)

    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        // 头像（渐变色块；cover 有值时用图）
        let placeholder = AvatarPlaceholderView(name: "艺", size: 48, style: .auto)
        placeholder.tag = 1001
        addSubview(placeholder)
        placeholder.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(48)
        }

        nameLabel.font = .appSection(15)
        nameLabel.textColor = Theme.Color.ink
        nameLabel.numberOfLines = 1
        addSubview(nameLabel)
        nameLabel.snp.makeConstraints { $0.leading.equalToSuperview().inset(72); $0.top.equalToSuperview().inset(Theme.Spacing.l); $0.trailing.equalToSuperview().inset(92) }

        metaLabel.font = .appLabel(12)
        metaLabel.textColor = Theme.Color.sub
        metaLabel.numberOfLines = 1
        addSubview(metaLabel)
        metaLabel.snp.makeConstraints { $0.leading.trailing.equalTo(nameLabel); $0.top.equalTo(nameLabel.snp.bottom).offset(2); $0.bottom.equalToSuperview().inset(Theme.Spacing.l) }

        // 进店
        enterButton.setTitle("进店 ›", for: .normal)
        enterButton.titleLabel?.font = .appSection(13)
        enterButton.setTitleColor(Theme.Color.brand, for: .normal)
        enterButton.backgroundColor = Theme.Color.brandSoft
        enterButton.layer.cornerRadius = Theme.Radius.button
        enterButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        addSubview(enterButton)
        enterButton.snp.makeConstraints { $0.trailing.equalToSuperview().inset(Theme.Spacing.m); $0.centerY.equalToSuperview() }
        enterButton.addTarget(self, action: #selector(didTapEnter), for: .touchUpInside)

        backgroundColor = Theme.Color.surface
        layer.cornerRadius = Theme.Radius.card
        layer.borderWidth = 1
        layer.borderColor = Theme.Color.line.cgColor
        layer.shadowColor = Theme.Shadow.card.color.cgColor
        layer.shadowOffset = Theme.Shadow.card.offset
        layer.shadowRadius = Theme.Shadow.card.radius
        layer.shadowOpacity = Theme.Shadow.card.opacity

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    /// cell 复用：重建内容
    func configure(item: StudioItem) {
        nameLabel.text = item.name
        metaLabel.text = item.rowMetaText

        // 头像：有 cover 换图，无则用渐变首字
        if let old = viewWithTag(1001) { old.removeFromSuperview() }
        if let coverURL = item.cover, let url = URL(string: coverURL) {
            let img = UIImageView()
            img.contentMode = .scaleAspectFill
            img.clipsToBounds = true
            img.layer.cornerRadius = Theme.Radius.avatar
            img.layer.masksToBounds = true
            addSubview(img)
            img.kf.setImage(with: url)
            img.snp.makeConstraints { $0.leading.equalToSuperview().inset(Theme.Spacing.m); $0.centerY.equalToSuperview(); $0.width.height.equalTo(48) }
        } else {
            let ph = AvatarPlaceholderView(name: item.name, size: 48, style: .auto)
            ph.tag = 1001
            addSubview(ph)
            ph.snp.makeConstraints { $0.leading.equalToSuperview().inset(Theme.Spacing.m); $0.centerY.equalToSuperview(); $0.width.height.equalTo(48) }
        }
    }

    @objc private func didTapEnter() { onTap?() }
    @objc private func didTap() { onTap?() }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 帖子卡（老师动态 feed）

final class PostCardView: UIView {

    private let authorNameLabel = UILabel()
    private let roleLabel = UILabel()
    private let timeLabel = UILabel()
    private let bodyLabel = UILabel()
    private let imageStack = UIStackView()
    private let likeLabel = UILabel()
    private let commentLabel = UILabel()
    private let relationLabel = UILabel()
    private var imageTop: Constraint?
    private var imageHeight: Constraint?

    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        // 头部：头像 + 名字 + 角色
        let ph = AvatarPlaceholderView(name: "师", size: 36, style: .auto)
        ph.tag = 2001
        addSubview(ph)
        ph.snp.makeConstraints { $0.leading.equalToSuperview().inset(Theme.Spacing.m); $0.top.equalToSuperview().inset(Theme.Spacing.m); $0.width.height.equalTo(36) }

        authorNameLabel.font = .appSection(14)
        authorNameLabel.textColor = Theme.Color.ink
        addSubview(authorNameLabel)
        authorNameLabel.snp.makeConstraints { $0.leading.equalToSuperview().inset(60); $0.top.equalToSuperview().inset(Theme.Spacing.m) }

        // 角色徽章
        roleLabel.font = .appLabel(10)
        roleLabel.textColor = Theme.Color.brand
        roleLabel.backgroundColor = Theme.Color.brandSoft
        roleLabel.layer.cornerRadius = 4
        roleLabel.layer.masksToBounds = true
        roleLabel.textAlignment = .center
        addSubview(roleLabel)
        roleLabel.snp.makeConstraints { $0.leading.equalTo(authorNameLabel.snp.trailing).offset(Theme.Spacing.xs); $0.centerY.equalTo(authorNameLabel); $0.height.equalTo(16) }
        roleLabel.snp.makeConstraints { $0.width.greaterThanOrEqualTo(28) }

        timeLabel.font = .appLabel(11)
        timeLabel.textColor = Theme.Color.muted
        addSubview(timeLabel)
        timeLabel.snp.makeConstraints { $0.trailing.equalToSuperview().inset(Theme.Spacing.m); $0.centerY.equalTo(authorNameLabel) }

        // 内容（左对齐作者名，避免与头像重叠）
        bodyLabel.font = .appBody(14)
        bodyLabel.textColor = Theme.Color.ink
        bodyLabel.numberOfLines = 3
        addSubview(bodyLabel)
        bodyLabel.snp.makeConstraints { $0.top.equalTo(authorNameLabel.snp.bottom).offset(Theme.Spacing.s); $0.leading.equalToSuperview().inset(60); $0.trailing.equalToSuperview().inset(Theme.Spacing.m) }

        // 图片（最多 3 张横排；无图时高度收为 0）
        imageStack.axis = .horizontal
        imageStack.spacing = Theme.Spacing.s
        imageStack.distribution = .fillEqually
        addSubview(imageStack)
        imageStack.snp.makeConstraints {
            imageTop = $0.top.equalTo(bodyLabel.snp.bottom).offset(Theme.Spacing.s).constraint
            imageHeight = $0.height.equalTo(96).constraint
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }

        // 底部：点赞 / 评论 / 关联
        let likeIcon = UIImageView(image: UIImage(systemName: "heart"))
        likeIcon.tintColor = Theme.Color.muted
        likeIcon.contentMode = .scaleAspectFit
        addSubview(likeIcon)
        likeIcon.snp.makeConstraints { $0.leading.equalToSuperview().inset(Theme.Spacing.m); $0.top.greaterThanOrEqualTo(imageStack.snp.bottom).offset(Theme.Spacing.m); $0.bottom.equalToSuperview().inset(Theme.Spacing.m); $0.width.height.equalTo(14) }

        likeLabel.font = .appLabel(11)
        likeLabel.textColor = Theme.Color.muted
        addSubview(likeLabel)
        likeLabel.snp.makeConstraints { $0.leading.equalTo(likeIcon.snp.trailing).offset(4); $0.centerY.equalTo(likeIcon) }

        let commentIcon = UIImageView(image: UIImage(systemName: "bubble.right"))
        commentIcon.tintColor = Theme.Color.muted
        commentIcon.contentMode = .scaleAspectFit
        addSubview(commentIcon)
        commentIcon.snp.makeConstraints { $0.leading.equalTo(likeLabel.snp.trailing).offset(Theme.Spacing.l); $0.centerY.equalTo(likeIcon); $0.width.height.equalTo(14) }

        commentLabel.font = .appLabel(11)
        commentLabel.textColor = Theme.Color.muted
        addSubview(commentLabel)
        commentLabel.snp.makeConstraints { $0.leading.equalTo(commentIcon.snp.trailing).offset(4); $0.centerY.equalTo(likeIcon) }

        // 关联文案（宝宝/课程）
        relationLabel.font = .appLabel(11)
        relationLabel.textColor = Theme.Color.brand
        relationLabel.textAlignment = .right
        relationLabel.numberOfLines = 1
        addSubview(relationLabel)
        relationLabel.snp.makeConstraints { $0.trailing.equalToSuperview().inset(Theme.Spacing.m); $0.centerY.equalTo(likeIcon); $0.leading.greaterThanOrEqualTo(commentLabel.snp.trailing).offset(Theme.Spacing.s) }

        backgroundColor = Theme.Color.surface
        layer.cornerRadius = Theme.Radius.card
        layer.borderWidth = 1
        layer.borderColor = Theme.Color.line.cgColor
        layer.shadowColor = Theme.Shadow.card.color.cgColor
        layer.shadowOffset = Theme.Shadow.card.offset
        layer.shadowRadius = Theme.Shadow.card.radius
        layer.shadowOpacity = Theme.Shadow.card.opacity

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    /// cell 复用：重建内容
    func configure(item: PostItem) {
        authorNameLabel.text = item.authorName
        roleLabel.text = item.roleText
        timeLabel.text = item.timeText
        bodyLabel.text = item.bodyText

        // 头像：有图换图，无图渐变首字
        if let old = viewWithTag(2001) { old.removeFromSuperview() }
        if let avatarURL = item.authorAvatar, let url = URL(string: avatarURL) {
            let img = UIImageView()
            img.contentMode = .scaleAspectFill
            img.clipsToBounds = true
            img.layer.cornerRadius = 18
            img.layer.masksToBounds = true
            addSubview(img)
            img.kf.setImage(with: url)
            img.snp.makeConstraints { $0.leading.equalToSuperview().inset(Theme.Spacing.m); $0.top.equalToSuperview().inset(Theme.Spacing.m); $0.width.height.equalTo(36) }
        } else {
            let ph = AvatarPlaceholderView(name: item.authorName, size: 36, style: .auto)
            ph.tag = 2001
            addSubview(ph)
            ph.snp.makeConstraints { $0.leading.equalToSuperview().inset(Theme.Spacing.m); $0.top.equalToSuperview().inset(Theme.Spacing.m); $0.width.height.equalTo(36) }
        }

        // 图片：无图隐藏（高度收 0）
        imageStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let urls = item.imageList.prefix(3)
        let empty = urls.isEmpty
        imageStack.isHidden = empty
        imageTop?.update(offset: empty ? 0 : Theme.Spacing.s)
        imageHeight?.update(offset: empty ? 0 : 96)
        for urlString in urls {
            let img = UIImageView()
            img.contentMode = .scaleAspectFill
            img.clipsToBounds = true
            img.backgroundColor = Theme.Color.surfaceAlt
            img.layer.cornerRadius = Theme.Radius.icon
            img.layer.masksToBounds = true
            if let url = URL(string: urlString) {
                img.kf.setImage(with: url)
            }
            imageStack.addArrangedSubview(img)
        }

        // 关联文案
        if let relation = item.relationText {
            relationLabel.text = relation
            relationLabel.isHidden = false
        } else {
            relationLabel.text = ""
            relationLabel.isHidden = true
        }
    }

    @objc private func didTap() { onTap?() }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
final class ChildCardView: UIView {

    private let avatar = UIImageView()
    private let nameLabel = UILabel()
    private let ageLabel = UILabel()

    var onTap: (() -> Void)?

    init(item: ChildItem) {
        super.init(frame: .zero)
        snp.makeConstraints { $0.width.equalTo(84) }

        avatar.contentMode = .scaleAspectFill
        avatar.clipsToBounds = true
        avatar.backgroundColor = Theme.Color.surfaceAlt
        avatar.layer.cornerRadius = 20
        avatar.layer.masksToBounds = true
        addSubview(avatar)
        avatar.snp.makeConstraints { $0.top.equalToSuperview().inset(Theme.Spacing.m); $0.centerX.equalToSuperview(); $0.width.height.equalTo(56) }
        if let avatarURL = item.avatar, let url = URL(string: avatarURL) {
            avatar.kf.setImage(with: url, placeholder: UIImage(named: "avatar_placeholder"))
        }

        nameLabel.text = item.nickname
        nameLabel.font = .appSection(13)
        nameLabel.textColor = Theme.Color.ink
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 1
        addSubview(nameLabel)
        nameLabel.snp.makeConstraints { $0.top.equalTo(avatar.snp.bottom).offset(Theme.Spacing.s); $0.leading.trailing.equalToSuperview().inset(2) }

        ageLabel.text = item.ageText
        ageLabel.font = .appLabel(11)
        ageLabel.textColor = Theme.Color.sub
        ageLabel.textAlignment = .center
        addSubview(ageLabel)
        ageLabel.snp.makeConstraints { $0.top.equalTo(nameLabel.snp.bottom).offset(2); $0.leading.trailing.equalTo(nameLabel); $0.bottom.equalToSuperview().offset(-Theme.Spacing.s) }

        backgroundColor = Theme.Color.surface
        layer.cornerRadius = Theme.Radius.card
        layer.borderWidth = 1
        layer.borderColor = Theme.Color.line.cgColor
        layer.shadowColor = Theme.Shadow.card.color.cgColor
        layer.shadowOffset = Theme.Shadow.card.offset
        layer.shadowRadius = Theme.Shadow.card.radius
        layer.shadowOpacity = Theme.Shadow.card.opacity

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    @objc private func didTap() { onTap?() }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
