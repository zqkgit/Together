const { ok, fail } = require("../utils/response");
const {
  listChildren,
  getChildDetail,
  createChild,
  updateChild
} = require("../services/childService");

async function getChildren(req, res) {
  try {
    const data = await listChildren(req.user.userId);
    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function getChild(req, res) {
  try {
    const data = await getChildDetail(req.user.userId, req.params.id);
    if (!data) {
      return fail(res, 404, 40430, "Child not found");
    }

    return ok(res, data);
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function postChild(req, res) {
  try {
    const data = await createChild(req.user.userId, req.body);
    return ok(res, data, "child created");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

async function putChild(req, res) {
  try {
    const data = await updateChild(req.user.userId, req.params.id, req.body);
    if (!data) {
      return fail(res, 404, 40430, "Child not found");
    }

    return ok(res, data, "child updated");
  } catch (error) {
    return fail(res, 500, 50000, error.message || "Internal server error");
  }
}

module.exports = {
  getChildren,
  getChild,
  postChild,
  putChild
};
