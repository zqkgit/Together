const { ok, fail } = require("../utils/response");
const { getStudioProfile, updateStudioProfile, reviewStudioLeave } = require("../services/studioService");

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


async function reviewLeave(req, res) {
  try {
    const data = await reviewStudioLeave(req.admin.studioId, req.params.id, req.body);
    if (!data) {
      return fail(res, 404, 40481, "Leave request not found");
    }
    return ok(res, data, "leave reviewed");
  } catch (error) {
    return fail(res, 400, 40062, error.message || "Internal server error");
  }
}

module.exports = {
  getMyStudioProfile,
  putMyStudioProfile,
  reviewLeave
};

