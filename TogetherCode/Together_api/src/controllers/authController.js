const {
  sendCode,
  register,
  loginWithCode,
  loginWithPassword,
  refreshAccessToken,
  logout,
  getProfile,
  updateProfile,
  switchRole
} = require("../services/authStore");
const {
  submitRoleApply,
  getRoleApplyStatus
} = require("../services/roleApplyService");
const { ok, fail } = require("../utils/response");

function requireFields(body, fields) {
  return fields.find((field) => !body?.[field]);
}

async function postSendCode(req, res) {
  try {
    const missing = requireFields(req.body, ["phone"]);
    if (missing) {
      return fail(res, 400, 40000, `Missing field: ${missing}`);
    }

    const result = await sendCode(req.body.phone);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }

    return ok(res, result.data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postRegister(req, res) {
  try {
    const missing = requireFields(req.body, ["phone", "code"]);
    if (missing) {
      return fail(res, 400, 40000, `Missing field: ${missing}`);
    }

    const result = await register(req.body);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }

    return ok(res, result.data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postLogin(req, res) {
  try {
    const missing = requireFields(req.body, ["phone", "code"]);
    if (missing) {
      return fail(res, 400, 40000, `Missing field: ${missing}`);
    }

    const result = await loginWithCode(req.body);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }

    return ok(res, result.data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postPasswordLogin(req, res) {
  try {
    const missing = requireFields(req.body, ["phone", "password"]);
    if (missing) {
      return fail(res, 400, 40000, `Missing field: ${missing}`);
    }

    const result = await loginWithPassword(req.body);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }

    return ok(res, result.data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postRefresh(req, res) {
  try {
    const missing = requireFields(req.body, ["refresh_token"]);
    if (missing) {
      return fail(res, 400, 40000, `Missing field: ${missing}`);
    }

    const result = await refreshAccessToken(req.body.refresh_token);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }

    return ok(res, result.data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postLogout(req, res) {
  try {
    await logout(req.body?.refresh_token);
    return ok(res, true);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getMe(req, res) {
  try {
    const profile = await getProfile(req.user.userId);
    if (!profile) {
      return fail(res, 404, 40402, "User not found");
    }

    return ok(res, profile);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// PUT /v1/me/profile · 注册引导完善资料
async function putMeProfile(req, res) {
  try {
    const result = await updateProfile(req.user.userId, req.body);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result.data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// POST /v1/auth/role/apply · 提交老师认证 / 工作室入驻
async function postRoleApply(req, res) {
  try {
    const result = await submitRoleApply(req.user.userId, req.body);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result.data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// GET /v1/auth/role/apply/:role · 认证申请状态
async function getRoleApplyStatusHandler(req, res) {
  try {
    const result = await getRoleApplyStatus(req.user.userId, req.params.role);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result.data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// POST /v1/auth/role/switch · 切换当前角色（重发 access token）
async function postRoleSwitch(req, res) {
  try {
    const result = await switchRole(req.user.userId, req.body.role);
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result.data, "角色已切换");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

module.exports = {
  postSendCode,
  postRegister,
  postLogin,
  postPasswordLogin,
  postRefresh,
  postLogout,
  getMe,
  putMeProfile,
  postRoleApply,
  getRoleApplyStatusHandler,
  postRoleSwitch
};
