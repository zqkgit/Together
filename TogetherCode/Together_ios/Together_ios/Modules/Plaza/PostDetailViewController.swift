import UIKit
import SnapKit
import Kingfisher

/// 帖子详情（对齐 PR 设计图 #postDetail）
/// 结构：绿色渐变 header（作者行 + 标题/正文/话题 + 作品大图 + 课程卡）+ 评论列表 + 底部操作栏（输入/点赞/收藏/发送）
final class PostDetailViewController: BaseViewController {

    private let postId: String
    private var post: PostItem?
    private var comments: [CommentItem] = []
    /// 组织后的展示行：根评论(0) / 一级回复(1) / 二级回复(2)
    private var commentRows: [CommentRow] = []
    /// 回复目标（nil = 普通评论）
    private var replyingTo: CommentItem?
    /// 回复目标的层级（0 根评论 / 1 一级回复 / 2 二级回复）
    private var replyingLevel = 0

    private lazy var tableView = UITableView(frame: .zero, style: .plain)
    private let headerView = PostHeaderView()
    private let bottomBar = PostBottomBar()
    /// 键盘 accessory 输入条（键盘顶部显示）
    private let keyboardView = CommentKeyboardView()
    /// 隐藏输入框：承载 inputAccessoryView，becomeFirstResponder 时弹出键盘
    private let hiddenInput = UITextField()

