const { generateId } = require("../utils/id");

module.exports = (sequelize, DataTypes) => {
  const TeacherProfile = sequelize.define(
    "TeacherProfile",
    {
      teacher_id: {
        type: DataTypes.BIGINT,
        primaryKey: true
      },
      user_id: {
        type: DataTypes.BIGINT,
        allowNull: false,
        unique: true
      },
      real_name: {
        type: DataTypes.STRING(40),
        allowNull: false
      },
      subjects: {
        type: DataTypes.JSON,
        allowNull: true
      },
      years: {
        type: DataTypes.SMALLINT,
        allowNull: true
      },
      intro: {
        type: DataTypes.STRING(500),
        allowNull: true
      },
      cert_no: {
        type: DataTypes.STRING(60),
        allowNull: true
      },
      portfolio: {
        type: DataTypes.JSON,
        allowNull: true
      },
      studio_id: {
        type: DataTypes.BIGINT,
        allowNull: true
      },
      cert_status: {
        type: DataTypes.SMALLINT,
        allowNull: false,
        defaultValue: 0
      },
      rating: {
        type: DataTypes.DECIMAL(2, 1),
        allowNull: false,
        defaultValue: 5
      },
      student_count: {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      work_count: {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      fans: {
        type: DataTypes.INTEGER,
        allowNull: false,
        defaultValue: 0
      }
    },
    {
      tableName: "teacher_profiles",
      createdAt: "created_at",
      updatedAt: "updated_at"
    }
  );

  TeacherProfile.associate = (models) => {
    TeacherProfile.belongsTo(models.User, { foreignKey: "user_id", as: "user" });
    TeacherProfile.belongsTo(models.StudioProfile, { foreignKey: "studio_id", as: "studio" });
    TeacherProfile.hasMany(models.Course, { foreignKey: "teacher_id", as: "courses" });
    TeacherProfile.hasMany(models.Class, { foreignKey: "teacher_id", as: "classes" });
    TeacherProfile.hasMany(models.Schedule, { foreignKey: "teacher_id", as: "schedules" });
  };

  TeacherProfile.beforeValidate((instance) => {
    if (!instance.teacher_id) {
      instance.teacher_id = generateId();
    }
  });

  return TeacherProfile;
};
