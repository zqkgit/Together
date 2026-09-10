const { query } = require("express-validator");

// 家长端查看类接口共用校验：child_id 可选、week 为日期、limit/offset 为数字
const parentViewValidators = [
  query("child_id").optional({ values: "falsy" }).isString(),
  query("week").optional({ values: "falsy" }).isString().isLength({ max: 10 }),
  query("limit").optional({ values: "falsy" }).isInt({ min: 1, max: 200 }),
  query("offset").optional({ values: "falsy" }).isInt({ min: 0 })
];

module.exports = {
  parentViewValidators
};
