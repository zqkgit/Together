const express = require("express");
const { getCourses, getCourse } = require("../controllers/courseController");
const { validateRequest } = require("../middlewares/validate");
const { listCoursesValidators, courseIdValidator } = require("../validators/courseValidator");

const router = express.Router();

// 角色归属：App 课程查询接口。
// 当前主调用方是家长端；老师 / 工作室轻量端后续也可直接复用查询能力。
router.get("/", listCoursesValidators, validateRequest, getCourses);
router.get("/:id", courseIdValidator, validateRequest, getCourse);

module.exports = router;
