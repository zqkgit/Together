const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const LessonLog = sequelize.define(
    "LessonLog",
    {
      log_id: {
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
        allowNull: false
      },
      post_id: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      schedule_id: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      source: {
        type: DataTypes.SMALLINT,
        allowNull: false
      },
      type: {
        type: DataTypes.SMALLINT,
        allowNull: false
      },
      delta: {
        type: DataTypes.SMALLINT,
        allowNull: false
      },
      balance_after: {
        type: DataTypes.SMALLINT,
        allowNull: false
      },
      note: {
        type: DataTypes.STRING(255),
        allowNull: true
      }
    },
    {
      tableName: "lesson_logs",
      createdAt: "created_at",
      updatedAt: false
    }
  );

  LessonLog.associate = (models) => {
    LessonLog.belongsTo(models.Child, { foreignKey: "child_id", as: "child" });
    LessonLog.belongsTo(models.Course, { foreignKey: "course_id", as: "course" });
    LessonLog.belongsTo(models.Order, { foreignKey: "order_id", as: "order" });
    LessonLog.belongsTo(models.Post, { foreignKey: "post_id", as: "post" });
    LessonLog.belongsTo(models.Schedule, { foreignKey: "schedule_id", as: "schedule" });
  };

  LessonLog.beforeValidate((instance) => {
    if (!instance.log_id) {
      instance.log_id = generateId();
    }
  });

  return LessonLog;
};
