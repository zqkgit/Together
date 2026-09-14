import UIKit

/// 双列瀑布流布局（广场作品流等场景复用）
/// 通过 delegate 提供每项高度；左右边距 12、列间距 12
final class WaterfallLayout: UICollectionViewLayout {

    protocol Delegate: AnyObject {
        func waterfall(_ layout: WaterfallLayout, heightForItemAt indexPath: IndexPath, itemWidth: CGFloat) -> CGFloat
    }

    weak var delegate: Delegate?

    /// 列数（默认 2）
    var columns: Int = 2
    /// 列间距 / 行间距
    var spacing: CGFloat = 12
    /// 内容左右边距（统一 12pt）
    var padding: CGFloat = 12

    private var cache: [UICollectionViewLayoutAttributes] = []
    private var contentHeight: CGFloat = 0
    private var itemWidth: CGFloat = 0

    override var collectionViewContentSize: CGSize {
        CGSize(width: collectionView?.bounds.width ?? 0, height: contentHeight)
    }

    override func prepare() {
        super.prepare()
        guard let collectionView else { return }

        cache.removeAll()
        contentHeight = 0

        let totalWidth = collectionView.bounds.width - padding * 2
        let gap = spacing * CGFloat(columns - 1)
        itemWidth = (totalWidth - gap) / CGFloat(columns)

        // 每列当前高度
        var columnHeights = [CGFloat](repeating: 0, count: columns)
        let itemCount = collectionView.numberOfItems(inSection: 0)
        guard itemCount > 0 else { return }

        for item in 0..<itemCount {
            let indexPath = IndexPath(item: item, section: 0)
            // 选最短列
            let targetColumn = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            let height = delegate?.waterfall(self, heightForItemAt: indexPath, itemWidth: itemWidth) ?? itemWidth * 1.3

            let x = padding + CGFloat(targetColumn) * (itemWidth + spacing)
            let y = columnHeights[targetColumn] + (columnHeights[targetColumn] > 0 ? spacing : 0)

            let attrs = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attrs.frame = CGRect(x: x, y: y, width: itemWidth, height: height)
            cache.append(attrs)

            columnHeights[targetColumn] = y + height
        }

        contentHeight = columnHeights.max() ?? 0
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        cache.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        cache.first { $0.indexPath == indexPath }
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView else { return false }
        return newBounds.width != collectionView.bounds.width
    }
}
