const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const AuthVerificationCode = sequelize.define(
    "AuthVerificationCode",
    {
      id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      phone: {
        type: DataTypes.STRING(20),
        allowNull: false
      },
      code: {
        type: DataTypes.STRING(10),
        allowNull: false
      },
      purpose: {
        type: DataTypes.STRING(20),
        allowNull: false,
        defaultValue: "login"
      },
      expires_at: {
        type: DataTypes.DATE,
        allowNull: false
      },
      consumed_at: {
        type: DataTypes.DATE,
        allowNull: true
      }
    },
    {
      tableName: "auth_verification_codes",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  AuthVerificationCode.beforeValidate((instance) => {
    if (!instance.id) {
      instance.id = generateId();
    }
  });

  return AuthVerificationCode;
};
