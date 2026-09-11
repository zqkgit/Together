import { request } from "./request";

export interface AuthUser {
  user_id: string;
  phone: string;
  nickname: string;
  avatar: string | null;
  city: string | null;
}

export interface SessionData {
  access_token: string;
  refresh_token: string;
  user: AuthUser;
  current_role: string;
  roles: string[];
}

export function sendCode(phone: string): Promise<{ expires_in?: number }> {
  return request({ url: "/auth/send-code", method: "POST", data: { phone }, auth: false });
}

export function loginWithCode(phone: string, code: string): Promise<SessionData> {
  return request({ url: "/auth/login", method: "POST", data: { phone, code }, auth: false });
}

export function wxLogin(payload: {
  code: string;
  phone?: string;
  sms_code?: string;
}): Promise<SessionData> {
  return request({ url: "/auth/wx-login", method: "POST", data: payload, auth: false });
}

export function getMe(): Promise<{ user: AuthUser; current_role: string; roles: string[] }> {
  return request({ url: "/auth/me", method: "GET" });
}

export function logout(): Promise<void> {
  return request({ url: "/auth/logout", method: "POST", data: {} });
}
