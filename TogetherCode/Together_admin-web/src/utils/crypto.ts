/**
 * 接口加密工具（Web Crypto 原生实现，零依赖）
 * 协议与后端 src/middlewares/encrypt.js 对齐：
 * RSA-OAEP(SHA256) 传输 32B 会话密钥 + AES-256-GCM 加密请求体/响应 data
 */
import type { AxiosResponse, InternalAxiosRequestConfig } from "axios";

// 开关：与后端 API_ENCRYPT_ENABLED 保持一致（上线开启，开发联调可关）
export const API_ENCRYPT_ENABLED =
  import.meta.env.VITE_API_ENCRYPT_ENABLED === "true";

// 后端 RSA 公钥（DER SPKI，base64）——由后端 config/api_enc_public.der 导出
const PUBLIC_KEY_DER_B64 = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAoAgbPsM0kaTfV0JdccSz/KYu78D21rD9o1cWSRUVQX8KvxnweWZ74f0ALoxBA9v9wyL30y/SRJBJmn/CBX83oeP+/zMre7E2KamNV+Gj47q/1DmQBsNrVAKRIE1ON1lX/TCJr2XGIF5LoM6pLobLTOoLNg/Xk6qUUpGEHTjCrDoOW3+0OGouWvC9UjhTMDhJwu9quWgLRq1frZL0PzyJpXBZtFTRwVVNo4jQpeisS5LzdviU2NuTxtQ/eIUHAf3pktqxxRYYUOaEqYJP8EE/j07X6y4IOSlLg5xYxbUQ2xN15mo8CYNAYd1HMRqAXz8X7lGfhyDmarNTos37jQeFAQIDAQAB";

export interface EncSession {
  key: CryptoKey;
  rawKey: Uint8Array; // 32B
  encKey: string;
  nonce: string;
  timestamp: string;
}

function b64(u8: ArrayBuffer | Uint8Array): string {
  const bytes = u8 instanceof Uint8Array ? u8 : new Uint8Array(u8);
  let bin = "";
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin);
}

function fromB64(s: string): Uint8Array {
  const bin = atob(s);
  const u8 = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) u8[i] = bin.charCodeAt(i);
  return u8;
}

let cachedPubKey: CryptoKey | null = null;

async function getPublicKey(): Promise<CryptoKey> {
  if (cachedPubKey) return cachedPubKey;
  cachedPubKey = await crypto.subtle.importKey(
    "spki",
    fromB64(PUBLIC_KEY_DER_B64).buffer as ArrayBuffer,
    { name: "RSA-OAEP", hash: "SHA-256" },
    false,
    ["encrypt"]
  );
  return cachedPubKey;
}

export async function makeSession(): Promise<EncSession | null> {
  try {
    const pubKey = await getPublicKey();
    const rawKey = crypto.getRandomValues(new Uint8Array(32));
    const aesKey = await crypto.subtle.importKey(
      "raw",
      rawKey.buffer as ArrayBuffer,
      "AES-GCM",
      false,
      ["encrypt", "decrypt"]
    );
    const encKeyBuf = await crypto.subtle.encrypt(
      { name: "RSA-OAEP" },
      pubKey,
      rawKey
    );
    const nonce = crypto.getRandomValues(new Uint8Array(16));
    return {
      key: aesKey,
      rawKey,
      encKey: b64(encKeyBuf),
      nonce: b64(nonce),
      timestamp: String(Math.floor(Date.now() / 1000))
    };
  } catch {
    return null;
  }
}

export async function encryptBody(
  data: Record<string, any>,
  session: EncSession
): Promise<Record<string, any>> {
  const plain = new TextEncoder().encode(JSON.stringify(data));
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const sealed = await crypto.subtle.encrypt({ name: "AES-GCM", iv }, session.key, plain);
  const sealedBytes = new Uint8Array(sealed); // 前 ct 后 tag（GCM combined）
  const tag = sealedBytes.slice(sealedBytes.length - 16);
  const ct = sealedBytes.slice(0, sealedBytes.length - 16);
  return {
    payload: {
      ct: b64(ct),
      tag: b64(tag),
      nonce: b64(iv)
    }
  };
}

export async function decryptData(
  payload: Record<string, any>,
  session: EncSession
): Promise<any> {
  const ct = fromB64(payload.ct);
  const tag = fromB64(payload.tag);
  const iv = fromB64(payload.nonce);
  const combined = new Uint8Array(ct.length + tag.length);
  combined.set(ct, 0);
  combined.set(tag, ct.length);
  const plain = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv: iv.buffer as ArrayBuffer },
    session.key,
    combined.buffer as ArrayBuffer
  );
  return JSON.parse(new TextDecoder().decode(plain));
}

/** axios 请求拦截：写方法加密 body + 附加加密头 */
export async function encryptRequest(
  config: InternalAxiosRequestConfig
): Promise<InternalAxiosRequestConfig> {
  if (!API_ENCRYPT_ENABLED) return config;
  const session = await makeSession();
  if (!session) return config;

  // 所有请求都带加密头（后端校验：缺头即 40091）
  config.headers = config.headers || {};
  config.headers["X-Enc-Key"] = session.encKey;
  config.headers["X-Enc-Nonce"] = session.nonce;
  config.headers["X-Enc-Timestamp"] = session.timestamp;
  // 会话用于响应解密（放 config 上传递）
  (config as any)._encSession = session;

  // 仅写方法且非上传表单时加密 body
  const isWrite = ["post", "put", "patch", "delete"].includes(
    (config.method || "get").toLowerCase()
  );
  if (isWrite && config.data && !(config.data instanceof FormData)) {
    config.data = await encryptBody(config.data, session);
  }
  return config;
}

/** axios 响应拦截：解密 code===0 且 enc 的 data */
export async function decryptResponse(
  response: AxiosResponse
): Promise<AxiosResponse> {
  const session = (response.config as any)?._encSession as EncSession | undefined;
  if (!session) return response;
  const body = response.data;
  if (body && body.enc && body.data) {
    let payload: Record<string, any>;
    try {
      payload = typeof body.data === "string" ? JSON.parse(body.data) : body.data;
    } catch {
      return response;
    }
    try {
      const decrypted = await decryptData(payload, session);
      body.data = decrypted;
      body.enc = false;
    } catch {
      // 解密失败保持原样，由业务层报错
    }
  }
  return response;
}
