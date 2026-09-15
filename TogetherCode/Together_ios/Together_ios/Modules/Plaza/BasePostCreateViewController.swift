import UIKit
import SnapKit
import HXPhotoPicker
import SwiftyJSON

/// 发布动态公共基类（家长 / 老师两端复用）
/// 公共：导航（发布动态 + × 关闭）、底部发布栏、正文输入、图片九宫格、话题、谁可以看、卡片样式、选择器弹窗
/// 子类实现：loadFormData / validateForm / publish / TableView 数据源
/// PR 图：顶部"发布动态" + 右上角 × 关闭；图片九宫格；底部胶囊发布按钮
class BasePostCreateViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate {

    // MARK: - 表单状态（子类可读写）

    var images: [UIImage] = []
    var topic = ""
    var visibility = 2 // 2 公开 / 1 仅好友
    var topics: [String] = []

    // MARK: - UI

    let tableView = UITableView(frame: .zero, style: .plain)
    private let bottomBar = UIView()
    private let publishButton = UIButton(type: .system)

    // MARK: - 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadFormData()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: "发布动态")
        // PR 图：右上角 × 关闭（无返回箭头）
        navigationItem.leftBarButtonItem = nil
        navigationItem.hidesBackButton = true
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = Theme.Color.ink
        closeButton.backgroundColor = Theme.Color.ink.withAlphaComponent(0.06)
        closeButton.layer.cornerRadius = 19
        closeButton.clipsToBounds = true
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        closeButton.snp.makeConstraints { $0.width.height.equalTo(38) }
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: closeButton)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    private func setupUI() {
        view.backgroundColor = Theme.Color.bg

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .onDrag
        tableView.estimatedRowHeight = 120
        // 关闭系统 header/footer 的额外间距，分组间距完全由页面控制（保证对称）
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.register(ImageGridCell.self, forCellReuseIdentifier: ImageGridCell.reuseId)
        tableView.register(TextCell.self, forCellReuseIdentifier: TextCell.reuseId)
        tableView.register(PickerCell.self, forCellReuseIdentifier: PickerCell.reuseId)
        tableView.register(SwitchCell.self, forCellReuseIdentifier: SwitchCell.reuseId)
        tableView.register(TeacherClassCell.self, forCellReuseIdentifier: TeacherClassCell.reuseId)
        tableView.register(ConsumeCell.self, forCellReuseIdentifier: ConsumeCell.reuseId)
        tableView.register(VisibilityCell.self, forCellReuseIdentifier: VisibilityCell.reuseId)
        // 底部发布栏（先添加，tableView 底部约束引用它，内容不被遮挡）
        bottomBar.backgroundColor = Theme.Color.surface
        view.addSubview(bottomBar)
        bottomBar.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
        }
        publishButton.setTitle("发布动态", for: .normal)
        publishButton.setTitleColor(.white, for: .normal)
        publishButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        publishButton.backgroundColor = Theme.Color.brand
        publishButton.layer.cornerRadius = 22
        publishButton.clipsToBounds = true
        publishButton.addTarget(self, action: #selector(didTapPublish), for: .touchUpInside)
        bottomBar.addSubview(publishButton)
        publishButton.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(44)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.xl)
        }

        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            // 从导航栏下方开始，顶部留 16pt 呼吸距离；底部到发布栏顶部留 8pt，内容可完整滚动露出
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(bottomBar.snp.top).offset(-Theme.Spacing.s)
        }
        // 底部 bar 上移避免遮挡键盘
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    // MARK: - 子类扩展点

    /// 拉取表单数据（孩子/课程班级/课次/话题等）
    func loadFormData() {}

    /// 发布前业务校验，返回 false 则中止（内部自行 toast 提示）
    func validateForm() -> Bool { true }

    /// 图片上传成功后真正发布
    func publish(content: String, imageUrls: [String]) {}

    /// 拉取发帖话题（公共接口，家长/老师都使用）
    func loadTopics(reloadSection: Int) {
        PostService.fetchTopics { [weak self] topics, _ in
            guard let self else { return }
            if let topics, !topics.isEmpty {
                self.topics = topics
            } else if self.topics.isEmpty {
                // 兜底：接口异常时仍可发帖
                self.topics = ["成长记录", "作品秀", "育儿经", "探店"]
            }
            if reloadSection < self.tableView.numberOfSections {
                self.tableView.reloadSections(IndexSet(integer: reloadSection), with: .none)
            }
        }
    }

    // MARK: - TableView 默认空实现（子类 override）

    func numberOfSections(in tableView: UITableView) -> Int { 0 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 0 }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell { UITableViewCell() }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { UITableView.automaticDimension }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 16 }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat { 0.001 }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? { nil }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {}

    // MARK: - 公共 Cell 工厂

    /// plain 分组下统一卡片样式：白底圆角 12、左右缩进 16
    @discardableResult
    func card(_ cell: UITableViewCell) -> UITableViewCell {
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        let tag = 9_876
        if cell.contentView.viewWithTag(tag) == nil {
            let cardView = UIView()
            cardView.tag = tag
            cardView.backgroundColor = Theme.Color.surface
            cardView.layer.cornerRadius = 12
            cardView.clipsToBounds = true
            cell.contentView.addSubview(cardView)
            cell.contentView.sendSubviewToBack(cardView)
            cardView.snp.makeConstraints { make in
                make.top.bottom.equalToSuperview()
                make.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            }
        }
        return cell
    }

    /// 话题标签行（"选择话题"标题 + 流式标签）
    func topicCell(_ tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "topicTag")
        cell.backgroundColor = Theme.Color.surface
        cell.selectionStyle = .none
        _ = embedTagView(
            in: cell,
            title: "选择话题",
            options: topics.map { "#\($0)" },
            selected: [],
            multiple: false
        ) { [weak self] tags in
            self?.topic = tags.first?.replacingOccurrences(of: "#", with: "") ?? ""
        }
        return cell
    }

    /// 谁可以看
    func visibilityCell(_ tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: VisibilityCell.reuseId, for: indexPath) as! VisibilityCell
        cell.setIndex(visibility == 2 ? 0 : 1)
        cell.onChange = { [weak self] index in
            self?.visibility = index == 0 ? 2 : 1
        }
        return cell
    }

    /// 标签嵌入 cell 统一封装（每次重建，避免 cell 复用导致 chips 丢失）
    @discardableResult
    func embedTagView(
        in cell: UITableViewCell,
        title: String?,
        options: [String],
        selected: Set<String>,
        multiple: Bool,
        onSelect: @escaping (Set<String>) -> Void
    ) -> TagSelectView {
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        var topItem: ConstraintRelatableTarget = cell.contentView.snp.top
        if let title {
            let label = UILabel()
            label.text = title
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.textColor = Theme.Color.sub
            cell.contentView.addSubview(label)
            label.snp.makeConstraints {
                $0.top.equalToSuperview().offset(Theme.Spacing.l)
                $0.leading.equalToSuperview().offset(Theme.Spacing.l * 2)
                $0.trailing.lessThanOrEqualToSuperview().offset(-Theme.Spacing.l * 2)
            }
            topItem = label.snp.bottom
        }
        let tagView = TagSelectView(options: options, selected: selected)
        tagView.allowsMultipleSelection = multiple
        tagView.onSelectionChanged = onSelect
        cell.contentView.addSubview(tagView)
        tagView.snp.makeConstraints {
            $0.top.equalTo(topItem).offset(title != nil ? Theme.Spacing.s : Theme.Spacing.l)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l * 2)
        }
        return tagView
    }

    /// 按文本宽度估算流式标签行高（TagSelectView 初始 intrinsic 为 0，cell 需显式高度）
    func tagRowsHeight(_ titles: [String]) -> CGFloat {
        guard !titles.isEmpty else { return 34 }
        let gap: CGFloat = Theme.Spacing.m
        let lineHeight: CGFloat = 34
        let width = UIScreen.main.bounds.width - Theme.Spacing.l * 2 - Theme.Spacing.m * 2
        var x: CGFloat = 0
        var rows: CGFloat = 1
        for title in titles {
            let w = (title as NSString).size(withAttributes: [.font: UIFont.appLabel(12)]).width + 32
            if x > 0 && x + w > width {
                x = 0
                rows += 1
            }
            x += w + gap
        }
        return rows * lineHeight + (rows - 1) * gap
    }

    // MARK: - 图片

    func pickImages() {
        view.endEditing(true)
        var config = PickerConfiguration()
        config.selectOptions = [.photo]
        config.maximumSelectedCount = max(1, 9 - images.count)
        let picker = PhotoPickerController(config: config)
        picker.finishHandler = { [weak self] result, _ in
            guard let self else { return }
            result.getImage(targetSize: CGSize(width: 1600, height: 1600)) { [weak self] images in
                guard let self else { return }
                for image in images where self.images.count < 9 {
                    self.images.append(image)
                }
                self.tableView.reloadData()
            }
        }
        present(picker, animated: true)
    }

    func updateImageCellHeight() {
        // 图片区固定 section 1
        if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 1)) as? ImageGridCell {
            cell.configure(images: images)
        }
        tableView.beginUpdates()
        tableView.endUpdates()
    }

    // MARK: - 发布

    @objc func didTapPublish() {
        view.endEditing(true)
        guard !images.isEmpty else {
            showToast("请至少上传一张作品图片")
            return
        }
        // 正文在 section 0
        let content = (tableView.cellForRow(at: IndexPath(row: 0, section: 0)) as? TextCell)?.text ?? ""
        guard validateForm() else { return }

        showLoading("发布中...")
        uploadAndPublish(content: content)
    }

    private func uploadAndPublish(content: String) {
        let datas = images.compactMap { $0.jpegData(compressionQuality: 0.8) }
        APIClient.shared.upload(files: datas, folder: "post") { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let json):
                let urls = json["urls"].arrayValue.map { $0.stringValue }
                if urls.isEmpty {
                    self.hideLoading()
                    self.showToast("图片上传失败")
                    return
                }
                self.publish(content: content, imageUrls: urls)
            case .failure(let error):
                self.hideLoading()
                self.showToast(error.message)
            }
        }
    }

    /// 发布成功统一处理
    func handlePublishSuccess(postId: String?, error: String?) {
        hideLoading()
        if let postId, !postId.isEmpty {
            showToast("发布成功")
            NotificationCenter.default.post(name: .postPublished, object: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self.dismiss(animated: true)
            }
        } else {
            showToast(error ?? "发布失败")
        }
    }

    // MARK: - 键盘

    @objc private func keyboardWillChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let frame = info[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let bottomInset = max(0, UIScreen.main.bounds.height - frame.minY)
        tableView.contentInset.bottom = bottomInset
        tableView.verticalScrollIndicatorInsets.bottom = bottomInset
        bottomBar.snp.updateConstraints {
            $0.bottom.equalToSuperview().offset(-bottomInset)
        }
        view.layoutIfNeeded()
    }

    @objc private func didTapClose() {
        view.endEditing(true)
        dismiss(animated: true)
    }
}

