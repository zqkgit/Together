/**
 * 消息推送逻辑骨架（先写逻辑，模板 ID / WS 地址配置后生效）
 * 双通道：微信订阅消息（下单/课时/退款提醒）+ 站内信 WebSocket（实时通知）
 */
import Taro from "@tarojs/taro";
import { APP_CONFIG } from "../config";
import { request } from "./request";

/** 请求订阅消息授权（微信小程序端，H5 环境自动跳过） */
export async function requestSubscribe(tplKey: "orderPaid" | "lessonRemind" | "refundResult"): Promise<boolean> {
  const tplId = APP_CONFIG.SUBSCRIBE_TPL_IDS[tplKey];
  if (!tplId) return false;
  if (!Taro.requestSubscribeMessage) return false;

  try {
    const res = await Taro.requestSubscribeMessage({ tmplIds: [tplId] });
    return res[tplId] === "accept";
  } catch {
    return false;
  }
}

/** 一键订阅常用提醒（登录后/下单成功后调用，最多 3 个模板） */
export async function subscribeCommonReminders(): Promise<void> {
  const tpls = APP_CONFIG.SUBSCRIBE_TPL_IDS;
  const ids = [tpls.orderPaid, tpls.lessonRemind, tpls.refundResult].filter(Boolean);
  if (ids.length === 0 || !Taro.requestSubscribeMessage) return;
  try {
    await Taro.requestSubscribeMessage({ tmplIds: ids });
  } catch {
    // 用户拒绝/取消，静默
  }
}

/**
 * 建立站内信 WebSocket（极光/自建服务）
 * 优先使用后端动态返回的 ws_url（开发环境零配置即可用）；
 * APP_CONFIG.WS_URL 配置后覆盖（上线走正式域名）。
 * 连接失败/未登录时返回 null（调用方走轮询兜底）
 */
export function connectMessageSocket(onMessage: (msg: any) => void): (() => void) | null {
  let socketTask: Taro.SocketTask | null = null;
  let closed = false;
  let retryTimer: ReturnType<typeof setTimeout> | null = null;

  const cleanupTask = () => {
    try {
      socketTask?.close({});
    } catch {
      // 忽略
    }
    socketTask = null;
  };

  const connect = async () => {
    if (closed) return;
    try {
      const data = await request<any>({ url: "/messages/ws/token", method: "GET" });
      if (closed) return;
      // 后端返回完整 ws_url（含 token），未配置 WS_URL 时直接用；
      // 配置了 WS_URL 则用它拼接 token（正式域名场景）
      let url = data?.ws_url || "";
      if (APP_CONFIG.WS_URL) {
        url = `${APP_CONFIG.WS_URL}?token=${encodeURIComponent(data?.ticket || data?.token || "")}`;
      }
      if (!url) {
        console.log("[push] no ws url");
        return;
      }
      cleanupTask();
      socketTask = await Taro.connectSocket({ url });
      if (closed) {
        cleanupTask();
        return;
      }
      socketTask.onOpen(() => {
        // 连接成功，通知调用方
        console.log("[push] ws open");
        onMessage({ event: "connected" });
      });
      socketTask.onMessage((res) => {
        try {
          const msg = typeof res.data === "string" ? JSON.parse(res.data) : res.data;
          onMessage(msg);
        } catch {
          // 忽略非 JSON 消息
        }
      });
      socketTask.onClose(() => {
        console.log("[push] ws close");
        if (!closed) {
          retryTimer = setTimeout(connect, 10000); // 断线重连（10s）
        }
      });
      socketTask.onError((err) => {
        if (!closed) {
          cleanupTask();
          retryTimer = setTimeout(connect, 15000);
        }
      });
    } catch (e) {
      // token 获取失败/连接失败（未登录/网络）：通知调用方可走轮询兜底
      onMessage({ event: "ws_unavailable" });
    }
  };

  connect();

  return () => {
    closed = true;
    if (retryTimer) clearTimeout(retryTimer);
    cleanupTask();
  };
}

/** 轮询兜底：WS 不可用时定时拉取通知列表 */
export function startNotificationPolling(onData: (list: any[]) => void, intervalMs = 30000): (() => void) | null {
  if (APP_CONFIG.WS_URL) return null; // 有 WS 就走 WS，不轮询
  let timer: ReturnType<typeof setInterval> | null = null;
  let stop = false;

  const tick = async () => {
    try {
      const data = await request<any>({ url: "/messages/notifications?page=1&page_size=20", method: "GET" });
      if (!stop) onData(data?.list || []);
    } catch {
      // 静默
    }
  };

  tick();
  timer = setInterval(() => {
    if (!stop) tick();
  }, intervalMs);

  return () => {
    stop = true;
    if (timer) clearInterval(timer);
  };
}
