import UIKit
import SnapKit
import FSPagerView
import Kingfisher

/// 图片数组轮播（基于 FSPagerView 成熟轮子）：
/// 横向分页滑动 + 页码指示 + 点击回调
/// 复用场景：帖子详情头部作品图、课程详情图集等
final class ImageCarouselView: UIView, FSPagerViewDataSource, FSPagerViewDelegate {

    /// 点击第 index 张图（用于全屏预览）
    var onTapImage: ((Int) -> Void)?

    private let pagerView = FSPagerView()
    private let pageControl = FSPageControl()
    private var imageURLs: [String] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true

        pagerView.dataSource = self
        pagerView.delegate = self
        pagerView.isInfinite = false
        pagerView.automaticSlidingInterval = 0
        pagerView.register(FSPagerViewCell.self, forCellWithReuseIdentifier: "cell")
        addSubview(pagerView)
        pagerView.snp.makeConstraints { $0.edges.equalToSuperview() }

        pageControl.contentHorizontalAlignment = .center
        pageControl.numberOfPages = 0
        pageControl.currentPage = 0
        pageControl.setFillColor(UIColor.white.withAlphaComponent(0.55), for: .normal)
        pageControl.setFillColor(Theme.Color.brand, for: .selected)
        addSubview(pageControl)
        pageControl.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.bottom.equalToSuperview().inset(8)
        }
    }

    func configure(images: [String]) {
        imageURLs = images
        pageControl.numberOfPages = images.count
        pageControl.currentPage = 0
        pagerView.reloadData()
    }

    // MARK: - FSPagerViewDataSource

    func numberOfItems(in pagerView: FSPagerView) -> Int {
        imageURLs.count
    }

    func pagerView(_ pagerView: FSPagerView, cellForItemAt index: Int) -> FSPagerViewCell {
        let cell = pagerView.dequeueReusableCell(withReuseIdentifier: "cell", at: index)
        if let imageView = cell.imageView {
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.backgroundColor = Theme.Color.brandSoft
            if let url = URL(string: imageURLs[index]) {
                imageView.kf.setImage(with: url)
            }
        }
        return cell
    }

    // MARK: - FSPagerViewDelegate

    func pagerView(_ pagerView: FSPagerView, didSelectItemAt index: Int) {
        onTapImage?(index)
    }

    func pagerViewDidScroll(_ pagerView: FSPagerView) {
        pageControl.currentPage = pagerView.currentIndex
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
