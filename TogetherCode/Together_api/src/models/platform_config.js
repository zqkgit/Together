const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const PlatformConfig = sequelize.define(
    "PlatformConfig",
    {
      config_id: { type: DataTypes.BIGINT, primaryKey: true },
      config_key: { type: DataTypes.STRING(64), allowNull: false, unique: true },
      config_value: { type: DataTypes.TEXT, allowNull: true },
      description: { type: DataTypes.STRING(255), allowNull: true },
      updated_by: { type: DataTypes.BIGINT, allowNull: true }
    },
    {
      tableName: "platform_configs",
      underscored: true
    }
  );

  PlatformConfig.beforeValidate((instance) => {
    if (!instance.config_id) {
      instance.config_id = generateId();
    }
  });

  return PlatformConfig;
};
