const express = require("express");
const { getStudioClasses, postStudioClass, getClassStudents } = require("../controllers/scheduleController");
const { validateRequest } = require("../middlewares/validate");
const { createStudioClassValidators, listStudioClassesValidators } = require("../validators/scheduleValidator");
const { classIdValidator } = require("../validators/studentValidator");

const router = express.Router();

// 角色归属：工作室后台（Web）。
// 已实现接口：班级列表、新建班级、班级学生名单。
router.get("/", listStudioClassesValidators, validateRequest, getStudioClasses);
router.post("/", createStudioClassValidators, validateRequest, postStudioClass);
router.get("/:id/students", classIdValidator, validateRequest, getClassStudents);

module.exports = router;
