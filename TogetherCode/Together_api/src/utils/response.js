function ok(res, data = null, message = "ok") {
  return res.json({
    code: 0,
    message,
    data
  });
}

function fail(res, status, code, message) {
  return res.status(status).json({
    code,
    message
  });
}

module.exports = {
  ok,
  fail
};
