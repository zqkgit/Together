---
name: Android 原生工程移植进度
description: iOS→Android(Kotlin+Compose) 全功能还原的模块进度与技术模式，接续开发时查阅
type: project
---

# Android 移植进度（全部完成，TODO 清零）

基础层+老师端+工作室端+增量批次(Phase1-5)均已完成：
- Phase1: MyCourses+CourseStudy；Phase2: 老师端4页+TeacherViewModel
- SearchScreen+Home入口；TeacherProfile+StudioHomepage
- Phase3: CourseReviews+ReviewCompose+MyReviews+接线
- Phase4: ScheduleDetailScreen(排课详情消课)+Timetable点击导航
- Phase5: StudiosScreen(找画室/找老师)+ClassList/ClassStudents(班级管理)+HomeScreen三处TODO接线+onStudy/onReorder/withdraw通知跳转

iOS→Android 差异处理：CourseEnroll内嵌CourseDetail弹窗(非独立页)；LocationPicker用GPS定位简化(无地图SDK)；StudioPlaceholder跳过。

模式：Service=object+suspend；ViewModel=AndroidViewModel+StateFlow；传对象用VM companion或object静态变量；ON_RESUME=DisposableEffect+LifecycleEventObserver；TogetherCard内置padding(CardInner)；自定义顶栏需手动statusBarsPadding；collectAsState不支持lambda选择器。