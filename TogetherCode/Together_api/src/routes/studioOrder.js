const express = require("express");
const { validateRequest } = require("../middlewares/validate");
const {
  studioListOrderValidators,
  studioOrderIdValidators
} = require("../validators/orderValidator");
const { getStudioOrders, getStudioOrder } = require("../controllers/studioOrderController");

const router = express.Router();

// 角色归属：工作室后台（Web）。
// 已实现接口：订单列表、订单详情。
router.get("/", studioListOrderValidators, validateRequest, getStudioOrders);
router.get("/:id", studioOrderIdValidators, validateRequest, getStudioOrder);

module.exports = router;
