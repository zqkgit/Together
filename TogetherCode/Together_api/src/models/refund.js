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
      // 审核通过时锁定的实际退款课时（申请后若已消课，可能小于 requested_lessons）
      approved_lessons: {
        type: DataTypes.SMALLINT,
        allowNull: true
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
      },
      // 退款方式：cash/wechat/alipay/bank/qrcode/other
      refund_method: {
        type: DataTypes.STRING(20),
        allowNull: true
      },
      // 工作室退款凭证图片 URL 数组
      voucher_images: {
        type: DataTypes.JSON,
        allowNull: true
      },
      reject_reason: {
        type: DataTypes.STRING(255),
        allowNull: true
      },
      processed_by: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      processed_at: {
        type: DataTypes.DATE,
        allowNull: true
      },
      // 家长确认收到退款的时间
      confirmed_at: {
        type: DataTypes.DATE,
        allowNull: true
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
