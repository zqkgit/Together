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

  // 消息推送：WS 实时优先 + 轮询兜底（WS connected 后停轮询），更新未读角标
  useEffect(() => {
    if (!isLoggedIn) return;
    let pollStop: (() => void) | null = null;
    const stopPoll = () => {
      pollStop?.();
      pollStop = null;
    };
    const startPoll = () => {
      if (pollStop) return;
      pollStop = startNotificationPolling((list) => {
        const unread = list.filter((n: any) => !n.is_read).length;
        setUnreadCount(unread);
      });
    };

    // 先轮询兜底，WS connected 后停掉
    startPoll();
    const stop = connectMessageSocket((msg) => {
      if (msg?.event === "connected") {
        stopPoll();
        return;
      }
      if (msg?.event === "ws_unavailable") {
        startPoll();
        return;
      }
      if (msg?.unread_total !== undefined) setUnreadCount(Number(msg.unread_total));
      if (msg?.type === "new_notification") setUnreadCount((c) => c + 1);
    });

    return () => {
      stop();
      stopPoll();
    };
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
    { label: "我的收藏", icon: "⭐", url: "/pages/favorites/index" },
    { label: "我的帖子", icon: "📝", url: "/pages/my-posts/index" },

    { label: "我的课程", icon: "🎓", url: "/pages/my-courses/index" },
    { label: "课程表", icon: "🗓️", url: "/pages/child-timetable/index" },
    { label: "收益中心", icon: "💰", url: "/pages/wallet/index" },
    { label: "消息通知", icon: "🔔", url: "/pages/messages/index", badge: unreadCount },
    { label: "退款申请", icon: "↩️", url: "/pages/refunds/index" }
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
