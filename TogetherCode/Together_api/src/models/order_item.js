const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const OrderItem = sequelize.define(
    "OrderItem",
    {
      item_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      order_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      course_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      package_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      course_title: {
        type: DataTypes.STRING(80),
        allowNull: false
      },
      package_name: {
        type: DataTypes.STRING(40),
        allowNull: false
      },
      lessons: {
        type: DataTypes.SMALLINT,
        allowNull: false
      },
      quantity: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 1
      },
      unit_price: {
        type: DataTypes.INTEGER,
        allowNull: false
      },
      total_price: {
        type: DataTypes.INTEGER,
        allowNull: false
      }
    },
    {
      tableName: "order_items",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  OrderItem.associate = (models) => {
    OrderItem.belongsTo(models.Order, { foreignKey: "order_id", as: "order" });
    OrderItem.belongsTo(models.Course, { foreignKey: "course_id", as: "course" });
    OrderItem.belongsTo(models.CoursePackage, { foreignKey: "package_id", as: "coursePackage" });
  };

  OrderItem.beforeValidate((instance) => {
    if (!instance.item_id) {
      instance.item_id = generateId();
    }
  });

  return OrderItem;
};
