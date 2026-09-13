import UIKit
import SnapKit

/// 占位页（M1 脚手架，后续逐个模块填充）
class PlaceholderViewController: BaseViewController {

    private let placeholderTitle: String

    init(title: String) {
        self.placeholderTitle = title
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = placeholderTitle

        let label = UILabel()
        label.text = placeholderTitle
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .secondaryLabel

        let tip = UILabel()
        tip.text = "模块开发中"
        tip.font = .systemFont(ofSize: 14)
        tip.textColor = .tertiaryLabel

        view.addSubview(label)
        view.addSubview(tip)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        tip.snp.makeConstraints { make in
            make.top.equalTo(label.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
        }
    }
}
