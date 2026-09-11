const { Op } = require("sequelize");
const bcrypt = require("bcryptjs");
const { sequelize, StudioAccount, AuditLog, AdminAccount, User } = require("../models");
const { generateId } = require("../utils/id");

/**
 * 工作室侧治理补缺：
 *  - GET  /studio/finance   财务对账（营收 / 退款 / 分销）
 *  - GET  /studio/accounts  结算账户列表
 *  - POST /studio/accounts  绑定结算账户
 *  - GET  /studio/audit     本店操作审计
 *  - POST /studio/staff     新增员工账号（owner）
 */

/**
 * 工作室财务对账。
 * 金额单位：分。统计区间：默认本月（可传 start_date / end_date）。
 */
async function getStudioFinance(studioId, query = {}) {
  const now = new Date();
  const defaultStart = new Date(now.getFullYear(), now.getMonth(), 1);
  const start = query.start_date ? new Date(`${query.start_date}T00:00:00`) : defaultStart;
  const end = query.end_date ? new Date(`${query.end_date}T23:59:59`) : new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59);

  const where = { studio_id: studioId, status: { [Op.ne]: 0 } };
  const rangeWhere = { ...where, created_at: { [Op.between]: [start, end] } };

  const [totalGmv, rangeGmv, totalRefund, rangeRefund, distRows, orderRows] = await Promise.all([
    // 累计营收（已支付订单）
    sequelize.query(
      `SELECT COALESCE(SUM(total_amount),0) AS total FROM orders WHERE studio_id = ? AND status <> 0`,
      { replacements: [studioId], type: sequelize.QueryTypes.SELECT }
    ),
    // 区间营收
    sequelize.query(
      `SELECT COALESCE(SUM(total_amount),0) AS total FROM orders WHERE studio_id = ? AND status <> 0 AND created_at BETWEEN ? AND ?`,
      { replacements: [studioId, start, end], type: sequelize.QueryTypes.SELECT }
    ),
    // 累计退款（已通过）
    sequelize.query(
      `SELECT COALESCE(SUM(r.amount),0) AS total FROM refunds r JOIN orders o ON o.order_id = r.order_id WHERE o.studio_id = ? AND r.status IN (2,3)`,
      { replacements: [studioId], type: sequelize.QueryTypes.SELECT }
    ),
    // 区间退款
    sequelize.query(
      `SELECT COALESCE(SUM(r.amount),0) AS total FROM refunds r JOIN orders o ON o.order_id = r.order_id WHERE o.studio_id = ? AND r.status IN (2,3) AND r.reviewed_at BETWEEN ? AND ?`,
      { replacements: [studioId, start, end], type: sequelize.QueryTypes.SELECT }
    ),
    // 分销支出：返利记录 → 分享链接 → 课程 → 工作室
    sequelize.query(
      `SELECT COALESCE(SUM(c.amount),0) AS total FROM commission_records c
         JOIN distribution_links l ON l.link_id = c.link_id
         JOIN courses cu ON cu.course_id = l.course_id
         WHERE cu.studio_id = ? AND c.status = 2`,
      { replacements: [studioId], type: sequelize.QueryTypes.SELECT }
    ),
    // 订单明细（区间）
    sequelize.query(
      `SELECT order_id, order_no, total_amount, status, paid_at FROM orders
         WHERE studio_id = ? AND status <> 0 AND created_at BETWEEN ? AND ? ORDER BY created_at DESC LIMIT 50`,
      { replacements: [studioId, start, end], type: sequelize.QueryTypes.SELECT }
    )
  ]);

  const totalGmvN = Number(totalGmv[0]?.total || 0);
  const rangeGmvN = Number(rangeGmv[0]?.total || 0);
  const totalRefundN = Number(totalRefund[0]?.total || 0);
  const rangeRefundN = Number(rangeRefund[0]?.total || 0);
  const distributionTotal = Number(distRows[0]?.total || 0);

  return {
    period: { start_date: start.toISOString().slice(0, 10), end_date: end.toISOString().slice(0, 10) },
    summary: {
      gmv_total: totalGmvN,
      gmv_period: rangeGmvN,
      refund_total: totalRefundN,
      refund_period: rangeRefundN,
      distribution_total: distributionTotal,
      net_total: totalGmvN - totalRefundN - distributionTotal,
      net_period: rangeGmvN - rangeRefundN
    },
    orders: orderRows.map((r) => ({
      order_id: String(r.order_id),
      order_no: r.order_no,
      total_amount: Number(r.total_amount),
      status: Number(r.status),
      paid_at: r.paid_at
    }))
  };
}

