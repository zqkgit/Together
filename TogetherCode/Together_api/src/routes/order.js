const express = require("express");
const { requireAuth } = require("../middlewares/auth");
const { validateRequest } = require("../middlewares/validate");
const {
  createOrderValidators,
  submitVoucherValidators,
  orderIdValidators,
  listOrderValidators,
  cancelOrderValidators,
  createRefundValidators
} = require("../validators/orderValidator");
const {
  postOrder,
  postPaymentVoucher,
  postOrderCancel,
  getOrders,
  getOrder,
  postOrderRefund,
  getRefunds,
  getRefund
} = require("../controllers/orderController");

const router = express.Router();

router.use(requireAuth);

// 角色归属：家长端接口。
// 线下资金模式：App 不发起在线支付。家长自助报名生成「待收款单」，线下转账后上传付款凭证，
// 由工作室在 /studio/orders/* 核对确认收款后发放课时；退款确认同样在工作室端处理。
// 退款列表/详情需放在 /:id 之前，避免被参数路由吞掉
router.get("/refunds/:refundId", getRefund);
router.get("/refunds", getRefunds);
router.get("/", listOrderValidators, validateRequest, getOrders);
router.get("/:id", orderIdValidators, validateRequest, getOrder);
router.post("/", createOrderValidators, validateRequest, postOrder);
router.post("/:id/payment-voucher", submitVoucherValidators, validateRequest, postPaymentVoucher);
router.post("/:id/cancel", cancelOrderValidators, validateRequest, postOrderCancel);
router.post("/:id/refunds", createRefundValidators, validateRequest, postOrderRefund);

module.exports = router;
