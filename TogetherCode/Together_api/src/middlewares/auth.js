const jwt = require("jsonwebtoken");
const env = require("../config/env");
const { User, AdminAccount } = require("../models");

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

async function requireAuthOptional(req, res, next) {
  const authHeader = req.headers.authorization || "";
  const token = authHeader.startsWith("Bearer ")
    ? authHeader.slice(7)
    : null;

  if (!token) {
    return next();
  }

  try {
    const decoded = jwt.verify(token, env.jwtSecret);
    const user = await User.findByPk(decoded.userId);
    if (user) {
      req.user = {
        userId: String(user.user_id),
        role: user.current_role,
        phone: user.phone
      };
    }
  } catch (_error) {
    // 可选登录：token 无效时按游客处理
  }
  return next();
}

function requireRole(...roles) {  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        code: 40100,
        message: "Unauthorized"
      });
    }

    if (!roles.includes(Number(req.user.role))) {
      return res.status(403).json({
        code: 40300,
        message: "Forbidden"
      });
    }

    return next();
  };
}

function requireBackofficeAuth(scope) {
  return async (req, res, next) => {
    const authHeader = req.headers.authorization || "";
    const token = authHeader.startsWith("Bearer ")
      ? authHeader.slice(7)
      : null;

    if (!token) {
      return res.status(401).json({
        code: 40110,
        message: "Unauthorized"
      });
    }

    try {
      const decoded = jwt.verify(token, env.jwtSecret);
      if (decoded.tokenType !== "backoffice") {
        return res.status(401).json({
          code: 40111,
          message: "Invalid token"
        });
      }

      if (scope && decoded.scope !== scope) {
        return res.status(403).json({
          code: 40310,
          message: "Forbidden"
        });
      }

      const account = await AdminAccount.findByPk(decoded.adminId);
      if (!account || Number(account.status) !== 1) {
        return res.status(401).json({
          code: 40112,
          message: "Admin account not found"
        });
      }

      req.admin = {
        adminId: String(account.admin_id),
        userId: account.user_id ? String(account.user_id) : null,
        username: account.username,
        role: account.role,
        studioId: account.studio_id ? String(account.studio_id) : null,
        scope: decoded.scope
      };

      return next();
    } catch (_error) {
      return res.status(401).json({
        code: 40113,
        message: "Invalid token"
      });
    }
  };
}

module.exports = {
  requireAuth,
  requireAuthOptional,
  requireRole,
  requireBackofficeAuth
};
