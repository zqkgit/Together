import UIKit
import SnapKit
import Kingfisher
import ESPullToRefresh
import HXPhotoPicker
import SwiftyJSON

/// 工作室端「佣金审核」：审核/驳回推广人的佣金领取申请
/// status: 0 待审核 → approve(选打款方式) → 1 待确认 → 推广人确认 → 3 已完成；reject → 2 已驳回
final class StudioCommissionReviewViewController: BaseViewController {

    // MARK: - 分段

    private struct Tab {
        let title: String
        let status: Int?
        let empty: String
    }

    private let tabs: [Tab] = [
        Tab(title: "待审核", status: 0, empty: "暂无待审核领取申请"),
        Tab(title: "待确认", status: 1, empty: "暂无待确认领取单"),
        Tab(title: "已驳回", status: 2, empty: "暂无已驳回领取单"),
        Tab(title: "已完成", status: 3, empty: "暂无已完成领取单")
    ]

    // MARK: - 数据

    private var currentTabIndex: Int = 0
    private var withdrawals: [CommissionWithdrawal] = []
    private var page = 1
    private var total = 0
    private var isLoading = false
    private let pageSize = 20
    private var hasMore: Bool { withdrawals.count < total }
    private var firstLoad = true

    // MARK: - 视图

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyView = EmptyStateView()
    private var chipRow: TagChipRow?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadWithdrawals(reset: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "佣金审核")
        if !firstLoad { loadWithdrawals(reset: true) }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    // MARK: - 布局

    private func setupUI() {
        view.backgroundColor = Theme.Color.bg

        // 分段切换
        let chipRow = TagChipRow(
            chips: tabs.map(\.title),
            selectedIndex: 0
        )
        chipRow.onSelect = { [weak self] index in
            guard let self else { return }
            self.currentTabIndex = index
            self.loadWithdrawals(reset: true)
        }
        view.addSubview(chipRow)
        chipRow.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.height.equalTo(34)
        }
        self.chipRow = chipRow

        // 列表
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(StudioCommissionCell.self, forCellReuseIdentifier: StudioCommissionCell.reuseID)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 180
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(chipRow.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.loadWithdrawals(reset: true)
        }
        tableView.es.addInfiniteScrolling { [weak self] in
            self?.loadWithdrawals(reset: false)
        }

        emptyView.isHidden = true
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints {
            $0.centerX.equalTo(tableView)
            $0.top.equalTo(tableView.snp.top).offset(200)
        }
    }

    // MARK: - 数据加载

    private func loadWithdrawals(reset: Bool) {
        if reset { page = 1 }
        guard !isLoading else { return }
        isLoading = true
        let status = tabs[currentTabIndex].status

        StudioService.fetchCommissionWithdrawals(status: status, page: page, pageSize: pageSize) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            self.firstLoad = false
            self.tableView.es.stopPullToRefresh()
            self.tableView.es.stopLoadingMore()
            switch result {
            case .success(let data):
                self.total = data.total
                if reset { self.withdrawals = data.list } else { self.withdrawals.append(contentsOf: data.list) }
                self.page += 1
                self.refreshEmptyState()
                self.tableView.reloadData()
            case .failure(let error):
                if reset { self.showToast(error.message ?? "加载失败") }
            }
        }
    }

    private func refreshEmptyState() {
        let isEmpty = withdrawals.isEmpty
        emptyView.isHidden = !isEmpty
        if isEmpty {
            emptyView.show(style: .empty(tabs[currentTabIndex].empty))
        }
    }

    // MARK: - 审核操作

    /// 审核通过：选打款方式 → 线上方式需上传凭证 → 提交
    private func approve(_ item: CommissionWithdrawal) {
        let methods = PayMethodOption.all
        let sheet = UIAlertController(title: "选择打款方式", message: nil, preferredStyle: .actionSheet)
        for m in methods {
            sheet.addAction(UIAlertAction(title: m.label, style: .default) { [weak self] _ in
                guard let self else { return }
                let isOnline = PayMethod.from(m.value)?.isOnline ?? true
                if isOnline {
                    // 线上打款必须上传凭证
                    self.pickVoucherThenSubmit(item, method: m.value)
                } else {
                    // 现金无需凭证，直接提交
                    self.submitReview(item, action: "approve", method: m.value)
                }
            })
        }
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(sheet, animated: true)
    }

    /// 选凭证图 → 上传 → 提交审核
    private func pickVoucherThenSubmit(_ item: CommissionWithdrawal, method: String) {
        var config = PickerConfiguration()
        config.selectOptions = [.photo]
        config.maximumSelectedCount = 9
        let picker = PhotoPickerController(config: config)
        picker.finishHandler = { [weak self] result, _ in
            guard let self else { return }
            result.getImage(targetSize: CGSize(width: 1600, height: 1600)) { [weak self] images in
                guard let self else { return }
                guard !images.isEmpty else {
                    self.showToast("请上传打款凭证截图")
                    return
                }
                self.uploadAndSubmit(item, method: method, images: images)
            }
        }
        present(picker, animated: true)
    }

    /// 上传凭证图 → 提交审核
    private func uploadAndSubmit(_ item: CommissionWithdrawal, method: String, images: [UIImage]) {
        showLoading("上传凭证中...")
        let datas = images.compactMap { $0.jpegData(compressionQuality: 0.8) }
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
                self.submitReview(item, action: "approve", method: method, voucherImages: urls)
            case .failure(let error):
                self.hideLoading()
                self.showToast(error.message ?? "凭证上传失败")
            }
        }
    }

    private func reject(_ item: CommissionWithdrawal) {
        ThemeInputAlertView.show(
            title: "驳回领取申请",
            placeholder: "请填写驳回原因（推广人可见）",
            maxCount: 100,
            confirmTitle: "确认驳回",
            onConfirm: { [weak self] reason in
                self?.submitReview(item, action: "reject", rejectReason: reason)
            }
        )
    }

    private func submitReview(_ item: CommissionWithdrawal, action: String, method: String? = nil, voucherImages: [String]? = nil, rejectReason: String? = nil) {
        guard let id = item.withdraw_id else { return }
        showLoading()
        StudioService.reviewCommissionWithdrawal(
            id: id,
            action: action,
            method: method,
            voucherImages: voucherImages,
            rejectReason: rejectReason
        ) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success:
                let msg = action == "approve" ? "已登记打款，待推广人确认" : "已驳回"
                self.showToast(msg)
                NotificationCenter.default.post(name: .commissionUpdated, object: nil)
                self.loadWithdrawals(reset: true)
            case .failure(let error):
                self.showToast(error.message ?? "操作失败")
            }
        }
    }
}

