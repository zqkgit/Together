import UIKit

/// 自动保持正圆的容器
/// 圆角始终跟随短边的一半，宽高由外部约束决定后无需手动设置 cornerRadius。
/// 适用于头像、圆形图标底、胶囊圆点等场景。
class CircleView: UIView {

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(bounds.width, bounds.height) / 2
        layer.masksToBounds = true
    }
}

/// 自动保持正圆的图片
/// 用于头像、圆图等场景，圆角跟随短边一半，无需手动设置。
class CircleImageView: UIImageView {

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(bounds.width, bounds.height) / 2
        layer.masksToBounds = true
    }
}
