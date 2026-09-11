const { body, query, param } = require("express-validator");

// 举报处置
const handleReportValidators = [
  param("id").isString().notEmpty(),
  body("status").isInt({ min: 1, max: 2 }),
  body("handle_note").optional({ values: "falsy" }).isString().isLength({ max: 255 })
];

// 内容下架 / 恢复
const moderatePostValidators = [
  param("id").isString().notEmpty(),
  body("status").isInt({ min: 0, max: 1 })
];

// 结算重打
const reprocessSettlementValidators = [param("id").isString().notEmpty()];

// 公告 / Banner
const createAnnouncementValidators = [
  body("title").isString().trim().notEmpty().withMessage("title is required"),
  body("content").optional({ values: "falsy" }).isString(),
  body("type").optional({ values: "falsy" }).isInt({ min: 1, max: 2 }),
  body("image").optional({ values: "falsy" }).isArray(),
  body("link").optional({ values: "falsy" }).isString().isLength({ max: 255 }),
  body("status").optional({ values: "falsy" }).isInt({ min: 0, max: 1 }),
  body("publish_at").optional({ values: "falsy" }).isISO8601(),
  body("expire_at").optional({ values: "falsy" }).isISO8601()
];

// 员工账号（平台 / 工作室共用字段）
const createStaffValidators = [
  body("username").isString().trim().notEmpty().withMessage("username is required"),
  body("password").isString().isLength({ min: 6 }).withMessage("password at least 6 chars"),
  body("name").optional({ values: "falsy" }).isString().isLength({ max: 40 })
];

// 平台配置（整包更新，无字段级校验）
const updateConfigValidators = [body().isObject().withMessage("config must be an object")];

// 结算账户
const upsertStudioAccountValidators = [
  body("account_id").optional({ values: "falsy" }).isString(),
  body("account_type").optional({ values: "falsy" }).isIn(["bank", "wechat", "alipay"]),
  body("account_name").isString().trim().notEmpty().withMessage("account_name is required"),
  body("account_no").isString().trim().notEmpty().withMessage("account_no is required"),
  body("bank_name").optional({ values: "falsy" }).isString().isLength({ max: 80 }),
  body("is_default").optional({ values: "falsy" }).isInt({ min: 0, max: 1 })
];

// 提现审核
const withdrawalReviewValidators = [
  param("id").isString().notEmpty(),
  body("action").isIn(["approve", "reject"])
];

module.exports = {
  handleReportValidators,
  moderatePostValidators,
  reprocessSettlementValidators,
  createAnnouncementValidators,
  createStaffValidators,
  updateConfigValidators,
  upsertStudioAccountValidators,
  withdrawalReviewValidators
};