// MARK: - 通知

extension Notification.Name {
    static let postPublished = Notification.Name("postPublished")
}

// MARK: - 图片九宫格 Cell

final class ImageGridCell: UITableViewCell, UICollectionViewDataSource, UICollectionViewDelegate {

    static let reuseId = "ImageGridCell"

    var images: [UIImage] = []
    var onAdd: (() -> Void)?
    var onDelete: ((Int) -> Void)?
    var onPreview: ((Int) -> Void)?

    private let collectionView: UICollectionView
    private let maxCount = 9

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 100, height: 100)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.surface
        selectionStyle = .none

        collectionView.isScrollEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(ImageItemCell.self, forCellWithReuseIdentifier: "ImageItemCell")
        contentView.addSubview(collectionView)
        collectionView.snp.makeConstraints {
            // 上下距卡片 16、左右距卡片 16（卡片本身缩进 16，故相对 contentView 为 32）
            $0.top.bottom.equalToSuperview().inset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l * 2)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(images: [UIImage]) {
        self.images = images
        collectionView.reloadData()
    }

    private var side: CGFloat { 100 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        min(images.count + 1, maxCount)
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageItemCell", for: indexPath) as! ImageItemCell
        if indexPath.item < images.count {
            cell.configure(image: images[indexPath.item], isAdd: false)
            cell.onDelete = { [weak self] in
                guard let self else { return }
                self.onDelete?(indexPath.item)
            }
        } else {
            cell.configure(image: nil, isAdd: true)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.item < images.count {
            onPreview?(indexPath.item)
        } else {
            onAdd?()
        }
    }
}

