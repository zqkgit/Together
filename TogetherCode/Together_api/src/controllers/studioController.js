const { ok, fail } = require("../utils/response");
const { getStudioProfile, updateStudioProfile } = require("../services/studioService");
const { getStudioOverview } = require("../services/studioOverviewService");

async function getMyStudioProfile(req, res) {
  try {
    const data = await getStudioProfile(req.admin.studioId);
    if (!data) {
      return fail(res, 404, 40480, "Studio not found");
    }

    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function putMyStudioProfile(req, res) {
  try {
    const data = await updateStudioProfile(req.admin.studioId, req.body);
    if (!data) {
      return fail(res, 404, 40480, "Studio not found");
    }

    return ok(res, data, "studio profile updated");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getMyStudioOverview(req, res) {
  try {
    const data = await getStudioOverview(req.admin.studioId);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

module.exports = {
  getMyStudioProfile,
  putMyStudioProfile,
  getMyStudioOverview
};
