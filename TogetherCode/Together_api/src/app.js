const express = require("express");
const cors = require("cors");
const morgan = require("morgan");
const env = require("./config/env");
const encryptMiddleware = require("./middlewares/encrypt");
const apiRoutes = require("./routes");
const adminRoutes = require("./routes/admin");
const studioRoutes = require("./routes/studio");

const app = express();

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(morgan(env.nodeEnv === "production" ? "combined" : "dev"));
// 本地上传文件静态服务（未配置 OSS 时的开发环境；生产环境建议由 Nginx/OSS 提供）
app.use("/uploads", express.static(env.upload.dir));
// 接口加密（API_ENCRYPT_ENABLED=true 时生效）
app.use(encryptMiddleware);

app.get("/", (_req, res) => {
  res.json({
    code: 0,
    message: "Together API bootstrap ready"
  });
});

app.use(env.apiPrefix, apiRoutes);
app.use(env.adminPrefix, adminRoutes);
app.use(env.studioPrefix, studioRoutes);

app.use((req, res) => {
  res.status(404).json({
    code: 40400,
    message: `Route not found: ${req.originalUrl}`
  });
});

module.exports = app;
