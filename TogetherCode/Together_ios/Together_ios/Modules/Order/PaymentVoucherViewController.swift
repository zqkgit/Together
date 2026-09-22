import UIKit
import SnapKit
import HXPhotoPicker
import SwiftyJSON

/// 线下付款凭证（替代旧在线支付页）
/// 平台不经手学费：家长与机构线下结算后，在此选择付款方式、上传付款凭证、填写备注，
/// 机构在后台核对到账并「确认收款」后发放全部课时。
/// 现金可免凭证；微信/支付宝/银行/收款码/其他等线上转账必须上传至少 1 张凭证截图。
final class PaymentVoucherViewController: BaseViewController {

    /// 提交成功回调（列表 / 详情刷新）
    var onSubmitted: (() -> Void)?

    private let order: OrderItem
    private var selectedMethod: PayMethod = .wechat
    private var pickedImages: [UIImage] = []

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let bottomBar = UIView()
    private var voucherCell: VoucherEditCell?

    init(order: OrderItem) {
        self.order = order
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
        // 凭证被驳回后重新上传：预选上次选择的支付方式（凭证图需重新上传）
        if let raw = order.rejectedPayment?.pay_method ?? order.rejectedPayment?.channel,
           let previous = PayMethod.from(raw) {
            selectedMethod = previous
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private enum Section: Int, CaseIterable {
        case tip, course, method, voucher, note
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureImmersiveNav(title: "线下付款")
        setupBottomBar()
        setupTableView()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    private func setupTableView() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(TipCell.self, forCellReuseIdentifier: TipCell.reuseID)
        tableView.register(VoucherCourseCell.self, forCellReuseIdentifier: VoucherCourseCell.reuseID)
        tableView.register(MethodRadioCell.self, forCellReuseIdentifier: MethodRadioCell.reuseID)
        tableView.register(VoucherEditCell.self, forCellReuseIdentifier: VoucherEditCell.reuseID)
        tableView.register(NoteCell.self, forCellReuseIdentifier: NoteCell.reuseID)
        tableView.contentInset = UIEdgeInsets(top: Theme.Spacing.s, left: 0, bottom: 96, right: 0)
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            $0.bottom.equalTo(bottomBar.snp.top)
        }
    }

    private func setupBottomBar() {
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

        let amountLabel = UILabel()
        amountLabel.font = .appSection(16)
        amountLabel.textColor = Theme.Color.ink
        amountLabel.text = "应付 \(order.amountText)"

        let submitButton = UIButton(type: .system)
        submitButton.setTitle("提交凭证", for: .normal)
        submitButton.titleLabel?.font = .appBody(15)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.backgroundColor = Theme.Color.brand
        submitButton.layer.cornerRadius = 22
        submitButton.addTarget(self, action: #selector(didTapSubmit), for: .touchUpInside)

        bottomBar.addSubview(amountLabel)
        bottomBar.addSubview(submitButton)
        amountLabel.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
        }
        submitButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
            $0.width.equalTo(140)
            $0.height.equalTo(44)
        }
    }

    // MARK: - 选图

    private func pickImages() {
        view.endEditing(true)
        let remain = 9 - pickedImages.count
        guard remain > 0 else { showToast("最多上传 9 张凭证"); return }
        var config = PickerConfiguration()
        config.selectOptions = [.photo]
        config.maximumSelectedCount = remain
        let picker = PhotoPickerController(config: config)
        picker.finishHandler = { [weak self] result, _ in
            guard let self else { return }
            result.getImage(targetSize: CGSize(width: 1600, height: 1600)) { [weak self] images in
                guard let self else { return }
                for image in images where self.pickedImages.count < 9 {
                    self.pickedImages.append(image)
                }
                self.voucherCell?.reload(images: self.pickedImages)
            }
        }
        present(picker, animated: true)
    }

    // MARK: - 提交

