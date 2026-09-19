const crypto = require("crypto");
const { redis } = require("../config/db");
const env = require("../config/env");
const { fail } = require("../utils/response");

/**
 * 接口加密中间件（RSA-OAEP 传输会话密钥 + AES-256-GCM 加密请求体/响应 data）
 *
 * 协议：
 * - 客户端每个请求生成 32B 会话密钥 + 12B GCM nonce + 16B 重放 nonce
 * - 请求头：
 *   X-Enc-Key       RSA-OAEP(SHA256) 加密的会话密钥（base64）
 *   X-Enc-Nonce     重放 nonce（base64，服务端 Redis 去重 5 分钟）
 *   X-Enc-Timestamp 客户端时间戳（秒，±5 分钟窗口）
 * - 请求体（POST/PUT/DELETE）：{"payload": {"ct": base64, "tag": base64, "nonce": base64}}
 * - 响应：code/message 明文，data 为 base64 密文并带 enc: true
 *
 * 开关：env.apiEncrypt.enabled（生产开；开发默认关，不加密照常联调）
 * 白名单：上传(multipart)、WebSocket 握手、健康检查
 */

const SKIP_PATHS = ["/upload", "/health", "/ws", "/ws/"];
const TIME_WINDOW = 300; // ±5 分钟

function getPrivateKey() {
  const base64 = env.apiEncrypt.privateKey;
  if (!base64) {
    // 兼容直接放 PEM 文件（config/api_enc_private.pem）
    const fs = require("fs");
    const path = require("path");
    const pemPath = path.resolve(__dirname, "../../config/api_enc_private.pem");
    if (fs.existsSync(pemPath)) return fs.readFileSync(pemPath, "utf8");
    return null;
  }
  return Buffer.from(base64, "base64").toString("utf8");
}

function rsaDecrypt(cipher) {
  const key = getPrivateKey();
  if (!key) throw new Error("API_ENCRYPT_PRIVATE_KEY 未配置");
  return crypto.privateDecrypt(
    { key, padding: crypto.constants.RSA_PKCS1_OAEP_PADDING, oaepHash: "sha256" },
    cipher
  );
}

function aesDecrypt(key, payload) {
  const decipher = crypto.createDecipheriv("aes-256-gcm", key, Buffer.from(payload.nonce, "base64"));
  decipher.setAuthTag(Buffer.from(payload.tag, "base64"));
  const plain = Buffer.concat([
    decipher.update(Buffer.from(payload.ct, "base64")),
    decipher.final()
  ]);
  return plain.toString("utf8");
}

function aesEncrypt(key, plain, nonce) {
  const cipher = crypto.createCipheriv("aes-256-gcm", key, nonce);
  const ct = Buffer.concat([cipher.update(plain, "utf8"), cipher.final()]);
  return { ct: ct.toString("base64"), tag: cipher.getAuthTag().toString("base64"), nonce: nonce.toString("base64") };
}

function isWriteMethod(method) {
  return ["POST", "PUT", "PATCH", "DELETE"].includes(method);
}

function shouldSkip(req) {
  const p = req.path || req.url;
  // 兼容带 apiPrefix 的路径（如 /v1/upload、/v1/ws/xxx、/v1/health）
  return (
    p === "/upload" ||
    p.startsWith("/upload") ||
    p.includes("/ws") ||
    p.endsWith("/health")
  );
}

/** 校验重放 nonce（Redis SETNX 去重，5 分钟） */
async function checkNonce(nonce) {
  try {
    const key = `enc:nonce:${nonce}`;
    const set = await redis.set(key, "1", { EX: TIME_WINDOW, NX: true });
    return set === "OK";
  } catch {
    // Redis 不可用时降级为仅时间窗校验
    return true;
  }
}

module.exports = async function encryptMiddleware(req, res, next) {
  try {
    if (!env.apiEncrypt.enabled) return next();
    if (shouldSkip(req)) return next();

    const encKey = req.get("x-enc-key");
    const encNonce = req.get("x-enc-nonce");
    const encTimestamp = Number(req.get("x-enc-timestamp") || 0);

    // 开启后所有非白名单请求必须带加密头
    if (!encKey || !encNonce || !encTimestamp) {
      return fail(res, 400, 40091, "缺少加密头 X-Enc-*");
    }

    // 防重放：时间窗口 + nonce 去重
    const now = Math.floor(Date.now() / 1000);
    if (Math.abs(now - encTimestamp) > TIME_WINDOW) {
      return fail(res, 400, 40092, "请求时间戳超出窗口");
    }
    const nonceOk = await checkNonce(encNonce);
    if (!nonceOk) {
      return fail(res, 400, 40093, "重复请求");
    }

    // RSA 解出会话密钥
    const sessionKey = rsaDecrypt(Buffer.from(encKey, "base64"));

    // 写请求解密 body
    if (isWriteMethod(req.method) && req.body && req.body.payload) {
      try {
        const plain = aesDecrypt(sessionKey, req.body.payload);
        req.body = JSON.parse(plain);
      } catch (e) {
        return fail(res, 400, 40094, "请求体解密失败");
      }
    }

    // 响应加密：拦截 res.json，只加密 code===0 的 data
    const originalJson = res.json.bind(res);
    res.json = (obj) => {
      try {
        if (obj && obj.code === 0 && obj.data !== undefined && obj.data !== null) {
          const raw = typeof obj.data === "string" ? obj.data : JSON.stringify(obj.data);
          const payload = aesEncrypt(sessionKey, raw, crypto.randomBytes(12));
          obj = { ...obj, data: JSON.stringify(payload), enc: true };
        }
      } catch {
        // 加密失败不回滚，按明文返回
      }
      return originalJson(obj);
    };

    return next();
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
};
