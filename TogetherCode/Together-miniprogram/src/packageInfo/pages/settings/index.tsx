import React, { useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Switch } from "@tarojs/components";
import { useAuthStore } from "../../../store/auth";
import "./index.scss";

/** 设置行 */
interface SettingRow {
  icon: string;
  title: string;
  value?: string;
  hasSwitch?: boolean;
  url?: string;
  action?: "about" | "contact" | "logout";
}

/** 分组 */
const sections: SettingRow[][] = [
  [
    { icon: "👤", title: "个人资料", url: "" },
    { icon: "🔒", title: "账号与安全", url: "" },
  ],
  [
    { icon: "🔔", title: "消息通知", hasSwitch: true },
    { icon: "💳", title: "支付与钱包", url: "/packageWallet/pages/wallet/index" },
  ],
  [
    { icon: "ℹ️", title: "关于艺启", value: "v1.0", action: "about" },
    { icon: "🎧", title: "联系客服", action: "contact" },
  ],
];

export default function SettingsPage() {
  const logout = useAuthStore((s) => s.logout);
  const [pushEnabled, setPushEnabled] = useState(
    Taro.getStorageSync("push_notification_enabled") !== "false"
  );

  const handleRowTap = (row: SettingRow) => {
    // 开关行不处理点击
    if (row.hasSwitch) return;

    if (row.action === "about") {
      Taro.navigateTo({ url: "/packageInfo/pages/settings/about" });
      return;
    }
    if (row.action === "contact") {
      Taro.showModal({
        title: "联系客服",
        content: "客服微信：yiqi_kefu\n服务时间：9:00 - 21:00",
        showCancel: false,
        confirmText: "知道了",
      });
      return;
    }
    if (row.url) {
      Taro.navigateTo({ url: row.url });
      return;
    }
    // 暂未开放的页面
    Taro.showToast({ title: `「${row.title}」功能开发中`, icon: "none" });
  };

  const handleSwitchChange = (val: boolean) => {
    setPushEnabled(val);
    Taro.setStorageSync("push_notification_enabled", String(val));
  };

  const handleLogout = () => {
    Taro.showModal({
      title: "退出登录",
      content: "确定要退出当前账号吗？",
      confirmText: "退出",
      confirmColor: "#E5484D",
      success: (res) => {
        if (res.confirm) {
          logout();
          Taro.reLaunch({ url: "/pages/login/index" });
        }
      },
    });
  };

  return (
    <View className="settings">
      {sections.map((group, si) => (
        <View key={si} className="settings-group">
          {group.map((row, ri) => (
            <View
              key={row.title}
              className={`settings-row ${ri < group.length - 1 ? "settings-row--border" : ""}`}
              onClick={() => handleRowTap(row)}
            >
              <Text className="settings-row-icon">{row.icon}</Text>
              <Text className="settings-row-title">{row.title}</Text>
              {row.hasSwitch ? (
                <Switch
                  className="settings-row-switch"
                  checked={pushEnabled}
                  color="#14A640"
                  onChange={(e) => handleSwitchChange(e.detail.value)}
                />
              ) : (
                <>
                  {row.value && (
                    <Text className="settings-row-value">{row.value}</Text>
                  )}
                  <Text className="settings-row-chevron">›</Text>
                </>
              )}
            </View>
          ))}
        </View>
      ))}

      <View className="settings-logout" onClick={handleLogout}>
        <Text className="settings-logout-text">退出登录</Text>
      </View>

      <View style={{ height: "100rpx" }} />
    </View>
  );
}