    init(postId: String) {
        self.postId = postId
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        setupBottomBar()   // 先加入 bottomBar，供 tableView 约束引用
        setupTableView()
        loadDetail()
        loadComments()
            }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(titleColor: .white, backBackground: UIColor.black.withAlphaComponent(0.28), backTint: .white)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    private func setupTableView() {
        tableView.backgroundColor = Theme.Color.bg
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        // 导航栏隐藏后，header 图片要顶到状态栏后面（避免顶部白条）
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.register(CommentCell.self, forCellReuseIdentifier: "CommentCell")
        tableView.dataSource = self
        tableView.delegate = self

        headerView.onFollow = { [weak self] in self?.toggleFollow() }
        headerView.onEnroll = { [weak self] in
            guard let self, let courseId = self.post?.course?.course_id else { return }
            let enroll = CourseEnrollViewController(courseId: courseId)
            self.navigationController?.pushViewController(enroll, animated: true)
        }
        headerView.onTapImage = { [weak self] index in
            guard let self, let images = self.post?.images, !images.isEmpty else { return }
            let preview = ImagePreviewViewController(images: images, startIndex: index)
            self.present(preview, animated: true)
        }
        tableView.tableHeaderView = headerView

        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(bottomBar.snp.top)
        }
    }

    private func setupBottomBar() {
        view.addSubview(bottomBar)
        bottomBar.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
        }
        bottomBar.onLike = { [weak self] in self?.toggleLike() }
        bottomBar.onFavorite = { [weak self] in self?.toggleFavorite() }
        // 输入胶囊 → 弹出键盘 accessory
        bottomBar.onActivateInput = { [weak self] in self?.activateCommentInput() }
        // 键盘 accessory：发送 / 收起
        keyboardView.onSend = { [weak self] text in self?.sendComment(text) }
        keyboardView.onDismiss = { [weak self] in self?.dismissCommentInput() }
        // 隐藏输入框承载 accessory
        hiddenInput.inputAccessoryView = keyboardView
        view.addSubview(hiddenInput)
    }

    // MARK: - 数据

    private func loadDetail() {
        showLoading()
        PostService.fetchDetail(postId: postId) { [weak self] post, error in
            guard let self else { return }
            self.hideLoading()
            if let error {
                self.showToast(error)
                return
            }
            self.post = post
            self.headerView.configure(post: post)
            self.layoutHeader()
            self.bottomBar.configure(post: post)
        }
    }

    private func loadComments() {
        PostService.fetchComments(postId: postId, page: 1, size: 50) { [weak self] list, _, error in
            guard let self else { return }
            if let error {
                self.showToast(error)
                return
            }
            self.comments = list ?? []
            self.rebuildCommentRows()
            self.tableView.reloadData()
        }
    }

    /// 平铺评论 → 树展开，UI 封顶两级（根 0 / 一级 1 / 其余一律 2）：
    /// 一级以下任意深度的子孙都降级为二级展示，不丢数据；回复按时间正序跟在父评论后
    private func rebuildCommentRows() {
        let byParent = Dictionary(grouping: comments) { $0.parent_id ?? "0" }
        func children(of parentId: String) -> [CommentItem] {
            (byParent[parentId] ?? []).sorted { ($0.created_at ?? "") < ($1.created_at ?? "") }
        }
        var rows: [CommentRow] = []
        for root in (byParent["0"] ?? []).sorted(by: { ($0.created_at ?? "") > ($1.created_at ?? "") }) {
            rows.append(CommentRow(comment: root, level: 0, replyToName: nil))
            for first in children(of: root.comment_id) {
                rows.append(CommentRow(comment: first, level: 1, replyToName: nil))
                // first 的子孙（任意深度）→ 一律 level 2，回复对象 = 其直接父作者
                var queue = children(of: first.comment_id)
                var visited = Set<String>()
                while !queue.isEmpty {
                    let node = queue.removeFirst()
                    guard !visited.contains(node.comment_id) else { continue }
                    visited.insert(node.comment_id)
                    let parent = comments.first { $0.comment_id == node.parent_id }
                    rows.append(CommentRow(comment: node, level: 2, replyToName: parent?.authorName))
                    queue.append(contentsOf: children(of: node.comment_id))
                }
            }
        }
        commentRows = rows
    }

    private func layoutHeader() {
        guard let header = tableView.tableHeaderView else { return }
        let width = view.bounds.width
        let size = header.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        )
        header.frame = CGRect(x: 0, y: 0, width: width, height: size.height)
        tableView.tableHeaderView = header
    }

    // MARK: - 交互

    private func toggleLike() {
        guard var post else { return }
        let target = !(post.is_liked ?? false)
        PostService.toggleLike(postId: postId, liked: post.is_liked ?? false) { [weak self] ok, error in
            guard let self else { return }
            if let error {
                self.showToast(error)
                return
            }
            post.is_liked = target
            post.like_count = max(0, (post.like_count ?? 0) + (target ? 1 : -1))
            self.post = post
            self.bottomBar.configure(post: post)
        }
    }

    /// 评论点赞 / 取消（本地计数联动 + cell 刷新）
    /// 评论点赞 / 取消（从数组取最新状态，支持连续切换）
    private func toggleCommentLike(index: Int, cell: CommentCell) {
        guard index < commentRows.count else { return }
        let commentId = commentRows[index].comment.comment_id
        var c = commentRows[index].comment
        let target = !(c.is_liked ?? false)
        PostService.toggleCommentLike(
            postId: postId,
            commentId: commentId,
            liked: c.is_liked ?? false
        ) { [weak self] ok, error in
            guard let self else { return }
            if let error {
                self.showToast(error)
                return
            }
            guard index < self.commentRows.count,
                  let idx = self.comments.firstIndex(where: { $0.comment_id == commentId })
            else { return }
            c = self.comments[idx]
            c.is_liked = target
            c.like_count = max(0, (c.like_count ?? 0) + (target ? 1 : -1))
            self.comments[idx] = c
            self.commentRows[index] = CommentRow(comment: c, level: self.commentRows[index].level, replyToName: self.commentRows[index].replyToName)
            cell.refreshLike(comment: c)
        }
    }

    /// 进入回复态：记录目标 + 层级 + 更新胶囊 + 弹出键盘
    private func startReply(to row: CommentRow) {
        replyingTo = row.comment
        replyingLevel = row.level
        bottomBar.setPlaceholder(text: "回复 @\(row.comment.authorName)")
        activateCommentInput()
    }

    /// 取消回复态
    private func cancelReply() {
        replyingTo = nil
        bottomBar.setPlaceholder(text: nil)
    }

    /// 弹出键盘（accessory 输入条）
    private func activateCommentInput() {
        keyboardView.setReplyTarget(name: replyingTo?.authorName)
        hiddenInput.becomeFirstResponder()
    }

    /// 收起键盘
    private func dismissCommentInput() {
        hiddenInput.resignFirstResponder()
        keyboardView.clear()
    }

    private func toggleFollow() {        guard var post, let authorId = post.author?.user_id else { return }
        let target = !(post.is_following ?? false)
        PostService.followUser(userId: authorId, followed: post.is_following ?? false) { [weak self] ok, error in
            guard let self else { return }
            if let error {
                self.showToast(error)
                return
            }
            post.is_following = target
            self.post = post
            self.headerView.setFollowing(target)
            self.showToast(target ? "已关注" : "已取消关注")
        }
    }

    private func toggleFavorite() {
        guard let post else { return }
        let target = !(post.is_favorite ?? false)
        PostService.toggleFavorite(postId: postId, favorited: post.is_favorite ?? false) { [weak self] newState, error in
            guard let self else { return }
            if let error {
                self.showToast(error)
                return
            }
            var p = post
            p.is_favorite = target
            self.post = p
            self.bottomBar.configure(post: p)
            self.showToast(target ? "已收藏" : "已取消收藏")
        }
    }

    private func sendComment(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // 层级规则：根评论(0)→一级；一级回复(1)→二级；二级回复(2)→挂到其父级，封顶两级
        let parentId: String?
        if replyingLevel == 2 {
            parentId = (replyingTo?.parent_id ?? "0") != "0" ? replyingTo?.parent_id : replyingTo?.comment_id
        } else {
            parentId = replyingTo?.comment_id
        }
        PostService.addComment(postId: postId, content: trimmed, parentId: parentId) { [weak self] comment, error in
            guard let self else { return }
            if let error {
                self.showToast(error)
                return
            }
            if let comment {
                self.comments.insert(comment, at: 0)
                self.rebuildCommentRows()
                self.tableView.reloadData()
            }
            self.cancelReply()
            self.dismissCommentInput()
        }
    }
}

