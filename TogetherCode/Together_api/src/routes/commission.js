const express = require("express");
const { requireAuth } = require("../middlewares/auth");
const { validateRequest } = require("../middlewares/validate");
const {
  postDistributionLink,
  getCommissionSummaryHandler,
  getCommissionRecords,
  postCommissionWithdraw
} = require("../controllers/commissionController");
const {
  createDistributionLinkValidators,
  listCommissionRecordsValidators,
  withdrawValidators
} = require("../validators/commissionValidator");

const router = express.Router();

router.use(requireAuth);

// 分销 / 钱包
router.post("/distribution/link", createDistributionLinkValidators, validateRequest, postDistributionLink);
router.get("/commission/summary", getCommissionSummaryHandler);
router.get("/commission/records", listCommissionRecordsValidators, validateRequest, getCommissionRecords);
router.post("/commission/withdraw", withdrawValidators, validateRequest, postCommissionWithdraw);

module.exports = router;
