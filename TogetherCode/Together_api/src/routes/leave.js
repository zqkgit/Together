const express = require("express");
const { requireAuth } = require("../middlewares/auth");
const { validateRequest } = require("../middlewares/validate");
const { getMyLeaves, postLeave } = require("../controllers/leaveController");
const { createLeaveValidators, listMyLeaveValidators } = require("../validators/leaveValidator");

const router = express.Router();

router.use(requireAuth);
router.get("/", listMyLeaveValidators, validateRequest, getMyLeaves);
router.post("/", createLeaveValidators, validateRequest, postLeave);

module.exports = router;
