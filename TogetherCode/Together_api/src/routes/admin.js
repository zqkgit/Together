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
  getTeachersData,
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
const {
  getReportsList,
  putReportHandle,
  putPostModerate,
  postSettlementReprocess,
  getConfig,
  putConfig,
  getAnnouncementsList,
  postAnnouncement,
  postStaff,
  getAuditList,
  getPostsList,
  getStaffList,
  putStaffStatus,
  putAnnouncementStatus,
  getWithdrawalsList,
  putWithdrawalReview
} = require("../controllers/platformGovernanceController");
const {
  handleReportValidators,
  moderatePostValidators,
  reprocessSettlementValidators,
  createAnnouncementValidators,
  createStaffValidators,
  updateConfigValidators,
  withdrawalReviewValidators
} = require("../validators/governanceValidator");

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

// 平台老师管理（已认证老师档案）
router.get("/teachers", getTeachersData);

// 标签管理（兴趣标签库：1 工作室 / 2 老师 / 3 通用）
router.get("/tags", getTagsData);
router.post("/tags", postTag);
router.put("/tags/:id", putTag);
router.delete("/tags/:id", deleteTagItem);

// 举报处置（P3）
router.get("/reports", getReportsList);
router.put("/reports/:id", handleReportValidators, validateRequest, putReportHandle);

// 内容管理：帖子列表 + 下架 / 恢复（P3）
router.get("/posts", getPostsList);
router.put("/posts/:id/moderate", moderatePostValidators, validateRequest, putPostModerate);

// 结算异常重打（P4）
router.post("/settlements/:id/reprocess", reprocessSettlementValidators, validateRequest, postSettlementReprocess);

// 平台配置（P7）
router.get("/config", getConfig);
router.put("/config", updateConfigValidators, validateRequest, putConfig);

// 公告 / Banner（P6）：列表 / 发布 / 上下架
router.get("/announcements", getAnnouncementsList);
router.post("/announcements", createAnnouncementValidators, validateRequest, postAnnouncement);
router.put("/announcements/:id", moderatePostValidators, validateRequest, putAnnouncementStatus);

// 平台员工（P8）：列表 / 新增 / 启用停用
router.get("/staff", getStaffList);
router.post("/staff", createStaffValidators, validateRequest, postStaff);
router.put("/staff/:id", moderatePostValidators, validateRequest, putStaffStatus);

// 全平台审计日志（P8）
router.get("/audit", getAuditList);

// 提现审核（分销闭环）：列表 / 通过·驳回
router.get("/withdrawals", getWithdrawalsList);
router.put("/withdrawals/:id", withdrawalReviewValidators, validateRequest, putWithdrawalReview);

module.exports = router;
