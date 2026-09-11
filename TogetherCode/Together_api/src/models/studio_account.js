const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const StudioAccount = sequelize.define(
    "StudioAccount",
    {
      account_id: { type: DataTypes.BIGINT, primaryKey: true },
      studio_id: { type: DataTypes.BIGINT, allowNull: false },
      account_type: { type: DataTypes.STRING(20), allowNull: false, defaultValue: "bank" },
      account_name: { type: DataTypes.STRING(80), allowNull: false },
      account_no: { type: DataTypes.STRING(64), allowNull: false },
      bank_name: { type: DataTypes.STRING(80), allowNull: true },
      is_default: { type: DataTypes.SMALLINT, allowNull: false, defaultValue: 1 },
      status: { type: DataTypes.SMALLINT, allowNull: false, defaultValue: 1 }
    },
    {
      tableName: "studio_accounts",
      underscored: true
    }
  );

  StudioAccount.beforeValidate((instance) => {
    if (!instance.account_id) {
      instance.account_id = generateId();
    }
  });

  StudioAccount.associate = (models) => {
    StudioAccount.belongsTo(models.StudioProfile, { foreignKey: "studio_id", as: "studio" });
  };

  return StudioAccount;
};
