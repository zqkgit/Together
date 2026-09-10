const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const env = require("../config/env");

function createAccessToken(user) {
  return jwt.sign(
    {
      userId: String(user.user_id),
      role: user.current_role,
      phone: user.phone
    },
    env.jwtSecret,
    { expiresIn: env.jwtExpiresIn }
  );
}

function createBackofficeAccessToken(account, scope) {
  return jwt.sign(
    {
      tokenType: "backoffice",
      adminId: String(account.admin_id),
      userId: account.user_id ? String(account.user_id) : null,
      username: account.username,
      role: account.role,
      studioId: account.studio_id ? String(account.studio_id) : null,
      scope
    },
    env.jwtSecret,
    { expiresIn: env.jwtExpiresIn }
  );
}

function createRefreshToken() {
  return crypto.randomBytes(24).toString("hex");
}

module.exports = {
  createAccessToken,
  createBackofficeAccessToken,
  createRefreshToken
};
