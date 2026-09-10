const { sequelize, redis, connectRedis } = require("../config/db");

async function main() {
  try {
    await sequelize.authenticate();
    await connectRedis();
    console.log("mysql: ok");
    console.log("redis: ok");
  } catch (error) {
    console.error("dependency check failed:", error.message);
    process.exitCode = 1;
  } finally {
    await sequelize.close().catch(() => {});
    if (redis.isOpen) {
      await redis.quit().catch(() => {});
    }
  }
}

main();
