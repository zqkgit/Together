import UIKit
import SnapKit

// MARK: - 日期区间筛选栏

/// 通用日期区间筛选组件，嵌入页面顶部
/// 提供「本月 / 上月 / 近3月 / 自定义」快捷选项
final class DateRangeFilterBar: UIView {

    // MARK: - 回调

    /// 用户选择新区间后触发，startDate/endDate 格式 yyyy-MM-dd
    var onRangeChange: ((_ startDate: String, _ endDate: String) -> Void)?

    // MARK: - 状态

    /// 当前选中的预设类型（nil 表示自定义）
    private(set) var selectedPreset: DateRangePreset?
    private(set) var startDate: String
    private(set) var endDate: String

    // MARK: - 子视图

    private let filterButton = UIButton(type: .system)
    private let dropdown = DateRangeDropdown()

    /// 用于找到最顶层的 ViewController 来 present 日期选择器
    private weak var hostViewController: UIViewController?

    // MARK: - Init

    init() {
        // 默认本月
        let (s, e) = DateRangePreset.thisMonth.dates()
        self.startDate = s
        self.endDate = e
        self.selectedPreset = .thisMonth
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 设置宿主 VC（用于 present 日期选择器）
    func setHostViewController(_ vc: UIViewController) {
        hostViewController = vc
    }

    // MARK: - 布局

    private func setupUI() {
        backgroundColor = Theme.Color.bg

        filterButton.titleLabel?.font = .appBody(13)
        filterButton.setTitleColor(Theme.Color.ink, for: .normal)
        filterButton.setImage(UIImage(systemName: "calendar"), for: .normal)
        filterButton.tintColor = Theme.Color.brand
        filterButton.semanticContentAttribute = .forceLeftToRight
        filterButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 4)
        filterButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 0)
        filterButton.contentHorizontalAlignment = .left
        filterButton.addTarget(self, action: #selector(toggleDropdown), for: .touchUpInside)
        updateButtonText()
        addSubview(filterButton)
        filterButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
            $0.height.equalTo(32)
        }

        dropdown.isHidden = true
        dropdown.onSelect = { [weak self] preset in
            self?.handlePreset(preset)
        }
        addSubview(dropdown)
        dropdown.snp.makeConstraints {
            $0.top.equalTo(filterButton.snp.bottom).offset(4)
            $0.leading.equalTo(filterButton)
            $0.width.equalTo(160)
        }

        // 点击空白关闭
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(hideDropdown)))
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 40)
    }

    // MARK: - 动作

    @objc private func toggleDropdown() {
        if dropdown.isHidden {
            showDropdown()
        } else {
            hideDropdown()
        }
    }

    private func showDropdown() {
        dropdown.alpha = 0
        dropdown.isHidden = false
        dropdown.highlight(preset: selectedPreset)
        UIView.animate(withDuration: 0.2) {
            self.dropdown.alpha = 1
        }
    }

    @objc private func hideDropdown() {
        guard !dropdown.isHidden else { return }
        UIView.animate(withDuration: 0.15, animations: {
            self.dropdown.alpha = 0
        }, completion: { _ in
            self.dropdown.isHidden = true
        })
    }

    private func handlePreset(_ preset: DateRangePreset) {
        if case .custom = preset {
            hideDropdown()
            presentCustomDatePicker()
            return
        }
        let (s, e) = preset.dates()
        selectedPreset = preset
        startDate = s
        endDate = e
        updateButtonText()
        hideDropdown()
        onRangeChange?(s, e)
    }

    /// 外部设置自定义区间（如从日期选择器回传）
    func setCustomRange(start: String, end: String) {
        selectedPreset = nil
        startDate = start
        endDate = end
        updateButtonText()
        onRangeChange?(start, end)
    }

    private func updateButtonText() {
        if let preset = selectedPreset {
            filterButton.setTitle(preset.title, for: .normal)
        } else {
            // 自定义：显示日期区间缩写
            let s = String(startDate.suffix(5)) // MM-dd
            let e = String(endDate.suffix(5))
            filterButton.setTitle("\(s) ~ \(e)", for: .normal)
        }
    }

    // MARK: - 自定义日期选择器

    private func presentCustomDatePicker() {
        guard let host = hostViewController else { return }
        let pickerVC = CustomDateRangeViewController(start: startDate, end: endDate)
        pickerVC.onConfirm = { [weak self] start, end in
            self?.setCustomRange(start: start, end: end)
        }
        let nav = UINavigationController(rootViewController: pickerVC)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        host.present(nav, animated: true)
    }
}

// MARK: - 预设区间枚举

enum DateRangePreset: CaseIterable {
    case thisMonth
    case lastMonth
    case last3Months
    case custom

