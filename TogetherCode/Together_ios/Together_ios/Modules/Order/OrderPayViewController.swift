import UIKit
import SnapKit
import Kingfisher

/// 订单支付（待支付订单确认，对齐 PR：选择上课的孩子 / 课程信息 / 费用明细 / 支付方式 / 实付 + 去支付）
/// 使用 UITableView 分组（.insetGrouped）承载卡片
/// 按后端实际：channel 仅 wechat_mini/ios_iap/offline；艺启余额支付未开通 → 置灰；材料包/优惠券后端暂无 → 省略
final class OrderPayViewController: BaseViewController {

    var onPaid: (() -> Void)?

    private let order: OrderItem
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let wechatRow = PayMethodRow()
    private let balanceRow = PayMethodRow()
    private var selectedChannel = "wechat_mini"

    /// 可切换的上课孩子（默认订单孩子优先）
    private var childList: [ChildItem] = []
    private var selectedChildId: String?

    init(order: OrderItem) {
        self.order = order
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureImmersiveNav(title: "确认支付")
        setupTableView()
        setupBottomBar()
        loadChildren()
    }

    // MARK: - UI

    private func setupTableView() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.alwaysBounceVertical = false
        tableView.showsVerticalScrollIndicator = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ChildPickerCell.self, forCellReuseIdentifier: ChildPickerCell.reuseID)
        tableView.register(CourseInfoCell.self, forCellReuseIdentifier: CourseInfoCell.reuseID)
        tableView.register(DetailRowCell.self, forCellReuseIdentifier: DetailRowCell.reuseID)
        tableView.register(PayMethodCell.self, forCellReuseIdentifier: PayMethodCell.reuseID)
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            $0.bottom.equalToSuperview()
        }
        tableView.contentInset = UIEdgeInsets(top: Theme.Spacing.s, left: 0, bottom: 64, right: 0)

        wechatRow.configure(
            icon: "message.fill",
            title: "微信支付",
            subtitle: nil,
            selected: true
        )
        wechatRow.onTap = { [weak self] in self?.selectChannel("wechat_mini") }

        balanceRow.configure(
            icon: "yensign.circle",
            title: "艺启余额",
            subtitle: "余额支付暂未开通",
            selected: false,
            enabled: false
        )
        balanceRow.onTap = { [weak self] in
            guard let self else { return }
            self.showToast("余额支付暂未开通，请使用微信支付")
        }
    }

    private func setupBottomBar() {
        let bottomBar = UIView()
        bottomBar.backgroundColor = Theme.Color.surface
        bottomBar.layer.shadowColor = UIColor.black.withAlphaComponent(0.06).cgColor
        bottomBar.layer.shadowOffset = CGSize(width: 0, height: -2)
        bottomBar.layer.shadowOpacity = 1
        bottomBar.layer.shadowRadius = 8
        view.addSubview(bottomBar)
        bottomBar.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.top.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-64)
        }

        let bottomStack = UIStackView()
        bottomStack.axis = .horizontal
        bottomStack.spacing = Theme.Spacing.m
        bottomStack.alignment = .center
        bottomBar.addSubview(bottomStack)
        bottomStack.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(44)
        }

        let amountLabel = UILabel()
        amountLabel.font = .appSection(16)
        amountLabel.textColor = Theme.Color.ink
        amountLabel.text = "实付 \(order.amountText)"

        let payButton = UIButton(type: .system)
        payButton.setTitle("去支付", for: .normal)
        payButton.titleLabel?.font = .appBody(15)
        payButton.setTitleColor(.white, for: .normal)
        payButton.backgroundColor = Theme.Color.brand
        payButton.layer.cornerRadius = 22
        payButton.addTarget(self, action: #selector(didTapPay), for: .touchUpInside)

        bottomStack.addArrangedSubview(amountLabel)
        bottomStack.addArrangedSubview(payButton)
        payButton.snp.makeConstraints {
            $0.width.equalTo(120)
            $0.height.equalTo(44)
        }
    }

    private func selectChannel(_ channel: String) {
        selectedChannel = channel
        wechatRow.setSelected(channel == "wechat_mini")
    }

    // MARK: - 孩子数据

    private func loadChildren() {
        // 先以订单孩子兜底展示
        let brief = order.child
        if let cid = brief?.child_id {
            selectedChildId = cid
            childList = [
                ChildItem(
                    child_id: cid,
                    nickname: brief?.nickname ?? "孩子",
                    avatar: nil,
                    birthday: nil,
                    gender: nil,
                    interests: nil,
                    total_remaining_lessons: nil,
                    balances: nil
                )
            ]
        }

        ChildService.fetchChildren { [weak self] result in
            guard let self, case .success(let list) = result, !list.isEmpty else { return }
            // 订单孩子排最前，其余按原顺序
            var ordered = list
            if let idx = ordered.firstIndex(where: { $0.child_id == self.order.child?.child_id }) {
                let item = ordered.remove(at: idx)
                ordered.insert(item, at: 0)
            }
            self.childList = ordered
            if self.selectedChildId == nil {
                self.selectedChildId = ordered.first?.child_id
            }
            self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
        }
    }

    // MARK: - 支付

    @objc private func didTapPay() {
        guard let orderId = order.order_id else { return }
        showLoading()
        OrderService.payOrder(orderId: orderId, channel: selectedChannel, childId: selectedChildId) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success:
                self.showToast("支付成功")
                self.onPaid?()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    self.navigationController?.popViewController(animated: true)
                }
            case .failure(let error):
                self.showToast(error.message ?? "支付失败")
            }
        }
    }
}

