/**
 * 微信小程序码：分享海报/传播获客用
 * 依赖 WX_APP_ID / WX_APP_SECRET（.env 配置后生效）
 * 未配置时返回 { available: false }，不影响其它功能
 */
const crypto = require("crypto");
const env = require("../config/env");
const { DistributionLink } = require("../models");
const { saveImage } = require("./uploadService");

let cachedToken = null;
let cachedTokenExpire = 0;

async function getWxAccessToken() {
  if (!env.wx.appId || !env.wx.appSecret) {
    return null;
  }
  const now = Date.now();
  if (cachedToken && now < cachedTokenExpire) {
    return cachedToken;
  }
  const url = `https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=${encodeURIComponent(
    env.wx.appId
  )}&secret=${encodeURIComponent(env.wx.appSecret)}`;
  const res = await fetch(url);
  const data = await res.json();
  if (!data.access_token) {
    return null;
  }
  cachedToken = data.access_token;
  cachedTokenExpire = now + (Number(data.expires_in || 7200) - 300) * 1000;
  return cachedToken;
}

function looksLikeImage(buffer) {
  if (!buffer || buffer.length < 4) return false;
  return (
    (buffer[0] === 0xff && buffer[1] === 0xd8) || // JPEG
    (buffer[0] === 0x89 && buffer[1] === 0x50) || // PNG
    (buffer[0] === 0x47 && buffer[1] === 0x49) // GIF
  );
}

/**
 * 生成带参小程序码（scene 固定为分享码，page 由分享类型决定）
 * @param {string} code 分销分享码
 */
async function createWxacodeForCode(code) {
  const codeStr = String(code || "").trim();
  if (!codeStr) {
    return { error: { status: 400, code: 40073, message: "分享码不能为空" } };
  }

  const link = await DistributionLink.findOne({ where: { code: codeStr, status: 1 } });
  if (!link) {
    return { error: { status: 404, code: 40473, message: "分享码不存在" } };
  }

  const token = await getWxAccessToken();
  if (!token) {
    // 微信凭据未配置：返回不可用（前端画占位二维码框）
    return { data: { available: false, message: "微信小程序码未配置，配置 WX_APP_ID/SECRET 后生效" } };
  }

  const page = link.post_id ? "pages/post-detail/index" : "pages/course-detail/index";
  const res = await fetch(`https://api.weixin.qq.com/wxa/getwxacodeunlimit?access_token=${token}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      scene: codeStr.slice(0, 32),
      page,
      width: 430,
      check_path: false,
      env_version: env.nodeEnv === "production" ? "release" : "develop"
    })
  });
  const arrayBuffer = await res.arrayBuffer();
  const buffer = Buffer.from(arrayBuffer);

  if (!looksLikeImage(buffer)) {
    return { error: { status: 502, code: 50270, message: "小程序码生成失败，请检查微信配置" } };
  }

  const url = await saveImage(buffer, { ext: "png", folder: "qrcode" });
  return {
    data: {
      available: true,
      qrcode_url: url,
      link_id: String(link.link_id),
      course_id: String(link.course_id),
      post_id: link.post_id ? String(link.post_id) : null
    }
  };
}

module.exports = {
  getWxAccessToken,
  createWxacodeForCode
};
