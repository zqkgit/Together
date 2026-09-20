import UIKit
import SnapKit
import Kingfisher
import HXPhotoPicker
import SwiftyJSON

/// 写评价 / 编辑评价（家长课后评课程）
/// 新增：POST /courses/:id/reviews；编辑：PUT /reviews/:id（待审核/驳回可改）
final class ReviewComposeViewController: BaseViewController {

    private enum Mode {
        case create(courseId: String, courseTitle: String)
        case edit(review: MyReviewItem)
    }

    private let mode: Mode
    private var rating = 5
    private var contentText = ""
    private var originImageUrls: [String] = []   // 编辑模式回显的已传 URL
    private var pickedImages: [UIImage] = []     // 本次新增图片
    private var images: [UIImage] { pickedImages }
    private var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }

    private let scrollView = UIScrollView()
    private let ratingCard = UIView()
    private let contentCard = UIView()
    private let imageCard = UIView()
    private let starStack = UIStackView()
    private var starButtons: [UIButton] = []
    private let ratingHintLabel = UILabel()
    private let textView = UITextView()
    private let imageGridStack = UIStackView()
    private let submitButton = UIButton(type: .system)

    init(courseId: String, courseTitle: String) {
        self.mode = .create(courseId: courseId, courseTitle: courseTitle)
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    init(review: MyReviewItem) {
        self.mode = .edit(review: review)
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
        rating = review.rating ?? 5
        contentText = review.content ?? ""
        originImageUrls = review.images ?? []
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        setupScroll()
        styleCards()
        setupRatingCard()
        setupContentCard()
        setupImageCard()
        setupSubmitBar()
        refreshStars()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureImmersiveNav(title: isEditMode ? "编辑评价" : "写评价")
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemNav()
    }

    // MARK: - UI

    private func setupScroll() {
        scrollView.backgroundColor = .clear
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(view.safeAreaLayoutGuide).offset(-72)
        }
    }

    /// 三个白色圆角卡片统一样式
    private func styleCards() {
        for card in [ratingCard, contentCard, imageCard] {
            card.backgroundColor = Theme.Color.surface
            card.layer.cornerRadius = Theme.Radius.card
            card.layer.masksToBounds = true
        }
    }

    private func setupRatingCard() {
        scrollView.addSubview(ratingCard)
        ratingCard.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.l)
            $0.leading.trailing.equalTo(view).inset(Theme.Spacing.m)
        }

        let card = ratingCard

        let title = UILabel()
        title.text = "整体评分"
        title.font = .appBody(14)
        title.textColor = Theme.Color.sub
        card.addSubview(title)
        title.snp.makeConstraints {
            $0.top.leading.equalToSuperview().inset(Theme.Spacing.l)
        }

        starStack.axis = .horizontal
        starStack.spacing = Theme.Spacing.m
        starStack.distribution = .fillEqually
        card.addSubview(starStack)
        starStack.snp.makeConstraints {
            $0.top.equalTo(title.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.xl)
            $0.height.equalTo(40)
        }

        for i in 1...5 {
            let button = UIButton(type: .system)
            button.tag = i
            button.setTitle("★", for: .normal)
            button.titleLabel?.font = .appTitle(28)
            button.addTarget(self, action: #selector(starTapped(_:)), for: .touchUpInside)
            starStack.addArrangedSubview(button)
            starButtons.append(button)
        }

        ratingHintLabel.font = .appLabel(12)
        ratingHintLabel.textColor = Theme.Color.muted
        ratingHintLabel.textAlignment = .center
        card.addSubview(ratingHintLabel)
        ratingHintLabel.snp.makeConstraints {
            $0.top.equalTo(starStack.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
    }

    private func setupContentCard() {
        scrollView.addSubview(contentCard)
        contentCard.snp.makeConstraints {
            $0.top.equalTo(ratingCard.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalTo(view).inset(Theme.Spacing.m)
        }

        let card = contentCard

        let title = UILabel()
        title.text = "评价内容"
        title.font = .appBody(14)
        title.textColor = Theme.Color.sub
        card.addSubview(title)
        title.snp.makeConstraints {
            $0.top.leading.equalToSuperview().inset(Theme.Spacing.l)
        }

        let placeholder = UILabel()
        placeholder.text = "说说孩子上课的感受吧（选填）"
        placeholder.font = .appBody(14)
        placeholder.textColor = Theme.Color.muted
        card.addSubview(placeholder)
        placeholder.snp.makeConstraints {
            $0.top.equalTo(title.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.equalToSuperview().inset(Theme.Spacing.l)
        }

        textView.font = .appBody(14)
        textView.textColor = Theme.Color.ink
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.delegate = self
        card.addSubview(textView)
        textView.snp.makeConstraints {
            $0.top.equalTo(title.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(100)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
        if !contentText.isEmpty {
            placeholder.isHidden = true
            textView.text = contentText
        }
    }

    private func setupImageCard() {
        scrollView.addSubview(imageCard)
        imageCard.snp.makeConstraints {
            $0.top.equalTo(contentCard.snp.bottom).offset(Theme.Spacing.l)
            $0.leading.trailing.equalTo(view).inset(Theme.Spacing.m)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.xl)
        }

        let card = imageCard

        let title = UILabel()
        title.text = "晒图（选填）"
        title.font = .appBody(14)
        title.textColor = Theme.Color.sub
        card.addSubview(title)
        title.snp.makeConstraints {
            $0.top.leading.equalToSuperview().inset(Theme.Spacing.l)
        }

        imageGridStack.axis = .vertical
        imageGridStack.spacing = Theme.Spacing.s
        card.addSubview(imageGridStack)
        imageGridStack.snp.makeConstraints {
            $0.top.equalTo(title.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.bottom.equalToSuperview().inset(Theme.Spacing.l)
        }
        renderImageGrid()
    }

    /// 3 列网格：已有图片（编辑回显）+ 新选图片 + 添加按钮
    private func renderImageGrid() {
        imageGridStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let allCount = originImageUrls.count + pickedImages.count
        let itemCount = min(allCount + 1, 9)
        let side: CGFloat = (UIScreen.main.bounds.width - Theme.Spacing.m * 2 - Theme.Spacing.l * 2 - Theme.Spacing.s * 2) / 3
        var rowViews: [UIStackView] = []
        for i in 0..<itemCount {
            if i % 3 == 0 {
                let row = UIStackView()
                row.axis = .horizontal
                row.spacing = Theme.Spacing.s
                row.distribution = .fillEqually
                imageGridStack.addArrangedSubview(row)
                row.snp.makeConstraints { $0.height.equalTo(side) }
                rowViews.append(row)
            }
            let container = UIView()
            rowViews[i / 3].addArrangedSubview(container)

            let isAdd = i == allCount
            if isAdd {
                let addButton = UIButton(type: .system)
                addButton.setImage(UIImage(systemName: "plus"), for: .normal)
                addButton.tintColor = Theme.Color.muted
                addButton.backgroundColor = Theme.Color.surfaceAlt
                addButton.layer.cornerRadius = Theme.Radius.icon
                addButton.layer.masksToBounds = true
                addButton.addTarget(self, action: #selector(pickImages), for: .touchUpInside)
                container.addSubview(addButton)
                addButton.snp.makeConstraints { $0.edges.equalToSuperview() }
            } else {
                let imageView = UIImageView()
                imageView.contentMode = .scaleAspectFill
                imageView.clipsToBounds = true
                imageView.layer.cornerRadius = Theme.Radius.icon
                imageView.layer.masksToBounds = true
                container.addSubview(imageView)
                imageView.snp.makeConstraints { $0.edges.equalToSuperview() }

                if i < originImageUrls.count {
                    if let url = URL(string: originImageUrls[i]) {
                        imageView.kf.setImage(with: url, placeholder: UIImage(systemName: "photo"))
                    }
                } else {
                    imageView.image = pickedImages[i - originImageUrls.count]
                }

                let removeButton = UIButton(type: .system)
                removeButton.tag = i
                removeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
                removeButton.tintColor = UIColor.black.withAlphaComponent(0.5)
                removeButton.addTarget(self, action: #selector(removeImage(_:)), for: .touchUpInside)
                container.addSubview(removeButton)
                removeButton.snp.makeConstraints {
                    $0.top.trailing.equalToSuperview()
                    $0.width.height.equalTo(20)
                }
            }
        }
    }

    private func setupSubmitBar() {
        let bar = UIView()
        bar.backgroundColor = Theme.Color.surface
        bar.layer.shadowColor = UIColor.black.cgColor
        bar.layer.shadowOpacity = 0.06
        bar.layer.shadowOffset = CGSize(width: 0, height: -2)
        bar.layer.shadowRadius = 8
        view.addSubview(bar)
        bar.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.top.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-64)
        }

        submitButton.setTitle(isEditMode ? "保存修改" : "提交评价", for: .normal)
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.titleLabel?.font = .appLabel(16)
        submitButton.backgroundColor = Theme.Color.brand
        submitButton.layer.cornerRadius = Theme.Radius.button
        submitButton.addTarget(self, action: #selector(didTapSubmit), for: .touchUpInside)
        bar.addSubview(submitButton)
        submitButton.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.m)
            $0.top.equalToSuperview().offset(10)
            $0.bottom.equalTo(view.safeAreaLayoutGuide).inset(10)
            $0.height.equalTo(46)
        }
    }

    // MARK: - 交互

    @objc private func starTapped(_ sender: UIButton) {
        rating = sender.tag
        refreshStars()
    }

    private func refreshStars() {
        for (index, button) in starButtons.enumerated() {
            let filled = index < rating
            button.setTitleColor(filled ? Theme.Color.clay : Theme.Color.line, for: .normal)
        }
        ratingHintLabel.text = ratingHint
    }

    private var ratingHint: String {
        switch rating {
        case 1: return "很不满意"
        case 2: return "不满意"
        case 3: return "一般"
        case 4: return "满意"
        default: return "非常满意"
        }
    }

    @objc private func pickImages() {
        view.endEditing(true)
        var config = PickerConfiguration()
        config.selectOptions = [.photo]
        config.maximumSelectedCount = max(1, 9 - originImageUrls.count - pickedImages.count)
        let picker = PhotoPickerController(config: config)
        picker.finishHandler = { [weak self] result, _ in
            guard let self else { return }
            result.getImage(targetSize: CGSize(width: 1600, height: 1600)) { [weak self] images in
                guard let self else { return }
                for image in images where self.pickedImages.count + self.originImageUrls.count < 9 {
                    self.pickedImages.append(image)
                }
                self.renderImageGrid()
            }
        }
        present(picker, animated: true)
    }

    @objc private func removeImage(_ sender: UIButton) {
        let index = sender.tag
        if index < originImageUrls.count {
            originImageUrls.remove(at: index)
        } else {
            pickedImages.remove(at: index - originImageUrls.count)
        }
        renderImageGrid()
    }

    // MARK: - 提交

    @objc private func didTapSubmit() {
        view.endEditing(true)
        let content = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)

        showLoading(isEditMode ? "保存中..." : "提交中...")
        let newDatas = pickedImages.compactMap { $0.jpegData(compressionQuality: 0.8) }

        func submit(imageUrls: [String]?) {
            var urls: [String]? = imageUrls
            // 编辑模式：未新增图片时传 nil 保留原图；有新增则原图+新图
            if let imageUrls {
                urls = self.originImageUrls + imageUrls
            }
            switch self.mode {
            case .create(let courseId, _):
                CourseService.postReview(courseId: courseId, rating: self.rating, content: content, imageUrls: urls ?? []) { [weak self] error in
                    self?.handleResult(error: error, successText: "评价提交成功，等待平台审核")
                }
            case .edit(let review):
                guard let reviewId = review.review_id else {
                    self.hideLoading()
                    self.showToast("评价数据异常")
                    return
                }
                CourseService.updateReview(reviewId: reviewId, rating: self.rating, content: content, imageUrls: urls) { [weak self] error in
                    self?.handleResult(error: error, successText: "评价已更新")
                }
            }
        }

        if newDatas.isEmpty {
            submit(imageUrls: nil)
        } else {
            APIClient.shared.upload(files: newDatas, folder: "review") { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let json):
                    let urls = json["urls"].arrayValue.map { $0.stringValue }
                    if urls.isEmpty {
                        self.hideLoading()
                        self.showToast("图片上传失败")
                        return
                    }
                    submit(imageUrls: urls)
                case .failure(let error):
                    self.hideLoading()
                    self.showToast(error.message)
                }
            }
        }
    }

    private func handleResult(error: String?, successText: String) {
        hideLoading()
        if let error {
            showToast(error)
            return
        }
        showToast(successText)
        AnalyticsManager.shared.event("review_submit", params: ["is_edit": isEditMode])
        NotificationCenter.default.post(name: .reviewsDidChange, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
    }
}

extension ReviewComposeViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        contentText = textView.text
    }
}
