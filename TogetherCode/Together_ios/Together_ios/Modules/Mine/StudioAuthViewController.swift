import UIKit
import SnapKit
import SwiftyJSON
import HXPhotoPicker
import Kingfisher

/// 工作室入驻认证页（平台认证）
/// 字段（对齐 PRD #studioAuth）：
/// 基本信息：工作室名称（必填）/ 城市区域 / 详细地址 / 联系人 / 手机号 / 营业类型（来自 Web 端标签库的工作室标签）/ 简介
/// 资质场地：营业执照号（必填）/ 是否有办学许可 / 场地照片（多图，OSS 数组）
/// 师资数量不再由用户填写，由后端按「实际合作老师数」统计（teacher_studio_bindings 在职绑定）
/// 状态：表单（unauth / rejected 可重提，被驳回自动回显上次提交内容）→ 提交后审核中（pending）
final class StudioAuthViewController: BaseViewController {

    private var initialStatus: String?
    private var rejectReason: String?
    private var applyData: JSON?

    // MARK: - 基本信息控件

    private let nameField = UITextField()
    private let cityField = UITextField()
    private let addressField = UITextField()
    private let contactField = UITextField()
    private let phoneField = UITextField()
    /// 营业类型：选项来自 Web 端「标签管理 · 工作室」标签库（GET /v1/tags?scope=1）
    /// 视图在拿到标签后于 showFormView 内创建（TagSelectView 选项初始化后不可变）
    private var typeTagView: TagSelectView!
    private var studioTagNames: [String] = []
    private let introTextView = UITextView()
    private let introCountLabel = UILabel()

    // MARK: - 资质 / 场地控件

    private let licenseField = UITextField()
    private let permitTagView = TagSelectView(
        options: ["有", "暂无"],
        selected: ["暂无"]
    )
    private var selectedPhotos: [UIImage] = []
    private let photoCollectionView: UICollectionView
    private let maxPhotoCount = 6

    private let scrollView = UIScrollView()
    private let pendingView = UIView()

    // MARK: - 初始化

    init(status: String? = nil, reason: String? = nil, apply: JSON? = nil) {
        self.initialStatus = status
        self.rejectReason = reason
        self.applyData = apply
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 100, height: 100)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        photoCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        configureImmersiveNav(title: "工作室入驻")

