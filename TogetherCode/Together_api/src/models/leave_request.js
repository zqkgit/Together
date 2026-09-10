const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const LeaveRequest = sequelize.define(
    "LeaveRequest",
    {
      leave_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      class_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      child_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      parent_user_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      schedule_id: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      reason: {
        type: DataTypes.STRING(200),
        allowNull: false
      },
      status: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 0
      },
      handled_at: {
        type: DataTypes.DATE,
        allowNull: true
      },
      makeup_status: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 0
      },
      makeup_schedule_id: {
        type: DataTypes.BIGINT,
        allowNull: true
      }
    },
    {
      tableName: "leave_requests",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  LeaveRequest.associate = (models) => {
    LeaveRequest.belongsTo(models.Class, { foreignKey: "class_id", as: "classItem" });
    LeaveRequest.belongsTo(models.Child, { foreignKey: "child_id", as: "child" });
    LeaveRequest.belongsTo(models.User, { foreignKey: "parent_user_id", as: "parent" });
    LeaveRequest.belongsTo(models.Schedule, { foreignKey: "schedule_id", as: "schedule" });
    LeaveRequest.belongsTo(models.Schedule, { foreignKey: "makeup_schedule_id", as: "makeupSchedule" });
  };

  LeaveRequest.beforeValidate((instance) => {
    if (!instance.leave_id) {
      instance.leave_id = generateId();
    }
  });

  return LeaveRequest;
};
