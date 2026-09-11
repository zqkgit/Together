const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const Favorite = sequelize.define(
    "Favorite",
    {
      favorite_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      user_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      target_type: {
        type: DataTypes.STRING(20),
        allowNull: false
      },
      target_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      }
    },
    {
      tableName: "favorites",
      createdAt: "created_at",
      updatedAt: "updated_at",
      indexes: [{ unique: true, fields: ["user_id", "target_type", "target_id"] }]
    }
  );

  Favorite.associate = (models) => {
    Favorite.belongsTo(models.User, { foreignKey: "user_id", as: "user" });
  };

  Favorite.beforeValidate((instance) => {
    if (!instance.favorite_id) {
      instance.favorite_id = generateId();
    }
  });

  return Favorite;
};
