const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const Notification = sequelize.define(
    "Notification",
    {
      notification_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      user_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      type: {
        type: DataTypes.STRING(30),
        allowNull: false
      },
      title: {
        type: DataTypes.STRING(120),
        allowNull: false
      },
      content: {
        type: DataTypes.STRING(500),
        allowNull: false
      },
      ref_type: {
        type: DataTypes.STRING(30),
        allowNull: true
      },
      ref_id: {
        type: DataTypes.STRING(64),
        allowNull: true
      },
      is_read: {
        type: DataTypes.BOOLEAN,
        allowNull: false,
        defaultValue: false
      }
    },
    {
      tableName: "notifications",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  Notification.associate = (models) => {
    Notification.belongsTo(models.User, { foreignKey: "user_id", as: "user" });
  };

  Notification.beforeValidate((instance) => {
    if (!instance.notification_id) {
      instance.notification_id = generateId();
    }
  });

  return Notification;
};
