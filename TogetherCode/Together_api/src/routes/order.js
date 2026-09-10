const express = require("express");
const { requireAuth } = require("../middlewares/auth");
const { validateRequest } = require("../middlewares/validate");
const {
  createOrderValidators,
  payOrderValidators,
  orderIdValidators,
  listOrderValidators,
  createRefundValidators
} = require("../validators/orderValidator");
const {
  postOrder,
  postOrderPay,
  getOrders,
  getOrder,
  postOrderRefund
} = require("../controllers/orderController");

const router = express.Router();

router.use(requireAuth);

// 角色归属：家长端接口。
// 说明：订单、支付、退款申请都由家长在 App 端发起；退款确认由工作室在 /studio/refunds/* 审核。
router.get("/", listOrderValidators, validateRequest, getOrders);
router.get("/:id", orderIdValidators, validateRequest, getOrder);
router.post("/", createOrderValidators, validateRequest, postOrder);
router.post("/:id/pay", payOrderValidators, validateRequest, postOrderPay);
router.post("/:id/refunds", createRefundValidators, validateRequest, postOrderRefund);

module.exports = router;
