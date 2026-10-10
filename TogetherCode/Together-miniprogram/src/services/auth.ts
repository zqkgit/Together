import { request } from "./request";

export interface AuthUser {
  user_id: string;
  phone: string;
  nickname: string;
  avatar: string | null;
  city: string | null;
  signature?: string | null;
  // has_pay_password?: boolean; // 暂时隐藏，不涉及支付

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

export function loginPassword(phone: string, password: string): Promise<SessionData> {
  return request({ url: "/auth/login-password", method: "POST", data: { phone, password }, auth: false });
}

export function register(phone: string, code: string): Promise<SessionData> {
  return request({ url: "/auth/register", method: "POST", data: { phone, code }, auth: false });
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

/** 更新个人资料（昵称/头像/城市/签名） */
export function updateProfile(data: {
  nickname?: string;
  avatar?: string | null;
  city?: string | null;
  signature?: string | null;
}): Promise<{ user: AuthUser }> {
  return request({ url: "/auth/profile", method: "PATCH", data });
}

/** 修改登录密码 */
export function changePassword(oldPassword: string, newPassword: string): Promise<void> {
  return request({ url: "/auth/change-password", method: "POST", data: { old_password: oldPassword, new_password: newPassword } });
}

/** 更换绑定手机号 */
export function changePhone(phone: string, code: string): Promise<void> {
  return request({ url: "/auth/change-phone", method: "POST", data: { phone, code } });
}

// /** 设置/修改支付密码 — 暂时隐藏，不涉及支付 */
// export function setPayPassword(password: string): Promise<void> {
//   return request({ url: "/auth/pay-password", method: "POST", data: { password } });
// }

/** 注销账号 */
export function deactivateAccount(code: string): Promise<void> {
  return request({ url: "/auth/deactivate", method: "POST", data: { code } });
}

/** 发送安全验证码（用于换绑手机号、注销账号等场景） */
export function sendSmsCode(phone: string): Promise<{ expires_in?: number }> {
  return request({ url: "/auth/send-sms-code", method: "POST", data: { phone } });
}
