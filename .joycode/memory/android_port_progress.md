---
name: Android 原生工程移植进度
description: iOS→Android(Kotlin+Compose) 全功能还原的模块进度与技术模式，接续开发时查阅
type: project
---

# Android 移植进度（全部完成）

Phase1-5 + WebSocket 全部完成。WebSocket: MessageSocketService(OkHttp+30s ping+指数退避重连+SharedFlow)。

iOS同步（2026-10-14）：课程详情/工作室主页/首页管理孩子按钮等UI对齐，详见git log。

差异：CourseEnroll内嵌弹窗；LocationPicker用GPS简化；StudioPlaceholder跳过。
模式：Service=object+suspend；VM=AndroidViewModel+StateFlow；传对象用VM companion；ON_RESUME=DisposableEffect；Kotlin字符串模板中文需${}包裹。

iOS同步（2026-10-15）：三角色发布对齐。①中间发布tab：老师弹AlertDialog选类型(孩子作品2/老师作品1)，家长/工作室直传postType=2；②工作室role3→1走家长链路POST /posts；③空childList隐藏关联孩子区块+跳过childId校验(工作室无孩子可发帖)；④MyTeachingCourses发作品消课接线postCreate(2,2)；⑤initEdit也做role3→1避免fetchTeacherClasses 403；⑥child_id空串不传。下拉刷新已全量换UltraSwipeRefresh三方库+AppPullRefreshBox封装。