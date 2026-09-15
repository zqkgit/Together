const express = require("express");
const { putMeProfile, postSetPayPassword } = require("../controllers/authController");
const { requireAuth } = require("../middlewares/auth");

const router = express.Router();

// /v1/me/* · 当前用户自身资源
router.put("/profile", requireAuth, putMeProfile);
router.post("/pay-password", requireAuth, postSetPayPassword);

module.exports = router;