    @objc private func didTapSubmit() {
        view.endEditing(true)
        guard let orderId = order.order_id else { return }

        if selectedMethod.isOnline && pickedImages.isEmpty {
            showToast("请上传\(selectedMethod.text)的付款凭证截图")
            return
        }

        let note = (view.viewWithTag(NoteCell.textFieldTag) as? UITextField)?.text?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        showLoading("提交中...")
        let datas = pickedImages.compactMap { $0.jpegData(compressionQuality: 0.8) }

        let submit: ([String]) -> Void = { urls in
            OrderService.submitPaymentVoucher(
                orderId: orderId,
                payMethod: self.selectedMethod.code,
                voucherImages: urls,
                note: note
            ) { [weak self] result in
                guard let self else { return }
                self.hideLoading()
                switch result {
                case .success:
                    self.showToast("凭证已提交，等待机构确认")
                    self.onSubmitted?()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        self.navigationController?.popViewController(animated: true)
                    }
                case .failure(let error):
                    self.showToast(error.message ?? "提交失败")
                }
            }
        }

        if datas.isEmpty {
            submit([])
        } else {
            APIClient.shared.upload(files: datas, folder: "voucher") { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let json):
                    let urls = json["urls"].arrayValue.map { $0.stringValue }
                    if urls.isEmpty {
                        self.hideLoading()
                        self.showToast("凭证上传失败")
                        return
                    }
                    submit(urls)
                case .failure(let error):
                    self.hideLoading()
                    self.showToast(error.message)
                }
            }
        }
    }
}

// MARK: - DataSource / Delegate

extension PaymentVoucherViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { Section.allCases.count }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .tip: return 1
        case .course: return 1
        case .method: return PayMethod.allCases.count
        case .voucher: return 1
        case .note: return 1
        case .none: return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(rawValue: indexPath.section) {
        case .tip:
            let cell = tableView.dequeueReusableCell(withIdentifier: TipCell.reuseID, for: indexPath) as! TipCell
            cell.configure(rejectReason: order.rejectedPayment?.reject_reason)
            return cell
        case .course:
            let cell = tableView.dequeueReusableCell(withIdentifier: VoucherCourseCell.reuseID, for: indexPath) as! VoucherCourseCell
            cell.configure(with: order)
            return cell
        case .method:
            let cell = tableView.dequeueReusableCell(withIdentifier: MethodRadioCell.reuseID, for: indexPath) as! MethodRadioCell
            let method = PayMethod.allCases[indexPath.row]
            cell.configure(method: method, selected: method == selectedMethod)
            return cell
        case .voucher:
            let cell = tableView.dequeueReusableCell(withIdentifier: VoucherEditCell.reuseID, for: indexPath) as! VoucherEditCell
            voucherCell = cell
            cell.onAdd = { [weak self] in self?.pickImages() }
            cell.onRemove = { [weak self] idx in
                guard let self, idx < self.pickedImages.count else { return }
                self.pickedImages.remove(at: idx)
                self.voucherCell?.reload(images: self.pickedImages)
            }
            cell.reload(images: pickedImages)
            return cell
        case .note:
            let cell = tableView.dequeueReusableCell(withIdentifier: NoteCell.reuseID, for: indexPath) as! NoteCell
            return cell
        case .none:
            return UITableViewCell()
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        view.endEditing(true)
        guard Section(rawValue: indexPath.section) == .method else { return }
        selectedMethod = PayMethod.allCases[indexPath.row]
        tableView.reloadSections(IndexSet(integer: Section.method.rawValue), with: .none)
        tableView.reloadSections(IndexSet(integer: Section.voucher.rawValue), with: .none)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let titles: [String] = ["", "", "付款方式", voucherHeaderTitle, "备注"]
        let container = UIView()
        container.backgroundColor = .clear
        let label = UILabel()
        label.text = titles[section]
        label.font = .appBody(15)
        label.textColor = Theme.Color.sub
        label.numberOfLines = 0
        container.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(4)
            $0.trailing.equalToSuperview().inset(4)
            $0.top.bottom.equalToSuperview().inset(6)
        }
        return container
    }

    private var voucherHeaderTitle: String {
        selectedMethod.isOnline
            ? "付款凭证（必传，转账 / 付款截图，最多 9 张）"
            : "付款凭证（现金可不上传，由机构核对登记）"
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        switch Section(rawValue: section) {
        case .tip, .course: return 8
        case .voucher: return 40
        default: return 36
        }
    }
}

