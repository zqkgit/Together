import Foundation
#if canImport(UMCommon)
import UMCommon
#endif

/// 友盟 U-App 统计封装
/// - AppKey 未配置时整体跳过（不影响开发）
/// - 统一入口：事件埋点一律走 `AnalyticsManager.shared.event(...)`
final class AnalyticsManager {

    static let shared = AnalyticsManager()

    /// 是否已启用（AppKey 非空才初始化并上报）
    var isEnabled: Bool {
        !APIConfig.umengAppKey.isEmpty
    }

    private init() {}

    /// 初始化（AppDelegate didFinishLaunching 调用）
    func setup() {
        guard isEnabled else { return }
        #if canImport(UMCommon)
        UMConfigure.setLogEnabled(false)
        UMConfigure.initWithAppkey(APIConfig.umengAppKey, channel: APIConfig.umengChannel)
        MobClick.setAutoPageEnabled(true) // 自动采集页面浏览
        #endif
    }

    /// 自定义事件
    /// - Parameters:
    ///   - eventId: 事件 ID（友盟控制台可配置）
    ///   - params: 附加属性（可选，建议只传业务分类字段，不传个人隐私）
    func event(_ eventId: String, params: [String: Any]? = nil) {
        guard isEnabled else { return }
        #if canImport(UMCommon)
        if let params = params, !params.isEmpty {
            MobClick.event(eventId, attributes: params)
        } else {
            MobClick.event(eventId)
        }
        #endif
    }
}
