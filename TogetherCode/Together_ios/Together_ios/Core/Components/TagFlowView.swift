import UIKit
import SnapKit

/// 流式布局标签视图（自动换行），用于搜索热词/历史场景
/// 标签为圆角 pill 样式，支持热词和历史两种风格
final class TagFlowView: UIView {

    enum Style {
        case hot       // 品牌色底白字
        case history   // 米白底深字
    }

    private var tags: [String] = []
    private var style: Style = .hot
    private var onTap: ((String) -> Void)?

    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        stack.axis = .horizontal
        stack.spacing = Theme.Spacing.s
        stack.alignment = .leading
        stack.distribution = .fill
        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    /// 配置标签数据和样式
    /// - Parameters:
    ///   - tags: 标签文字数组
    ///   - style: 样式（hot / history）
    ///   - onTap: 点击回调
    func configure(tags: [String], style: Style = .hot, onTap: @escaping (String) -> Void) {
        self.tags = tags
        self.style = style
        self.onTap = onTap
        rebuild()
    }

    private func rebuild() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        // 创建行容器
        var currentRow: UIStackView = makeRowStack()
        stack.addArrangedSubview(currentRow)

        var rowWidth: CGFloat = 0
        let maxWidth = UIScreen.main.bounds.width - Theme.Spacing.m * 2
        let spacing: CGFloat = Theme.Spacing.s

        for tag in tags {
            let pill = makePill(tag)
            let pillWidth = pill.intrinsicContentSize.width + 16 // 左右 padding 各8

            if rowWidth + pillWidth > maxWidth, rowWidth > 0 {
                // 换行
                currentRow = makeRowStack()
                stack.addArrangedSubview(currentRow)
                rowWidth = 0
            }

            currentRow.addArrangedSubview(pill)
            rowWidth += pillWidth + spacing
        }

        // 更新 stack 为垂直排列以支持换行
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.s
        invalidateIntrinsicContentSize()
    }

    private func makeRowStack() -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = Theme.Spacing.s
        row.alignment = .leading
        return row
    }

    private func makePill(_ text: String) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(text, for: .normal)
        btn.titleLabel?.font = .appLabel(13)
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        btn.layer.cornerRadius = 15
        btn.clipsToBounds = true
        btn.addTarget(self, action: #selector(didTapPill(_:)), for: .touchUpInside)

        switch style {
        case .hot:
            btn.setTitleColor(.white, for: .normal)
            btn.backgroundColor = Theme.Color.brand
        case .history:
            btn.setTitleColor(Theme.Color.ink, for: .normal)
            btn.backgroundColor = Theme.Color.surface.withAlphaComponent(0.9)
            btn.layer.borderWidth = 0.5
            btn.layer.borderColor = Theme.Color.muted.withAlphaComponent(0.3).cgColor
        }

        return btn
    }

    @objc private func didTapPill(_ sender: UIButton) {
        guard let title = sender.title(for: .normal) else { return }
        onTap?(title)
    }

    override var intrinsicContentSize: CGSize {
        return stack.intrinsicContentSize
    }
}