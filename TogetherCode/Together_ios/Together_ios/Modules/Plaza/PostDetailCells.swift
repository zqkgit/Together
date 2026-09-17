import UIKit
import SnapKit

// MARK: - 帖子详情分组

/// 帖子详情按内容分组的枚举：图片 → 作者 → 内容 → 课程 → 已关联学生 → 评论
enum PostDetailSection: Int, CaseIterable {
    case gallery   // 图片轮播（有图才显示）
    case author    // 发帖人信息
    case content   // 标题 / 正文 / 话题
    case course    // 关联课程卡（有关联课程才显示）
    case students  // 已关联学生（老师帖 + 有学生才显示）
    case comments  // 评论（唯一多行分组）

    /// 是否渲染 section header
    var showsHeader: Bool { self == .comments }
}

// MARK: - 图片分组

/// 顶部图片轮播（400pt 高，横滑 + 点击全屏预览）
final class PostGalleryCell: UITableViewCell {
    var onTapImage: ((Int) -> Void)?

    private let carouselView = ImageCarouselView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(carouselView)
        carouselView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(400)
            $0.bottom.equalToSuperview()
        }
        carouselView.onTapImage = { [weak self] index in self?.onTapImage?(index) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(images: [String]) {
        carouselView.configure(images: images)
    }
}

// MARK: - 作者分组

/// 发帖人信息行：头像 + 昵称 + 身份 + 时间 + 关注按钮
final class PostAuthorCell: UITableViewCell {
    var onFollow: (() -> Void)?

