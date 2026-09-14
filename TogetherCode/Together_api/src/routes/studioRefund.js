const express = require("express");
const { validateRequest } = require("../middlewares/validate");
const {
  studioListRefundValidators,
  studioReviewRefundValidators
} = require("../validators/orderValidator");
const { getStudioRefunds, putStudioRefund } = require("../controllers/studioOrderController");

const router = express.Router();

// 角色归属：工作室后台（Web）。
// 已实现接口：退款列表、退款审核。
router.get("/", studioListRefundValidators, validateRequest, getStudioRefunds);
router.put("/:id", studioReviewRefundValidators, validateRequest, putStudioRefund);

module.exports = router;
