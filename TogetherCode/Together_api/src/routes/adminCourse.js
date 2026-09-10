const express = require("express");
const { getStudioCourses, getCourse, postCourse, putCourse } = require("../controllers/courseController");
const { validateRequest } = require("../middlewares/validate");
const { saveCourseValidators, listCoursesValidators, courseIdValidator } = require("../validators/courseValidator");

const router = express.Router();

router.get("/", listCoursesValidators, validateRequest, getStudioCourses);
router.post("/", saveCourseValidators, validateRequest, postCourse);
router.put("/:id", courseIdValidator, saveCourseValidators, validateRequest, putCourse);
router.get("/:id", courseIdValidator, validateRequest, getCourse);

module.exports = router;
