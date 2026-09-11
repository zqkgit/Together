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
 * 先取 ws token（/v1/messages/ws/token），再连 WS_URL；
 * WS_URL 未配置时返回 null（调用方走轮询兜底）
 */
export function connectMessageSocket(onMessage: (msg: any) => void): (() => void) | null {
  if (!APP_CONFIG.WS_URL) return null;

  let socketTask: Taro.SocketTask | null = null;
  let closed = false;

  const connect = async () => {
    try {
      const data = await request<any>({ url: "/messages/ws/token", method: "GET" });
      const url = `${APP_CONFIG.WS_URL}?token=${encodeURIComponent(data?.token || "")}`;
      socketTask = Taro.connectSocket({ url });
      socketTask.onMessage((res) => {
        try {
          const msg = typeof res.data === "string" ? JSON.parse(res.data) : res.data;
          onMessage(msg);
        } catch {
          // 忽略非 JSON 消息
        }
      });
      socketTask.onClose(() => {
        if (!closed) setTimeout(connect, 10000); // 断线重连
      });
      socketTask.onError(() => {
        if (!closed) setTimeout(connect, 15000);
      });
    } catch {
      // token 获取失败，静默（调用方走轮询）
    }
  };

  connect();

  return () => {
    closed = true;
    socketTask?.close({});
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