private final class ImageItemCell: UICollectionViewCell {
    var onDelete: (() -> Void)?

    private let imageView = UIImageView()
    private let addLabel = UILabel()
    private let addSubLabel = UILabel()
    private let deleteButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 10
        contentView.clipsToBounds = true
        contentView.backgroundColor = Theme.Color.surfaceAlt

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        contentView.addSubview(imageView)
        imageView.snp.makeConstraints { $0.edges.equalToSuperview() }

        addLabel.text = "+"
        addLabel.font = .systemFont(ofSize: 38, weight: .light)
        addLabel.textColor = Theme.Color.sub
        addLabel.textAlignment = .center
        contentView.addSubview(addLabel)
        addLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalToSuperview().offset(-8)
        }

        addSubLabel.text = "添加图片"
        addSubLabel.font = .systemFont(ofSize: 10, weight: .regular)
        addSubLabel.textColor = Theme.Color.sub.withAlphaComponent(0.9)
        addSubLabel.textAlignment = .center
        contentView.addSubview(addSubLabel)
        addSubLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.top.equalTo(addLabel.snp.bottom).offset(2)
        }

        deleteButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        deleteButton.tintColor = UIColor.black.withAlphaComponent(0.55)
        deleteButton.addTarget(self, action: #selector(didTapDelete), for: .touchUpInside)
        contentView.addSubview(deleteButton)
        deleteButton.snp.makeConstraints {
            $0.top.trailing.equalToSuperview()
            $0.width.height.equalTo(24)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(image: UIImage?, isAdd: Bool) {
        imageView.isHidden = isAdd       // 加号格不显示图片
        addLabel.isHidden = !isAdd       // 加号格显示 +
        addSubLabel.isHidden = !isAdd    // 加号格显示"添加图片"
        deleteButton.isHidden = isAdd    // 加号格无删除按钮
        if !isAdd { imageView.image = image }
    }

    @objc private func didTapDelete() { onDelete?() }
}

// MARK: - 正文 Cell

final class TextCell: UITableViewCell, UITextViewDelegate {

    static let reuseId = "TextCell"

    var onTextChange: ((String) -> Void)?
    var placeholder: String = "" {
        didSet { placeholderLabel.text = placeholder }
    }
    var maxLength = 100

    var text: String { textView.text }

    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    private let countLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.surface
        selectionStyle = .none

        textView.font = .appBody(15)
        textView.textColor = Theme.Color.ink
        textView.backgroundColor = .clear
        textView.delegate = self
        // 高度随内容自适应（cell automaticDimension），最小 72pt → cell 最小 96pt
        textView.isScrollEnabled = false
        contentView.addSubview(textView)
        textView.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l * 2)
            $0.height.greaterThanOrEqualTo(72)
        }

        placeholderLabel.font = .appBody(15)
        placeholderLabel.textColor = Theme.Color.sub.withAlphaComponent(0.7)
        placeholderLabel.numberOfLines = 0
        contentView.addSubview(placeholderLabel)
        placeholderLabel.snp.makeConstraints {
            $0.top.equalTo(textView).offset(7)
            $0.leading.equalTo(textView).offset(4)
            $0.trailing.lessThanOrEqualTo(textView).offset(-4)
        }

        countLabel.font = .appLabel(11)
        countLabel.textColor = Theme.Color.sub.withAlphaComponent(0.6)
        countLabel.textAlignment = .right
        contentView.addSubview(countLabel)
        countLabel.snp.makeConstraints {
            $0.trailing.equalTo(textView).offset(-2)
            $0.bottom.equalTo(textView)
        }
        updateCount()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        updateCount()
        onTextChange?(textView.text)
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let newText = (textView.text as NSString).replacingCharacters(in: range, with: text)
        return newText.count <= maxLength
    }

    private func updateCount() {
        countLabel.text = "\(textView.text.count)/\(maxLength)"
    }
}