        if initialStatus == "pending" {
            showPendingView()
        } else {
            loadStudioTagsThenShowForm()
        }
    }

    /// 先拉取 Web 端「工作室标签」库，再渲染表单（营业类型选项依赖该数据）
    private func loadStudioTagsThenShowForm() {
        showLoading("加载中...")
        TagService.fetchTags(scope: .studio) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success(let tags):
                // 按后台 sort 升序展示
                self.studioTagNames = tags.sorted { $0.sort < $1.sort }.map { $0.name }
            case .failure:
                // 标签加载失败不阻断表单；营业类型为必选项，未选会由提交校验拦截
                self.studioTagNames = []
            }
            self.showFormView()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    // MARK: - 表单

    private func showFormView() {
        pendingView.removeFromSuperview()
        setupScrollView()

        // 被拒提示条
        var rejectBar: UIView?
        if initialStatus == "rejected", let reason = rejectReason, !reason.isEmpty {
            rejectBar = makeCard()
            let icon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
            icon.tintColor = UIColor.systemOrange
            icon.contentMode = .scaleAspectFit
            rejectBar!.addSubview(icon)
            icon.snp.makeConstraints {
                $0.leading.equalToSuperview().offset(Theme.Spacing.l)
                $0.centerY.equalToSuperview()
                $0.width.height.equalTo(18)
            }
            let label = UILabel()
            label.text = "上次被驳回：\(reason)"
            label.font = .appBody(13)
            label.textColor = Theme.Color.ink
            label.numberOfLines = 0
            rejectBar!.addSubview(label)
            label.snp.makeConstraints {
                $0.leading.equalTo(icon.snp.trailing).offset(Theme.Spacing.s)
                $0.trailing.equalToSuperview().offset(-Theme.Spacing.l)
                $0.top.bottom.equalToSuperview().inset(Theme.Spacing.l)
            }
            scrollView.addSubview(rejectBar!)
            rejectBar!.snp.makeConstraints {
                $0.top.equalToSuperview().offset(Theme.Spacing.l)
                $0.leading.trailing.equalTo(view).inset(Theme.Spacing.l)
            }
        }

        // 说明卡
        let hero = makeCard()
        let heroIcon = UIImageView(image: UIImage(systemName: "storefront.fill"))
        heroIcon.tintColor = Theme.Color.brand
        heroIcon.contentMode = .scaleAspectFit
        hero.addSubview(heroIcon)
        heroIcon.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.width.height.equalTo(22)
        }
        let heroTitle = UILabel()
        heroTitle.text = "工作室需资质审核"
        heroTitle.font = .appBody(15)
        heroTitle.textColor = Theme.Color.ink
        hero.addSubview(heroTitle)
        heroTitle.snp.makeConstraints {
            $0.leading.equalTo(heroIcon.snp.trailing).offset(Theme.Spacing.s)
            $0.centerY.equalTo(heroIcon)
        }
        let heroDesc = UILabel()
        heroDesc.text = "提交营业执照与办学资质，由艺启平台审核（1–3 个工作日）。通过后开启经营后台：课程管理、学员、订单与结算。"
        heroDesc.font = .appLabel(13)
        heroDesc.textColor = Theme.Color.sub
        heroDesc.numberOfLines = 0
        hero.addSubview(heroDesc)
        heroDesc.snp.makeConstraints {
            $0.top.equalTo(heroIcon.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.l)
        }
        scrollView.addSubview(hero)
        hero.snp.makeConstraints {
            $0.top.equalTo(rejectBar == nil ? scrollView.snp.top : rejectBar!.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalTo(view).inset(Theme.Spacing.l)
        }

        // MARK: 卡 1 · 基本信息
        let infoCard = makeCard()
        scrollView.addSubview(infoCard)
        infoCard.snp.makeConstraints {
            $0.top.equalTo(hero.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalTo(view).inset(Theme.Spacing.l)
        }

        var anchor: UIView!
        anchor = addField("工作室名称", placeholder: "如：青苗艺术工坊", card: infoCard, top: infoCard.snp.top, field: nameField)
        anchor = addField("所在城市 / 区域", placeholder: "如：杭州 · 西湖区", card: infoCard, top: anchor.snp.bottom, field: cityField)
        anchor = addField("详细地址", placeholder: "街道门牌", card: infoCard, top: anchor.snp.bottom, field: addressField)
        anchor = addField("联系人", placeholder: "如：王校长", card: infoCard, top: anchor.snp.bottom, field: contactField)
        anchor = addField("联系手机号", placeholder: "用于审核与经营通知", card: infoCard, top: anchor.snp.bottom, field: phoneField, keyboard: .phonePad)

        // 营业类型（来自 Web 端标签库的工作室标签，动态加载）
        let typeTitle = makeFieldTitle("营业类型（可多选）")
        infoCard.addSubview(typeTitle)
        typeTitle.snp.makeConstraints {
            $0.top.equalTo(anchor.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        typeTagView = TagSelectView(options: studioTagNames, selected: [])
        typeTagView.allowsMultipleSelection = true // 营业类型支持多选（标签库 scope=1）
        infoCard.addSubview(typeTagView)
        typeTagView.snp.makeConstraints {
            $0.top.equalTo(typeTitle.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        anchor = typeTagView

        // 简介
        let introTitle = makeFieldTitle("工作室简介")
        infoCard.addSubview(introTitle)
        introTitle.snp.makeConstraints {
            $0.top.equalTo(anchor.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        introTextView.font = .appBody(14)
        introTextView.textColor = Theme.Color.ink
        introTextView.backgroundColor = Theme.Color.surfaceAlt
        introTextView.layer.cornerRadius = 10
        introTextView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        introTextView.delegate = self
        infoCard.addSubview(introTextView)
        introTextView.snp.makeConstraints {
            $0.top.equalTo(introTitle.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(88)
        }
        introCountLabel.font = .appLabel(11)
        introCountLabel.textColor = Theme.Color.sub
        introCountLabel.text = "0/100"
        introCountLabel.textAlignment = .right
        infoCard.addSubview(introCountLabel)
        introCountLabel.snp.makeConstraints {
            $0.top.equalTo(introTextView.snp.bottom).offset(4)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.l)
        }

        // MARK: 卡 2 · 资质与场地
        let certCard = makeCard()
        scrollView.addSubview(certCard)
        certCard.snp.makeConstraints {
            $0.top.equalTo(infoCard.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalTo(view).inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().offset(-24)
        }

        var cAnchor: UIView!
        licenseField.keyboardType = .asciiCapable
        cAnchor = addField("营业执照号", placeholder: "统一社会信用代码", card: certCard, top: certCard.snp.top, field: licenseField)

        // 是否有办学许可
        let permitTitle = makeFieldTitle("是否有办学许可")
        certCard.addSubview(permitTitle)
        permitTitle.snp.makeConstraints {
            $0.top.equalTo(cAnchor.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        permitTagView.allowsMultipleSelection = false
        certCard.addSubview(permitTagView)
        permitTagView.snp.makeConstraints {
            $0.top.equalTo(permitTitle.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        cAnchor = permitTagView

        // 场地照片
        let photoTitle = makeFieldTitle("教学场地照片")
        certCard.addSubview(photoTitle)
        photoTitle.snp.makeConstraints {
            $0.top.equalTo(cAnchor.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        let photoSub = UILabel()
        photoSub.text = "最多 \(maxPhotoCount) 张，展示教室、教学环境，审核更易通过"
        photoSub.font = .appLabel(11)
        photoSub.textColor = Theme.Color.sub
        photoSub.numberOfLines = 0
        certCard.addSubview(photoSub)
        photoSub.snp.makeConstraints {
            $0.top.equalTo(photoTitle.snp.bottom).offset(2)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        photoCollectionView.backgroundColor = .clear
        photoCollectionView.showsHorizontalScrollIndicator = false
        photoCollectionView.dataSource = self
        photoCollectionView.delegate = self
        photoCollectionView.register(StudioPhotoCell.self, forCellWithReuseIdentifier: StudioPhotoCell.reuseId)
        certCard.addSubview(photoCollectionView)
        photoCollectionView.snp.makeConstraints {
            $0.top.equalTo(photoSub.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(100)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.l)
        }

        // 提交按钮
        let submit = UIButton(type: .system)
        submit.setTitle("提交入驻申请", for: .normal)
        submit.titleLabel?.font = .appBody(17)
        submit.setTitleColor(.white, for: .normal)
        submit.backgroundColor = Theme.Color.brand
        submit.layer.cornerRadius = 22
        submit.addTarget(self, action: #selector(didTapSubmit), for: .touchUpInside)
        view.addSubview(submit)
        submit.snp.makeConstraints {
            $0.leading.trailing.equalTo(view).inset(Theme.Spacing.l)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-Theme.Spacing.l)
            $0.height.equalTo(44)
        }
        scrollView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 76, right: 0)

        applyPreviousData()
    }

    /// 往卡片追加「标题 + 输入框（+ 分隔线）」，返回分隔线/输入框作为下一个字段的顶部锚点
    @discardableResult
    private func addField(_ title: String,
                          placeholder: String,
                          card: UIView,
                          top: ConstraintRelatableTarget,
                          field: UITextField,
                          keyboard: UIKeyboardType = .default,
                          divider: Bool = true) -> UIView {
        let titleLabel = makeFieldTitle(title)
        card.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(top).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        field.font = .appBody(15)
        field.textColor = Theme.Color.ink
        field.placeholder = placeholder
        field.keyboardType = keyboard
        field.returnKeyType = .done
        field.delegate = self
        card.addSubview(field)
        field.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(44)
        }
        if divider {
            let line = UIView()
            line.backgroundColor = Theme.Color.surfaceAlt
            card.addSubview(line)
            line.snp.makeConstraints {
                $0.top.equalTo(field.snp.bottom)
                $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
                $0.height.equalTo(1)
            }
            return line
        }
        return field
    }

    // MARK: - 被驳回 / 重新申请：回显上次提交的数据

    private func applyPreviousData() {
        guard let a = applyData else { return }
        nameField.text = a["name"].string
        cityField.text = a["city"].string
        addressField.text = a["address"].string
        contactField.text = a["contact_name"].string
        phoneField.text = a["phone"].string
        let bizTags = a["business_tags"].array?.compactMap { $0.string }.filter { !$0.isEmpty } ?? []
        if !bizTags.isEmpty {
            typeTagView.setSelected(Set(bizTags))
        } else if let bt = a["business_type"].string, !bt.isEmpty {
            typeTagView.setSelected([bt])
        }
        licenseField.text = a["license"].string
        if let permit = a["permit"].string, !permit.isEmpty {
            permitTagView.setSelected([permit])
        }
        if let intro = a["intro"].string, !intro.isEmpty {
            introTextView.text = intro
            introCountLabel.text = "\(intro.count)/100"
        }
        if let urls = a["photos"].array {
            loadPhotos(urls: urls.compactMap { $0.string })
        }
    }

    /// 上次提交的场地照片回显（Kingfisher 异步加载）
    private func loadPhotos(urls: [String]) {
        guard !urls.isEmpty else { return }
        let group = DispatchGroup()
        var images: [UIImage?] = Array(repeating: nil, count: urls.count)
        for (i, urlStr) in urls.enumerated() {
            guard let url = URL(string: urlStr) else { continue }
            group.enter()
            KingfisherManager.shared.retrieveImage(with: url) { result in
                defer { group.leave() }
                if case .success(let r) = result {
                    images[i] = r.image
                }
            }
        }
        group.notify(queue: .main) { [weak self] in
            let loaded = images.compactMap { $0 }
            if !loaded.isEmpty {
                self?.selectedPhotos = loaded
                self?.photoCollectionView.reloadData()
            }
        }
    }

    private func makeCard() -> UIView {
        let v = UIView()
        v.backgroundColor = Theme.Color.surface
        v.layer.cornerRadius = 12
        return v
    }

    private func makeFieldTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .appBody(13)
        label.textColor = Theme.Color.sub
        return label
    }

    private func setupScrollView() {
        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.bottom.equalToSuperview()
        }
        scrollView.contentInsetAdjustmentBehavior = .never
    }

    // MARK: - 审核中

    private func showPendingView() {
        view.subviews.filter { $0 !== pendingView }.forEach { $0.removeFromSuperview() }
        pendingView.backgroundColor = Theme.Color.bg
        view.addSubview(pendingView)
        pendingView.snp.makeConstraints { $0.edges.equalToSuperview() }

        let icon = UIImageView(image: UIImage(systemName: "clock.fill"))
        icon.tintColor = Theme.Color.brand
        icon.contentMode = .scaleAspectFit
        pendingView.addSubview(icon)
        icon.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(96)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(64)
        }

        let title = UILabel()
        title.text = "入驻审核中"
        title.font = .appSection(18)
        title.textColor = Theme.Color.ink
        title.textAlignment = .center
        pendingView.addSubview(title)
        title.snp.makeConstraints {
            $0.top.equalTo(icon.snp.bottom).offset(Theme.Spacing.m)
            $0.centerX.equalToSuperview()
        }

        let desc = UILabel()
        desc.text = "已提交至艺启平台，由平台运营审核（1–3 个工作日）。结果会通知联系人，审核通过后即可进入工作室端。"
        desc.font = .appBody(14)
        desc.textColor = Theme.Color.sub
        desc.textAlignment = .center
        desc.numberOfLines = 0
        pendingView.addSubview(desc)
        desc.snp.makeConstraints {
            $0.top.equalTo(title.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(48)
        }

        // 步骤条：已提交 · 平台审核中 · 等待结果
        let steps = ["已提交", "平台审核中", "等待结果"]
        let stepRow = UIStackView()
        stepRow.axis = .horizontal
        stepRow.distribution = .fillEqually
        pendingView.addSubview(stepRow)
        stepRow.snp.makeConstraints {
            $0.top.equalTo(desc.snp.bottom).offset(32)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(60)
        }
        let stepViews = steps.enumerated().map { index, text -> UIView in
            let container = UIView()
            let dot = UIView()
            dot.backgroundColor = index < 2 ? Theme.Color.brand : Theme.Color.surfaceAlt
            dot.layer.cornerRadius = 6
            container.addSubview(dot)
            dot.snp.makeConstraints {
                $0.top.equalToSuperview()
                $0.centerX.equalToSuperview()
                $0.width.height.equalTo(12)
            }
            let line = UIView()
            line.backgroundColor = Theme.Color.surfaceAlt
            container.addSubview(line)
            line.snp.makeConstraints {
                $0.centerY.equalTo(dot)
                $0.leading.trailing.equalToSuperview().inset(24)
                $0.height.equalTo(1)
            }
            line.isHidden = index == 0 || index == steps.count - 1
            let label = UILabel()
            label.text = text
            label.font = .appLabel(11)
            label.textColor = index < 2 ? Theme.Color.brand : Theme.Color.sub
            label.textAlignment = .center
            container.addSubview(label)
            label.snp.makeConstraints {
                $0.top.equalTo(dot.snp.bottom).offset(6)
                $0.centerX.equalToSuperview()
            }
            return container
        }
        stepViews.forEach { stepRow.addArrangedSubview($0) }

        let button = UIButton(type: .system)
        button.setTitle("知道了", for: .normal)
        button.titleLabel?.font = .appBody(17)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = Theme.Color.brand
        button.layer.cornerRadius = 22
        button.addTarget(self, action: #selector(didTapDone), for: .touchUpInside)
        pendingView.addSubview(button)
        button.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-Theme.Spacing.l)
            $0.height.equalTo(44)
        }
    }

    @objc private func didTapDone() {
        navigationController?.popViewController(animated: true)
    }

    // MARK: - 提交

    @objc private func didTapSubmit() {
        let name = nameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let city = cityField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let address = addressField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let contact = contactField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let phone = phoneField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let license = licenseField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        let intro = introTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else { showToast("请填写工作室名称"); return }
        guard !phone.isEmpty, phone.count >= 11 else { showToast("请填写正确的联系手机号"); return }
        let selectedBizTags = studioTagNames.filter { typeTagView.selectedTags.contains($0) }
        guard let businessType = selectedBizTags.first else { showToast("请选择营业类型（至少 1 项）"); return }
        guard !license.isEmpty else { showToast("请填写营业执照号"); return }
        guard !selectedPhotos.isEmpty else { showToast("请至少上传 1 张场地照片"); return }
        let permit = permitTagView.selectedTags.first ?? "暂无"
        view.endEditing(true)

        showLoading("提交中...")
        uploadPhotosIfNeeded { [weak self] urls in
            guard let self else { return }
            var payload: [String: Any] = [
                "name": name,
                "city": city,
                "address": address,
                "contact_name": contact,
                "phone": phone,
                "business_type": businessType,
                "business_tags": selectedBizTags,
                "license": license,
                "permit": permit,
                "intro": intro,
                "photos": urls
            ]
            if let cover = urls.first { payload["cover"] = cover }

            AuthService.submitRoleApply(role: "studio", payload: payload) { result in
                self.hideLoading()
                switch result {
                case .success(let json):
                    if json["status"].stringValue == "pending" {
                        self.showPendingView()
                    } else {
                        self.showToast("提交成功")
                    }
                case .failure(let error):
                    self.showToast(error.message ?? "提交失败")
                }
            }
        }
    }

    /// 场地照片先上传到 studio 目录，返回 URL 数组
    private func uploadPhotosIfNeeded(completion: @escaping ([String]) -> Void) {
        guard !selectedPhotos.isEmpty else {
            completion([])
            return
        }
        let datas = selectedPhotos.map { $0.jpegData(compressionQuality: 0.8) ?? Data() }
        APIClient.shared.upload(files: datas, folder: "studio") { result in
            switch result {
            case .success(let json):
                let urls = json.arrayValue.compactMap { $0["url"].string }
                completion(urls)
            case .failure:
                completion([])
            }
        }
    }
}

// MARK: - 输入代理

extension StudioAuthViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

extension StudioAuthViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        let count = textView.text.count
        introCountLabel.text = "\(count)/100"
        if count > 100 {
            textView.text = String(textView.text.prefix(100))
            introCountLabel.text = "100/100"
        }
    }
}

// MARK: - 场地照片

extension StudioAuthViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        min(selectedPhotos.count + 1, maxPhotoCount)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: StudioPhotoCell.reuseId, for: indexPath) as! StudioPhotoCell
        if indexPath.item < selectedPhotos.count {
            cell.configure(image: selectedPhotos[indexPath.item], isAdd: false) { [weak self] in
                self?.selectedPhotos.remove(at: indexPath.item)
                self?.photoCollectionView.reloadData()
            }
        } else {
            cell.configure(image: nil, isAdd: true) { [weak self] in
                self?.didTapAddPhoto()
            }
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item >= selectedPhotos.count {
            didTapAddPhoto()
        }
    }
}

extension StudioAuthViewController {
    private func didTapAddPhoto() {
        view.endEditing(true)
        var config = PickerConfiguration()
        config.selectOptions = [.photo]
        config.maximumSelectedCount = maxPhotoCount - selectedPhotos.count
        let picker = PhotoPickerController(config: config)
        picker.finishHandler = { [weak self] result, _ in
            guard let self else { return }
            result.getImage(targetSize: CGSize(width: 800, height: 800)) { images in
                self.selectedPhotos.append(contentsOf: images)
                self.photoCollectionView.reloadData()
            }
        }
        present(picker, animated: true)
    }
}

// MARK: - 照片格子

private final class StudioPhotoCell: UICollectionViewCell {
    static let reuseId = "StudioPhotoCell"

    private let imageView = UIImageView()
    private let addIcon = UIImageView()
    private let deleteButton = UIButton(type: .system)
    private var onDelete: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = Theme.Color.surfaceAlt
        contentView.layer.cornerRadius = 12
        contentView.clipsToBounds = true

        addIcon.image = UIImage(systemName: "plus")
        addIcon.tintColor = Theme.Color.sub
        addIcon.contentMode = .scaleAspectFit
        contentView.addSubview(addIcon)
        addIcon.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalToSuperview().offset(18)
            $0.width.height.equalTo(28)
        }

        let label = UILabel()
        label.text = "添加照片"
        label.font = .appLabel(11)
        label.textColor = Theme.Color.sub
        label.textAlignment = .center
        contentView.addSubview(label)
        label.snp.makeConstraints {
            $0.top.equalTo(addIcon.snp.bottom).offset(4)
            $0.centerX.equalToSuperview()
        }

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.isHidden = true
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { $0.edges.equalToSuperview() }

        deleteButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        deleteButton.tintColor = UIColor.white
        deleteButton.isHidden = true
        contentView.addSubview(deleteButton)
        deleteButton.snp.makeConstraints {
            $0.top.trailing.equalToSuperview().inset(4)
            $0.width.height.equalTo(24)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(image: UIImage?, isAdd: Bool, onDelete: (() -> Void)?) {
        addIcon.isHidden = !isAdd
        contentView.subviews.forEach { if let l = $0 as? UILabel { l.isHidden = !isAdd } }
        imageView.isHidden = isAdd
        imageView.image = image
        deleteButton.isHidden = isAdd
        deleteButton.isUserInteractionEnabled = !isAdd
        deleteButton.removeTarget(nil, action: nil, for: .touchUpInside)
        if !isAdd {
            deleteButton.addTarget(self, action: #selector(didTapDelete), for: .touchUpInside)
        }
        self.onDelete = onDelete
    }

    @objc private func didTapDelete() {
        onDelete?()
    }
}
