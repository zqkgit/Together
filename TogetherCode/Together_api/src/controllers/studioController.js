const { ok, fail } = require("../utils/response");
const { getStudioProfile, updateStudioProfile } = require("../services/studioService");
const { getStudioOverview } = require("../services/studioOverviewService");
const {
  getStudioTeachers,
  reviewTeacherApplication
} = require("../services/studioTeacherService");

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

async function getMyStudioTeachers(req, res) {
  try {
    const data = await getStudioTeachers(req.admin.studioId, req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function putTeacherReview(req, res) {
  try {
    const result = await reviewTeacherApplication(req.admin.studioId, req.params.id, req.body, req.admin);
    if (result.error) {
      return fail(res, result.error.status, result.error.status === 404 ? 40481 : 40081, result.error.message);
    }

    return ok(res, result.data, result.message);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

module.exports = {
  getMyStudioProfile,
  putMyStudioProfile,
  getMyStudioOverview,
  getMyStudioTeachers,
  putTeacherReview
};
