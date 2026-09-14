import UIKit
import SnapKit

/// 横向滚动的胶囊标签行（广场话题/筛选场景复用）
/// 选中态：品牌绿底白字；未选态：米白底 sub 字
final class TagChipRow: UIView {

    var onSelect: ((Int) -> Void)?

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private var buttons: [UIButton] = []
    private(set) var selectedIndex: Int = 0
    private var chips: [String]

    /// - Parameters:
    ///   - chips: 标签文案数组
    ///   - selectedIndex: 默认选中下标
    init(chips: [String], selectedIndex: Int = 0) {
        self.chips = chips
        self.selectedIndex = selectedIndex
        super.init(frame: .zero)

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = false
        addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }

        stack.axis = .horizontal
        stack.spacing = Theme.Spacing.s
        scrollView.addSubview(stack)
        stack.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.height.equalToSuperview()
        }

        rebuild()
    }

    /// 更新全部 chips（数据回来后再填充）
    func update(chips: [String], selectedIndex: Int = 0) {
        self.chips = chips
        rebuild(selectedIndex: selectedIndex)
    }

    /// 重建全部 chips（含选中态）
    func rebuild(selectedIndex: Int? = nil) {
        if let selectedIndex { self.selectedIndex = selectedIndex }
        buttons.forEach { $0.removeFromSuperview() }
        buttons.removeAll()

        for (i, title) in chips.enumerated() {
            let btn = UIButton(type: .system)
            btn.setTitle(title, for: .normal)
            btn.titleLabel?.font = .appLabel(13)
            btn.tag = i
            btn.addTarget(self, action: #selector(didTap(_:)), for: .touchUpInside)
            btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
            btn.layer.cornerRadius = 15  // 胶囊全圆
            stack.addArrangedSubview(btn)
            buttons.append(btn)
        }
        applySelection()
    }

    func select(index: Int) {
        guard index >= 0, index < buttons.count else { return }
        selectedIndex = index
        applySelection()
        // 滚动到选中项可见
        let btn = buttons[index]
        let target = CGPoint(x: btn.frame.midX - scrollView.bounds.width / 2, y: 0)
        scrollView.setContentOffset(CGPoint(x: max(0, target.x), y: 0), animated: true)
    }

    private func applySelection() {
        for (i, btn) in buttons.enumerated() {
            let selected = i == selectedIndex
            btn.backgroundColor = selected ? Theme.Color.brand : Theme.Color.surfaceAlt
            btn.setTitleColor(selected ? .white : Theme.Color.sub, for: .normal)
            btn.layer.borderWidth = selected ? 0 : 1
            btn.layer.borderColor = Theme.Color.line.cgColor
        }
    }

    @objc private func didTap(_ sender: UIButton) {
        select(index: sender.tag)
        onSelect?(sender.tag)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
