import UIKit
import SnapKit
import HXPhotoPicker
import SwiftyJSON

/// 发布动态（家长/老师双角色）
/// 家长：图片 + 正文 + 关联孩子(单选) + 可选关联课程 + 话题 + 谁可以看
/// 老师：图片 + 正文 + 关联课程·班级 + 同步销课(课次+学生) + 话题 + 谁可以看
/// PR 图：顶部"发布动态" + 右上角 × 关闭；图片九宫格；底部胶囊发布按钮
final class PostCreateViewController: BaseViewController, UITableViewDataSource, UITableViewDelegate, UITextViewDelegate {

    // MARK: - 角色与表单状态

    private let isTeacher = TokenManager.shared.userRole == 2

    private var childList: [ChildItem] = []
    private var teacherClasses: [TeacherClassItem] = []
    private var timetableItems: [TeacherTimetableItem] = []
    private var classStudents: [TeacherStudentItem] = []

    private var images: [UIImage] = []
    private var selectedChildId: String?
    private var selectedClass: TeacherClassItem?
    private var selectedSchedule: TeacherTimetableItem?
    private var selectedStudentIds = Set<String>()
    private var consumeEnabled = false
    private var topic = ""
    private var visibility = 2 // 2 公开 / 1 仅好友

    private var topics: [String] = []

    // MARK: - UI

