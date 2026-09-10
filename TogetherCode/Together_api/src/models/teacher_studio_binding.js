const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const TeacherStudioBinding = sequelize.define(
    "TeacherStudioBinding",
    {
      binding_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      teacher_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      studio_id: {
        type: DataTypes.BIGINT,
        allowNull: false
      },
      // 1 在职绑定 / 0 已解除
      status: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 1
      },
      bound_at: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW
      },
      released_at: {
        type: DataTypes.DATE,
        allowNull: true
      }
    },
    {
      tableName: "teacher_studio_bindings",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  TeacherStudioBinding.associate = (models) => {
    TeacherStudioBinding.belongsTo(models.TeacherProfile, { foreignKey: "teacher_id", as: "teacher" });
    TeacherStudioBinding.belongsTo(models.StudioProfile, { foreignKey: "studio_id", as: "studio" });
  };

  TeacherStudioBinding.beforeValidate((instance) => {
    if (!instance.binding_id) {
      instance.binding_id = generateId();
    }
  });

  return TeacherStudioBinding;
};
