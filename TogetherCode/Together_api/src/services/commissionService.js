const crypto = require("crypto");
const { sequelize, DistributionLink, CommissionRecord, Wallet, Withdrawal, Order, Course, Post, StudioProfile, User } = require("../models");
const { generateId } = require("../utils/id");
const { createNotification } = require("./messageService");
const { PAY_METHODS, PAY_METHOD_TEXT, isOnlinePayMethod } = require("../utils/payMethods");

const DISTRIBUTE_MIN = 5;
const DISTRIBUTE_MAX = 15;

/*
 * 状态口径（线下资金模式，平台不碰钱）
 * CommissionRecord.status：1 待申请 / 2 已到账 / 3 申请中
 * Withdrawal.status：      0 待工作室审核 / 1 待推广人确认 / 2 已驳回 / 3 已完成
 * 闭环：推广人分享 → 新用户带码报名、工作室确认收款（生成待申请佣金）
 *      → 推广人按工作室发起领取（待工作室审核）
 *      → 工作室线下打款、登记方式/凭证（待推广人确认）
 *      → 推广人确认收到（佣金到账、计入累计收益）。
 */
const WITHDRAWAL_STATUS_TEXT = { 0: "待工作室审核", 1: "待我确认", 2: "已驳回", 3: "已完成" };
const STUDIO_WITHDRAWAL_STATUS_TEXT = { 0: "待审核", 1: "待推广人确认", 2: "已驳回", 3: "已完成" };
const COMMISSION_STATUS_TEXT = { 1: "待申请", 2: "已到账", 3: "申请中" };

function r2(n) {
  return Number(Number(n || 0).toFixed(2));
}
function yuanText(n) {
  return `¥${Number(n || 0).toFixed(2)}`;
}
function normalizeImages(value) {
  if (!Array.isArray(value)) return [];
  return value.map((v) => String(v || "").trim()).filter(Boolean);
}

function generateShareCode(userId, courseId) {
  const raw = `${userId}:${courseId}:${Date.now()}`;
  return crypto.createHash("md5").update(raw).digest("hex").slice(0, 16);
}

/**
 * 生成分享链接
 * body: { course_id, post_id? }
 */
async function createDistributionLink(userId, payload = {}) {
  const courseId = String(payload.course_id || "");
  if (!courseId) {
    return { error: { status: 400, code: 40071, message: "course_id 不能为空" } };
  }
  const course = await Course.findByPk(courseId);
  if (!course) {
    return { error: { status: 404, code: 40471, message: "课程不存在" } };
  }

  // 帖子分享返利：帖子必须存在、属于当前发帖人、且确实挂了该课程
  let postId = payload.post_id ? String(payload.post_id) : null;
  if (postId) {
    const post = await Post.findByPk(postId);
    if (!post || Number(post.status) !== 1) {
      return { error: { status: 404, code: 40472, message: "帖子不存在或已下架" } };
    }
    if (String(post.author_id) !== String(userId)) {
      return { error: { status: 403, code: 40371, message: "只能为本人发布的帖子生成分享码" } };
    }
    if (!post.course_id || String(post.course_id) !== courseId) {
      return { error: { status: 400, code: 40072, message: "该帖子未挂载此课程" } };
    }
  }

  const code = generateShareCode(userId, courseId);
  const link = await DistributionLink.create({
    link_id: generateId(),
    parent_user_id: userId,
    course_id: courseId,
    post_id: postId,
    code,
    status: 1
  });

  return {
    data: {
      link_id: String(link.link_id),
      code,
      share_url: postId
        ? `/pages/post-detail?id=${postId}&dist=${code}`
        : `/pages/course-detail?id=${courseId}&dist=${code}`,
      course: {
        course_id: String(course.course_id),
        title: course.title
      },
      post_id: postId || null
    }
  };
}

/**
 * 按分享码解析分销来源（下单时调用）
 */
async function resolveDistributionCode(code, transaction = null) {
  if (!code) {
    return null;
  }
  const link = await DistributionLink.findOne({ where: { code: String(code).trim(), status: 1 }, transaction });
  if (!link) {
    return null;
  }
  return link;
}

async function getOrCreateWallet(userId, transaction) {
  const existing = await Wallet.findByPk(userId, { transaction });
  if (existing) {
    return existing;
  }
  return Wallet.create({ user_id: userId }, { transaction });
}

/**
 * 工作室确认收款后结算返利：生成「待申请」佣金（钱仍在工作室，不入推广人钱包）。
 * @param {object} order 已收款订单实例（含 course_id、studio_id、total_amount、distribution_link_id）
 */