    var title: String {
        switch self {
        case .thisMonth: return "本月"
        case .lastMonth: return "上月"
        case .last3Months: return "近3月"
        case .custom: return "自定义"
        }
    }

    /// 返回 (startDate, endDate)，格式 yyyy-MM-dd
    func dates() -> (String, String) {
        let cal = Calendar.current
        let now = Date()
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        switch self {
        case .thisMonth:
            let start = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            let end = cal.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
            return (fmt.string(from: start), fmt.string(from: end))
        case .lastMonth:
            let thisMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            let start = cal.date(byAdding: DateComponents(month: -1), to: thisMonthStart)!
            let end = cal.date(byAdding: DateComponents(day: -1), to: thisMonthStart)!
            return (fmt.string(from: start), fmt.string(from: end))
        case .last3Months:
            let thisMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!
            let start = cal.date(byAdding: DateComponents(month: -3), to: thisMonthStart)!
            let end = cal.date(byAdding: DateComponents(day: -1), to: thisMonthStart)!
            return (fmt.string(from: start), fmt.string(from: end))
        case .custom:
            // 自定义需要外部设置，这里返回本月作为默认值
            return DateRangePreset.thisMonth.dates()
        }
    }
}

// MARK: - 下拉菜单

private final class DateRangeDropdown: UIView {

    var onSelect: ((DateRangePreset) -> Void)?

    private let stack = UIStackView()
    private var buttons: [UIButton] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.Color.surface
        layer.cornerRadius = Theme.Radius.card
        layer.shadowColor = UIColor.black.withAlphaComponent(0.1).cgColor
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 12
        layer.shadowOpacity = 1
        layer.masksToBounds = false

