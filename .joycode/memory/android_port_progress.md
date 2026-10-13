---
name: Android 原生工程移植进度
description: iOS→Android(Kotlin+Compose) 全功能还原的模块进度与技术模式，接续开发时查阅
type: project
---

# Android 移植进度（9/15 模块完成）

**Why:** iOS 是全功能主端，逐步还原到 Android。本机无 Java 无法编译，只能手动检查引用。
**How to apply:** 接续开发按模块清单找下一项，遵循已固化模式。

已完成：网络层/存储层/主题组件/Models+9 Services/登录/MainTab/首页/课程/订单模块。
待做：孩子→广场→消息→我的→老师→工作室。

关键模式：Service 用 object+suspend+ApiService；ViewModel 用 AndroidViewModel+StateFlow；复杂对象导航用 ViewModel 伴生对象 navOrder 缓存；PayMethod String 枚举；订单 UI 自行映射状态色；PickMultipleVisualMedia 选图 + ApiService.upload 上传。