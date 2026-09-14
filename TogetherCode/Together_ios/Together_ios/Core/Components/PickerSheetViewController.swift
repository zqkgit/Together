import UIKit
import SnapKit

/// 通用底部选择弹层（出生年份等场景复用）
/// 半透明遮罩 + 底部圆角卡片：标题 + UIPickerView + 取消/确定
/// 使用：present(PickerSheetViewController(...), animated: false)，onConfirm 回调选中下标
final class PickerSheetViewController: UIViewController {

    /// 确认回调，参数为选中的 row 下标
    var onConfirm: ((Int) -> Void)?

    private let sheetTitle: String
    private let rows: [String]
    private let initialIndex: Int
    private let pickerView = UIPickerView()
    private var card: UIView!

    /// - Parameters:
    ///   - title: 弹层标题
    ///   - rows: 选项文案（单列）
    ///   - initialIndex: 初始选中下标
    init(title: String, rows: [String], initialIndex: Int = 0) {
        self.sheetTitle = title
        self.rows = rows
        self.initialIndex = min(max(initialIndex, 0), max(rows.count - 1, 0))
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        pickerView.selectRow(initialIndex, inComponent: 0, animated: false)
        // 初始位置在屏幕外，viewDidAppear 滑入
        card.transform = CGAffineTransform(translationX: 0, y: 320)
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
        dim.addTarget(self, action: #selector(didTapDim), for: .touchUpInside)
        view.addSubview(dim)
        dim.snp.makeConstraints { $0.edges.equalToSuperview() }

        // 底部卡片
        card = UIView()
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = 20
        card.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.addSubview(card)
        card.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
        }

        // 标题
        let titleLabel = UILabel()
        titleLabel.text = sheetTitle
        titleLabel.font = .appSection(16)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.textAlignment = .center
        card.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        // 选择器
        pickerView.delegate = self
        pickerView.dataSource = self
        card.addSubview(pickerView)
        pickerView.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview()
            $0.height.equalTo(200)
        }

        // 按钮行
        let cancelButton = makeActionButton("取消", tint: Theme.Color.sub, action: #selector(didTapCancel))
        let confirmButton = makeActionButton("确定", tint: .white, action: #selector(didTapConfirm))
        confirmButton.backgroundColor = Theme.Color.brand
        confirmButton.layer.cornerRadius = Theme.Radius.button

        let row = UIStackView(arrangedSubviews: [cancelButton, confirmButton])
        row.axis = .horizontal
        row.spacing = Theme.Spacing.l
        row.distribution = .fillEqually
        card.addSubview(row)
        row.snp.makeConstraints {
            $0.top.equalTo(pickerView.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(46)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    private func makeActionButton(_ title: String, tint: UIColor, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(tint, for: .normal)
        button.titleLabel?.font = .appSection(15)
        button.layer.cornerRadius = Theme.Radius.button
        button.backgroundColor = Theme.Color.surfaceAlt
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    // MARK: - 交互

    @objc private func didTapDim() { dismiss(animated: false) }

    @objc private func didTapCancel() { dismiss(animated: false) }

    @objc private func didTapConfirm() {
        let index = pickerView.selectedRow(inComponent: 0)
        dismiss(animated: false)
        onConfirm?(index)
    }
}

// MARK: - Picker

extension PickerSheetViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        rows.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        rows[row]
    }
}
