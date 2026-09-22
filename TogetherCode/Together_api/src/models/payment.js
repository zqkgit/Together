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
      },
      // 线下支付方式：cash/wechat/alipay/bank/qrcode/other（与 channel 同义，channel 保留）
      pay_method: {
        type: DataTypes.STRING(20),
        allowNull: true
      },
      // 付款凭证图片 URL 数组（OSS）
      voucher_images: {
        type: DataTypes.JSON,
        allowNull: true
      },
      payer_note: {
        type: DataTypes.STRING(255),
        allowNull: true
      },
      // 凭证上传方：0 家长上传  1 工作室登记
      upload_by: {
        type: DataTypes.TINYINT,
        allowNull: false,
        defaultValue: 0
      },
      confirm_by: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      reject_reason: {
        type: DataTypes.STRING(255),
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
