import Taro from "@tarojs/taro";

const BASE_URL = "http://127.0.0.1:3001/v1";
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

export async function request<T = any>(options: RequestOptions): Promise<T> {
  const { url, method = "GET", data, auth = true, retried = false } = options;
  const header: Record<string, string> = { "Content-Type": "application/json" };
  if (auth) {
    const token = getToken();
    if (token) header.Authorization = `Bearer ${token}`;
  }

  const response = await Taro.request({
    url: `${BASE_URL}${url}`,
    method,
    data,
    header,
    timeout: 15000
  });

  const body = response.data as any;

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
    const res = await Taro.request({
      url: `${BASE_URL}/auth/refresh`,
      method: "POST",
      data: { refresh_token: refreshToken },
      header: { "Content-Type": "application/json" },
      timeout: 10000
    });
    const body = res.data as any;
    if (body?.code === 0 && body.data?.access_token) {
      saveSession(body.data);
      return true;
    }
    return false;
  } catch {
    return false;
  }
}
