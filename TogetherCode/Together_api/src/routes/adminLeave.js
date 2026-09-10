const express = require("express");
const { validateRequest } = require("../middlewares/validate");
const { getStudioLeaves, putStudioLeave, putStudioLeaveMakeup } = require("../controllers/leaveController");
const { listStudioLeaveValidators, handleLeaveValidators, handleLeaveMakeupValidators } = require("../validators/leaveValidator");

const router = express.Router();

// 角色归属：工作室后台（Web）。
// 已实现接口：请假列表、请假审批、补课绑定 / 放弃补课。
router.get("/", listStudioLeaveValidators, validateRequest, getStudioLeaves);
router.put("/:id", handleLeaveValidators, validateRequest, putStudioLeave);
router.put("/:id/makeup", handleLeaveMakeupValidators, validateRequest, putStudioLeaveMakeup);

module.exports = router;
