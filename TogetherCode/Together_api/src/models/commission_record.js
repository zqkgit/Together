const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const CommissionRecord = sequelize.define(
    "CommissionRecord",
    {
      commission_id: { type: DataTypes.BIGINT, primaryKey: true },
      link_id: { type: DataTypes.BIGINT, allowNull: false },
      order_id: { type: DataTypes.BIGINT, allowNull: false },
      parent_user_id: { type: DataTypes.BIGINT, allowNull: false },
      rate: { type: DataTypes.DECIMAL(5, 2), allowNull: false, defaultValue: 0 },
      amount: { type: DataTypes.DECIMAL(10, 2), allowNull: false, defaultValue: 0 },
      status: { type: DataTypes.TINYINT, allowNull: false, defaultValue: 1, comment: "1待结算 2已到账" },
      settle_at: { type: DataTypes.DATE, allowNull: true }
    },
    {
      tableName: "commission_records",
      createdAt: "created_at",
      updatedAt: false
    }
  );

  CommissionRecord.associate = (models) => {
    CommissionRecord.belongsTo(models.DistributionLink, { foreignKey: "link_id", as: "link" });
    CommissionRecord.belongsTo(models.Order, { foreignKey: "order_id", as: "order" });
    CommissionRecord.belongsTo(models.User, { foreignKey: "parent_user_id", as: "parent" });
  };

  CommissionRecord.beforeValidate((instance) => {
    if (!instance.commission_id) {
      instance.commission_id = generateId();
    }
  });

  return CommissionRecord;
};
