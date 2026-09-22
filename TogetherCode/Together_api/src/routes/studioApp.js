const express = require("express");
const { requireAuth, requireRole } = require("../middlewares/auth");
const { validateRequest } = require("../middlewares/validate");
const {
  studioListRefundValidators,
  studioReviewRefundValidators
} = require("../validators/orderValidator");
const {
  getStudioMineHandler,
  getStudioOverviewHandler,
  getStudioRefundsHandler,
  putStudioRefundHandler
} = require("../controllers/studioAppController");

const router = express.Router();

// /v1/studio/* · 工作室角色 App 端（与 Web 侧 /studio/* 后台接口区分）
router.use(requireAuth, requireRole(3));

router.get("/mine", getStudioMineHandler);
router.get("/overview", getStudioOverviewHandler);

// 退款审核：列表 + 审核（通过 / 驳回留言 / 确认打款）
router.get("/refunds", studioListRefundValidators, validateRequest, getStudioRefundsHandler);
router.put("/refunds/:id", studioReviewRefundValidators, validateRequest, putStudioRefundHandler);

module.exports = router;