// MARK: - 选择行 Cell

final class PickerCell: UITableViewCell {
    static let reuseId = "PickerCell"

    var title: String = "" { didSet { titleLabel.text = title } }
    var detail: String = "" { didSet { detailLabel.text = detail } }

    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let chevron = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.surface
        titleLabel.font = .appBody(15)
        titleLabel.textColor = Theme.Color.ink
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.bottom.equalToSuperview().inset(Theme.Spacing.l)
            $0.leading.equalToSuperview().offset(Theme.Spacing.l * 2)
        }

        chevron.image = UIImage(systemName: "chevron.right")
        chevron.tintColor = Theme.Color.sub.withAlphaComponent(0.5)
        chevron.contentMode = .scaleAspectFit
        contentView.addSubview(chevron)
        chevron.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.l * 2)
            $0.width.equalTo(12)
            $0.height.equalTo(14)
        }

        detailLabel.font = .appBody(14)
        detailLabel.textColor = Theme.Color.sub
        detailLabel.textAlignment = .right
        contentView.addSubview(detailLabel)
        detailLabel.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.trailing.equalTo(chevron.snp.leading).offset(-4)
            $0.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(Theme.Spacing.m)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 课程·班级 + 选择学生 合并卡片

final class TeacherClassCell: UITableViewCell {
    static let reuseId = "TeacherClassCell"

