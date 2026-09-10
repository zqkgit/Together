const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const Post = sequelize.define(
    "Post",
    {
      post_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      author_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      author_role: {
        type: DataTypes.SMALLINT,
        allowNull: false
      },
      type: {
        type: DataTypes.SMALLINT,
        allowNull: false
      },
      child_id: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      course_id: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      images: {
        type: DataTypes.JSON,
        allowNull: true
      },
      content: {
        type: DataTypes.STRING(1000),
        allowNull: true
      },
      visibility: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 2
      },
      like_count: {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      comment_count: {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      share_count: {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      status: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 1
      }
    },
    {
      tableName: "posts",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  Post.associate = (models) => {
    Post.belongsTo(models.User, { foreignKey: "author_id", as: "author" });
    Post.belongsTo(models.Child, { foreignKey: "child_id", as: "child" });
    Post.belongsTo(models.Course, { foreignKey: "course_id", as: "course" });
    Post.hasMany(models.PostStudent, { foreignKey: "post_id", as: "students" });
    Post.hasMany(models.LessonLog, { foreignKey: "post_id", as: "lessonLogs" });
  };

  Post.beforeValidate((instance) => {
    if (!instance.post_id) {
      instance.post_id = generateId();
    }
  });

  return Post;
};
