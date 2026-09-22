const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const Order = sequelize.define(
    "Order",
    {
      order_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      order_no: {
        type: DataTypes.STRING(32),
        allowNull: false,
        unique: true
      },
      user_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      child_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      studio_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      course_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      class_id: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      package_id: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      total_lessons: {
        type: DataTypes.SMALLINT,
        allowNull: false
      },
      consumed_lessons: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 0
      },
      distribution_link_id: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      refunded_lessons: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 0
      },
      total_amount: {
        type: DataTypes.INTEGER,
        allowNull: false
      },
      paid_amount: {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      refund_amount: {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      pay_channel: {
        type: DataTypes.STRING(20),
        allowNull: true
      },
      paid_at: {
        type: DataTypes.DATE,
        allowNull: true
      },
      completed_at: {
        type: DataTypes.DATE,
        allowNull: true
      },
      status: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 0
      },
      remark: {
        type: DataTypes.STRING(255),
        allowNull: true
      },
      // 订单来源：0 家长App自助报名  1 工作室后台手动建单
      source: {
        type: DataTypes.TINYINT,
        allowNull: false,
        defaultValue: 0
      },
      // 工作室确认收款的操作人（后台账号 id）
      confirmed_by: {
        type: DataTypes.BIGINT,
        allowNull: true
      }
    },
    {
      tableName: "orders",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  Order.associate = (models) => {
    Order.belongsTo(models.User, { foreignKey: "user_id", as: "user" });
    Order.belongsTo(models.Child, { foreignKey: "child_id", as: "child" });
    Order.belongsTo(models.StudioProfile, { foreignKey: "studio_id", as: "studio" });
    Order.belongsTo(models.Course, { foreignKey: "course_id", as: "course" });
    Order.belongsTo(models.CoursePackage, { foreignKey: "package_id", as: "coursePackage" });
    Order.belongsTo(models.Class, { foreignKey: "class_id", as: "class" });
    Order.hasMany(models.OrderItem, { foreignKey: "order_id", as: "items" });
    Order.hasMany(models.Payment, { foreignKey: "order_id", as: "payments" });
    Order.hasMany(models.Refund, { foreignKey: "order_id", as: "refunds" });
    Order.hasMany(models.LessonLog, { foreignKey: "order_id", as: "lessonLogs" });
    Order.hasMany(models.Attendance, { foreignKey: "order_id", as: "attendanceRecords" });
    Order.hasMany(models.PostStudent, { foreignKey: "order_id", as: "postStudents" });
    Order.hasOne(models.ChildCourseBalance, { foreignKey: "order_id", as: "balance" });
  };

  Order.beforeValidate((instance) => {
    if (!instance.order_id) {
      instance.order_id = generateId();
    }
    if (!instance.order_no) {
      instance.order_no = `TG${generateId()}`;
    }
  });

  return Order;
};
