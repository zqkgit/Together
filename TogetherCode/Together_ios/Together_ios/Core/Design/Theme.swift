import UIKit

/// 艺启 · 设计 Token（对齐 YIQI 设计系统 v2「温暖手作」）
enum Theme {

    // MARK: - 颜色

    enum Color {
        /// 页面底色（暖纸米白，非纯白）
        static let bg = UIColor(hex: 0xFAF7F1)
        /// 卡片面 / 顶栏
        static let surface = UIColor(hex: 0xFFFFFF)
        /// 交替面 / 次级容器
        static let surfaceAlt = UIColor(hex: 0xF4EFE6)
        /// 1px whisper 边
        static let line = UIColor(hex: 0xE6DFD3)
        /// 主文字
        static let ink = UIColor(hex: 0x2B2621)
        /// 次要文字
        static let sub = UIColor(hex: 0x726A60)
        /// 占位 / 禁用
        static let muted = UIColor(hex: 0x9C948A)

        /// 品牌主色（深松绿）：主按钮 / 选中态 / Tab 选中 pill
        static let brand = UIColor(hex: 0x2F5D45)
        /// 品牌深色
        static let brandDark = UIColor(hex: 0x22422F)
        /// 品牌绿 tint（标签底）
        static let brandSoft = UIColor(hex: 0xE8F0EA)

        /// 木色（第二主色）：头像占位、功能图标
        static let wood = UIColor(hex: 0xA87A3E)
        /// 木色 tint
        static let woodSoft = UIColor(hex: 0xF4EFE6)

        /// 陶土橙（强调色）：Hero 数字、待办
        static let clay = UIColor(hex: 0xC15F2C)

        /// 语义色（一律颜色 + 文字双编码）
        static let success = UIColor(hex: 0x3D8B5F)
        static let successTint = UIColor(hex: 0xE9F1EA)
        static let warn = UIColor(hex: 0xC77B2A)
        static let warnTint = UIColor(hex: 0xFBEEDC)
        static let danger = UIColor(hex: 0xB03A2B)
        static let dangerTint = UIColor(hex: 0xFAE8E4)
        static let info = UIColor(hex: 0x3A6B96)
        static let infoTint = UIColor(hex: 0xE7EFF7)

        /// 微信绿
        static let wechat = UIColor(hex: 0x07C160)

        /// 老师回复标签紫
        static let violet = UIColor(hex: 0x7C3AED)
        static let violetTint = UIColor(hex: 0xF5F3FF)

        // MARK: - 随机色（柔和色板，适合头像底、标签底）

        /// 柔和预设色板（主色 + 浅色成对）
        private static let palette: [(main: UIColor, soft: UIColor)] = [
            (UIColor(hex: 0x2F5D45), UIColor(hex: 0xE8F0EA)), // 品牌绿
            (UIColor(hex: 0x3A6B96), UIColor(hex: 0xE7EFF7)), // 蓝
            (UIColor(hex: 0x7C3AED), UIColor(hex: 0xF5F3FF)), // 紫
            (UIColor(hex: 0xC15F2C), UIColor(hex: 0xFAEDE5)), // 陶橙
            (UIColor(hex: 0xA87A3E), UIColor(hex: 0xF6EEDF)), // 木色
            (UIColor(hex: 0xB03A2B), UIColor(hex: 0xFAE8E4)), // 砖红
            (UIColor(hex: 0x3D8B5F), UIColor(hex: 0xE9F1EA)), // 草绿
            (UIColor(hex: 0x9B59B6), UIColor(hex: 0xF3ECF9)), // 紫罗兰
            (UIColor(hex: 0x2E86AB), UIColor(hex: 0xE4F0F6)), // 湖蓝
            (UIColor(hex: 0xD98E32), UIColor(hex: 0xFBF1E0)), // 琥珀
            (UIColor(hex: 0x5B6B8C), UIColor(hex: 0xECEFF4)), // 靛灰
            (UIColor(hex: 0xC0507B), UIColor(hex: 0xFAEAF1))  // 玫红
        ]

        /// 每次调用随机返回一个柔和主色
        static func random() -> UIColor {
            palette[Int.random(in: 0..<palette.count)].main
        }

        /// 随机主色 + 对应浅色（如头像底/文字色）
        static func randomPair() -> (main: UIColor, soft: UIColor) {
            palette[Int.random(in: 0..<palette.count)]
        }

        /// 按字符串稳定取色（同一字符串永远得到同一颜色，适合头像/昵称底色）
        static func color(forSeed seed: String) -> UIColor {
            palette[abs(seed.hashValue) % palette.count].main
        }

        /// 按字符串稳定取色（主色 + 浅色）
        static func colorPair(forSeed seed: String) -> (main: UIColor, soft: UIColor) {
            palette[abs(seed.hashValue) % palette.count]
        }
    }

    // MARK: - 圆角

    enum Radius {
        static let card: CGFloat = 16
        static let button: CGFloat = 12
        static let input: CGFloat = 14
        static let icon: CGFloat = 10
        static let avatar: CGFloat = 16
    }

    // MARK: - 间距（8pt 网格）

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: - 阴影

    enum Shadow {
        /// 卡片双层暖阴影
        static let card: (offset: CGSize, radius: CGFloat, color: UIColor, opacity: Float) = (
            CGSize(width: 0, height: 4), 16, UIColor(hex: 0x2B2621).withAlphaComponent(0.05), 1
        )
    }
}

// MARK: - UIColor(hex:)

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255.0,
            green: CGFloat((hex >> 8) & 0xFF) / 255.0,
            blue: CGFloat(hex & 0xFF) / 255.0,
            alpha: alpha
        )
    }
}

// MARK: - 字体阶梯（PingFang 映射，后续可按需内嵌 Noto Serif/Sans SC）

extension UIFont {
    /// 屏幕标题 / 品牌名（衬线感粗体）
    static func appTitle(_ size: CGFloat = 28) -> UIFont {
        .systemFont(ofSize: size, weight: .bold)
    }

    /// Hero 数字（等宽数字防跳变）
    static func appHero(_ size: CGFloat = 30) -> UIFont {
        .monospacedDigitSystemFont(ofSize: size, weight: .bold)
    }

    /// 区块标题 / 列表主行
    static func appSection(_ size: CGFloat = 17) -> UIFont {
        .systemFont(ofSize: size, weight: .semibold)
    }

    /// 正文
    static func appBody(_ size: CGFloat = 14) -> UIFont {
        .systemFont(ofSize: size, weight: .regular)
    }

    /// 标签 / 元信息
    static func appLabel(_ size: CGFloat = 12) -> UIFont {
        .systemFont(ofSize: size, weight: .medium)
    }
}
