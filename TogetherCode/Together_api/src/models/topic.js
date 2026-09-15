const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const Topic = sequelize.define(
    "Topic",
    {
      topic_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      name: {
        type: DataTypes.STRING(40),
        allowNull: false
      },
      // 1 上架 / 0 下架
      status: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 1
      },
      sort: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 0
      }
    },
    {
      tableName: "topics",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  Topic.beforeValidate((instance) => {
    if (!instance.topic_id) {
      instance.topic_id = generateId();
    }
  });

  return Topic;
};
