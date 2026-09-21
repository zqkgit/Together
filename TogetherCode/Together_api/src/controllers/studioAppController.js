const { ok, fail } = require("../utils/response");
const { getStudioMine, getStudioOverviewForApp } = require("../services/studioAppService");

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

module.exports = {
  getStudioMineHandler,
  getStudioOverviewHandler
};
