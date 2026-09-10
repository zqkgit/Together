const express = require("express");
const { requireBackofficeAuth } = require("../middlewares/auth");
const { studioAuthController } = require("../controllers/backofficeAuthController");

const router = express.Router();

// 角色归属：工作室后台登录接口。
router.post("/login", studioAuthController.postLogin);
router.post("/refresh", studioAuthController.postRefresh);
router.post("/logout", studioAuthController.postLogout);
router.get("/me", requireBackofficeAuth("studio"), studioAuthController.getMe);

module.exports = router;
