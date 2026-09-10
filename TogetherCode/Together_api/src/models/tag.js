const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const Tag = sequelize.define(
    "Tag",
    {
      tag_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      name: {
        type: DataTypes.STRING(40),
        allowNull: false
      },
      // 使用场景：1 工作室兴趣标签 / 2 老师兴趣标签 / 3 通用
      scope: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 3
      },
      sort: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 0
      },
      // 1 启用 / 0 停用
      status: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 1
      }
    },
    {
      tableName: "tags",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  Tag.beforeValidate((instance) => {
    if (!instance.tag_id) {
      instance.tag_id = generateId();
    }
  });

  return Tag;
};