    private let avatarView = AvatarPlaceholderView(name: "?", size: 44)
    private let nameLabel = UILabel()
    private let roleBadge = UILabel()
    private let timeLabel = UILabel()
    private let followButton = UIButton(type: .system)
    private var avatarTop: Constraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            avatarTop = $0.top.equalToSuperview().offset(Theme.Spacing.m).constraint
            $0.leading.equalToSuperview().inset(Theme.Spacing.m)
            $0.width.height.equalTo(44)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.m)
        }

        nameLabel.font = .appSection(15)
        nameLabel.textColor = Theme.Color.ink
        contentView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.top.equalTo(avatarView.snp.top)
            $0.leading.equalTo(avatarView.snp.trailing).offset(Theme.Spacing.s)
        }
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameLabel.lineBreakMode = .byTruncatingTail

        roleBadge.font = .appLabel(10)
        roleBadge.textColor = Theme.Color.brand
        roleBadge.textAlignment = .center
        roleBadge.backgroundColor = Theme.Color.brandSoft
        roleBadge.layer.cornerRadius = 8
        roleBadge.clipsToBounds = true
        contentView.addSubview(roleBadge)
        roleBadge.snp.makeConstraints {
            $0.centerY.equalTo(nameLabel)
            $0.leading.equalTo(nameLabel.snp.trailing).offset(6)
            $0.height.equalTo(16)
            $0.width.greaterThanOrEqualTo(34)
        }

        timeLabel.font = .appLabel(11)
        timeLabel.textColor = Theme.Color.muted
        contentView.addSubview(timeLabel)
        timeLabel.snp.makeConstraints {
            $0.top.equalTo(nameLabel.snp.bottom).offset(3)
            $0.leading.equalTo(nameLabel)
        }

        followButton.titleLabel?.font = .appLabel(12)
        followButton.layer.cornerRadius = 13
        followButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        followButton.addTarget(self, action: #selector(didTapFollow), for: .touchUpInside)
        contentView.addSubview(followButton)
        followButton.snp.makeConstraints {
            $0.centerY.equalTo(avatarView)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func didTapFollow() { onFollow?() }

    func configure(post: PostItem?, topInset: CGFloat = Theme.Spacing.m) {
        guard let post else { return }
        avatarTop?.update(offset: topInset)
        avatarView.update(name: post.authorName)
        nameLabel.text = post.authorName
        roleBadge.text = post.roleText
        roleBadge.isHidden = post.roleText.isEmpty
        timeLabel.text = "\(post.created_at?.shortRelativeTime ?? "")·广场"
        setFollowing(post.is_following ?? false)
    }

    func setFollowing(_ following: Bool) {
        if following {
            followButton.setTitle("已关注", for: .normal)
            followButton.setTitleColor(Theme.Color.sub, for: .normal)
            followButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            followButton.layer.borderWidth = 0.5
            followButton.layer.borderColor = Theme.Color.line.cgColor
        } else {
            followButton.setTitle("+ 关注", for: .normal)
            followButton.setTitleColor(Theme.Color.brand, for: .normal)
            followButton.backgroundColor = Theme.Color.brandSoft
            followButton.layer.borderWidth = 0
        }
    }
}

// MARK: - 内容分组

/// 标题 + 正文 + 话题 chip
final class PostContentCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let topicLabel = UILabel()
    private var bottomRef: UIView?
    private var bottomConstraint: Constraint?
    private var topicTop: Constraint?
    private var topicHeight: Constraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        titleLabel.font = .appTitle(20)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 0
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }

        bodyLabel.font = .appBody(14)
        bodyLabel.textColor = Theme.Color.sub
        bodyLabel.numberOfLines = 0
        contentView.addSubview(bodyLabel)
        bodyLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }

        topicLabel.font = .appLabel(12)
        topicLabel.textColor = Theme.Color.brand
        topicLabel.backgroundColor = Theme.Color.brandSoft
        topicLabel.layer.cornerRadius = 11
        topicLabel.clipsToBounds = true
        topicLabel.textAlignment = .center
        contentView.addSubview(topicLabel)
        topicLabel.snp.makeConstraints {
            topicTop = $0.top.equalTo(bodyLabel.snp.bottom).offset(Theme.Spacing.s).constraint
            $0.leading.equalToSuperview().inset(Theme.Spacing.m)
            topicHeight = $0.height.equalTo(22).constraint
            $0.width.greaterThanOrEqualTo(52)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(post: PostItem?) {
        guard let post else { return }
        // 首行加粗为标题，其余为正文
        let content = post.bodyText
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        if lines.count > 1 {
            titleLabel.text = String(lines[0])
            bodyLabel.text = lines.dropFirst().joined(separator: "\n")
            bodyLabel.isHidden = false
        } else {
            titleLabel.text = content.isEmpty ? "作品分享" : content
            bodyLabel.isHidden = true
        }
        if let topic = post.safeTopic {
            topicLabel.text = "#\(topic)"
            topicLabel.isHidden = false
            topicTop?.activate()
            topicHeight?.activate()
        } else {
            // 无话题：完全移除占位，不显示也不撑高度
            topicLabel.isHidden = true
            topicTop?.deactivate()
            topicHeight?.deactivate()
        }
        // 底部锚点始终落在最后可见元素上，避免分组高度塌陷
        bottomConstraint?.deactivate()
        let anchor: UIView
        if !topicLabel.isHidden { anchor = topicLabel }
        else if !bodyLabel.isHidden { anchor = bodyLabel }
        else { anchor = titleLabel }
        bottomRef = anchor
        anchor.snp.makeConstraints {
            bottomConstraint = $0.bottom.equalToSuperview().offset(-Theme.Spacing.m).constraint
        }
    }
}

// MARK: - 课程分组

/// 关联课程卡：标题 + 价格 + 去报名
final class PostCourseCell: UITableViewCell {
    var onEnroll: (() -> Void)?

    private let card = UIView()
    private let titleLabel = UILabel()
    private let priceLabel = UILabel()
    private let enrollButton = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        card.layer.borderWidth = 1
        card.layer.borderColor = Theme.Color.line.cgColor
        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.height.equalTo(76)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.m)
        }

        titleLabel.font = .appBody(14)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 1
        card.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.leading.equalToSuperview().inset(Theme.Spacing.m)
            $0.trailing.lessThanOrEqualToSuperview().inset(88)
        }

        priceLabel.font = .appBody(13)
        priceLabel.textColor = Theme.Color.clay
        card.addSubview(priceLabel)
        priceLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(4)
            $0.leading.equalTo(titleLabel)
        }

        enrollButton.setTitle("去报名", for: .normal)
        enrollButton.setTitleColor(.white, for: .normal)
        enrollButton.titleLabel?.font = .appLabel(13)
        enrollButton.backgroundColor = Theme.Color.brand
        enrollButton.layer.cornerRadius = Theme.Radius.button
        enrollButton.addTarget(self, action: #selector(didTapEnroll), for: .touchUpInside)
        card.addSubview(enrollButton)
        enrollButton.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.width.equalTo(72)
            $0.height.equalTo(34)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func didTapEnroll() { onEnroll?() }

    func configure(post: PostItem?) {
        guard let course = post?.course else { return }
        titleLabel.text = course.title
        if let price = course.price, price > 0 {
            priceLabel.text = "¥\(String(format: "%.2f", Double(price) / 100)) 元"
        } else {
            priceLabel.text = "价格咨询"
        }
    }
}