// MARK: - UITableViewDataSource / Delegate

extension OrderPayViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { 4 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1          // 选择上课的孩子
        case 1: return 1          // 课程信息
        case 2: return 2          // 费用明细：课程费用 / 实付
        case 3: return 2          // 支付方式：微信 / 艺启余额
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: ChildPickerCell.reuseID, for: indexPath) as! ChildPickerCell
            cell.configure(children: childList, selectedId: selectedChildId)
            cell.onPick = { [weak self] childId in
                guard let self, self.selectedChildId != childId else { return }
                self.selectedChildId = childId
                self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
            }
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: CourseInfoCell.reuseID, for: indexPath) as! CourseInfoCell
            cell.configure(with: order)
            return cell
        case 2:
            let cell = tableView.dequeueReusableCell(withIdentifier: DetailRowCell.reuseID, for: indexPath) as! DetailRowCell
            if indexPath.row == 0 {
                cell.configure(title: "课程费用", value: order.amountText, emphasized: false)
            } else {
                cell.configure(title: "实付", value: order.amountText, emphasized: true)
            }
            return cell
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: PayMethodCell.reuseID, for: indexPath) as! PayMethodCell
            cell.configure(with: indexPath.row == 0 ? wechatRow : balanceRow)
            return cell
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0: return 96
        case 1: return 96
        default: return 52
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let titles = ["选择上课的孩子", "课程信息", "费用明细", "支付方式"]
        let container = UIView()
        container.backgroundColor = .clear
        let label = UILabel()
        label.text = titles[section]
        label.font = .appBody(16)
        label.textColor = Theme.Color.ink
        container.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalToSuperview()
            $0.centerY.equalToSuperview()
        }
        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 40 }
}

// MARK: - Cells

/// 选择上课的孩子：横向头像 + 名字 + 勾选角标，可切换
private final class ChildPickerCell: UITableViewCell {

    static let reuseID = "ChildPickerCell"

    var onPick: ((String) -> Void)?

    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Theme.Color.surface
        contentView.backgroundColor = Theme.Color.surface

        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.isDirectionalLockEnabled = true
        contentView.addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }

        stack.axis = .horizontal
        stack.spacing = Theme.Spacing.xl
        stack.alignment = .center
        scrollView.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.bottom.equalToSuperview()
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(children: [ChildItem], selectedId: String?) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for child in children {
            let view = ChildPickView()
            view.configure(child: child, selected: child.child_id == selectedId)
            view.onTap = { [weak self] in self?.onPick?(child.child_id) }
            stack.addArrangedSubview(view)
            view.snp.makeConstraints { $0.width.equalTo(64) }
        }
    }
}

/// 单个孩子项：圆形头像 + 名字 + 右上角勾选
private final class ChildPickView: UIView {

    var onTap: (() -> Void)?

    private let avatarView = UIImageView()
    private let initialLabel = UILabel()
    private let nameLabel = UILabel()
    private let checkView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        avatarView.backgroundColor = Theme.Color.brand.withAlphaComponent(0.12)
        avatarView.layer.cornerRadius = 22
        avatarView.clipsToBounds = true
        avatarView.contentMode = .scaleAspectFill

        initialLabel.font = .appBody(18)
        initialLabel.textColor = Theme.Color.brand
        initialLabel.textAlignment = .center

        nameLabel.font = .appLabel(12)
        nameLabel.textColor = Theme.Color.ink
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 1

        checkView.contentMode = .scaleAspectFit

        addSubview(avatarView)
        addSubview(initialLabel)
        addSubview(nameLabel)
        addSubview(checkView)

