const express = require("express");
const {
  postSendCode,
  postRegister,
  postLogin,
  postPasswordLogin,
  postRefresh,
  postLogout,
  getMe
} = require("../controllers/authController");
const { requireAuth } = require("../middlewares/auth");

const router = express.Router();

// 角色归属：App 通用认证接口（家长 / 老师 / 工作室）。
// 说明：这里不区分业务角色，只负责登录态与当前身份信息。
router.post("/send-code", postSendCode);
router.post("/register", postRegister);
router.post("/login", postLogin);
router.post("/login-password", postPasswordLogin);
router.post("/refresh", postRefresh);
router.post("/logout", postLogout);
router.get("/me", requireAuth, getMe);

module.exports = router;
