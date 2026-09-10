const { ok, fail } = require("../utils/response");
const {
  getMyBalances,
  getMyLessonLogs,
  getChildTimetable
} = require("../services/parentService");

async function getMyBalancesData(req, res) {
  try {
    const data = await getMyBalances(req.user.userId, req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getMyLessonLogsData(req, res) {
  try {
    const data = await getMyLessonLogs(req.user.userId, req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getChildTimetableData(req, res) {
  try {
    const result = await getChildTimetable(req.user.userId, req.query);
    if (result.error) {
      return fail(res, result.error.status, result.error.status === 404 ? 40440 : 40040, result.error.message);
    }
    return ok(res, result);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

module.exports = {
  getMyBalancesData,
  getMyLessonLogsData,
  getChildTimetableData
};
