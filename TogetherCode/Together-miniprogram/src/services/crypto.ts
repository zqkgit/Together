/**
 * 小程序接口加密工具（node-forge 实现）
 * 协议与后端 src/middlewares/encrypt.js 对齐：
 * RSA-OAEP(SHA256) 传输 32B 会话密钥 + AES-256-GCM 加密请求体/响应 data
 */
import forge from "node-forge";
import { APP_CONFIG } from "../config";

export const API_ENCRYPT_ENABLED = APP_CONFIG.API_ENCRYPT_ENABLED === true;

// 后端 RSA 公钥（DER SPKI，base64）——由后端 config/api_enc_public.der 导出
const PUBLIC_KEY_DER_B64 = APP_CONFIG.API_ENCRYPT_PUBLIC_KEY || "";

export interface EncSession {
  key: string; // 32B 会话密钥（原始字节的 latin1 字符串）
  encKey: string;
  nonce: string;
  timestamp: string;
}

/** Uint8Array → forge bytes string */
function bytesToString(u8: Uint8Array): string {
  return forge.util.binary.raw.encode(u8);
}

let cachedPubKey: forge.pki.rsa.PublicKey | null = null;

function getPublicKey(): forge.pki.rsa.PublicKey | null {
  if (cachedPubKey) return cachedPubKey;
  try {
    const der = forge.util.decode64(PUBLIC_KEY_DER_B64);
    const asn1 = forge.asn1.fromDer(forge.util.createBuffer(der));
    cachedPubKey = forge.pki.publicKeyFromAsn1(asn1);
    return cachedPubKey;
  } catch {
    return null;
  }
}

/** 随机字节：H5 用 crypto.getRandomValues，微信端用 wx.getRandomValues，兜底 Math.random */
async function randomBytes(n: number): Promise<Uint8Array> {
  const u8 = new Uint8Array(n);
  const g = globalThis as any;
  if (typeof crypto !== "undefined" && crypto.getRandomValues) {
    crypto.getRandomValues(u8);
    return u8;
  }
  if (g.wx && typeof g.wx.getRandomValues === "function") {
    const res = await new Promise<Uint8Array>((resolve, reject) => {
      g.wx.getRandomValues({
        length: n,
        success: (r: any) => resolve(new Uint8Array(r.randomValues)),
        fail: () => reject(new Error("wx.getRandomValues failed"))
      });
    });
    return res;
  }
  for (let i = 0; i < n; i++) u8[i] = Math.floor(Math.random() * 256);
  return u8;
}

export async function makeSession(): Promise<EncSession | null> {
  try {
    const pubKey = getPublicKey();
    if (!pubKey) return null;
    const keyBytes = await randomBytes(32);
    const keyStr = bytesToString(keyBytes);
    const encrypted = pubKey.encrypt(keyStr, "RSA-OAEP", {
      md: forge.md.sha256.create()
    });
    const nonce = await randomBytes(16);
    return {
      key: keyStr,
      encKey: forge.util.encode64(encrypted),
      nonce: forge.util.encode64(bytesToString(nonce)),
      timestamp: String(Math.floor(Date.now() / 1000))
    };
  } catch {
    return null;
  }
}

/** AES-256-GCM 加密 → {payload:{ct,tag,nonce}} */
export async function encryptBody(
  data: Record<string, any>,
  session: EncSession
): Promise<Record<string, any>> {
  const iv = bytesToString(await randomBytes(12));
  const cipher = forge.cipher.createCipher("AES-GCM", session.key);
  cipher.start({ iv: forge.util.createBuffer(iv) });
  cipher.update(forge.util.createBuffer(JSON.stringify(data), "utf8"));
  cipher.finish();
  const tag = (cipher.mode as any).tag.getBytes();
  return {
    payload: {
      ct: forge.util.encode64(cipher.output.getBytes()),
      tag: forge.util.encode64(tag),
      nonce: forge.util.encode64(iv)
    }
  };
}

/** AES-256-GCM 解密服务端响应 payload */
export async function decryptData(
  payload: Record<string, any>,
  session: EncSession
): Promise<any> {
  const decipher = forge.cipher.createDecipher("AES-GCM", session.key);
  decipher.start({
    iv: forge.util.createBuffer(forge.util.decode64(payload.nonce)),
    tag: forge.util.createBuffer(forge.util.decode64(payload.tag))
  });
  decipher.update(
    forge.util.createBuffer(forge.util.decode64(payload.ct))
  );
  const ok = (decipher as any).finish();
  if (!ok) {
    throw new Error("AES-GCM auth failed");
  }
  return JSON.parse((decipher as any).output.toString("utf8"));
}

/** 响应 data 可能是字符串（后端 JSON.stringify 后返回）或对象 */
export function extractPayload(body: any): Record<string, any> | null {
  if (!body || body.enc !== true || body.data == null) return null;
  const raw = body.data;
  if (typeof raw === "object" && raw.ct) return raw;
  if (typeof raw === "string") {
    try {
      const obj = JSON.parse(raw);
      return obj && obj.ct ? obj : null;
    } catch {
      return null;
    }
  }
  return null;
}
