const express = require("express");
const { getStudioClasses, postStudioClass, getClassStudents } = require("../controllers/scheduleController");
const { validateRequest } = require("../middlewares/validate");
const { createStudioClassValidators, listStudioClassesValidators } = require("../validators/scheduleValidator");
const { classIdValidator } = require("../validators/studentValidator");

const router = express.Router();

router.get("/", listStudioClassesValidators, validateRequest, getStudioClasses);
router.post("/", createStudioClassValidators, validateRequest, postStudioClass);
router.get("/:id/students", classIdValidator, validateRequest, getClassStudents);

module.exports = router;
