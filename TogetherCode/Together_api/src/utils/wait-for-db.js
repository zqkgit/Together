const { sequelize } = require("../models");

async function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function main() {
  const retries = 30;

  for (let index = 1; index <= retries; index += 1) {
    try {
      await sequelize.authenticate();
      console.log("Database is ready");
      await sequelize.close();
      process.exit(0);
    } catch (error) {
      console.log(`Waiting for database... ${index}/${retries}`);
      if (index === retries) {
        console.error("Database connection failed:", error.message);
        process.exit(1);
      }
      await sleep(2000);
    }
  }
}

main();
