const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const CourseReview = sequelize.define(
    "CourseReview",
    {
      review_id: {
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
      studio_id: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      user_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      order_id: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      child_id: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      rating: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 5
      },
      content: {
        type: DataTypes.TEXT,
        allowNull: true
      },
      images: {
        type: DataTypes.JSON,
        allowNull: true
      },
      reply_content: {
        type: DataTypes.TEXT,
        allowNull: true
      },
      reply_at: {
        type: DataTypes.DATE,
        allowNull: true
      },
      teacher_reply_content: {
        type: DataTypes.TEXT,
        allowNull: true,
        comment: "老师回复内容"
      },
      teacher_reply_at: {
        type: DataTypes.DATE,
        allowNull: true,
        comment: "老师回复时间"
      },
      status: {
        // 0 待审核 / 1 通过 / 2 驳回
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 0
      },
      reject_reason: {
        type: DataTypes.STRING(255),
        allowNull: true
      }
    },
    {
      tableName: "course_reviews",
      createdAt: "created_at",
      updatedAt: "updated_at",
      indexes: [{ unique: true, fields: ["course_id", "user_id"] }]
    }
  );

  CourseReview.associate = (models) => {
    CourseReview.belongsTo(models.Course, { foreignKey: "course_id", as: "course" });
    CourseReview.belongsTo(models.User, { foreignKey: "user_id", as: "user" });
    CourseReview.belongsTo(models.StudioProfile, { foreignKey: "studio_id", as: "studio" });
    CourseReview.belongsTo(models.TeacherProfile, { foreignKey: "teacher_id", as: "teacher" });
  };

  CourseReview.beforeValidate((instance) => {
    if (!instance.review_id) {
      instance.review_id = generateId();
    }
  });

  return CourseReview;
};
