import UIKit
import SnapKit
import SwiftyJSON
import HXPhotoPicker
import Kingfisher

/// 老师认证页（平台认证）
/// 字段：真实姓名（必填）/ 教龄 / 擅长方向 / 资质证书·作品集（多图）/ 一句话简介
/// 状态：表单（unauth / rejected 可重提，被驳回自动回显上次提交内容）→ 提交后审核中（pending）
final class TeacherAuthViewController: BaseViewController {

    private var initialStatus: String?
    private var rejectReason: String?
    private var applyData: JSON?

    // MARK: - 表单控件

    private let nameField = UITextField()
    private let expTagView = TagSelectView(
        options: ["1–3 年", "3–5 年", "5 年以上"],
        selected: []
    )
    private let skillTagView = TagSelectView(
        options: ["水彩", "硬笔书法", "国画", "黏土", "素描", "油画"],
        selected: []
    )
    private let introTextView = UITextView()
    private let introCountLabel = UILabel()
    private var selectedPhotos: [UIImage] = []
    private let photoCollectionView: UICollectionView
    private let maxPhotoCount = 9

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
        configureImmersiveNav(title: "老师认证")

        if initialStatus == "pending" {
            showPendingView()
        } else {
            showFormView()
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

        // 被拒提示条（可重新提交）
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
        let heroIcon = UIImageView(image: UIImage(systemName: "graduationcap.fill"))
        heroIcon.tintColor = Theme.Color.brand
        heroIcon.contentMode = .scaleAspectFit
        hero.addSubview(heroIcon)
        heroIcon.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.width.height.equalTo(22)
        }
        let heroTitle = UILabel()
        heroTitle.text = "老师身份需认证"
        heroTitle.font = .appBody(15)
        heroTitle.textColor = Theme.Color.ink
        hero.addSubview(heroTitle)
        heroTitle.snp.makeConstraints {
            $0.leading.equalTo(heroIcon.snp.trailing).offset(Theme.Spacing.s)
            $0.centerY.equalTo(heroIcon)
        }
        let heroDesc = UILabel()
        heroDesc.text = "提交教学资料后，由艺启平台审核（1–2 个工作日）。审核通过即可使用老师端：发作品、消课，并可申请与工作室合作。"
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

        // 信息卡
        let formCard = makeCard()
        var lastView: UIView?

