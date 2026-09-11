const { Op } = require("sequelize");
const {
  sequelize,
  Conversation,
  ConversationMessage,
  Notification,
  UserDevice,
  User,
  Child
} = require("../models");
const { generateId } = require("../utils/id");
const wsHub = require("../ws/hub");
const jpush = require("./jpushService");

const CONV_STATUS_ACTIVE = 1;

function peerPair(myId, peerId) {
  const a = String(myId);
  const b = String(peerId);
  return a < b ? { peer_a: a, peer_b: b } : { peer_a: b, peer_b: a };
}

function normalizeUser(user) {
  return user
    ? {
        user_id: String(user.user_id),
        nickname: user.nickname || "艺启用户",
        avatar: user.avatar || null,
        role: user.current_role !== undefined ? Number(user.current_role) : null
      }
    : null;
}

function normalizeConversation(row, myUserId) {
  const mineIsA = String(row.peer_a) === String(myUserId);
  const peer = mineIsA ? row.userB : row.userA;
  const unread = mineIsA ? Number(row.unread_a || 0) : Number(row.unread_b || 0);

  return {
    conversation_id: String(row.conversation_id),
    peer: normalizeUser(peer),
    child: row.child
      ? { child_id: String(row.child.child_id), nickname: row.child.nickname }
      : null,
    last_message: row.lastMessage
      ? {
          message_id: String(row.lastMessage.message_id),
          sender_id: String(row.lastMessage.sender_id),
          type: row.lastMessage.type,
          content: row.lastMessage.content,
          created_at: row.lastMessage.created_at
        }
      : null,
    unread_count: unread,
    updated_at: row.updated_at
  };
}

/**
 * 会话列表（含最后一条消息 + 对方未读数）
 */
async function listConversations(userId, query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.min(Number(query.size) || 20, 50);

  const { rows, count } = await Conversation.findAndCountAll({
    where: {
      status: CONV_STATUS_ACTIVE,
      [Op.or]: [{ peer_a: userId }, { peer_b: userId }]
    },
    include: [
      { model: User, as: "userA", attributes: ["user_id", "nickname", "avatar", "current_role"] },
      { model: User, as: "userB", attributes: ["user_id", "nickname", "avatar", "current_role"] },
      { model: Child, as: "child", attributes: ["child_id", "nickname"] },
      {
        model: ConversationMessage,
        as: "lastMessage",
        attributes: ["message_id", "sender_id", "type", "content", "created_at"]
      }
    ],
    order: [["updated_at", "DESC"]],
    offset: (page - 1) * size,
    limit: size
  });

  const unread = await countUnread(userId);

  return {
    total: count,
    page,
    size,
    unread_total: unread,
    list: rows.map((row) => normalizeConversation(row, userId))
  };
}

async function countUnread(userId) {
  const conversations = await Conversation.findAll({
    where: { status: CONV_STATUS_ACTIVE, [Op.or]: [{ peer_a: userId }, { peer_b: userId }] },
    attributes: ["peer_a", "peer_b", "unread_a", "unread_b"]
  });

  return conversations.reduce((sum, conv) => {
    if (String(conv.peer_a) === String(userId)) {
      return sum + Number(conv.unread_a || 0);
    }
    return sum + Number(conv.unread_b || 0);
  }, 0);
}

/**
 * 发起私聊（幂等：已有会话直接返回）
 */