// MARK: - UITableView

extension PostDetailViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        commentRows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CommentCell", for: indexPath) as! CommentCell
        let row = commentRows[indexPath.row]
        let isOwn = row.comment.user?.user_id == TokenManager.shared.userId
        cell.configure(comment: row.comment, level: row.level, replyToName: row.replyToName, isOwn: isOwn)
        cell.onLike = { [weak self, weak cell] in
            guard let self, let cell else { return }
            self.toggleCommentLike(index: indexPath.row, cell: cell)
        }
        cell.onReply = { [weak self] in
            guard let self else { return }
            self.startReply(to: self.commentRows[indexPath.row])
        }
        cell.onDelete = { [weak self] in
            guard let self else { return }
            self.confirmDeleteComment(at: indexPath.row)
        }
        return cell
    }

    /// 删除自己的评论：确认弹窗 → 调接口 → 移除本地数据
    private func confirmDeleteComment(at index: Int) {
        guard index < commentRows.count else { return }
        let row = commentRows[index]
        let alert = UIAlertController(title: "删除评论", message: "确定删除这条评论吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "删除", style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.deleteComment(commentId: row.comment.comment_id)
        })
        present(alert, animated: true)
    }

    private func deleteComment(commentId: String) {
        PostService.deleteComment(commentId: commentId) { [weak self] ok, error in
            guard let self else { return }
            if let error {
                self.showToast(error)
                return
            }
            self.comments.removeAll { $0.comment_id == commentId }
            self.rebuildCommentRows()
            self.tableView.reloadData()
            if var post = self.post {
                post.comment_count = max(0, (post.comment_count ?? 0) - 1)
                self.post = post
                self.tableView.reloadData()
            }
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let label = UILabel()
        label.font = .appSection(14)
        label.textColor = Theme.Color.ink
        label.text = "评论(\(post?.comment_count ?? comments.count))"
        let wrap = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 36))
        wrap.backgroundColor = Theme.Color.bg
        wrap.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
        }
        return wrap
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 36 }
}

// MARK: - 帖子头部（渐变 + 作者 + 内容 + 大图 + 课程卡）

final class PostHeaderView: UIView {

    var onFollow: (() -> Void)?
    var onEnroll: (() -> Void)?
    var onTapImage: ((Int) -> Void)?

