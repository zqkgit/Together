import UIKit
import SnapKit
import Kingfisher

/// 「我的孩子」列表（PR 图1）
/// 孩子卡片（头像/昵称/性别年龄/剩余课时/课程标签/查看）+ 底部虚线添加按钮
final class MyChildrenViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var childItems: [ChildItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadChildren()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "我的孩子")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    private func setupUI() {
        view.backgroundColor = Theme.Color.bg
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 132
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ChildCardCell.self, forCellReuseIdentifier: "ChildCardCell")
        view.addSubview(tableView)
        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }

        // 底部虚线「+添加孩子」
        let addButton = AddChildDashedButton()
        addButton.addTarget(self, action: #selector(didTapAdd), for: .touchUpInside)
        let footer = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 96))
        footer.addSubview(addButton)
        addButton.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.height.equalTo(56)
        }
        tableView.tableFooterView = footer
    }

    private func loadChildren() {
        showLoading()
        ChildService.fetchChildren { [weak self] result in
            guard let self else { return }
            self.hideLoading()
            switch result {
            case .success(let list):
                self.childItems = list
                self.tableView.reloadData()
                if list.isEmpty {
                    self.showEmpty("还没有孩子档案", "点击下方「添加孩子」创建")
                } else {
                    self.tableView.backgroundView = nil
                }
            case .failure(let error):
                self.showToast(error.message ?? "加载失败")
            }
        }
    }

    private func showEmpty(_ title: String, _ subtitle: String) {
        let empty = EmptyStateView()
        empty.show(style: .empty("\(title)\n\(subtitle)"))
        tableView.backgroundView = empty
    }

    @objc private func didTapAdd() {
        let vc = AddChildViewController()
        vc.onSaved = { [weak self] in
            self?.loadChildren()
        }
        let nav = BaseNavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .fullScreen
        present(nav, animated: true)
    }

    // MARK: - TableView

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        childItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ChildCardCell", for: indexPath) as! ChildCardCell
        cell.configure(with: childItems[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let child = childItems[indexPath.row]
        navigationController?.pushViewController(ChildHomeViewController(child: child), animated: true)
    }
}

// MARK: - 孩子卡片 Cell

final class ChildCardCell: UITableViewCell {

