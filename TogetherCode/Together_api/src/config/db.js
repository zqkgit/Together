const { createClient } = require("redis");
const env = require("./env");
const { sequelize } = require("../models");

const redis = createClient({ url: env.redisUrl });

async function connectRedis() {
  if (!redis.isOpen) {
    await redis.connect();
  }
  return redis;
}

module.exports = {
  sequelize,
  redis,
  connectRedis
};
