import UIKit
import SnapKit
import HXPhotoPicker
import Kingfisher
import SwiftyJSON

/// 个人资料（设置 → 个人资料）：头像 / 昵称 / 城市
final class EditProfileViewController: BaseViewController {

    private let avatarView = CircleImageView()
    private var avatarURL: String?

    private let nicknameField = UITextField()
    private let cityField = UITextField()
    private let signatureField = UITextField()
    private let signatureCountLabel = UILabel()
    private let saveButton = UIButton(type: .system)
    private var originalNickname = ""
    private var originalCity = ""
    private var originalSignature = ""

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        setupUI()
        loadProfile()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "个人资料")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    private func setupUI() {
        // 头像
        avatarView.backgroundColor = Theme.Color.surfaceAlt
        avatarView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(pickAvatar))
        avatarView.addGestureRecognizer(tap)
        view.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(24)
            $0.centerX.equalToSuperview()
            $0.width.height.equalTo(84)
        }

        let tipLabel = UILabel()
        tipLabel.text = "点击更换头像"
        tipLabel.font = .appLabel(12)
        tipLabel.textColor = Theme.Color.sub
        tipLabel.textAlignment = .center
        view.addSubview(tipLabel)
        tipLabel.snp.makeConstraints {
            $0.top.equalTo(avatarView.snp.bottom).offset(8)
            $0.centerX.equalToSuperview()
        }

        // 昵称
        let nicknameTitle = makeFieldTitle("昵称")
        view.addSubview(nicknameTitle)
        nicknameTitle.snp.makeConstraints {
            $0.top.equalTo(tipLabel.snp.bottom).offset(Theme.Spacing.xl)
            $0.leading.equalToSuperview().inset(Theme.Spacing.l + 4)
        }

        let nicknameCard = makeFieldCard(field: nicknameField, placeholder: "请输入昵称")
        view.addSubview(nicknameCard)
        nicknameCard.snp.makeConstraints {
            $0.top.equalTo(nicknameTitle.snp.bottom).offset(6)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(52)
        }

        // 城市
        let cityTitle = makeFieldTitle("城市")
        view.addSubview(cityTitle)
        cityTitle.snp.makeConstraints {
            $0.top.equalTo(nicknameCard.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.equalToSuperview().inset(Theme.Spacing.l + 4)
        }

        let cityCard = makeFieldCard(field: cityField, placeholder: "请输入所在城市（选填）")
        view.addSubview(cityCard)
        cityCard.snp.makeConstraints {
            $0.top.equalTo(cityTitle.snp.bottom).offset(6)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(52)
        }

        // 个性签名
        let signatureTitle = makeFieldTitle("个性签名")
        view.addSubview(signatureTitle)
        signatureTitle.snp.makeConstraints {
            $0.top.equalTo(cityCard.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.equalToSuperview().inset(Theme.Spacing.l + 4)
        }

        let signatureCard = makeFieldCard(field: signatureField, placeholder: "一句话介绍自己（选填）")
        view.addSubview(signatureCard)
        signatureCard.snp.makeConstraints {
            $0.top.equalTo(signatureTitle.snp.bottom).offset(6)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(52)
        }
        signatureField.addTarget(self, action: #selector(signatureChanged), for: .editingChanged)

        signatureCountLabel.font = .appLabel(11)
        signatureCountLabel.textColor = Theme.Color.sub
        signatureCountLabel.textAlignment = .right
        signatureCountLabel.text = "0/20"
        signatureCard.addSubview(signatureCountLabel)
        signatureCountLabel.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
        }
        signatureField.snp.remakeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
            $0.trailing.equalTo(signatureCountLabel.snp.leading).offset(-8)
            $0.centerY.equalToSuperview()
        }

        // 保存
        saveButton.setTitle("保存", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font = .appBody(16)
        saveButton.backgroundColor = Theme.Color.brand
        saveButton.layer.cornerRadius = 25
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        view.addSubview(saveButton)
        saveButton.snp.makeConstraints {
            $0.top.equalTo(signatureCard.snp.bottom).offset(32)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(50)
        }
    }

    private func makeFieldTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .appBody(14)
        label.textColor = Theme.Color.ink
        return label
    }

    private func makeFieldCard(field: UITextField, placeholder: String) -> UIView {
        let card = UIView()
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = 12

        field.font = .appBody(15)
        field.textColor = Theme.Color.ink
        field.placeholder = placeholder
        field.clearButtonMode = .whileEditing
        card.addSubview(field)
        field.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
        }
        return card
    }

    private func loadProfile() {
        showLoading("加载中...")
        AuthService.fetchMe { [weak self] profile, error in
            guard let self else { return }
            self.hideLoading()
            if let profile {
                self.originalNickname = profile.nickname
                self.originalCity = profile.city ?? ""
                self.originalSignature = profile.signature ?? ""
                self.nicknameField.text = profile.nickname
                self.cityField.text = profile.city
                self.signatureField.text = profile.signature
                self.updateSignatureCount()
                self.avatarURL = profile.avatar
                if let avatar = profile.avatar, let url = URL(string: avatar) {
                    self.avatarView.kf.setImage(with: url, placeholder: nil)
                } else {
                    self.avatarView.image = nil
                }
            } else if let error {
                self.showToast(error)
            }
        }
    }

    @objc private func pickAvatar() {
        view.endEditing(true)
        var config = PickerConfiguration()
        config.selectOptions = [.photo]
        config.maximumSelectedCount = 1
        let picker = PhotoPickerController(config: config)
        picker.finishHandler = { [weak self] result, _ in
            guard let self, let image = result.photoAssets.first else { return }
            result.getImage(targetSize: CGSize(width: 300, height: 300)) { images in
                guard let thumb = images.first else { return }
                self.uploadAvatar(thumb)
            }
        }
        present(picker, animated: true)
    }

    private func uploadAvatar(_ image: UIImage) {
        showLoading("上传中...")
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            hideLoading()
            return
        }
        APIClient.shared.upload(files: [data], folder: "avatar") { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success(let json):
                let url = json.arrayValue.first?["url"].string
                if let url {
                    self.avatarURL = url
                    self.avatarView.image = image
                } else {
                    self.showToast("上传失败")
                }
            case .failure(let error):
                self.showToast(error.message ?? "上传失败")
            }
        }
    }

    private func updateSignatureCount() {
        let count = signatureField.text?.count ?? 0
        signatureCountLabel.text = "\(count)/20"
        signatureCountLabel.textColor = count > 20 ? UIColor(hex: 0xE5484D) : Theme.Color.sub
    }

    @objc private func signatureChanged() {
        if let text = signatureField.text, text.count > 20 {
            signatureField.text = String(text.prefix(20))
        }
        updateSignatureCount()
    }

    @objc private func saveTapped() {        let nickname = nicknameField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !nickname.isEmpty else {
            showToast("昵称不能为空")
            return
        }
        view.endEditing(true)
        showLoading("保存中...")
        AuthService.updateProfile(
            nickname: nickname,
            avatar: avatarURL,
            city: cityField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
            signature: signatureField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        ) { [weak self] success, error in
            guard let self else { return }
            self.hideLoading()
            if success {
                self.showToast("保存成功")
                NotificationCenter.default.post(name: .userProfileUpdated, object: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    self.navigationController?.popViewController(animated: true)
                }
            } else {
                self.showToast(error ?? "保存失败")
            }
        }
    }
}
