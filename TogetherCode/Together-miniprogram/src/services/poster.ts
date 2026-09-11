import { request } from "./request";

export interface WxacodeResult {
  available: boolean;
  qrcode_url?: string;
  message?: string;
  link_id?: string;
  course_id?: string;
  post_id?: string | null;
}

/** 获取分享海报用的小程序码（配置 WX_APP_ID/SECRET 后返回真实码） */
export function fetchWxacode(code: string): Promise<WxacodeResult> {
  return request({ url: "/distribution/qrcode", method: "POST", data: { code } });
}
