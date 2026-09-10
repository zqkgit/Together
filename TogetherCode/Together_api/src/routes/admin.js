const express = require("express");
const { requireBackofficeAuth } = require("../middlewares/auth");
const {
  getOverview,
  getStudiosList,
  getStudioDetailById,
  getReviewsList,
  getReviewDetail,
  putReview,
  putStudioBan,
  putStudioUnban,
  getSettlementsData,
  postGenerateSettlements,
  postPayoutSettlement,
  getTeacherApplicationsData,
  putTeacherApplicationReview,
  getTagsData,
  postTag,
  putTag,
  deleteTagItem
} = require("../controllers/adminController");
const adminAuthRoutes = require("./adminAuth");
const { validateRequest } = require("../middlewares/validate");
const {
  studioIdValidator,
  reviewIdValidator,
  listStudiosValidators,
  listReviewsValidators,
  handleStudioReviewValidators,
  banStudioValidators
} = require("../validators/backofficeValidator");

const router = express.Router();

router.use("/auth", adminAuthRoutes);
router.use(requireBackofficeAuth("platform"));

// 角色归属：平台 admin（Web 管理端）。
// 说明：这一组是平台级治理接口，服务 platform_super / platform_ops。
router.get("/dashboard/overview", getOverview);
router.get("/studios", listStudiosValidators, validateRequest, getStudiosList);
router.get("/studios/:id", studioIdValidator, validateRequest, getStudioDetailById);
router.put("/studios/:id/ban", banStudioValidators, validateRequest, putStudioBan);
router.put("/studios/:id/unban", studioIdValidator, validateRequest, putStudioUnban);
router.get("/reviews", listReviewsValidators, validateRequest, getReviewsList);
router.get("/reviews/:id", reviewIdValidator, validateRequest, getReviewDetail);
router.put("/reviews/:id", handleStudioReviewValidators, validateRequest, putReview);
router.get("/settlements", getSettlementsData);
router.post("/settlements/generate", postGenerateSettlements);
router.post("/settlements/:id/payout", postPayoutSettlement);

// 平台老师认证审核（studio_id 为空的申请：用户申请成为老师）
router.get("/teacher-applications", getTeacherApplicationsData);
router.put("/teacher-applications/:id", putTeacherApplicationReview);

// 标签管理（兴趣标签库：1 工作室 / 2 老师 / 3 通用）
router.get("/tags", getTagsData);
router.post("/tags", postTag);
router.put("/tags/:id", putTag);
router.delete("/tags/:id", deleteTagItem);

module.exports = router;
