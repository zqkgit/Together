import UIKit
import SnapKit
import Kingfisher
import HXPhotoPicker
import ESPullToRefresh
import SwiftyJSON

/// 工作室 App 端 · 退款审核
/// 状态分段：待审核(0) / 待家长确认(1) / 已驳回(2) / 已退款(3)
/// - 待审核：同意退款（选退款方式+上传凭证 → 待家长确认）/ 拒绝并留言（→已驳回）
/// - 待家长确认：工作室线下打款后「确认已打款」（→已退款，此时才扣课时）
final class StudioRefundViewController: BaseViewController {

    private struct Tab {
        let title: String
        let status: Int
        let empty: String
    }

    private let tabs: [Tab] = [
        Tab(title: "待审核", status: 0, empty: "暂无待审核退款"),
        Tab(title: "待确认", status: 1, empty: "暂无待确认退款"),
        Tab(title: "已驳回", status: 2, empty: "暂无已驳回退款"),
        Tab(title: "已退款", status: 3, empty: "暂无已退款退款")
    ]

    private var currentStatus: Int
    private var refunds: [StudioRefund] = []
    private var chipRow: TagChipRow?
    private var firstLoad = true

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyView = EmptyStateView()

    init(initialStatus: Int = 0) {
        self.currentStatus = initialStatus
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "退款审核")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    private func setupUI() {
        view.backgroundColor = Theme.Color.bg

        let chipRow = TagChipRow(
            chips: tabs.map(\.title),
            selectedIndex: max(0, tabs.firstIndex { $0.status == currentStatus } ?? 0)
        )
        chipRow.onSelect = { [weak self] index in
            guard let self else { return }
            self.currentStatus = self.tabs[index].status
            self.loadData()
        }
        view.addSubview(chipRow)
        chipRow.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.height.equalTo(34)
        }
        self.chipRow = chipRow

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(StudioRefundCell.self, forCellReuseIdentifier: StudioRefundCell.reuseID)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 220
        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.loadData()
        }
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(chipRow.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.bottom.equalTo(view.safeAreaLayoutGuide)
        }

        emptyView.isHidden = true
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints {
            $0.centerX.equalTo(tableView)
            $0.centerY.equalTo(tableView)
        }
    }

    private func currentTab() -> Tab {
        tabs.first { $0.status == currentStatus } ?? tabs[0]
    }

    private func loadData() {
        if firstLoad { emptyView.show(style: .loading) }
        StudioService.fetchRefunds(status: currentStatus) { [weak self] result in
            guard let self else { return }
            self.firstLoad = false
            self.tableView.es.stopPullToRefresh()
            switch result {
            case .success(let list):
                self.refunds = list
                self.tableView.reloadData()
                let isEmpty = list.isEmpty
                self.emptyView.isHidden = !isEmpty
                if isEmpty { self.emptyView.show(style: .empty(self.currentTab().empty)) }
            case .failure(let error):
                self.emptyView.isHidden = false
                self.emptyView.show(style: .error(error.message ?? "加载失败") { [weak self] in
                    self?.loadData()
                })
            }
        }
    }

    // MARK: - 审核操作

    /// 审核通过：选退款方式 → 线上方式需上传凭证 → 提交
    private func approve(_ refund: StudioRefund) {
        let methods = PayMethodOption.all
        let sheet = UIAlertController(title: "选择退款方式", message: "线下结算，平台不经手资金", preferredStyle: .actionSheet)
        for m in methods {
            sheet.addAction(UIAlertAction(title: m.label, style: .default) { [weak self] _ in
                guard let self else { return }
                let isOnline = PayMethod.from(m.value)?.isOnline ?? true
                if isOnline {
                    // 线上退款必须上传凭证
                    self.pickVoucherThenSubmit(refund, method: m.value)
                } else {
                    // 现金无需凭证，直接提交
                    self.submit(refund, action: "approve", refundMethod: m.value)
                }
            })
        }
        sheet.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(sheet, animated: true)
    }

    /// 选凭证图 → 上传 → 提交审核
    private func pickVoucherThenSubmit(_ refund: StudioRefund, method: String) {
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
                self.uploadAndSubmit(refund, method: method, images: images)
            }
        }
        present(picker, animated: true)
    }

    /// 上传凭证图 → 提交审核
    private func uploadAndSubmit(_ refund: StudioRefund, method: String, images: [UIImage]) {
        showLoading("上传凭证中...")
        let datas = images.compactMap { $0.jpegData(compressionQuality: 0.8) }
        APIClient.shared.upload(files: datas, folder: "refund") { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let json):
                let urls = json["urls"].arrayValue.map { $0.stringValue }
                if urls.isEmpty {
                    self.hideLoading()
                    self.showToast("凭证上传失败")
                    return
                }
                self.submit(refund, action: "approve", refundMethod: method, voucherImages: urls)
            case .failure(let error):
                self.hideLoading()
                self.showToast(error.message ?? "凭证上传失败")
            }
        }
    }

    private func reject(_ refund: StudioRefund) {
        ThemeInputAlertView.show(
            title: "拒绝并留言",
            placeholder: "请填写拒绝原因（家长可见）",
            maxCount: 100,
            confirmTitle: "确认拒绝",
            onConfirm: { [weak self] reason in
                self?.submit(refund, action: "reject", reason: reason)
            }
        )
    }

    private func confirmPaid(_ refund: StudioRefund) {
        ThemeAlertView.show(
            title: "确认已打款",
            message: "确认已向「\(refund.parentName)」完成退款 \(refund.amountText)？\n确认后将扣减相应课时，不可撤销。",
            confirmTitle: "确认打款",
            cancelTitle: "取消",
            onConfirm: { [weak self] in
                self?.submit(refund, action: "confirm")
            }
        )
    }

    private func submit(_ refund: StudioRefund, action: String, reason: String? = nil, refundMethod: String? = nil, voucherImages: [String]? = nil) {
        showLoading()
        StudioService.reviewRefund(refundId: refund.refund_id, action: action, reason: reason, refundMethod: refundMethod, voucherImages: voucherImages) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success:
                let msg: String
                switch action {
                case "approve": msg = "已通过，等待家长确认"
                case "reject": msg = "已驳回"
                default: msg = "打款已确认"
                }
                self.showToast(msg)
                self.loadData()
            case .failure(let error):
                self.showToast(error.message ?? "操作失败")
            }
        }
    }

    // MARK: - 凭证图片预览

    private func previewVoucher(urls: [String], index: Int) {
        guard !urls.isEmpty else { return }
        let overlay = UIView(frame: UIScreen.main.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.9)
        overlay.alpha = 0
        let scrollView = UIScrollView(frame: overlay.bounds)
        scrollView.isPagingEnabled = true
        scrollView.contentSize = CGSize(width: overlay.bounds.width * CGFloat(urls.count), height: overlay.bounds.height)
        for (i, urlString) in urls.enumerated() {
            let iv = UIImageView(frame: CGRect(x: overlay.bounds.width * CGFloat(i), y: 0, width: overlay.bounds.width, height: overlay.bounds.height))
            iv.contentMode = .scaleAspectFit
            if let url = URL(string: urlString) {
                iv.kf.setImage(with: url)
            }
            scrollView.addSubview(iv)
        }
        scrollView.contentOffset = CGPoint(x: overlay.bounds.width * CGFloat(index), y: 0)
        overlay.addSubview(scrollView)

        // 页码
        let pageLabel = UILabel()
        pageLabel.font = .appBody(14)
        pageLabel.textColor = .white
        pageLabel.textAlignment = .center
        pageLabel.text = "\(index + 1)/\(urls.count)"
        overlay.addSubview(pageLabel)
        pageLabel.snp.makeConstraints {
            $0.bottom.equalTo(overlay.safeAreaLayoutGuide).inset(20)
            $0.centerX.equalToSuperview()
        }

        // 关闭按钮
        let closeBtn = UIButton(type: .system)
        closeBtn.setTitle("✕", for: .normal)
        closeBtn.setTitleColor(.white, for: .normal)
        closeBtn.titleLabel?.font = .appTitle(20)
        closeBtn.addTarget(self, action: #selector(dismissVoucherPreview(_:)), for: .touchUpInside)
        overlay.addSubview(closeBtn)
        closeBtn.snp.makeConstraints {
            $0.top.equalTo(overlay.safeAreaLayoutGuide).offset(12)
            $0.trailing.equalToSuperview().inset(16)
            $0.width.height.equalTo(44)
        }

        keyWindow?.addSubview(overlay)
        UIView.animate(withDuration: 0.25) { overlay.alpha = 1 }
        objc_setAssociatedObject(overlay, "overlay", overlay, .OBJC_ASSOCIATION_RETAIN)
    }

    @objc private func dismissVoucherPreview(_ sender: UIButton) {
        guard let overlay = sender.superview else { return }
        UIView.animate(withDuration: 0.25, animations: { overlay.alpha = 0 }) { _ in overlay.removeFromSuperview() }
    }

    private var keyWindow: UIWindow? {
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}

extension StudioRefundViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        refunds.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: StudioRefundCell.reuseID, for: indexPath) as! StudioRefundCell
        let refund = refunds[indexPath.row]
        cell.configure(refund)
        cell.onApprove = { [weak self] in self?.approve(refund) }
        cell.onReject = { [weak self] in self?.reject(refund) }
        cell.onConfirm = { [weak self] in self?.confirmPaid(refund) }
        cell.onVoucherTap = { [weak self] urls, idx in self?.previewVoucher(urls: urls, index: idx) }
        return cell
    }
}

