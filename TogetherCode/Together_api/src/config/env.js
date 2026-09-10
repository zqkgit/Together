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
  jwtRefreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || "30d"
};