async function listStudioAccounts(studioId) {
  const rows = await StudioAccount.findAll({
    where: { studio_id: studioId, status: 1 },
    order: [["is_default", "DESC"], ["created_at", "DESC"]]
  });
  return {
    total: rows.length,
    list: rows.map((r) => ({
      account_id: String(r.account_id),
      account_type: r.account_type,
      account_name: r.account_name,
      account_no: r.account_no,
      bank_name: r.bank_name,
      is_default: Number(r.is_default),
      status: Number(r.status)
    }))
  };
}

async function upsertStudioAccount(studioId, payload) {
  const accountType = ["bank", "wechat", "alipay"].includes(payload.account_type) ? payload.account_type : "bank";
  const accountName = String(payload.account_name || "").trim();
  const accountNo = String(payload.account_no || "").trim();
  if (!accountName || !accountNo) {
    return { error: { status: 400, code: 40080, message: "账户名与账号不能为空" } };
  }

  const existing = payload.account_id
    ? await StudioAccount.findOne({ where: { account_id: payload.account_id, studio_id: studioId } })
    : null;
  if (existing) {
    await existing.update({
      account_type: accountType,
      account_name: accountName,
      account_no: accountNo,
      bank_name: payload.bank_name ? String(payload.bank_name) : existing.bank_name,
      is_default: payload.is_default !== undefined ? Number(payload.is_default) : existing.is_default
    });
    return { data: { account_id: String(existing.account_id) }, message: "结算账户已更新" };
  }

  // 首个账户自动设为默认
  const count = await StudioAccount.count({ where: { studio_id: studioId, status: 1 } });
  const created = await StudioAccount.create({
    account_id: generateId(),
    studio_id: studioId,
    account_type: accountType,
    account_name: accountName,
    account_no: accountNo,
    bank_name: payload.bank_name ? String(payload.bank_name) : null,
    is_default: count === 0 ? 1 : payload.is_default !== undefined ? Number(payload.is_default) : 0,
    status: 1
  });
  return { data: { account_id: String(created.account_id) }, message: "结算账户已绑定" };
}

async function listStudioAudit(studioId, query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const pageSize = Math.min(100, Math.max(1, Number(query.page_size) || 20));
  const where = { studio_id: studioId };
  if (query.action) where.action = query.action;

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
 * 新增工作室员工账号（owner 专属）。
 * 复用 admin_accounts：role = studio_ops，studio_id 归属。
 */
async function createStudioStaff(studioId, payload) {
  const username = String(payload.username || "").trim();
  const password = String(payload.password || "");
  const name = String(payload.name || "").trim();
  if (!username || !password) {
    return { error: { status: 400, code: 40081, message: "用户名与密码不能为空" } };
  }
  if (password.length < 6) {
    return { error: { status: 400, code: 40082, message: "密码至少 6 位" } };
  }
  const exists = await AdminAccount.findOne({ where: { username } });
  if (exists) {
    return { error: { status: 400, code: 40083, message: "用户名已存在" } };
  }
  // 内部账号同步创建 User（无手机号），供后台登录的 refresh token 机制使用
  const internalUser = await User.create({
    user_id: generateId(),
    phone: null,
    nickname: name || username,
    current_role: 1,
    status: 1
  });
  const created = await AdminAccount.create({
    admin_id: generateId(),
    user_id: internalUser.user_id,
    username,
    password_hash: bcrypt.hashSync(password, 10),
    role: "studio_ops",
    studio_id: studioId,
    status: 1
  });
  return { data: { admin_id: String(created.admin_id), username }, message: `员工账号 ${name || username} 已创建` };
}

/**
 * 本店员工列表（studio_owner / studio_ops）。
 */
async function listStudioStaff(studioId, query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const pageSize = Math.min(100, Math.max(1, Number(query.page_size) || 20));
  const where = { studio_id: studioId, role: { [Op.in]: ["studio_owner", "studio_ops"] } };
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
 * 本店员工启用 / 停用（owner 专属；不能停用 owner 自己）。
 */
async function updateStudioStaffStatus(staffId, studioId, admin, payload = {}) {
  const account = await AdminAccount.findOne({ where: { admin_id: staffId, studio_id: studioId } });
  if (!account || !["studio_owner", "studio_ops"].includes(account.role)) {
    return { error: { status: 404, code: 40483, message: "员工账号不存在" } };
  }
  if (String(account.admin_id) === String(admin.admin_id)) {
    return { error: { status: 400, code: 40084, message: "不能停用自己的账号" } };
  }
  const status = Number(payload.status);
  if (![0, 1].includes(status)) {
    return { error: { status: 400, code: 40084, message: "status 仅支持 0(停用) / 1(启用)" } };
  }
  await account.update({ status });
  return { data: { admin_id: String(account.admin_id), status }, message: status === 1 ? "账号已启用" : "账号已停用" };
}

module.exports = {
  getStudioFinance,
  listStudioAccounts,
  upsertStudioAccount,
  listStudioAudit,
  createStudioStaff,
  listStudioStaff,
  updateStudioStaffStatus
};
