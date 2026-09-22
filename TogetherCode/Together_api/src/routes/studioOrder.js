const express = require("express");
const { validateRequest } = require("../middlewares/validate");
const {
  studioListOrderValidators,
  studioOrderIdValidators,
  createStudioOrderValidators,
  studioPaymentValidators,
  studioRejectPaymentValidators
} = require("../validators/orderValidator");
const {
  getStudioOrders,
  getStudioOrder,
  exportStudioOrders,
  getStudioOrderContacts,
  postStudioOrder,
  postStudioPaymentConfirm,
  postStudioPaymentReject,
  postStudioOrderCancel
} = require("../controllers/studioOrderController");

const router = express.Router();

// 角色归属：工作室后台（Web），认证由父路由 /studio 统一注入。
// 线下资金模式：手动建单、确认收款（发课时）、驳回凭证、手动取消；联系人库供建单选孩子。
// 字面量路由必须放在 /:id 之前，避免被参数路由吞掉。
router.get("/contacts", studioListOrderValidators, validateRequest, getStudioOrderContacts);
router.get("/export", studioListOrderValidators, validateRequest, exportStudioOrders);
router.get("/", studioListOrderValidators, validateRequest, getStudioOrders);
router.post("/", createStudioOrderValidators, validateRequest, postStudioOrder);
router.get("/:id", studioOrderIdValidators, validateRequest, getStudioOrder);
router.post("/:id/payments/confirm", studioPaymentValidators, validateRequest, postStudioPaymentConfirm);
router.post("/:id/payments/reject", studioRejectPaymentValidators, validateRequest, postStudioPaymentReject);
router.post("/:id/cancel", studioOrderIdValidators, validateRequest, postStudioOrderCancel);

module.exports = router;
