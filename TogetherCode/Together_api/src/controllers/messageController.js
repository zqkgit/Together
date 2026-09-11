const { ok, fail } = require("../utils/response");
const jwt = require("jsonwebtoken");
const env = require("../config/env");
const {
  listConversations,
  createConversation,
  listConversationMessages,
  sendConversationMessage,
  listNotifications,
  markNotificationRead,
  markAllNotificationsRead,
  registerDevice
} = require("../services/messageService");

async function getConversations(req, res) {
  try {
    return ok(res, await listConversations(req.user.userId, req.query));
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postConversation(req, res) {
  try {
    const result = await createConversation(req.user.userId, req.body);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result.data, "会话已创建");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getConversationMessages(req, res) {
  try {
    const result = await listConversationMessages(req.user.userId, req.params.id, req.query);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postConversationMessage(req, res) {
  try {
    const result = await sendConversationMessage(req.user.userId, req.params.id, req.body);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result.data, "发送成功");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getNotificationsList(req, res) {
  try {
    return ok(res, await listNotifications(req.user.userId, req.query));
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function putNotificationRead(req, res) {
  try {
    const data = await markNotificationRead(req.user.userId, req.params.id);
    if (!data) {
      return fail(res, 404, 40493, "通知不存在");
    }
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function putNotificationsReadAll(req, res) {
  try {
    const data = await markAllNotificationsRead(req.user.userId);
    return ok(res, data, "已全部标记已读");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postDevice(req, res) {
  try {
    const result = await registerDevice(req.user.userId, req.body);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result.data, "设备已注册");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// GET /v1/ws/token · 签发 5 分钟短时效 WS 连接令牌
async function getWsToken(req, res) {
  try {
    const token = jwt.sign(
      {
        tokenType: "ws",
        userId: req.user.userId
      },
      env.jwtSecret,
      { expiresIn: "5m" }
    );

    return ok(res, {
      ws_url: `ws://${req.headers.host || "localhost:3000"}/ws?token=${token}`,
      ticket: token,
      expires_in: 300
    });
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

module.exports = {
  getConversations,
  postConversation,
  getConversationMessages,
  postConversationMessage,
  getNotificationsList,
  putNotificationRead,
  putNotificationsReadAll,
  postDevice,
  getWsToken
};
