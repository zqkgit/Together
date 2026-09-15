import UIKit
import SnapKit

/// 流式多选标签组件（兴趣方向等场景复用）
/// 未选：surfaceAlt 底 + sub 字；选中：brandSoft 底 + brand 字；胶囊 34 高全圆角
/// 自动换行、高度随内容自适应（intrinsicContentSize），父视图无需手动约束高度
final class TagSelectView: UIView {

    /// 选中变化回调（allowsMultipleSelection 控制单选/多选）
    var onSelectionChanged: ((Set<String>) -> Void)?
    /// 单选模式（点击已选项可取消）
    var allowsMultipleSelection = true

    private let options: [String]
    private var buttons: [UIButton] = []
    private var selected: Set<String>
    private var totalHeight: CGFloat = 0

    init(options: [String], selected: Set<String> = []) {
        self.options = options
        self.selected = selected
        super.init(frame: .zero)
        buildChips()
        refreshAppearance()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 当前选中的标签集合
    var selectedTags: Set<String> { selected }

    /// 外部设置选中态（如回显）
    func setSelected(_ tags: Set<String>) {
        selected = tags
        refreshAppearance()
    }

    // MARK: - 构建

    private func buildChips() {
        for (index, title) in options.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .appLabel(12)
            button.tag = index
            button.addTarget(self, action: #selector(didTap(_:)), for: .touchUpInside)
            button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
            button.layer.cornerRadius = 17
            addSubview(button)
            buttons.append(button)
        }
    }

    private func refreshAppearance() {
        for (index, button) in buttons.enumerated() {
            let isSelected = selected.contains(options[index])
            button.backgroundColor = isSelected ? Theme.Color.brandSoft : Theme.Color.surfaceAlt
            button.setTitleColor(isSelected ? Theme.Color.brand : Theme.Color.sub, for: .normal)
            // 选中加细描边，避免浅色底在高亮下不明显
            button.layer.borderWidth = isSelected ? 1 : 0
            button.layer.borderColor = isSelected ? Theme.Color.brand.withAlphaComponent(0.35).cgColor : UIColor.clear.cgColor
        }
    }

    // MARK: - 布局（自动换行）

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutChips()
    }

    private func layoutChips() {
        let gap: CGFloat = Theme.Spacing.m
        let lineHeight: CGFloat = 34
        var x: CGFloat = 0
        var y: CGFloat = 0
        for button in buttons {
            let size = button.intrinsicContentSize
            button.frame.size = size
            if x > 0 && x + size.width > bounds.width {
                x = 0
                y += lineHeight + gap
            }
            button.frame.origin = CGPoint(x: x, y: y)
            x += size.width + gap
        }
        let newHeight = buttons.isEmpty ? 0 : y + lineHeight
        if abs(newHeight - totalHeight) > 0.5 {
            totalHeight = newHeight
            invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: totalHeight)
    }

    // MARK: - 交互

    @objc private func didTap(_ sender: UIButton) {
        let tag = options[sender.tag]
        if selected.contains(tag) {
            selected.remove(tag)
        } else {
            if allowsMultipleSelection {
                selected.insert(tag)
            } else {
                selected = [tag]
            }
        }
        refreshAppearance()
        onSelectionChanged?(selected)
    }
}
