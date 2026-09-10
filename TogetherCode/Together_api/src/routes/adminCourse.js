const express = require("express");
const { getStudioCourses, getCourse, postCourse, putCourse } = require("../controllers/courseController");
const { validateRequest } = require("../middlewares/validate");
const { saveCourseValidators, listCoursesValidators, courseIdValidator } = require("../validators/courseValidator");

const router = express.Router();

// 角色归属：工作室后台（Web）。
// 已实现接口：课程列表、课程详情、新增课程、编辑课程。
router.get("/", listCoursesValidators, validateRequest, getStudioCourses);
router.post("/", saveCourseValidators, validateRequest, postCourse);
router.put("/:id", courseIdValidator, saveCourseValidators, validateRequest, putCourse);
router.get("/:id", courseIdValidator, validateRequest, getCourse);

module.exports = router;
