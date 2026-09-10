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
  getSettlementsData
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

module.exports = router;
