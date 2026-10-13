---
name: Android 原生工程移植进度
description: iOS→Android(Kotlin+Compose) 全功能还原的模块进度与技术模式，接续开发时查阅
type: project
---

# Android 移植进度（13/15 模块完成）

**Why:** iOS 是全功能主端，逐步还原到 Android。本机无 Java 无法编译，只能手动检查引用。
**How to apply:** 接续开发按模块清单找下一项，遵循已固化模式。

已完成：网络/存储/组件/Models+Services/登录/MainTab/首页/课程/订单/孩子/广场/消息。待做：我的(23文件)→老师(3文件)→工作室(17文件)。

关键模式：Service=object+suspend；ViewModel=AndroidViewModel+StateFlow；复杂对象导航用伴生缓存(navOrder/navChild/navPost/navEditPost/navConversation)；ON_RESUME刷新；FlowRow需OptIn；LocalLifecycleOwner用compose.ui.platform版；状态收集统一collectAsState()（非collectAsStateWithLifecycle，缺依赖）；触底加载=snapshotFlow+distinctUntilChanged+filter；触顶加载=drop(1)跳初始状态。

消息细节：MessageViewModel三组状态(message/chat/following)；双Tab胶囊+角标(当前Tab不显示)+静默刷新(列表非空不显示动画)；聊天=服务端倒序reversed+>5min/跨天插时间行+乐观插入local-id+replaceTemp+lastMessageId变化才滚底；气泡自己右Brand/对方左Surface+头像30+圆角14+图片180；通知ref_type跳转(post/order/refund/course/withdraw)。