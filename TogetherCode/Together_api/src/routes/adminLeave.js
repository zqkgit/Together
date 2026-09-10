const express = require("express");
const { validateRequest } = require("../middlewares/validate");
const { getStudioLeaves, putStudioLeave, putStudioLeaveMakeup } = require("../controllers/leaveController");
const { listStudioLeaveValidators, handleLeaveValidators, handleLeaveMakeupValidators } = require("../validators/leaveValidator");

const router = express.Router();

router.get("/", listStudioLeaveValidators, validateRequest, getStudioLeaves);
router.put("/:id", handleLeaveValidators, validateRequest, putStudioLeave);
router.put("/:id/makeup", handleLeaveMakeupValidators, validateRequest, putStudioLeaveMakeup);

module.exports = router;
