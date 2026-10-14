---
name: Android 原生工程移植进度
description: iOS→Android(Kotlin+Compose) 全功能还原的模块进度与技术模式，接续开发时查阅
type: project
---

# Android 移植进度（全部完成，含 WebSocket 实时消息 + 课程详情同步）

Phase1-5 + WebSocket 全部完成：MyCourses/CourseStudy、老师端4页、Search/TeacherProfile/StudioHomepage、CourseReviews/ReviewCompose/MyReviews、ScheduleDetail消课、Studios/ClassList/ClassStudents、TODO接线全清零。

WebSocket: MessageSocketService(OkHttp+30s pingInterval+指数退避重连1s→30s+SharedFlow分发)；goMain/启动已登录→connect，401/登出/角色切换→disconnect/reconnect；ChatVM observeRealtimeMessages+observeConversationUpdates。

课程详情同步 iOS（2026-10-14）：卡片式封面(0.78宽高比+圆角)替代全宽封面；信息区标签统一brandSoft+副标题(机构·课时)，价格移到底部栏；机构卡改图标行(Business/Person+副标题)；班级列表→课时安排(lessons圆点列表)；评价区加评分分布条+写评价按钮+工作室/老师回复条(Info蓝/Violet紫)+最多2条+空状态；底部栏加咨询工作室(线框按钮→createConversation→Chat)+价格带/N节。

差异：CourseEnroll内嵌弹窗；LocationPicker用GPS简化；StudioPlaceholder跳过。
模式：Service=object+suspend；VM=AndroidViewModel+StateFlow；传对象用VM companion；ON_RESUME=DisposableEffect；collectAsState不支持lambda选择器；Kotlin字符串模板中文需${}包裹。