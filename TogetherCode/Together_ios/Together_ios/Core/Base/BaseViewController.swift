import UIKit
import SnapKit
import MBProgressHUD

/// 基类控制器：统一背景、加载、提示、空态、沉浸式导航
class BaseViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupNavigationBar()
    }

    private func setupNavigationBar() {
        navigationController?.navigationBar.prefersLargeTitles = false
    }

    // MARK: - 统一沉浸式导航（透明系统导航栏方案）

    /// 沉浸式导航：透明导航栏 + 自定义圆底返回按钮 + 系统标题（标题居中、转场动画、侧滑返回手势均由系统管理）
    /// 子类在 viewWillAppear 调用；viewWillDisappear 调用 restoreSystemNav() 恢复默认导航栏
    func configureImmersiveNav(
        title: String? = nil,
        titleColor: UIColor = Theme.Color.ink,
        backBackground: UIColor = Theme.Color.ink.withAlphaComponent(0.06),
        backTint: UIColor = Theme.Color.ink
    ) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.shadowColor = .clear
        appearance.backgroundColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: titleColor,
            .font: UIFont.appSection(17)
        ]
        guard let nav = navigationController else { return }
        nav.navigationBar.standardAppearance = appearance
        nav.navigationBar.scrollEdgeAppearance = appearance
        nav.navigationBar.compactAppearance = appearance
        nav.navigationBar.isTranslucent = true

        // 自定义圆底返回按钮（帖子详情样式：白 chevron + 黑半透明圆底 38pt）
        // 用容器承载：系统导航栏 ItemWrapperView 高度固定 36，直接给 customView 按钮设 38 高会与其冲突；
        // 容器高度交给系统，按钮 38×38 在容器内居中（上下各溢出 1pt，容器不裁剪）
        let button = UIButton(type: .system)
        button.backgroundColor = backBackground
        button.layer.cornerRadius = 19
        button.clipsToBounds = true
        button.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        button.tintColor = backTint
        button.addTarget(self, action: #selector(didTapImmersiveBack), for: .touchUpInside)

        let backContainer = UIView()
        backContainer.addSubview(button)
        button.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(38)
        }
        backContainer.snp.makeConstraints { make in
            make.width.equalTo(38)
        }

        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backContainer)
        navigationItem.hidesBackButton = true
        navigationItem.title = title
    }

    /// 恢复默认不透明导航栏（沉浸式页在 viewWillDisappear 调用，保证上一级普通页正常显示）
    func restoreSystemNav() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Theme.Color.surface
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: Theme.Color.ink,
            .font: UIFont.appSection(17)
        ]
        guard let nav = navigationController else { return }
        nav.navigationBar.standardAppearance = appearance
        nav.navigationBar.scrollEdgeAppearance = appearance
        nav.navigationBar.compactAppearance = appearance
        // isTranslucent 保持 true（与沉浸式一致）：iOS 17 在转场中切换 translucent 会渲染出整片导航阴影
        nav.navigationBar.isTranslucent = true
    }

    @objc private func didTapImmersiveBack() {
        if let nav = navigationController, nav.viewControllers.count > 1 {
            nav.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    // MARK: - 加载

    private var hud: MBProgressHUD?

    func showLoading(_ text: String = "加载中...") {
        if hud == nil {
            hud = MBProgressHUD.showAdded(to: view, animated: true)
        }
        hud?.mode = .indeterminate
        hud?.label.text = text
    }

    func hideLoading() {
        hud?.hide(animated: true)
        hud = nil
    }

    // MARK: - 提示

    func showToast(_ message: String) {
        guard let window = view.window ?? (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first else {
            return
        }
        let hud = MBProgressHUD.showAdded(to: window, animated: true)
        hud.mode = .text
        hud.detailsLabel.text = message
        hud.hide(animated: true, afterDelay: 1.8)
    }
}
