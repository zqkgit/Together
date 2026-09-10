const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const Payment = sequelize.define(
    "Payment",
    {
      payment_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      order_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      payment_no: {
        type: DataTypes.STRING(32),
        allowNull: false,
        unique: true
      },
      channel: {
        type: DataTypes.STRING(20),
        allowNull: false
      },
      amount: {
        type: DataTypes.INTEGER,
        allowNull: false
      },
      paid_at: {
        type: DataTypes.DATE,
        allowNull: true
      },
      status: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 0
      },
      trade_no: {
        type: DataTypes.STRING(64),
        allowNull: true
      }
    },
    {
      tableName: "payments",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  Payment.associate = (models) => {
    Payment.belongsTo(models.Order, { foreignKey: "order_id", as: "order" });
  };

  Payment.beforeValidate((instance) => {
    if (!instance.payment_id) {
      instance.payment_id = generateId();
    }
    if (!instance.payment_no) {
      instance.payment_no = `PM${generateId()}`;
    }
  });

  return Payment;
};
