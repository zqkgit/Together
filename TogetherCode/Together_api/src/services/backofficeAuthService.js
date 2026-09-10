const bcrypt = require("bcryptjs");
const { Op } = require("sequelize");
const env = require("../config/env");
const { sequelize, AdminAccount, User, StudioProfile, RefreshToken } = require("../models");
const { createBackofficeAccessToken, createRefreshToken } = require("../utils/token");
const { generateId } = require("../utils/id");

const BACKOFFICE_SCOPES = {
  platform: ["platform_super", "platform_ops"],
  studio: ["studio_owner", "studio_ops"]
};

function addDuration(date, duration) {
  const unit = duration.slice(-1);
  const value = Number(duration.slice(0, -1));
  const next = new Date(date.getTime());

  if (unit === "d") {
    next.setDate(next.getDate() + value);
  } else if (unit === "h") {
    next.setHours(next.getHours() + value);
  } else if (unit === "m") {
    next.setMinutes(next.getMinutes() + value);
  } else {
    next.setDate(next.getDate() + 30);
  }

  return next;
}

function normalizeAccount(account, scope) {
  return {
    admin_id: String(account.admin_id),
    user_id: account.user_id ? String(account.user_id) : null,
    username: account.username,
    role: account.role,
    scope,
    studio_id: account.studio_id ? String(account.studio_id) : null,
    studio: account.studio
      ? {
          studio_id: String(account.studio.studio_id),
          name: account.studio.name,
          status: account.studio.status
        }
      : null,
    user: account.user
      ? {
          user_id: String(account.user.user_id),
          phone: account.user.phone,
          nickname: account.user.nickname,
          avatar: account.user.avatar
        }
      : null
  };
}

async function findBackofficeAccountByUsername(username, scope, transaction) {
  const roles = BACKOFFICE_SCOPES[scope] || [];
  if (!roles.length) {
    throw new Error("Backoffice scope is invalid");
  }

  return AdminAccount.findOne({
    where: {
      username,
      role: {
        [Op.in]: roles
      }
    },
    include: [
      {
        model: User,
        as: "user",
        attributes: ["user_id", "phone", "nickname", "avatar"]
      },
      {
        model: StudioProfile,
        as: "studio",
        attributes: ["studio_id", "name", "status"]
      }
    ],
    transaction
  });
}

async function findBackofficeAccountById(adminId, scope, transaction) {
  const roles = BACKOFFICE_SCOPES[scope] || [];
  if (!roles.length) {
    throw new Error("Backoffice scope is invalid");
  }

  return AdminAccount.findOne({
    where: {
      admin_id: adminId,
      role: {
        [Op.in]: roles
      }
    },
    include: [
      {
        model: User,
        as: "user",
        attributes: ["user_id", "phone", "nickname", "avatar"]
      },
      {
        model: StudioProfile,
        as: "studio",
        attributes: ["studio_id", "name", "status"]
      }
    ],
    transaction
  });
}

async function issueBackofficeTokens(account, scope, transaction) {
  const accessToken = createBackofficeAccessToken(account, scope);
  const refreshToken = `${account.admin_id}.${createRefreshToken()}`;
  const expiresAt = addDuration(new Date(), env.jwtRefreshExpiresIn);

  if (!account.user_id) {
    throw new Error("Admin account missing user binding");
  }

  await RefreshToken.create(
    {
      id: generateId(),
      user_id: account.user_id,
      token: refreshToken,
      expires_at: expiresAt
    },
    { transaction }
  );

  return {
    access_token: accessToken,
    refresh_token: refreshToken,
    account: normalizeAccount(account, scope)
  };
}

async function loginBackoffice(scope, { username, password }) {
  const account = await findBackofficeAccountByUsername(username, scope);
  if (!account || Number(account.status) !== 1) {
    return { error: { status: 404, code: 40410, message: "Admin account not found" } };
  }

  const matched = bcrypt.compareSync(password, account.password_hash || "");
  if (!matched) {
    return { error: { status: 401, code: 40120, message: "Username or password incorrect" } };
  }

  return sequelize.transaction(async (transaction) => {
    const freshAccount = await findBackofficeAccountById(account.admin_id, scope, transaction);
    return {
      data: await issueBackofficeTokens(freshAccount, scope, transaction)
    };
  });
}

async function refreshBackofficeAccessToken(scope, refreshToken) {
  const [adminId] = String(refreshToken || "").split(".");
  if (!adminId) {
    return { error: { status: 401, code: 40121, message: "Refresh token invalid" } };
  }

  const tokenRecord = await RefreshToken.findOne({
    where: {
      token: refreshToken,
      revoked_at: null,
      expires_at: {
        [Op.gt]: new Date()
      }
    }
  });

  if (!tokenRecord) {
    return { error: { status: 401, code: 40121, message: "Refresh token invalid" } };
  }

  const account = await findBackofficeAccountById(adminId, scope);
  if (!account || !account.user_id || String(account.user_id) !== String(tokenRecord.user_id)) {
    return { error: { status: 401, code: 40122, message: "Admin account not found" } };
  }

  return {
    data: {
      access_token: createBackofficeAccessToken(account, scope),
      refresh_token: refreshToken,
      account: normalizeAccount(account, scope)
    }
  };
}

async function logoutBackoffice(refreshToken) {
  if (!refreshToken) {
    return { data: true };
  }

  await RefreshToken.update(
    { revoked_at: new Date() },
    {
      where: {
        token: refreshToken,
        revoked_at: null
      }
    }
  );

  return { data: true };
}

async function getBackofficeProfile(scope, adminId) {
  const account = await findBackofficeAccountById(adminId, scope);
  if (!account || Number(account.status) !== 1) {
    return null;
  }

  return normalizeAccount(account, scope);
}

module.exports = {
  loginBackoffice,
  refreshBackofficeAccessToken,
  logoutBackoffice,
  getBackofficeProfile
};
