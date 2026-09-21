import UIKit
import MapKit
import CoreLocation
import SnapKit

/// 地点选择页（半屏卡片）
/// 仿「地点」选择交互：搜索地点（MKLocalSearch 实时检索）+ 当前位置（定位 + 反地理编码）
/// + 附近地点（MKLocalPointsOfInterestRequest 周边 POI），并保留「在地图上选取」二级兜底。
/// 全部使用 Apple 原生能力，不依赖第三方地图 SDK / Key。
final class LocationSearchViewController: UIViewController {

    /// 选点结果回调：纬度 / 经度 / 地点名
    var onSelect: ((Double, Double, String) -> Void)?
    /// 进入时预选位置（编辑回显，用于地图选点初始中心）
    var initialLocation: PostLocation?

    // MARK: 数据

    fileprivate struct Point {
        let name: String
        let address: String
        let coordinate: CLLocationCoordinate2D
    }

    private var currentCoord: CLLocationCoordinate2D?
    private var currentPoint: Point?
    private var nearby: [Point] = []
    private var nearbyLoading = false

    private var results: [Point] = []
    private var keyword = ""
    private var isSearching = false
    private var isSearchMode: Bool {
        let kw = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        return !kw.isEmpty
    }

    private let geocoder = CLGeocoder()
    private var nearbySearch: MKLocalSearch?
    private var keywordSearch: MKLocalSearch?
    private var searchWorkItem: DispatchWorkItem?
    private var locateTimeout: DispatchWorkItem?
    private var nearbyTimeout: DispatchWorkItem?
    private var searchTimeout: DispatchWorkItem?

    // MARK: UI