    private let card = UIView()
    private let avatarView = UIView()
    private let avatarLabel = UILabel()
    private let nicknameLabel = UILabel()
    private let infoLabel = UILabel()
    private let lessonsLabel = UILabel()
    private let viewButton = UIButton(type: .system)
    private let tagStack = UIStackView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.s)
        }
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        card.layer.borderWidth = 1
        card.layer.borderColor = Theme.Color.line.cgColor

        // 头像
        avatarView.backgroundColor = Theme.Color.brandSoft
        avatarView.layer.cornerRadius = 26
        avatarView.layer.masksToBounds = true
        card.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
            $0.width.height.equalTo(52)
        }

        avatarLabel.font = .appTitle(24)
        avatarLabel.textColor = Theme.Color.brand
        avatarLabel.textAlignment = .center
        avatarView.addSubview(avatarLabel)
        avatarLabel.snp.makeConstraints { $0.edges.equalToSuperview() }

        // 昵称 + 信息
        nicknameLabel.font = .appSection(16)
        nicknameLabel.textColor = Theme.Color.ink
        card.addSubview(nicknameLabel)
        nicknameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarView.snp.trailing).offset(Theme.Spacing.m)
            $0.top.equalTo(avatarView).offset(2)
        }

        infoLabel.font = .appLabel(12)
        infoLabel.textColor = Theme.Color.sub
        card.addSubview(infoLabel)
        infoLabel.snp.makeConstraints {
            $0.leading.equalTo(nicknameLabel)
            $0.top.equalTo(nicknameLabel.snp.bottom).offset(2)
        }

        lessonsLabel.font = .appLabel(12)
        lessonsLabel.textColor = Theme.Color.brand
        card.addSubview(lessonsLabel)
        lessonsLabel.snp.makeConstraints {
            $0.leading.equalTo(nicknameLabel)
            $0.top.equalTo(infoLabel.snp.bottom).offset(2)
        }

        // 查看
        viewButton.setTitle("查看", for: .normal)
        viewButton.titleLabel?.font = .appLabel(12)
        viewButton.setTitleColor(Theme.Color.brand, for: .normal)
        viewButton.backgroundColor = Theme.Color.brandSoft
        viewButton.layer.cornerRadius = 13
        card.addSubview(viewButton)
        viewButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.centerY.equalTo(avatarView)
            $0.width.equalTo(52)
            $0.height.equalTo(26)
        }

        // 课程标签
        tagStack.axis = .horizontal
        tagStack.spacing = Theme.Spacing.s
        card.addSubview(tagStack)
        tagStack.snp.makeConstraints {
            $0.top.equalTo(avatarView.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.equalTo(avatarView)
            $0.trailing.lessThanOrEqualToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(24)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with child: ChildItem) {
        let name = child.nickname
        nicknameLabel.text = name

        if let avatar = child.avatar, avatar.hasPrefix("http") {
            avatarLabel.text = ""
            avatarLabel.isHidden = true
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = avatarView.layer.cornerRadius
            avatarView.addSubview(imageView)
            imageView.snp.makeConstraints { $0.edges.equalToSuperview() }
            if let url = URL(string: avatar) {
                imageView.kf.setImage(with: url)
            }
        } else if let avatar = child.avatar, !avatar.isEmpty {
            avatarLabel.text = avatar
        } else {
            avatarLabel.text = String(name.prefix(1))
        }

        // 性别·年龄
        let gender = child.gender == 2 ? "女" : (child.gender == 1 ? "男" : "")
        let age = child.ageText ?? ""
        infoLabel.text = [gender, age].filter { !$0.isEmpty }.joined(separator: "·")

        // 剩余课时
        lessonsLabel.text = "剩余课时\(child.total_remaining_lessons ?? 0)节"

        // 课程标签（去重前 3）
        tagStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let courses = child.balances?.compactMap { $0.course_title }.uniquePrefix(3) ?? []
        if courses.isEmpty {
            let chip = makeTag("未报名课程", tint: Theme.Color.muted)
            tagStack.addArrangedSubview(chip)
        } else {
            for title in courses {
                tagStack.addArrangedSubview(makeTag(title, tint: Theme.Color.wood))
            }
        }
    }

    private func makeTag(_ text: String, tint: UIColor) -> UIView {
        let view = UIView()
        view.backgroundColor = tint.withAlphaComponent(0.12)
        view.layer.cornerRadius = 12
        let label = UILabel()
        label.text = text
        label.font = .appLabel(11)
        label.textColor = tint
        view.addSubview(label)
        label.snp.makeConstraints {
            $0.edges.equalToSuperview().inset(UIEdgeInsets(top: 3, left: 10, bottom: 3, right: 10))
        }
        return view
    }
}

extension Array where Element == String {
    func uniquePrefix(_ max: Int) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for item in self where !seen.contains(item) {
            seen.insert(item)
            result.append(item)
            if result.count >= max { break }
        }
        return result
    }
}

// MARK: - 虚线添加按钮

final class AddChildDashedButton: UIButton {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setTitle("+ 添加孩子", for: .normal)
        setTitleColor(Theme.Color.brand, for: .normal)
        titleLabel?.font = .appBody(15)
        backgroundColor = Theme.Color.brandSoft
        layer.cornerRadius = Theme.Radius.button
        addDashedBorder()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addDashedBorder() {
        let dashed = CAShapeLayer()
        dashed.strokeColor = Theme.Color.brand.cgColor
        dashed.lineWidth = 1.2
        dashed.lineDashPattern = [5, 4]
        dashed.fillColor = UIColor.clear.cgColor
        dashed.frame = bounds
        dashed.path = UIBezierPath(roundedRect: bounds, cornerRadius: Theme.Radius.button).cgPath
        layer.addSublayer(dashed)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.sublayers?.forEach { layer in
            if let shape = layer as? CAShapeLayer {
                shape.frame = bounds
                shape.path = UIBezierPath(roundedRect: bounds, cornerRadius: Theme.Radius.button).cgPath
            }
        }
    }
}
