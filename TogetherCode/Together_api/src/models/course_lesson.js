// 课程课时标题：创建课程时可自定义每一节课的标题，排课时默认带入
module.exports = (sequelize, DataTypes) => {
  const CourseLesson = sequelize.define(
    "CourseLesson",
    {
      lesson_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      course_id: {
        type: DataTypes.BIGINT,
        allowNull: false,
        comment: "所属课程"
      },
      lesson_no: {
        type: DataTypes.INTEGER,
        allowNull: false,
        comment: "第几节课（1..N）"
      },
      title: {
        type: DataTypes.STRING(120),
        allowNull: false,
        comment: "课时标题"
      },
      created_at: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW
      }
    },
    {
      tableName: "course_lessons",
      timestamps: false,
      underscored: true
    }
  );

  CourseLesson.associate = (models) => {
    CourseLesson.belongsTo(models.Course, { foreignKey: "course_id", as: "course" });
    models.Course.hasMany(CourseLesson, { foreignKey: "course_id", as: "lessons" });
  };

  return CourseLesson;
};
