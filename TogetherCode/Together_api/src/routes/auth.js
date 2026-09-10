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

router.post("/send-code", postSendCode);
router.post("/register", postRegister);
router.post("/login", postLogin);
router.post("/login-password", postPasswordLogin);
router.post("/refresh", postRefresh);
router.post("/logout", postLogout);
router.get("/me", requireAuth, getMe);

module.exports = router;