    // 顶部图片轮播（可横滑 + 点击全屏预览）
    private let carouselView = ImageCarouselView()
    // 发帖人信息（白底）
    private let avatarView = AvatarPlaceholderView(name: "?", size: 44)
    private let nameLabel = UILabel()
    private let roleBadge = UILabel()
    private let timeLabel = UILabel()
    private let followButton = UIButton(type: .system)
    // 内容
    private let titleLabel = UILabel()
    private let bodyLabel = UILabel()
    private let topicLabel = UILabel()
    // 课程卡
    private let courseCard = UIView()
    private let courseTitle = UILabel()
    private let coursePrice = UILabel()
    private let enrollButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.Color.bg
        setupCarousel()
        setupAuthorRow()
        setupContent()
        setupCourseCard()
    }

    /// 顶部图片数组轮播（400pt），返回按钮浮在图片左上角
    private func setupCarousel() {
        carouselView.onTapImage = { [weak self] index in self?.onTapImage?(index) }
        addSubview(carouselView)
        carouselView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.height.equalTo(400)
        }
    }

    /// 发帖人信息行（白底，图片下方）
    private func setupAuthorRow() {
        addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.top.equalTo(carouselView.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.equalToSuperview().inset(Theme.Spacing.m)
            $0.width.height.equalTo(44)
        }

        nameLabel.font = .appSection(15)
        nameLabel.textColor = Theme.Color.ink
        addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.top.equalTo(avatarView.snp.top)
            $0.leading.equalTo(avatarView.snp.trailing).offset(Theme.Spacing.s)
        }
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameLabel.lineBreakMode = .byTruncatingTail

        roleBadge.font = .appLabel(10)
        roleBadge.textColor = Theme.Color.brand
        roleBadge.textAlignment = .center
        roleBadge.backgroundColor = Theme.Color.brandSoft
        roleBadge.layer.cornerRadius = 8
        roleBadge.clipsToBounds = true
        addSubview(roleBadge)
        roleBadge.snp.makeConstraints {
            $0.centerY.equalTo(nameLabel)
            $0.leading.equalTo(nameLabel.snp.trailing).offset(6)
            $0.height.equalTo(16)
            $0.width.greaterThanOrEqualTo(34)
        }

        timeLabel.font = .appLabel(11)
        timeLabel.textColor = Theme.Color.muted
        addSubview(timeLabel)
        timeLabel.snp.makeConstraints {
            $0.top.equalTo(nameLabel.snp.bottom).offset(3)
            $0.leading.equalTo(nameLabel)
        }

        followButton.setTitle("+ 关注", for: .normal)
        followButton.setTitleColor(Theme.Color.brand, for: .normal)
        followButton.titleLabel?.font = .appLabel(12)
        followButton.backgroundColor = Theme.Color.brandSoft
        followButton.layer.cornerRadius = 13
        followButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        followButton.addTarget(self, action: #selector(didTapFollow), for: .touchUpInside)
        addSubview(followButton)
        followButton.snp.makeConstraints {
            $0.centerY.equalTo(avatarView)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }
    }

    private func setupContent() {
        titleLabel.font = .appTitle(20)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.numberOfLines = 0
        addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(avatarView.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }

        bodyLabel.font = .appBody(14)
        bodyLabel.textColor = Theme.Color.sub
        bodyLabel.numberOfLines = 0
        addSubview(bodyLabel)
        bodyLabel.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }

        topicLabel.font = .appLabel(12)
        topicLabel.textColor = Theme.Color.brand
        topicLabel.backgroundColor = Theme.Color.brandSoft
        topicLabel.layer.cornerRadius = 11
        topicLabel.clipsToBounds = true
        topicLabel.textAlignment = .center
        addSubview(topicLabel)
        topicLabel.snp.makeConstraints {
            $0.top.equalTo(bodyLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.equalToSuperview().inset(Theme.Spacing.m)
            $0.height.equalTo(22)
            $0.width.greaterThanOrEqualTo(52)
        }
    }

    private func setupCourseCard() {
        courseCard.backgroundColor = Theme.Color.surface
        courseCard.layer.cornerRadius = Theme.Radius.card
        courseCard.layer.borderWidth = 1
        courseCard.layer.borderColor = Theme.Color.line.cgColor
        addSubview(courseCard)
        courseCard.snp.makeConstraints {
            $0.top.equalTo(topicLabel.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.m)
            $0.height.equalTo(76)
        }

        courseTitle.font = .appBody(14)
        courseTitle.textColor = Theme.Color.ink
        courseTitle.numberOfLines = 1
        courseCard.addSubview(courseTitle)
        courseTitle.snp.makeConstraints {
            $0.top.leading.equalToSuperview().inset(Theme.Spacing.m)
            $0.trailing.lessThanOrEqualToSuperview().inset(88)
        }

        coursePrice.font = .appBody(13)
        coursePrice.textColor = Theme.Color.clay
        courseCard.addSubview(coursePrice)
        coursePrice.snp.makeConstraints {
            $0.top.equalTo(courseTitle.snp.bottom).offset(4)
            $0.leading.equalTo(courseTitle)
        }

        enrollButton.setTitle("去报名", for: .normal)
        enrollButton.setTitleColor(.white, for: .normal)
        enrollButton.titleLabel?.font = .appLabel(13)
        enrollButton.backgroundColor = Theme.Color.brand
        enrollButton.layer.cornerRadius = Theme.Radius.button
        enrollButton.addTarget(self, action: #selector(didTapEnroll), for: .touchUpInside)
        courseCard.addSubview(enrollButton)
        enrollButton.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.width.equalTo(72)
            $0.height.equalTo(34)
        }
    }

    func configure(post: PostItem?) {
        guard let post else { return }

        // 图片数组轮播
        carouselView.configure(images: post.images ?? [])

        avatarView.update(name: post.authorName)
        nameLabel.text = post.authorName
        roleBadge.text = post.roleText
        roleBadge.isHidden = post.roleText.isEmpty
        timeLabel.text = "\(post.created_at?.shortRelativeTime ?? "")·广场"
        setFollowing(post.is_following ?? false)

        // 标题 + 正文：content 首行加粗为标题，其余为正文
        let content = post.bodyText
        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        if lines.count > 1 {
            titleLabel.text = String(lines[0])
            bodyLabel.text = lines.dropFirst().joined(separator: "\n")
            bodyLabel.isHidden = false
        } else {
            titleLabel.text = content.isEmpty ? "作品分享" : content
            bodyLabel.isHidden = true
        }

        if let topic = post.topic, !topic.isEmpty {
            topicLabel.text = "#\(topic)"
            topicLabel.isHidden = false
        } else {
            topicLabel.isHidden = true
        }

        // 课程卡
        if let course = post.course, !(course.title ?? "").isEmpty {
            courseCard.isHidden = false
            courseTitle.text = course.title
            if let price = course.price, price > 0 {
                coursePrice.text = "¥\(String(format: "%.2f", Double(price) / 100)) 元"
            } else {
                coursePrice.text = "价格咨询"
            }
        } else {
            courseCard.isHidden = true
        }
    }

    /// 关注状态刷新（"+ 关注" ↔ "已关注"）
    func setFollowing(_ following: Bool) {
        if following {
            followButton.setTitle("已关注", for: .normal)
            followButton.setTitleColor(Theme.Color.sub, for: .normal)
            followButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            followButton.layer.borderWidth = 0.5
            followButton.layer.borderColor = Theme.Color.line.cgColor
        } else {
            followButton.setTitle("+ 关注", for: .normal)
            followButton.setTitleColor(Theme.Color.brand, for: .normal)
            followButton.backgroundColor = Theme.Color.brandSoft
            followButton.layer.borderWidth = 0
        }
    }

    @objc private func didTapFollow() { onFollow?() }
    @objc private func didTapEnroll() { onEnroll?() }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 评论 cell