        // 真实姓名
        let nameTitle = makeFieldTitle("真实姓名")
        formCard.addSubview(nameTitle)
        nameTitle.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        nameField.font = .appBody(15)
        nameField.textColor = Theme.Color.ink
        nameField.placeholder = "如：陈晓"
        nameField.returnKeyType = .done
        nameField.delegate = self
        formCard.addSubview(nameField)
        nameField.snp.makeConstraints {
            $0.top.equalTo(nameTitle.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(44)
        }
        let nameLine = UIView()
        nameLine.backgroundColor = Theme.Color.surfaceAlt
        formCard.addSubview(nameLine)
        nameLine.snp.makeConstraints {
            $0.top.equalTo(nameField.snp.bottom)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(1)
        }
        lastView = nameLine

        // 教龄
        let expTitle = makeFieldTitle("教龄")
        formCard.addSubview(expTitle)
        expTitle.snp.makeConstraints {
            $0.top.equalTo(lastView!.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        expTagView.allowsMultipleSelection = false
        formCard.addSubview(expTagView)
        expTagView.snp.makeConstraints {
            $0.top.equalTo(expTitle.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        lastView = expTagView

        // 擅长方向
        let skillTitle = makeFieldTitle("擅长方向（可多选）")
        formCard.addSubview(skillTitle)
        skillTitle.snp.makeConstraints {
            $0.top.equalTo(lastView!.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        formCard.addSubview(skillTagView)
        skillTagView.snp.makeConstraints {
            $0.top.equalTo(skillTitle.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        lastView = skillTagView

        // 资质证书 / 作品集
        let certTitle = makeFieldTitle("资质证书 / 作品集")
        formCard.addSubview(certTitle)
        certTitle.snp.makeConstraints {
            $0.top.equalTo(lastView!.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        let certSub = UILabel()
        certSub.text = "最多 \(maxPhotoCount) 张，审核通过后展示在老师主页"
        certSub.font = .appLabel(11)
        certSub.textColor = Theme.Color.sub
        formCard.addSubview(certSub)
        certSub.snp.makeConstraints {
            $0.top.equalTo(certTitle.snp.bottom).offset(2)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        photoCollectionView.backgroundColor = .clear
        photoCollectionView.showsHorizontalScrollIndicator = false
        photoCollectionView.dataSource = self
        photoCollectionView.delegate = self
        photoCollectionView.register(TeacherCertCell.self, forCellWithReuseIdentifier: TeacherCertCell.reuseId)
        formCard.addSubview(photoCollectionView)
        photoCollectionView.snp.makeConstraints {
            $0.top.equalTo(certSub.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(100)
        }
        lastView = photoCollectionView

        // 一句话简介
        let introTitle = makeFieldTitle("一句话简介")
        formCard.addSubview(introTitle)
        introTitle.snp.makeConstraints {
            $0.top.equalTo(lastView!.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        introTextView.font = .appBody(14)
        introTextView.textColor = Theme.Color.ink
        introTextView.backgroundColor = Theme.Color.surfaceAlt
        introTextView.layer.cornerRadius = 10
        introTextView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        introTextView.delegate = self
        formCard.addSubview(introTextView)
        introTextView.snp.makeConstraints {
            $0.top.equalTo(introTitle.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(88)
        }
        introCountLabel.font = .appLabel(11)
        introCountLabel.textColor = Theme.Color.sub
        introCountLabel.text = "0/100"
        introCountLabel.textAlignment = .right
        formCard.addSubview(introCountLabel)
        introCountLabel.snp.makeConstraints {
            $0.top.equalTo(introTextView.snp.bottom).offset(4)
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.l)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.l)
        }
        lastView = introCountLabel

        scrollView.addSubview(formCard)
        formCard.snp.makeConstraints {
            $0.top.equalTo(hero.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalTo(view).inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().offset(-24)
        }

        // 提交按钮
        let submit = UIButton(type: .system)
        submit.setTitle("提交认证申请", for: .normal)
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

    // MARK: - 被驳回/重新申请：回显上次提交的数据

    private func applyPreviousData() {
        guard let a = applyData else { return }
        if let name = a["real_name"].string, !name.isEmpty {
            nameField.text = name
        }
        if let years = a["years"].string, !years.isEmpty {
            expTagView.setSelected([years])
        }
        if let subjects = a["subjects"].string, !subjects.isEmpty {
            let tags = subjects.split(separator: ",").map(String.init)
            skillTagView.setSelected(Set(tags))
        } else {
            let tags = a["subjects"].arrayValue.compactMap { $0.string }
            if !tags.isEmpty {
                skillTagView.setSelected(Set(tags))
            }
        }
        if let intro = a["intro"].string, !intro.isEmpty {
            introTextView.text = intro
            introCountLabel.text = "\(intro.count)/100"
        }
        if let urls = a["portfolio"].array {
            loadPortfolio(urls: urls.compactMap { $0.string })
        }
    }

    /// 上次提交的证书/作品集图片回显（Kingfisher 异步加载）
    private func loadPortfolio(urls: [String]) {
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
        scrollView.addSubview(UIView()) // 底部锚点占位
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
        title.text = "认证审核中"
        title.font = .appSection(18)
        title.textColor = Theme.Color.ink
        title.textAlignment = .center
        pendingView.addSubview(title)
        title.snp.makeConstraints {
            $0.top.equalTo(icon.snp.bottom).offset(Theme.Spacing.m)
            $0.centerX.equalToSuperview()
        }

        let desc = UILabel()
        desc.text = "已提交至艺启平台，预计 1–2 个工作日内完成审核。结果会通过消息通知你。"
        desc.font = .appBody(14)
        desc.textColor = Theme.Color.sub
        desc.textAlignment = .center
        desc.numberOfLines = 0
        pendingView.addSubview(desc)
        desc.snp.makeConstraints {
            $0.top.equalTo(title.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(48)
        }

        // 步骤条
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
        let stepLabels = steps.enumerated().map { index, text -> UIView in
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
        stepLabels.forEach { stepRow.addArrangedSubview($0) }

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
        guard let name = nameField.text?.trimmingCharacters(in: .whitespaces), !name.isEmpty else {
            showToast("请填写真实姓名")
            return
        }
        guard let exp = expTagView.selectedTags.first else {
            showToast("请选择教龄")
            return
        }
        let skills = Array(skillTagView.selectedTags)
        guard !skills.isEmpty else {
            showToast("请选择擅长方向")
            return
        }
        let intro = introTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        view.endEditing(true)

        // 教龄区间 → 年数（后端 years 为 smallint）
        let expMap = ["1–3 年": 2, "3–5 年": 4, "5 年以上": 6]
        let years = expMap[exp] ?? 2

        showLoading("提交中...")
        uploadPhotosIfNeeded { [weak self] urls in
            guard let self else { return }
            AuthService.submitRoleApply(role: "teacher", payload: [
                "real_name": name,
                "years": years,
                "subjects": skills,
                "intro": intro,
                "portfolio": urls
            ]) { result in
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

    /// 证书图片先上传到 cert 目录，返回 URL 数组（无图时返回空数组）
    private func uploadPhotosIfNeeded(completion: @escaping ([String]) -> Void) {
        guard !selectedPhotos.isEmpty else {
            completion([])
            return
        }
        let datas = selectedPhotos.map { $0.jpegData(compressionQuality: 0.8) ?? Data() }
        APIClient.shared.upload(files: datas, folder: "cert") { result in
            switch result {
            case .success(let json):
                // 响应已剥壳为 data（URL 数组）
                let urls = json.arrayValue.compactMap { $0["url"].string }
                completion(urls)
            case .failure:
                completion([])
            }
        }
    }
}

// MARK: - UITextFieldDelegate

extension TeacherAuthViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - UITextViewDelegate（简介 100 字限制 + 计数）

extension TeacherAuthViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        let count = textView.text.count
        introCountLabel.text = "\(count)/100"
        if count > 100 {
            textView.text = String(textView.text.prefix(100))
            introCountLabel.text = "100/100"
        }
    }
}

// MARK: - 照片选择（证书/作品集）

extension TeacherAuthViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        min(selectedPhotos.count + 1, maxPhotoCount)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TeacherCertCell.reuseId, for: indexPath) as! TeacherCertCell
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

extension TeacherAuthViewController {
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

// MARK: - 证书格

private final class TeacherCertCell: UICollectionViewCell {
    static let reuseId = "TeacherCertCell"

    private let imageView = UIImageView()
    private let addIcon = UIImageView()
    private let deleteButton = UIButton(type: .system)

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
        deleteButton.tag = isAdd ? 0 : 1
        deleteButton.removeTarget(nil, action: nil, for: .touchUpInside)
        if !isAdd, let onDelete {
            deleteButton.addTarget(self, action: #selector(didTapDelete), for: .touchUpInside)
        }
        self.onDelete = onDelete
    }

    private var onDelete: (() -> Void)?

    @objc private func didTapDelete() {
        onDelete?()
    }
}