// MARK: - 提示卡

private final class TipCell: UITableViewCell {
    static let reuseID = "TipCell"
    private let box = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let descLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        box.backgroundColor = Theme.Color.brand.withAlphaComponent(0.08)
        box.layer.cornerRadius = Theme.Radius.card
        contentView.addSubview(box)
        box.snp.makeConstraints { $0.edges.equalToSuperview() }

        iconView.image = UIImage(systemName: "info.circle.fill")
        iconView.tintColor = Theme.Color.brand
        iconView.contentMode = .scaleAspectFit
        box.addSubview(iconView)
        iconView.snp.makeConstraints {
            $0.leading.top.equalToSuperview().inset(Theme.Spacing.l)
            $0.width.height.equalTo(20)
        }

        titleLabel.font = .appBody(14)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 0
        box.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(iconView.snp.trailing).offset(Theme.Spacing.s)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalTo(iconView)
        }

        descLabel.font = .appLabel(13)
        descLabel.textColor = Theme.Color.sub
        descLabel.numberOfLines = 0
        box.addSubview(descLabel)
        descLabel.snp.makeConstraints {
            $0.leading.trailing.equalTo(titleLabel)
            $0.top.equalTo(titleLabel.snp.bottom).offset(6)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    func configure(rejectReason: String?) {
        if let reason = rejectReason, !reason.isEmpty {
            titleLabel.text = "上次付款凭证未通过，请重新上传"
            titleLabel.textColor = UIColor.systemRed
            descLabel.text = "原因：\(reason)\n平台不经手学费，请与机构线下结算后重新上传付款凭证，机构确认到账后发放课时。"
        } else {
            titleLabel.text = "线下付款 · 平台不经手学费"
            titleLabel.textColor = Theme.Color.ink
            descLabel.text = "请与机构线下完成付款，并在此上传付款凭证；机构核对到账并确认后，课时将自动发放到孩子账户。"
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 课程信息卡

private final class VoucherCourseCell: UITableViewCell {
    static let reuseID = "VoucherCourseCell"
    private let titleLabel = UILabel()
    private let subLabel = UILabel()
    private let amountLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Theme.Color.surface
        contentView.backgroundColor = Theme.Color.surface

        titleLabel.font = .appSection(16)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 2
        subLabel.font = .appLabel(13)
        subLabel.textColor = Theme.Color.sub
        subLabel.numberOfLines = 1
        amountLabel.font = .appSection(17)
        amountLabel.textColor = Theme.Color.clay

        contentView.addSubview(titleLabel)
        contentView.addSubview(subLabel)
        contentView.addSubview(amountLabel)
        titleLabel.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        subLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(6)
            $0.leading.trailing.equalTo(titleLabel)
        }
        amountLabel.snp.makeConstraints {
            $0.top.equalTo(subLabel.snp.bottom).offset(10)
            $0.leading.equalTo(titleLabel)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    func configure(with order: OrderItem) {
        titleLabel.text = order.courseTitleWithLessons
        subLabel.text = order.studioClassText
        amountLabel.text = "应付 \(order.amountText)"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 付款方式单选行

private final class MethodRadioCell: UITableViewCell {
    static let reuseID = "MethodRadioCell"
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let checkView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Theme.Color.surface
        contentView.backgroundColor = Theme.Color.surface

        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = Theme.Color.brand
        titleLabel.font = .appBody(15)
        titleLabel.textColor = Theme.Color.ink

        contentView.addSubview(iconView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(checkView)
        iconView.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(22)
            $0.top.bottom.equalToSuperview().inset(14)
        }
        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(iconView.snp.trailing).offset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
        }
        checkView.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(22)
        }
    }

    func configure(method: PayMethod, selected: Bool) {
        iconView.image = UIImage(systemName: method.icon)
        titleLabel.text = method.text
        checkView.image = UIImage(systemName: selected ? "checkmark.circle.fill" : "circle")
        checkView.tintColor = selected ? Theme.Color.brand : Theme.Color.line
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 凭证九宫格（UIStackView 自适应）

private final class VoucherEditCell: UITableViewCell {
    static let reuseID = "VoucherEditCell"
    var onAdd: (() -> Void)?
    var onRemove: ((Int) -> Void)?

    private let verticalStack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Theme.Color.surface
        contentView.backgroundColor = Theme.Color.surface

        verticalStack.axis = .vertical
        verticalStack.spacing = 8
        contentView.addSubview(verticalStack)
        verticalStack.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    func reload(images: [UIImage]) {
        verticalStack.arrangedSubviews.forEach {
            verticalStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        let slotCount = images.count + (images.count < 9 ? 1 : 0)
        let rows = Int(ceil(Double(max(slotCount, 1)) / 3.0))
        for r in 0..<rows {
            let row = UIStackView()
            row.axis = .horizontal
            row.spacing = 8
            row.distribution = .fillEqually
            for c in 0..<3 {
                let idx = r * 3 + c
                let slot = UIView()
                row.addArrangedSubview(slot)
                slot.snp.makeConstraints { $0.height.equalTo(slot.snp.width) }
                if idx < images.count {
                    configureImageSlot(slot, image: images[idx], index: idx)
                } else if idx == images.count && images.count < 9 {
                    configureAddSlot(slot)
                } else {
                    slot.isHidden = true
                }
            }
            verticalStack.addArrangedSubview(row)
        }
    }

    private func configureImageSlot(_ slot: UIView, image: UIImage, index: Int) {
        let iv = UIImageView(image: image)
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 8
        slot.addSubview(iv)
        iv.snp.makeConstraints { $0.edges.equalToSuperview() }

        let del = UIButton(type: .custom)
        del.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        del.tintColor = .white
        del.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        del.layer.cornerRadius = 11
        del.tag = index
        del.addTarget(self, action: #selector(didTapRemove(_:)), for: .touchUpInside)
        slot.addSubview(del)
        del.snp.makeConstraints {
            $0.top.trailing.equalToSuperview().inset(4)
            $0.width.height.equalTo(22)
        }
    }

    private func configureAddSlot(_ slot: UIView) {
        let btn = UIButton(type: .custom)
        btn.setImage(UIImage(systemName: "camera"), for: .normal)
        btn.tintColor = Theme.Color.muted
        btn.backgroundColor = Theme.Color.surfaceAlt
        btn.layer.cornerRadius = 8
        btn.layer.borderWidth = 1
        btn.layer.borderColor = Theme.Color.line.cgColor
        btn.addTarget(self, action: #selector(didTapAdd), for: .touchUpInside)
        slot.addSubview(btn)
        btn.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    @objc private func didTapAdd() { onAdd?() }
    @objc private func didTapRemove(_ sender: UIButton) { onRemove?(sender.tag) }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 备注

private final class NoteCell: UITableViewCell, UITextFieldDelegate {
    static let reuseID = "NoteCell"
    static let textFieldTag = 20260922

    private let field = UITextField()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Theme.Color.surface
        contentView.backgroundColor = Theme.Color.surface

        field.tag = Self.textFieldTag
        field.placeholder = "选填：付款时间、转账姓名、备注说明等"
        field.font = .appBody(14)
        field.textColor = Theme.Color.ink
        field.delegate = self
        field.returnKeyType = .done
        contentView.addSubview(field)
        field.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 14, left: Theme.Spacing.l, bottom: 14, right: Theme.Spacing.l))
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
