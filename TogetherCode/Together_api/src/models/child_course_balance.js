const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const ChildCourseBalance = sequelize.define(
    "ChildCourseBalance",
    {
      balance_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      child_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      course_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      order_id: {
        type: DataTypes.BIGINT,
        allowNull: false,
        unique: true
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
      refunded_lessons: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 0
      },
      remaining_lessons: {
        type: DataTypes.SMALLINT,
        allowNull: false
      },
      valid_from: {
        type: DataTypes.DATEONLY,
        allowNull: false
      },
      valid_to: {
        type: DataTypes.DATEONLY,
        allowNull: true
      },
      status: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 1
      }
    },
    {
      tableName: "child_course_balances",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  ChildCourseBalance.associate = (models) => {
    ChildCourseBalance.belongsTo(models.Child, { foreignKey: "child_id", as: "child" });
    ChildCourseBalance.belongsTo(models.Course, { foreignKey: "course_id", as: "course" });
    ChildCourseBalance.belongsTo(models.Order, { foreignKey: "order_id", as: "order" });
  };

  ChildCourseBalance.beforeValidate((instance) => {
    if (!instance.balance_id) {
      instance.balance_id = generateId();
    }
  });

  return ChildCourseBalance;
};