async function createConversation(userId, payload) {
  const peerId = String(payload.peer_user_id);
  if (!peerId || String(peerId) === String(userId)) {
    return { error: { status: 400, code: 40090, message: "peer_user_id 不合法" } };
  }

  const peer = await User.findByPk(peerId);
  if (!peer) {
    return { error: { status: 404, code: 40490, message: "对方用户不存在" } };
  }

  const pair = peerPair(userId, peerId);
  const where = {
    status: CONV_STATUS_ACTIVE,
    peer_a: pair.peer_a,
    peer_b: pair.peer_b
  };
  if (payload.child_id) {
    where.child_id = payload.child_id;
  }

  let conversation = await Conversation.findOne({
    where,
    include: [
      { model: User, as: "userA", attributes: ["user_id", "nickname", "avatar", "current_role"] },
      { model: User, as: "userB", attributes: ["user_id", "nickname", "avatar", "current_role"] },
      { model: Child, as: "child", attributes: ["child_id", "nickname"] },
      {
        model: ConversationMessage,
        as: "lastMessage",
        attributes: ["message_id", "sender_id", "type", "content", "created_at"]
      }
    ]
  });

  if (!conversation) {
    conversation = await Conversation.create({
      conversation_id: generateId(),
      peer_a: pair.peer_a,
      peer_b: pair.peer_b,
      child_id: payload.child_id || null,
      last_message_id: null,
      unread_a: 0,
      unread_b: 0,
      status: CONV_STATUS_ACTIVE
    });
    conversation = await Conversation.findByPk(conversation.conversation_id, {
      include: [
        { model: User, as: "userA", attributes: ["user_id", "nickname", "avatar", "current_role"] },
        { model: User, as: "userB", attributes: ["user_id", "nickname", "avatar", "current_role"] },
        { model: Child, as: "child", attributes: ["child_id", "nickname"] },
        {
          model: ConversationMessage,
          as: "lastMessage",
          attributes: ["message_id", "sender_id", "type", "content", "created_at"]
        }
      ]
    });
  }

  return { data: normalizeConversation(conversation, userId) };
}

function normalizeMessage(row) {
  return {
    message_id: String(row.message_id),
    conversation_id: String(row.conversation_id),
    sender: normalizeUser(row.sender),
    type: row.type,
    content: row.content,
    read_at: row.read_at,
    created_at: row.created_at
  };
}

/**
 * 消息记录（分页，读取后自动把"对方发来的未读"标记已读）
 */
async function listConversationMessages(userId, conversationId, query = {}) {
  const conversation = await Conversation.findOne({
    where: { conversation_id: conversationId, status: CONV_STATUS_ACTIVE }
  });
  if (!conversation) {
    return { error: { status: 404, code: 40491, message: "会话不存在" } };
  }
  if (String(conversation.peer_a) !== String(userId) && String(conversation.peer_b) !== String(userId)) {
    return { error: { status: 403, code: 40390, message: "无权访问该会话" } };
  }

  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.min(Number(query.size) || 30, 50);

  const { rows, count } = await ConversationMessage.findAndCountAll({
    where: { conversation_id: conversationId, status: 1 },
    include: [{ model: User, as: "sender", attributes: ["user_id", "nickname", "avatar", "current_role"] }],
    order: [["created_at", "DESC"]],
    offset: (page - 1) * size,
    limit: size
  });

  // 标记已读：把对方发来且未读的消息置 read_at
  await ConversationMessage.update(
    { read_at: new Date() },
    {
      where: {
        conversation_id: conversationId,
        sender_id: { [Op.ne]: userId },
        read_at: null
      }
    }
  );
  await clearConversationUnread(userId, conversation);

  return {
    total: count,
    page,
    size,
    list: rows.map(normalizeMessage)
  };
}

async function clearConversationUnread(userId, conversation) {
  const mineIsA = String(conversation.peer_a) === String(userId);
  const updates = mineIsA ? { unread_a: 0 } : { unread_b: 0 };
  await conversation.update(updates);
}

/**
 * 发送消息 → 落库 + 会话更新 + 在线 WS 推送 + 离线极光兜底
 */
async function sendConversationMessage(userId, conversationId, payload) {
  const content = String(payload.content || "").trim();
  if (!content) {
    return { error: { status: 400, code: 40091, message: "消息内容不能为空" } };
  }
  const type = Number(payload.type) === 2 ? 2 : 1;
  if (type === 2 && !/^https?:\/\//.test(content)) {
    return { error: { status: 400, code: 40091, message: "图片消息需传图片 URL" } };
  }

  const conversation = await Conversation.findOne({
    where: { conversation_id: conversationId, status: CONV_STATUS_ACTIVE }
  });

  if (!conversation) {
    return { error: { status: 404, code: 40491, message: "会话不存在" } };
  }
  if (String(conversation.peer_a) !== String(userId) && String(conversation.peer_b) !== String(userId)) {
    return { error: { status: 403, code: 40390, message: "无权在该会话发言" } };
  }

  const peerId = String(conversation.peer_a) === String(userId) ? conversation.peer_b : conversation.peer_a;

  const message = await ConversationMessage.create({
    message_id: generateId(),
    conversation_id: conversationId,
    sender_id: userId,
    type,
    content,
    read_at: null,
    status: 1
  });

  // 对方未读数 +1，更新最后一条
  const mineIsA = String(conversation.peer_a) === String(userId);
  await conversation.update({
    last_message_id: message.message_id,
    ...(mineIsA ? { unread_b: Number(conversation.unread_b || 0) + 1 } : { unread_a: Number(conversation.unread_a || 0) + 1 })
  });

  const row = await ConversationMessage.findByPk(message.message_id, {
    include: [{ model: User, as: "sender", attributes: ["user_id", "nickname", "avatar", "current_role"] }]
  });
  const data = normalizeMessage(row);

  // 实时推送：在线走 WS，离线走极光
  const sender = row.sender;
  wsHub.sendToUser(peerId, {
    event: "message",
    data: {
      ...data,
      conversation_id: String(conversationId)
    }
  });

  jpush.notifyUser(peerId, {
    title: (sender?.nickname || "艺启用户") + " 发来消息",
    content: type === 2 ? "[图片]" : content,
    extras: {
      type: "chat",
      conversation_id: String(conversationId),
      message_id: String(message.message_id)
    }
  });

  return { data };
}

