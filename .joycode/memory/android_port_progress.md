---
name: Android 原生工程移植进度
description: iOS→Android(Kotlin+Compose) 全功能还原的模块进度与技术模式，接续开发时查阅
type: project
---

Android移植全部完成(Phase1-5+WebSocket)。WebSocket: OkHttp+30s ping+指数退避+SharedFlow。

技术模式：Service=object+suspend；VM=AndroidViewModel+StateFlow；传对象用VM companion；ON_RESUME=DisposableEffect；Kotlin字符串模板中文需${}包裹。差异：CourseEnroll内嵌弹窗；LocationPicker GPS简化；下拉刷新=UltraSwipeRefresh+AppPullRefreshBox。

iOS同步(2026-10-14~15)：①课程详情/工作室主页/首页管理孩子按钮UI对齐；②三角色发布对齐(老师弹选择/家长postType=2/工作室postType=1+role3→1走家长链路)；③动态不关联孩子(仅postType=2显示)；④收藏动态cell UI对齐(FavoriteWorkCard+FeedCard+九宫格)；⑤Tab状态rememberSaveable；⑥角色切换RoleEventBus原地更新；⑦家长身份胶囊加前缀；⑧后端tags ID→文字(buildTagNameMap)；⑨iOS接入我的评价菜单(MyReviewsViewController早已实现仅缺入口)。