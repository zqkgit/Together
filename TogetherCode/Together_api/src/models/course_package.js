const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const CoursePackage = sequelize.define(
    "CoursePackage",
    {
      package_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      course_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      name: {
        type: DataTypes.STRING(40),
        allowNull: false
      },
      lessons: {
        type: DataTypes.SMALLINT,
        allowNull: false
      },
      price: {
        type: DataTypes.INTEGER,
        allowNull: false
      },
      original_price: {
        type: DataTypes.INTEGER,
        allowNull: true
      },
      status: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 1
      }
    },
    {
      tableName: "course_packages",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  CoursePackage.associate = (models) => {
    CoursePackage.belongsTo(models.Course, { foreignKey: "course_id", as: "course" });
    CoursePackage.hasMany(models.Order, { foreignKey: "package_id", as: "orders" });
    CoursePackage.hasMany(models.OrderItem, { foreignKey: "package_id", as: "orderItems" });
  };

  CoursePackage.beforeValidate((instance) => {
    if (!instance.package_id) {
      instance.package_id = generateId();
    }
  });

  return CoursePackage;
};