// MARK: - 退款卡片

private final class StudioRefundCell: UITableViewCell {
    static let reuseID = "StudioRefundCell"

    var onApprove: (() -> Void)?
    var onReject: (() -> Void)?
    var onConfirm: (() -> Void)?
    var onVoucherTap: (([String], Int) -> Void)?

    private let card = UIView()
    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let subLabel = UILabel()
    private let amountLabel = UILabel()
    private let reasonBar = UIView()
    private let reasonIcon = UIImageView()
    private let reasonLabel = UILabel()
    /// 动态信息区（退款方式+凭证 / 驳回原因）
    private let infoWrap = UIView()
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

        // 家长称呼
        nameLabel.font = .appSection(15)
        nameLabel.textColor = Theme.Color.ink
        card.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarView.snp.trailing).offset(Theme.Spacing.m)
            $0.top.equalTo(avatarView).offset(2)
            $0.trailing.lessThanOrEqualToSuperview().inset(96)
        }

        // 副标题：课程 · 剩余 x/y 节 / 时间
        subLabel.font = .appLabel(12)
        subLabel.textColor = Theme.Color.muted
        subLabel.numberOfLines = 2
        card.addSubview(subLabel)
        subLabel.snp.makeConstraints {
            $0.leading.equalTo(nameLabel)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalTo(nameLabel.snp.bottom).offset(4)
        }

        // 右上金额
        amountLabel.textAlignment = .right
        card.addSubview(amountLabel)
        amountLabel.snp.makeConstraints {
            $0.top.equalTo(avatarView).offset(2)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        // 退款原因条（浅黄）
        reasonBar.backgroundColor = Theme.Color.warnTint
        reasonBar.layer.cornerRadius = Theme.Radius.icon
        card.addSubview(reasonBar)
        reasonBar.snp.makeConstraints {
            $0.top.equalTo(avatarView.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        reasonIcon.image = UIImage(systemName: "text.bubble.fill")
        reasonIcon.tintColor = Theme.Color.warn
        reasonIcon.contentMode = .scaleAspectFit
        reasonBar.addSubview(reasonIcon)
        reasonIcon.snp.makeConstraints {
            $0.leading.top.equalToSuperview().inset(Theme.Spacing.m)
            $0.width.height.equalTo(16)
        }
        reasonLabel.font = .appLabel(12.5)
        reasonLabel.textColor = Theme.Color.sub
        reasonLabel.numberOfLines = 0
        reasonBar.addSubview(reasonLabel)
        reasonLabel.snp.makeConstraints {
            $0.leading.equalTo(reasonIcon.snp.trailing).offset(Theme.Spacing.s)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.top.bottom.equalToSuperview().inset(Theme.Spacing.m)
            $0.centerY.equalTo(reasonIcon)
        }

        // 动态信息区
        card.addSubview(infoWrap)
        infoWrap.snp.makeConstraints {
            $0.top.equalTo(reasonBar.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        // 操作区
        card.addSubview(actionWrap)
        actionWrap.snp.makeConstraints {
            $0.top.equalTo(infoWrap.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    func configure(_ refund: StudioRefund) {
        nameLabel.text = refund.parentName
        if let urlString = refund.parentAvatar, let url = URL(string: urlString) {
            avatarView.kf.setImage(with: url, placeholder: UIImage(named: "avatar_placeholder"))
        } else {
            avatarView.image = UIImage(named: "avatar_placeholder")
        }

        let timeText = StudioRefundTimeText(refund.created_at)
        subLabel.text = "\(refund.courseTitle) · 剩余 \(refund.remaining)/\(refund.totalLessons) 节\n\(timeText)"
        amountLabel.attributedText = StudioRefundAmountText(refund.amountText)

        // 退款原因
        reasonLabel.text = refund.reasonText.isEmpty ? "家长未填写退款原因" : refund.reasonText

        // 存储凭证图片用于点击预览
        currentVoucherImages = refund.voucherImageList

        // 动态信息区
        rebuildInfoArea(refund)

        // 操作区
        rebuildActionArea(refund)
        setNeedsLayout()
    }

    // MARK: - 动态信息区

    private func rebuildInfoArea(_ refund: StudioRefund) {
        infoWrap.subviews.forEach { $0.removeFromSuperview() }

        switch refund.status {
        case 1, 3:
            // 待家长确认 / 已退款：展示退款方式 + 凭证缩略图
            var lastView: UIView = infoWrap
            var isFirst = true

            // 退款方式
            let methodText = refund.refundMethodText
            if !methodText.isEmpty {
                let methodLabel = UILabel()
                methodLabel.font = .appLabel(12)
                methodLabel.textColor = Theme.Color.sub
                methodLabel.text = "退款方式：\(methodText)"
                infoWrap.addSubview(methodLabel)
                methodLabel.snp.makeConstraints {
                    if isFirst {
                        $0.top.leading.trailing.equalToSuperview()
                        isFirst = false
                    } else {
                        $0.top.equalTo(lastView.snp.bottom).offset(Theme.Spacing.s)
                        $0.leading.trailing.equalToSuperview()
                    }
                }
                lastView = methodLabel
            }

            // 凭证缩略图
            let images = refund.voucherImageList
            if !images.isEmpty {
                let voucherRow = UIView()
                infoWrap.addSubview(voucherRow)
                voucherRow.snp.makeConstraints {
                    if isFirst {
                        $0.top.leading.trailing.equalToSuperview()
                        isFirst = false
                    } else {
                        $0.top.equalTo(lastView.snp.bottom).offset(Theme.Spacing.s)
                        $0.leading.trailing.equalToSuperview()
                    }
                    $0.height.equalTo(56)
                }
                lastView = voucherRow

                let thumbSize: CGFloat = 48
                let spacing: CGFloat = 6
                var prevThumb: UIView?
                for (idx, urlString) in images.prefix(5).enumerated() {
                    let iv = UIImageView()
                    iv.contentMode = .scaleAspectFill
                    iv.layer.cornerRadius = 6
                    iv.clipsToBounds = true
                    iv.backgroundColor = Theme.Color.bg
                    if let url = URL(string: urlString) {
                        iv.kf.setImage(with: url)
                    }
                    iv.isUserInteractionEnabled = true
                    iv.tag = idx
                    iv.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapVoucher(_:))))
                    voucherRow.addSubview(iv)
                    iv.snp.makeConstraints {
                        $0.top.equalToSuperview()
                        $0.width.height.equalTo(thumbSize)
                        if let prev = prevThumb {
                            $0.leading.equalTo(prev.snp.trailing).offset(spacing)
                        } else {
                            $0.leading.equalToSuperview()
                        }
                    }
                    prevThumb = iv
                }
                // 超过5张显示+N
                if images.count > 5 {
                    let moreLabel = UILabel()
                    moreLabel.font = .appLabel(11)
                    moreLabel.textColor = Theme.Color.muted
                    moreLabel.text = "+\(images.count - 5)"
                    voucherRow.addSubview(moreLabel)
                    moreLabel.snp.makeConstraints {
                        if let prev = prevThumb {
                            $0.leading.equalTo(prev.snp.trailing).offset(spacing)
                        }
                        $0.centerY.equalToSuperview()
                    }
                }
            }

            // 驳回原因（status 2）
        case 2:
            if !refund.rejectReasonText.isEmpty {
                let rejectBar = UIView()
                rejectBar.backgroundColor = Theme.Color.dangerTint
                rejectBar.layer.cornerRadius = Theme.Radius.icon
                infoWrap.addSubview(rejectBar)
                rejectBar.snp.makeConstraints {
                    $0.top.leading.trailing.equalToSuperview()
                }
                let icon = UIImageView()
                icon.image = UIImage(systemName: "xmark.circle.fill")
                icon.tintColor = Theme.Color.danger
                icon.contentMode = .scaleAspectFit
                rejectBar.addSubview(icon)
                icon.snp.makeConstraints {
                    $0.leading.top.equalToSuperview().inset(Theme.Spacing.m)
                    $0.width.height.equalTo(16)
                }
                let label = UILabel()
                label.font = .appLabel(12.5)
                label.textColor = Theme.Color.danger
                label.numberOfLines = 0
                label.text = refund.rejectReasonText
                rejectBar.addSubview(label)
                label.snp.makeConstraints {
                    $0.leading.equalTo(icon.snp.trailing).offset(Theme.Spacing.s)
                    $0.trailing.equalToSuperview().inset(Theme.Spacing.m)
                    $0.top.bottom.equalToSuperview().inset(Theme.Spacing.m)
                    $0.centerY.equalTo(icon)
                }
            }
        default:
            break
        }
    }

    @objc private func tapVoucher(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view else { return }
        // 找到当前 refund 的凭证列表
        // 通过 superview 链找到 cell，再找到 refund 数据
        // 这里用简单方式：把 voucherImages 存在 cell 上
        if let urls = currentVoucherImages, !urls.isEmpty {
            onVoucherTap?(urls, view.tag)
        }
    }

    private var currentVoucherImages: [String]?

    // MARK: - 操作区

    private func rebuildActionArea(_ refund: StudioRefund) {
        actionWrap.subviews.forEach { $0.removeFromSuperview() }

        switch refund.status {
        case 0:
            // 待审核：拒绝并留言（描边） + 同意退款（实心）
            let rejectBtn = makeButton(title: "拒绝并留言", filled: false, action: #selector(tapReject))
            let approveBtn = makeButton(title: "同意退款", filled: true, action: #selector(tapApprove))
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
            // 待家长确认：提示 + 确认已打款
            let tip = UILabel()
            tip.font = .appLabel(12)
            tip.textColor = Theme.Color.success
            tip.text = "审核已通过，请在线下完成打款后点击确认"
            tip.numberOfLines = 0
            let confirmBtn = makeButton(title: "确认已打款", filled: true, action: #selector(tapConfirm))
            actionWrap.addSubview(tip)
            actionWrap.addSubview(confirmBtn)
            tip.snp.makeConstraints {
                $0.top.leading.trailing.equalToSuperview()
            }
            confirmBtn.snp.makeConstraints {
                $0.top.equalTo(tip.snp.bottom).offset(Theme.Spacing.s)
                $0.leading.trailing.bottom.equalToSuperview()
                $0.height.equalTo(40)
            }
        default:
            // 2 已驳回 / 3 已退款：仅状态标签
            let done = refund.status == 3
            let pill = PaddingLabel()
            pill.text = done ? "已退款" : "已驳回"
            pill.font = .appLabel(12)
            pill.textColor = done ? Theme.Color.success : Theme.Color.danger
            pill.backgroundColor = done ? Theme.Color.successTint : Theme.Color.dangerTint
            pill.layer.cornerRadius = 12
            pill.clipsToBounds = true
            pill.textInsets = UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)
            actionWrap.addSubview(pill)
            pill.snp.makeConstraints {
                $0.leading.top.bottom.equalToSuperview()
                $0.height.equalTo(24)
            }
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
    @objc private func tapConfirm() { onConfirm?() }
}

// MARK: - 金额 / 时间格式化

/// 金额：¥ 用小字号、数字加粗（设计稿红色 ¥440.00）
private func StudioRefundAmountText(_ text: String) -> NSAttributedString {
    let attr = NSMutableAttributedString(
        string: text,
        attributes: [.font: UIFont.appSection(17), .foregroundColor: Theme.Color.danger]
    )
    if text.hasPrefix("¥") {
        attr.addAttributes(
            [.font: UIFont.appLabel(12), .foregroundColor: Theme.Color.danger],
            range: NSRange(location: 0, length: 1)
        )
    }
    return attr
}

/// 申请时间：今天 HH:mm / 昨天 HH:mm / 本周 周X HH:mm / 今年 MM-dd HH:mm / 更早 yyyy-MM-dd
private func StudioRefundTimeText(_ iso: String?) -> String {
    guard let iso, !iso.isEmpty, let date = StudioRefundParseDate(iso) else { return "" }
    let cal = Calendar.current
    let hmFmt = DateFormatter()
    hmFmt.locale = Locale(identifier: "zh_CN")
    hmFmt.dateFormat = "HH:mm"
    let hm = hmFmt.string(from: date)

    if cal.isDateInToday(date) { return "今天 \(hm)" }
    if cal.isDateInYesterday(date) { return "昨天 \(hm)" }
    let weekday = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"][cal.component(.weekday, from: date) - 1]
    let days = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: Date())).day ?? 99
    if days < 7 { return "\(weekday) \(hm)" }

    let yearFmt = DateFormatter()
    yearFmt.locale = Locale(identifier: "zh_CN")
    if cal.component(.year, from: date) == cal.component(.year, from: Date()) {
        yearFmt.dateFormat = "MM-dd HH:mm"
    } else {
        yearFmt.dateFormat = "yyyy-MM-dd"
    }
    return yearFmt.string(from: date)
}

private func StudioRefundParseDate(_ iso: String) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "UTC")
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
    if let d = formatter.date(from: iso) { return d }
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    return formatter.date(from: iso)
}

/// 带内边距的文本标签（状态 pill / 角标，模块内复用）
final class PaddingLabel: UILabel {
    var textInsets = UIEdgeInsets.zero
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + textInsets.left + textInsets.right,
                      height: size.height + textInsets.top + textInsets.bottom)
    }
}
