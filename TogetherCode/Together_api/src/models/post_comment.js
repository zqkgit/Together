const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const PostComment = sequelize.define(
    "PostComment",
    {
      comment_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      post_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      user_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      content: {
        type: DataTypes.STRING(500),
        allowNull: false
      },
      parent_id: {
        type: DataTypes.BIGINT,
        allowNull: false,
        defaultValue: 0,
        comment: "0 顶级评论，否则为被回复的评论 id"
      },
      like_count: {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      status: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 1,
        comment: "1 正常 / 0 已删除"
      }
    },
    {
      tableName: "post_comments",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  PostComment.associate = (models) => {
    PostComment.belongsTo(models.Post, { foreignKey: "post_id", as: "post" });
    PostComment.belongsTo(models.User, { foreignKey: "user_id", as: "user" });
  };

  PostComment.beforeValidate((instance) => {
    if (!instance.comment_id) {
      instance.comment_id = generateId();
    }
  });

  return PostComment;
};
