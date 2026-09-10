const express = require("express");
const { requireAuth } = require("../middlewares/auth");
const { validateRequest } = require("../middlewares/validate");
const { getMyLeaves, postLeave } = require("../controllers/leaveController");
const { createLeaveValidators, listMyLeaveValidators } = require("../validators/leaveValidator");

const router = express.Router();

router.use(requireAuth);

// 角色归属：家长端接口。
// 说明：家长提交请假；老师审批请假走 /v1/teacher/leaves，工作室后台处理走 /admin/studio/leaves。
router.get("/", listMyLeaveValidators, validateRequest, getMyLeaves);
router.post("/", createLeaveValidators, validateRequest, postLeave);

module.exports = router;
