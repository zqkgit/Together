const { ok, fail } = require("../utils/response");
const {
  getUserProfile,
  getTeacherHomepage,
  getStudioHomepage
} = require("../services/profileService");

async function getUserProfileHandler(req, res) {
  try {
    const data = await getUserProfile(req.params.id);
    if (!data) {
      return fail(res, 404, 40480, "用户不存在");
    }
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getTeacherHomepageHandler(req, res) {
  try {
    const data = await getTeacherHomepage(req.params.id, req.query);
    if (!data) {
      return fail(res, 404, 40481, "老师不存在或未认证");
    }
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getStudioHomepageHandler(req, res) {
  try {
    const data = await getStudioHomepage(req.params.id, req.query);
    if (!data) {
      return fail(res, 404, 40482, "工作室不存在或已下架");
    }
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

module.exports = {
  getUserProfileHandler,
  getTeacherHomepageHandler,
  getStudioHomepageHandler
};