async function settleCommissionForOrder(order, { transaction } = {}) {
  const linkId = order.distribution_link_id;
  if (!linkId) {
    return null;
  }
  const link = await DistributionLink.findByPk(linkId, { transaction });
  if (!link) {
    return null;
  }
  // 防自购：分享人自己下单不返利
  if (String(link.parent_user_id) === String(order.user_id)) {
    return null;
  }

  const studio = await StudioProfile.findByPk(order.studio_id, { transaction });
  const rate = Number(studio?.distribute_rate || 5);
  // total_amount 单位分 → 元（÷100）后 × 返利比例（%），结果单位元
  const amount = r2((Number(order.total_amount || 0) / 100) * (rate / 100));
  if (amount <= 0) {
    return null;
  }

  const commission = await CommissionRecord.create(
    {
      commission_id: generateId(),
      link_id: link.link_id,
      order_id: order.order_id,
      parent_user_id: link.parent_user_id,
      studio_id: order.studio_id,
      rate,
      amount,
      status: 1, // 待申请
      settle_at: null
    },
    { transaction }
  );

  // 通知推广人：获得一笔待领取的分享奖励
  const course = await Course.findByPk(order.course_id, { transaction });
  createNotification({
    userId: link.parent_user_id,
    type: "commission",
    title: "获得分享奖励",
    content: `你分享的「${course?.title || "课程"}」有好友完成报名，获得 ¥${amount.toFixed(2)} 分享奖励，可在收益中心发起领取。`.slice(0, 120),
    refType: "course",
    refId: order.course_id
  }).catch(() => {});

  return commission;
}

/**
 * 收益中心概览（按工作室分组）
 */
async function getCommissionSummary(userId) {
  const wallet = await Wallet.findByPk(userId);
  const rows = await CommissionRecord.findAll({ where: { parent_user_id: userId } });

  const total = r2(rows.reduce((a, b) => a + Number(b.amount), 0));
  const sumStatus = (s) => r2(rows.filter((r) => Number(r.status) === s).reduce((a, b) => a + Number(b.amount), 0));
  const receivable = sumStatus(1); // 待申请
  const applying = sumStatus(3); // 申请中
  const settled = sumStatus(2); // 已到账

  const map = new Map();
  for (const r of rows) {
    const sid = String(r.studio_id);
    if (!map.has(sid)) map.set(sid, { studio_id: sid, receivable: 0, applying: 0, settled: 0, total: 0 });
    const g = map.get(sid);
    g.total = r2(g.total + Number(r.amount));
    if (Number(r.status) === 1) g.receivable = r2(g.receivable + Number(r.amount));
    else if (Number(r.status) === 3) g.applying = r2(g.applying + Number(r.amount));
    else if (Number(r.status) === 2) g.settled = r2(g.settled + Number(r.amount));
  }
  const studios = await Promise.all(
    [...map.values()].map(async (g) => {
      const s = await StudioProfile.findByPk(g.studio_id, { attributes: ["studio_id", "name", "cover"] });
      return { ...g, name: s?.name || "", cover: s?.cover || null };
    })
  );
  studios.sort((a, b) => b.receivable - a.receivable || b.total - a.total);

  return {
    data: {
      wallet: {
        balance: r2(wallet?.balance),
        frozen: r2(wallet?.frozen),
        withdrawn: r2(wallet?.withdrawn),
        debt: r2(wallet?.debt)
      },
      stats: {
        total_commission: total,
        receivable_commission: receivable,
        applying_commission: applying,
        settled_commission: settled
      },
      studios
    }
  };
}

/**
 * 返利明细
 */
async function listCommissionRecords(userId, query = {}) {
  const page = Number(query.page || 1);
  const pageSize = Number(query.page_size || 20);
  const where = { parent_user_id: userId };
  if (query.status) {
    where.status = Number(query.status);
  }
  if (query.studio_id) {
    where.studio_id = String(query.studio_id);
  }

  const { count, rows } = await CommissionRecord.findAndCountAll({
    where,
    order: [["created_at", "DESC"]],
    offset: (page - 1) * pageSize,
    limit: pageSize
  });

  const list = await Promise.all(
    rows.map(async (record) => {
      const link = await DistributionLink.findByPk(record.link_id, {
        include: [{ model: Course, as: "course", attributes: ["course_id", "title", "cover"] }]
      });
      const studio = await StudioProfile.findByPk(record.studio_id, {
        attributes: ["studio_id", "name", "cover"]
      });
      return {
        commission_id: String(record.commission_id),
        order_id: String(record.order_id),
        amount: Number(record.amount),
        rate: Number(record.rate),
        status: Number(record.status),
        status_text: COMMISSION_STATUS_TEXT[Number(record.status)] || "",
        settle_at: record.settle_at,
        created_at: record.created_at,
        studio: studio ? { studio_id: String(studio.studio_id), name: studio.name, cover: studio.cover } : null,
        course: link?.course
          ? { course_id: String(link.course.course_id), title: link.course.title, cover: link.course.cover }
          : null
      };
    })
  );

  return { data: { total: count, list, page, page_size: pageSize } };
}

