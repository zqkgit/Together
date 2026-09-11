import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text } from "@tarojs/components";
import { getNotifications, markNotificationRead, markAllNotificationsRead, type NotificationItem } from "../../services/message";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

export default function MessagesPage() {
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const [notifications, setNotifications] = useState<NotificationItem[]>([]);
  const [unread, setUnread] = useState(0);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!isLoggedIn) {
      Taro.reLaunch({ url: "/pages/login/index" });
      return;
    }
    load();
  }, [isLoggedIn]);

  const load = async () => {
    setLoading(true);
    try {
      const data = await getNotifications({ page: 1, page_size: 50 });
      setNotifications(data.list);
      setUnread(data.unread_total || 0);
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const onItemClick = async (item: NotificationItem) => {
    if (!item.read) {
      setUnread((u) => Math.max(0, u - 1));
      setNotifications((prev) => prev.map((n) => (n.notification_id === item.notification_id ? { ...n, read: true } : n)));
      markNotificationRead(item.notification_id).catch(() => undefined);
    }
    // 通知类型跳转：订单/课时/佣金等
    if (item.type === "order" && item.link) {
      Taro.navigateTo({ url: `/pages/order-detail/index?id=${item.link}` });
    } else if (item.type === "post" && item.link) {
      Taro.navigateTo({ url: `/pages/post-detail/index?id=${item.link}` });
    }
  };

  const readAll = async () => {
    if (unread === 0) return;
    setUnread(0);
    setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
    try {
      await markAllNotificationsRead();
    } catch {
      // 忽略
    }
  };

  const typeText = (t: string) => {
    const map: Record<string, string> = { order: "订单", course: "课程", commission: "收益", post: "动态", system: "系统" };
    return map[t] || "通知";
  };

  return (
    <View className="messages">
      <View className="head">
        <Text className="title">消息通知</Text>
        {unread > 0 && <Text className="read-all" onClick={readAll}>全部已读</Text>}
      </View>

      {loading ? (
        <View className="empty-tip">加载中...</View>
      ) : notifications.length === 0 ? (
        <View className="empty-tip">暂无消息</View>
      ) : (
        <View className="list">
          {notifications.map((n) => (
            <View key={n.notification_id} className={`card item ${n.read ? "" : "unread"}`} onClick={() => onItemClick(n)}>
              <View className="item-head">
                <Text className="item-type">{typeText(n.type)}</Text>
                {!n.read && <View className="dot" />}
              </View>
              <View className="item-title">{n.title}</View>
              <View className="item-content">{n.content}</View>
              <View className="item-time">{String(n.created_at || "").slice(0, 16)}</View>
            </View>
          ))}
        </View>
      )}
    </View>
  );
}
