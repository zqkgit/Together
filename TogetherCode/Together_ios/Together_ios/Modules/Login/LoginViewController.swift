import UIKit
import SnapKit

/// 品牌页：Logo + 标语 + 登录/注册入口 + 微信一键登录 + 协议
final class LoginViewController: BaseViewController {

    private let agreeButton = UIButton(type: .system)
    private var agreed = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 渐变随布局更新
        if let gradient = view.layer.sublayers?.first as? CAGradientLayer {
            gradient.frame = view.bounds
        }
    }

    private func setupUI() {
        // 绿-米白渐变背景
        let gradient = CAGradientLayer()
        gradient.colors = [
            UIColor(hex: 0xE9F1E4).cgColor,
            UIColor(hex: 0xF7FAF4).cgColor,
            Theme.Color.bg.cgColor
        ]
        gradient.locations = [0, 0.55, 1]
        gradient.frame = view.bounds
        view.layer.insertSublayer(gradient, at: 0)
        view.backgroundColor = Theme.Color.bg

        // Logo
        let logoView = UIView()
        logoView.backgroundColor = Theme.Color.brand
        logoView.layer.cornerRadius = 22
        logoView.clipsToBounds = true

        let logoIcon = UIImageView(image: UIImage(systemName: "paintbrush.pointed.fill"))
        logoIcon.tintColor = .white
        logoIcon.contentMode = .scaleAspectFit

        // 标题 / 标语
        let appLabel = UILabel()
        appLabel.text = "艺启"
        appLabel.font = .appTitle(34)
        appLabel.textColor = Theme.Color.ink
        appLabel.textAlignment = .center

        let sloganLabel = UILabel()
        sloganLabel.text = "让每一次创作，都被看见"
        sloganLabel.font = .appBody(14)
        sloganLabel.textColor = Theme.Color.sub
        sloganLabel.textAlignment = .center

        // 主按钮：登录/注册
        let loginButton = UIButton(type: .system)
        loginButton.setTitle("登录/注册", for: .normal)
        loginButton.setTitleColor(.white, for: .normal)
        loginButton.titleLabel?.font = .appSection(17)
        loginButton.backgroundColor = Theme.Color.brand
        loginButton.layer.cornerRadius = Theme.Radius.button
        loginButton.addTarget(self, action: #selector(didTapLogin), for: .touchUpInside)

        // 微信一键登录
        let wechatButton = UIButton(type: .system)
        wechatButton.backgroundColor = Theme.Color.surface
        wechatButton.layer.cornerRadius = Theme.Radius.button
        wechatButton.layer.borderWidth = 1
        wechatButton.layer.borderColor = Theme.Color.line.cgColor
        wechatButton.addTarget(self, action: #selector(didTapWechat), for: .touchUpInside)

        let wechatIcon = UILabel()
        wechatIcon.text = "微"
        wechatIcon.font = .appSection(13)
        wechatIcon.textColor = .white
        wechatIcon.textAlignment = .center
        wechatIcon.backgroundColor = Theme.Color.wechat
        wechatIcon.layer.cornerRadius = 12
        wechatIcon.clipsToBounds = true

        let wechatLabel = UILabel()
        wechatLabel.text = "微信一键登录"
        wechatLabel.font = .appBody(15)
        wechatLabel.textColor = Theme.Color.ink

        // 图标+文字整体视觉居中
        let wechatRow = UIView()
        wechatRow.isUserInteractionEnabled = false
        wechatRow.addSubview(wechatIcon)
        wechatRow.addSubview(wechatLabel)
        wechatIcon.snp.makeConstraints { make in
            make.left.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }
        wechatLabel.snp.makeConstraints { make in
            make.left.equalTo(wechatIcon.snp.right).offset(10)
            make.centerY.equalToSuperview()
            make.right.equalToSuperview()
        }
        wechatButton.addSubview(wechatRow)
        wechatRow.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        // 协议行
        agreeButton.setImage(UIImage(systemName: "circle"), for: .normal)
        agreeButton.setImage(UIImage(systemName: "checkmark.circle"), for: .selected)
        agreeButton.tintColor = Theme.Color.brand
        agreeButton.addTarget(self, action: #selector(didTapAgree), for: .touchUpInside)

        let agreeLabel = UILabel()
        let text = "已阅读并同意《用户协议》与《隐私政策》"
        let attributed = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        attributed.addAttribute(.font, value: UIFont.appLabel(12), range: fullRange)
        attributed.addAttribute(.foregroundColor, value: Theme.Color.sub, range: fullRange)
        let agreeRange = (text as NSString).range(of: "《用户协议》")
        let privacyRange = (text as NSString).range(of: "《隐私政策》")
        attributed.addAttribute(.foregroundColor, value: Theme.Color.brand, range: agreeRange)
        attributed.addAttribute(.foregroundColor, value: Theme.Color.brand, range: privacyRange)
        agreeLabel.attributedText = attributed
        agreeLabel.isUserInteractionEnabled = true
        agreeLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapProtocol(_:))))

        let agreeRow = UIView()
        agreeRow.addSubview(agreeButton)
        agreeRow.addSubview(agreeLabel)
        agreeButton.snp.makeConstraints { make in
            make.left.centerY.equalToSuperview()
            make.width.height.equalTo(24)
        }
        agreeLabel.snp.makeConstraints { make in
            make.left.equalTo(agreeButton.snp.right).offset(4)
            make.centerY.equalToSuperview()
            make.right.equalToSuperview()
        }

        view.addSubview(logoView)
        view.addSubview(logoIcon)
        view.addSubview(appLabel)
        view.addSubview(sloganLabel)
        view.addSubview(loginButton)
        view.addSubview(wechatButton)
        view.addSubview(agreeRow)

        logoView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide).offset(140)
            make.width.height.equalTo(78)
        }
        logoIcon.snp.makeConstraints { make in
            make.center.equalTo(logoView)
            make.width.height.equalTo(40)
        }
        appLabel.snp.makeConstraints { make in
            make.top.equalTo(logoView.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
        }
        sloganLabel.snp.makeConstraints { make in
            make.top.equalTo(appLabel.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
        }
        loginButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(32)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-172)
            make.height.equalTo(50)
        }
        wechatButton.snp.makeConstraints { make in
            make.left.right.equalTo(loginButton)
            make.top.equalTo(loginButton.snp.bottom).offset(14)
            make.height.equalTo(50)
        }
        agreeRow.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(wechatButton.snp.bottom).offset(18)
            make.height.equalTo(24)
        }
    }

    // MARK: - Actions

    @objc private func didTapAgree() {
        agreed.toggle()
        agreeButton.isSelected = agreed
    }

    @objc private func didTapProtocol(_ tap: UITapGestureRecognizer) {
        guard let label = tap.view as? UILabel, let text = label.text else { return }
        let layoutManager = NSLayoutManager()
        let textStorage = NSTextStorage(attributedString: label.attributedText ?? NSAttributedString())
        textStorage.addLayoutManager(layoutManager)
        let container = NSTextContainer(size: label.bounds.size)
        container.lineFragmentPadding = 0
        container.maximumNumberOfLines = label.numberOfLines
        layoutManager.addTextContainer(container)

        let location = tap.location(in: label)
        let index = layoutManager.characterIndex(for: location, in: container, fractionOfDistanceBetweenInsertionPoints: nil)
        let nsText = text as NSString
        if nsText.range(of: "《用户协议》").contains(index) {
            showToast("《用户协议》即将开放")
        } else if nsText.range(of: "《隐私政策》").contains(index) {
            showToast("《隐私政策》即将开放")
        }
    }

    @objc private func didTapLogin() {
        guard agreed else {
            showToast("请先阅读并同意用户协议与隐私政策")
            return
        }
        navigationController?.pushViewController(PhoneLoginViewController(), animated: true)
    }

    @objc private func didTapWechat() {
        guard agreed else {
            showToast("请先阅读并同意用户协议与隐私政策")
            return
        }
        showToast("微信登录即将开放，请先使用手机号登录")
    }
}
