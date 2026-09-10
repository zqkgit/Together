const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const Course = sequelize.define(
    "Course",
    {
      course_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      studio_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      teacher_id: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      title: {
        type: DataTypes.STRING(80),
        allowNull: false
      },
      cover: {
        type: DataTypes.STRING(255),
        allowNull: true
      },
      category: {
        type: DataTypes.SMALLINT,
        allowNull: false
      },
      age_min: {
        type: DataTypes.SMALLINT,
        allowNull: true
      },
      age_max: {
        type: DataTypes.SMALLINT,
        allowNull: true
      },
      total_lessons: {
        type: DataTypes.SMALLINT,
        allowNull: false
      },
      duration_min: {
        type: DataTypes.SMALLINT,
        allowNull: false
      },
      price: {
        type: DataTypes.INTEGER,
        allowNull: false
      },
      class_size: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 12
      },
      rating: {
        type: DataTypes.DECIMAL(2, 1),
        allowNull: false,
        defaultValue: 5
      },
      sales: {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      distribute_rate: {
        type: DataTypes.DECIMAL(4, 2),
        allowNull: false,
        defaultValue: 0.08
      },
      validity_days: {
        type: DataTypes.SMALLINT,
        allowNull: true
      },
      status: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 0
      }
    },
    {
      tableName: "courses",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  Course.associate = (models) => {
    Course.belongsTo(models.StudioProfile, { foreignKey: "studio_id", as: "studio" });
    Course.belongsTo(models.TeacherProfile, { foreignKey: "teacher_id", as: "teacher" });
    Course.hasMany(models.CoursePackage, { foreignKey: "course_id", as: "packages" });
    Course.hasMany(models.Class, { foreignKey: "course_id", as: "classes" });
    Course.hasMany(models.Schedule, { foreignKey: "course_id", as: "schedules" });
    Course.hasMany(models.Post, { foreignKey: "course_id", as: "posts" });
    Course.hasMany(models.Order, { foreignKey: "course_id", as: "orders" });
    Course.hasMany(models.ChildCourseBalance, { foreignKey: "course_id", as: "balances" });
    Course.hasMany(models.LessonLog, { foreignKey: "course_id", as: "lessonLogs" });
  };

  Course.beforeValidate((instance) => {
    if (!instance.course_id) {
      instance.course_id = generateId();
    }
  });

  return Course;
};
