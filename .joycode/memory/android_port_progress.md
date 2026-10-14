---
name: Android 原生工程移植进度
description: iOS→Android(Kotlin+Compose) 全功能还原的模块进度与技术模式，接续开发时查阅
type: project
---

# Android 移植进度（15/15 模块，工作室 UI 层进行中）

已完成：网络/存储/组件/Models+Services/登录/MainTab/首页/课程/订单/孩子/广场/消息/我的/老师端(Workbench+Timetable+MineScreen)/工作室(Service+ViewModel+Overview+Mine+Refund+Todo+OrderList+OrderDetail)。

**关键修复**：mainRouteForRole 统一返回 ParentMain（所有角色走 MainTabScreen 5-Tab）；tab4 按角色分：role=2→TeacherMineScreen，else→MineScreen；TeacherMineScreen 复用 MineViewModel 做身份切换 + TeacherService.fetchMine() 拉老师数据。

**工作室待完成**：TeacherList/Detail/Application + StudentList/Detail + CommissionReview/Revenue + CourseList + 导航接线。

模式：Service=object+suspend；ViewModel=AndroidViewModel+StateFlow；PullToRefreshBox需OptIn；ON_RESUME=DisposableEffect+LifecycleEventObserver；TogetherCard内置padding(CardInner)勿重复；weight需RowScope内。