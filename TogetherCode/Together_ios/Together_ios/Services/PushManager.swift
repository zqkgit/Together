//
//  PushManager.swift
//  Together_ios
//
//  极光推送（JPush）统一封装：
//  1. App 启动时初始化极光 + 注册 APNs（AppKey 未配置时整体跳过，不影响开发环境）
//  2. 拿到极光 registrationID 后，登录态存在则自动上报 /v1/message/devices
//  3. 登录/注册成功（TokenManager.save）后再次触发上报（幂等，后端同 registration_id 复用）
//  未配置 JPush 时 App 内消息仍走 WebSocket 实时通道 + 轮询兜底。
//

import UIKit
import UserNotifications
import Alamofire
#if canImport(JPush)
import JPush
#endif

final class PushManager: NSObject {

    static let shared = PushManager()

    /// 是否启用极光（配置了 AppKey 才初始化；未配置时静默跳过）
    var isEnabled: Bool {
        !APIConfig.jpushAppKey.isEmpty
    }

    private let ridKey = "together_jpush_registration_id"
    private var registrationID: String? {
        get { UserDefaults.standard.string(forKey: ridKey) }
        set {
            if let newValue, !newValue.isEmpty {
                UserDefaults.standard.set(newValue, forKey: ridKey)
            } else {
                UserDefaults.standard.removeObject(forKey: ridKey)
            }
        }
    }

    private override init() {
        super.init()
    }

    // MARK: - 初始化

    /// App didFinishLaunching 调用
    func setup(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard isEnabled else {
            // 未配置 AppKey：跳过极光初始化，仅保留 APNs 注册由系统完成（可选，避免无谓授权弹窗，这里不申请）
            return
        }
        #if canImport(JPush)
        let entity = JPUSHRegisterEntity()
        entity.types = Int(
            JPAuthorizationOption.alert.rawValue
                | JPAuthorizationOption.badge.rawValue
                | JPAuthorizationOption.sound.rawValue
        )
        JPUSHService.register(forRemoteNotificationConfig: entity, delegate: self)
        JPUSHService.setup(
            withOption: launchOptions,
            appKey: APIConfig.jpushAppKey,
            channel: APIConfig.jpushChannel,
            apsForProduction: APIConfig.jpushIsProduction
        )
        // registrationID 异步返回（真机 APNs 注册成功后才会有；模拟器通常拿不到，自动跳过上报）
        JPUSHService.registrationIDCompletionHandler { [weak self] resCode, rid in
            guard resCode == 0, let rid = rid, !rid.isEmpty else { return }
            self?.registrationID = rid
            self?.reportIfNeeded()
        }
        #endif
    }

    /// 登录态就绪/变化后调用：登记当前设备
    func reportDevice() {
        reportIfNeeded()
    }

    /// 退出登录：解绑当前设备的极光推送（软删，重新登录自动复用）
    func unbindDevice() {
        guard isEnabled, let rid = registrationID, !rid.isEmpty else { return }
        // 退出登录时 token 即将被清空，先捕获再用独立请求发送
        guard let token = TokenManager.shared.accessToken else { return }
        let url = APIConfig.baseURL + "/message/devices"
        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(token)",
            "Accept": "application/json"
        ]
        AF.request(
            url,
            method: .delete,
            parameters: ["registration_id": rid],
            encoding: JSONEncoding.default,
            headers: headers
        ).responseJSON { _ in
            // 解绑失败静默（重新登录会自动换绑/复用）
        }
    }

    // MARK: - APNs token 转发（AppDelegate）

    func handleDeviceToken(_ deviceToken: Data) {
        #if canImport(JPush)
        JPUSHService.registerDeviceToken(deviceToken)
        #endif
    }

    // MARK: - 内部

    private func reportIfNeeded() {
        guard isEnabled, let rid = registrationID, !rid.isEmpty else { return }
        guard TokenManager.shared.isLoggedIn else { return }
        APIClient.shared.request(
            "/messages/devices",
            method: .post,
            parameters: ["registration_id": rid, "platform": "ios"]
        ) { _ in
            // 上报失败静默处理（下次登录/冷启动再报），不影响主流程
        }
    }
}

#if canImport(JPush)
extension PushManager: JPUSHRegisterDelegate {

    // iOS 10+：App 在前台收到推送
    func jpushNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (Int) -> Void
    ) {
        completionHandler(Int(UNNotificationPresentationOptions.alert.rawValue | UNNotificationPresentationOptions.sound.rawValue))
    }

    // iOS 10+：点击推送进入 App
    func jpushNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
#endif
