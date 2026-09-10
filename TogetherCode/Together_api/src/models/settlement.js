const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const Settlement = sequelize.define(
    "Settlement",
    {
      settlement_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      studio_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      period_start: {
        type: DataTypes.DATEONLY,
        allowNull: false
      },
      period_end: {
        type: DataTypes.DATEONLY,
        allowNull: false
      },
      income: {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      refund: {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      distribution: {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      net_amount: {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      fee_rate: {
        type: DataTypes.DECIMAL(4, 2),
        allowNull: false,
        defaultValue: 0.1
      },
      fee_amount: {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      payable_amount: {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      status: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 0
      },
      pay_no: {
        type: DataTypes.STRING(64),
        allowNull: true
      },
      operator_id: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      paid_at: {
        type: DataTypes.DATE,
        allowNull: true
      }
    },
    {
      tableName: "settlements",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  Settlement.associate = (models) => {
    Settlement.belongsTo(models.StudioProfile, { foreignKey: "studio_id", as: "studio" });
    Settlement.belongsTo(models.AdminAccount, { foreignKey: "operator_id", as: "operator" });
  };

  Settlement.beforeValidate((instance) => {
    if (!instance.settlement_id) {
      instance.settlement_id = generateId();
    }
  });

  return Settlement;
};
