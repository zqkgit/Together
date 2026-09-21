import UIKit
import MapKit
import CoreLocation
import SnapKit

/// 选择位置（Apple 原生 MKMapView + CLGeocoder 反地理编码）
/// 交互：点击地图任意点落点 → 中心大头针 + 反向地理编码出地点名；右上「确定」回传经纬度与名称。
/// 不上传第三方地图 SDK，满足「发布帖子时添加位置」与「附近推荐」的前置选点能力。
final class LocationPickerViewController: BaseViewController {

    /// 选点结果回调：纬度 / 经度 / 地点名
    var onSelect: ((Double, Double, String) -> Void)?
    /// 进入时预选位置（编辑回显）
    var initialLocation: PostLocation?

    private let mapView = MKMapView()
    private let pin = MKPointAnnotation()
    private let geoCoder = CLGeocoder()
    private var selectedCoord: CLLocationCoordinate2D?
    private var currentName = ""

    private let namePanel = UIView()
    private let nameLabel = UILabel()
    private let confirmButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        configureImmersiveNav(title: "选择位置", backTint: Theme.Color.ink)
        setupMap()
        setupBottomBar()
        setupInitialCenter()
    }

    // MARK: - UI

    private func setupMap() {
        mapView.delegate = self
        mapView.showsUserLocation = true
        mapView.showsScale = true
        view.addSubview(mapView)
        mapView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            // bottom 等 namePanel 加入同一层级后，在 setupBottomBar 中补齐，避免无共同祖先崩溃
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(didTapMap(_:)))
        mapView.addGestureRecognizer(tap)

        pin.title = "选择的位置"
        mapView.addAnnotation(pin)
    }

    private func setupBottomBar() {
        namePanel.backgroundColor = Theme.Color.surface
        namePanel.layer.shadowColor = UIColor.black.withAlphaComponent(0.06).cgColor
        namePanel.layer.shadowOffset = CGSize(width: 0, height: -2)
        namePanel.layer.shadowOpacity = 1
        namePanel.layer.shadowRadius = 6
        view.addSubview(namePanel)
        namePanel.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(96)
        }
        // 此时 mapView、namePanel 已同在 view 层级下，约束拥有共同祖先，可安全激活
        mapView.snp.makeConstraints {
            $0.bottom.equalTo(namePanel.snp.top)
        }

        nameLabel.font = .appBody(14)
        nameLabel.textColor = Theme.Color.ink
        nameLabel.numberOfLines = 2
        nameLabel.text = "点击地图选择位置"
        namePanel.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
        }

        confirmButton.setTitle("确定", for: .normal)
        confirmButton.setTitleColor(.white, for: .normal)
        confirmButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        confirmButton.backgroundColor = Theme.Color.brand
        confirmButton.layer.cornerRadius = 22
        confirmButton.clipsToBounds = true
        confirmButton.addTarget(self, action: #selector(didTapConfirm), for: .touchUpInside)
        namePanel.addSubview(confirmButton)
        confirmButton.snp.makeConstraints {
            $0.top.equalTo(nameLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(44)
        }
    }

    private func setupInitialCenter() {
        let center: CLLocationCoordinate2D
        if let loc = initialLocation {
            center = CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
        } else if let last = LocationManager.shared.lastLocation?.coordinate {
            center = last
        } else {
            // 默认北京（仅在无任何定位时兜底；首次进入会请求授权）
            center = CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)
        }
        let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        mapView.setRegion(region, animated: false)
        pin.coordinate = center
        selectedCoord = center
        reverseGeocode(center)
    }

    // MARK: - 交互

    @objc private func didTapMap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: mapView)
        let coord = mapView.convert(point, toCoordinateFrom: mapView)
        pin.coordinate = coord
        selectedCoord = coord
        reverseGeocode(coord)
    }

    private func reverseGeocode(_ coord: CLLocationCoordinate2D) {
        geoCoder.cancelGeocode()
        geoCoder.reverseGeocodeLocation(CLLocation(latitude: coord.latitude, longitude: coord.longitude)) { [weak self] placemarks, _ in
            guard let self else { return }
            let pm = placemarks?.first
            var parts: [String] = []
            if let name = pm?.name, !name.isEmpty { parts.append(name) }
            if let sub = pm?.thoroughfare, !sub.isEmpty, sub != pm?.name { parts.append(sub) }
            if let district = pm?.subLocality, !district.isEmpty { parts.append(district) }
            let title = parts.joined(separator: " ")
            let finalName = title.isEmpty
                ? String(format: "%.4f, %.4f", coord.latitude, coord.longitude)
                : title
            self.currentName = finalName
            self.nameLabel.text = "位置：" + finalName
        }
    }

    @objc private func didTapConfirm() {
        guard let coord = selectedCoord else { return }
        onSelect?(coord.latitude, coord.longitude, currentName)
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - MKMapViewDelegate

extension LocationPickerViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // 用户定位蓝点不自定义
        guard !(annotation is MKUserLocation) else { return nil }
        let reuseId = "LocationPin"
        var view = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? MKMarkerAnnotationView
        if view == nil {
            view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
        }
        view?.annotation = annotation
        view?.glyphText = ""
        view?.markerTintColor = Theme.Color.brand
        view?.isDraggable = true
        view?.canShowCallout = false
        return view
    }
}
