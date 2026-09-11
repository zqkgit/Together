const { Op } = require("sequelize");
const bcrypt = require("bcryptjs");
const { sequelize, Report, AuditLog, PlatformConfig, Announcement, AdminAccount, Post, Settlement, User, Withdrawal, Wallet } = require("../models");
const { generateId } = require("../utils/id");

/**
 * 平台侧治理补缺：
 *  - GET  /admin/platform/reports                    举报处置列表
 *  - PUT  /admin/platform/reports/:id                处理举报
 *  - PUT  /admin/platform/posts/:id/moderate         内容下架 / 恢复
 *  - POST /admin/platform/settlements/:id/reprocess  结算异常重打
 *  - GET  /admin/platform/config                     读取平台配置
 *  - PUT  /admin/platform/config                     更新平台配置
 *  - GET  /admin/platform/announcements              公告列表
 *  - POST /admin/platform/announcements              发布公告 / Banner
 *  - POST /admin/platform/staff                      新增平台员工
 *  - GET  /admin/platform/audit                      全平台审计日志
 */

const REPORT_STATUS = { 0: "待处理", 1: "已处理", 2: "已驳回" };

async function listReports(query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const pageSize = Math.min(100, Math.max(1, Number(query.page_size) || 20));
  const where = {};
  if (query.status !== undefined && query.status !== "") where.status = Number(query.status);
  if (query.target_type) where.target_type = query.target_type;

  const { count, rows } = await Report.findAndCountAll({
    where,
    order: [["created_at", "DESC"]],
    offset: (page - 1) * pageSize,
    limit: pageSize,
    include: [{ model: require("../models").User, as: "reporter", attributes: ["user_id", "nickname", "phone"] }]
  });
  return {
    total: count,
    page,
    page_size: pageSize,
    list: rows.map((r) => ({
      report_id: String(r.report_id),
      reporter: r.reporter
        ? { user_id: String(r.reporter.user_id), nickname: r.reporter.nickname, phone: r.reporter.phone }
        : null,
      target_type: r.target_type,
      target_id: r.target_id,
      reason: r.reason,
      detail: r.detail,
      images: r.images || [],
      status: Number(r.status),
      status_text: REPORT_STATUS[Number(r.status)],
      handle_note: r.handle_note,
      handled_at: r.handled_at,
      created_at: r.created_at
    }))
  };
}

async function handleReport(reportId, admin, payload = {}) {
  const report = await Report.findByPk(reportId);
  if (!report) {
    return { error: { status: 404, code: 40490, message: "举报不存在" } };
  }
  if (Number(report.status) !== 0) {
    return { error: { status: 400, code: 40090, message: "该举报已处理" } };
  }
  const status = Number(payload.status);
  if (![1, 2].includes(status)) {
    return { error: { status: 400, code: 40091, message: "status 仅支持 1(已处理) / 2(已驳回)" } };
  }
  await report.update({
    status,
    handled_by: admin.admin_id,
    handle_note: payload.handle_note ? String(payload.handle_note).slice(0, 255) : null,
    handled_at: new Date()
  });
  return { data: { report_id: String(report.report_id), status }, message: status === 1 ? "举报已处理" : "举报已驳回" };
}

/**
 * 内容下架 / 恢复：posts.status 1 上架 / 0 下架。
 */
async function moderatePost(postId, admin, payload = {}) {
  const post = await Post.findByPk(postId);
  if (!post) {
    return { error: { status: 404, code: 40492, message: "帖子不存在" } };
  }
  const status = Number(payload.status);
  if (![0, 1].includes(status)) {
    return { error: { status: 400, code: 40092, message: "status 仅支持 0(下架) / 1(恢复)" } };
  }
  if (Number(post.status) === status) {
    return { error: { status: 400, code: 40093, message: status === 0 ? "帖子已在下架状态" : "帖子已在正常状态" } };
  }
  await post.update({ status });
  return { data: { post_id: String(post.post_id), status }, message: status === 0 ? "内容已下架" : "内容已恢复" };
}

/**
 * 结算异常重打：status 3(异常待复核) -> 0(待结算)。
 */
