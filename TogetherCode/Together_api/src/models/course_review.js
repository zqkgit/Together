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
      user_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      order_id: {
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
      status: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 1
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
  };

  CourseReview.beforeValidate((instance) => {
    if (!instance.review_id) {
      instance.review_id = generateId();
    }
  });

  return CourseReview;
};
