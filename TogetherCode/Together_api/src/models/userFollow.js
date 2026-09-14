const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const UserFollow = sequelize.define(
    "UserFollow",
    {
      id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      follower_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      followee_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      }
    },
    {
      tableName: "user_follows",
      createdAt: "created_at",
      updatedAt: "updated_at",
      indexes: [{ unique: true, fields: ["follower_id", "followee_id"] }]
    }
  );

  UserFollow.associate = (models) => {
    UserFollow.belongsTo(models.User, { foreignKey: "followee_id", as: "followee" });
    UserFollow.belongsTo(models.User, { foreignKey: "follower_id", as: "follower" });
  };

  UserFollow.beforeValidate((instance) => {
    if (!instance.id) {
      instance.id = generateId();
    }
  });

  return UserFollow;
};
