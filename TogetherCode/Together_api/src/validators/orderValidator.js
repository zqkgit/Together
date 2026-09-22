const { body, param, query } = require("express-validator");
const { PAY_METHODS } = require("../services/orderService");

const createOrderValidators = [
  body("child_id").isString().notEmpty().withMessage("child_id is required"),
  body("course_id").isString().notEmpty().withMessage("course_id is required"),
  body("class_id").isString().notEmpty().withMessage("请选择上课班级"),
  body("package_id").optional({ values: "falsy" }).isString(),
  body("distribution_code").optional({ values: "falsy" }).isString().isLength({ max: 64 }),
  body("remark").optional({ values: "falsy" }).isString().isLength({ max: 255 })
];

// 家长上传线下付款凭证：线上转账必传凭证（服务层二次校验），现金一般由工作室直接登记
const submitVoucherValidators = [
  param("id").isString().notEmpty().withMessage("order id is required"),
  body("pay_method").isIn(PAY_METHODS).withMessage("请选择支付方式"),
  body("voucher_images").optional({ values: "falsy" }).isArray({ max: 9 }).withMessage("凭证最多 9 张"),
  body("voucher_images.*").optional().isString(),
  body("note").optional({ values: "falsy" }).isString().isLength({ max: 255 })
];

const orderIdValidators = [param("id").isString().notEmpty().withMessage("order id is required")];

const listOrderValidators = [query("status").optional({ values: "falsy" }).isInt({ min: 0, max: 5 })];

const cancelOrderValidators = [param("id").isString().notEmpty().withMessage("order id is required")];

const createRefundValidators = [
  param("id").isString().notEmpty().withMessage("order id is required"),
  body("lessons").isInt({ min: 1 }).withMessage("lessons must be greater than 0"),
  body("reason").optional({ values: "falsy" }).isString().isLength({ max: 255 })
];

const studioListOrderValidators = [
  query("status").optional({ values: "falsy" }).isInt({ min: 0, max: 5 }),
  query("q").optional({ values: "falsy" }).isString().isLength({ max: 64 })
];

const studioOrderIdValidators = [param("id").isString().notEmpty().withMessage("order id is required")];

const studioListRefundValidators = [
  query("status").optional({ values: "falsy" }).isInt({ min: 0, max: 5 })
];

// 工作室手动建单（老学员续费 / 线下现金报名）
const createStudioOrderValidators = [
  body("child_id").isString().notEmpty().withMessage("请选择孩子"),
  body("course_id").isString().notEmpty().withMessage("请选择课程"),
  body("class_id").optional({ values: "falsy" }).isString(),
  body("total_amount").isInt({ min: 1 }).withMessage("请填写收款金额（单位：分）"),
  body("remark").optional({ values: "falsy" }).isString().isLength({ max: 255 }),
  body("confirm").optional({ values: "falsy" }).isIn([0, 1, "0", "1"]),
  body("pay_method").optional({ values: "falsy" }).isIn(PAY_METHODS),
  body("voucher_images").optional({ values: "falsy" }).isArray({ max: 9 }),
  body("voucher_images.*").optional().isString(),
  body("note").optional({ values: "falsy" }).isString().isLength({ max: 255 })
];

// 工作室确认收款（确认家长凭证 / 直接登记现金收款）
const studioPaymentValidators = [
  param("id").isString().notEmpty().withMessage("order id is required"),
  body("pay_method").isIn(PAY_METHODS).withMessage("请选择支付方式"),
  body("voucher_images").optional({ values: "falsy" }).isArray({ max: 9 }),
  body("voucher_images.*").optional().isString(),
  body("note").optional({ values: "falsy" }).isString().isLength({ max: 255 })
];

// 工作室驳回家长付款凭证
const studioRejectPaymentValidators = [
  param("id").isString().notEmpty().withMessage("order id is required"),
  body("reason").optional({ values: "falsy" }).isString().isLength({ max: 255 })
];

const studioReviewRefundValidators = [
  param("id").isString().notEmpty().withMessage("refund id is required"),
  body("action").isIn(["approve", "reject", "confirm"]).withMessage("action is invalid"),
  body("reason").optional({ values: "falsy" }).isString().isLength({ max: 255 }),
  body("refund_method").optional({ values: "falsy" }).isIn(PAY_METHODS),
  body("voucher_images").optional({ values: "falsy" }).isArray({ max: 9 }),
  body("voucher_images.*").optional().isString()
];

module.exports = {
  cancelOrderValidators,
  createOrderValidators,
  submitVoucherValidators,
  orderIdValidators,
  listOrderValidators,
  createRefundValidators,
  studioListOrderValidators,
  studioOrderIdValidators,
  createStudioOrderValidators,
  studioPaymentValidators,
  studioRejectPaymentValidators,
  studioListRefundValidators,
  studioReviewRefundValidators
};
