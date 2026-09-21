//
//  AppDelegate.swift
//  Together_ios
//
//  Created by qk on 2026/9/10.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        configureGlobalNavAppearance()
        // 极光推送（AppKey 未配置时自动跳过）
        PushManager.shared.setup(launchOptions: launchOptions)
        // 友盟统计（AppKey 未配置时自动跳过）
        AnalyticsManager.shared.setup()
        return true
    }

    /// APNs 注册成功 → 转发 deviceToken 给极光
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushManager.shared.handleDeviceToken(deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // 静默（模拟器/未配置时常见），不影响主流程
    }

    /// 全局导航栏统一外观：不透明白底 + 无分隔线。
    /// 与 BaseViewController.restoreSystemNav() 保持一致，避免 iOS 17 转场中 appearance 切换导致整片导航阴影。
    private func configureGlobalNavAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = Theme.Color.surface
        appearance.shadowColor = .clear
        appearance.titleTextAttributes = [
            .foregroundColor: Theme.Color.ink,
            .font: UIFont.appSection(17)
        ]
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}