/* ===================== 推广人：佣金领取（按工作室） ===================== */

function buildSteps(status) {
  // 0 提交领取 → 1 工作室审核打款 → 2 确认到账
  return [
    { title: "已提交领取", done: true, current: false },
    { title: "工作室审核打款", done: status >= 1, current: status === 0 },
    { title: "确认到账", done: status === 3, current: status === 1 }
  ];
}

function formatWithdrawal(row, { forStudio = false } = {}) {
  const status = Number(row.status);
  const textMap = forStudio ? STUDIO_WITHDRAWAL_STATUS_TEXT : WITHDRAWAL_STATUS_TEXT;
  return {
    withdraw_id: String(row.withdraw_id),
    user: row.user
      ? { user_id: String(row.user.user_id), nickname: row.user.nickname, phone: row.user.phone }
      : null,
    studio:
      row.studio || row.studio_id
        ? {
            studio_id: String(row.studio?.studio_id || row.studio_id),
            name: row.studio?.name || "",
            cover: row.studio?.cover || null
          }
        : null,
    amount: Number(row.amount),
    amount_text: yuanText(row.amount),
    method: row.method,
    method_text: PAY_METHOD_TEXT[row.method] || row.method,
    account: row.account || null,
    status,
    status_text: textMap[status] || "未知",
    voucher_images: Array.isArray(row.voucher_images) ? row.voucher_images : [],
    reject_reason: row.reject_reason || null,
    created_at: row.created_at,
    processed_at: row.processed_at || null,
    confirmed_at: row.confirmed_at || null,
    can_confirm: status === 1 && !forStudio,
    commissions: (row.commissions || []).map((c) => ({
      commission_id: String(c.commission_id),
      order_id: String(c.order_id),
      amount: Number(c.amount),
      rate: Number(c.rate),
      status: Number(c.status),
      status_text: COMMISSION_STATUS_TEXT[Number(c.status)] || "",
      created_at: c.created_at
    })),
    steps: buildSteps(status)
  };
}

async function loadWithdrawal(withdrawId, { transaction } = {}) {
  return Withdrawal.findByPk(withdrawId, {
    include: [
      { model: User, as: "user", attributes: ["user_id", "nickname", "phone"] },
      { model: StudioProfile, as: "studio", attributes: ["studio_id", "user_id", "name", "cover"] },
      { model: CommissionRecord, as: "commissions" }
    ],
    transaction
  });
}

/**
 * 发起领取：一次性领取某工作室名下全部「待申请」佣金。
 * body: { studio_id, method?, account? }
 */
async function requestStudioWithdraw(userId, payload = {}) {
  const studioId = payload.studio_id ? String(payload.studio_id) : "";
  if (!studioId) {
    return { error: { status: 400, code: 40072, message: "studio_id 不能为空" } };
  }
  const studio = await StudioProfile.findByPk(studioId);
  if (!studio) {
    return { error: { status: 404, code: 40410, message: "工作室不存在" } };
  }

  return sequelize.transaction(async (transaction) => {
    const commissions = await CommissionRecord.findAll({
      where: { parent_user_id: userId, studio_id: studioId, status: 1 },
      transaction,
      lock: transaction.LOCK.UPDATE,
      order: [["created_at", "ASC"]]
    });
    if (commissions.length === 0) {
      return { error: { status: 400, code: 40073, message: "该工作室暂无可领取佣金" } };
    }

    const amount = r2(commissions.reduce((a, c) => a + Number(c.amount), 0));
    const method = PAY_METHODS.includes(payload.method) ? payload.method : "wechat";
    const withdrawal = await Withdrawal.create(
      {
        withdraw_id: generateId(),
        user_id: userId,
        studio_id: studioId,
        amount,
        method,
        account: payload.account || null,
        status: 0 // 待工作室审核
      },
      { transaction }
    );
    await CommissionRecord.update(
      { status: 3, withdrawal_id: withdrawal.withdraw_id },
      { where: { commission_id: commissions.map((c) => c.commission_id) }, transaction }
    );

    const detail = await loadWithdrawal(withdrawal.withdraw_id, { transaction });
    return { data: formatWithdrawal(detail) };
  });
}

