const express = require("express");
const { requireBackofficeAuth } = require("../middlewares/auth");
const { platformAuthController } = require("../controllers/backofficeAuthController");

const router = express.Router();

// 角色归属：平台 admin 登录接口。
router.post("/login", platformAuthController.postLogin);
router.post("/refresh", platformAuthController.postRefresh);
router.post("/logout", platformAuthController.postLogout);
router.get("/me", requireBackofficeAuth("platform"), platformAuthController.getMe);

module.exports = router;
