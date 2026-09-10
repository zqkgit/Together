const express = require("express");
const { validateRequest } = require("../middlewares/validate");
const { listStudioStudentsValidators, consumeLessonValidators } = require("../validators/studentValidator");
const { getStudioStudents, postConsumeLessons } = require("../controllers/studentController");

const router = express.Router();

router.get("/", listStudioStudentsValidators, validateRequest, getStudioStudents);
router.post("/:id/consume", consumeLessonValidators, validateRequest, postConsumeLessons);

module.exports = router;
