import UIKit
import SnapKit
import Kingfisher

/// 微信式九宫格图片组件：按图片数量自动布局
/// - 1 张：大图（宽 2/3 容器，高 3/4 宽）
/// - 2 张：横排两列
/// - 3 张：横排三列
/// - 4 张：2×2
/// - 5~9 张：3 列网格（不足 9 张按序填充）
/// 间距统一 6pt，圆角统一 8pt；点击回调索引
final class PostImageGridView: UIView {

    var onTapImage: ((Int) -> Void)?

    private let spacing: CGFloat = 6
    private let corner: CGFloat = 8
    private var stackViews: [UIStackView] = []
    private var imageViews: [UIImageView] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 重建内容（可反复调用）
    func configure(urls: [String]) {
        stackViews.forEach { $0.removeFromSuperview() }
        stackViews.removeAll()
        imageViews.removeAll()

        guard !urls.isEmpty else { return }

        let count = urls.count
        if count == 1 {
            // 单张：大图靠左（宽 2/3 容器，4:3 比例）
            let imageView = makeImageView()
            addSubview(imageView)
            imageView.snp.makeConstraints {
                $0.top.leading.equalToSuperview()
                $0.width.equalToSuperview().multipliedBy(2.0 / 3.0)
                $0.height.equalTo(imageView.snp.width).multipliedBy(0.75)
                $0.bottom.equalToSuperview()
            }
            imageViews.append(imageView)
        } else {
            // 多张：列数 2 张=2、3 张=3、4 张=2、5~9 张=3
            let columns = count == 4 ? 2 : min(count, 3)
            let rows = Int(ceil(Double(count) / Double(columns)))
            for rowIndex in 0..<rows {
                let row = UIStackView()
                row.axis = .horizontal
                row.distribution = .fillEqually
                row.spacing = spacing
                addSubview(row)
                if rowIndex == 0 {
                    row.snp.makeConstraints { $0.top.leading.trailing.equalToSuperview() }
                } else {
                    row.snp.makeConstraints {
                        $0.top.equalTo(stackViews[rowIndex - 1].snp.bottom).offset(spacing)
                        $0.leading.trailing.equalToSuperview()
                    }
                }
                if rowIndex == rows - 1 {
                    row.snp.makeConstraints { $0.bottom.equalToSuperview() }
                }
                stackViews.append(row)

                let start = rowIndex * columns
                let end = min(start + columns, count)
                for index in start..<end {
                    let imageView = makeImageView()
                    row.addArrangedSubview(imageView)
                    imageViews.append(imageView)
                    imageView.snp.makeConstraints {
                        $0.height.equalTo(imageView.snp.width).multipliedBy(1.0) // 正方形
                    }
                }
            }
        }

        // 绑定图片
        for (index, imageView) in imageViews.enumerated() {
            imageView.tag = index
            let urlString = urls[index]
            if let url = URL(string: urlString) {
                imageView.kf.setImage(with: url, placeholder: WorkCardView.gradientPlaceholder(colors: [Theme.Color.surfaceAlt, Theme.Color.line]))
            }
        }
    }

    private func makeImageView() -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = Theme.Color.surfaceAlt
        imageView.layer.cornerRadius = corner
        imageView.layer.masksToBounds = true
        imageView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapImage(_:)))
        imageView.addGestureRecognizer(tap)
        return imageView
    }

    @objc private func didTapImage(_ sender: UITapGestureRecognizer) {
        guard let imageView = sender.view else { return }
        onTapImage?(imageView.tag)
    }
}
