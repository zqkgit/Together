const { ok } = require("../utils/response");
const {
  getDashboardOverview,
  getStudios,
  getReviews,
  getSettlements,
  getStudioDetail,
  getStudioReviewDetail,
  reviewStudioApplication
} = require("../services/adminStore");
const { fail } = require("../utils/response");

async function getOverview(_req, res) {
  return ok(res, await getDashboardOverview());
}

async function getStudiosList(_req, res) {
  return ok(res, await getStudios());
}

async function getStudioDetailById(req, res) {
  const data = await getStudioDetail(req.params.id);
  if (!data) {
    return fail(res, 404, 40470, "Studio not found");
  }

  return ok(res, data);
}

async function getReviewsList(_req, res) {
  return ok(res, await getReviews());
}

async function getReviewDetail(req, res) {
  const data = await getStudioReviewDetail(req.params.id);
  if (!data) {
    return fail(res, 404, 40471, "Studio review not found");
  }

  return ok(res, data);
}

async function putReview(req, res) {
  try {
    const data = await reviewStudioApplication(req.params.id, req.body, req.admin);
    if (!data) {
      return fail(res, 404, 40471, "Studio review not found");
    }

    return ok(res, data, "studio review handled");
  } catch (error) {
    const status = /already handled/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40070 : 50000, error.message || "Internal server error");
  }
}

async function getSettlementsData(_req, res) {
  return ok(res, await getSettlements());
}

module.exports = {
  getOverview,
  getStudiosList,
  getStudioDetailById,
  getReviewsList,
  getReviewDetail,
  putReview,
  getSettlementsData
};
