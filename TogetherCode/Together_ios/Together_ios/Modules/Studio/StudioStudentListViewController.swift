import UIKit
import SnapKit
import Kingfisher
import ESPullToRefresh

/// 工作室 App 端 · 学员管理
///
/// 分段：全部 / 待续费（剩余课时 ≤ 3）/ 本月新增（本月首次报名）
/// 卡片：头像 + 昵称 + 「年龄 · 主推课程 · 家长」 + 右侧剩余课时（待续费转橙色）
/// 右上搜索：按学员昵称 / 家长检索（接口 q）；点行进学员详情
final class StudioStudentListViewController: BaseViewController {

    // MARK: - 状态

    private var currentFilter: StudioStudentFilter = .all
    private var summary: StudioStudentSummary = .empty
    private var students: [StudioStudentItem] = []
    private var keyword = ""
    private var firstLoad = true
    private var searchDebounce: DispatchWorkItem?

    // MARK: - 视图

    private let headerStack = UIStackView()
    private let searchBar = StudioStudentSearchBar()
    private let filterBar = StudioStudentFilterBar()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let emptyView = EmptyStateView()
    private lazy var searchItem = UIBarButtonItem(customView: makeSearchButton())

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "学员管理")
        navigationItem.rightBarButtonItem = searchItem
        if !firstLoad { loadData() }   // 从详情/退款等返回后刷新剩余课时
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    // MARK: - 布局

    private func setupUI() {
        view.backgroundColor = Theme.Color.bg

        // 内联搜索条（默认收起，点右上搜索展开）
        searchBar.isHidden = true
        searchBar.onChange = { [weak self] text in self?.scheduleSearch(text) }
        searchBar.onCancel = { [weak self] in self?.closeSearch() }

        filterBar.onSelect = { [weak self] index in
            guard let self, let filter = StudioStudentFilter.allCases[safe: index] else { return }
            self.currentFilter = filter
            self.loadData()
        }

        headerStack.axis = .vertical
        headerStack.spacing = 10
        headerStack.addArrangedSubview(searchBar)
        headerStack.addArrangedSubview(filterBar)
        view.addSubview(headerStack)
        headerStack.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }
        searchBar.snp.makeConstraints { $0.height.equalTo(42) }
        filterBar.snp.makeConstraints { $0.height.equalTo(43) }

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(StudioStudentCell.self, forCellReuseIdentifier: StudioStudentCell.reuseID)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 74
        tableView.keyboardDismissMode = .onDrag
        // iOS 15+ plain 样式首个 section 前会凭空多出 22pt（首行卡片离筛选条很远）→ 归零
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.es.addPullToRefresh(animator: BrandRefreshHeader()) { [weak self] in
            self?.loadData()
        }
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(headerStack.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        emptyView.isHidden = true
        view.addSubview(emptyView)
        emptyView.snp.makeConstraints {
            $0.centerX.equalTo(tableView)
            $0.centerY.equalTo(tableView)
        }
    }

    private func makeSearchButton() -> UIButton {
        let button = UIButton(type: .system)
        button.backgroundColor = Theme.Color.surface
        button.layer.cornerRadius = 12
        button.layer.shadowColor = UIColor(hex: 0x2B2621).cgColor
        button.layer.shadowOpacity = 0.05
        button.layer.shadowRadius = 8
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.setImage(
            UIImage(systemName: "magnifyingglass")?.withConfiguration(
                UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
            ),
            for: .normal
        )
        button.tintColor = Theme.Color.ink
        button.addTarget(self, action: #selector(tapSearch), for: .touchUpInside)
        button.snp.makeConstraints { $0.width.height.equalTo(36) }
        return button
    }

    // MARK: - 搜索

    @objc private func tapSearch() {
        if searchBar.isHidden {
            searchBar.isHidden = false
            UIView.animate(withDuration: 0.22) { self.view.layoutIfNeeded() }
        }
        searchBar.focus()
    }

    private func closeSearch() {
        searchBar.clear()
        searchBar.resign()
        searchBar.isHidden = true
        UIView.animate(withDuration: 0.22) { self.view.layoutIfNeeded() }
        if !keyword.isEmpty {
            keyword = ""
            loadData()
        }
    }

    /// 输入防抖：停止输入 0.35s 后再请求
    private func scheduleSearch(_ text: String) {
        searchDebounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed != self.keyword else { return }
            self.keyword = trimmed
            self.loadData()
        }
        searchDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    // MARK: - 数据

    private func loadData() {
        if firstLoad { emptyView.show(style: .loading) }
        StudioService.fetchStudents(filter: currentFilter, keyword: keyword) { [weak self] result in
            guard let self else { return }
            self.firstLoad = false
            self.tableView.es.stopPullToRefresh()
            switch result {
            case .success(let page):
                self.summary = page.summary ?? .empty
                self.students = page.list ?? []
                self.filterBar.update(summary: self.summary)
                self.tableView.reloadData()
                self.applyEmptyState()
            case .failure(let error):
                self.emptyView.isHidden = false
                self.emptyView.show(style: .error(error.message ?? "加载失败") { [weak self] in
                    self?.loadData()
                })
            }
        }
    }

    private func applyEmptyState() {
        if students.isEmpty {
            emptyView.isHidden = false
            // 结果为空但工作室有学员 → 说明是筛选/搜索导致，提示换条件
            let text = summary.count(for: .all) > 0 && !keyword.isEmpty
                ? "没有找到「\(keyword)」相关学员"
                : currentFilter.emptyText
            emptyView.show(style: .empty(text))
        } else {
            emptyView.isHidden = true
        }
    }

    private func openDetail(_ student: StudioStudentItem) {
        let vc = StudioStudentDetailViewController(childId: student.child_id, nickname: student.displayName)
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - 列表

extension StudioStudentListViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        students.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: StudioStudentCell.reuseID, for: indexPath) as! StudioStudentCell
        cell.configure(students[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        openDetail(students[indexPath.row])
    }
}

// MARK: - 分段筛选条（全部 / 待续费 / 本月新增）

/// 白色圆角卡片内三段等分：选中态浅绿胶囊 + 深色字，未选态透明底 + 棕色字
private final class StudioStudentFilterBar: UIView {

    var onSelect: ((Int) -> Void)?

    private let stack = UIStackView()
    private var buttons: [UIButton] = []
    private var summary: StudioStudentSummary = .empty
    private var selectedIndex = 0

    init() {
        super.init(frame: .zero)
        backgroundColor = Theme.Color.surface
        layer.cornerRadius = Theme.Radius.card
        layer.shadowColor = UIColor(hex: 0x2B2621).cgColor
        layer.shadowOpacity = 0.04
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 3)

        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 0
        addSubview(stack)
        stack.snp.makeConstraints { $0.edges.equalToSuperview().inset(4) }

        for (index, filter) in StudioStudentFilter.allCases.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.layer.cornerRadius = 13
            button.addTarget(self, action: #selector(didTap(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
            buttons.append(button)
        }
        applySelection()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(summary: StudioStudentSummary) {
        self.summary = summary
        applySelection()
    }

    @objc private func didTap(_ sender: UIButton) {
        guard sender.tag != selectedIndex else { return }
        selectedIndex = sender.tag
        applySelection()
        onSelect?(sender.tag)
    }

    private func applySelection() {
        for (index, button) in buttons.enumerated() {
            let filter = StudioStudentFilter.allCases[index]
            let selected = index == selectedIndex
            button.backgroundColor = selected ? Theme.Color.brandSoft : .clear
            button.setAttributedTitle(attributedTitle(filter: filter, selected: selected), for: .normal)
        }
    }

    /// 「全部 186」：文案 + 定宽空格 + 数字，选中加粗
    private func attributedTitle(filter: StudioStudentFilter, selected: Bool) -> NSAttributedString {
        let text = "\(filter.title) \(summary.count(for: filter))"
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        return NSAttributedString(
            string: text,
            attributes: [
                .font: selected ? UIFont.appSection(14) : UIFont.appBody(14),
                .foregroundColor: selected ? Theme.Color.ink : Theme.Color.sub,
                .paragraphStyle: paragraph
            ]
        )
    }
}

// MARK: - 内联搜索条

private final class StudioStudentSearchBar: UIView, UITextFieldDelegate {

    var onChange: ((String) -> Void)?
    var onCancel: (() -> Void)?

    /// 输入卡与「取消」之间的间距
    private static let cancelWidth: CGFloat = 44
    private static let cancelGap: CGFloat = 10

    private let fieldCard = UIView()
    private let icon = UIImageView()
    private let textField = UITextField()
    private let cancelButton = UIButton(type: .system)

    init() {
        super.init(frame: .zero)
        backgroundColor = .clear

        // 输入卡（白色圆角）只占左侧，右侧留给「取消」
        fieldCard.backgroundColor = Theme.Color.surface
        fieldCard.layer.cornerRadius = 14
        addSubview(fieldCard)

        icon.image = UIImage(systemName: "magnifyingglass")?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        )
        icon.tintColor = Theme.Color.muted
        icon.contentMode = .center
        fieldCard.addSubview(icon)
        icon.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(12)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(18)
        }

        textField.placeholder = "搜索学员昵称 / 家长"
        textField.font = .appBody(14)
        textField.textColor = Theme.Color.ink
        textField.tintColor = Theme.Color.brand
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .search
        textField.delegate = self
        textField.addTarget(self, action: #selector(editingChanged), for: .editingChanged)
        fieldCard.addSubview(textField)
        textField.snp.makeConstraints {
            $0.leading.equalTo(icon.snp.trailing).offset(8)
            $0.trailing.equalToSuperview().offset(-12)
            $0.centerY.equalToSuperview()
        }

        // 先 addSubview 再互相引用：SnapKit 会立即激活约束，引用的视图必须先在同一层级
        cancelButton.setTitle("取消", for: .normal)
        cancelButton.titleLabel?.font = .appBody(14)
        cancelButton.setTitleColor(Theme.Color.sub, for: .normal)
        // 定宽 + 内容右对齐：文字始终贴着容器右边缘，不会被按钮自身尺寸带跑
        cancelButton.contentHorizontalAlignment = .right
        cancelButton.addTarget(self, action: #selector(tapCancel), for: .touchUpInside)
        addSubview(cancelButton)
        cancelButton.snp.makeConstraints {
            $0.trailing.equalToSuperview()
            $0.centerY.equalToSuperview()
            $0.width.equalTo(Self.cancelWidth)
            $0.height.equalTo(30)
        }

        fieldCard.snp.makeConstraints {
            $0.leading.top.bottom.equalToSuperview()
            $0.trailing.equalTo(cancelButton.snp.leading).offset(-Self.cancelGap)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func focus() { textField.becomeFirstResponder() }
    func resign() { textField.resignFirstResponder() }

    func clear() {
        textField.text = ""
    }

    @objc private func editingChanged() {
        onChange?(textField.text ?? "")
    }

    @objc private func tapCancel() { onCancel?() }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - 学员卡片

private final class StudioStudentCell: UITableViewCell {

    static let reuseID = "StudioStudentCell"

    private let card = UIView()
    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let subLabel = UILabel()
    private let valueStack = UIStackView()
    private let lessonsLabel = UILabel()
    private let captionLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupUI() {
        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = Theme.Radius.card
        card.layer.shadowColor = UIColor(hex: 0x2B2621).cgColor
        card.layer.shadowOpacity = 0.04
        card.layer.shadowRadius = 10
        card.layer.shadowOffset = CGSize(width: 0, height: 3)
        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalToSuperview().offset(5)
            $0.bottom.equalToSuperview().offset(-5)
        }

        // 头像（无图时按 id 取稳定色块）
        avatarView.layer.cornerRadius = 21
        avatarView.clipsToBounds = true
        avatarView.contentMode = .scaleAspectFill
        avatarView.backgroundColor = Theme.Color.surfaceAlt
        card.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(12)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(42)
        }

        // 右侧剩余课时（垂直堆叠，右对齐）
        // 抗压缩设为 required：副标题过长时只截断副标题，绝不让「剩余课时 / 待续费」被挤没
        lessonsLabel.font = .appSection(16)
        lessonsLabel.textAlignment = .right
        lessonsLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        captionLabel.font = .appLabel(11)
        captionLabel.textColor = Theme.Color.muted
        captionLabel.textAlignment = .right
        captionLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueStack.axis = .vertical
        valueStack.alignment = .trailing
        valueStack.spacing = 2
        valueStack.addArrangedSubview(lessonsLabel)
        valueStack.addArrangedSubview(captionLabel)
        card.addSubview(valueStack)
        valueStack.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-14)
            $0.centerY.equalToSuperview()
        }

        // 昵称 + 副标题（上/下内侧间距撑出卡片高度 = 14 + 20 + 4 + 16 + 14 ≈ 64）
        nameLabel.font = .appSection(15)
        nameLabel.textColor = Theme.Color.ink
        nameLabel.numberOfLines = 1
        card.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(14)
            $0.leading.equalTo(avatarView.snp.trailing).offset(12)
            $0.trailing.lessThanOrEqualTo(valueStack.snp.leading).offset(-8)
        }

        subLabel.font = .appLabel(12)
        subLabel.textColor = Theme.Color.muted
        subLabel.numberOfLines = 1
        card.addSubview(subLabel)
        subLabel.snp.makeConstraints {
            $0.top.equalTo(nameLabel.snp.bottom).offset(4)
            $0.leading.equalTo(nameLabel)
            $0.trailing.lessThanOrEqualTo(valueStack.snp.leading).offset(-8)
            $0.bottom.equalToSuperview().offset(-14)
        }
    }

    func configure(_ student: StudioStudentItem) {
        nameLabel.text = student.displayName
        subLabel.text = student.subtitle
        lessonsLabel.text = student.lessonsText
        lessonsLabel.textColor = student.isRenew ? Theme.Color.warn : Theme.Color.brandDark
        captionLabel.text = student.lessonsCaption
        captionLabel.textColor = student.isRenew ? Theme.Color.warn : Theme.Color.muted

        if let urlString = student.avatar, let url = URL(string: urlString), !urlString.isEmpty {
            avatarView.backgroundColor = Theme.Color.surfaceAlt
            avatarView.kf.setImage(with: url)
        } else {
            avatarView.kf.cancelDownloadTask()
            avatarView.image = nil
            avatarView.backgroundColor = StudioStudentAvatarTint(student.child_id)
        }
    }
}

/// 学员头像占位色（设计稿为纯色圆形，按 child_id 稳定取色）
private func StudioStudentAvatarTint(_ id: String) -> UIColor {
    let palette: [UInt32] = [0x93B978, 0x87B3C8, 0xD9BA75, 0xBA96C8, 0xBB96B2, 0x8FBFB0]
    var hash = 0
    for u in id.unicodeScalars { hash = (hash &* 31) &+ Int(u.value) }
    return UIColor(hex: palette[abs(hash) % palette.count])
}

// MARK: - 便捷下标

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
