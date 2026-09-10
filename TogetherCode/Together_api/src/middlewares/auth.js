const jwt = require("jsonwebtoken");
const env = require("../config/env");
const { User } = require("../models");

async function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization || "";
  const token = authHeader.startsWith("Bearer ")
    ? authHeader.slice(7)
    : null;

  if (!token) {
    return res.status(401).json({
      code: 40100,
      message: "Unauthorized"
    });
  }

  try {
    const decoded = jwt.verify(token, env.jwtSecret);
    const user = await User.findByPk(decoded.userId);

    if (!user) {
      return res.status(401).json({
        code: 40102,
        message: "User not found"
      });
    }

    req.user = {
      userId: String(user.user_id),
      role: user.current_role,
      phone: user.phone
    };
    return next();
  } catch (_error) {
    return res.status(401).json({
      code: 40101,
      message: "Invalid token"
    });
  }
}

module.exports = {
  requireAuth
};
