import UIKit
import SnapKit

/// 主题底部操作菜单（编辑 / 删除 / 取消），风格对齐 App：半透明遮罩 + 底部圆角卡片
/// 使用：present(ThemeActionSheet(...), animated: false)，onSelect 回调选中下标（0 起）
final class ThemeActionSheet: UIViewController {

    /// 选中回调，参数为 actions 下标
    var onSelect: ((Int) -> Void)?

    private let sheetTitle: String?
    private let actions: [(title: String, destructive: Bool)]
    private let cancelTitle: String
    private var card: UIView!

    /// - Parameters:
    ///   - title: 可选标题
    ///   - actions: 操作项（destructive 为红色警示项，如删除）
    ///   - cancelTitle: 取消按钮文案，默认「取消」
    init(title: String? = nil, actions: [(String, Bool)], cancelTitle: String = "取消") {
        self.sheetTitle = title
        self.actions = actions
        self.cancelTitle = cancelTitle
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        // 初始位置在屏幕外，viewDidAppear 滑入
        card.transform = CGAffineTransform(translationX: 0, y: 420)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 0.28, delay: 0, options: .curveEaseOut) {
            self.card.transform = .identity
        }
    }

    private func setupUI() {
        // 遮罩
        let dim = UIControl()
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        dim.addTarget(self, action: #selector(dismissSheet), for: .touchUpInside)
        view.addSubview(dim)
        dim.snp.makeConstraints { $0.edges.equalToSuperview() }

        // 底部卡片
        card = UIView()
        card.backgroundColor = Theme.Color.bg
        card.layer.cornerRadius = 20
        card.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.addSubview(card)
        card.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
        }

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.s
        stack.distribution = .fillEqually
        card.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-Theme.Spacing.xl)
        }

        // 标题（可选）
        if let sheetTitle, !sheetTitle.isEmpty {
            let titleLabel = UILabel()
            titleLabel.text = sheetTitle
            titleLabel.font = .appSection(15)
            titleLabel.textColor = Theme.Color.sub
            titleLabel.textAlignment = .center
            card.addSubview(titleLabel)
            titleLabel.snp.makeConstraints {
                $0.top.equalToSuperview().offset(Theme.Spacing.xl)
                $0.centerX.equalToSuperview()
            }
        }

        // 操作项
        for (index, action) in actions.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(action.title, for: .normal)
            button.titleLabel?.font = .appBody(15)
            button.setTitleColor(action.destructive ? .systemRed : Theme.Color.ink, for: .normal)
            button.backgroundColor = Theme.Color.surface
            button.layer.cornerRadius = 12
            button.clipsToBounds = true
            button.tag = index
            button.addTarget(self, action: #selector(didTapAction(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
            button.snp.makeConstraints { $0.height.equalTo(48) }
        }

        // 取消
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle(cancelTitle, for: .normal)
        cancelButton.titleLabel?.font = .appBody(15)
        cancelButton.setTitleColor(Theme.Color.sub, for: .normal)
        cancelButton.backgroundColor = Theme.Color.surface
        cancelButton.layer.cornerRadius = 12
        cancelButton.clipsToBounds = true
        cancelButton.addTarget(self, action: #selector(dismissSheet), for: .touchUpInside)
        card.addSubview(cancelButton)
        cancelButton.snp.makeConstraints {
            $0.height.equalTo(48)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-Theme.Spacing.s)
        }

        if sheetTitle != nil && !(sheetTitle?.isEmpty ?? true) {
            stack.snp.remakeConstraints {
                $0.top.equalToSuperview().offset(Theme.Spacing.xxxl)
                $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
                $0.bottom.equalTo(cancelButton.snp.top).offset(-Theme.Spacing.m)
            }
        } else {
            // 无标题：操作项顶部收紧到卡片内边距，底部同样绑定取消按钮上方（避免与 safeArea 约束冲突导致按钮被压缩）
            stack.snp.remakeConstraints {
                $0.top.equalToSuperview().offset(Theme.Spacing.m)
                $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
                $0.bottom.equalTo(cancelButton.snp.top).offset(-Theme.Spacing.m)
            }
        }
    }

    @objc private func didTapAction(_ sender: UIButton) {
        let index = sender.tag
        // 关键：先 dismiss，再在 completion 中回调 onSelect。
        // 否则 present 新页面的请求会与当前 sheet 的 present 冲突（UIKit 报
        // "presentation is in progress" 并忽略），导致点击「重新选择」等动作无反应。
        let handler = onSelect
        dismiss(animated: false) {
            handler?(index)
        }
    }

    @objc private func dismissSheet() {
        dismiss(animated: false)
    }
}
