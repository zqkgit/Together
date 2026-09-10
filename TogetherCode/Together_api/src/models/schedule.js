const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const Schedule = sequelize.define(
    "Schedule",
    {
      schedule_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      studio_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      class_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      course_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      teacher_id: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      lesson_date: {
        type: DataTypes.DATEONLY,
        allowNull: false
      },
      start_time: {
        type: DataTypes.STRING(5),
        allowNull: false
      },
      end_time: {
        type: DataTypes.STRING(5),
        allowNull: false
      },
      location: {
        type: DataTypes.STRING(120),
        allowNull: true
      },
      status: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 0
      },
      is_makeup: {
        type: DataTypes.BOOLEAN,
        allowNull: false,
        defaultValue: false
      },
      makeup_from: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      remark: {
        type: DataTypes.STRING(255),
        allowNull: true
      }
    },
    {
      tableName: "schedules",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  Schedule.associate = (models) => {
    Schedule.belongsTo(models.StudioProfile, { foreignKey: "studio_id", as: "studio" });
    Schedule.belongsTo(models.Class, { foreignKey: "class_id", as: "classItem" });
    Schedule.belongsTo(models.Course, { foreignKey: "course_id", as: "course" });
    Schedule.belongsTo(models.TeacherProfile, { foreignKey: "teacher_id", as: "teacher" });
    Schedule.belongsTo(models.Schedule, { foreignKey: "makeup_from", as: "makeupSource" });
    Schedule.hasMany(models.Schedule, { foreignKey: "makeup_from", as: "makeupSchedules" });
    Schedule.hasMany(models.Attendance, { foreignKey: "schedule_id", as: "attendanceRecords" });
    Schedule.hasMany(models.LessonLog, { foreignKey: "schedule_id", as: "lessonLogs" });
    Schedule.hasMany(models.LeaveRequest, { foreignKey: "schedule_id", as: "leaveRequests" });
    Schedule.hasMany(models.LeaveRequest, { foreignKey: "makeup_schedule_id", as: "makeupLeaveRequests" });
  };

  Schedule.beforeValidate((instance) => {
    if (!instance.schedule_id) {
      instance.schedule_id = generateId();
    }
  });

  return Schedule;
};
