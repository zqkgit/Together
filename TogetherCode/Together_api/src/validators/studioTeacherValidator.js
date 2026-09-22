const { body, query, param } = require("express-validator");

// 老师列表：q 模糊搜索（姓名 / 擅长方向）
const teacherRosterValidators = [
  query("q").optional({ values: "falsy" }).isString().isLength({ max: 40 })
];

// 合作申请列表：status 白名单（不传或 all 为全部）
const teacherApplicationListValidators = [
  query("status").optional({ values: "falsy" }).isIn(["0", "1", "2", "all"])
];

// 合作申请审批：approve / reject（驳回必须带原因）
const teacherApplicationReviewValidators = [
  param("id").isString().notEmpty().withMessage("id is required"),
  body("action").isIn(["approve", "reject"]).withMessage("action must be approve or reject"),
  body("reason").optional({ values: "falsy" }).isString().isLength({ max: 255 })
];

// 邀请老师：手机号
const teacherInviteValidators = [
  body("phone").matches(/^1\d{10}$/).withMessage("phone must be a valid mobile number")
];

// 老师 id（路径参数）
const teacherIdValidator = [param("id").isString().notEmpty().withMessage("id is required")];

module.exports = {
  teacherRosterValidators,
  teacherApplicationListValidators,
  teacherApplicationReviewValidators,
  teacherInviteValidators,
  teacherIdValidator
};
