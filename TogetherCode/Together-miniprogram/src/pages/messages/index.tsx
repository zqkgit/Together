import React, { useEffect, useRef, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image } from "@tarojs/components";
import {
  getNotifications,
  markNotificationRead,
  markAllNotificationsRead,
  getConversations,
  type NotificationItem,
  type ConversationItem,
} from "../../services/message";
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

function fmtShortTime(value: string): string {
  if (!value) return "";
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return "";
  const bj = new Date(d.getTime() + 8 * 3600 * 1000);
  const pad = (n: number) => String(n).padStart(2, "0");
  const now = new Date();
  const nowBj = new Date(now.getTime() + 8 * 3600 * 1000);
  const todayStr = `${nowBj.getUTCFullYear()}-${pad(nowBj.getUTCMonth() + 1)}-${pad(nowBj.getUTCDate())}`;
  const dateStr = `${bj.getUTCFullYear()}-${pad(bj.getUTCMonth() + 1)}-${pad(bj.getUTCDate())}`;
  if (dateStr === todayStr) return `${pad(bj.getUTCHours())}:${pad(bj.getUTCMinutes())}`;
  return `${pad(bj.getUTCMonth() + 1)}-${pad(bj.getUTCDate())}`;
}

export default function MessagesPage() {
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const [tab, setTab] = useState(0); // 0=对话 1=通知
  const [conversations, setConversations] = useState<ConversationItem[]>([]);
  const [convUnread, setConvUnread] = useState(0);
  const [notifications, setNotifications] = useState<NotificationItem[]>([]);
  const [unread, setUnread] = useState(0);
  const [loading, setLoading] = useState(true);
  const stopWsRef = useRef<(() => void) | null>(null);

  const loadConv = async () => {
    try {
      const res = await getConversations({ page: 1, size: 50 });
      setConversations(res.list || []);
      setConvUnread(res.unread_total || 0);
    } catch {
      // 拦截器已提示
    }
  };

  const loadNotif = async () => {
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

  const loadAll = async () => {
    setLoading(true);
    await Promise.all([loadConv(), loadNotif()]);
    setLoading(false);
  };

  useEffect(() => {
    if (!isLoggedIn) {
      Taro.reLaunch({ url: "/pages/login/index" });
      return;
    }
    loadAll();
    const stop = connectMessageSocket((msg: any) => {
      if (msg?.event === "notification" || msg?.type === "new_notification" || msg?.data?.notification_id) {
        loadNotif();
      }
      if (msg?.event === "chat" || msg?.type === "new_message" || msg?.data?.message_id) {
        loadConv();
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
    const id = item.ref_id;
    const map: Record<string, string> = {
      post: "/pages/post-detail/index?id=",
      order: "/pages/order-detail/index?id=",
      refund: "/pages/refund-detail/index?id=",
      course: "/pages/course-detail/index?id=",
      announcement: "/pages/announcement-detail/index?id=",
      withdraw: "/pages/wallet/index",
    };
    const prefix = item.ref_type ? map[item.ref_type] : "";
    if (prefix && id) {
      Taro.navigateTo({ url: `${prefix}${id}` });
    }
  };

  const onConvClick = (item: ConversationItem) => {
    const peerName = encodeURIComponent(item.peer?.nickname || "艺启用户");
    Taro.navigateTo({ url: `/pages/chat/index?conversation_id=${item.conversation_id}&peer_name=${peerName}` });
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
        <View className="tab-bar">
          <View className={`tab ${tab === 0 ? "active" : ""}`} onClick={() => setTab(0)}>
            <Text className="tab-text">对话</Text>
            {convUnread > 0 && <View className="tab-badge"><Text className="badge-text">{convUnread > 99 ? "99+" : convUnread}</Text></View>}
          </View>
          <View className={`tab ${tab === 1 ? "active" : ""}`} onClick={() => setTab(1)}>
            <Text className="tab-text">通知</Text>
            {unread > 0 && <View className="tab-dot" />}
          </View>
        </View>
        {tab === 0 && (
          <Text className="add-btn" onClick={() => Taro.navigateTo({ url: "/pages/following-list/index" })}>+</Text>
        )}
        {tab === 1 && unread > 0 && (
          <Text className="read-all" onClick={readAll}>全部已读</Text>
        )}
      </View>

      {tab === 0 ? (
        loading ? (
          <View className="empty-tip">加载中...</View>
        ) : conversations.length === 0 ? (
          <View className="empty-tip">暂无对话{"\n"}点击右上角 + 发起聊天</View>
        ) : (
          <View className="conv-list">
            {conversations.map((c) => (
              <View key={c.conversation_id} className="card conv-card" onClick={() => onConvClick(c)}>
                {c.peer?.avatar ? (
                  <Image className="conv-avatar" src={c.peer.avatar} mode="aspectFill" />
                ) : (
                  <View className="conv-avatar avatar-placeholder">
                    <Text className="avatar-letter">{(c.peer?.nickname || "用").slice(0, 1)}</Text>
                  </View>
                )}
                <View className="conv-body">
                  <View className="conv-top">
                    <Text className="conv-name">{c.peer?.nickname || "艺启用户"}</Text>
                    <Text className="conv-time">{fmtShortTime(c.updated_at)}</Text>
                  </View>
                  <View className="conv-bottom">
                    <Text className="conv-preview">
                      {c.last_message ? (c.last_message.type === 2 ? "[图片]" : c.last_message.content) : "开始聊天吧"}
                    </Text>
                    {c.unread_count > 0 && (
                      <View className="conv-badge"><Text className="badge-text">{c.unread_count > 99 ? "99+" : c.unread_count}</Text></View>
                    )}
                  </View>
                </View>
              </View>
            ))}
          </View>
        )
      ) : (
        <>
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
        </>
      )}
    </View>
  );
}