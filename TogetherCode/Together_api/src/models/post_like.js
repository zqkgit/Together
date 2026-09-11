const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const PostLike = sequelize.define(
    "PostLike",
    {
      like_id: {
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
      }
    },
    {
      tableName: "post_likes",
      createdAt: "created_at",
      updatedAt: "updated_at",
      indexes: [
        {
          unique: true,
          fields: ["post_id", "user_id"]
        }
      ]
    }
  );

  PostLike.associate = (models) => {
    PostLike.belongsTo(models.Post, { foreignKey: "post_id", as: "post" });
    PostLike.belongsTo(models.User, { foreignKey: "user_id", as: "user" });
  };

  PostLike.beforeValidate((instance) => {
    if (!instance.like_id) {
      instance.like_id = generateId();
    }
  });

  return PostLike;
};
