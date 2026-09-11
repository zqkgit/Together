const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const DistributionLink = sequelize.define(
    "DistributionLink",
    {
      link_id: { type: DataTypes.BIGINT, primaryKey: true },
      parent_user_id: { type: DataTypes.BIGINT, allowNull: false },
      course_id: { type: DataTypes.BIGINT, allowNull: false },
      post_id: { type: DataTypes.BIGINT, allowNull: true },
      code: { type: DataTypes.STRING(32), allowNull: false, unique: true },
      status: { type: DataTypes.TINYINT, allowNull: false, defaultValue: 1 }
    },
    {
      tableName: "distribution_links",
      createdAt: "created_at",
      updatedAt: false
    }
  );

  DistributionLink.associate = (models) => {
    DistributionLink.belongsTo(models.User, { foreignKey: "parent_user_id", as: "parent" });
    DistributionLink.belongsTo(models.Course, { foreignKey: "course_id", as: "course" });
    DistributionLink.belongsTo(models.Post, { foreignKey: "post_id", as: "post" });
  };

  DistributionLink.beforeValidate((instance) => {
    if (!instance.link_id) {
      instance.link_id = generateId();
    }
  });

  return DistributionLink;
};
