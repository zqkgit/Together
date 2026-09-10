const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const PostStudent = sequelize.define(
    "PostStudent",
    {
      id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      post_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      child_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      order_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      deducted: {
        type: DataTypes.BOOLEAN,
        allowNull: false,
        defaultValue: false
      }
    },
    {
      tableName: "post_students",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  PostStudent.associate = (models) => {
    PostStudent.belongsTo(models.Post, { foreignKey: "post_id", as: "post" });
    PostStudent.belongsTo(models.Child, { foreignKey: "child_id", as: "child" });
    PostStudent.belongsTo(models.Order, { foreignKey: "order_id", as: "order" });
  };

  PostStudent.beforeValidate((instance) => {
    if (!instance.id) {
      instance.id = generateId();
    }
  });

  return PostStudent;
};
