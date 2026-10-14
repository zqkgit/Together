---
name: Android 原生工程移植进度
description: iOS→Android(Kotlin+Compose) 全功能还原的模块进度与技术模式，接续开发时查阅
type: project
---

# Android 移植进度（全部完成）

Phase1-5 + WebSocket 全部完成。WebSocket: MessageSocketService(OkHttp+30s ping+指数退避重连+SharedFlow)。

iOS同步（2026-10-14）：课程详情——卡片封面(0.78宽高比)、标签brandSoft+副标题、机构卡图标行、课时安排lessons圆点列表、评价区分布条+回复条(Info蓝/Violet紫)+最多2条、底部栏咨询工作室+价格/N节。工作室主页——头部linearGradient(Brand→BrandDark)+装饰圆+咨询/电话圆形按钮、Tab选中Brand底白字、课程卡detailText+priceText(fenToYuanText)、作品卡clickable→postDetail、介绍tab图标行(LocationOn/Schedule/Business/Tag/Phone)、环境照片横滑(240x170dp)、VM加chatCreating+createConversation、showNavButtons判断studioUserId!=myUserId。首页——管理孩子按钮fillMaxHeight+IntrinsicSize.Min修复高度。

差异：CourseEnroll内嵌弹窗；LocationPicker用GPS简化；StudioPlaceholder跳过。
模式：Service=object+suspend；VM=AndroidViewModel+StateFlow；传对象用VM companion；ON_RESUME=DisposableEffect；Kotlin字符串模板中文需${}包裹。