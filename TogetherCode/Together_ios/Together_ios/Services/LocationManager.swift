import Foundation
import CoreLocation

/// 定位封装（Apple 原生）
/// 仅请求 WhenInUse 权限；提供一次性取当前坐标 + 内存缓存 lastLocation。
/// 不接第三方地图 SDK，满足「附近推荐/选位置」的前置能力。
final class LocationManager: NSObject, CLLocationManagerDelegate {

    static let shared = LocationManager()

    private let manager = CLLocationManager()
    private var pending: ((CLLocation?) -> Void)?
    /// 最近一次成功坐标（缓存，避免频繁弹授权/定位）
    private(set) var lastLocation: CLLocation?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
    }

    /// 当前授权状态
    var authorizationStatus: CLAuthorizationStatus {
        if #available(iOS 14.0, *) {
            return manager.authorizationStatus
        }
        return CLLocationManager.authorizationStatus()
    }

    /// 是否已获得「使用中」授权
    var isAuthorized: Bool {
        let s = authorizationStatus
        return s == .authorizedWhenInUse || s == .authorizedAlways
    }

    /// 请求一次当前坐标。
    /// - 已授权：直接启动定位，拿到首个有效坐标后回调并停止。
    /// - 未决定：先请求授权，待用户选择后再尝试。
    /// - 拒绝/受限：直接回调 nil。
    func requestCurrentLocation(completion: @escaping (CLLocation?) -> Void) {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocating(completion: completion)
        case .notDetermined:
            pending = completion
            manager.requestWhenInUseAuthorization()
        default:
            completion(nil)
        }
    }

    private func startLocating(completion: @escaping (CLLocation?) -> Void) {
        pending = completion
        manager.requestLocation()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first, loc.horizontalAccuracy >= 0 else { return }
        lastLocation = loc
        manager.stopUpdatingLocation()
        pending?(loc)
        pending = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 定位失败（含用户拒绝定位/信号弱）：回调 nil，交由调用方兜底
        pending?(nil)
        pending = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if isAuthorized {
            // 授权刚授予：复用等待中的回调直接启动定位。
            // 注意：不要在此处包一层新闭包再调 self?.pending，否则 didUpdateLocations
            // 回调该闭包时会再次调用 self?.pending（仍是自己）形成无限递归导致栈溢出崩溃。
            if let pending = pending {
                startLocating(completion: pending)
            }
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            pending?(nil)
            pending = nil
        }
    }
}