final class CommentCell: UITableViewCell {

    var onLike: (() -> Void)?
    var onReply: (() -> Void)?
    var onDelete: (() -> Void)?

    private let avatarView = AvatarPlaceholderView(name: "?", size: 36)
    private let nameLabel = UILabel()
    private let timeLabel = UILabel()
    private let contentLabel = UILabel()
    private let likeButton = UIButton(type: .system)
    private let replyButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = Theme.Color.bg

        contentView.addSubview(avatarView)
        avatarView.snp.makeConstraints {
            $0.top.leading.equalToSuperview().inset(Theme.Spacing.m)
            $0.width.height.equalTo(36)
        }

        nameLabel.font = .appLabel(12)
        nameLabel.textColor = Theme.Color.sub
        contentView.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.top.equalTo(avatarView.snp.top)
            $0.leading.equalTo(avatarView.snp.trailing).offset(Theme.Spacing.s)
        }
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameLabel.lineBreakMode = .byTruncatingTail

        timeLabel.font = .appLabel(11)
        timeLabel.textColor = Theme.Color.muted
        contentView.addSubview(timeLabel)
        timeLabel.snp.makeConstraints {
            $0.centerY.equalTo(nameLabel)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }

        contentLabel.font = .appBody(14)
        contentLabel.textColor = Theme.Color.ink
        contentLabel.numberOfLines = 0
        contentView.addSubview(contentLabel)
        contentLabel.snp.makeConstraints {
            $0.top.equalTo(nameLabel.snp.bottom).offset(5)
            $0.leading.equalTo(nameLabel)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.m)
        }

        likeButton.titleLabel?.font = .appLabel(11)
        likeButton.setTitleColor(Theme.Color.muted, for: .normal)
        likeButton.addTarget(self, action: #selector(didTapLike), for: .touchUpInside)
        contentView.addSubview(likeButton)
        likeButton.snp.makeConstraints {
            $0.top.equalTo(contentLabel.snp.bottom).offset(4)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.m)
            $0.height.equalTo(24)
        }

        // 回复按钮依赖 likeButton 已加入层级（SnapKit 约束须有公共祖先）
        replyButton.setTitle("回复", for: .normal)
        replyButton.setTitleColor(Theme.Color.sub, for: .normal)
        replyButton.titleLabel?.font = .appLabel(11)
        replyButton.addTarget(self, action: #selector(didTapReply), for: .touchUpInside)
        contentView.addSubview(replyButton)
        replyButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.centerY.equalTo(likeButton)
            $0.height.equalTo(24)
        }

        deleteButton.setTitle("删除", for: .normal)
        deleteButton.setTitleColor(Theme.Color.danger, for: .normal)
        deleteButton.titleLabel?.font = .appLabel(11)
        deleteButton.addTarget(self, action: #selector(didTapDelete), for: .touchUpInside)
        contentView.addSubview(deleteButton)
        deleteButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.centerY.equalTo(likeButton)
            $0.height.equalTo(24)
        }
        deleteButton.isHidden = true

        // 点赞按钮让位给"回复"（在回复按钮左侧）
        likeButton.snp.remakeConstraints {
            $0.top.equalTo(contentLabel.snp.bottom).offset(4)
            $0.trailing.equalTo(replyButton.snp.leading).offset(-2)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.m)
            $0.height.equalTo(24)
        }
    }

    /// level：0 根评论 / 1 一级回复（缩进）/ 2 二级回复（缩进 + 回复对象前缀）
    func configure(comment: CommentItem, level: Int = 0, replyToName: String? = nil, isOwn: Bool = false) {
        avatarView.update(name: comment.authorName)
        nameLabel.text = comment.authorName
        timeLabel.text = comment.timeText
        if level == 2, let replyToName, !replyToName.isEmpty {
            contentLabel.text = "回复 @\(replyToName)：\(comment.content)"
        } else {
            contentLabel.text = comment.content
        }
        let indent = CGFloat(level) * Theme.Spacing.l
        avatarView.snp.updateConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.m + indent)
        }
        // 自己的评论：不显示回复（不能回复自己，后端同样拦截），显示删除
        replyButton.isHidden = isOwn
        deleteButton.isHidden = !isOwn
        refreshLike(comment: comment)
    }

    func refreshLike(comment: CommentItem) {
        let liked = comment.is_liked ?? false
        let count = comment.like_count ?? 0
        let icon = liked ? "heart.fill" : "heart"
        likeButton.setImage(UIImage(systemName: icon), for: .normal)
        likeButton.setTitle(count > 0 ? " \(count)" : "", for: .normal)
        likeButton.setTitleColor(liked ? Theme.Color.clay : Theme.Color.muted, for: .normal)
        likeButton.tintColor = liked ? Theme.Color.clay : Theme.Color.muted
    }

    @objc private func didTapLike() { onLike?() }
    @objc private func didTapReply() { onReply?() }

    @objc private func didTapDelete() { onDelete?() }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 评论层级行

