---
name: Android 原生工程移植进度
description: iOS→Android(Kotlin+Compose) 全功能还原的模块进度与技术模式，接续开发时查阅
type: project
---

# Android 移植进度（14/15 模块，我的模块全部完成）

**Why:** iOS 是全功能主端，逐步还原到 Android。本机无 Java 无法编译，只能手动检查引用。
**How to apply:** 接续开发按模块清单找下一项，遵循已固化模式。

已完成：网络/存储/组件/Models+Services/登录/MainTab/首页/课程/订单/孩子/广场/消息/我的(全部23+文件)。待做：老师(3文件)→工作室(17文件)。

我的模块含：MineScreen+RoleSwitchSheet+Settings+EditProfile+AccountSecurity+About+收益中心全链路(Wallet/Withdrawals/StudioCommissionDetail+CommissionService)+收藏与动态+作品管理+认证(TeacherAuth/StudioAuth+AuthComponents+AuthNavCache)。

认证页要点：AuthNavCache传status/reason/applyData；handleNeedAuth提取apply；老师=姓名+教龄+擅长+证书9图+简介；工作室=基本信息+营业类型(fetchScopedTags scope=1)+资质6图；PickMultipleVisualMedia+upload(cert/studio)；驳回回显；ApiService.getElement处理数组data。

通用模式：Service=object+suspend；ViewModel=AndroidViewModel+StateFlow+collectAsState()；导航缓存(navOrder/navChild/CommissionNavCache/AuthNavCache)；触底=derivedStateOf；FlowRow需OptIn。