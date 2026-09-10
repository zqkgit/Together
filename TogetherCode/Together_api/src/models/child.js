const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const Child = sequelize.define(
    "Child",
    {
      child_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      parent_user_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      nickname: {
        type: DataTypes.STRING(40),
        allowNull: false
      },
      avatar: {
        type: DataTypes.STRING(255),
        allowNull: true
      },
      birthday: {
        type: DataTypes.DATEONLY,
        allowNull: false
      },
      gender: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 0
      }
    },
    {
      tableName: "children",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  Child.associate = (models) => {
    Child.belongsTo(models.User, { foreignKey: "parent_user_id", as: "parent" });
    Child.hasMany(models.Order, { foreignKey: "child_id", as: "orders" });
    Child.hasMany(models.ChildCourseBalance, { foreignKey: "child_id", as: "balances" });
    Child.hasMany(models.LessonLog, { foreignKey: "child_id", as: "lessonLogs" });
    Child.hasMany(models.Attendance, { foreignKey: "child_id", as: "attendanceRecords" });
    Child.hasMany(models.LeaveRequest, { foreignKey: "child_id", as: "leaveRequests" });
    Child.hasMany(models.Post, { foreignKey: "child_id", as: "posts" });
    Child.hasMany(models.PostStudent, { foreignKey: "child_id", as: "postStudents" });
  };

  Child.beforeValidate((instance) => {
    if (!instance.child_id) {
      instance.child_id = generateId();
    }
  });

  return Child;
};
