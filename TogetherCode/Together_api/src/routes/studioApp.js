const express = require("express");
const { requireAuth, requireRole } = require("../middlewares/auth");
const { getStudioMineHandler, getStudioOverviewHandler } = require("../controllers/studioAppController");

const router = express.Router();

// /v1/studio/* · 工作室角色 App 端（与 Web 侧 /studio/* 后台接口区分）
router.use(requireAuth, requireRole(3));

router.get("/mine", getStudioMineHandler);
router.get("/overview", getStudioOverviewHandler);

module.exports = router;
