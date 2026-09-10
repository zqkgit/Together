const { validationResult } = require("express-validator");
const { fail } = require("../utils/response");

function validateRequest(req, res, next) {
  const result = validationResult(req);
  if (!result.isEmpty()) {
    return fail(res, 400, 40002, result.array()[0].msg);
  }

  return next();
}

module.exports = {
  validateRequest
};
