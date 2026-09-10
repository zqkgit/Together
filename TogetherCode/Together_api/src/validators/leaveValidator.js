const { body, query, param } = require("express-validator");

const createLeaveValidators = [
  body("class_id").isString().notEmpty().withMessage("class_id is required"),
  body("child_id").isString().notEmpty().withMessage("child_id is required"),
  body("schedule_id").optional({ values: "falsy" }).isString(),
  body("reason").isString().trim().isLength({ min: 1, max: 200 }).withMessage("reason is required")
];

const listMyLeaveValidators = [
  query("status").optional({ values: "falsy" }).isInt({ min: 0, max: 2 })
];

const listStudioLeaveValidators = [
  query("studio_id").isString().notEmpty().withMessage("studio_id is required"),
  query("status").optional({ values: "falsy" }).isInt({ min: 0, max: 2 }),
  query("class_id").optional({ values: "falsy" }).isString(),
  query("child_id").optional({ values: "falsy" }).isString()
];

const handleLeaveValidators = [
  param("id").isString().notEmpty().withMessage("leave id is required"),
  body("action").isIn(["agree", "reject"]).withMessage("action is invalid"),
  body("note").optional({ values: "falsy" }).isString().isLength({ max: 255 })
];

const handleLeaveMakeupValidators = [
  param("id").isString().notEmpty().withMessage("leave id is required"),
  body("action").isIn(["assign", "abandon"]).withMessage("action is invalid"),
  body("makeup_schedule_id")
    .if(body("action").equals("assign"))
    .isString()
    .notEmpty()
    .withMessage("makeup_schedule_id is required for assign")
];

module.exports = {
  createLeaveValidators,
  listMyLeaveValidators,
  listStudioLeaveValidators,
  handleLeaveValidators,
  handleLeaveMakeupValidators
};
