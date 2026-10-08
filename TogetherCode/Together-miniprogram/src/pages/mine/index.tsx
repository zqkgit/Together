import React, { useEffect, useRef, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image, ScrollView } from "@tarojs/components";
import { useAuthStore } from "../../store/auth";
import { connectMessageSocket, startNotificationPolling } from "../../services/push";
import { listChildren } from "../../services/child";
import { getFavorites } from "../../services/interaction";
import "./index.scss";

/** 统计数据 */
interface MineStats {
  childrenCount: number;
  courseCount: number;
  favoriteCount: number;
}

export default function MinePage() {
  const user = useAuthStore((s) => s.user);
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const currentRole = useAuthStore((s) => s.currentRole);
  const roles = useAuthStore((s) => s.roles);
  const logout = useAuthStore((s) => s.logout);
  const [unreadCount, setUnreadCount] = useState(0);
  const [stats, setStats] = useState<MineStats>({ childrenCount: 0, courseCount: 0, favoriteCount: 0 });
  const cleanupRef = useRef<(() => void) | null>(null);

  // 消息推送
  useEffect(() => {
    if (!isLoggedIn) return;
    let pollStop: (() => void) | null = null;
    const stopPoll = () => { pollStop?.(); pollStop = null; };
    const startPoll = () => {
      if (pollStop) return;
      pollStop = startNotificationPolling((list) => {
        const unread = list.filter((n: any) => !n.is_read).length;
        setUnreadCount(unread);
      });
    };
    startPoll();
    const stop = connectMessageSocket((msg) => {
      if (msg?.event === "connected") { stopPoll(); return; }
      if (msg?.event === "ws_unavailable") { startPoll(); return; }
      if (msg?.unread_total !== undefined) setUnreadCount(Number(msg.unread_total));
      if (msg?.type === "new_notification") setUnreadCount((c) => c + 1);
    });
    return () => { stop(); stopPoll(); };
  }, [isLoggedIn]);

  // 加载统计
  useEffect(() => {
    if (!isLoggedIn) return;
    loadStats();
  }, [isLoggedIn]);

  const loadStats = async () => {
    try {
      const [childRes, favRes] = await Promise.all([
        listChildren().catch(() => null),
        getFavorites("course", 1).catch(() => null)
      ]);
      let childrenCount = 0;
      let courseCount = 0;
      if (childRes) {
        const children = childRes.list || childRes.children || [];
        childrenCount = children.length;
        const courseIds = new Set<string>();
        (children as any[]).forEach((c: any) => {
          (c.balances || []).forEach((b: any) => {
            if (b.course_id) courseIds.add(b.course_id);
          });
        });
        courseCount = courseIds.size;
      }
      const favoriteCount = favRes?.total || 0;
      setStats({ childrenCount, courseCount, favoriteCount });
    } catch {
      // 忽略
    }
  };

  const handleLogout = () => {
    cleanupRef.current?.();
    logout();
    Taro.reLaunch({ url: "/pages/login/index" });
  };

  // 身份文案
  const roleText = (() => {
    const r = Number(currentRole) || 1;
    if (r === 2) return "当前身份：老师";
    if (r === 3) return "当前身份：工作室";
    return "当前身份：家长";
  })();

  // 是否需要认证提示（非老师且非工作室）
  const needsAuth = !roles?.includes("2") && !roles?.includes("3") && !roles?.includes(2) && !roles?.includes(3);

  // 菜单组
  const contentItems = [
    { icon: "👶", title: "我的孩子", url: "/pages/children/index" },
    { icon: "🎓", title: "我的课程", url: "/pages/my-courses/index" },
    { icon: "📦", title: "我的订单", url: "/pages/orders/index" },
    { icon: "🖼", title: "作品管理", url: "" }
  ];
  const serviceItems = [
    { icon: "⭐", title: "收藏与动态", url: "/pages/favorites/index" },
    { icon: "💰", title: "收益中心", url: "/pages/wallet/index" },
    { icon: "🎫", title: "优惠券", url: "" },
    { icon: "⚙️", title: "设置", url: "" }
  ];

  const handleMenuTap = (item: { title: string; url: string }) => {
    if (!item.url) {
      Taro.showToast({ title: `「${item.title}」功能开发中`, icon: "none" });
      return;
    }
    Taro.navigateTo({ url: item.url });
  };

  // 未登录状态
  if (!isLoggedIn) {
    return (
      <View className="mine">
        <View className="mine-header">
          <View className="mine-header-bg">
            <View className="mine-identity-chip">
              <Text className="mine-identity-text">当前身份：家长</Text>
            </View>
          </View>
          <View className="mine-user-row">
            <View className="mine-avatar-wrap">
              <Text className="mine-avatar-letter">艺</Text>
            </View>
            <View className="mine-user-info">
              <Text className="mine-nick">未登录</Text>
            </View>
          </View>
        </View>
        <View className="mine-menu-card">
          <View
            className="mine-menu-row"
            onClick={() => Taro.navigateTo({ url: "/pages/login/index" })}
          >
            <View className="mine-menu-icon-tile"><Text className="mine-menu-icon">🔑</Text></View>
            <Text className="mine-menu-label">去登录</Text>
            <Text className="mine-menu-chevron">›</Text>
          </View>
        </View>
      </View>
    );
  }

  return (
    <ScrollView className="mine" scrollY>
      {/* 沉浸式头部 */}
      <View className="mine-header">
        <View className="mine-header-bg">
          {/* 身份胶囊 + 设置 */}
          <View className="mine-header-top">
            <View className="mine-identity-chip">
              <Text className="mine-identity-text">{roleText}</Text>
              <Text className="mine-identity-chevron">▾</Text>
            </View>
            <View className="mine-settings-btn" onClick={handleLogout}>
              <Text className="mine-settings-icon">⚙</Text>
            </View>
          </View>
          {/* 用户行 */}
          <View className="mine-user-row">
            <View className="mine-avatar-wrap">
              {user?.avatar ? (
                <Image className="mine-avatar-img" src={user.avatar} mode="aspectFill" />
              ) : (
                <Text className="mine-avatar-letter">
                  {(user?.nickname || "艺").charAt(0)}
                </Text>
              )}
            </View>
            <View className="mine-user-info">
              <Text className="mine-nick">{user?.nickname || "家长用户"}</Text>
              <View className="mine-city-chip">
                <Text className="mine-city-pin">📍</Text>
                <Text className="mine-city-text">{user?.city || "未设置"}</Text>
              </View>
            </View>
          </View>
          {/* 统计卡 */}
          <View className="mine-stat-card">
            <View className="mine-stat-item" onClick={() => Taro.navigateTo({ url: "/pages/children/index" })}>
              <Text className="mine-stat-value">{stats.childrenCount}</Text>
              <Text className="mine-stat-label">我的孩子</Text>
            </View>
            <View className="mine-stat-divider" />
            <View className="mine-stat-item" onClick={() => Taro.navigateTo({ url: "/pages/my-courses/index" })}>
              <Text className="mine-stat-value">{stats.courseCount}</Text>
              <Text className="mine-stat-label">在学课程</Text>
            </View>
            <View className="mine-stat-divider" />
            <View className="mine-stat-item" onClick={() => Taro.navigateTo({ url: "/pages/favorites/index" })}>
              <Text className="mine-stat-value">{stats.favoriteCount}</Text>
              <Text className="mine-stat-label">收藏作品</Text>
            </View>
          </View>
        </View>
      </View>

      {/* 菜单卡 — 第一组 */}
      <View className="mine-menu-card">
        {contentItems.map((item, i) => (
          <View
            key={item.title}
            className={`mine-menu-row ${i < contentItems.length - 1 ? "mine-menu-row-border" : ""}`}
            onClick={() => handleMenuTap(item)}
          >
            <View className="mine-menu-icon-tile"><Text className="mine-menu-icon">{item.icon}</Text></View>
            <Text className="mine-menu-label">{item.title}</Text>
            <Text className="mine-menu-chevron">›</Text>
          </View>
        ))}
      </View>

      {/* 菜单卡 — 第二组 */}
      <View className="mine-menu-card mine-menu-card--second">
        {serviceItems.map((item, i) => (
          <View
            key={item.title}
            className={`mine-menu-row ${i < serviceItems.length - 1 ? "mine-menu-row-border" : ""}`}
            onClick={() => handleMenuTap(item)}
          >
            <View className="mine-menu-icon-tile"><Text className="mine-menu-icon">{item.icon}</Text></View>
            <Text className="mine-menu-label">{item.title}</Text>
            {item.title === "消息通知" && unreadCount > 0 && (
              <Text className="mine-menu-badge">{unreadCount > 99 ? "99+" : unreadCount}</Text>
            )}
            <Text className="mine-menu-chevron">›</Text>
          </View>
        ))}
      </View>

      {/* 开通身份提示 */}
      {needsAuth && (
        <View className="mine-auth-footer" onClick={() => Taro.showToast({ title: "认证功能开发中", icon: "none" })}>
          <View className="mine-auth-container">
            <Text className="mine-auth-icon">🔑</Text>
            <Text className="mine-auth-text">开通老师/工作室身份，解锁教学与经营能力</Text>
            <Text className="mine-auth-btn">去认证</Text>
          </View>
        </View>
      )}

      <View style={{ height: "200rpx" }} />
    </ScrollView>
  );
}