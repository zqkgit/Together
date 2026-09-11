const { ok, fail } = require("../utils/response");
const {
  createCourseReview,
  listCourseReviews
} = require("../services/reviewService");
const {
  addFavorite,
  removeFavorite,
  listFavoriteIds,
  listFavorites
} = require("../services/favoriteService");

/** 课程评价列表（公开） */
async function getCourseReviews(req, res) {
  try {
    return ok(res, await listCourseReviews(req.params.id, req.query));
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/** 提交课程评价（登录） */
async function postCourseReview(req, res) {
  try {
    const result = await createCourseReview(req.user.userId, { ...req.body, course_id: req.params.id });
    if (result && result.error) {
      return fail(res, result.error.status || 400, result.error.code || 40000, result.error.message);
    }
    return ok(res, result, "评价成功");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/** 添加收藏（登录） */
async function postFavorite(req, res) {
  try {
    const result = await addFavorite(req.user.userId, req.body);
    if (result && result.error) {
      return fail(res, result.error.status || 400, result.error.code || 40000, result.error.message);
    }
    return ok(res, result, "已收藏");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/** 取消收藏（登录） */
async function deleteFavorite(req, res) {
  try {
    const result = await removeFavorite(req.user.userId, req.query);
    if (result && result.error) {
      return fail(res, result.error.status || 400, result.error.code || 40000, result.error.message);
    }
    return ok(res, result, result.removed ? "已取消收藏" : "未收藏");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/** 我的收藏列表（登录） */
async function getFavorites(req, res) {
  try {
    return ok(res, await listFavorites(req.user.userId, req.query));
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

/** 已收藏 id 列表（登录） */
async function getFavoriteIds(req, res) {
  try {
    const ids = await listFavoriteIds(req.user.userId, req.query.target_type);
    return ok(res, { ids });
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

module.exports = {
  getCourseReviews,
  postCourseReview,
  postFavorite,
  deleteFavorite,
  getFavorites,
  getFavoriteIds
};