/**
 * 我的领取单列表
 */
async function listMyWithdrawals(userId, query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const pageSize = Number(query.page_size) === 0 ? 100000 : Math.min(100, Math.max(1, Number(query.page_size) || 20));
  const where = { user_id: userId };
  if (query.status !== undefined && query.status !== "") where.status = Number(query.status);

  const { count, rows } = await Withdrawal.findAndCountAll({
    where,
    order: [["created_at", "DESC"]],
    offset: (page - 1) * pageSize,
    limit: pageSize,
    include: [
      { model: StudioProfile, as: "studio", attributes: ["studio_id", "name", "cover"] },
      { model: CommissionRecord, as: "commissions", attributes: ["commission_id", "order_id", "amount", "rate", "status", "created_at"] }
    ]
  });

  return {
    data: { total: count, page, page_size: pageSize, list: rows.map((r) => formatWithdrawal(r)) }
  };
}

/**
 * 我的领取单详情
 */
async function getMyWithdrawalDetail(userId, withdrawId) {
  const row = await loadWithdrawal(withdrawId);
  if (!row) {
    return { error: { status: 404, code: 40495, message: "领取单不存在" } };
  }
  if (String(row.user_id) !== String(userId)) {
    return { error: { status: 403, code: 40395, message: "无权查看该领取单" } };
  }
  return { data: formatWithdrawal(row) };
}

/**
 * 推广人确认收到：待推广人确认（1）→ 已完成（3），佣金到账、计入累计收益。
 */
async function confirmWithdrawal(userId, withdrawId) {
  return sequelize.transaction(async (transaction) => {
    const row = await loadWithdrawal(withdrawId, { transaction });
    if (!row) {
      return { error: { status: 404, code: 40495, message: "领取单不存在" } };
    }
    if (String(row.user_id) !== String(userId)) {
      return { error: { status: 403, code: 40395, message: "无权操作该领取单" } };
    }
    if (Number(row.status) !== 1) {
      return { error: { status: 400, code: 40031, message: "该领取单当前无需你确认" } };
    }

    const amount = Number(row.amount);
    await Withdrawal.update(
      { status: 3, confirmed_at: new Date() },
      { where: { withdraw_id: row.withdraw_id }, transaction }
    );
    await CommissionRecord.update(
      { status: 2, settle_at: new Date() },
      { where: { withdrawal_id: row.withdraw_id }, transaction }
    );
    const wallet = await getOrCreateWallet(userId, transaction);
    await wallet.update({ withdrawn: r2(Number(wallet.withdrawn) + amount) }, { transaction });

    // 通知工作室：推广人已确认收到
    if (row.studio?.user_id) {
      createNotification({
        userId: row.studio.user_id,
        type: "commission",
        title: "推广人已确认收到佣金",
        content: `你审核的 ¥${amount.toFixed(2)} 佣金，推广人已确认收到。`,
        refType: "withdraw",
        refId: row.withdraw_id
      }).catch(() => {});
    }

    const latest = await loadWithdrawal(withdrawId, { transaction });
    return { data: formatWithdrawal(latest) };
  });
}

/* ===================== 工作室：佣金审核 / 打款 ===================== */

/**
 * 工作室佣金领取单列表
 */
async function listStudioWithdrawals(studioId, query = {}) {
  const page = Math.max(1, Number(query.page) || 1);
  const pageSize = Number(query.page_size) === 0 ? 100000 : Math.min(100, Math.max(1, Number(query.page_size) || 20));
  const where = { studio_id: studioId };
  if (query.status !== undefined && query.status !== "") where.status = Number(query.status);

  const { count, rows } = await Withdrawal.findAndCountAll({
    where,
    order: [["created_at", "DESC"]],
    offset: (page - 1) * pageSize,
    limit: pageSize,
    include: [
      { model: User, as: "user", attributes: ["user_id", "nickname", "phone"] },
      { model: CommissionRecord, as: "commissions", attributes: ["commission_id", "order_id", "amount", "rate", "status", "created_at"] }
    ]
  });

  return {
    data: { total: count, page, page_size: pageSize, list: rows.map((r) => formatWithdrawal(r, { forStudio: true })) }
  };
}

