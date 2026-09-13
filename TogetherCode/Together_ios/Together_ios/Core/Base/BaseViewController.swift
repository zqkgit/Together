import UIKit
import MBProgressHUD

/// 基类控制器：统一背景、加载、提示、空态
class BaseViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupNavigationBar()
    }

    private func setupNavigationBar() {
        navigationController?.navigationBar.prefersLargeTitles = false
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
