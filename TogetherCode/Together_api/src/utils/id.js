const crypto = require("crypto");

function generateId() {
  const timestamp = Date.now().toString();
  const random = crypto.randomInt(100000, 999999).toString();
  return `${timestamp}${random}`;
}

module.exports = {
  generateId
};
