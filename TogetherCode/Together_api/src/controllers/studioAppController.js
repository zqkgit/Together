const { ok, fail } = require("../utils/response");
const { StudioProfile } = require("../models");
const { getStudioMine, getStudioOverviewForApp } = require("../services/studioAppService");
const {
  listStudioRefunds,
  reviewStudioRefund,
  confirmRefundPaid
} = require("../services/studioOrderService");

/**
 * 由登录用户（工作室主体）解析其 studio_id；非工作室主体返回 null
 */
async function resolveStudioId(userId) {
  const studio = await StudioProfile.findOne({
    where: { user_id: userId },
    attributes: ["studio_id"]
  });
  return studio ? studio.studio_id : null;
}

/**
 * GET /v1/studio/mine · 工作室 App 端「我的」
 * 机构资料 + 经营统计（在读学员 / 在售课程 / 入驻教师 / 待退款）
 */
async function getStudioMineHandler(req, res) {
  try {
    const data = await getStudioMine(req.user.userId);
    if (!data) {
      return fail(res, 404, 40480, "Studio not found");
    }
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/**
 * GET /v1/studio/overview · 工作室 App 端「经营概览」
 * 营收卡（本月营收 / 可提现 / 分销返利 / 结算中）+ 三项统计 + 待办 + 机构动态
 */
async function getStudioOverviewHandler(req, res) {
  try {
    const data = await getStudioOverviewForApp(req.user.userId);
    if (!data) {
      return fail(res, 404, 40480, "Studio not found");
    }
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/**
 * GET /v1/studio/refunds · 工作室 App 端退款列表（query: status 0申请中/1待打款/2已驳回/3已打款）
 */
async function getStudioRefundsHandler(req, res) {
  try {
    const studioId = await resolveStudioId(req.user.userId);
    if (!studioId) {
      return fail(res, 404, 40480, "Studio not found");
    }
    const data = await listStudioRefunds(studioId, req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/**
 * PUT /v1/studio/refunds/:id · 退款审核
 * body.action: approve 通过(0→1待打款) / reject 驳回(→2，带 reason) / confirm 确认打款(1→3)
 */
async function putStudioRefundHandler(req, res) {
  try {
    const studioId = await resolveStudioId(req.user.userId);
    if (!studioId) {
      return fail(res, 404, 40480, "Studio not found");
    }
    const operator = { adminId: req.user.userId };
    const isConfirm = req.body.action === "confirm";
    const data = isConfirm
      ? await confirmRefundPaid(studioId, req.params.id, operator)
      : await reviewStudioRefund(studioId, req.params.id, req.body, operator);
    if (!data) {
      return fail(res, 404, 40491, "Refund not found");
    }
    return ok(res, data, isConfirm ? "refund paid" : "refund handled");
  } catch (error) {
    const status = /already handled|exceed|not found|awaiting payout/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40090 : 50000, error.message || "Internal server error");
  }
}

module.exports = {
  getStudioMineHandler,
  getStudioOverviewHandler,
  getStudioRefundsHandler,
  putStudioRefundHandler
};