// MARK: - TableView

extension StudioCommissionReviewViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        withdrawals.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: StudioCommissionCell.reuseID, for: indexPath) as! StudioCommissionCell
        let item = withdrawals[indexPath.row]
        cell.configure(with: item)
        cell.onApprove = { [weak self] in self?.approve(item) }
        cell.onReject = { [weak self] in self?.reject(item) }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - 佣金领取单卡片

final class StudioCommissionCell: UITableViewCell {
    static let reuseID = "StudioCommissionCell"

    var onApprove: (() -> Void)?
    var onReject: (() -> Void)?

    private let card = UIView()
    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let timeLabel = UILabel()
    private let amountLabel = UILabel()
    private let statusPill = PaddingLabel()
    private let methodLabel = UILabel()
    private let actionWrap = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.top.equalToSuperview().offset(6)
            $0.bottom.equalToSuperview().offset(-6)
        }

        // 头像
        avatarView.contentMode = .scaleAspectFill
        avatarView.layer.cornerRadius = 21
        avatarView.clipsToBounds = true
        avatarView.backgroundColor = Theme.Color.brandSoft
        card.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.leading.top.equalToSuperview().inset(Theme.Spacing.l)
            $0.width.height.equalTo(42)
        }

        // 推广人名称
        nameLabel.font = .appSection(15)
        nameLabel.textColor = Theme.Color.ink
        card.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarView.snp.trailing).offset(Theme.Spacing.m)
            $0.top.equalTo(avatarView).offset(2)
            $0.trailing.lessThanOrEqualToSuperview().inset(96)
        }

        // 时间
        timeLabel.font = .appLabel(12)
        timeLabel.textColor = Theme.Color.muted
        card.addSubview(timeLabel)
        timeLabel.snp.makeConstraints {
            $0.leading.equalTo(nameLabel)
            $0.top.equalTo(nameLabel.snp.bottom).offset(4)
        }

        // 右上金额
        amountLabel.font = .appSection(17)
        amountLabel.textColor = Theme.Color.clay
        amountLabel.textAlignment = .right
        card.addSubview(amountLabel)
        amountLabel.snp.makeConstraints {
            $0.top.equalTo(avatarView).offset(2)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        // 收款方式
        methodLabel.font = .appLabel(12)
        methodLabel.textColor = Theme.Color.sub
        card.addSubview(methodLabel)
        methodLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalTo(amountLabel.snp.bottom).offset(4)
        }

        // 状态标签
        statusPill.font = .appLabel(11)
        statusPill.layer.cornerRadius = 12
        statusPill.clipsToBounds = true
        statusPill.textInsets = UIEdgeInsets(top: 3, left: 10, bottom: 3, right: 10)
        card.addSubview(statusPill)
        statusPill.snp.makeConstraints {
            $0.leading.equalTo(nameLabel)
            $0.top.equalTo(timeLabel.snp.bottom).offset(Theme.Spacing.s)
        }

        // 操作区
        card.addSubview(actionWrap)
        actionWrap.snp.makeConstraints {
            $0.top.equalTo(statusPill.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    func configure(with item: CommissionWithdrawal) {
        let name = item.user?.nickname ?? "推广人"
        nameLabel.text = name
        avatarView.image = avatarPlaceholder(for: name)

        amountLabel.text = CommissionService.yuan(item.amount)
        timeLabel.text = CommissionService.fmtTime(item.created_at)
        methodLabel.text = item.method_text ?? ""
        configureStatus(item.status ?? 0)
        rebuildActions(item)
        setNeedsLayout()
    }

    /// 按昵称首字生成主题色圆形占位头像
    private func avatarPlaceholder(for name: String) -> UIImage {
        let colors: [UIColor] = [Theme.Color.brand, Theme.Color.wood, Theme.Color.clay, Theme.Color.info]
        let index = abs(name.hashValue) % colors.count
        let color = colors[index]
        let size = CGSize(width: 42, height: 42)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 21).fill()
            let first = String(name.prefix(1))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.appSection(18),
                .foregroundColor: UIColor.white
            ]
            let textSize = (first as NSString).size(withAttributes: attrs)
            let point = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )
            (first as NSString).draw(at: point, withAttributes: attrs)
        }
    }

    private func configureStatus(_ status: Int) {
        let config: (String, UIColor, UIColor)
        switch status {
        case 0: config = ("待审核", Theme.Color.warn, Theme.Color.warnTint)
        case 1: config = ("待确认", Theme.Color.info, Theme.Color.infoTint)
        case 2: config = ("已驳回", Theme.Color.danger, Theme.Color.dangerTint)
        case 3: config = ("已完成", Theme.Color.success, Theme.Color.successTint)
        default: config = ("未知", Theme.Color.muted, Theme.Color.surfaceAlt)
        }
        statusPill.text = config.0
        statusPill.textColor = config.1
        statusPill.backgroundColor = config.2
    }

    private func rebuildActions(_ item: CommissionWithdrawal) {
        actionWrap.subviews.forEach { $0.removeFromSuperview() }
        let status = item.status ?? 0

        switch status {
        case 0:
            let rejectBtn = makeButton(title: "驳回", filled: false, action: #selector(tapReject))
            let approveBtn = makeButton(title: "通过并打款", filled: true, action: #selector(tapApprove))
            actionWrap.addSubview(rejectBtn)
            actionWrap.addSubview(approveBtn)
            rejectBtn.snp.makeConstraints {
                $0.leading.top.bottom.equalToSuperview()
                $0.height.equalTo(40)
            }
            approveBtn.snp.makeConstraints {
                $0.leading.equalTo(rejectBtn.snp.trailing).offset(Theme.Spacing.m)
                $0.trailing.top.bottom.equalToSuperview()
                $0.width.equalTo(rejectBtn)
                $0.height.equalTo(40)
            }
        case 1:
            let tip = UILabel()
            tip.font = .appLabel(12)
            tip.textColor = Theme.Color.info
            tip.text = "已登记打款，等待推广人确认到账"
            tip.numberOfLines = 0
            actionWrap.addSubview(tip)
            tip.snp.makeConstraints {
                $0.top.leading.trailing.bottom.equalToSuperview()
            }
        default:
            break
        }
    }

    private func makeButton(title: String, filled: Bool, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .appBody(14)
        btn.layer.cornerRadius = 20
        btn.clipsToBounds = true
        if filled {
            btn.backgroundColor = Theme.Color.brand
            btn.setTitleColor(.white, for: .normal)
        } else {
            btn.backgroundColor = Theme.Color.surface
            btn.setTitleColor(Theme.Color.ink, for: .normal)
            btn.layer.borderWidth = 1
            btn.layer.borderColor = Theme.Color.line.cgColor
        }
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    @objc private func tapApprove() { onApprove?() }
    @objc private func tapReject() { onReject?() }
}