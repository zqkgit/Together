import UIKit
import SnapKit
import HXPhotoPicker

/// 添加孩子表单（PR 图5）：头像选择 / 昵称 / 出生年份 / 性别 / 兴趣多选 / 绑定学籍 / 保存
final class AddChildViewController: BaseViewController {

    var onSaved: (() -> Void)?

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // 头像（5 个 emoji + 相册自定义）
    private let avatarOptions = ["🌻", "🦊", "🐟", "🍀", "🎀"]
    private var avatarViews: [CircleView] = []
    private var selectedAvatar = "🌻"
    private var customAvatarImage: UIImage?
    private var customAvatarView: UIView?
    private var customPhotoImageView: UIImageView?

    // 昵称
    private let nicknameField = UITextField()

    // 出生年份（2010-2024）
    private let birthLabel = UILabel()
    private let years: [Int] = Array((2010...2024).reversed())
    private var selectedYear = 2019

    // 性别
    private let interests = ["水彩", "黏土", "书法", "国画", "儿童画", "素描"]
    private let interestView = TagSelectView(options: ["水彩", "黏土", "书法", "国画", "儿童画", "素描"])
    private var selectedInterests: Set<String> = []
    private var genderButtons: [UIButton] = []
    private var selectedGender = 2

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationItem.title = "添加孩子"
        let close = UIBarButtonItem(image: UIImage(systemName: "xmark"), style: .plain, target: self, action: #selector(didTapClose))
        close.tintColor = Theme.Color.ink
        navigationItem.leftBarButtonItem = close
        let save = UIBarButtonItem(title: "保存", style: .plain, target: self, action: #selector(didTapSave))
        save.tintColor = Theme.Color.brand
        navigationItem.rightBarButtonItem = save
    }

    private func setupUI() {
        view.backgroundColor = Theme.Color.bg

        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false

        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints {
            $0.edges.equalToSuperview()
            $0.width.equalTo(view)
        }

        var lastView: UIView?

        // 头像选择
        lastView = sectionTitle("选一个头像", below: nil)
        lastView = buildAvatarRow(below: lastView)

        // 昵称
        lastView = sectionTitle("孩子昵称", below: lastView)
        lastView = buildTextFieldRow(below: lastView)

        // 出生年份
        lastView = sectionTitle("出生年份", below: lastView)
        lastView = buildBirthRow(below: lastView)

        // 性别
        lastView = sectionTitle("性别", below: lastView)
        lastView = buildGenderRow(below: lastView)

        // 兴趣方向
        lastView = sectionTitle("兴趣方向（可多选）", below: lastView)
        lastView = buildInterestRow(below: lastView)

        // 绑定学籍
        lastView = buildStudioRow(below: lastView)

    }

    // MARK: - 区块构建

    private func sectionTitle(_ text: String, below: UIView?) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .appSection(14)
        label.textColor = Theme.Color.ink
        contentView.addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            if let below {
                make.top.equalTo(below.snp.bottom).offset(Theme.Spacing.xl)
            } else {
                make.top.equalToSuperview().offset(Theme.Spacing.xl)
            }
        }
        return label
    }

    private func buildAvatarRow(below: UIView?) -> UIView {
        // 白底圆角卡片容器（高度由内容决定）
        let card = UIView()
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.top.equalTo(below!.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        // 6 项均分一行，每项宽=高=正圆
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = Theme.Spacing.m
        row.distribution = .fillEqually
        card.addSubview(row)
        row.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }

        // 相册入口放第一个
        let album = CircleView()
        album.layer.borderWidth = 2
        album.layer.borderColor = UIColor.clear.cgColor
        album.backgroundColor = Theme.Color.surfaceAlt
        album.isUserInteractionEnabled = true
        album.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapAlbum)))
        let camera = UIImageView(image: UIImage(systemName: "camera.fill"))
        camera.tintColor = Theme.Color.sub
        camera.contentMode = .scaleAspectFit
        album.addSubview(camera)
        camera.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalToSuperview().offset(7)
            $0.width.height.equalTo(18)
        }
        let tip = UILabel()
        tip.text = "相册"
        tip.font = .appLabel(8)
        tip.textColor = Theme.Color.sub
        tip.textAlignment = .center
        album.addSubview(tip)
        tip.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(camera.snp.bottom).offset(1)
        }
        row.addArrangedSubview(album)
        album.snp.makeConstraints { $0.width.equalTo(album.snp.height) }
        avatarViews.append(album)
        customAvatarView = album

        // 5 个 emoji 圆形选项
        for (index, emoji) in avatarOptions.enumerated() {
            let container = CircleView()
            container.layer.borderWidth = 2
            container.layer.borderColor = (index == 0 ? Theme.Color.brand : UIColor.clear).cgColor
            container.backgroundColor = (index == 0 ? Theme.Color.brandSoft : Theme.Color.surfaceAlt)
            container.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(didTapAvatar(_:)))
            container.addGestureRecognizer(tap)

            let label = UILabel()
            label.text = emoji
            label.font = .systemFont(ofSize: 24)
            label.textAlignment = .center
            container.addSubview(label)
            label.snp.makeConstraints { $0.edges.equalToSuperview() }
            container.tag = index

            row.addArrangedSubview(container)
            container.snp.makeConstraints { $0.width.equalTo(container.snp.height) }
            avatarViews.append(container)
        }

        return card
    }

    private func buildTextFieldRow(below: UIView?) -> UIView {
        let field = nicknameField
        field.placeholder = "如：糖糖"
        field.font = .appBody(15)
        field.backgroundColor = Theme.Color.surface
        field.layer.cornerRadius = Theme.Radius.input
        field.layer.borderWidth = 1
        field.layer.borderColor = Theme.Color.line.cgColor
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 40))
        field.leftViewMode = .always
        field.returnKeyType = .done
        field.delegate = self
        contentView.addSubview(field)
        field.snp.makeConstraints {
            $0.top.equalTo(below!.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(46)
        }
        return field
    }

    private func buildBirthRow(below: UIView?) -> UIView {
        birthLabel.font = .appBody(15)
        birthLabel.textColor = Theme.Color.ink
        birthLabel.text = "\(selectedYear)年（\(age(for: selectedYear))）"
        birthLabel.textAlignment = .center
        birthLabel.backgroundColor = Theme.Color.surface
        birthLabel.layer.cornerRadius = Theme.Radius.input
        birthLabel.layer.masksToBounds = true
        birthLabel.layer.borderWidth = 1
        birthLabel.layer.borderColor = Theme.Color.line.cgColor
        birthLabel.isUserInteractionEnabled = true
        birthLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapBirth)))
        contentView.addSubview(birthLabel)
        birthLabel.snp.makeConstraints {
            $0.top.equalTo(below!.snp.bottom).offset(Theme.Spacing.m)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.width.equalTo(160)
            $0.height.equalTo(46)
        }

        return birthLabel
    }

    private func buildGenderRow(below: UIView?) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = Theme.Spacing.l
        row.distribution = .fillEqually
        contentView.addSubview(row)
        row.snp.makeConstraints {
            $0.top.equalTo(below!.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(44)
        }

        for (index, title) in ["女孩", "男孩"].enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .appBody(15)
            button.tag = index == 0 ? 2 : 1
            button.layer.cornerRadius = Theme.Radius.input
            button.addTarget(self, action: #selector(didTapGender(_:)), for: .touchUpInside)
            updateGenderButton(button, selected: index == 0)
            row.addArrangedSubview(button)
            genderButtons.append(button)
        }
        return row
    }

    private func buildInterestRow(below: UIView?) -> UIView {
        interestView.onSelectionChanged = { [weak self] selected in
            self?.selectedInterests = selected
        }
        contentView.addSubview(interestView)
        interestView.snp.makeConstraints {
            $0.top.equalTo(below!.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.m)
        }
        return interestView
    }

    private func buildStudioRow(below: UIView?) -> UIView {
        let card = UIView()
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.top.equalTo(below!.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        let title = UILabel()
        title.text = "绑定工作室学籍（可选）"
        title.font = .appBody(14)
        title.textColor = Theme.Color.ink
        card.addSubview(title)
        title.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
        }


        let desc = UILabel()
        desc.text = "绑定学籍后，老师发布的课堂作品会自动归入孩子的成长档案。"
        desc.font = .appLabel(11)
        desc.textColor = Theme.Color.sub
        desc.numberOfLines = 2
        card.addSubview(desc)
        desc.snp.makeConstraints {
            $0.top.equalTo(title.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }

        return card
    }

    // MARK: - 交互

    @objc private func didTapClose() {
        dismiss(animated: true)
    }

    @objc private func didTapAvatar(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view else { return }
        let index = view.tag
        guard index >= 0, index < avatarOptions.count else { return }
        // 选 emoji 时清掉自定义照片（相册项恢复默认样式）
        customAvatarImage = nil
        customPhotoImageView?.removeFromSuperview()
        customPhotoImageView = nil
        if let custom = customAvatarView {
            custom.layer.borderColor = UIColor.clear.cgColor
            custom.backgroundColor = Theme.Color.surfaceAlt
            custom.subviews.forEach { sub in
                if sub is UIImageView || (sub is UILabel) { sub.isHidden = false }
            }
        }
        selectedAvatar = avatarOptions[index]
        for (i, v) in avatarViews.enumerated() {
            let isEmoji = i > 0 && (i - 1) == index
            v.layer.borderColor = (isEmoji ? Theme.Color.brand : UIColor.clear).cgColor
            v.backgroundColor = (isEmoji ? Theme.Color.brandSoft : Theme.Color.surfaceAlt)
        }
    }

    // MARK: - 相册自定义头像

    @objc private func didTapAlbum() {
        view.endEditing(true)
        var config = PickerConfiguration()
        config.selectOptions = [.photo]
        config.maximumSelectedCount = 1
        let picker = PhotoPickerController(config: config)
        picker.finishHandler = { [weak self] result, _ in
            guard let self, let image = result.photoAssets.first else { return }
            result.getImage(targetSize: CGSize(width: 200, height: 200)) { images in
                guard let thumb = images.first else { return }
                self.applyCustomAvatar(thumb)
            }
        }
        present(picker, animated: true)
    }

    private func applyCustomAvatar(_ image: UIImage) {
        customAvatarImage = image
        selectedAvatar = ""
        guard let custom = customAvatarView else { return }
        // 清空所有 emoji 选中态
        for v in avatarViews {
            v.layer.borderColor = UIColor.clear.cgColor
            v.backgroundColor = Theme.Color.surfaceAlt
        }
        // 相册项高亮
        custom.layer.borderColor = Theme.Color.brand.cgColor
        custom.backgroundColor = Theme.Color.brandSoft
        // 隐藏图标/文字，显示照片
        custom.subviews.forEach { sub in
            if sub is UIImageView || (sub is UILabel) { sub.isHidden = true }
        }
        customPhotoImageView?.removeFromSuperview()
        let photo = CircleImageView(image: image)
        photo.contentMode = .scaleAspectFill
        custom.addSubview(photo)
        photo.snp.makeConstraints { $0.edges.equalToSuperview().inset(2) }
        customPhotoImageView = photo
    }

    @objc private func didTapBirth() {
        view.endEditing(true)
        let rows = years.map { "\($0)年（\(age(for: $0))）" }
        let initialIndex = years.firstIndex(of: selectedYear) ?? 0
        let sheet = PickerSheetViewController(title: "选择出生年份", rows: rows, initialIndex: initialIndex)
        sheet.onConfirm = { [weak self] index in
            guard let self else { return }
            self.selectedYear = self.years[index]
            self.birthLabel.text = "\(self.selectedYear)年（\(self.age(for: self.selectedYear))）"
        }
        present(sheet, animated: false)
    }

    @objc private func didTapGender(_ sender: UIButton) {
        selectedGender = sender.tag
        for button in genderButtons {
            updateGenderButton(button, selected: button.tag == selectedGender)
        }
    }

    private func updateGenderButton(_ button: UIButton, selected: Bool) {
        if selected {
            button.setTitleColor(.white, for: .normal)
            button.backgroundColor = Theme.Color.brand
        } else {
            button.setTitleColor(Theme.Color.sub, for: .normal)
            button.backgroundColor = Theme.Color.surface
            button.layer.borderWidth = 1
            button.layer.borderColor = Theme.Color.line.cgColor
        }
    }

    private func age(for year: Int) -> Int {
        let currentYear = Calendar.current.component(.year, from: Date())
        return max(0, currentYear - year)
    }

    // MARK: - 保存

    @objc private func didTapSave() {
        view.endEditing(true)
        let nickname = nicknameField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !nickname.isEmpty else {
            showToast("请填写孩子昵称")
            return
        }
        guard nickname.count <= 20 else {
            showToast("昵称最多 20 个字")
            return
        }

        showLoading("保存中...")
        // TODO: OSS 配置后，customAvatarImage 上传 OSS 并替换 avatar 为 URL
        let avatar: String
        if let image = customAvatarImage {
            avatar = "custom:avatar"
            _ = image // 预留：待 OSS 上传
        } else {
            avatar = selectedAvatar
        }
        ChildService.createChild(
            nickname: nickname,
            avatar: avatar,
            birthday: "\(selectedYear)-01-01",
            gender: selectedGender,
            interests: Array(selectedInterests)
        ) { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success:
                self.showToast("添加成功")
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    self.onSaved?()
                    self.dismiss(animated: true)
                }
            case .failure(let error):
                self.showToast(error.message ?? "保存失败")
            }
        }
    }
}

// MARK: - TextField / Picker

extension AddChildViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