async function reprocessSettlement(settlementId, admin) {
  const row = await Settlement.findByPk(settlementId);
  if (!row) {
    return { error: { status: 404, code: 40494, message: "结算单不存在" } };
  }
  if (Number(row.status) !== 3) {
    return { error: { status: 400, code: 40094, message: "仅异常待复核的结算单可重打" } };
  }
  await row.update({ status: 0, operator_id: admin.admin_id });
  return { data: { settlement_id: String(row.settlement_id), status: 0 }, message: "已重置为待结算，可重新打款" };
}

async function getPlatformConfig() {
  const rows = await PlatformConfig.findAll({ order: [["config_key", "ASC"]] });
  const map = {};
  rows.forEach((r) => {
    try {
      map[r.config_key] = JSON.parse(r.config_value);
    } catch {
      map[r.config_key] = r.config_value;
    }
  });
  return { configs: map, list: rows.map((r) => ({ config_key: r.config_key, description: r.description })) };
}

async function updatePlatformConfig(admin, payload = {}) {
  const updates = [];
  for (const [key, value] of Object.entries(payload)) {
    if (!key || key.startsWith("_")) continue;
    const existing = await PlatformConfig.findOne({ where: { config_key: key } });
    const text = typeof value === "string" ? value : JSON.stringify(value);
    if (existing) {
      await existing.update({ config_value: text, updated_by: admin.admin_id });
    } else {
      await PlatformConfig.create({ config_id: generateId(), config_key: key, config_value: text, updated_by: admin.admin_id });
    }
    updates.push(key);
  }
  return { data: { updated: updates }, message: `已更新 ${updates.length} 项配置` };
}

async function listAnnouncements(query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const pageSize = Math.min(100, Math.max(1, Number(query.page_size) || 20));
  const where = {};
  if (query.status !== undefined && query.status !== "") where.status = Number(query.status);
  if (query.type) where.type = Number(query.type);

  const { count, rows } = await Announcement.findAndCountAll({
    where,
    order: [["created_at", "DESC"]],
    offset: (page - 1) * pageSize,
    limit: pageSize
  });
  return {
    total: count,
    page,
    page_size: pageSize,
    list: rows.map((r) => ({
      announcement_id: String(r.announcement_id),
      title: r.title,
      content: r.content,
      type: Number(r.type),
      image: r.image || [],
      link: r.link,
      status: Number(r.status),
      publish_at: r.publish_at,
      expire_at: r.expire_at,
      created_at: r.created_at
    }))
  };
}

async function createAnnouncement(admin, payload = {}) {
  const title = String(payload.title || "").trim();
  if (!title) {
    return { error: { status: 400, code: 40095, message: "标题不能为空" } };
  }
  const type = [1, 2].includes(Number(payload.type)) ? Number(payload.type) : 1;
  const created = await Announcement.create({
    announcement_id: generateId(),
    title,
    content: payload.content ? String(payload.content) : null,
    type,
    image: Array.isArray(payload.image) ? payload.image.slice(0, 9) : [],
    link: payload.link ? String(payload.link) : null,
    status: payload.status !== undefined ? Number(payload.status) : 1,
    publish_at: payload.publish_at ? new Date(payload.publish_at) : new Date(),
    expire_at: payload.expire_at ? new Date(payload.expire_at) : null,
    created_by: admin.admin_id
  });
  return { data: { announcement_id: String(created.announcement_id) }, message: type === 1 ? "公告已发布" : "Banner 已发布" };
}

/**
 * 新增平台员工（platform_super 专属）。
 */
async function createPlatformStaff(admin, payload = {}) {
  const username = String(payload.username || "").trim();
  const password = String(payload.password || "");
  if (!username || !password) {
    return { error: { status: 400, code: 40096, message: "用户名与密码不能为空" } };
  }
  if (password.length < 6) {
    return { error: { status: 400, code: 40097, message: "密码至少 6 位" } };
  }
  const exists = await AdminAccount.findOne({ where: { username } });
  if (exists) {
    return { error: { status: 400, code: 40098, message: "用户名已存在" } };
  }
  // 内部账号同步创建 User（无手机号），供后台登录的 refresh token 机制使用
  const internalUser = await User.create({
    user_id: generateId(),
    phone: null,
    nickname: payload.name || username,
    current_role: 1,
    status: 1
  });
  const created = await AdminAccount.create({
    admin_id: generateId(),
    user_id: internalUser.user_id,
    username,
    password_hash: bcrypt.hashSync(password, 10),
    role: "platform_ops",
    studio_id: null,
    status: 1
  });
  return { data: { admin_id: String(created.admin_id), username }, message: `平台员工 ${username} 已创建` };
}

