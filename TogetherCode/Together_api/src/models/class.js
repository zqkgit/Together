const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const Class = sequelize.define(
    "Class",
    {
      class_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      course_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      teacher_id: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      name: {
        type: DataTypes.STRING(60),
        allowNull: false
      },
      schedule_rule: {
        type: DataTypes.JSON,
        allowNull: true
      },
      start_date: {
        type: DataTypes.DATEONLY,
        allowNull: true
      },
      end_date: {
        type: DataTypes.DATEONLY,
        allowNull: true
      },
      capacity: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 12
      },
      enrolled: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 0
      }
    },
    {
      tableName: "classes",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  Class.associate = (models) => {
    Class.belongsTo(models.Course, { foreignKey: "course_id", as: "course" });
    Class.belongsTo(models.TeacherProfile, { foreignKey: "teacher_id", as: "teacher" });
    Class.hasMany(models.Schedule, { foreignKey: "class_id", as: "schedules" });
    Class.hasMany(models.LeaveRequest, { foreignKey: "class_id", as: "leaveRequests" });
  };

  Class.beforeValidate((instance) => {
    if (!instance.class_id) {
      instance.class_id = generateId();
    }
  });

  return Class;
};
