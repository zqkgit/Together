const path = require("path");
const dotenv = require("dotenv");

dotenv.config({ path: path.resolve(__dirname, "../../.env") });

module.exports = {
  nodeEnv: process.env.NODE_ENV || "development",
  port: Number(process.env.PORT || 3000),
  apiPrefix: process.env.API_PREFIX || "/v1",
  adminPrefix: process.env.ADMIN_PREFIX || "/admin",
  studioPrefix: process.env.STUDIO_PREFIX || "/studio",
  frontendUrl: process.env.FRONTEND_URL || "http://127.0.0.1:5173",
  db: {
    host: process.env.DB_HOST || "127.0.0.1",
    port: Number(process.env.DB_PORT || 3306),
    database: process.env.DB_NAME || "together",
    username: process.env.DB_USER || "root",
    password: process.env.DB_PASSWORD || "",
    dialect: "mysql",
    timezone: "+08:00",
    logging: process.env.DB_LOGGING === "true" ? console.log : false,
    define: {
      underscored: true
    }
  },
  redisUrl: process.env.REDIS_URL || "redis://127.0.0.1:6379",
  jwtSecret: process.env.JWT_SECRET || "replace-me",
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || "7d",
  jwtRefreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || "30d",
  // 图片上传：配置 OSS_* 后走阿里云 OSS；未配置则回退本地静态目录（开发环境）
  upload: {
    dir: process.env.UPLOAD_DIR || path.resolve(__dirname, "../../uploads"),
    publicUrl: process.env.UPLOAD_PUBLIC_URL || "",
    maxFiles: Number(process.env.UPLOAD_MAX_FILES || 9),
    maxSizeMb: Number(process.env.UPLOAD_MAX_SIZE_MB || 10)
  },
  oss: {
    region: process.env.OSS_REGION || "",
    accessKeyId: process.env.OSS_ACCESS_KEY_ID || "",
    accessKeySecret: process.env.OSS_ACCESS_KEY_SECRET || "",
    bucket: process.env.OSS_BUCKET || "",
    publicUrl: process.env.OSS_PUBLIC_URL || ""
  },
  // 极光推送：配置 JPUSH_* 后离线推送自动生效；未配置时静默跳过（只走 WebSocket/轮询）
  jpush: {
    appKey: process.env.JPUSH_APP_KEY || "",
    masterSecret: process.env.JPUSH_MASTER_SECRET || ""
  },
  // 微信开放平台（小程序登录/支付）：未配置时微信相关能力返回"未配置"错误，不影响开发
  wx: {
    appId: process.env.WX_APP_ID || "",
    appSecret: process.env.WX_APP_SECRET || "",
    payMchId: process.env.WX_PAY_MCH_ID || "",
    payKey: process.env.WX_PAY_KEY || "",
    payNotifyUrl: process.env.WX_PAY_NOTIFY_URL || ""
  }
};
