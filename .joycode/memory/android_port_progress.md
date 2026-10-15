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

iOS同步（2026-10-15）：三角色发布对齐+动态不关联孩子。①中间发布tab：老师弹类型选择(孩子作品2/老师作品1)，家长直传postType=2，工作室直传postType=1(仅发动态)；②工作室role3→1走家长链路POST /posts；③动态(postType=1)不关联孩子：仅postType=2显示关联孩子+关联课程区块、自动选第一个孩子、校验必选孩子；④MyTeachingCourses发作品消课接线postCreate(2,2)；⑤initEdit也做role3→1避免fetchTeacherClasses 403；⑥child_id空串不传。iOS侧：BasePostCreateViewController加customNavTitle属性，工作室发布标题"发布动态"。下拉刷新已全量换UltraSwipeRefresh三方库+AppPullRefreshBox封装。