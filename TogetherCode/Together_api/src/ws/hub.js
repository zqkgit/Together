const { WebSocketServer } = require("ws");
const jwt = require("jsonwebtoken");
const env = require("../config/env");

/**
 * WebSocket 连接中心
 * - 同一用户多端连接（Set 管理）
 * - 握手用 JWT（access token 或 /ws/token 签发的短时令牌）
 * - 心跳：服务端 30s ping，客户端 pong 响应，60s 无响应断开
 */
class WsHub {
  constructor() {
    this.wss = null;
    this.connections = new Map(); // userId(String) -> Set<ws>
    this.heartbeatInterval = null;
  }

  attach(server) {
    this.wss = new WebSocketServer({ server, path: "/ws" });

    this.wss.on("connection", (ws, req) => {
      const userId = this.authenticate(req);
      if (!userId) {
        ws.close(4001, "Unauthorized");
        return;
      }

      ws.userId = userId;
      ws.isAlive = true;
      ws.on("pong", () => {
        ws.isAlive = true;
      });

      if (!this.connections.has(userId)) {
        this.connections.set(userId, new Set());
      }
      this.connections.get(userId).add(ws);

      this.send(ws, { event: "connected", data: { user_id: userId } });

      ws.on("close", () => {
        const set = this.connections.get(userId);
        if (set) {
          set.delete(ws);
          if (set.size === 0) {
            this.connections.delete(userId);
          }
        }
      });
    });

    this.heartbeatInterval = setInterval(() => {
      if (!this.wss) return;
      for (const ws of this.wss.clients) {
        if (!ws.isAlive) {
          ws.terminate();
          continue;
        }
        ws.isAlive = false;
        ws.ping();
      }
    }, 30000);

    this.wss.on("close", () => {
      clearInterval(this.heartbeatInterval);
    });
  }

  authenticate(req) {
    const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);
    const token = url.searchParams.get("token");
    if (!token) {
      return null;
    }
    try {
      const decoded = jwt.verify(token, env.jwtSecret);
      if (decoded.tokenType === "ws" || decoded.userId) {
        return String(decoded.userId);
      }
      return null;
    } catch (_error) {
      return null;
    }
  }

  send(ws, payload) {
    if (ws.readyState === 1) {
      ws.send(JSON.stringify(payload));
    }
  }

  /**
   * 给指定用户所有在线连接推送；无人在线返回 false（调用方可走离线通道）
   */
  sendToUser(userId, payload) {
    const set = this.connections.get(String(userId));
    if (!set || set.size === 0) {
      return false;
    }
    for (const ws of set) {
      this.send(ws, payload);
    }
    return true;
  }

  isOnline(userId) {
    const set = this.connections.get(String(userId));
    return Boolean(set && set.size > 0);
  }
}

module.exports = new WsHub();