    private let titleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let searchBox = UIView()
    private let searchIcon = UIImageView()
    private let searchField = UITextField()
    private let clearButton = UIButton(type: .system)
    private lazy var tableView = UITableView(frame: .zero, style: .grouped)
    private let statusLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .medium)

    // MARK: 生命周期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.bg
        setupHeader()
        setupSearchBar()
        setupTable()
        setupStatus()
        loadCurrentLocation()
    }

    // MARK: 布局

    private func setupHeader() {
        titleLabel.text = "地点"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = Theme.Color.ink
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)
        titleLabel.snp.makeConstraints {
            $0.top.equalTo(view.safeAreaLayoutGuide).offset(Theme.Spacing.s)
            $0.centerX.equalToSuperview()
            $0.height.equalTo(36)
        }

        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = Theme.Color.ink
        closeButton.backgroundColor = Theme.Color.surface
        closeButton.layer.cornerRadius = 18
        closeButton.layer.masksToBounds = true
        closeButton.layer.borderColor = Theme.Color.line.cgColor
        closeButton.layer.borderWidth = 1
        closeButton.addTarget(self, action: #selector(didTapClose), for: .touchUpInside)
        view.addSubview(closeButton)
        closeButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
            $0.centerY.equalTo(titleLabel)
            $0.width.height.equalTo(36)
        }
    }

    private func setupSearchBar() {
        searchBox.backgroundColor = Theme.Color.surface
        searchBox.layer.cornerRadius = 22
        searchBox.layer.masksToBounds = true
        view.addSubview(searchBox)
        searchBox.snp.makeConstraints {
            $0.top.equalTo(titleLabel.snp.bottom).offset(Theme.Spacing.s)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.height.equalTo(44)
        }

        searchIcon.image = UIImage(systemName: "magnifyingglass")
        searchIcon.tintColor = Theme.Color.muted
        searchIcon.contentMode = .scaleAspectFit
        searchBox.addSubview(searchIcon)
        searchIcon.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(18)
        }

        searchField.placeholder = "搜索地点"
        searchField.font = .appBody(15)
        searchField.textColor = Theme.Color.ink
        searchField.returnKeyType = .search
        searchField.clearButtonMode = .never
        searchField.delegate = self
        searchField.addTarget(self, action: #selector(textDidChange), for: .editingChanged)
        searchBox.addSubview(searchField)
        searchField.snp.makeConstraints {
            $0.leading.equalTo(searchIcon.snp.trailing).offset(Theme.Spacing.s)
            $0.top.bottom.equalToSuperview()
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.xl)
        }

        clearButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clearButton.tintColor = Theme.Color.muted
        clearButton.isHidden = true
        clearButton.addTarget(self, action: #selector(didTapClearKeyword), for: .touchUpInside)
        searchBox.addSubview(clearButton)
        clearButton.snp.makeConstraints {
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.m)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(20)
        }
    }

    private func setupTable() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.estimatedRowHeight = 72
        tableView.rowHeight = UITableView.automaticDimension
        tableView.sectionHeaderTopPadding = 0
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: Theme.Spacing.l, right: 0)
        tableView.register(LocationPointCell.self, forCellReuseIdentifier: LocationPointCell.reuseId)
        tableView.register(LocationLoadingCell.self, forCellReuseIdentifier: LocationLoadingCell.reuseId)
        view.addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.top.equalTo(searchBox.snp.bottom).offset(Theme.Spacing.m)
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(view.safeAreaLayoutGuide)
        }
    }

    private func setupStatus() {
        statusLabel.font = .appBody(14)
        statusLabel.textColor = Theme.Color.sub
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.isHidden = true
        view.addSubview(statusLabel)
        statusLabel.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalTo(tableView).offset(-40)
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.xl)
        }

        spinner.isHidden = true
        view.addSubview(spinner)
        spinner.snp.makeConstraints {
            $0.centerX.equalToSuperview()
            $0.centerY.equalTo(tableView).offset(-70)
        }
    }

    // MARK: 数据加载

    private func loadCurrentLocation() {
        nearbyLoading = true
        NSLog("[LOCSEARCH] authorization status=\(LocationManager.shared.authorizationStatus.rawValue)")

        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.currentCoord == nil else { return }
            NSLog("[LOCSEARCH] location timeout (simulator may have no simulated location)")
            self.nearbyLoading = false
            self.currentPoint = nil
            self.tableView.reloadData()
            self.updateStatus()
        }
        locateTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeout)

        LocationManager.shared.requestCurrentLocation { [weak self] loc in
            guard let self else { return }
            guard let loc else {
                NSLog("[LOCSEARCH] location returned nil (denied / unavailable)")
                DispatchQueue.main.async {
                    self.locateTimeout?.cancel()
                    self.nearbyLoading = false
                    self.currentPoint = nil
                    self.currentCoord = nil
                    self.tableView.reloadData()
                    self.updateStatus()
                }
                return
            }
            let coord = loc.coordinate
            NSLog("[LOCSEARCH] got coordinate \(coord.latitude),\(coord.longitude)")
            self.currentCoord = coord
            self.geocoder.cancelGeocode()
            self.geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, error in
                guard let self else { return }
                if let error = error {
                    NSLog("[LOCSEARCH] reverse geocode error: \(error.localizedDescription)")
                }
                let pm = placemarks?.first
                let point = Point(
                    name: (pm?.name?.isEmpty == false) ? pm!.name! : "当前位置",
                    address: pm.map { Self.formatRegion($0) } ?? "",
                    coordinate: coord
                )
                NSLog("[LOCSEARCH] current name=\(point.name) region=\(point.address)")
                DispatchQueue.main.async {
                    self.locateTimeout?.cancel()
                    self.currentPoint = point
                    self.tableView.reloadData()
                }
            }
            self.fetchNearby(coord: coord)
        }
    }

    private func fetchNearby(coord: CLLocationCoordinate2D) {
        let request = MKLocalPointsOfInterestRequest(center: coord, radius: 2000)
        // 排除与「选位置」无关的交通/自助设施，降低噪声
        request.pointOfInterestFilter = MKPointOfInterestFilter(excluding: [
            .atm, .parking, .carRental, .gasStation, .evCharger,
            .fireStation, .restroom, .publicTransport
        ])
        let search = MKLocalSearch(request: request)
        nearbySearch = search

        // 超时兜底：模拟器/弱网下 POI 接口可能很慢，不阻塞当前位置与搜索
        nearbyTimeout?.cancel()
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.nearbyLoading else { return }
            NSLog("[LOCSEARCH] nearby POI timeout")
            self.nearbyLoading = false
            self.nearby = []
            self.tableView.reloadData()
            self.updateStatus()
        }
        nearbyTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: timeout)

        search.start { [weak self] response, error in
            guard let self else { return }
            if let error = error {
                NSLog("[LOCSEARCH] nearby POI error: \(error.localizedDescription)")
            }
            NSLog("[LOCSEARCH] nearby POI raw count=\(response?.mapItems.count ?? -1)")
            var seen = Set<String>()
            let points = (response?.mapItems ?? [])
                .filter { Self.distance($0.placemark.coordinate, from: coord) <= 3000 }
                .compactMap { item -> Point? in
                    guard let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !name.isEmpty, !seen.contains(name) else { return nil }
                    seen.insert(name)
                    return Point(name: name, address: Self.formatAddress(item.placemark), coordinate: item.placemark.coordinate)
                }
                .sorted { Self.distance($0.coordinate, from: coord) < Self.distance($1.coordinate, from: coord) }
            let limited = Array(points.prefix(20))
            DispatchQueue.main.async {
                self.nearbyTimeout?.cancel()
                self.nearby = limited
                self.nearbyLoading = false
                self.tableView.reloadData()
                self.updateStatus()
            }
        }
    }

    private func scheduleSearch(_ keyword: String) {
        searchWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.performSearch(keyword: keyword)
        }
        searchWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func performSearch(keyword: String) {
        keywordSearch?.cancel()
        searchTimeout?.cancel()
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = keyword
        let baseCoord = currentCoord ?? LocationManager.shared.lastLocation?.coordinate
        if let coord = baseCoord {
            request.region = MKCoordinateRegion(
                center: coord,
                latitudinalMeters: 50000,
                longitudinalMeters: 50000
            )
        }
        request.resultTypes = [.pointOfInterest, .address]
        request.pointOfInterestFilter = .includingAll
        let search = MKLocalSearch(request: request)
        keywordSearch = search
        isSearching = true
        results = []
        updateStatus()
        tableView.reloadData()

        // 超时兜底（弱网/区域判定异常时避免长时间转圈）
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.isSearching else { return }
            NSLog("[LOCSEARCH] keyword search timeout")
            self.isSearching = false
            self.results = []
            self.tableView.reloadData()
            self.updateStatus()
        }
        searchTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: timeout)

        search.start { [weak self] response, error in
            guard let self else { return }
            if let error = error {
                NSLog("[LOCSEARCH] keyword search error: \(error.localizedDescription)")
            }
            NSLog("[LOCSEARCH] keyword(\(keyword)) count=\(response?.mapItems.count ?? -1)")
            var items = response?.mapItems ?? []
            // 有当前坐标时按距离排序，且只保留 50km 内结果，避免区域判定异常时出现跨省/国外地点
            if let base = baseCoord {
                items.sort { Self.distance($0.placemark.coordinate, from: base) < Self.distance($1.placemark.coordinate, from: base) }
                items = items.filter { Self.distance($0.placemark.coordinate, from: base) <= 50000 }
            }
            var seen = Set<String>()
            let points = items
                .compactMap { item -> Point? in
                    guard let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !name.isEmpty, !seen.contains(name) else { return nil }
                    seen.insert(name)
                    return Point(name: name, address: Self.formatAddress(item.placemark), coordinate: item.placemark.coordinate)
                }
            DispatchQueue.main.async {
                self.searchTimeout?.cancel()
                self.isSearching = false
                self.results = points
                self.tableView.reloadData()
                self.updateStatus()
            }
        }
    }

    private func updateStatus() {
        if isSearchMode {
            if isSearching {
                statusLabel.isHidden = true
                spinner.isHidden = false
                spinner.startAnimating()
            } else {
                spinner.stopAnimating()
                spinner.isHidden = true
                if results.isEmpty {
                    statusLabel.text = "未找到相关地点，可点击「在地图上选取」"
                    statusLabel.isHidden = false
                } else {
                    statusLabel.isHidden = true
                }
            }
        } else {
            spinner.stopAnimating()
            spinner.isHidden = true
            if currentPoint == nil && !nearbyLoading {
                statusLabel.text = "无法获取当前位置，可点击下方在地图上选点"
                statusLabel.isHidden = false
            } else {
                statusLabel.isHidden = true
            }
        }
    }

    // MARK: 选择与跳转

    private func select(_ point: Point) {
        view.endEditing(true)
        onSelect?(point.coordinate.latitude, point.coordinate.longitude, point.name)
        dismiss(animated: true)
    }

    private func openMapPicker() {
        view.endEditing(true)
        let picker = LocationPickerViewController()
        picker.initialLocation = initialLocation
            ?? currentPoint.map { PostLocation(latitude: $0.coordinate.latitude, longitude: $0.coordinate.longitude, name: $0.name) }
        picker.onSelect = { [weak self] lat, lng, name in
            self?.onSelect?(lat, lng, name)
            self?.dismiss(animated: true)
        }
        navigationController?.pushViewController(picker, animated: true)
    }

    @objc private func didTapClose() {
        view.endEditing(true)
        dismiss(animated: true)
    }

    @objc private func didTapClearKeyword() {
        searchField.text = ""
        keyword = ""
        clearButton.isHidden = true
        keywordSearch?.cancel()
        results = []
        isSearching = false
        tableView.reloadData()
        updateStatus()
    }

    // MARK: 工具

    /// 详细地址：门牌/道路 + 区 + 市 + 省（去重）
    private static func formatAddress(_ pm: CLPlacemark) -> String {
        var parts: [String] = []
        let street = [pm.subThoroughfare, pm.thoroughfare]
            .compactMap { $0 }
            .joined()
        if !street.isEmpty { parts.append(street) }
        for cand in [pm.subLocality, pm.subAdministrativeArea, pm.locality, pm.administrativeArea] {
            if let v = cand, !v.isEmpty, !parts.contains(v) { parts.append(v) }
        }
        return parts.joined(separator: " ")
    }

    /// 当前位置简略地址：区 + 市 + 省
    private static func formatRegion(_ pm: CLPlacemark) -> String {
        [pm.subLocality ?? pm.subAdministrativeArea, pm.locality, pm.administrativeArea]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func distance(_ coord: CLLocationCoordinate2D, from base: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            .distance(from: CLLocation(latitude: base.latitude, longitude: base.longitude))
    }
}

