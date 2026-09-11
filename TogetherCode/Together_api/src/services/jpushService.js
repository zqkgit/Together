const axios = require("axios");
const env = require("../config/env");

/**
 * 极光推送（JPush）封装
 * 未配置 JPUSH_* 凭据时静默跳过（本地/联调环境不影响开发），配置后自动生效。
 * 文档：https://docs.jiguang.cn/jpush/server/push/rest_api_v3_push
 */
function isJpushEnabled() {
  return Boolean(env.jpush.appKey && env.jpush.masterSecret);
}

/**
 * 给指定用户推送（按该用户已上报的设备 registration_id 定向推送）
 * @param {string|number} userId 接收方 user_id
 * @param {object} payload { title, content, extras }
 */
async function notifyUser(userId, { title = "", content = "", extras = {} } = {}) {
  if (!isJpushEnabled()) {
    return { skipped: true, reason: "jpush not configured" };
  }

  const { UserDevice } = require("../models");
  const devices = await UserDevice.findAll({
    where: { user_id: userId, status: 1 },
    attributes: ["registration_id", "platform"]
  });
  if (!devices.length) {
    return { skipped: true, reason: "no device registered" };
  }

  // 极光 push API 每次 audience 上限 1000 个 registration_id
  const registrationIds = devices.map((device) => device.registration_id);
  const audience =
    registrationIds.length === 1
      ? { registration_id: [registrationIds[0]] }
      : { registration_id: registrationIds };

  try {
    const response = await axios.post(
      "https://api.jpush.cn/v3/push",
      {
        platform: "all",
        audience,
        notification: {
          alert: content || title,
          title,
          android: { alert: content || title, title, extras },
          ios: { alert: content || title, title, extras, sound: "default" }
        },
        options: {
          time_to_live: 86400,
          apns_production: env.nodeEnv === "production"
        }
      },
      {
        auth: {
          username: env.jpush.appKey,
          password: env.jpush.masterSecret
        },
        timeout: 5000
      }
    );
    return { sent: true, msg_id: response.data?.msg_id || null };
  } catch (error) {
    // 推送失败不阻断主流程（消息已落库，App 下次拉取可补）
    console.warn("[jpush] push failed:", error.message);
    return { skipped: true, reason: "push failed" };
  }
}

module.exports = {
  isJpushEnabled,
  notifyUser
};
