const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const AuditLog = sequelize.define(
    "AuditLog",
    {
      log_id: { type: DataTypes.BIGINT, primaryKey: true },
      actor_id: { type: DataTypes.BIGINT, allowNull: true },
      actor_name: { type: DataTypes.STRING(80), allowNull: true },
      role: { type: DataTypes.STRING(32), allowNull: false },
      studio_id: { type: DataTypes.BIGINT, allowNull: true },
      action: { type: DataTypes.STRING(64), allowNull: false },
      target_type: { type: DataTypes.STRING(32), allowNull: true },
      target_id: { type: DataTypes.STRING(64), allowNull: true },
      detail: { type: DataTypes.TEXT, allowNull: true },
      ip: { type: DataTypes.STRING(64), allowNull: true }
    },
    {
      tableName: "audit_logs",
      underscored: true,
      updatedAt: false
    }
  );

  AuditLog.beforeValidate((instance) => {
    if (!instance.log_id) {
      instance.log_id = generateId();
    }
  });

  return AuditLog;
};
