const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const UserDevice = sequelize.define(
    "UserDevice",
    {
      device_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      user_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      registration_id: {
        type: DataTypes.STRING(128),
        allowNull: false
      },
      platform: {
        type: DataTypes.STRING(20),
        allowNull: false,
        defaultValue: "android"
      },
      status: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 1
      }
    },
    {
      tableName: "user_devices",
      createdAt: "created_at",
      updatedAt: "updated_at",
      indexes: [{ unique: true, fields: ["registration_id"] }]
    }
  );

  UserDevice.associate = (models) => {
    UserDevice.belongsTo(models.User, { foreignKey: "user_id", as: "user" });
  };

  UserDevice.beforeValidate((instance) => {
    if (!instance.device_id) {
      instance.device_id = generateId();
    }
  });

  return UserDevice;
};