        avatarView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(44)
        }
        initialLabel.snp.makeConstraints { $0.edges.equalTo(avatarView) }
        checkView.snp.makeConstraints {
            $0.trailing.equalTo(avatarView.snp.trailing).offset(4)
            $0.top.equalTo(avatarView.snp.top).offset(-4)
            $0.width.height.equalTo(18)
        }
        nameLabel.snp.makeConstraints {
            $0.top.equalTo(avatarView.snp.bottom).offset(6)
            $0.centerX.equalToSuperview()
            $0.bottom.equalToSuperview().inset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview()
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(child: ChildItem, selected: Bool) {
        nameLabel.text = child.nickname
        if let avatar = child.avatar, !avatar.isEmpty, let url = URL(string: avatar) {
            initialLabel.isHidden = true
            avatarView.kf.setImage(with: url)
        } else {
            initialLabel.isHidden = false
            avatarView.image = nil
            initialLabel.text = String(child.nickname.prefix(1))
        }
        checkView.image = UIImage(systemName: selected ? "checkmark.circle.fill" : "circle")
        checkView.tintColor = selected ? Theme.Color.brand : Theme.Color.line
    }

    @objc private func handleTap() {
        onTap?()
    }
}

/// 课程信息卡：课程名·节数 + 授课方
private final class CourseInfoCell: UITableViewCell {

    static let reuseID = "CourseInfoCell"

    private let titleLabel = UILabel()
    private let studioLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Theme.Color.surface
        contentView.backgroundColor = Theme.Color.surface

        titleLabel.font = .appSection(17)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 2
        studioLabel.font = .appLabel(14)
        studioLabel.textColor = Theme.Color.sub
        studioLabel.numberOfLines = 2

        let stack = UIStackView(arrangedSubviews: [titleLabel, studioLabel])
        stack.axis = .vertical
        stack.spacing = 8
        contentView.addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(Theme.Spacing.l) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with order: OrderItem) {
        titleLabel.text = order.courseTitleWithLessons
        studioLabel.text = order.studioTeacherText
    }
}

/// 费用明细行：左标题 + 右数值（实付高亮）
private final class DetailRowCell: UITableViewCell {

    static let reuseID = "DetailRowCell"

    private let titleLabel = UILabel()
    private let valueLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Theme.Color.surface
        contentView.backgroundColor = Theme.Color.surface

        titleLabel.font = .appLabel(14)
        titleLabel.textColor = Theme.Color.sub
        valueLabel.font = .appBody(16)
        valueLabel.textColor = Theme.Color.ink
        valueLabel.textAlignment = .right
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.centerY.equalToSuperview().inset(Theme.Spacing.l)
        }
        valueLabel.snp.makeConstraints {
            $0.trailing.centerY.equalToSuperview().inset(Theme.Spacing.l)
            $0.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(Theme.Spacing.m)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(title: String, value: String, emphasized: Bool) {
        titleLabel.text = title
        valueLabel.text = value
        valueLabel.font = emphasized ? .appBody(16) : .appBody(16)
        valueLabel.textColor = emphasized ? Theme.Color.brand : Theme.Color.ink
    }
}

private final class PayMethodCell: UITableViewCell {

    static let reuseID = "PayMethodCell"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Theme.Color.surface
        contentView.backgroundColor = Theme.Color.surface
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(with row: PayMethodRow) {
        contentView.subviews.forEach { $0.removeFromSuperview() }
        contentView.addSubview(row)
        row.snp.makeConstraints { $0.edges.equalToSuperview() }
    }
}

// MARK: - 支付方式行

private final class PayMethodRow: UIView {

    var onTap: (() -> Void)?

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let checkView = UIImageView()
    private var isEnabled = true

    override init(frame: CGRect) {
        super.init(frame: frame)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(icon: String, title: String, subtitle: String?, selected: Bool, enabled: Bool = true) {
        isEnabled = enabled
        isUserInteractionEnabled = enabled

        [iconView, titleLabel, subtitleLabel, checkView].forEach { addSubview($0) }

        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = Theme.Color.brand
        iconView.contentMode = .scaleAspectFit
        iconView.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(24)
        }

        titleLabel.text = title
        titleLabel.font = .appBody(15)
        titleLabel.textColor = enabled ? Theme.Color.ink : Theme.Color.sub
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(iconView.snp.trailing).offset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
        }

        if let subtitle {
            subtitleLabel.text = subtitle
            subtitleLabel.font = .appLabel(12)
            subtitleLabel.textColor = Theme.Color.sub
            subtitleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
            subtitleLabel.snp.makeConstraints {
                $0.leading.equalTo(titleLabel.snp.trailing).offset(Theme.Spacing.s)
                $0.centerY.equalToSuperview()
                $0.trailing.lessThanOrEqualTo(checkView.snp.leading).offset(-Theme.Spacing.s)
            }
        }

        checkView.image = UIImage(systemName: selected ? "checkmark.circle.fill" : "circle")
        checkView.tintColor = selected ? Theme.Color.brand : Theme.Color.line
        checkView.contentMode = .scaleAspectFit
        checkView.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(22)
        }
    }

    func setSelected(_ selected: Bool) {
        checkView.image = UIImage(systemName: selected ? "checkmark.circle.fill" : "circle")
        checkView.tintColor = selected ? Theme.Color.brand : Theme.Color.line
    }

    @objc private func handleTap() {
        guard isEnabled else { return }
        onTap?()
    }
}
