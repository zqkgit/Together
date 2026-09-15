import UIKit
import SnapKit

/// 轻量分段 Tab（文本 + 底部下划线，选中品牌绿；订单/列表筛选等场景复用）
/// 左对齐排列，选中项底部品牌绿短下划线
final class TabBarView: UIView {

    var onSelect: ((Int) -> Void)?

    private let titles: [String]
    private var buttons: [UIButton] = []
    private(set) var selectedIndex: Int = 0
    private let underline = UIView()
    private let underlineStack = UIStackView()

    init(titles: [String], selectedIndex: Int = 0) {
        self.titles = titles
        self.selectedIndex = selectedIndex
        super.init(frame: .zero)
        build()
        applySelection(animated: false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func select(index: Int) {
        guard index >= 0, index < buttons.count, index != selectedIndex else { return }
        selectedIndex = index
        applySelection(animated: true)
        onSelect?(index)
    }

    private func build() {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = Theme.Spacing.xl
        addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.bottom.leading.equalToSuperview()
        }

        for (i, title) in titles.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .appSection(16)
            button.tag = i
            button.addTarget(self, action: #selector(didTap(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
            buttons.append(button)
        }

        // 下划线（放在与按钮同层的容器，按选中按钮宽度移动）
        underline.backgroundColor = Theme.Color.brand
        underline.layer.cornerRadius = 1.5
        addSubview(underline)
    }

    private func applySelection(animated: Bool) {
        for (i, button) in buttons.enumerated() {
            let selected = i == selectedIndex
            button.setTitleColor(selected ? Theme.Color.brand : Theme.Color.sub, for: .normal)
            button.titleLabel?.font = .appSection(16)
        }
        guard let selected = buttons[safe: selectedIndex] else { return }
        let width = selected.titleLabel?.intrinsicContentSize.width ?? 40
        let x = selected.frame.minX
        underline.snp.remakeConstraints {
            $0.top.equalTo(selected.snp.bottom).offset(4)
            $0.leading.equalToSuperview().offset(x)
            $0.width.equalTo(width)
            $0.height.equalTo(3)
        }
        if animated {
            UIView.animate(withDuration: 0.2) { self.layoutIfNeeded() }
        } else {
            layoutIfNeeded()
        }
    }

    @objc private func didTap(_ sender: UIButton) {
        select(index: sender.tag)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
