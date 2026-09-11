const { ok, fail } = require("../utils/response");
const {
  createDistributionLink,
  getCommissionSummary,
  listCommissionRecords,
  requestWithdraw,
  setStudioDistributeRate
} = require("../services/commissionService");

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

async function postCommissionWithdraw(req, res) {
  try {
    const result = await requestWithdraw(req.user.userId, req.body);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result.data, "提现申请已提交");
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

module.exports = {
  postDistributionLink,
  getCommissionSummaryHandler,
  getCommissionRecords,
  postCommissionWithdraw,
  putStudioDistributeRate
};
