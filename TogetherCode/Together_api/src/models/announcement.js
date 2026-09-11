const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const Announcement = sequelize.define(
    "Announcement",
    {
      announcement_id: { type: DataTypes.BIGINT, primaryKey: true },
      title: { type: DataTypes.STRING(120), allowNull: false },
      content: { type: DataTypes.TEXT, allowNull: true },
      type: { type: DataTypes.SMALLINT, allowNull: false, defaultValue: 1 },
      image: { type: DataTypes.JSON, allowNull: true },
      link: { type: DataTypes.STRING(255), allowNull: true },
      status: { type: DataTypes.SMALLINT, allowNull: false, defaultValue: 1 },
      publish_at: { type: DataTypes.DATE, allowNull: true },
      expire_at: { type: DataTypes.DATE, allowNull: true },
      created_by: { type: DataTypes.BIGINT, allowNull: true }
    },
    {
      tableName: "announcements",
      underscored: true
    }
  );

  Announcement.beforeValidate((instance) => {
    if (!instance.announcement_id) {
      instance.announcement_id = generateId();
    }
  });

  return Announcement;
};
