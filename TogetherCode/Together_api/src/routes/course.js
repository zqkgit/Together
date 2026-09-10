const express = require("express");
const { getCourses, getCourse } = require("../controllers/courseController");
const { validateRequest } = require("../middlewares/validate");
const { listCoursesValidators, courseIdValidator } = require("../validators/courseValidator");

const router = express.Router();

router.get("/", listCoursesValidators, validateRequest, getCourses);
router.get("/:id", courseIdValidator, validateRequest, getCourse);

module.exports = router;
