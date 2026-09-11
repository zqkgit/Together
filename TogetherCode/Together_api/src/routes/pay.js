const express = require("express");
const { postWxPayCallback } = require("../controllers/payController");

const router = express.Router();

// 微信支付回调：微信服务器调用，无登录态；XML body 由 express.text 解析
router.post(
  "/callback/wx",
  express.text({ type: ["application/xml", "text/xml"] }),
  postWxPayCallback
);

module.exports = router;
