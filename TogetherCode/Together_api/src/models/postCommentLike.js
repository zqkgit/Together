const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const PostCommentLike = sequelize.define(
    "PostCommentLike",
    {
      id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      comment_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      user_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      }
    },
    {
      tableName: "post_comment_likes",
      createdAt: "created_at",
      updatedAt: "updated_at",
      indexes: [{ unique: true, fields: ["comment_id", "user_id"] }]
    }
  );

  PostCommentLike.beforeValidate((instance) => {
    if (!instance.id) {
      instance.id = generateId();
    }
  });

  return PostCommentLike;
};
