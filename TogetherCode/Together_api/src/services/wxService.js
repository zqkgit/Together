const axios = require("axios");
const env = require("../config/env");

/**
 * 微信开放平台封装：仅保留小程序登录(code2session)。
 * 线下资金模式已移除微信支付下单 / 回调验签，平台全程不碰学费资金。
 * 未配置 WX_* 凭据时返回 { notConfigured: true }，调用方按 503 处理。
 */

function isWxConfigured() {
  return Boolean(env.wx.appId && env.wx.appSecret);
}

/**
 * 登录凭证校验：code → { openid, unionid, session_key }
 */
async function code2session(code) {
  if (!isWxConfigured()) {
    return { notConfigured: true };
  }
  if (!code) {
    return { error: { status: 400, code: 40080, message: "code is required" } };
  }

  try {
    const response = await axios.get("https://api.weixin.qq.com/sns/jscode2session", {
      params: {
        appid: env.wx.appId,
        secret: env.wx.appSecret,
        js_code: code,
        grant_type: "authorization_code"
      },
      timeout: 8000
    });
    const data = response.data || {};
    if (data.errcode) {
      return { error: { status: 400, code: 40081, message: `微信登录失败: ${data.errmsg || data.errcode}` } };
    }
    return { openid: data.openid, unionid: data.unionid || null, session_key: data.session_key };
  } catch (error) {
    return { error: { status: 502, code: 50280, message: "微信服务不可达" } };
  }
}

module.exports = {
  isWxConfigured,
  code2session
};
