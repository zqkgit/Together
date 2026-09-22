const express = require("express");
const { requireAuth, requireRole } = require("../middlewares/auth");
const { validateRequest } = require("../middlewares/validate");
const { body } = require("express-validator");
const {
  studioListRefundValidators,
  studioReviewRefundValidators
} = require("../validators/orderValidator");
const { listCoursesValidators, courseIdValidator } = require("../validators/courseValidator");
const {
  studioAppStudentListValidators,
  studentIdValidator
} = require("../validators/studentValidator");
const {
  getStudioMineHandler,
  getStudioOverviewHandler,
  getStudioRefundsHandler,
  putStudioRefundHandler,
  getStudioCoursesHandler,
  getStudioCourseHandler,
  patchStudioCourseStatusHandler,
  getStudioStudentsHandler,
  getStudioStudentDetailHandler
} = require("../controllers/studioAppController");

const router = express.Router();

// /v1/studio/* · 工作室角色 App 端（与 Web 侧 /studio/* 后台接口区分）
router.use(requireAuth, requireRole(3));

router.get("/mine", getStudioMineHandler);
router.get("/overview", getStudioOverviewHandler);

// 退款审核：列表 + 审核（通过 / 驳回留言 / 确认打款）
router.get("/refunds", studioListRefundValidators, validateRequest, getStudioRefundsHandler);
router.put("/refunds/:id", studioReviewRefundValidators, validateRequest, putStudioRefundHandler);

// 课程管理：本工作室课程列表 / 详情 / 上架下架
const courseStatusValidators = [
  body("status").isInt({ min: 1, max: 2 }).withMessage("status must be 1(on) or 2(off)")
];
router.get("/courses", listCoursesValidators, validateRequest, getStudioCoursesHandler);
router.get("/courses/:id", courseIdValidator, validateRequest, getStudioCourseHandler);
router.patch("/courses/:id/status", courseIdValidator, courseStatusValidators, validateRequest, patchStudioCourseStatusHandler);

// 学员管理：本工作室学员列表（全部 / 待续费 / 本月新增）+ 学员详情（课时余额 + 流水）
router.get("/students", studioAppStudentListValidators, validateRequest, getStudioStudentsHandler);
router.get("/students/:id", studentIdValidator, validateRequest, getStudioStudentDetailHandler);

module.exports = router;
