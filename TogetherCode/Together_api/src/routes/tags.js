const express = require("express");
const { ok } = require("../utils/response");
const { listTags } = require("../services/tagService");

const router = express.Router();

// 公共兴趣标签库：App 端工作室/老师申请表单、Web 后台均可读取（仅启用标签）
router.get("/", async (_req, res) => {
  try {
    const data = await listTags(_req.query, true);
    return ok(res, data);
  } catch (error) {
    return res.status(500).json({ code: 50000, message: error.message || "Internal server error" });
  }
});

module.exports = router;