    var onTapClass: (() -> Void)?
    var onStudentsChanged: ((Set<String>) -> Void)?

    private let classTitleLabel = UILabel()
    private let detailLabel = UILabel()
    private let chevron = UIImageView()
    private let divider = UIView()
    private let studentTitleLabel = UILabel()
    private var tagView: TagSelectView?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.surface
        selectionStyle = .none

        classTitleLabel.font = .appBody(15)
        classTitleLabel.textColor = Theme.Color.ink
        classTitleLabel.text = "课程 · 班级"
        contentView.addSubview(classTitleLabel)
        classTitleLabel.snp.makeConstraints {
            $0.top.equalToSuperview()
            $0.leading.equalToSuperview().offset(Theme.Spacing.l * 2)
            $0.height.equalTo(48)
        }

        chevron.image = UIImage(systemName: "chevron.right")
        chevron.tintColor = Theme.Color.sub.withAlphaComponent(0.5)
        chevron.contentMode = .scaleAspectFit
        contentView.addSubview(chevron)
        chevron.snp.makeConstraints {
            $0.centerY.equalTo(classTitleLabel)
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.l * 2)
            $0.width.equalTo(12)
            $0.height.equalTo(14)
        }

        detailLabel.font = .appBody(14)
        detailLabel.textColor = Theme.Color.sub
        detailLabel.textAlignment = .right
        contentView.addSubview(detailLabel)
        detailLabel.snp.makeConstraints {
            $0.centerY.equalTo(classTitleLabel)
            $0.trailing.equalTo(chevron.snp.leading).offset(-4)
            $0.leading.greaterThanOrEqualTo(classTitleLabel.snp.trailing).offset(Theme.Spacing.m)
        }

        divider.backgroundColor = Theme.Color.line
        contentView.addSubview(divider)
        divider.snp.makeConstraints {
            $0.top.equalTo(classTitleLabel.snp.bottom)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l * 2)
            $0.height.equalTo(0.5)
        }

        studentTitleLabel.text = "选择学生"
        studentTitleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        studentTitleLabel.textColor = Theme.Color.sub
        contentView.addSubview(studentTitleLabel)
        studentTitleLabel.snp.makeConstraints {
            $0.top.equalTo(divider.snp.bottom).offset(12)
            $0.leading.equalToSuperview().offset(Theme.Spacing.l * 2)
            $0.height.equalTo(18)
        }
    }

    func configure(classDetail: String, students: [String], selected: Set<String>, hasClass: Bool) {
        detailLabel.text = classDetail

        // 未选班级：只显示"课程·班级"一行（无线、无学生区）
        divider.isHidden = !hasClass
        studentTitleLabel.isHidden = !hasClass
        tagView?.removeFromSuperview()
        tagView = nil
        guard hasClass else { return }

        let tag = TagSelectView(options: students, selected: selected)
        tag.allowsMultipleSelection = true
        tag.onSelectionChanged = { [weak self] tags in self?.onStudentsChanged?(tags) }
        contentView.addSubview(tag)
        tag.snp.makeConstraints {
            $0.top.equalTo(studentTitleLabel.snp.bottom).offset(8)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l * 2)
        }
        tagView = tag
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 同步消课 + 上课课次 合并卡片