async function listPlatformAudit(query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const pageSize = Math.min(100, Math.max(1, Number(query.page_size) || 20));
  const where = { role: { [Op.in]: ["platform_super", "platform_ops"] } };
  if (query.action) where.action = query.action;
  if (query.actor_name) where.actor_name = { [Op.like]: `%${query.actor_name}%` };
  if (query.target_type) where.target_type = query.target_type;

  const { count, rows } = await AuditLog.findAndCountAll({
    where,
    order: [["created_at", "DESC"]],
    offset: (page - 1) * pageSize,
    limit: pageSize
  });
  return {
    total: count,
    page,
    page_size: pageSize,
    list: rows.map((r) => ({
      log_id: String(r.log_id),
      actor_name: r.actor_name,
      role: r.role,
      action: r.action,
      target_type: r.target_type,
      target_id: r.target_id,
      detail: r.detail,
      ip: r.ip,
      created_at: r.created_at
    }))
  };
}

/**
 * 平台帖子列表（内容管理页使用：分页 / 状态 / 关键词过滤）。
 */
async function listPosts(query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const pageSize = Math.min(100, Math.max(1, Number(query.page_size) || 20));
  const where = {};
  if (query.status !== undefined && query.status !== "") where.status = Number(query.status);
  if (query.q) where.content = { [Op.like]: `%${query.q}%` };

  const { count, rows } = await Post.findAndCountAll({
    where,
    order: [["created_at", "DESC"]],
    offset: (page - 1) * pageSize,
    limit: pageSize,
    include: [
      { model: require("../models").User, as: "author", attributes: ["user_id", "nickname", "phone"] },
      { model: require("../models").Course, as: "course", attributes: ["course_id", "title"] }
    ]
  });
  return {
    total: count,
    page,
    page_size: pageSize,
    list: rows.map((r) => ({
      post_id: String(r.post_id),
      author: r.author
        ? { user_id: String(r.author.user_id), nickname: r.author.nickname, phone: r.author.phone }
        : null,
      course: r.course ? { course_id: String(r.course.course_id), title: r.course.title } : null,
      content: r.content,
      images: r.images || [],
      like_count: Number(r.like_count),
      comment_count: Number(r.comment_count),
      share_count: Number(r.share_count),
      status: Number(r.status),
      visibility: Number(r.visibility),
      created_at: r.created_at
    }))
  };
}

/**
 * 平台员工列表（admin_accounts 中 platform 角色）。
 */
async function listPlatformStaff(query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const pageSize = Math.min(100, Math.max(1, Number(query.page_size) || 20));
  const where = { role: { [Op.in]: ["platform_super", "platform_ops"] } };
  if (query.q) where.username = { [Op.like]: `%${query.q}%` };

  const { count, rows } = await AdminAccount.findAndCountAll({
    where,
    order: [["created_at", "ASC"]],
    offset: (page - 1) * pageSize,
    limit: pageSize
  });
  return {
    total: count,
    page,
    page_size: pageSize,
    list: rows.map((r) => ({
      admin_id: String(r.admin_id),
      username: r.username,
      role: r.role,
      status: Number(r.status),
      created_at: r.created_at
    }))
  };
}

/**
 * 员工账号启用 / 停用（平台侧管理平台员工）。
 */
async function updateAdminStaffStatus(staffId, admin, payload = {}) {
  const account = await AdminAccount.findByPk(staffId);
  if (!account || !["platform_ops", "platform_super"].includes(account.role)) {
    return { error: { status: 404, code: 40498, message: "员工账号不存在" } };
  }
  if (String(account.admin_id) === String(admin.admin_id)) {
    return { error: { status: 400, code: 40099, message: "不能停用自己的账号" } };
  }
  const status = Number(payload.status);
  if (![0, 1].includes(status)) {
    return { error: { status: 400, code: 40099, message: "status 仅支持 0(停用) / 1(启用)" } };
  }
  await account.update({ status });
  return { data: { admin_id: String(account.admin_id), status }, message: status === 1 ? "账号已启用" : "账号已停用" };
}

/**
 * 公告 / Banner 上下架。
 */
