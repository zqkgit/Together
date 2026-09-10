const express = require("express");
const multer = require("multer");
const path = require("path");
const env = require("../config/env");
const { requireAuth } = require("../middlewares/auth");
const { saveImage, isOssEnabled } = require("../services/uploadService");
const { ok, fail } = require("../utils/response");

const router = express.Router();

// 内存暂存，交由 uploadService 落 OSS 或本地
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: env.upload.maxSizeMb * 1024 * 1024,
    files: env.upload.maxFiles
  },
  fileFilter(_req, file, cb) {
    const ext = path.extname(file.originalname || "").slice(1).toLowerCase();
    const allowed = ["jpg", "jpeg", "png", "gif", "webp", "heic"];
    if (!allowed.includes(ext)) {
      return cb(new Error(`不支持的图片格式：${ext || "未知"}（支持 jpg/png/gif/webp/heic）`));
    }
    cb(null, true);
  }
});

// POST /v1/upload · 图片上传（字段名 files，支持多张，一次最多 9 张）
// 返回 { urls: [...] } 数组，可直接存入 images/photos/portfolio 等数组字段
router.post("/", requireAuth, (req, res) => {
  upload.array("files", env.upload.maxFiles)(req, res, async (err) => {
    if (err) {
      const message = err.code === "LIMIT_FILE_SIZE"
        ? `单张图片不能超过 ${env.upload.maxSizeMb}MB`
        : err.message || "上传失败";
      return fail(res, 400, 40020, message);
    }

    const files = req.files || [];
    if (!files.length) {
      return fail(res, 400, 40020, "请选择要上传的图片（字段名 files）");
    }

    const folder = req.body.folder || "common";
    const allowedFolders = ["common", "avatar", "course", "post", "work", "studio", "cert"];
    const safeFolder = allowedFolders.includes(folder) ? folder : "common";

    try {
      const urls = [];
      for (const file of files) {
        const ext = path.extname(file.originalname || "").slice(1).toLowerCase() || "png";
        const url = await saveImage(file.buffer, { ext, folder: safeFolder });
        urls.push(url);
      }
      return ok(res, { urls, storage: isOssEnabled() ? "oss" : "local" });
    } catch (error) {
      return fail(res, 500, 50000, error.message || "图片保存失败");
    }
  });
});

module.exports = router;