// MARK: - 已关联学生分组

/// 已关联学生卡：标题 + 学生行（已消课且是作者本人可点撤销）
final class PostStudentCell: UITableViewCell {
    var onUndoStudent: ((PostItem.PostStudentItem) -> Void)?

    private let card = UIView()
    private let titleLabel = UILabel()
    private var rows: [PostStudentRowView] = []
    private var titleBottom: Constraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        card.layer.borderWidth = 1
        card.layer.borderColor = Theme.Color.line.cgColor
        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.m)
        }

        titleLabel.font = .appSection(13)
        titleLabel.textColor = Theme.Color.sub
        titleLabel.text = "已关联学生"
        card.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(students: [PostItem.PostStudentItem], canUndo: Bool) {
        rows.forEach { $0.removeFromSuperview() }
        rows = []
        titleBottom?.deactivate()

        var previous: UIView = titleLabel
        for student in students {
            let row = PostStudentRowView()
            row.configure(student: student)
            if canUndo && student.deducted == true {
                row.onTap = { [weak self] in self?.onUndoStudent?(student) }
            }
            card.addSubview(row)
            row.snp.makeConstraints {
                $0.top.equalTo(previous.snp.bottom).offset(Theme.Spacing.s)
                $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
                $0.height.equalTo(40)
            }
            rows.append(row)
            previous = row
        }
        if let last = rows.last {
            last.snp.makeConstraints { $0.bottom.equalToSuperview().offset(-Theme.Spacing.m) }
        } else {
            titleLabel.snp.makeConstraints { titleBottom = $0.bottom.equalToSuperview().offset(-Theme.Spacing.m).constraint }
        }
    }
}

// MARK: - 学生行（内部复用）

/// 关联学生单行：头像 + 昵称 + 已消课/未消课（整行可点撤销）
final class PostStudentRowView: UIView {
    var onTap: (() -> Void)?

    private let avatarView = AvatarPlaceholderView(name: "?", size: 28)
    private let nameLabel = UILabel()
    private let statusLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        avatarView.isUserInteractionEnabled = false
        addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.leading.centerY.equalToSuperview()
            $0.width.height.equalTo(28)
        }

        nameLabel.font = .appBody(14)
        nameLabel.textColor = Theme.Color.ink
        nameLabel.isUserInteractionEnabled = false
        addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarView.snp.trailing).offset(Theme.Spacing.s)
            $0.centerY.equalToSuperview()
        }

        statusLabel.font = .appLabel(11)
        statusLabel.textAlignment = .center
        statusLabel.layer.cornerRadius = 8
        statusLabel.clipsToBounds = true
        statusLabel.isUserInteractionEnabled = false
        addSubview(statusLabel)
        statusLabel.snp.makeConstraints {
            $0.centerY.trailing.equalToSuperview()
            $0.height.equalTo(17)
            $0.width.greaterThanOrEqualTo(44)
        }

        // 整行可点：行级点击手势（子视图不拦截触摸）
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func didTap() { NSLog("[PostDetail] student row tap"); onTap?() }

    func configure(student: PostItem.PostStudentItem) {
        avatarView.update(name: student.nickname ?? "宝宝")
        nameLabel.text = student.nickname ?? "宝宝"
        let consumed = student.deducted == true
        statusLabel.text = consumed ? "已消课" : "未消课"
        statusLabel.textColor = consumed ? Theme.Color.brand : Theme.Color.sub
        statusLabel.backgroundColor = consumed ? Theme.Color.brandSoft : Theme.Color.bg
        isAccessibilityElement = true
        accessibilityLabel = "学生 \(nameLabel.text ?? "") \(statusLabel.text ?? "")"
        accessibilityTraits = .button
    }
}
