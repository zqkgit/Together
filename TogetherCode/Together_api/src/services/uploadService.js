const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const env = require("../config/env");

let ossClient = null;
function getOssClient() {
  const { region, accessKeyId, accessKeySecret, bucket } = env.oss;
  if (!region || !accessKeyId || !accessKeySecret || !bucket) {
    return null;
  }
  if (!ossClient) {
    const OSS = require("ali-oss");
    ossClient = new OSS({
      region,
      accessKeyId,
      accessKeySecret,
      bucket
    });
  }
  return ossClient;
}

function isOssEnabled() {
  return !!getOssClient();
}

const MIME_MAP = {
  jpg: "image/jpeg",
  jpeg: "image/jpeg",
  png: "image/png",
  gif: "image/gif",
  webp: "image/webp",
  heic: "image/heic"
};

/**
 * 保存图片文件（内存 buffer）→ 返回可访问 URL
 * 优先阿里云 OSS；未配置 OSS 时写入本地 uploads 目录（开发环境），由 /uploads 静态服务提供
 * @param {Buffer} buffer 文件内容
 * @param {object} options { ext 扩展名(不含点), folder 子目录 }
 */
async function saveImage(buffer, { ext = "png", folder = "common" } = {}) {
  const safeExt = ext.replace(/[^a-zA-Z0-9]/g, "").toLowerCase() || "png";
  const date = new Date();
  const ymd = `${date.getFullYear()}${String(date.getMonth() + 1).padStart(2, "0")}${String(date.getDate()).padStart(2, "0")}`;
  const key = `${folder}/${ymd}/${crypto.randomBytes(16).toString("hex")}.${safeExt}`;

  const client = getOssClient();
  if (client) {
    await client.put(key, buffer, {
      mime: MIME_MAP[safeExt] || "application/octet-stream"
    });
    const region = env.oss.region.startsWith("oss-") ? env.oss.region : `oss-${env.oss.region}`;
    const base = env.oss.publicUrl || `https://${env.oss.bucket}.${region}.aliyuncs.com`;
    return `${base.replace(/\/$/, "")}/${key}`;
  }

  // 本地回退
  const target = path.join(env.upload.dir, key);
  fs.mkdirSync(path.dirname(target), { recursive: true });
  fs.writeFileSync(target, buffer);
  return `/uploads/${key}`;
}

module.exports = {
  saveImage,
  isOssEnabled
};