// MARK: - UITableViewDataSource / Delegate

extension LocationSearchViewController: UITableViewDataSource, UITableViewDelegate {

    private enum Section: Int {
        case current = 0
        case nearby = 1
        case mapPick = 2
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        isSearchMode ? 1 : 3
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isSearchMode { return results.count }
        switch Section(rawValue: section) {
        case .current: return 1
        case .nearby: return nearbyLoading ? 1 : nearby.count
        case .mapPick: return 1
        case .none: return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isSearchMode {
            let cell = tableView.dequeueReusableCell(withIdentifier: LocationPointCell.reuseId, for: indexPath) as! LocationPointCell
            cell.configure(point: results[indexPath.row], style: .nearby)
            return cell
        }
        switch Section(rawValue: indexPath.section) {
        case .current:
            let cell = tableView.dequeueReusableCell(withIdentifier: LocationPointCell.reuseId, for: indexPath) as! LocationPointCell
            if let p = currentPoint {
                cell.configure(point: p, style: .current)
            } else {
                cell.configure(
                    point: Point(name: "无法获取当前位置", address: "点击在地图上选择位置", coordinate: CLLocationCoordinate2D()),
                    style: .disabledCurrent
                )
            }
            return cell
        case .nearby:
            if nearbyLoading {
                return tableView.dequeueReusableCell(withIdentifier: LocationLoadingCell.reuseId, for: indexPath)
            }
            let cell = tableView.dequeueReusableCell(withIdentifier: LocationPointCell.reuseId, for: indexPath) as! LocationPointCell
            cell.configure(point: nearby[indexPath.row], style: .nearby)
            return cell
        case .mapPick:
            let cell = tableView.dequeueReusableCell(withIdentifier: LocationPointCell.reuseId, for: indexPath) as! LocationPointCell
            cell.configure(
                point: Point(name: "在地图上选取", address: "移动地图光标，选择任意位置", coordinate: CLLocationCoordinate2D()),
                style: .mapPick
            )
            return cell
        case .none:
            return UITableViewCell()
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if isSearchMode {
            select(results[indexPath.row])
            return
        }
        switch Section(rawValue: indexPath.section) {
        case .current:
            if let p = currentPoint { select(p) } else { openMapPicker() }
        case .nearby:
            guard !nearbyLoading else { return }
            select(nearby[indexPath.row])
        case .mapPick:
            openMapPicker()
        case .none:
            break
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !isSearchMode, Section(rawValue: section) == .nearby,
              nearbyLoading || !nearby.isEmpty else { return UIView() }
        let holder = UIView()
        let label = UILabel()
        label.text = "附近地点"
        label.font = .appLabel(13)
        label.textColor = Theme.Color.sub
        holder.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.l + 4)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.s)
        }
        return holder
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard !isSearchMode else { return CGFloat.leastNormalMagnitude }
        if Section(rawValue: section) == .nearby {
            return (nearbyLoading || !nearby.isEmpty) ? 30 : CGFloat.leastNormalMagnitude
        }
        return CGFloat.leastNormalMagnitude
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? { UIView() }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        CGFloat.leastNormalMagnitude
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        view.endEditing(true)
    }
}

