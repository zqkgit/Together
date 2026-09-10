const app = require("./app");
const env = require("./config/env");
const { sequelize, connectRedis } = require("./config/db");

async function bootstrap() {
  sequelize
    .authenticate()
    .then(() => console.log("MySQL connected"))
    .catch((error) => console.warn("MySQL not ready:", error.message));

  connectRedis()
    .then(() => console.log("Redis connected"))
    .catch((error) => console.warn("Redis not ready:", error.message));

  app.listen(env.port, () => {
    console.log(`Together API running at http://localhost:${env.port}${env.apiPrefix}`);
  });
}

bootstrap();