        stack.axis = .vertical
        stack.spacing = 0
        addSubview(stack)
        stack.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        for preset in DateRangePreset.allCases {
            let btn = UIButton(type: .system)
            btn.titleLabel?.font = .appBody(14)
            btn.setTitleColor(Theme.Color.ink, for: .normal)
            btn.setTitle(preset.title, for: .normal)
            btn.contentHorizontalAlignment = .left
            btn.contentEdgeInsets = UIEdgeInsets(top: 12, left: 16, bottom: 12, right: 16)
            btn.tag = preset.index
            btn.addTarget(self, action: #selector(didSelect(_:)), for: .touchUpInside)
            stack.addArrangedSubview(btn)
            buttons.append(btn)

            // 分隔线（非最后一个）
            if preset != DateRangePreset.allCases.last {
                let divider = UIView()
                divider.backgroundColor = Theme.Color.line
                divider.snp.makeConstraints { $0.height.equalTo(0.5) }
                stack.addArrangedSubview(divider)
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func didSelect(_ sender: UIButton) {
        let index = sender.tag
        guard let preset = DateRangePreset.allCases.enumerated().first(where: { $0.offset == index })?.element else { return }
        onSelect?(preset)
    }

    func highlight(preset: DateRangePreset?) {
        for (i, btn) in buttons.enumerated() {
            let p = DateRangePreset.allCases[i]
            let isSelected = (p == preset) || (preset == nil && p == .custom)
            btn.setTitleColor(isSelected ? Theme.Color.brand : Theme.Color.ink, for: .normal)
            btn.titleLabel?.font = isSelected ? .appSection(14) : .appBody(14)
        }
    }
}

// MARK: - DateRangePreset index

private extension DateRangePreset {
    var index: Int {
        switch self {
        case .thisMonth: return 0
        case .lastMonth: return 1
        case .last3Months: return 2
        case .custom: return 3
        }
    }
}

// MARK: - 自定义日期区间选择器

final class CustomDateRangeViewController: UIViewController {

    var onConfirm: ((_ startDate: String, _ endDate: String) -> Void)?

    private static let minDate: Date = {
        let cal = Calendar.current
        return cal.date(from: DateComponents(year: 2026, month: 1, day: 1))!
    }()

    private let fmt = DateFormatter()
    private var startDate: Date
    private var endDate: Date
    private var activeField: ActiveField = .start

    private let startField = UIButton(type: .system)
    private let endField = UIButton(type: .system)
    private let dashLabel = UILabel()
    private let datePicker = UIDatePicker()

    private enum ActiveField { case start, end }

    init(start: String, end: String) {
        fmt.dateFormat = "yyyy-MM-dd"
        self.startDate = fmt.date(from: start) ?? Date()
        self.endDate = fmt.date(from: end) ?? Date()
        super.init(nibName: nil, bundle: nil)
        title = "选择日期区间"
        let cancelBtn = UIButton(type: .system)
        cancelBtn.setTitle("取消", for: .normal)
        cancelBtn.titleLabel?.font = .appBody(14)
        cancelBtn.setTitleColor(Theme.Color.sub, for: .normal)
        cancelBtn.snp.makeConstraints { $0.width.equalTo(72); $0.height.equalTo(32) }
        cancelBtn.addTarget(self, action: #selector(dismissSelf), for: .touchUpInside)
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: cancelBtn)

        let confirmBtn = UIButton(type: .system)
        confirmBtn.setTitle("确定", for: .normal)
        confirmBtn.titleLabel?.font = .appBody(14)
        confirmBtn.setTitleColor(.white, for: .normal)
        confirmBtn.backgroundColor = Theme.Color.brand
        confirmBtn.layer.cornerRadius = 16
        confirmBtn.snp.makeConstraints { $0.width.equalTo(72); $0.height.equalTo(32) }
        confirmBtn.addTarget(self, action: #selector(confirm), for: .touchUpInside)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: confirmBtn)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg

        // 日期选择行：[开始日期] — [结束日期]
        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 0
        view.addSubview(row)
        row.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(44)
        }

        // 开始日期框
        configureFieldButton(startField)
        startField.addTarget(self, action: #selector(tapStartField), for: .touchUpInside)
        row.addArrangedSubview(startField)
        startField.snp.makeConstraints { $0.height.equalTo(44) }

        // 连接线
        dashLabel.text = "—"
        dashLabel.font = .appBody(16)
        dashLabel.textColor = Theme.Color.muted
        dashLabel.textAlignment = .center
        dashLabel.setContentHuggingPriority(.required, for: .horizontal)
        dashLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        row.addArrangedSubview(dashLabel)
        dashLabel.snp.makeConstraints { $0.width.equalTo(24) }

        // 结束日期框
        configureFieldButton(endField)
        endField.addTarget(self, action: #selector(tapEndField), for: .touchUpInside)
        row.addArrangedSubview(endField)
        endField.snp.makeConstraints { $0.height.equalTo(44) }

        // 开始/结束等宽
        startField.snp.makeConstraints { $0.width.equalTo(endField) }

        // DatePicker
        datePicker.datePickerMode = .date
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.locale = Locale(identifier: "zh_CN")
        datePicker.minimumDate = Self.minDate
        datePicker.maximumDate = Date()
        datePicker.addTarget(self, action: #selector(pickerChanged), for: .valueChanged)
        view.addSubview(datePicker)
        datePicker.snp.makeConstraints {
            $0.top.equalTo(row.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview()
        }

        updateFieldDisplay()
        selectField(.start)
    }

    private func configureFieldButton(_ btn: UIButton) {
        btn.titleLabel?.font = .appSection(15)
        btn.setTitleColor(Theme.Color.ink, for: .normal)
        btn.backgroundColor = Theme.Color.surface
        btn.layer.cornerRadius = 8
        btn.layer.borderWidth = 1.5
        btn.layer.borderColor = UIColor.clear.cgColor
    }

    private func updateFieldDisplay() {
        startField.setTitle(fmt.string(from: startDate), for: .normal)
        endField.setTitle(fmt.string(from: endDate), for: .normal)
    }

    private func selectField(_ field: ActiveField) {
        activeField = field
        // 高亮选中框
        startField.layer.borderColor = field == .start ? Theme.Color.brand.cgColor : UIColor.clear.cgColor
        endField.layer.borderColor = field == .end ? Theme.Color.brand.cgColor : UIColor.clear.cgColor
        startField.setTitleColor(field == .start ? Theme.Color.brand : Theme.Color.ink, for: .normal)
        endField.setTitleColor(field == .end ? Theme.Color.brand : Theme.Color.ink, for: .normal)
        // 同步 picker
        switch field {
        case .start:
            datePicker.date = startDate
            datePicker.minimumDate = Self.minDate
            datePicker.maximumDate = endDate
        case .end:
            datePicker.date = endDate
            datePicker.minimumDate = max(startDate, Self.minDate)
            datePicker.maximumDate = Date()
        }
    }

    @objc private func tapStartField() { selectField(.start) }
    @objc private func tapEndField() { selectField(.end) }

    @objc private func pickerChanged() {
        switch activeField {
        case .start:
            startDate = datePicker.date
            // 如果开始日期超过结束日期，自动调整结束日期
            if startDate > endDate { endDate = startDate }
        case .end:
            endDate = datePicker.date
            // 如果结束日期早于开始日期，自动调整开始日期
            if endDate < startDate { startDate = endDate }
        }
        updateFieldDisplay()
        selectField(activeField) // 刷新 minimumDate/maximumDate
    }

    @objc private func dismissSelf() { dismiss(animated: true) }

    @objc private func confirm() {
        // 保证 end >= start
        if endDate < startDate { swap(&startDate, &endDate) }
        let s = fmt.string(from: startDate)
        let e = fmt.string(from: endDate)
        onConfirm?(s, e)
        dismiss(animated: true)
    }
}