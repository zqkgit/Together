const fs = require("fs");
const path = require("path");
const { Sequelize, DataTypes } = require("sequelize");
const env = require("../config/env");

const basename = path.basename(__filename);
const sequelize = new Sequelize(env.db);
const db = {};

fs.readdirSync(__dirname)
  .filter((file) => {
    return file !== basename && file.endsWith(".js");
  })
  .forEach((file) => {
    const defineModel = require(path.join(__dirname, file));
    const model = defineModel(sequelize, DataTypes);
    db[model.name] = model;
  });

Object.keys(db).forEach((modelName) => {
  if (typeof db[modelName].associate === "function") {
    db[modelName].associate(db);
  }
});

db.sequelize = sequelize;
db.Sequelize = Sequelize;

module.exports = db;
