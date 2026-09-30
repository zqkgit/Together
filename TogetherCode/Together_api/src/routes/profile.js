const express = require("express");
const {
  getUserProfileHandler,
  getTeacherHomepageHandler,
  getStudioHomepageHandler,
  getTeacherReviewsHandler,
  getTeacherStudentWorksHandler,
  getStudioStudentWorksHandler
} = require("../controllers/profileController");

const router = express.Router();

// 主页 / 公开档案（无需登录，游客可浏览）
router.get("/users/:id/profile", getUserProfileHandler);
router.get("/teacher/:id/homepage", getTeacherHomepageHandler);
router.get("/teacher/:id/reviews", getTeacherReviewsHandler);
router.get("/teacher/:id/student-works", getTeacherStudentWorksHandler);
router.get("/studio/:id/homepage", getStudioHomepageHandler);
router.get("/studio/:id/student-works", getStudioStudentWorksHandler);

module.exports = router;
