/**
 * 全局配置（集中管理，后续上线时只需改这里）
 */
export const APP_CONFIG = {
  // 后端 API 地址：开发环境走本地，上线替换为正式域名
  BASE_URL: "http://127.0.0.1:3001/v1",

  // 环境标识：dev / test / prod（决定日志、埋点等行为）
  ENV: "dev",

  // 微信小程序 AppID（从微信公众平台获取，配置后开启一键登录）
  WX_APP_ID: "",

  // 图片 CDN / OSS 域名（配置 OSS 后，图片 URL 前缀；未配置时使用后端返回原值）
  OSS_DOMAIN: "",

  // 微信订阅消息模板 ID（从小程序后台「订阅消息」申请，配置后开启下单/课时提醒）
  SUBSCRIBE_TPL_IDS: {
    orderPaid: "",
    lessonRemind: "",
    refundResult: ""
  },

  // 站内信 WebSocket（极光/自建 WS 二选一；未配置时退回轮询）
  WS_URL: ""
};
