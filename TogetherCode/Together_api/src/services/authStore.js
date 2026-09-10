const bcrypt = require("bcryptjs");
const { Op } = require("sequelize");
const env = require("../config/env");
const { sequelize, User, UserRole, AuthVerificationCode, RefreshToken } = require("../models");
const { createAccessToken, createRefreshToken } = require("../utils/token");
const { generateId } = require("../utils/id");

const CODE_TTL_SECONDS = 300;
const LOGIN_FAIL_LIMIT = 5;
const LOCK_MINUTES = 15;
const DEFAULT_PASSWORD = "123456";

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

async function buildUserPayload(userRecord) {
  const user = userRecord instanceof User ? userRecord : await User.findByPk(userRecord.user_id);
  const roles = await UserRole.findAll({
    where: { user_id: user.user_id },
    order: [["role", "ASC"]]
  });

  return {
    user: {
      user_id: String(user.user_id),
      phone: user.phone,
      nickname: user.nickname,
      avatar: user.avatar,
      city: user.city
    },
    current_role: user.current_role,
    roles: roles.map((item) => item.role)
  };
}

async function issueTokens(user, transaction) {
  const accessToken = createAccessToken(user);
  const refreshToken = createRefreshToken();
  const expiresAt = addDuration(new Date(), env.jwtRefreshExpiresIn);

  await RefreshToken.create(
    {
      id: generateId(),
      user_id: user.user_id,
      token: refreshToken,
      expires_at: expiresAt
    },
    { transaction }
  );

  return {
    access_token: accessToken,
    refresh_token: refreshToken,
    ...(await buildUserPayload(user))
  };
}

async function getUserByPhone(phone) {
  return User.findOne({
    where: {
      phone,
      deleted_at: null
    }
  });
}

async function getUserById(userId) {
  return User.findByPk(userId);
}

async function consumeVerificationCode(phone, code, transaction) {
  const record = await AuthVerificationCode.findOne({
    where: {
      phone,
      code,
      consumed_at: null,
      expires_at: {
        [Op.gt]: new Date()
      }
    },
    order: [["created_at", "DESC"]],
    transaction,
    lock: transaction ? transaction.LOCK.UPDATE : undefined
  });

  if (!record) {
    return null;
  }

  record.consumed_at = new Date();
  await record.save({ transaction });
  return record;
}

async function sendCode(phone) {
  const latest = await AuthVerificationCode.findOne({
    where: {
      phone,
      created_at: {
        [Op.gt]: new Date(Date.now() - 60 * 1000)
      }
    },
    order: [["created_at", "DESC"]]
  });

  if (latest) {
    return {
      error: { status: 429, code: 42901, message: "Code requested too frequently" }
    };
  }

  const user = await getUserByPhone(phone);
  const code = "123456";

  await AuthVerificationCode.create({
    id: generateId(),
    phone,
    code,
    purpose: user ? "login" : "register",
    expires_at: new Date(Date.now() + CODE_TTL_SECONDS * 1000)
  });

  return {
    data: {
      ttl: CODE_TTL_SECONDS,
      is_new_user: !user,
      debug_code: code
    }
  };
}

async function register({ phone, code, password }) {
  const exists = await getUserByPhone(phone);
  if (exists) {
    return { error: { status: 409, code: 40901, message: "Phone already registered" } };
  }

  return sequelize.transaction(async (transaction) => {
    const record = await consumeVerificationCode(phone, code, transaction);
    if (!record) {
      return { error: { status: 400, code: 40001, message: "Invalid verification code" } };
    }

    const user = await User.create(
      {
        user_id: generateId(),
        phone,
        nickname: `用户${phone.slice(-4)}`,
        password_hash: bcrypt.hashSync(password || DEFAULT_PASSWORD, 10),
        current_role: 1,
        status: 1,
        terms_agreed_at: new Date()
      },
      { transaction }
    );

    await UserRole.create(
      {
        id: generateId(),
        user_id: user.user_id,
        role: 1,
        verified: true
      },
      { transaction }
    );

    return {
      data: await issueTokens(user, transaction)
    };
  });
}

async function loginWithCode({ phone, code }) {
  const user = await getUserByPhone(phone);
  if (!user) {
    return { error: { status: 404, code: 40401, message: "Phone not registered" } };
  }

  return sequelize.transaction(async (transaction) => {
    const record = await consumeVerificationCode(phone, code, transaction);
    if (!record) {
      return { error: { status: 400, code: 40001, message: "Invalid verification code" } };
    }

    await user.update(
      {
        login_fail_count: 0,
        locked_until: null,
        last_login_at: new Date()
      },
      { transaction }
    );

    return {
      data: await issueTokens(user, transaction)
    };
  });
}

async function loginWithPassword({ phone, password }) {
  const user = await getUserByPhone(phone);
  if (!user) {
    return { error: { status: 404, code: 40401, message: "Phone not registered" } };
  }

  if (user.locked_until && new Date(user.locked_until).getTime() > Date.now()) {
    return { error: { status: 423, code: 42301, message: "Account temporarily locked" } };
  }

  const matched = bcrypt.compareSync(password, user.password_hash || "");
  if (!matched) {
    const nextFailCount = Number(user.login_fail_count || 0) + 1;
    const payload = {
      login_fail_count: nextFailCount
    };

    if (nextFailCount >= LOGIN_FAIL_LIMIT) {
      payload.locked_until = new Date(Date.now() + LOCK_MINUTES * 60 * 1000);
      payload.login_fail_count = 0;
    }

    await user.update(payload);
    return { error: { status: 401, code: 40102, message: "Phone or password incorrect" } };
  }

  return sequelize.transaction(async (transaction) => {
    await user.update(
      {
        login_fail_count: 0,
        locked_until: null,
        last_login_at: new Date()
      },
      { transaction }
    );

    return {
      data: await issueTokens(user, transaction)
    };
  });
}

async function refreshAccessToken(refreshToken) {
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
    return { error: { status: 401, code: 40103, message: "Refresh token invalid" } };
  }

  const user = await getUserById(tokenRecord.user_id);
  if (!user) {
    return { error: { status: 401, code: 40104, message: "User not found" } };
  }

  return {
    data: {
      access_token: createAccessToken(user),
      refresh_token: refreshToken
    }
  };
}

async function logout(refreshToken) {
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

async function getProfile(userId) {
  const user = await getUserById(userId);
  if (!user) {
    return null;
  }

  return buildUserPayload(user);
}

module.exports = {
  sendCode,
  register,
  loginWithCode,
  loginWithPassword,
  refreshAccessToken,
  logout,
  getProfile
};
