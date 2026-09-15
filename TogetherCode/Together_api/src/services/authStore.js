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
      city: user.city,
      signature: user.signature
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
  const code = "1234";

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

  if (user.status === 0) {
    return { error: { status: 403, code: 40302, message: "账号已注销，无法登录" } };
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

/**
 * 微信一键登录：
 * - code → code2session 拿 openid/unionid
 * - 已绑定 unionid 的用户直接登录
 * - 未绑定时需带手机号+短信验证码完成绑定（注册或给已有账号绑定 unionid）
 */
async function wxLogin({ code, phone, smsCode }) {
  const wx = require("./wxService");
  const result = await wx.code2session(code);
  if (result.error) {
    return result;
  }
  if (result.notConfigured) {
    return { error: { status: 503, code: 50380, message: "微信登录未配置（请配置 WX_APP_ID / WX_APP_SECRET）" } };
  }

  const { openid, unionid } = result;
  const unionId = unionid || openid;

  const existing = await User.findOne({ where: { wx_unionid: unionId } });
  if (existing) {
    return sequelize.transaction(async (transaction) => {
      await existing.update(
        { last_login_at: new Date(), login_fail_count: 0, locked_until: null },
        { transaction }
      );
      return { data: await issueTokens(existing, transaction) };
    });
  }

  // 未绑定：需要手机号 + 验证码
  if (!phone || !smsCode) {
    return { error: { status: 400, code: 40084, message: "微信未绑定手机号，请提供 phone + sms_code" } };
  }

  return sequelize.transaction(async (transaction) => {
    const record = await consumeVerificationCode(String(phone), String(smsCode), transaction);
    if (!record) {
      return { error: { status: 400, code: 40001, message: "Invalid verification code" } };
    }

    const user = await getUserByPhone(phone);
    if (user) {
      // 已有账号：绑定 unionid 后登录
      await user.update({ wx_unionid: unionId }, { transaction });
      return { data: await issueTokens(user, transaction) };
    }

    // 新用户：注册家长角色并绑定
    const created = await User.create(
      {
        user_id: generateId(),
        phone,
        wx_unionid: unionId,
        nickname: `用户${String(phone).slice(-4)}`,
        password_hash: bcrypt.hashSync(DEFAULT_PASSWORD, 10),
        current_role: 1,
        status: 1,
        terms_agreed_at: new Date()
      },
      { transaction }
    );
    await UserRole.create(
      {
        id: generateId(),
        user_id: created.user_id,
        role: 1,
        verified: true
      },
      { transaction }
    );
    return { data: await issueTokens(created, transaction) };
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

const ROLE_TEXT = {
  1: "家长",
  2: "老师",
  3: "工作室"
};

/**
 * 切换当前角色（家长 ↔ 老师 ↔ 工作室）
 * 仅允许切换到已开通的角色（user_roles 存在），更新 current_role 并重发 access token
 */
async function switchRole(userId, role) {
  const roleValue = Number(role);
  if (![1, 2, 3].includes(roleValue)) {
    return { error: { status: 400, code: 40000, message: "角色不合法" } };
  }

  const user = await getUserById(userId);
  if (!user) {
    return { error: { status: 404, code: 40402, message: "User not found" } };
  }

  const roleRecord = await UserRole.findOne({
    where: { user_id: userId, role: roleValue }
  });
  if (!roleRecord) {
    return { error: { status: 400, code: 40003, message: `该账号未开通「${ROLE_TEXT[roleValue] || "该"}」角色` } };
  }

  await user.update({ current_role: roleValue });

  const payload = await buildUserPayload(user);
  return {
    data: {
      ...payload,
      access_token: createAccessToken(user),
      token_type: "Bearer"
    }
  };
}

/**
 * 完善资料（注册引导 / 个人中心编辑）
 * 支持：nickname / avatar / city / signature；terms_agreed: true 时留痕协议同意时间
 */
async function updateProfile(userId, payload = {}) {
  const user = await getUserById(userId);
  if (!user) {
    return { error: { status: 404, code: 40402, message: "User not found" } };
  }

  const changes = {};

  if (payload.nickname !== undefined && payload.nickname !== null) {
    const nickname = String(payload.nickname).trim();
    if (!nickname) {
      return { error: { status: 400, code: 40000, message: "昵称不能为空" } };
    }
    if (nickname.length > 40) {
      return { error: { status: 400, code: 40000, message: "昵称长度不能超过 40 字" } };
    }
    changes.nickname = nickname;
  }

  if (payload.avatar !== undefined && payload.avatar !== null) {
    const avatar = String(payload.avatar).trim();
    if (avatar.length > 255) {
      return { error: { status: 400, code: 40000, message: "头像地址过长" } };
    }
    changes.avatar = avatar;
  }

  if (payload.city !== undefined && payload.city !== null) {
    const city = String(payload.city).trim();
    if (city.length > 60) {
      return { error: { status: 400, code: 40000, message: "城市名称过长" } };
    }
    changes.city = city;
  }

  if (payload.signature !== undefined && payload.signature !== null) {
    const signature = String(payload.signature).trim();
    if (signature.length > 255) {
      return { error: { status: 400, code: 40000, message: "个性签名不能超过 255 字" } };
    }
    changes.signature = signature;
  }

  if (payload.terms_agreed === true && !user.terms_agreed_at) {
    changes.terms_agreed_at = new Date();
  }

  if (Object.keys(changes).length) {
    await user.update(changes);
  }

  return { data: await buildUserPayload(user) };
}

/**
 * 修改登录密码
 * 校验原密码后更新 password_hash
 */
async function changePassword(userId, { old_password, new_password }) {
  const user = await getUserById(userId);
  if (!user) {
    return { error: { status: 404, code: 40402, message: "User not found" } };
  }

  const matched = bcrypt.compareSync(String(old_password || ""), user.password_hash || "");
  if (!matched) {
    return { error: { status: 400, code: 40001, message: "原密码不正确" } };
  }

  const password = String(new_password || "").trim();
  if (password.length < 6 || password.length > 20) {
    return { error: { status: 400, code: 40000, message: "新密码长度需为 6-20 位" } };
  }

  await user.update({ password_hash: bcrypt.hashSync(password, 10) });
  return { data: { updated: true } };
}

/**
 * 更换绑定手机号
 * 校验新手机号验证码 + 手机号未被占用
 */
async function changePhone(userId, { phone, code }) {
  const user = await getUserById(userId);
  if (!user) {
    return { error: { status: 404, code: 40402, message: "User not found" } };
  }

  const newPhone = String(phone || "").trim();
  if (!/^1\d{10}$/.test(newPhone)) {
    return { error: { status: 400, code: 40000, message: "手机号格式不正确" } };
  }

  const existed = await getUserByPhone(newPhone);
  if (existed && String(existed.user_id) !== String(userId)) {
    return { error: { status: 400, code: 40003, message: "该手机号已被其他账号绑定" } };
  }

  return sequelize.transaction(async (transaction) => {
    const record = await consumeVerificationCode(newPhone, code, transaction);
    if (!record) {
      return { error: { status: 400, code: 40001, message: "验证码错误或已过期" } };
    }
    await user.update({ phone: newPhone }, { transaction });
    return { data: { phone: newPhone } };
  });
}

/**
 * 设置/修改支付密码（6 位数字，bcrypt 存储）
 */
async function setPayPassword(userId, { pay_password }) {
  const user = await getUserById(userId);
  if (!user) {
    return { error: { status: 404, code: 40402, message: "User not found" } };
  }

  const payPassword = String(pay_password || "").trim();
  if (!/^\d{6}$/.test(payPassword)) {
    return { error: { status: 400, code: 40000, message: "支付密码需为 6 位数字" } };
  }

  await user.update({ pay_password_hash: bcrypt.hashSync(payPassword, 10) });
  return { data: { updated: true } };
}

/**
 * 注销账号（软注销）
 * 校验当前手机号验证码后置 status=0
 */
async function deactivateAccount(userId, { code }) {
  const user = await getUserById(userId);
  if (!user) {
    return { error: { status: 404, code: 40402, message: "User not found" } };
  }

  return sequelize.transaction(async (transaction) => {
    const record = await consumeVerificationCode(user.phone, code, transaction);
    if (!record) {
      return { error: { status: 400, code: 40001, message: "验证码错误或已过期" } };
    }
    await user.update({ status: 0 }, { transaction });
    return { data: { deactivated: true } };
  });
}

module.exports = {
  sendCode,
  register,
  loginWithCode,
  loginWithPassword,
  wxLogin,
  refreshAccessToken,
  logout,
  getProfile,
  updateProfile,
  switchRole,
  changePassword,
  changePhone,
  setPayPassword,
  deactivateAccount
};