final class ConsumeCell: UITableViewCell {
    static let reuseId = "ConsumeCell"

    var onSwitch: ((Bool) -> Void)?
    var onTapSchedule: (() -> Void)?

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let switchControl = UISwitch()
    private let divider = UIView()
    private let scheduleTitleLabel = UILabel()
    private let scheduleDetailLabel = UILabel()
    private let scheduleChevron = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.surface
        selectionStyle = .none

        switchControl.onTintColor = Theme.Color.brand
        switchControl.addTarget(self, action: #selector(switched(_:)), for: .valueChanged)

        titleLabel.font = .appBody(15)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.text = "发布后同步消课"

        subtitleLabel.font = .appBody(12)
        subtitleLabel.textColor = Theme.Color.sub
        subtitleLabel.text = "开启后为所选学生扣除本节课时"

        divider.backgroundColor = Theme.Color.line

        scheduleTitleLabel.font = .appBody(15)
        scheduleTitleLabel.textColor = Theme.Color.ink
        scheduleTitleLabel.text = "上课课次"

        scheduleChevron.image = UIImage(systemName: "chevron.right")
        scheduleChevron.tintColor = Theme.Color.sub.withAlphaComponent(0.5)
        scheduleChevron.contentMode = .scaleAspectFit

        scheduleDetailLabel.font = .appBody(14)
        scheduleDetailLabel.textColor = Theme.Color.sub
        scheduleDetailLabel.textAlignment = .right

        // 先全部 addSubview 再统一约束，避免跨层级引用崩溃
        [titleLabel, subtitleLabel, switchControl, divider, scheduleTitleLabel, scheduleDetailLabel, scheduleChevron].forEach {
            contentView.addSubview($0)
        }

        switchControl.snp.makeConstraints {
            $0.centerY.equalTo(titleLabel)
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.l * 2)
        }

        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.equalToSuperview().offset(Theme.Spacing.l * 2)
            $0.trailing.lessThanOrEqualTo(switchControl.snp.leading).offset(-Theme.Spacing.m)
        }

        subtitleLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(2)
            $0.leading.equalTo(titleLabel)
            $0.trailing.lessThanOrEqualTo(switchControl.snp.leading).offset(-Theme.Spacing.m)
        }

        divider.snp.makeConstraints {
            $0.top.equalTo(subtitleLabel.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l * 2)
            $0.height.equalTo(0.5)
        }

        scheduleTitleLabel.snp.makeConstraints {
            $0.top.equalTo(divider.snp.bottom)
            $0.leading.equalToSuperview().offset(Theme.Spacing.l * 2)
            $0.height.equalTo(48)
        }

        scheduleChevron.snp.makeConstraints {
            $0.centerY.equalTo(scheduleTitleLabel)
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.l * 2)
            $0.width.equalTo(12)
            $0.height.equalTo(14)
        }

        scheduleDetailLabel.snp.makeConstraints {
            $0.centerY.equalTo(scheduleTitleLabel)
            $0.trailing.equalTo(scheduleChevron.snp.leading).offset(-4)
            $0.leading.greaterThanOrEqualTo(scheduleTitleLabel.snp.trailing).offset(Theme.Spacing.m)
        }
    }

    func configure(switchValue: Bool, showSchedule: Bool, scheduleDetail: String) {
        switchControl.isOn = switchValue
        scheduleDetailLabel.text = scheduleDetail
        // 消课关闭时课次行与分割线都不显示
        divider.isHidden = !showSchedule
        scheduleTitleLabel.isHidden = !showSchedule
        scheduleChevron.isHidden = !showSchedule
        scheduleDetailLabel.isHidden = !showSchedule
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func switched(_ sender: UISwitch) { onSwitch?(sender.isOn) }
}

