import React, { useEffect, useRef, useState } from "react";
import Taro, { usePullDownRefresh, useDidShow } from "@tarojs/taro";
import { View, Text, Image, ScrollView } from "@tarojs/components";
import {
  getNotifications,
  markNotificationRead,
  markAllNotificationsRead,
  getConversations,
  type NotificationItem,
  type ConversationItem,
} from "../../services/message";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

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

/** 通知类型 → emoji 图标（对齐 iOS SF Symbol 映射） */
function typeIcon(t: string): string {
  const map: Record<string, string> = {
    comment: "💬", like: "❤️", follow: "👤", order: "🛒",
    refund: "↩️", course: "📖", class: "📖", growth: "📈",
    checkin: "📈", leave: "📅", commission: "💰", withdraw: "💰",
    balance: "💰", teacher: "✅", studio: "✅", system: "📢",
    invite: "🤝", cert: "📜", attendance: "📋",
  };
  return map[t] || "🔔";
}

function typeText(t: string): string {
  const map: Record<string, string> = {
    order: "订单", course: "课程", commission: "收益", post: "动态",
    system: "系统", like: "点赞", comment: "评论", refund: "退款",
    leave: "请假", invite: "合作", withdraw: "提现", cert: "认证",
    growth: "成长", attendance: "上课", follow: "关注", balance: "余额",
    teacher: "老师", studio: "工作室", class: "课程", checkin: "签到",
  };
  return map[t] || "通知";
}

