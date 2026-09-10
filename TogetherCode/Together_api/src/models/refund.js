const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const Refund = sequelize.define(
    "Refund",
    {
      refund_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      order_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      user_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      requested_lessons: {
        type: DataTypes.SMALLINT,
        allowNull: false
      },
      refundable_lessons: {
        type: DataTypes.SMALLINT,
        allowNull: false
      },
      unit_price: {
        type: DataTypes.INTEGER,
        allowNull: false
      },
      amount: {
        type: DataTypes.INTEGER,
        allowNull: false
      },
      reason: {
        type: DataTypes.STRING(255),
        allowNull: true
      },
      reviewed_by: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      reviewed_at: {
        type: DataTypes.DATE,
        allowNull: true
      },
      refunded_at: {
        type: DataTypes.DATE,
        allowNull: true
      },
      status: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 0
      }
    },
    {
      tableName: "refunds",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  Refund.associate = (models) => {
    Refund.belongsTo(models.Order, { foreignKey: "order_id", as: "order" });
    Refund.belongsTo(models.User, { foreignKey: "user_id", as: "user" });
  };

  Refund.beforeValidate((instance) => {
    if (!instance.refund_id) {
      instance.refund_id = generateId();
    }
  });

  return Refund;
};
