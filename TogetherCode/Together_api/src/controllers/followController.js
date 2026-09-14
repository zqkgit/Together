const { ok, fail } = require("../utils/response");
const {
  followUser,
  unfollowUser,
  listFollowing,
  listFollowers
} = require("../services/followService");

/** 关注用户（登录） */
async function postFollow(req, res) {
  try {
    const followeeId = req.params.id;
    const result = await followUser(req.user.userId, followeeId);
    if (result && result.error) {
      return fail(res, result.error.status || 400, result.error.code || 40000, result.error.message);
    }
    return ok(res, result, "已关注");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/** 取消关注（登录） */
async function deleteFollow(req, res) {
  try {
    const result = await unfollowUser(req.user.userId, req.params.id);
    return ok(res, result, result.removed ? "已取消关注" : "未关注");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/** 我的关注列表 */
async function getFollowing(req, res) {
  try {
    const { page = 1, size = 20 } = req.query;
    return ok(res, await listFollowing(req.user.userId, Number(page), Number(size)));
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/** 我的粉丝列表 */
async function getFollowers(req, res) {
  try {
    const { page = 1, size = 20 } = req.query;
    return ok(res, await listFollowers(req.user.userId, Number(page), Number(size)));
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

module.exports = {
  postFollow,
  deleteFollow,
  getFollowing,
  getFollowers
};
