const express = require("express");
const { requireAuth } = require("../middlewares/auth");
const { validateRequest } = require("../middlewares/validate");
const {
  postDistributionLink,
  getCommissionSummaryHandler,
  getCommissionRecords,
  postCommissionWithdraw,
  postWxacode
} = require("../controllers/commissionController");
const {
  createDistributionLinkValidators,
  listCommissionRecordsValidators,
  withdrawValidators,
  wxacodeValidators
} = require("../validators/commissionValidator");

const router = express.Router();

router.use(requireAuth);

// 分销 / 钱包（挂载于 /v1/distribution 前缀下）
router.post("/link", createDistributionLinkValidators, validateRequest, postDistributionLink);
router.post("/qrcode", wxacodeValidators, validateRequest, postWxacode);
router.get("/commission/summary", getCommissionSummaryHandler);
router.get("/commission/records", listCommissionRecordsValidators, validateRequest, getCommissionRecords);
router.post("/commission/withdraw", withdrawValidators, validateRequest, postCommissionWithdraw);

module.exports = router;