/**
 * 工作室审核领取单
 * action=approve：body { method, voucher_images }（线上必传凭证、现金免图）→ 待推广人确认（1）
 * action=reject： body { reject_reason } → 已驳回（2），佣金退回待申请
 */
async function reviewStudioWithdrawal(studioId, withdrawId, payload = {}, operator = {}) {
  const action = payload.action;
  if (!["approve", "reject"].includes(action)) {
    return { error: { status: 400, code: 40095, message: "action 仅支持 approve / reject" } };
  }

  return sequelize.transaction(async (transaction) => {
    const row = await loadWithdrawal(withdrawId, { transaction });
    if (!row || String(row.studio_id) !== String(studioId)) {
      return null;
    }
    const status = Number(row.status);

    if (action === "reject") {
      if (status !== 0 && status !== 1) {
        return { error: { status: 400, code: 40095, message: "该领取单已处理，不可驳回" } };
      }
      const reason = String(payload.reject_reason || payload.reason || "").trim();
      await Withdrawal.update(
        {
          status: 2,
          reject_reason: reason || "工作室未通过该领取申请",
          processed_by: operator.adminId || null,
          processed_at: new Date()
        },
        { where: { withdraw_id: row.withdraw_id }, transaction }
      );
      // 佣金退回待申请
      await CommissionRecord.update(
        { status: 1, withdrawal_id: null },
        { where: { withdrawal_id: row.withdraw_id }, transaction }
      );
      createNotification({
        userId: row.user_id,
        type: "commission",
        title: "佣金领取申请已驳回",
        content: `你申请领取的 ¥${Number(row.amount).toFixed(2)} 佣金未通过：${reason || "请与工作室联系"}`.slice(0, 120),
        refType: "withdraw",
        refId: row.withdraw_id
      }).catch(() => {});

      const latest = await loadWithdrawal(withdrawId, { transaction });
      return formatWithdrawal(latest, { forStudio: true });
    }

    // approve：仅待审核（0）可通过
    if (status !== 0) {
      return { error: { status: 400, code: 40095, message: "仅待审核的领取单可通过" } };
    }
    const method = String(payload.method || row.method || "").trim();
    if (!PAY_METHODS.includes(method)) {
      return { error: { status: 400, code: 40095, message: "请选择打款方式" } };
    }
    const vouchers = normalizeImages(payload.voucher_images);
    if (isOnlinePayMethod(method) && vouchers.length === 0) {
      return { error: { status: 400, code: 40095, message: "线上打款请上传打款凭证" } };
    }

    await Withdrawal.update(
      {
        status: 1,
        method,
        voucher_images: vouchers,
        processed_by: operator.adminId || null,
        processed_at: new Date()
      },
      { where: { withdraw_id: row.withdraw_id }, transaction }
    );
    createNotification({
      userId: row.user_id,
      type: "commission",
      title: "佣金已打款，待你确认",
      content: `你申请领取的 ¥${Number(row.amount).toFixed(2)} 佣金工作室已线下打款，请核对凭证并确认收到。`.slice(0, 120),
      refType: "withdraw",
      refId: row.withdraw_id
    }).catch(() => {});

    const latest = await loadWithdrawal(withdrawId, { transaction });
    return formatWithdrawal(latest, { forStudio: true });
  });
}

/**
 * 工作室设置返利比例（5%-15%）
 */
async function setStudioDistributeRate(studioId, rate) {
  const value = Number(rate);
  if (!(value >= DISTRIBUTE_MIN && value <= DISTRIBUTE_MAX)) {
    return { error: { status: 400, code: 40074, message: `返利比例需在 ${DISTRIBUTE_MIN}%-${DISTRIBUTE_MAX}% 之间` } };
  }
  const studio = await StudioProfile.findByPk(studioId);
  if (!studio) {
    return { error: { status: 404, code: 40410, message: "工作室不存在" } };
  }
  await studio.update({ distribute_rate: value });
  return { data: { studio_id: String(studio.studio_id), distribute_rate: Number(value) } };
}

module.exports = {
  createDistributionLink,
  resolveDistributionCode,
  settleCommissionForOrder,
  getCommissionSummary,
  listCommissionRecords,
  requestStudioWithdraw,
  listMyWithdrawals,
  getMyWithdrawalDetail,
  confirmWithdrawal,
  listStudioWithdrawals,
  reviewStudioWithdrawal,
  setStudioDistributeRate,
  DISTRIBUTE_MIN,
  DISTRIBUTE_MAX
};
