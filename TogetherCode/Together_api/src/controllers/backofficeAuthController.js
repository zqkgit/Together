const { ok, fail } = require("../utils/response");
const {
  loginBackoffice,
  refreshBackofficeAccessToken,
  logoutBackoffice,
  getBackofficeProfile
} = require("../services/backofficeAuthService");

function requireFields(body, fields) {
  return fields.find((field) => !body?.[field]);
}

function createBackofficeAuthController(scope) {
  async function postLogin(req, res) {
    try {
      const missing = requireFields(req.body, ["username", "password"]);
      if (missing) {
        return fail(res, 400, 40010, `Missing field: ${missing}`);
      }

      const result = await loginBackoffice(scope, req.body);
      if (result.error) {
        return fail(res, result.error.status, result.error.code, result.error.message);
      }

      return ok(res, result.data, "login success");
    } catch (error) {
      return fail(res, 500, 50000, error.message || "Internal server error");
    }
  }

  async function postRefresh(req, res) {
    try {
      const missing = requireFields(req.body, ["refresh_token"]);
      if (missing) {
        return fail(res, 400, 40010, `Missing field: ${missing}`);
      }

      const result = await refreshBackofficeAccessToken(scope, req.body.refresh_token);
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
      await logoutBackoffice(req.body?.refresh_token);
      return ok(res, true);
    } catch (error) {
      return fail(res, 500, 50000, error.message || "Internal server error");
    }
  }

  async function getMe(req, res) {
    try {
      const profile = await getBackofficeProfile(scope, req.admin.adminId);
      if (!profile) {
        return fail(res, 404, 40410, "Admin account not found");
      }

      return ok(res, profile);
    } catch (error) {
      return fail(res, 500, 50000, error.message || "Internal server error");
    }
  }

  return {
    postLogin,
    postRefresh,
    postLogout,
    getMe
  };
}

const platformAuthController = createBackofficeAuthController("platform");
const studioAuthController = createBackofficeAuthController("studio");

module.exports = {
  platformAuthController,
  studioAuthController
};
