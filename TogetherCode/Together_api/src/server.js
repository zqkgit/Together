const http = require("http");
const app = require("./app");
const env = require("./config/env");
const { sequelize, connectRedis } = require("./config/db");
const wsHub = require("./ws/hub");

async function bootstrap() {
  sequelize
    .authenticate()
    .then(() => console.log("MySQL connected"))
    .catch((error) => console.warn("MySQL not ready:", error.message));

  connectRedis()
    .then(() => console.log("Redis connected"))
    .catch((error) => console.warn("Redis not ready:", error.message));

  const server = http.createServer(app);

  // WebSocket 实时通道（与 HTTP 同端口 /ws 升级）
  wsHub.attach(server);

  server.listen(env.port, () => {
    console.log(`Together API running at http://localhost:${env.port}${env.apiPrefix}`);
    console.log(`WebSocket running at ws://localhost:${env.port}/ws`);
  });
}

bootstrap();
