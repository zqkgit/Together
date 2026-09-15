const {
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

// POST /v1/auth/wx-login · 微信一键登录（未绑定手机号时需带 phone + sms_code 完成绑定）
async function postWxLogin(req, res) {
  try {
    const result = await wxLogin({
      code: req.body.code,
      phone: req.body.phone,
      smsCode: req.body.sms_code
    });
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result.data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// POST /v1/auth/change-password · 修改登录密码
async function postChangePassword(req, res) {
  try {
    const result = await changePassword(req.user.userId, {
      old_password: req.body.old_password,
      new_password: req.body.new_password
    });
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result.data, "密码已修改");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// POST /v1/auth/change-phone · 更换绑定手机号
async function postChangePhone(req, res) {
  try {
    const result = await changePhone(req.user.userId, {
      phone: req.body.phone,
      code: req.body.code
    });
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result.data, "手机号已更换");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// POST /v1/me/pay-password · 设置支付密码
async function postSetPayPassword(req, res) {
  try {
    const result = await setPayPassword(req.user.userId, {
      pay_password: req.body.pay_password
    });
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result.data, "支付密码已设置");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

// POST /v1/auth/deactivate · 注销账号（短信验证码确认）
async function postDeactivate(req, res) {
  try {
    const result = await deactivateAccount(req.user.userId, {
      code: req.body.code
    });
    if (result.error) {
      return fail(res, result.error.status, result.error.code, result.error.message);
    }
    return ok(res, result.data, "账号已注销");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

module.exports = {
  postSendCode,
  postRegister,
  postLogin,
  postPasswordLogin,
  postWxLogin,
  postRefresh,
  postLogout,
  getMe,
  putMeProfile,
  postRoleApply,
  getRoleApplyStatusHandler,
  postRoleSwitch,
  postChangePassword,
  postChangePhone,
  postSetPayPassword,
  postDeactivate
};
