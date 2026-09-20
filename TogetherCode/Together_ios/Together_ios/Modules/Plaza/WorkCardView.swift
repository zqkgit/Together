import UIKit
import SnapKit
import Kingfisher

/// 广场作品卡（对齐 PR 设计图 #plaza）
/// 结构：外层卡片容器（白底圆角边框）内 = 作品图（3:4，无图时按话题色渐变占位）→ 标题 → 作者·点赞 → 关联课程
final class WorkCardView: UIView {

    private let cardView = UIView()
    private let imageView = UIImageView()
    private let imageContainer = UIView()
    private let titleLabel = UILabel()
    private let authorLabel = UILabel()
    private let likeLabel = UILabel()
    private let courseLabel = UILabel()

    var onTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)

        // 卡片容器：白底圆角 + 细边框，图片与信息整体一体
        cardView.backgroundColor = Theme.Color.surface
        cardView.layer.cornerRadius = Theme.Radius.card
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = Theme.Color.line.cgColor
        cardView.clipsToBounds = true
        addSubview(cardView)
        cardView.snp.makeConstraints { $0.edges.equalToSuperview() }

        // 作品图（顶部圆角由 cardView 裁剪，3:4）
        imageContainer.backgroundColor = Theme.Color.surfaceAlt
        cardView.addSubview(imageContainer)
        imageContainer.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(imageContainer.snp.width).multipliedBy(4.0 / 3.0)
        }

        imageView.contentMode = .scaleAspectFill
        imageContainer.addSubview(imageView)
        imageView.snp.makeConstraints { $0.edges.equalToSuperview() }

        // 信息区（内边距统一 12）
        titleLabel.font = .appSection(14)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 2
        cardView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(imageContainer.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }

        authorLabel.font = .appLabel(11)
        authorLabel.textColor = Theme.Color.sub
        cardView.addSubview(authorLabel)
        authorLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(4)
            $0.leading.equalToSuperview().inset(Theme.Spacing.m)
        }

        likeLabel.font = .appLabel(11)
        likeLabel.textColor = Theme.Color.muted
        cardView.addSubview(likeLabel)
        likeLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.centerY.equalTo(authorLabel)
        }

        // 关联课程（无则隐藏）
        courseLabel.font = .appLabel(11)
        courseLabel.textColor = Theme.Color.brand
        courseLabel.numberOfLines = 1
        cardView.addSubview(courseLabel)
        courseLabel.snp.makeConstraints {
            $0.top.equalTo(authorLabel.snp.bottom).offset(4)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.m)
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTap))
        addGestureRecognizer(tap)
        isUserInteractionEnabled = true
    }

    func configure(item: PostItem) {
        titleLabel.text = item.content?.isEmpty == false ? item.content : "作品分享"
        var authorText = item.authorName
        if let distance = item.distanceText {
            authorText += " · \(distance)"
        }
        authorLabel.text = authorText
        likeLabel.text = "♥ \(item.like_count ?? 0)"
        if let course = item.course?.title, !course.isEmpty {
            courseLabel.text = "关联课程·\(course)"
            courseLabel.isHidden = false
        } else {
            courseLabel.text = ""
            courseLabel.isHidden = true
        }

        // 作品图：有图加载，无图/失败按话题色渐变占位
        let colorPair = Self.palette(for: item.topic)
        if let urlString = item.images?.first, let url = URL(string: urlString) {
            imageContainer.backgroundColor = colorPair.0
            imageView.kf.setImage(with: url, placeholder: Self.gradientPlaceholder(colors: [colorPair.0, colorPair.1]))
        } else {
            imageContainer.backgroundColor = colorPair.0
            imageView.image = Self.gradientPlaceholder(colors: [colorPair.0, colorPair.1])
        }
    }

    /// 话题 → 色系
    static func palette(for topic: String?) -> (UIColor, UIColor) {
        switch topic {
        case "水彩": return (UIColor(hex: 0x7FB5C8), UIColor(hex: 0x4A7C9B))
        case "黏土": return (UIColor(hex: 0xE0A878), UIColor(hex: 0xC15F2C))
        case "书法": return (UIColor(hex: 0x8B8B8B), UIColor(hex: 0x4A4A4A))
        case "素描": return (UIColor(hex: 0xC9C4BC), UIColor(hex: 0x8A8478))
        case "国画": return (UIColor(hex: 0xA8BDA0), UIColor(hex: 0x6E8A66))
        default: return (Theme.Color.brandSoft, Theme.Color.brand)
        }
    }

    static func gradientPlaceholder(colors: [UIColor]) -> UIImage? {
        let size = CGSize(width: 1, height: 1)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        let cg = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors.map { $0.cgColor } as CFArray,
            locations: [0, 1]
        )
        ctx.drawLinearGradient(cg!, start: .zero, end: CGPoint(x: 1, y: 1), options: [])
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }

    @objc private func didTap() { onTap?() }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
