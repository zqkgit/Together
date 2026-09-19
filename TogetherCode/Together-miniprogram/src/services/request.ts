import Taro from "@tarojs/taro";
import { APP_CONFIG } from "../config";
import { API_ENCRYPT_ENABLED, makeSession, encryptBody, decryptData, extractPayload, EncSession } from "./crypto";

const BASE_URL = APP_CONFIG.BASE_URL;
const TOKEN_KEY = "together_wx_access_token";
const REFRESH_KEY = "together_wx_refresh_token";
const ACCOUNT_KEY = "together_wx_account";

export function getToken(): string {
  return Taro.getStorageSync(TOKEN_KEY) || "";
}

export function getRefreshToken(): string {
  return Taro.getStorageSync(REFRESH_KEY) || "";
}

export function getAccount(): Record<string, any> | null {
  const raw = Taro.getStorageSync(ACCOUNT_KEY);
  return raw || null;
}

export function saveSession(data: any): void {
  Taro.setStorageSync(TOKEN_KEY, data.access_token);
  Taro.setStorageSync(REFRESH_KEY, data.refresh_token);
  Taro.setStorageSync(ACCOUNT_KEY, {
    user: data.user,
    current_role: data.current_role,
    roles: data.roles
  });
}

export function clearSession(): void {
  Taro.removeStorageSync(TOKEN_KEY);
  Taro.removeStorageSync(REFRESH_KEY);
  Taro.removeStorageSync(ACCOUNT_KEY);
}

interface RequestOptions {
  url: string;
  method?: "GET" | "POST" | "PUT" | "DELETE";
  data?: Record<string, any>;
  auth?: boolean;
  retried?: boolean;
}

function showError(message: string): void {
  Taro.showToast({ title: message, icon: "none", duration: 2200 });
}

/** 开启加密时：生成会话 + 附加加密头 + 写方法加密 body */
async function applyEncryption(
  method: string,
  data: Record<string, any> | undefined,
  header: Record<string, string>
): Promise<{ data: Record<string, any> | undefined; session: EncSession | null }> {
  if (!API_ENCRYPT_ENABLED) return { data, session: null };
  const session = await makeSession();
  if (!session) return { data, session: null };
  header["X-Enc-Key"] = session.encKey;
  header["X-Enc-Nonce"] = session.nonce;
  header["X-Enc-Timestamp"] = session.timestamp;
  const isWrite = ["POST", "PUT", "PATCH", "DELETE"].includes(method.toUpperCase());
  if (isWrite && data) {
    return { data: await encryptBody(data, session), session };
  }
  return { data, session };
}

/** 解密响应 data（enc===true 时） */
async function decryptResponseBody(body: any, session: EncSession | null): Promise<any> {
  if (!session) return body;
  const payload = extractPayload(body);
  if (!payload) return body;
  try {
    const decrypted = await decryptData(payload, session);
    return { ...body, data: decrypted, enc: false };
  } catch {
    return body;
  }
}

export async function request<T = any>(options: RequestOptions): Promise<T> {
  const { url, method = "GET", data, auth = true, retried = false } = options;
  const header: Record<string, string> = { "Content-Type": "application/json" };
  if (auth) {
    const token = getToken();
    if (token) header.Authorization = `Bearer ${token}`;
  }

  const { data: finalData, session } = await applyEncryption(method, data, header);

  const response = await Taro.request({
    url: `${BASE_URL}${url}`,
    method,
    data: finalData,
    header,
    timeout: 15000
  });

  let body = response.data as any;
  body = await decryptResponseBody(body, session);

  // 401 未登录/失效：尝试 refresh 一次
  if (body?.code === 40100 && auth && !retried) {
    const refreshed = await tryRefresh();
    if (refreshed) {
      return request({ ...options, retried: true });
    }
    clearSession();
    Taro.reLaunch({ url: "/pages/login/index" });
    throw new Error("登录已失效");
  }

  if (body?.code !== 0 && body?.code !== undefined) {
    showError(body?.message || "请求失败");
    throw new Error(body?.message || "请求失败");
  }

  return body?.data ?? (body as T);
}

async function tryRefresh(): Promise<boolean> {
  try {
    const refreshToken = getRefreshToken();
    if (!refreshToken) return false;
    const header: Record<string, string> = { "Content-Type": "application/json" };
    const { data: finalData, session } = await applyEncryption("POST", { refresh_token: refreshToken }, header);
    const res = await Taro.request({
      url: `${BASE_URL}/auth/refresh`,
      method: "POST",
      data: finalData,
      header,
      timeout: 10000
    });
    let body = res.data as any;
    body = await decryptResponseBody(body, session);
    if (body?.code === 0 && body.data?.access_token) {
      saveSession(body.data);
      return true;
    }
    return false;
  } catch {
    return false;
  }
}
