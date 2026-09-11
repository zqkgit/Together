const crypto = require("crypto");
const axios = require("axios");
const env = require("../config/env");

/**
 * 微信开放平台封装：小程序登录(code2session) + 支付回调验签
 * 未配置 WX_* 凭据时返回 { notConfigured: true }，调用方按 503 处理。
 */

function isWxConfigured() {
  return Boolean(env.wx.appId && env.wx.appSecret);
}

function isWxPayConfigured() {
  return Boolean(env.wx.payMchId && env.wx.payKey);
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

/**
 * 微信支付 V2 回调验签（MD5）
 * 返回 null 表示验签失败；成功返回解出的字段对象。
 */
function verifyPayCallback(rawBody) {
  if (!isWxPayConfigured()) {
    return { notConfigured: true };
  }

  // 微信回调 XML 转对象（只取需要字段）
  const text = String(rawBody || "");
  const fields = {};
  const regex = /<(\w+)><!\[CDATA\[(.*?)\]\]><\/\1>/g;
  let match;
  while ((match = regex.exec(text))) {
    fields[match[1]] = match[2];
  }
  const plainRegex = /<(\w+)>([^<]+)<\/\1>/g;
  while ((match = plainRegex.exec(text))) {
    fields[match[1]] = match[2];
  }

  if (!fields.sign) {
    return { error: { status: 400, code: 40082, message: "回调缺少签名" } };
  }

  const { sign, ...rest } = fields;
  const signStr = Object.keys(rest)
    .filter((key) => rest[key] !== "" && key !== "sign")
    .sort()
    .map((key) => `${key}=${rest[key]}`)
    .join("&");

  const expected = crypto
    .createHash("md5")
    .update(`${signStr}&key=${env.wx.payKey}`)
    .digest("hex")
    .toUpperCase();

  if (expected !== String(sign).toUpperCase()) {
    return { error: { status: 400, code: 40083, message: "回调签名校验失败" } };
  }

  return fields;
}

module.exports = {
  isWxConfigured,
  isWxPayConfigured,
  code2session,
  verifyPayCallback
};
