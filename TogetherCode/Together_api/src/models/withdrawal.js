const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const Withdrawal = sequelize.define(
    "Withdrawal",
    {
      withdraw_id: { type: DataTypes.BIGINT, primaryKey: true },
      user_id: { type: DataTypes.BIGINT, allowNull: false },
      amount: { type: DataTypes.DECIMAL(10, 2), allowNull: false },
      method: { type: DataTypes.STRING(32), allowNull: false, defaultValue: "wechat" },
      account: { type: DataTypes.STRING(128), allowNull: true },
      status: { type: DataTypes.TINYINT, allowNull: false, defaultValue: 1, comment: "1申请 2处理中 3成功 4失败" },
      reviewed_at: { type: DataTypes.DATE, allowNull: true }
    },
    {
      tableName: "withdrawals",
      createdAt: "created_at",
      updatedAt: false
    }
  );

  Withdrawal.associate = (models) => {
    Withdrawal.belongsTo(models.User, { foreignKey: "user_id", as: "user" });
  };

  Withdrawal.beforeValidate((instance) => {
    if (!instance.withdraw_id) {
      instance.withdraw_id = generateId();
    }
  });

  return Withdrawal;
};
