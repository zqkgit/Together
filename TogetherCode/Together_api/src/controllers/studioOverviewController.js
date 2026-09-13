const { ok, fail } = require("../utils/response");
const { getStudioOverview, getStudioReports } = require("../services/studioOverviewService");

async function getStudioOverviewData(req, res) {
  try {
    const studioId = req.admin.studioId;
    const data = await getStudioOverview(studioId);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getStudioReportsData(req, res) {
  try {
    const studioId = req.admin.studioId;
    const data = await getStudioReports(studioId);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

module.exports = {
  getStudioOverviewData,
  getStudioReportsData
};
