const express = require("express");
const { requireAuth } = require("../middlewares/auth");
const {
  getConversations,
  postConversation,
  getConversationMessages,
  postConversationMessage,
  getNotificationsList,
  putNotificationRead,
  putNotificationsReadAll,
  postDevice,
  getWsToken
} = require("../controllers/messageController");

const router = express.Router();

router.use(requireAuth);

// 私聊会话与消息
router.get("/conversations", getConversations);
router.post("/conversations", postConversation);
router.get("/conversations/:id/messages", getConversationMessages);
router.post("/conversations/:id/messages", postConversationMessage);

// 通知
router.get("/notifications", getNotificationsList);
router.put("/notifications/:id/read", putNotificationRead);
router.put("/notifications/read-all", putNotificationsReadAll);

// 极光设备上报 + WS 连接令牌
router.post("/devices", postDevice);
router.get("/ws/token", getWsToken);

module.exports = router;
