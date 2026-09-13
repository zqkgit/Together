const express = require("express");
const { body, query, param } = require("express-validator");
const { validateRequest } = require("../middlewares/validate");
const { requireAuth } = require("../middlewares/auth");
const {
  getCourseReviews,
  postCourseReview,
  postFavorite,
  deleteFavorite,
  getFavorites,
  getFavoriteIds
} = require("../controllers/interactionController");
const { postReport } = require("../controllers/platformGovernanceController");

const router = express.Router();

const reviewValidators = [
  body("rating").isInt({ min: 1, max: 5 }).withMessage("rating must be 1-5"),
  body("content").optional({ values: "falsy" }).isString().isLength({ max: 500 }),
  body("images")
    .optional({ values: "falsy" })
    .custom((v) => Array.isArray(v) && v.length <= 9 && v.every((u) => typeof u === "string"))
    .withMessage("images must be an array of up to 9 image urls")
];

const favoriteValidators = [
  body("target_type").isIn(["course", "teacher", "studio", "post"]).withMessage("target_type invalid"),
  body("target_id").isInt({ gt: 0 }).withMessage("target_id is required")
];

const favoriteQueryValidators = [
  query("target_type").optional({ values: "falsy" }).isIn(["course", "teacher", "studio", "post"]),
  query("page").optional({ values: "falsy" }).isInt({ min: 1 }),
  query("page_size").optional({ values: "falsy" }).isInt({ min: 1, max: 100 })
];

const reportValidators = [
  body("target_type").isIn(["post", "comment", "teacher", "studio"]).withMessage("target_type invalid"),
  body("target_id").isString().notEmpty().withMessage("target_id is required"),
  body("reason").isString().notEmpty().isLength({ max: 20 }).withMessage("reason is required"),
  body("detail").optional({ values: "falsy" }).isString().isLength({ max: 500 }),
  body("images").optional({ values: "falsy" })
    .custom((v) => Array.isArray(v) && v.length <= 9 && v.every((u) => typeof u === "string"))
    .withMessage("images must be an array of up to 9 image urls")
];

const deleteFavoriteValidators = [
  query("target_type").isIn(["course", "teacher", "studio", "post"]).withMessage("target_type invalid"),
  query("target_id").isInt({ gt: 0 }).withMessage("target_id is required")
];

// 课程评价（挂在 /v1/courses/:id 之后需独立路由：/v1/reviews/courses/:id/reviews 简化 —— 见 index.js 挂载说明）
router.get("/courses/:id/reviews", validateRequest, getCourseReviews);
router.post("/courses/:id/reviews", requireAuth, reviewValidators, validateRequest, postCourseReview);

// 收藏
router.post("/favorites", requireAuth, favoriteValidators, validateRequest, postFavorite);
router.delete("/favorites", requireAuth, deleteFavoriteValidators, validateRequest, deleteFavorite);
router.get("/favorites/ids", requireAuth, validateRequest, getFavoriteIds);
router.get("/favorites", requireAuth, favoriteQueryValidators, validateRequest, getFavorites);

// 举报提交（家长/老师端）
router.post("/reports", requireAuth, reportValidators, validateRequest, postReport);

module.exports = router;
