const {
  applyStudioCooperation
} = require("../services/applicationService");

function fail(res, status, code, message) {
  return res.status(status || 400).json({ code: code || 40000, message });
}
function ok(res, data) {
  return res.json({ code: 0, message: "ok", data });
}

async function postStudioCooperation(req, res) {
  try {
    const studioId = String(req.body.studio_id || "");
    if (!studioId) return fail(res, 400, 40001, "请选择要申请的工作室");
    const data = await applyStudioCooperation(req.user.userId, studioId, req.body);
    if (data?.error) return fail(res, data.error.status, data.error.code, data.error.message);
    return ok(res, data.data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

module.exports = {
  postStudioCooperation
};
