const { ok, fail } = require("../utils/response");
const {
  createDistributionLink,
  getCommissionSummary,
  listCommissionRecords,
  requestStudioWithdraw,
  listMyWithdrawals,
  getMyWithdrawalDetail,
  confirmWithdrawal,
  listStudioWithdrawals,
  reviewStudioWithdrawal,
  setStudioDistributeRate
} = require("../services/commissionService");
const { createWxacodeForCode } = require("../services/wxCodeService");

/* ===================== 家长 / 推广人 ===================== */

async function postDistributionLink(req, res) {
  try {
    const result = await createDistributionLink(req.user.userId, req.body);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result.data, "分享链接已生成");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getCommissionSummaryHandler(req, res) {
  try {
    const result = await getCommissionSummary(req.user.userId);
    return ok(res, result.data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getCommissionRecords(req, res) {
  try {
    const result = await listCommissionRecords(req.user.userId, req.query);
    return ok(res, result.data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// 发起领取（按工作室一次性领取全部待申请佣金）
async function postCommissionWithdraw(req, res) {
  try {
    const result = await requestStudioWithdraw(req.user.userId, req.body);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result.data, "领取申请已提交");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// 我的领取单列表
async function getMyWithdrawals(req, res) {
  try {
    const result = await listMyWithdrawals(req.user.userId, req.query);
    return ok(res, result.data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// 我的领取单详情
async function getMyWithdrawalDetailHandler(req, res) {
  try {
    const result = await getMyWithdrawalDetail(req.user.userId, req.params.id);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result.data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// 确认收到佣金
async function postConfirmWithdrawal(req, res) {
  try {
    const result = await confirmWithdrawal(req.user.userId, req.params.id);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result.data, "已确认收到");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/* ===================== 工作室 ===================== */

// 工作室佣金领取单列表
async function getStudioWithdrawals(req, res) {
  try {
    const result = await listStudioWithdrawals(req.admin.studioId, req.query);
    return ok(res, result.data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// 工作室审核领取单（approve / reject）
async function putStudioWithdrawalReview(req, res) {
  try {
    const result = await reviewStudioWithdrawal(
      req.admin.studioId,
      req.params.id,
      req.body,
      req.admin
    );
    if (result === null) {
      return fail(res, 404, 40495, "领取单不存在");
    }
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    const msg = req.body.action === "reject" ? "已驳回" : "已登记打款";
    return ok(res, result, msg);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// PUT /studio/distribute-rate · 工作室设置返利比例
async function putStudioDistributeRate(req, res) {
  try {
    const result = await setStudioDistributeRate(req.admin?.studioId || req.body.studio_id, req.body.rate);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result.data, "返利比例已更新");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/** 生成分享海报用的小程序码 */
async function postWxacode(req, res) {
  try {
    const result = await createWxacodeForCode(req.body.code);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result.data, "ok");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

module.exports = {
  // 家长
  postDistributionLink,
  getCommissionSummaryHandler,
  getCommissionRecords,
  postCommissionWithdraw,
  getMyWithdrawals,
  getMyWithdrawalDetailHandler,
  postConfirmWithdrawal,
  // 工作室
  getStudioWithdrawals,
  putStudioWithdrawalReview,
  putStudioDistributeRate,
  postWxacode
};
