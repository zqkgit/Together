const express = require("express");
const { ok } = require("../utils/response");
const { listTopics } = require("../services/topicService");

const router = express.Router();

// 公共话题库：App 端发帖可选话题、Web 后台均可读取（仅上架话题）
router.get("/", async (_req, res) => {
  try {
    const data = await listTopics(_req.query, true);
    return ok(res, data);
  } catch (error) {
    return res.status(500).json({ code: 50000, message: error.message || "Internal server error" });
  }
});

module.exports = router;
