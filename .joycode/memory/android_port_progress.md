---
name: Android 原生工程移植进度
description: iOS→Android(Kotlin+Compose) 全功能还原的模块进度与技术模式，接续开发时查阅
type: project
---

# Android 移植进度（12/15 模块完成）

**Why:** iOS 是全功能主端，逐步还原到 Android。本机无 Java 无法编译，只能手动检查引用。
**How to apply:** 接续开发按模块清单找下一项，遵循已固化模式。

已完成：网络/存储/组件/Models+Services/登录/MainTab/首页/课程/订单/孩子/广场。待做：消息→我的→老师→工作室。

关键模式：Service=object+suspend；ViewModel=AndroidViewModel+StateFlow；复杂对象导航用伴生 navOrder/navChild/navPost/navEditPost 缓存；ON_RESUME 刷新；FlowRow 需 OptIn；LocalLifecycleOwner 用 compose.ui.platform 版；HorizontalPager 稳定；icons-extended 已引入。

广场细节：PlazaViewModel 三组状态(plaza/detail/create)；评论两级树 BFS 降级 level2 带"回复@xx："前缀；家长选课程=type2/纯动态=type1；老师作品关联学生消课；老师孩子作品不可删；详情 ON_RESUME 刷新；CourseDetail/CourseList 已接线；中间加号→onPublish(role)→postCreate(role,1)。