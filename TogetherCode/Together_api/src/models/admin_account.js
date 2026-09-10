const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const AdminAccount = sequelize.define(
    "AdminAccount",
    {
      admin_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      user_id: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      username: {
        type: DataTypes.STRING(40),
        allowNull: false,
        unique: true
      },
      password_hash: {
        type: DataTypes.STRING(100),
        allowNull: false
      },
      role: {
        type: DataTypes.STRING(32),
        allowNull: false
      },
      studio_id: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      status: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 1
      }
    },
    {
      tableName: "admin_accounts",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  AdminAccount.associate = (models) => {
    AdminAccount.belongsTo(models.User, { foreignKey: "user_id", as: "user" });
    AdminAccount.belongsTo(models.StudioProfile, { foreignKey: "studio_id", as: "studio" });
  };

  AdminAccount.beforeValidate((instance) => {
    if (!instance.admin_id) {
      instance.admin_id = generateId();
    }
  });

  return AdminAccount;
};