// MARK: - UITextFieldDelegate

extension LocationSearchViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    @objc private func textDidChange() {
        let text = searchField.text ?? ""
        keyword = text
        clearButton.isHidden = text.isEmpty
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            searchWorkItem?.cancel()
            keywordSearch?.cancel()
            results = []
            isSearching = false
            tableView.reloadData()
            updateStatus()
        } else {
            scheduleSearch(text)
            tableView.reloadData()
            updateStatus()
        }
    }
}

// MARK: - 地点卡片 Cell

private final class LocationPointCell: UITableViewCell {
    static let reuseId = "LocationPointCell"

    fileprivate enum Style {
        case current       // 当前位置：绿色图标 + 右侧「当前位置」标签
        case nearby        // 附近 / 搜索结果：灰色图标
        case mapPick       // 地图选点入口
        case disabledCurrent
    }

    private let card = UIView()
    private let iconBox = UIView()
    private let iconView = UIImageView()
    private let nameLabel = UILabel()
    private let addressLabel = UILabel()
    private let tagLabel = PaddedLabel()
    private let chevron = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = 16
        card.layer.masksToBounds = true
        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalToSuperview().offset(4)
            $0.bottom.equalToSuperview().offset(-4)
        }

        iconBox.layer.cornerRadius = 20
        iconBox.layer.masksToBounds = true
        card.addSubview(iconBox)
        iconBox.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
            $0.width.height.equalTo(40)
            $0.top.greaterThanOrEqualToSuperview().offset(Theme.Spacing.m)
            $0.bottom.lessThanOrEqualToSuperview().offset(-Theme.Spacing.m)
        }

        iconView.contentMode = .scaleAspectFit
        iconBox.addSubview(iconView)
        iconView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.width.height.equalTo(20)
        }

        nameLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        nameLabel.textColor = Theme.Color.ink
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        card.addSubview(nameLabel)
        nameLabel.snp.makeConstraints {
            $0.top.equalToSuperview().offset(Theme.Spacing.m)
            $0.leading.equalTo(iconBox.snp.trailing).offset(Theme.Spacing.m)
            $0.trailing.lessThanOrEqualToSuperview().offset(-Theme.Spacing.l)
        }

        addressLabel.font = .appBody(13)
        addressLabel.textColor = Theme.Color.sub
        addressLabel.numberOfLines = 2
        card.addSubview(addressLabel)
        addressLabel.snp.makeConstraints {
            $0.top.equalTo(nameLabel.snp.bottom).offset(2)
            $0.leading.equalTo(nameLabel)
            $0.trailing.lessThanOrEqualToSuperview().offset(-Theme.Spacing.l)
            $0.bottom.equalToSuperview().offset(-Theme.Spacing.m)
        }

        tagLabel.text = "当前位置"
        tagLabel.font = .appLabel(12)
        tagLabel.textColor = Theme.Color.sub
        tagLabel.backgroundColor = Theme.Color.surfaceAlt
        tagLabel.textInsets = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        tagLabel.layer.cornerRadius = 9
        tagLabel.layer.masksToBounds = true
        tagLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        tagLabel.isHidden = true
        card.addSubview(tagLabel)
        tagLabel.snp.makeConstraints {
            $0.centerY.equalTo(nameLabel)
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.l)
            $0.leading.greaterThanOrEqualTo(nameLabel.snp.trailing).offset(Theme.Spacing.s)
        }

        chevron.image = UIImage(systemName: "chevron.right")
        chevron.tintColor = Theme.Color.muted
        chevron.contentMode = .scaleAspectFit
        chevron.isHidden = true
        card.addSubview(chevron)
        chevron.snp.makeConstraints {
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.l)
            $0.width.equalTo(10)
            $0.height.equalTo(13)
        }

    }

    func configure(point: LocationSearchViewController.Point, style: Style) {
        nameLabel.text = point.name
        addressLabel.text = point.address
        addressLabel.isHidden = point.address.isEmpty
        tagLabel.isHidden = true
        chevron.isHidden = true

        switch style {
        case .current:
            iconBox.backgroundColor = Theme.Color.brandSoft
            iconView.tintColor = Theme.Color.brand
            iconView.image = UIImage(systemName: "paperplane.fill")
            tagLabel.isHidden = false
        case .nearby:
            iconBox.backgroundColor = Theme.Color.surfaceAlt
            iconView.tintColor = Theme.Color.sub
            iconView.image = UIImage(systemName: "paperplane.fill")
        case .mapPick:
            iconBox.backgroundColor = Theme.Color.brandSoft
            iconView.tintColor = Theme.Color.brand
            iconView.image = UIImage(systemName: "map.fill")
            chevron.isHidden = false
        case .disabledCurrent:
            iconBox.backgroundColor = Theme.Color.surfaceAlt
            iconView.tintColor = Theme.Color.muted
            iconView.image = UIImage(systemName: "location.slash")
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 加载中 Cell

private final class LocationLoadingCell: UITableViewCell {
    static let reuseId = "LocationLoadingCell"

    private let card = UIView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let label = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        card.backgroundColor = Theme.Color.surface
        card.layer.cornerRadius = 16
        card.layer.masksToBounds = true
        contentView.addSubview(card)
        card.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(Theme.Spacing.l)
            $0.top.equalToSuperview().offset(4)
            $0.bottom.equalToSuperview().offset(-4)
            $0.height.greaterThanOrEqualTo(56)
        }

        spinner.startAnimating()
        card.addSubview(spinner)
        spinner.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(Theme.Spacing.l)
            $0.centerY.equalToSuperview()
        }

        label.text = "正在获取附近地点…"
        label.font = .appBody(14)
        label.textColor = Theme.Color.sub
        card.addSubview(label)
        label.snp.makeConstraints {
            $0.leading.equalTo(spinner.snp.trailing).offset(Theme.Spacing.m)
            $0.centerY.equalToSuperview()
            $0.trailing.equalToSuperview().offset(-Theme.Spacing.l)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - 可设内边距的 Label

private final class PaddedLabel: UILabel {
    var textInsets = UIEdgeInsets.zero
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + textInsets.left + textInsets.right,
                      height: size.height + textInsets.top + textInsets.bottom)
    }
}
