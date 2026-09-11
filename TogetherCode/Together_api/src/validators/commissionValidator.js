const { body, query } = require("express-validator");

const createDistributionLinkValidators = [
  body("course_id").isString().notEmpty().withMessage("course_id is required"),
  body("post_id").optional({ values: "falsy" }).isString()
];

const listCommissionRecordsValidators = [
  query("page").optional({ values: "falsy" }).isInt({ min: 1 }),
  query("page_size").optional({ values: "falsy" }).isInt({ min: 1, max: 100 }),
  query("status").optional({ values: "falsy" }).isIn(["1", "2"])
];

const withdrawValidators = [
  body("amount").isFloat({ gt: 0 }).withMessage("amount must be greater than 0"),
  body("method").optional({ values: "falsy" }).isString().isLength({ max: 32 }),
  body("account").optional({ values: "falsy" }).isString().isLength({ max: 128 })
];

module.exports = {
  createDistributionLinkValidators,
  listCommissionRecordsValidators,
  withdrawValidators
};