/**
 * 通知列表
 */
async function listNotifications(userId, query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const size = Math.min(Number(query.size) || 20, 50);

  const where = { user_id: userId };
  if (query.type) {
    where.type = query.type;
  }

  const { rows, count } = await Notification.findAndCountAll({
    where,
    order: [["created_at", "DESC"]],
    offset: (page - 1) * size,
    limit: size
  });

  const unread = await Notification.count({
    where: { user_id: userId, is_read: false }
  });

  return {
    total: count,
    page,
    size,
    unread_total: unread,
    list: rows.map((row) => ({
      notification_id: String(row.notification_id),
      type: row.type,
      title: row.title,
      content: row.content,
      ref_type: row.ref_type,
      ref_id: row.ref_id,
      is_read: row.is_read,
      created_at: row.created_at
    }))
  };
}

async function markNotificationRead(userId, notificationId) {
  const notification = await Notification.findOne({
    where: { notification_id: notificationId, user_id: userId }
  });
  if (!notification) {
    return null;
  }
  await notification.update({ is_read: true });
  return { notification_id: String(notificationId), is_read: true };
}

async function markAllNotificationsRead(userId) {
  const updated = await Notification.update(
    { is_read: true },
    { where: { user_id: userId, is_read: false } }
  );
  return { updated: updated[0] || 0 };
}

/**
 * 创建系统通知（业务挂点调用：请假/退款/点赞/评论/消课）
 */
async function createNotification({ userId, type, title, content, refType, refId }) {
  if (!userId) return null;

  const notification = await Notification.create({
    notification_id: generateId(),
    user_id: userId,
    type,
    title,
    content,
    ref_type: refType || null,
    ref_id: refId ? String(refId) : null,
    is_read: false
  });

  wsHub.sendToUser(userId, {
    event: "notification",
    data: {
      notification_id: String(notification.notification_id),
      type,
      title,
      content,
      ref_type: refType || null,
      ref_id: refId ? String(refId) : null,
      is_read: false,
      created_at: notification.created_at
    }
  });

  jpush.notifyUser(userId, {
    title,
    content,
    extras: { type: "notification", notification_type: type, ref_id: refId ? String(refId) : null }
  });

  return notification;
}

/**
 * 上报极光设备（幂等：同一 registration_id 复用）
 */
async function registerDevice(userId, payload) {
  const registrationId = String(payload.registration_id || "").trim();
  if (!registrationId) {
    return { error: { status: 400, code: 40092, message: "registration_id 不能为空" } };
  }

  const existing = await UserDevice.findOne({ where: { registration_id: registrationId } });
  if (existing) {
    if (String(existing.user_id) !== String(userId) || Number(existing.status) !== 1) {
      await existing.update({ user_id: userId, status: 1 });
    }
    return { data: { device_id: String(existing.device_id), registered: true } };
  }

  const device = await UserDevice.create({
    device_id: generateId(),
    user_id: userId,
    registration_id: registrationId,
    platform: ["android", "ios", "h5"].includes(payload.platform) ? payload.platform : "android",
    status: 1
  });

  return { data: { device_id: String(device.device_id), registered: true } };
}

module.exports = {
  listConversations,
  createConversation,
  listConversationMessages,
  sendConversationMessage,
  listNotifications,
  markNotificationRead,
  markAllNotificationsRead,
  createNotification,
  registerDevice
};