// MARK: - 开关行 Cell

final class SwitchCell: UITableViewCell {
    static let reuseId = "SwitchCell"

    var title: String = "" { didSet { titleLabel.text = title } }
    var subtitle: String = "" { didSet { subtitleLabel.text = subtitle } }
    var switchValue: Bool = false { didSet { switchControl.isOn = switchValue } }
    var onSwitch: ((Bool) -> Void)?

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let switchControl = UISwitch()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.surface
        selectionStyle = .none

        // 先 addSubview 再约束：label 的 trailing 会引用 switch 的 leading
        switchControl.onTintColor = Theme.Color.brand
        switchControl.addTarget(self, action: #selector(switched(_:)), for: .valueChanged)
        contentView.addSubview(switchControl)
        switchControl.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.m)
        }

        titleLabel.font = .appBody(15)
        titleLabel.textColor = Theme.Color.ink
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.equalToSuperview().offset(Theme.Spacing.l * 2)
            $0.trailing.lessThanOrEqualTo(switchControl.snp.leading).offset(-Theme.Spacing.m)
        }

        subtitleLabel.font = .appBody(12)
        subtitleLabel.textColor = Theme.Color.sub
        contentView.addSubview(subtitleLabel)
        subtitleLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(2)
            $0.leading.equalTo(titleLabel)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.l)
            $0.trailing.lessThanOrEqualTo(switchControl.snp.leading).offset(-Theme.Spacing.m)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func switched(_ sender: UISwitch) { onSwitch?(sender.isOn) }
}

// MARK: - 可见范围 Cell

final class VisibilityCell: UITableViewCell {
    static let reuseId = "VisibilityCell"

    var onChange: ((Int) -> Void)?

    private var buttons: [UIButton] = []
    private var selectedIndex = 0

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.Color.surface
        selectionStyle = .none

        let titleLabel = UILabel()
        titleLabel.text = "谁可以看"
        titleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        titleLabel.textColor = Theme.Color.sub
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.equalToSuperview().offset(Theme.Spacing.l * 2)
        }

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8
        contentView.addSubview(stack)
        stack.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l * 2)
            $0.height.equalTo(40)
        }

        for (index, title) in ["公开", "仅好友"].enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.titleLabel?.font = .appLabel(13)
            button.layer.cornerRadius = 20
            button.tag = index
            button.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
            buttons.append(button)
        }
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setIndex(_ index: Int) {
        selectedIndex = index
        refresh()
    }

    private func refresh() {
        for (index, button) in buttons.enumerated() {
            let isSelected = index == selectedIndex
            button.backgroundColor = isSelected ? Theme.Color.brand : Theme.Color.surfaceAlt
            button.setTitleColor(isSelected ? .white : Theme.Color.sub, for: .normal)
        }
    }

    @objc private func tapped(_ sender: UIButton) {
        selectedIndex = sender.tag
        refresh()
        onChange?(selectedIndex)
    }
}
