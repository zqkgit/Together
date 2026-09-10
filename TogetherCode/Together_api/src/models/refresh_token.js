const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const RefreshToken = sequelize.define(
    "RefreshToken",
    {
      id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      user_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      token: {
        type: DataTypes.STRING(128),
        allowNull: false,
        unique: true
      },
      expires_at: {
        type: DataTypes.DATE,
        allowNull: false
      },
      revoked_at: {
        type: DataTypes.DATE,
        allowNull: true
      }
    },
    {
      tableName: "refresh_tokens",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  RefreshToken.associate = (models) => {
    RefreshToken.belongsTo(models.User, { foreignKey: "user_id", as: "user" });
  };

  RefreshToken.beforeValidate((instance) => {
    if (!instance.id) {
      instance.id = generateId();
    }
  });

  return RefreshToken;
};