struct CommentRow {
    let comment: CommentItem
    let level: Int
    let replyToName: String?
}

// MARK: - 底部操作栏

final class PostBottomBar: UIView {

    var onLike: (() -> Void)?
    var onFavorite: (() -> Void)?
    /// 点击输入胶囊（弹出键盘 accessory）
    var onActivateInput: (() -> Void)?

    private let inputPlaceholder = UIButton(type: .system)
    private let likeButton = UIButton(type: .system)
    private let favButton = UIButton(type: .system)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.Color.surface
        layer.borderWidth = 1
        layer.borderColor = Theme.Color.line.cgColor

        // 先全部加入层级，再统一约束（SnapKit 要求引用视图已在层级中）
        addSubview(inputPlaceholder)
        addSubview(likeButton)
        addSubview(favButton)

        // 收藏按钮（最右）
        favButton.tintColor = Theme.Color.sub
        favButton.setImage(UIImage(systemName: "bookmark"), for: .normal)
        favButton.addTarget(self, action: #selector(didTapFavorite), for: .touchUpInside)
        favButton.snp.makeConstraints {
            $0.centerY.equalTo(inputPlaceholder)
            $0.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.width.equalTo(40)
            $0.height.equalTo(38)
        }

        // 点赞按钮（收藏左侧）
        likeButton.tintColor = Theme.Color.sub
        likeButton.setImage(UIImage(systemName: "heart"), for: .normal)
        likeButton.addTarget(self, action: #selector(didTapLike), for: .touchUpInside)
        likeButton.snp.makeConstraints {
            $0.centerY.equalTo(inputPlaceholder)
            $0.trailing.equalTo(favButton.snp.leading).offset(-Theme.Spacing.s)
            $0.width.equalTo(40)
            $0.height.equalTo(38)
        }

        // 输入胶囊（最左，右侧贴点赞按钮）
        inputPlaceholder.setTitle("说点什么...", for: .normal)
        inputPlaceholder.setTitleColor(Theme.Color.muted, for: .normal)
        inputPlaceholder.titleLabel?.font = .appBody(14)
        inputPlaceholder.contentHorizontalAlignment = .left
        inputPlaceholder.titleEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 0)
        inputPlaceholder.backgroundColor = Theme.Color.surfaceAlt
        inputPlaceholder.layer.cornerRadius = Theme.Radius.button
        inputPlaceholder.addTarget(self, action: #selector(didTapActivate), for: .touchUpInside)
        inputPlaceholder.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(Theme.Spacing.s)
            $0.top.equalTo(self.safeAreaLayoutGuide.snp.top).offset(Theme.Spacing.s)
            $0.bottom.equalTo(self.safeAreaLayoutGuide.snp.bottom).offset(-Theme.Spacing.s)
            $0.height.equalTo(38)
            $0.trailing.equalTo(likeButton.snp.leading).offset(-Theme.Spacing.s)
        }

        // 底部栏自身不参与输入；底部高度由安全区撑起
    }

    func configure(post: PostItem?) {
        guard let post else { return }
        let liked = post.is_liked ?? false
        likeButton.setImage(UIImage(systemName: liked ? "heart.fill" : "heart"), for: .normal)
        likeButton.tintColor = liked ? Theme.Color.clay : Theme.Color.sub
        likeButton.setTitle(" \(post.like_count ?? 0)", for: .normal)
        likeButton.setTitleColor(Theme.Color.sub, for: .normal)

        let fav = post.is_favorite ?? false
        favButton.setImage(UIImage(systemName: fav ? "bookmark.fill" : "bookmark"), for: .normal)
        favButton.tintColor = fav ? Theme.Color.brand : Theme.Color.sub
    }

    /// 胶囊文字：普通评论 / 回复态
    func setPlaceholder(text: String?) {
        inputPlaceholder.setTitle(text ?? "说点什么...", for: .normal)
    }

    @objc private func didTapActivate() { onActivateInput?() }
    @objc private func didTapLike() { onLike?() }
    @objc private func didTapFavorite() { onFavorite?() }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
