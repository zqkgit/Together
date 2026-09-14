import UIKit
import SnapKit
import ESPullToRefresh

/// 品牌下拉刷新头：品牌绿旋转圆环 + 状态文案（对齐 YIQI 设计系统）
/// 注意：ESPullToRefresh 基类方法为 nonisolated，工程默认 MainActor 隔离，
/// 因此所有 override 显式标 nonisolated，UI 操作经 MainActor.assumeIsolated 执行。
final class BrandRefreshHeader: ESRefreshAnimator {

    private var spinner: BrandSpinnerView!
    private var titleLabel: UILabel!

    nonisolated override init() {
        super.init()
        MainActor.assumeIsolated {
            let spinner = BrandSpinnerView()
            let titleLabel = UILabel()

            let container = UIView()
            container.backgroundColor = .clear

            container.addSubview(spinner)
            spinner.snp.makeConstraints { $0.centerY.equalToSuperview(); $0.leading.equalToSuperview().offset(Theme.Spacing.l); $0.width.height.equalTo(22) }

            titleLabel.text = "下拉刷新"
            titleLabel.font = .appBody(13)
            titleLabel.textColor = Theme.Color.sub
            container.addSubview(titleLabel)
            titleLabel.snp.makeConstraints { $0.center.equalToSuperview() }

            self.spinner = spinner
            self.titleLabel = titleLabel
            self.view = container
            self.trigger = 56
            self.executeIncremental = 56
        }
    }

    nonisolated override func refreshAnimationBegin(view: ESRefreshComponent) {
        MainActor.assumeIsolated { [weak self] in
            self?.spinner.startAnimating()
        }
    }

    nonisolated override func refreshAnimationEnd(view: ESRefreshComponent) {
        MainActor.assumeIsolated { [weak self] in
            self?.spinner.stopAnimating()
            self?.titleLabel.text = "下拉刷新"
        }
    }

    nonisolated override func refresh(view: ESRefreshComponent, stateDidChange state: ESRefreshViewState) {
        MainActor.assumeIsolated { [weak self] in
            switch state {
            case .pullToRefresh:
                self?.titleLabel.text = "下拉刷新"
            case .releaseToRefresh:
                self?.titleLabel.text = "松开刷新"
            case .refreshing, .autoRefreshing:
                self?.titleLabel.text = "刷新中..."
            case .noMoreData:
                break
            }
        }
    }
}

/// 品牌绿旋转圆环（CAShapeLayer，无需图片资源）
final class BrandSpinnerView: UIView {

    private let shapeLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        let path = UIBezierPath(
            arcCenter: CGPoint(x: 11, y: 11),
            radius: 9,
            startAngle: -.pi / 2,
            endAngle: .pi * 1.5,
            clockwise: true
        )
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = Theme.Color.brand.cgColor
        shapeLayer.fillColor = UIColor.clear.cgColor
        shapeLayer.lineWidth = 2.2
        shapeLayer.lineCap = .round
        // 只画 3/4 圆环，开口随旋转产生"卷动"感
        shapeLayer.strokeEnd = 0.75
        layer.addSublayer(shapeLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func startAnimating() {
        let rotate = CABasicAnimation(keyPath: "transform.rotation.z")
        rotate.toValue = CGFloat.pi * 2
        rotate.duration = 0.8
        rotate.repeatCount = .infinity
        rotate.isRemovedOnCompletion = false
        layer.add(rotate, forKey: "brand_spinner_rotate")
        isHidden = false
    }

    func stopAnimating() {
        layer.removeAnimation(forKey: "brand_spinner_rotate")
        isHidden = true
    }
}
