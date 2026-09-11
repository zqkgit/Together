import React, { useEffect, useRef, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image, Button } from "@tarojs/components";
import { useAuthStore } from "../../store/auth";
import { connectMessageSocket, startNotificationPolling } from "../../services/push";
import "./index.scss";

export default function MinePage() {
  const user = useAuthStore((s) => s.user);
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const logout = useAuthStore((s) => s.logout);
  const [unreadCount, setUnreadCount] = useState(0);
  const cleanupRef = useRef<(() => void) | null>(null);

  // 消息推送：登录后建立站内信 WS（未配置 WS_URL 时退回轮询），更新未读角标
  useEffect(() => {
    if (!isLoggedIn) return;
    const stop = connectMessageSocket((msg) => {
      if (msg?.unread_total !== undefined) setUnreadCount(Number(msg.unread_total));
      if (msg?.type === "new_notification") setUnreadCount((c) => c + 1);
    });
    if (!stop) {
      const pollStop = startNotificationPolling((list) => {
        const unread = list.filter((n: any) => !n.read).length;
        setUnreadCount(unread);
      });
      cleanupRef.current = pollStop;
    } else {
      cleanupRef.current = stop;
    }
    return () => cleanupRef.current?.();
  }, [isLoggedIn]);

  const handleLogout = () => {
    cleanupRef.current?.();
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
    { label: "课程表", icon: "🗓️", url: "/pages/child-timetable/index" },
    { label: "收益中心", icon: "💰", url: "/pages/wallet/index" },
    { label: "消息通知", icon: "🔔", url: "/pages/messages/index", badge: unreadCount },
    { label: "退款申请", icon: "↩️", url: "/pages/orders/index?status=1" }
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
            {item.badge > 0 && <Text className="menu-badge">{item.badge > 99 ? "99+" : item.badge}</Text>}
            <Text className="menu-arrow">›</Text>
          </View>
        ))}
      </View>

      <Button className="btn-plain logout-btn" onClick={handleLogout}>退出登录</Button>
    </View>
  );
}
