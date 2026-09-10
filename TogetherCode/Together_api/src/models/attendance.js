const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const Attendance = sequelize.define(
    "Attendance",
    {
      attendance_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      schedule_id: {
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
      status: {
        type: DataTypes.SMALLINT,
        allowNull: false
      },
      note: {
        type: DataTypes.STRING(255),
        allowNull: true
      }
    },
    {
      tableName: "attendance",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  Attendance.associate = (models) => {
    Attendance.belongsTo(models.Schedule, { foreignKey: "schedule_id", as: "schedule" });
    Attendance.belongsTo(models.Child, { foreignKey: "child_id", as: "child" });
    Attendance.belongsTo(models.Order, { foreignKey: "order_id", as: "order" });
  };

  Attendance.beforeValidate((instance) => {
    if (!instance.attendance_id) {
      instance.attendance_id = generateId();
    }
  });

  return Attendance;
};
