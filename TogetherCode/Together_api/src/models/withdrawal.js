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
      reviewed_at: { type: DataTypes.DATE, allowNull: true },
      // 付款工作室（佣金按订单归属工作室分别结算）
      studio_id: { type: DataTypes.BIGINT, allowNull: true },
      // 工作室打款凭证图片 URL 数组
      voucher_images: { type: DataTypes.JSON, allowNull: true },
      reject_reason: { type: DataTypes.STRING(255), allowNull: true },
      processed_by: { type: DataTypes.BIGINT, allowNull: true },
      processed_at: { type: DataTypes.DATE, allowNull: true },
      // 推广人确认到账时间
      confirmed_at: { type: DataTypes.DATE, allowNull: true }
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
