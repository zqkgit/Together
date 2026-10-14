---
name: Android 原生工程移植进度
description: iOS→Android(Kotlin+Compose) 全功能还原的模块进度与技术模式，接续开发时查阅
type: project
---

# Android 移植进度（全部完成，含 WebSocket 实时消息）

Phase1-5 + WebSocket 全部完成：MyCourses/CourseStudy、老师端4页、Search/TeacherProfile/StudioHomepage、CourseReviews/ReviewCompose/MyReviews、ScheduleDetail消课、Studios/ClassList/ClassStudents、TODO接线全清零。

WebSocket: MessageSocketService(OkHttp+30s pingInterval+指数退避重连1s→30s+SharedFlow分发)；goMain/启动已登录→connect，401/登出/角色切换→disconnect/reconnect；ChatVM observeRealtimeMessages+observeConversationUpdates。

差异：CourseEnroll内嵌弹窗；LocationPicker用GPS简化；StudioPlaceholder跳过。
模式：Service=object+suspend；VM=AndroidViewModel+StateFlow；传对象用VM companion；ON_RESUME=DisposableEffect；collectAsState不支持lambda选择器。