    private let tableView = UITableView(frame: .zero, style: .plain)
    private let bottomBar = UIView()
    private let publishButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadData()
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
        // 关闭系统 header/footer 的额外间距，分组间距完全由本页控制（保证对称）
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
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            // 从导航栏下方开始，顶部留 16pt 呼吸距离
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalToSuperview()
        }

        // 底部发布栏
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
        // 底部 bar 上移避免遮挡键盘
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChange(_:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    // MARK: - 数据

    private func loadData() {
        if isTeacher {
            PostService.fetchTeacherClasses { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let list):
                    self.teacherClasses = list
                    self.tableView.reloadData()
                case .failure(let error):
                    self.showToast(error.message)
                }
            }
            PostService.fetchTeacherTimetable { [weak self] result in
                guard let self else { return }
                if case .success(let list) = result {
                    self.timetableItems = list
                }
            }
        } else {
            ChildService.fetchChildren { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let list):
                    self.childList = list
                    if self.selectedChildId == nil { self.selectedChildId = list.first?.child_id }
                    self.tableView.reloadData()
                case .failure(let error):
                    self.showToast(error.message)
                }
            }
        }

        // 发帖话题（公共接口，家长/老师都拉取）
        PostService.fetchTopics { [weak self] topics, _ in
            guard let self else { return }
            if let topics, !topics.isEmpty {
                self.topics = topics
            } else if self.topics.isEmpty {
                // 兜底：接口异常时仍可发帖
                self.topics = ["成长记录", "作品秀", "育儿经", "探店"]
            }
            let section = self.isTeacher ? 6 : 4
            if section < self.tableView.numberOfSections {
                self.tableView.reloadSections(IndexSet(integer: section), with: .none)
            }
        }
    }

    private func loadClassStudents(classId: String) {
        PostService.fetchTeacherClassStudents(classId: classId) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let list):
                self.classStudents = list
                self.selectedStudentIds.removeAll()
                self.tableView.reloadData()
            case .failure(let error):
                self.showToast(error.message)
            }
        }
    }

    // MARK: - TableView

    private var sectionsCount: Int {
        if isTeacher {
            // 0文字 1图片 2课程·班级+选择学生 3同步消课+上课课次 4话题 5谁可以看
            return 6
        }
        return 6
    }

    func numberOfSections(in tableView: UITableView) -> Int { sectionsCount }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isTeacher {
            switch section {
            case 2: return teacherClasses.isEmpty ? 0 : 1 // 课程·班级+学生卡片：无班级时不显示
            case 3: return teacherClasses.isEmpty ? 0 : 1 // 同步消课+课次卡片：无班级时用不到
            default: return 1
            }
        }
        switch section {
        case 3: return selectedParentCourseTitle != nil ? 1 : 0 // 关联课程：孩子无课程时隐藏
        default: return 1
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        // 标题已移入卡片内，header 只作卡片间距；空 section（隐藏的卡片）不留间距
        if section == 0 { return 0 }
        return tableView.numberOfRows(inSection: section) == 0 ? 0 : 16
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        // 关闭系统默认 footer，避免上组到标题的间距被额外撑大
        0
    }

    private func sectionHeaderTitle(_ section: Int) -> String? {
        if section == 0 { return nil }
        if isTeacher {
            switch section {
            case 2: return "关联课程"
            case 3: return "同步销课"
            case 4: return "选择话题"
            case 5: return "谁可以看"
            default: return nil
            }
        }
        switch section {
        case 2: return "关联孩子"
        case 3: return "关联课程"
        case 4: return "选择话题"
        case 5: return "谁可以看"
        default: return nil
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        nil
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(withIdentifier: TextCell.reuseId, for: indexPath) as! TextCell
            cell.placeholder = isTeacher ? "记录这节课的精彩瞬间，分享给家长…" : "分享孩子的成长瞬间，老师和其他家长都能看到并点赞。"
            cell.onTextChange = { [weak self] text in _ = self }
            return card(cell)
        case 1:
            let cell = tableView.dequeueReusableCell(withIdentifier: ImageGridCell.reuseId, for: indexPath) as! ImageGridCell
            cell.configure(images: images)
            cell.onAdd = { [weak self] in self?.pickImages() }
            cell.onDelete = { [weak self] index in
                guard let self, index < self.images.count else { return }
                self.images.remove(at: index)
                cell.configure(images: self.images)
                self.updateImageCellHeight()
            }
            return card(cell)
        case 2:
            if isTeacher {
                let cell = tableView.dequeueReusableCell(withIdentifier: TeacherClassCell.reuseId, for: indexPath) as! TeacherClassCell
                cell.configure(
                    classDetail: selectedClass?.displayName ?? "请选择",
                    students: classStudents.map { $0.nickname },
                    selected: Set(classStudents.filter { selectedStudentIds.contains($0.child_id) }.map { $0.nickname }),
                    hasClass: selectedClass != nil
                )
                cell.onTapClass = { [weak self] in self?.presentClassPicker() }
                cell.onStudentsChanged = { [weak self] tags in
                    guard let self else { return }
                    self.selectedStudentIds = Set(self.classStudents.filter { tags.contains($0.nickname) }.map { $0.child_id })
                }
                return card(cell)
            } else {
                let cell = UITableViewCell(style: .default, reuseIdentifier: "childTag")
                cell.selectionStyle = .none
                let selectedChildNames: Set<String> = Set(
                    selectedChildId.flatMap { id in
                        childList.first(where: { $0.child_id == id }).map { [$0.nickname] }
                    } ?? (childList.first.map { [$0.nickname] } ?? [])
                )
                _ = embedTagView(
                    in: cell,
                    title: "关联孩子",
                    options: childList.map { $0.nickname },
                    selected: selectedChildNames,
                    multiple: false
                ) { [weak self] tags in
                    guard let self else { return }
                    if let name = tags.first, let child = self.childList.first(where: { $0.nickname == name }) {
                        self.selectedChildId = child.child_id
                        self.tableView.reloadData()
                    }
                }
                return card(cell)
            }
        case 3:
            if isTeacher {
                let cell = tableView.dequeueReusableCell(withIdentifier: ConsumeCell.reuseId, for: indexPath) as! ConsumeCell
                cell.configure(
                    switchValue: consumeEnabled,
                    showSchedule: consumeEnabled,
                    scheduleDetail: selectedSchedule?.displayName ?? "请选择"
                )
                cell.onSwitch = { [weak self] on in
                    guard let self else { return }
                    self.consumeEnabled = on
                    if !on { self.selectedSchedule = nil }
                    self.tableView.reloadData()
                }
                cell.onTapSchedule = { [weak self] in self?.presentSchedulePicker() }
                return card(cell)
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: PickerCell.reuseId, for: indexPath) as! PickerCell
                cell.title = "关联课程"
                cell.detail = selectedParentCourseTitle ?? "不关联"
                return card(cell)
            }
        case 4:
            return card(topicCell(tableView, indexPath: indexPath))
        case 5:
            if isTeacher {
                return card(visibilityCell(tableView, indexPath: indexPath))
            } else {
                return card(visibilityCell(tableView, indexPath: indexPath))
            }
        default:
            return UITableViewCell()
        }
    }

    /// plain 分组下统一卡片样式：白底圆角 12、左右缩进 16
    @discardableResult
    private func card(_ cell: UITableViewCell) -> UITableViewCell {
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

    private var selectedParentCourseTitle: String? {
        guard let selectedChildId else { return nil }
        let child = childList.first(where: { $0.child_id == selectedChildId })
        let course = child?.balances?.first(where: { $0.status == 1 }) ?? child?.balances?.first
        return course?.course_title
    }

    private func topicCell(_ tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
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

    private func studentCell(_ tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "studentTag")
        cell.backgroundColor = Theme.Color.surface
        cell.selectionStyle = .none
        if classStudents.isEmpty {
            cell.textLabel?.text = "暂无学生"
            cell.textLabel?.font = .appBody(13)
            cell.textLabel?.textColor = Theme.Color.sub
            return cell
        }
        _ = embedTagView(
            in: cell,
            title: "选择学生",
            options: classStudents.map { $0.nickname },
            selected: Set(classStudents.filter { selectedStudentIds.contains($0.child_id) }.map { $0.nickname }),
            multiple: true
        ) { [weak self] tags in
            guard let self else { return }
            self.selectedStudentIds = Set(self.classStudents.filter { tags.contains($0.nickname) }.map { $0.child_id })
        }
        return cell
    }

    /// 标签嵌入 cell 统一封装（每次重建，避免 cell 复用导致 chips 丢失）
    @discardableResult
    private func embedTagView(
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

    private func visibilityCell(_ tableView: UITableView, indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: VisibilityCell.reuseId, for: indexPath) as! VisibilityCell
        cell.setIndex(visibility == 2 ? 0 : 1)
        cell.onChange = { [weak self] index in
            self?.visibility = index == 0 ? 2 : 1
        }
        return cell
    }

    @objc private func visibilityChanged(_ sender: UISegmentedControl) {
        visibility = sender.selectedSegmentIndex == 0 ? 2 : 1
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        switch indexPath.section {
        case 0:
            // 正文随内容自适应（最小 128pt：96 输入区 + 上下 16×2）
            return UITableView.automaticDimension
        case 1:
            return 132 // 照片横向：100 高 + 上下间距 16×2
        case 2:
            if isTeacher {
                // 未选班级：只显示课程·班级行 48；选了班级：+ 分割线 + 学生区
                guard selectedClass != nil else { return 48 }
                return 48 + 0.5 + 12 + 18 + 8 + tagRowsHeight(classStudents.map { $0.nickname }) + Theme.Spacing.l
            }
            return tagRowsHeight(childList.map { $0.nickname }) + Theme.Spacing.l * 2 + 40
        case 3:
            if isTeacher {
                // 消课开关行 70 + 分割线 0.5 + 课次行（开启消课才显示 48）
                return 70 + 0.5 + (consumeEnabled ? 48 : 0)
            }
            return UITableView.automaticDimension
        case 4:
            // 话题标签流式布局：TagSelectView 初始 intrinsic 为 0，须固定高度（家长/老师一致）
            return tagRowsHeight(topics.map { "#\($0)" }) + Theme.Spacing.l * 2 + 40
        default:
            return UITableView.automaticDimension
        }
    }

    /// 按文本宽度估算流式标签行高（TagSelectView 初始 intrinsic 为 0，cell 需显式高度）
    private func tagRowsHeight(_ titles: [String]) -> CGFloat {
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

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        view.endEditing(true)
        if isTeacher && indexPath.section == 2 {
            presentClassPicker()
        } else if isTeacher && consumeEnabled && indexPath.section == 3 {
            presentSchedulePicker()
        } else if !isTeacher && indexPath.section == 3 {
            presentParentCoursePicker()
        }
    }

    // MARK: - 选择器

    private func presentClassPicker() {
        guard !teacherClasses.isEmpty else {
            showToast("暂无班级")
            return
        }
        let picker = PickerSheetViewController(title: "选择课程 · 班级", rows: teacherClasses.map { $0.displayName })
        picker.onConfirm = { [weak self] index in
            guard let self, index < self.teacherClasses.count else { return }
            self.selectedClass = self.teacherClasses[index]
            self.selectedSchedule = nil
            self.selectedStudentIds.removeAll()
            self.loadClassStudents(classId: self.teacherClasses[index].class_id)
            self.tableView.reloadData()
        }
        present(picker, animated: false)
    }

    private func presentSchedulePicker() {
        guard let selectedClass else { return }
        let items = timetableItems.filter { $0.class?.class_id == selectedClass.class_id }
        guard !items.isEmpty else {
            showToast("该班级暂无课次")
            return
        }
        let picker = PickerSheetViewController(title: "选择上课课次", rows: items.map { $0.displayName })
        picker.onConfirm = { [weak self] index in
            guard let self, index < items.count else { return }
            self.selectedSchedule = items[index]
            self.tableView.reloadData()
        }
        present(picker, animated: false)
    }

    private func presentParentCoursePicker() {
        guard let selectedChildId,
              let child = childList.first(where: { $0.child_id == selectedChildId }),
              let balances = child.balances, !balances.isEmpty else {
            showToast("该孩子暂无课程")
            return
        }
        let rows = balances.compactMap { $0.course_title }
        let picker = PickerSheetViewController(title: "关联课程", rows: rows + ["不关联"])
        picker.onConfirm = { [weak self] index in
            guard let self else { return }
            self.selectedParentCourseIndex = index < balances.count ? index : nil
            self.tableView.reloadData()
        }
        present(picker, animated: false)
    }

    private var selectedParentCourseIndex: Int? {
        didSet { tableView.reloadData() }
    }

    private func selectedParentCourseId() -> String? {
        guard let selectedParentCourseIndex,
              let child = childList.first(where: { $0.child_id == selectedChildId }),
              let balances = child.balances, selectedParentCourseIndex < balances.count else { return nil }
        return balances[selectedParentCourseIndex].course_id
    }

    // MARK: - 图片

    private func pickImages() {
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

    private func updateImageCellHeight() {
        // 图片区在 section 1
        if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 1)) as? ImageGridCell {
            cell.configure(images: images)
        }
        tableView.beginUpdates()
        tableView.endUpdates()
    }

    // MARK: - 发布

    @objc private func didTapPublish() {
        view.endEditing(true)
        guard !images.isEmpty else {
            showToast("请至少上传一张作品图片")
            return
        }
        let content = (tableView.cellForRow(at: IndexPath(row: 0, section: 1)) as? TextCell)?.text ?? ""

        if isTeacher {
            if consumeEnabled {
                guard selectedClass != nil else { showToast("请先选择课程班级"); return }
                guard selectedSchedule != nil else { showToast("请选择上课课次"); return }
                guard !selectedStudentIds.isEmpty else { showToast("请选择上课学生"); return }
            }
        } else {
            guard selectedChildId != nil else { showToast("请选择关联孩子"); return }
        }

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
                if self.isTeacher {
                    self.publishTeacherPost(content: content, imageUrls: urls)
                } else {
                    self.publishParentPost(content: content, imageUrls: urls)
                }
            case .failure(let error):
                self.hideLoading()
                self.showToast(error.message)
            }
        }
    }

    private func publishParentPost(content: String, imageUrls: [String]) {
        PostService.createPost(
            content: content,
            images: imageUrls,
            childId: selectedChildId ?? "",
            courseId: selectedParentCourseId(),
            topic: topic,
            visibility: visibility
        ) { [weak self] postId, error in
            guard let self else { return }
            self.hideLoading()
            if let postId, !postId.isEmpty {
                self.showToast("发布成功")
                NotificationCenter.default.post(name: .postPublished, object: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    self.dismiss(animated: true)
                }
            } else {
                self.showToast(error ?? "发布失败")
            }
        }
    }

    private func publishTeacherPost(content: String, imageUrls: [String]) {
        // 关联学生（家长可见/推送）与消课分离：选学生即关联；consume=true 才扣课时
        let students: [[String: Any]] = selectedStudentIds.map { ["child_id": $0, "count": 1] }
        PostService.createTeacherPost(
            content: content,
            images: imageUrls,
            courseId: selectedClass?.course?.course_id,
            classId: selectedClass?.class_id,
            scheduleId: selectedSchedule?.schedule_id,
            students: students,
            consume: consumeEnabled,
            topic: topic,
            visibility: visibility
        ) { [weak self] postId, error in
            guard let self else { return }
            self.hideLoading()
            if let postId, !postId.isEmpty {
                self.showToast("发布成功")
                NotificationCenter.default.post(name: .postPublished, object: nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    self.dismiss(animated: true)
                }
            } else {
                self.showToast(error ?? "发布失败")
            }
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
