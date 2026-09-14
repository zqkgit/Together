import UIKit
import SnapKit

/// 通用横向滚动卡片行：左右对齐内容区 24，卡片间 12 间距
final class HCardRow<Item>: UIView, UICollectionViewDataSource, UICollectionViewDelegate {

    typealias Builder = (Item) -> UIView
    typealias TapHandler = (Item) -> Void

    private var items: [Item]
    private let builder: Builder
    private let onTap: TapHandler?
    private let collectionView: UICollectionView
    private let cellID = "HCardCell"

    /// - Parameters:
    ///   - items: 数据
    ///   - itemSize: 卡片尺寸（与 builder 里卡片视图的宽高一致，flow layout 依赖它排布）
    ///   - builder: 卡片视图构建
    ///   - onTap: 点击回调
    init(items: [Item], itemSize: CGSize, builder: @escaping Builder, onTap: TapHandler? = nil) {
        self.items = items
        self.builder = builder
        self.onTap = onTap
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = Theme.Spacing.m
        layout.itemSize = itemSize
        // 左右边距由外层 cell 的 12pt inset 提供，这里不再额外缩进
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: .zero)

        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(HCardCell.self, forCellWithReuseIdentifier: cellID)
        addSubview(collectionView)
        collectionView.snp.makeConstraints { $0.edges.equalToSuperview() }
        // 高度由调用方按卡片内容设置（HCardRow 自身不设高度）
    }

    /// 更新数据（刷新）
    func reload(items: [Item]) {
        self.items = items
        collectionView.reloadData()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellID, for: indexPath) as! HCardCell
        let card = builder(items[indexPath.item])
        cell.configure(card: card)
        return cell
    }

    // MARK: - UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onTap?(items[indexPath.item])
    }
}

/// 横滑容器 cell：内容 = 卡片视图
final class HCardCell: UICollectionViewCell {
    private var cardView: UIView?

    func configure(card: UIView) {
        cardView?.removeFromSuperview()
        cardView = card
        contentView.addSubview(card)
        card.snp.makeConstraints { $0.edges.equalToSuperview() }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        cardView?.removeFromSuperview()
        cardView = nil
    }
}
