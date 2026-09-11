const crypto = require("crypto");
const { sequelize, DistributionLink, CommissionRecord, Wallet, Withdrawal, Order, Course, Post, StudioProfile, User } = require("../models");
const { generateId } = require("../utils/id");

const DISTRIBUTE_MIN = 5;
const DISTRIBUTE_MAX = 15;

/**
 * 分销返利 / 钱包
 * 闭环：家长生成分享链接(code) → 新用户带码下单 → 支付成功后按当时 distribute_rate 记返利 → 家长钱包到账 → 提现申请。
 */

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
async function resolveDistributionCode(code) {
  if (!code) {
    return null;
  }
  const link = await DistributionLink.findOne({ where: { code: String(code).trim(), status: 1 } });
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
 * 支付成功后结算返利（orderService 在事务内调用）
 * @param {object} order 已支付订单实例（含 course_id、studio_id、total_amount）
 * @param {object} options { transaction, settleImmediately? }
 */
async function settleCommissionForOrder(order, { transaction, settleImmediately = false } = {}) {
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
  const amount = Number((Number(order.total_amount || 0) * rate) / 100).toFixed(2);

  if (Number(amount) <= 0) {
    return null;
  }

  const commission = await CommissionRecord.create(
    {
      commission_id: generateId(),
      link_id: link.link_id,
      order_id: order.order_id,
      parent_user_id: link.parent_user_id,
      rate,
      amount,
      status: settleImmediately ? 2 : 1,
      settle_at: settleImmediately ? new Date() : null
    },
    { transaction }
  );

  if (settleImmediately) {
    const wallet = await getOrCreateWallet(link.parent_user_id, transaction);
    const debt = Number(wallet.debt || 0);
    const credit = Number(amount);
    if (debt > 0) {
      // 先抵欠款
      const payDebt = Math.min(debt, credit);
      await wallet.update(
        {
          debt: Number((debt - payDebt).toFixed(2)),
          balance: Number((Number(wallet.balance || 0) + (credit - payDebt)).toFixed(2))
        },
        { transaction }
      );
    } else {
      await wallet.update(
        { balance: Number((Number(wallet.balance || 0) + credit).toFixed(2)) },
        { transaction }
      );
    }
  }

  return commission;
}

/**
 * 收益中心概览
 */
async function getCommissionSummary(userId) {
  const wallet = await Wallet.findByPk(userId);
  const total = await CommissionRecord.sum("amount", { where: { parent_user_id: userId } });
  const settled = await CommissionRecord.sum("amount", {
    where: { parent_user_id: userId, status: 2 }
  });
  const pending = await CommissionRecord.sum("amount", {
    where: { parent_user_id: userId, status: 1 }
  });
  const totalWithdrawn = await Withdrawal.sum("amount", {
    where: { user_id: userId, status: { [require("sequelize").Op.in]: [2, 3] } }
  });

  return {
    data: {
      wallet: {
        balance: Number(wallet?.balance || 0),
        frozen: Number(wallet?.frozen || 0),
        withdrawn: Number(wallet?.withdrawn || 0),
        debt: Number(wallet?.debt || 0)
      },
      stats: {
        total_commission: Number(total || 0),
        settled_commission: Number(settled || 0),
        pending_commission: Number(pending || 0),
        total_withdrawn: Number(totalWithdrawn || 0)
      },
      withdrawable: Number((Number(wallet?.balance || 0) - Number(wallet?.frozen || 0)).toFixed(2))
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

  const { count, rows } = await CommissionRecord.findAndCountAll({
    where,
    order: [["created_at", "DESC"]],
    offset: (page - 1) * pageSize,
    limit: pageSize
  });

  // CommissionRecord 没有直接关联 course，通过 link 拿课程信息
  const list = await Promise.all(
    rows.map(async (record) => {
      const link = await DistributionLink.findByPk(record.link_id, {
        include: [
          { model: Course, as: "course", attributes: ["course_id", "title", "cover"] }
        ]
      });
      return {
        commission_id: String(record.commission_id),
        amount: Number(record.amount),
        rate: Number(record.rate),
        status: record.status,
        settle_at: record.settle_at,
        created_at: record.created_at,
        course: link?.course
          ? { course_id: String(link.course.course_id), title: link.course.title, cover: link.course.cover }
          : null
      };
    })
  );

  return {
    data: { total: count, list, page, page_size: pageSize }
  };
}

/**
 * 提现申请：余额 → 冻结，写提现单
 */
async function requestWithdraw(userId, payload = {}) {
  const amount = Number(payload.amount || 0);
  if (!(amount > 0)) {
    return { error: { status: 400, code: 40072, message: "提现金额必须大于 0" } };
  }

  const wallet = await getOrCreateWallet(userId);
  const available = Number(wallet.balance || 0) - Number(wallet.frozen || 0);
  if (amount > available) {
    return { error: { status: 400, code: 40073, message: "可提现余额不足" } };
  }

  return sequelize.transaction(async (transaction) => {
    const locked = await Wallet.findByPk(userId, { transaction, lock: transaction.LOCK.UPDATE });
    const lockedAvailable = Number(locked?.balance || 0) - Number(locked?.frozen || 0);
    if (amount > lockedAvailable) {
      return { error: { status: 400, code: 40073, message: "可提现余额不足" } };
    }

    await locked.update(
      {
        balance: Number((Number(locked.balance) - amount).toFixed(2)),
        frozen: Number((Number(locked.frozen || 0) + amount).toFixed(2))
      },
      { transaction }
    );

    const withdrawal = await Withdrawal.create(
      {
        withdraw_id: generateId(),
        user_id: userId,
        amount,
        method: payload.method || "wechat",
        account: payload.account || null,
        status: 1
      },
      { transaction }
    );

    return {
      data: {
        withdraw_id: String(withdrawal.withdraw_id),
        amount: Number(withdrawal.amount),
        status: withdrawal.status
      }
    };
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
  requestWithdraw,
  setStudioDistributeRate,
  DISTRIBUTE_MIN,
  DISTRIBUTE_MAX
};
