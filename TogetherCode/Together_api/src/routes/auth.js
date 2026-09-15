const express = require("express");
const {
  postSendCode,
  postRegister,
  postLogin,
  postPasswordLogin,
  postRefresh,
  postLogout,
  getMe,
  postRoleApply,
  getRoleApplyStatusHandler,
  postRoleSwitch,
  postChangePassword,
  postChangePhone,
  postSetPayPassword,
  postDeactivate
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

// 角色认证申请：提交（teacher / studio 平台认证）、查询状态、切换角色（重发 token）
router.post("/role/apply", requireAuth, postRoleApply);
router.get("/role/apply/:role", requireAuth, getRoleApplyStatusHandler);
router.post("/role/switch", requireAuth, postRoleSwitch);

// 账号与安全
router.post("/change-password", requireAuth, postChangePassword);
router.post("/change-phone", requireAuth, postChangePhone);
router.post("/deactivate", requireAuth, postDeactivate);

module.exports = router;
