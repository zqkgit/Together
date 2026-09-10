const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const UserRole = sequelize.define(
    "UserRole",
    {
      id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      user_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      role: {
        type: DataTypes.SMALLINT,
        allowNull: false
      },
      ref_id: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      verified: {
        type: DataTypes.BOOLEAN,
        allowNull: false,
        defaultValue: false
      }
    },
    {
      tableName: "user_roles",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  UserRole.associate = (models) => {
    UserRole.belongsTo(models.User, { foreignKey: "user_id", as: "user" });
  };

  UserRole.beforeValidate((instance) => {
    if (!instance.id) {
      instance.id = generateId();
    }
  });

  return UserRole;
};
