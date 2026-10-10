import React, { useEffect, useRef } from "react";
import Taro, { useDidShow } from "@tarojs/taro";
import "./app.scss";
import { useAuthStore } from "./store/auth";
import { connectMessageSocket } from "./services/push";
import { getConversations, getNotifications } from "./services/message";

/** 全局更新消息 TabBar 红点（index 3 = 消息 tab） */
async function updateGlobalBadge() {
  try {
    const [convRes, notifRes] = await Promise.all([
      getConversations({ page: 1, size: 1 }),
      getNotifications({ page: 1, page_size: 1 }),
    ]);
    const total = (convRes.unread_total || 0) + (notifRes.unread_total || 0);
    // 通知 custom-tab-bar 渲染红点
    Taro.eventCenter.trigger("unread:update", total);
  } catch {
    // 静默
  }
}

function App(props) {
  const hydrate = useAuthStore((s) => s.hydrate);
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const hydrated = useAuthStore((s) => s.hydrated);
  const stopWsRef = useRef<(() => void) | null>(null);

  useEffect(() => {
    hydrate();
  }, []);

  // 全局登录守卫：hydrate 完成后，未登录则跳转登录页
  useEffect(() => {
    if (hydrated && !isLoggedIn) {
      Taro.reLaunch({ url: "/pages/login/index" });
    }
  }, [hydrated, isLoggedIn]);

  // 全局 WS 连接：登录后建立，卸载时断开；通过 eventCenter 广播消息
  useEffect(() => {
    if (!isLoggedIn) {
      stopWsRef.current?.();
      stopWsRef.current = null;
      return;
    }
    // 登录后立即拉取未读数设置 badge
    updateGlobalBadge();

    const stop = connectMessageSocket((msg: any) => {
      // 广播给所有页面（messages / chat 等）
      Taro.eventCenter.trigger("ws:message", msg);

      // 收到新消息/通知时更新 TabBar 红点
      const evt = msg?.event || msg?.type;
      const isNotif = evt === "notification" || evt === "new_notification" || msg?.data?.notification_id;
      const isMsg = evt === "message" || evt === "chat" || evt === "new_message" || msg?.data?.message_id;
      if (isNotif || isMsg) {
        updateGlobalBadge();
      }
    });
    stopWsRef.current = stop || null;

    return () => {
      stopWsRef.current?.();
      stopWsRef.current = null;
    };
  }, [isLoggedIn]);

  // 每次页面显示时通知 custom-tab-bar 刷新选中态
  useDidShow(() => {
    Taro.eventCenter.trigger("onTabBarRefresh");
  });

  return props.children;
}

export default App;
