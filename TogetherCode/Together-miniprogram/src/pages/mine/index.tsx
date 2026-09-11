import React from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image, Button } from "@tarojs/components";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

export default function MinePage() {
  const user = useAuthStore((s) => s.user);
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const logout = useAuthStore((s) => s.logout);

  const handleLogout = () => {
    logout();
    Taro.reLaunch({ url: "/pages/login/index" });
  };

  if (!isLoggedIn) {
    return (
      <View className="mine">
        <View className="mine-hero">
          <View className="avatar-placeholder">艺</View>
          <View className="mine-nick">未登录</View>
        </View>
        <Button
          className="btn-primary login-btn"
          onClick={() => Taro.navigateTo({ url: "/pages/login/index" })}
        >
          去登录
        </Button>
      </View>
    );
  }

  const entries = [
    { label: "我的订单", icon: "📦", url: "/pages/orders/index" },
    { label: "我的孩子", icon: "👶", url: "/pages/children/index" },
    { label: "收益中心", icon: "💰", url: "/pages/wallet/index" },
    { label: "消息通知", icon: "🔔", url: "/pages/messages/index" },
    { label: "退款申请", icon: "↩️", url: "/pages/refund/index" }
  ];

  return (
    <View className="mine">
      <View className="mine-hero">
        <Image className="mine-avatar" src={user?.avatar || ""} mode="aspectFill" />
        <View className="mine-nick">{user?.nickname || "家长用户"}</View>
        <View className="mine-phone">{user?.phone}</View>
      </View>

      <View className="card menu-card">
        {entries.map((item, index) => (
          <View
            key={item.url}
            className={`menu-row ${index < entries.length - 1 ? "menu-row-border" : ""}`}
            onClick={() => Taro.navigateTo({ url: item.url })}
          >
            <Text className="menu-icon">{item.icon}</Text>
            <Text className="menu-label">{item.label}</Text>
            <Text className="menu-arrow">›</Text>
          </View>
        ))}
      </View>

      <Button className="btn-plain logout-btn" onClick={handleLogout}>退出登录</Button>
    </View>
  );
}