export default function MessagesPage() {
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const [tab, setTab] = useState(0); // 0=对话 1=通知
  const [conversations, setConversations] = useState<ConversationItem[]>([]);
  const [convUnread, setConvUnread] = useState(0);
  const convUnreadRef = useRef(0);
  const [convPage, setConvPage] = useState(1);
  const [convHasMore, setConvHasMore] = useState(true);

  const [notifications, setNotifications] = useState<NotificationItem[]>([]);
  const [unread, setUnread] = useState(0);
  const notifUnreadRef = useRef(0);
  const [notifPage, setNotifPage] = useState(1);
  const [notifHasMore, setNotifHasMore] = useState(true);

  const [loading, setLoading] = useState(true);

  const loadConv = async (page: number = 1, showLoading: boolean = true) => {
    if (showLoading && page === 1) setLoading(true);
    try {
      const res = await getConversations({ page, size: 20 });
      const list = res.list || [];
      if (page === 1) {
        setConversations(list);
      } else {
        setConversations((prev) => [...prev, ...list]);
      }
      setConvPage(page);
      setConvHasMore(list.length >= 20 && (conversations.length + list.length) < (res.total || 0));
      const convUn = res.unread_total || 0;
      setConvUnread(convUn);
      convUnreadRef.current = convUn;
      updateTabBarBadge();
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const loadNotif = async (page: number = 1, showLoading: boolean = true) => {
    if (showLoading && page === 1) setLoading(true);
    try {
      const data = await getNotifications({ page, page_size: 20 });
      const list = data.list || [];
      if (page === 1) {
        setNotifications(list);
      } else {
        setNotifications((prev) => [...prev, ...list]);
      }
      setNotifPage(page);
      setNotifHasMore(list.length >= 20 && (notifications.length + list.length) < (data.total || 0));
      const notifUn = data.unread_total || 0;
      setUnread(notifUn);
      notifUnreadRef.current = notifUn;
      updateTabBarBadge();
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const loadAll = async () => {
    setLoading(true);
    await Promise.all([loadConv(1, false), loadNotif(1, false)]);
    setLoading(false);
  };

  // 更新 TabBar 红点（通知 custom-tab-bar 渲染）
  // 使用 ref 取最新值，避免 loadConv/loadNotif 并行时闭包读到 stale state
  const updateTabBarBadge = () => {
    const total = convUnreadRef.current + notifUnreadRef.current;
    Taro.eventCenter.trigger("unread:update", total);
  };

  // 页面每次显示时刷新会话列表（对齐 iOS viewWillAppear → reloadCurrent）
  // 从聊天页返回后，后端已自动清除该会话未读数，重新拉取即可同步红点
  useDidShow(() => {
    if (!isLoggedIn) return;
    loadConv(1, false);
    loadNotif(1, false);
  });

  // 监听全局 WS 消息（由 app.tsx 广播）
  useEffect(() => {
    const handler = (msg: any) => {
      const evt = msg?.event || msg?.type;
      if (evt === "notification" || evt === "new_notification" || msg?.data?.notification_id) {
        loadNotif(1, false);
      }
      if (evt === "message" || evt === "chat" || evt === "new_message" || msg?.data?.message_id) {
        loadConv(1, false);
      }
    };
    Taro.eventCenter.on("ws:message", handler);
    return () => {
      Taro.eventCenter.off("ws:message", handler);
    };
  }, []);

  // 下拉刷新
  usePullDownRefresh(() => {
    const loader = tab === 0 ? loadConv(1, false) : loadNotif(1, false);
    loader.finally(() => Taro.stopPullDownRefresh());
  });

  // 滚动到底部加载更多
  const onScrollToLower = () => {
    if (tab === 0 && convHasMore) {
      loadConv(convPage + 1, false);
    } else if (tab === 1 && notifHasMore) {
      loadNotif(notifPage + 1, false);
    }
  };

  const onItemClick = async (item: NotificationItem) => {
    if (!item.is_read) {
      const newUnread = Math.max(0, notifUnreadRef.current - 1);
      setUnread(newUnread);
      notifUnreadRef.current = newUnread;
      setNotifications((prev) =>
        prev.map((n) => (n.notification_id === item.notification_id ? { ...n, is_read: true } : n))
      );
      updateTabBarBadge();
      markNotificationRead(item.notification_id).catch(() => undefined);
    }
    const id = item.ref_id;
    const map: Record<string, string> = {
      post: "/packageSocial/pages/post-detail/index?id=",
      order: "/packageOrder/pages/order-detail/index?id=",
      refund: "/packageOrder/pages/refund-detail/index?id=",
      course: "/packageCourses/pages/course-detail/index?id=",
      announcement: "/packageInfo/pages/announcement-detail/index?id=",
      withdraw: "/packageWallet/pages/wallet/index",
    };
    const prefix = item.ref_type ? map[item.ref_type] : "";
    if (prefix && id) {
      Taro.navigateTo({ url: `${prefix}${id}` });
    }
  };

  const onConvClick = (item: ConversationItem) => {
    const peerName = encodeURIComponent(item.peer?.nickname || "艺启用户");
    const peerAvatar = encodeURIComponent(item.peer?.avatar || "");
    Taro.navigateTo({ url: `/packageInfo/pages/chat/index?conversation_id=${item.conversation_id}&peer_name=${peerName}&peer_avatar=${peerAvatar}` });
  };

  const readAll = async () => {
    if (notifUnreadRef.current === 0) return;
    setUnread(0);
    notifUnreadRef.current = 0;
    setNotifications((prev) => prev.map((n) => ({ ...n, is_read: true })));
    updateTabBarBadge();
    try {
      await markAllNotificationsRead();
    } catch {
      // 忽略
    }
  };

  const switchTab = (index: number) => {
    if (index === tab) return;
    setTab(index);
    // 切换时如果列表为空则加载
    if (index === 0 && conversations.length === 0) loadConv(1, false);
    if (index === 1 && notifications.length === 0) loadNotif(1, false);
  };

  return (
    <View className="messages">
      {/* 胶囊式双Tab + 右侧操作 */}
      <View className="segment-row">
        <View className="segment">
          <View className={`seg-option ${tab === 0 ? "active" : ""}`} onClick={() => switchTab(0)}>
            <Text className="seg-text">对话</Text>
            {convUnread > 0 && (
              <View className="seg-badge">
                <Text className="seg-badge-text">{convUnread > 99 ? "99+" : convUnread}</Text>
              </View>
            )}
          </View>
          <View className={`seg-option ${tab === 1 ? "active" : ""}`} onClick={() => switchTab(1)}>
            <Text className="seg-text">通知</Text>
            {unread > 0 && <View className="seg-dot" />}
          </View>
        </View>
        <View className="seg-action">
          {tab === 0 && (
            <View className="add-btn" onClick={() => Taro.navigateTo({ url: "/packageSocial/pages/following-list/index" })}>
              <Text className="add-icon">+</Text>
            </View>
          )}
          {tab === 1 && unread > 0 && (
            <Text className="read-all" onClick={readAll}>全部已读</Text>
          )}
        </View>
      </View>

      {/* 列表区域 */}
      <ScrollView
        className="list-scroll"
        scrollY
        enhanced
        refresherEnabled
        onRefresherRefresh={() => {
          const p = tab === 0 ? loadConv(1, false) : loadNotif(1, false);
          p.finally(() => undefined);
        }}
        onScrollToLower={onScrollToLower}
      >
        {tab === 0 ? (
          loading && conversations.length === 0 ? (
            <View className="empty-state">加载中...</View>
          ) : conversations.length === 0 ? (
            <View className="empty-state">{"暂无会话，去和老师聊聊吧"}</View>
          ) : (
            <View className="conv-list">
              {conversations.map((c) => (
                <View key={c.conversation_id} className="conv-card" onClick={() => onConvClick(c)}>
                  {/* 头像 */}
                  {c.peer?.avatar ? (
                    <Image className="conv-avatar" src={c.peer.avatar} mode="aspectFill" />
                  ) : (
                    <View className="conv-avatar avatar-placeholder">
                      <Text className="avatar-letter">{(c.peer?.nickname || "艺").slice(0, 1)}</Text>
                    </View>
                  )}
                  {/* 内容 */}
                  <View className="conv-body">
                    <View className="conv-top">
                      <Text className="conv-name">{c.peer?.nickname || "艺启用户"}</Text>
                      <Text className="conv-time">{fmtShortTime(c.updated_at)}</Text>
                    </View>
                    <View className="conv-bottom">
                      <Text className={`conv-preview ${c.unread_count > 0 ? "unread" : ""}`}>
                        {c.last_message ? (c.last_message.type === 2 ? "[图片]" : c.last_message.content) : "开始聊天吧"}
                      </Text>
                      {c.unread_count > 0 && (
                        <View className="conv-badge">
                          <Text className="conv-badge-text">{c.unread_count > 99 ? "99+" : c.unread_count}</Text>
                        </View>
                      )}
                    </View>
                  </View>
                </View>
              ))}
            </View>
          )
        ) : (
          loading && notifications.length === 0 ? (
            <View className="empty-state">加载中...</View>
          ) : notifications.length === 0 ? (
            <View className="empty-state">暂无通知</View>
          ) : (
            <View className="notif-list">
              {notifications.map((n) => (
                <View
                  key={n.notification_id}
                  className={`notif-card ${n.is_read ? "" : "unread"}`}
                  onClick={() => onItemClick(n)}
                >
                  {/* 类型图标圆底 */}
                  <View className="notif-icon-wrap">
                    <Text className="notif-icon-emoji">{typeIcon(n.type)}</Text>
                  </View>
                  {/* 内容区 */}
                  <View className="notif-content">
                    <View className="notif-top">
                      <Text className={`notif-title ${n.is_read ? "" : "bold"}`}>{n.title}</Text>
                      <Text className="notif-time">{fmtShortTime(n.created_at)}</Text>
                    </View>
                    <View className="notif-bottom">
                      <Text className={`notif-desc ${n.is_read ? "" : "unread"}`}>
                        {n.content || n.title}
                      </Text>
                      {!n.is_read && <View className="notif-dot" />}
                    </View>
                  </View>
                </View>
              ))}
            </View>
          )
        )}
      </ScrollView>
    </View>
  );
}