async function updateAnnouncementStatus(id, payload = {}) {
  const row = await Announcement.findByPk(id);
  if (!row) {
    return { error: { status: 404, code: 40499, message: "公告不存在" } };
  }
  const status = Number(payload.status);
  if (![0, 1].includes(status)) {
    return { error: { status: 400, code: 40099, message: "status 仅支持 0(下架) / 1(上架)" } };
  }
  await row.update({ status });
  return { data: { announcement_id: String(row.announcement_id), status }, message: status === 1 ? "公告已上架" : "公告已下架" };
}

/**
 * 提现单列表（平台审核用）：分页 / 状态筛选。
 */
async function listWithdrawals(query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const pageSize = Math.min(100, Math.max(1, Number(query.page_size) || 20));
  const where = {};
  if (query.status !== undefined && query.status !== "") where.status = Number(query.status);

  const { count, rows } = await Withdrawal.findAndCountAll({
    where,
    order: [["created_at", "DESC"]],
    offset: (page - 1) * pageSize,
    limit: pageSize,
    include: [{ model: User, as: "user", attributes: ["user_id", "nickname", "phone"] }]
  });
  return {
    total: count,
    page,
    page_size: pageSize,
    list: rows.map((r) => ({
      withdraw_id: String(r.withdraw_id),
      user: r.user
        ? { user_id: String(r.user.user_id), nickname: r.user.nickname, phone: r.user.phone }
        : null,
      amount: Number(r.amount),
      method: r.method,
      account: r.account,
      status: Number(r.status),
      status_text: WITHDRAW_STATUS_TEXT[Number(r.status)] || "未知",
      created_at: r.created_at,
      reviewed_at: r.reviewed_at
    }))
  };
}

const WITHDRAW_STATUS_TEXT = {
  1: "待审核",
  2: "处理中",
  3: "已打款",
  4: "已驳回"
};

/**
 * 提现审核：通过 → 3 已打款（frozen 转 withdrawn）；驳回 → 4 已驳回（frozen 解冻回余额）。
 */
async function reviewWithdrawal(withdrawId, payload = {}) {
  const action = payload.action;
  if (!["approve", "reject"].includes(action)) {
    return { error: { status: 400, code: 40095, message: "action 仅支持 approve / reject" } };
  }
  const row = await Withdrawal.findByPk(withdrawId);
  if (!row) {
    return { error: { status: 404, code: 40495, message: "提现单不存在" } };
  }
  if (Number(row.status) !== 1) {
    return { error: { status: 400, code: 40095, message: "仅待审核的提现单可处理" } };
  }

  await sequelize.transaction(async (transaction) => {
    const wallet = await Wallet.findByPk(row.user_id, { transaction, lock: transaction.LOCK.UPDATE });
    const frozen = Number(wallet?.frozen || 0);
    const amount = Number(row.amount);
    const nextFrozen = Math.max(Number((frozen - amount).toFixed(2)), 0);

    if (action === "approve") {
      await Withdrawal.update(
        { status: 3, reviewed_at: new Date() },
        { where: { withdraw_id: row.withdraw_id }, transaction }
      );
      if (wallet) {
        await wallet.update(
          {
            frozen: nextFrozen,
            withdrawn: Number((Number(wallet.withdrawn || 0) + amount).toFixed(2))
          },
          { transaction }
        );
      }
    } else {
      await Withdrawal.update(
        { status: 4, reviewed_at: new Date() },
        { where: { withdraw_id: row.withdraw_id }, transaction }
      );
      if (wallet) {
        await wallet.update(
          {
            frozen: nextFrozen,
            balance: Number((Number(wallet.balance || 0) + amount).toFixed(2))
          },
          { transaction }
        );
      }
    }
  });

  return {
    data: {
      withdraw_id: String(row.withdraw_id),
      status: action === "approve" ? 3 : 4,
      status_text: action === "approve" ? "已打款" : "已驳回"
    },
    message: action === "approve" ? "提现已通过并标记打款" : "提现已驳回，金额已退回余额"
  };
}

module.exports = {
  listReports,
  handleReport,
  moderatePost,
  reprocessSettlement,
  getPlatformConfig,
  updatePlatformConfig,
  listAnnouncements,
  createAnnouncement,
  createPlatformStaff,
  listPlatformAudit,
  listPosts,
  listPlatformStaff,
  updateAdminStaffStatus,
  updateAnnouncementStatus,
  listWithdrawals,
  reviewWithdrawal
};
