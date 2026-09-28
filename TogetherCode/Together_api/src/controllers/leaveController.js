const { ok, fail } = require("../utils/response");
const {
  submitLeaveRequest,
  listMyLeaveRequests,
  listStudioLeaveRequests,
  reviewLeaveRequest,
  bindMakeupSchedule,
  cancelMyLeaveRequest
} = require("../services/leaveService");
const { recordAudit } = require("../utils/audit");

async function getMyLeaves(req, res) {
  try {
    const data = await listMyLeaveRequests(req.user.userId, req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postLeave(req, res) {
  try {
    const data = await submitLeaveRequest(req.user.userId, req.body);
    return ok(res, data, "leave created");
  } catch (error) {
    const status = /not found|does not belong|already exists|not enrolled/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40050 : 50000, error.message || "Internal server error");
  }
}

async function putMyLeave(req, res) {
  try {
    const data = await cancelMyLeaveRequest(req.user.userId, req.params.id);
    return ok(res, data, "请假已取消");
  } catch (error) {
    const status = /not found|already handled/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40053 : 50000, error.message || "Internal server error");
  }
}

async function getStudioLeaves(req, res) {
  try {
    const data = await listStudioLeaveRequests(req.query);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function putStudioLeave(req, res) {
  try {
    const data = await reviewLeaveRequest(req.params.id, req.body);
    if (!data) {
      return fail(res, 404, 40450, "Leave request not found");
    }
    await recordAudit({ actor: req.admin, studioId: req.admin.studioId, action: "leave.review", targetType: "leave", targetId: req.params.id, ip: req.ip });
    return ok(res, data, "leave handled");
  } catch (error) {
    const status = /already handled|already consumed|not found/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40051 : 50000, error.message || "Internal server error");
  }
}

async function putStudioLeaveMakeup(req, res) {
  try {
    const data = await bindMakeupSchedule(req.params.id, req.body);
    if (!data) {
      return fail(res, 404, 40450, "Leave request not found");
    }
    await recordAudit({ actor: req.admin, studioId: req.admin.studioId, action: "leave.makeup", targetType: "leave", targetId: req.params.id, ip: req.ip });
    return ok(res, data, "leave makeup updated");
  } catch (error) {
    const status = /not approved|not found|does not belong|already assigned|missing|completed|canceled|later/i.test(error.message) ? 400 : 500;
    return fail(res, status, status === 400 ? 40052 : 50000, error.message || "Internal server error");
  }
}

module.exports = {
  getMyLeaves,
  postLeave,
  putMyLeave,
  getStudioLeaves,
  putStudioLeave,
  putStudioLeaveMakeup
};
