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

function createRefreshToken() {
  return crypto.randomBytes(24).toString("hex");
}

module.exports = {
  createAccessToken,
  createRefreshToken
};
