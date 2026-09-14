import UIKit
import SnapKit
import Kingfisher

/// 图片全屏预览：黑底 + 横向分页浏览 + 页码 + 关闭
final class ImagePreviewViewController: UIViewController, UIScrollViewDelegate {

    private let images: [String]
    private let startIndex: Int

    private let scrollView = UIScrollView()
    private let pageControl = UIPageControl()
    private let closeButton = UIButton(type: .system)
    private var imageViews: [UIImageView] = []
    private var currentIndex: Int

    init(images: [String], startIndex: Int = 0) {
        self.images = images
        self.startIndex = startIndex
        self.currentIndex = startIndex
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .crossDissolve
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        currentIndex = startIndex
        setupScroll()
        setupChrome()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutImages()
    }

    /// 手动 frame 布局：每张图占一屏（scaleAspectFit 内容自动居中），分页横滑
    private func layoutImages() {
        let w = scrollView.bounds.width
        let h = scrollView.bounds.height
        guard w > 0, h > 0 else { return }
        for (i, iv) in imageViews.enumerated() {
            iv.frame = CGRect(x: CGFloat(i) * w, y: 0, width: w, height: h)
        }
        scrollView.contentSize = CGSize(width: w * CGFloat(imageViews.count), height: h)
        scrollView.setContentOffset(CGPoint(x: CGFloat(currentIndex) * w, y: 0), animated: false)
    }

    private func setupScroll() {
        scrollView.isPagingEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bounces = false
        scrollView.delegate = self
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { $0.edges.equalToSuperview() }

        for urlString in images {
            let iv = UIImageView()
            iv.contentMode = .scaleAspectFit
            iv.backgroundColor = .black
            if let url = URL(string: urlString) {
                iv.kf.setImage(with: url)
            }
            scrollView.addSubview(iv)
            imageViews.append(iv)
        }
    }

    private func setupChrome() {
        pageControl.isUserInteractionEnabled = false
        pageControl.hidesForSinglePage = true
        pageControl.numberOfPages = images.count
        pageControl.currentPage = startIndex
        pageControl.currentPageIndicatorTintColor = .white
        pageControl.pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.4)
        view.addSubview(pageControl)
        pageControl.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalToSuperview().inset(48)
        }

        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        closeButton.layer.cornerRadius = 18
        closeButton.clipsToBounds = true
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        view.addSubview(closeButton)
        closeButton.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            $0.trailing.equalToSuperview().inset(16)
            $0.width.height.equalTo(36)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.bounds.width > 0 else { return }
        currentIndex = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        pageControl.currentPage = currentIndex
    }

    @objc private func didTapClose() { dismiss(animated: true) }
}
