const path = require("path");
const dotenv = require("dotenv");

dotenv.config({ path: path.resolve(__dirname, "../../.env") });

const shared = {
  host: process.env.DB_HOST || "127.0.0.1",
  port: Number(process.env.DB_PORT || 3306),
  username: process.env.DB_USER || "root",
  password: process.env.DB_PASSWORD || "",
  dialect: "mysql",
  timezone: "+08:00",
  define: {
    underscored: true
  },
  logging: process.env.DB_LOGGING === "true" ? console.log : false
};

module.exports = {
  development: {
    ...shared,
    database: process.env.DB_NAME || "together"
  },
  test: {
    ...shared,
    database: process.env.DB_NAME_TEST || process.env.DB_NAME || "together_test"
  },
  production: {
    ...shared,
    database: process.env.DB_NAME || "together"
  }
};
