const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const Report = sequelize.define(
    "Report",
    {
      report_id: { type: DataTypes.BIGINT, primaryKey: true },
      reporter_id: { type: DataTypes.BIGINT, allowNull: false },
      target_type: { type: DataTypes.STRING(20), allowNull: false },
      target_id: { type: DataTypes.STRING(64), allowNull: false },
      reason: { type: DataTypes.STRING(20), allowNull: false },
      detail: { type: DataTypes.STRING(500), allowNull: true },
      images: { type: DataTypes.JSON, allowNull: true },
      status: { type: DataTypes.SMALLINT, allowNull: false, defaultValue: 0 },
      handled_by: { type: DataTypes.BIGINT, allowNull: true },
      handle_note: { type: DataTypes.STRING(255), allowNull: true },
      handled_at: { type: DataTypes.DATE, allowNull: true }
    },
    {
      tableName: "reports",
      underscored: true
    }
  );

  Report.beforeValidate((instance) => {
    if (!instance.report_id) {
      instance.report_id = generateId();
    }
  });

  Report.associate = (models) => {
    Report.belongsTo(models.User, { foreignKey: "reporter_id", as: "reporter" });
  };

  return Report;
};
