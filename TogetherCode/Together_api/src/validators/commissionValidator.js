const { body, query } = require("express-validator");
const { PAY_METHODS } = require("../utils/payMethods");

const createDistributionLinkValidators = [
  body("course_id").isString().notEmpty().withMessage("course_id is required"),
  body("post_id").optional({ values: "falsy" }).isString()
];

const listCommissionRecordsValidators = [
  query("page").optional({ values: "falsy" }).isInt({ min: 1 }),
  query("page_size").optional({ values: "falsy" }).isInt({ min: 1, max: 100 }),
  query("status").optional({ values: "falsy" }).isIn(["1", "2", "3"])
];

// 发起领取：studio_id 必填，一次性领取该工作室全部待申请佣金
const withdrawValidators = [
  body("studio_id").isString().notEmpty().withMessage("studio_id is required"),
  body("method").optional({ values: "falsy" }).isIn(PAY_METHODS).withMessage("invalid method"),
  body("account").optional({ values: "falsy" }).isString().isLength({ max: 128 })
];

// 领取单列表
const listWithdrawalsValidators = [
  query("page").optional({ values: "falsy" }).isInt({ min: 1 }),
  query("page_size").optional({ values: "falsy" }).isInt({ min: 1, max: 100 }),
  query("status").optional({ values: "falsy" }).isIn(["0", "1", "2", "3"])
];

// 工作室审核领取单
const studioReviewValidators = [
  body("action").isIn(["approve", "reject"]).withMessage("action must be approve / reject"),
  body("method").optional({ values: "falsy" }).isIn(PAY_METHODS).withMessage("invalid method"),
  body("voucher_images").optional({ values: "falsy" }).isArray(),
  body("reject_reason").optional({ values: "falsy" }).isString().isLength({ max: 255 })
];

const wxacodeValidators = [body("code").isString().notEmpty().withMessage("code is required")];

module.exports = {
  createDistributionLinkValidators,
  listCommissionRecordsValidators,
  withdrawValidators,
  listWithdrawalsValidators,
  studioReviewValidators,
  wxacodeValidators
};
