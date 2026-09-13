import React, { useEffect, useRef, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text } from "@tarojs/components";
import { getNotifications, markNotificationRead, markAllNotificationsRead, type NotificationItem } from "../../services/message";
import { connectMessageSocket } from "../../services/push";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

function fmtTime(value: string | null | undefined): string {
  if (!value) return "";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return String(value).slice(0, 16).replace("T", " ");
  const bj = new Date(d.getTime() + 8 * 3600 * 1000);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${bj.getUTCFullYear()}-${pad(bj.getUTCMonth() + 1)}-${pad(bj.getUTCDate())} ${pad(bj.getUTCHours())}:${pad(bj.getUTCMinutes())}`;
}

export default function MessagesPage() {
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const [notifications, setNotifications] = useState<NotificationItem[]>([]);
  const [unread, setUnread] = useState(0);
  const [loading, setLoading] = useState(true);
  const stopWsRef = useRef<(() => void) | null>(null);

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

  useEffect(() => {
    if (!isLoggedIn) {
      Taro.reLaunch({ url: "/pages/login/index" });
      return;
    }
    load();
    // WS 实时：收到新通知立即刷新列表与未读数
    const stop = connectMessageSocket((msg: any) => {
      if (msg?.event === "notification" || msg?.type === "new_notification" || msg?.data?.notification_id) {
        load();
      }
    });
    stopWsRef.current = stop || null;
    return () => {
      stopWsRef.current?.();
      stopWsRef.current = null;
    };
  }, [isLoggedIn]);

  const onItemClick = async (item: NotificationItem) => {
    if (!item.is_read) {
      setUnread((u) => Math.max(0, u - 1));
      setNotifications((prev) => prev.map((n) => (n.notification_id === item.notification_id ? { ...n, is_read: true } : n)));
      markNotificationRead(item.notification_id).catch(() => undefined);
    }
    // 按引用类型跳转
    const id = item.ref_id;
    const map: Record<string, string> = {
      post: "/pages/post-detail/index?id=",
      order: "/pages/order-detail/index?id=",
      refund: "/pages/refund-detail/index?id=",
      course: "/pages/course-detail/index?id=",
      announcement: "/pages/announcement-detail/index?id=",
      withdraw: "/pages/wallet/index"
    };
    const prefix = item.ref_type ? map[item.ref_type] : "";
    if (prefix && id) {
      Taro.navigateTo({ url: `${prefix}${id}` });
    }
  };

  const readAll = async () => {
    if (unread === 0) return;
    setUnread(0);
    setNotifications((prev) => prev.map((n) => ({ ...n, is_read: true })));
    try {
      await markAllNotificationsRead();
    } catch {
      // 忽略
    }
  };

  const typeText = (t: string) => {
    const map: Record<string, string> = { order: "订单", course: "课程", commission: "收益", post: "动态", system: "系统", like: "点赞", comment: "评论", refund: "退款", leave: "请假", invite: "合作", withdraw: "提现", cert: "认证", growth: "成长", attendance: "上课" };
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
            <View key={n.notification_id} className={`card item ${n.is_read ? "" : "unread"}`} onClick={() => onItemClick(n)}>
              <View className="item-head">
                <Text className="item-type">{typeText(n.type)}</Text>
                {!n.is_read && <View className="dot" />}
              </View>
              <View className="item-title">{n.title}</View>
              <View className="item-content">{n.content}</View>
              <View className="item-time">{fmtTime(n.created_at)}</View>
            </View>
          ))}
        </View>
      )}
    </View>
  );
}
