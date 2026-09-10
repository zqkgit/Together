function getHealth(_req, res) {
  res.json({
    code: 0,
    message: "ok",
    data: {
      service: "together-api",
      now: new Date().toISOString()
    }
  });
}

module.exports = {
  getHealth
};
