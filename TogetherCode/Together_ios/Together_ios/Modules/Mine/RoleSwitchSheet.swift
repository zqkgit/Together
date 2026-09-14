import UIKit
import SnapKit

/// 「切换身份」底部弹窗（PR 图3）
/// 家长（当前）/ 老师（去认证）/ 工作室（去认证），各行带功能说明
final class RoleSwitchSheet: UIView {

    private static let shared = RoleSwitchSheet()

    private let panel = UIView()
    private var roles: [Int] = []
    private var onSelect: ((Int) -> Void)?
    private var onNeedAuth: ((Int) -> Void)?

    private struct RoleRow {
        let role: Int
        let title: String
        let subtitle: String
        let icon: String
        static let all = [
            RoleRow(role: 1, title: "家长", subtitle: "报名课程·看孩子成长", icon: "person"),
            RoleRow(role: 2, title: "老师", subtitle: "消课·发作品·带学生", icon: "graduationcap"),
            RoleRow(role: 3, title: "工作室", subtitle: "经营数据·课程管理", icon: "storefront")
        ]
    }

    // MARK: - 展示

    static func show(
        roles: [Int],
        onSelect: ((Int) -> Void)? = nil,
        onNeedAuth: ((Int) -> Void)? = nil
    ) {
        guard let window = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first else {
            return
        }
        shared.roles = roles
        shared.onSelect = onSelect
        shared.onNeedAuth = onNeedAuth
        shared.buildRows()
        shared.frame = window.bounds
        window.addSubview(shared)
        shared.present()
    }

    // MARK: - 初始化

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        let mask = UIControl()
        mask.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        mask.addTarget(self, action: #selector(didTapMask), for: .touchUpInside)
        addSubview(mask)
        mask.snp.makeConstraints { $0.edges.equalToSuperview() }

        panel.backgroundColor = Theme.Color.surface
        panel.layer.cornerRadius = 20
        panel.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        addSubview(panel)
        panel.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
        }

        let title = UILabel()
        title.text = "切换身份"
        title.font = .appSection(17)
        title.textColor = Theme.Color.ink
        title.textAlignment = .center
        title.tag = 888
        panel.addSubview(title)
        title.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.centerX.equalToSuperview()
        }
    }

    /// 在 roles 已就绪后构建身份行（重复 show 先清空旧行）
    private func buildRows() {
        panel.subviews
            .filter { $0.tag == 999 }
            .forEach { $0.removeFromSuperview() }

        var lastRow: UIView?
        for (index, row) in RoleRow.all.enumerated() {
            let rowView = makeRow(row, index: index)
            rowView.tag = 999
            panel.addSubview(rowView)
            rowView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
                make.height.equalTo(64)
                if let lastRow {
                    make.top.equalTo(lastRow.snp.bottom).offset(Theme.Spacing.s)
                } else {
                    if let title = panel.viewWithTag(888) {
                        make.top.equalTo(title.snp.bottom).offset(Theme.Spacing.l)
                    }
                }
            }
            lastRow = rowView
        }
        lastRow?.snp.makeConstraints { make in
            make.bottom.equalToSuperview().inset(Theme.Spacing.xl + 24)
        }
    }

    private func makeRow(_ row: RoleRow, index: Int) -> UIView {
        let container = UIView()
        container.backgroundColor = Theme.Color.surfaceAlt
        container.layer.cornerRadius = Theme.Radius.button
        container.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapRow(_:)))
        container.addGestureRecognizer(tap)

        let iconView = UIImageView(image: UIImage(systemName: row.icon))
        iconView.tintColor = Theme.Color.brand
        iconView.contentMode = .scaleAspectFit
        container.addSubview(iconView)
        iconView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(24)
        }

        let title = UILabel()
        title.text = row.title
        title.font = .appBody(15)
        title.textColor = Theme.Color.ink
        container.addSubview(title)
        title.snp.makeConstraints {
            $0.leading.equalTo(iconView.snp.trailing).offset(Theme.Spacing.m)
            $0.top.equalToSuperview().offset(12)
        }

        let subtitle = UILabel()
        subtitle.text = row.subtitle
        subtitle.font = .appLabel(11)
        subtitle.textColor = Theme.Color.sub
        container.addSubview(subtitle)
        subtitle.snp.makeConstraints {
            $0.leading.equalTo(title)
            $0.top.equalTo(title.snp.bottom).offset(2)
        }

        let status = UILabel()
        status.font = .appLabel(12)
        status.text = roles.contains(row.role) ? "当前" : "去认证"
        status.textColor = roles.contains(row.role) ? Theme.Color.brand : Theme.Color.muted
        container.addSubview(status)
        status.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
        }

        return container
    }

    // MARK: - 动作

    @objc private func didTapMask() {
        dismiss()
    }

    @objc private func didTapRow(_ gesture: UITapGestureRecognizer) {
        guard let view = gesture.view else { return }
        let row = RoleRow.all[view.tag]
        dismiss()
        if roles.contains(row.role) {
            onSelect?(row.role)
        } else {
            onNeedAuth?(row.role)
        }
    }

    private func present() {
        alpha = 0
        panel.transform = CGAffineTransform(translationX: 0, y: 260)
        UIView.animate(withDuration: 0.28, delay: 0, options: .curveEaseOut) {
            self.alpha = 1
            self.panel.transform = .identity
        }
    }

    private func dismiss() {
        UIView.animate(withDuration: 0.22, animations: {
            self.alpha = 0
            self.panel.transform = CGAffineTransform(translationX: 0, y: 260)
        }) { _ in
            self.removeFromSuperview()
        }
    }
}
