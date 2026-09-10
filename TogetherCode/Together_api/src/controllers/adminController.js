const { ok } = require("../utils/response");
const {
  getDashboardOverview,
  getStudios,
  getReviews,
  getSettlements
} = require("../services/adminStore");

async function getOverview(_req, res) {
  return ok(res, await getDashboardOverview());
}

async function getStudiosList(_req, res) {
  return ok(res, await getStudios());
}

async function getReviewsList(_req, res) {
  return ok(res, await getReviews());
}

async function getSettlementsData(_req, res) {
  return ok(res, await getSettlements());
}

module.exports = {
  getOverview,
  getStudiosList,
  getReviewsList,
  getSettlementsData
};
