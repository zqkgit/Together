# Together Android 原生开发方案

## 1. 目标

Android 端采用 **原生 Kotlin + Jetpack Compose**，整体模块、角色边界、页面组织尽量与现有 iOS 工程保持一致，减少产品语义偏差与双端沟通成本。

本阶段目标不是重新设计一套 Android 产品，而是：

1. 直接复用 iOS 已验证过的业务结构
2. 对齐现有 Together API 的角色与接口边界
3. 先完成可持续扩展的 Android 工程骨架
4. 再按角色逐步补业务页面

## 2. 技术方案

### 2.1 固定技术栈

- 语言：`Kotlin`
- UI：`Jetpack Compose`
- 架构：`MVVM + Repository`
- 路由：`Navigation Compose`
- 网络：`Retrofit + OkHttp + Kotlinx Serialization`
- 状态：`ViewModel + StateFlow`
- 本地存储：`DataStore`
- 图片加载：`Coil`
- 异步：`Kotlin Coroutines`

### 2.2 暂不引入

第一阶段先不引入以下能力，避免初始化期过重：

- `Hilt / Koin`
- 多 module Gradle 拆包
- Room
- WebSocket 即时消息
- 复杂埋点与崩溃平台

这些能力等主链稳定后再加。

## 3. 与 iOS 对齐原则

### 3.1 角色边界保持一致

- 家长：课程浏览、购课、孩子、订单、请假、成长
- 老师：工作台、班级、课表、请假处理、发帖消课
- 工作室：轻量经营入口、订单、退款、资料、学员、老师

### 3.2 iOS 到 Android 模块映射

| iOS 模块 | Android 模块 |
|---|---|
| `Modules/Login` | `modules/login` |
| `Modules/MainTab` | `modules/main` |
| `Modules/Home` | `modules/home` |
| `Modules/Child` | `modules/child` |
| `Modules/Course` | `modules/course` |
| `Modules/Order` | `modules/order` |
| `Modules/Plaza` | `modules/plaza` |
| `Modules/Message` | `modules/message` |
| `Modules/Mine` | `modules/mine` |
| `Modules/Teacher` | `modules/teacher` |
| `Modules/Studio` | `modules/studio` |

### 3.3 基础层映射

| iOS 文件/概念 | Android 对应 |
|---|---|
| `AppRouter.swift` | `app/AppNavigator.kt` |
| `Theme.swift` | `core/design/AppTheme.kt` |
| `APIClient.swift` | `core/network/ApiClient.kt` |
| `TokenManager` | `core/storage/TokenStore.kt` |
| `BaseNavigationController` | `Navigation Compose` 导航栈 |
| `UIViewController` 页面 | `Compose Screen + ViewModel` |

## 4. 工程目录规划

```text
Together_android/
├── app/
│   ├── build.gradle.kts
│   └── src/main/
│       ├── AndroidManifest.xml
│       ├── java/com/together/app/
│       │   ├── app/
│       │   │   ├── TogetherApplication.kt
│       │   │   ├── MainActivity.kt
│       │   │   ├── AppNavigator.kt
│       │   │   └── AppRoutes.kt
│       │   ├── core/
│       │   │   ├── base/
│       │   │   ├── component/
│       │   │   ├── design/
│       │   │   ├── network/
│       │   │   └── storage/
│       │   ├── modules/
│       │   │   ├── login/
│       │   │   ├── main/
│       │   │   ├── home/
│       │   │   ├── child/
│       │   │   ├── course/
│       │   │   ├── order/
│       │   │   ├── plaza/
│       │   │   ├── message/
│       │   │   ├── mine/
│       │   │   ├── teacher/
│       │   │   └── studio/
│       │   └── services/
│       └── res/
├── build.gradle.kts
├── settings.gradle.kts
└── docs/
    └── android-native-plan.md
```

## 5. 页面组织方式

每个业务模块建议统一采用下面的结构：

```text
modules/course/
├── api/
├── model/
├── repository/
├── ui/
│   ├── CourseRoute.kt
│   ├── CourseScreen.kt
│   ├── CourseViewModel.kt
│   └── components/
└── mapper/
```

说明：

- `api/`：Retrofit 接口定义
- `model/`：请求/响应模型、UI 模型
- `repository/`：聚合接口调用与数据拼装
- `ui/`：Compose 页面、ViewModel、子组件
- `mapper/`：接口模型转 UI 模型

## 6. 首批必须落地的基础层

### 6.1 app 层

- `TogetherApplication`
- `MainActivity`
- `AppNavigator`
- `AppRoutes`

### 6.2 core/design

- `AppTheme.kt`
- `AppColors.kt`
- `AppTypography.kt`
- `AppDimens.kt`

要求：

- 颜色命名尽量对齐 iOS `Theme.Color`
- 例如 `bg / surface / line / ink / sub / brand / danger / warn`

### 6.3 core/network

- `ApiConfig.kt`
- `ApiClient.kt`
- `ApiResponse.kt`
- `AuthInterceptor.kt`
- `NetworkLogger.kt`

要求：

- 对齐 iOS 的统一返回结构：`{ code, message, data }`
- 自动注入 `Authorization`
- `401` 自动清 token 并跳登录
- 预留上传接口支持

### 6.4 core/storage

- `TokenStore.kt`
- `UserSessionStore.kt`

要求：

- 保存 `access_token`
- 保存基础用户信息
- 保存当前角色

## 7. 第一阶段页面骨架

第一阶段只做骨架，不追求所有业务都打通。

### 7.1 启动与登录

- Splash / 启动判定
- 登录页
- 验证码登录
- 密码登录
- 登录后角色切换

### 7.2 MainTab

家长端先落一套标准主 Tab：

- 首页
- 广场
- 消息
- 我的

### 7.3 首批骨架页面

- `HomeScreen`
- `MyChildrenScreen`
- `CourseListScreen`
- `MyOrdersScreen`
- `MineScreen`
- `TeacherWorkbenchScreen`
- `StudioOverviewScreen`

## 8. 接口接入顺序

按后端当前真实进度，建议接入顺序如下：

1. `/v1/auth/*`
2. `/v1/children/*`
3. `/v1/courses/*`
4. `/v1/orders/*`
5. `/v1/leave/*`
6. `/v1/teacher/*`
7. `/studio/auth/*`
8. `/studio/orders/*`
9. `/studio/refunds/*`

不要一开始就接消息或上传，先把主链跑通。

## 9. 开发阶段建议

### Phase 1：初始化骨架

- 创建 Android 工程
- 接 Compose
- 接主题
- 接网络层
- 接 token 存储
- 接登录态路由

### Phase 2：家长主链

- 首页
- 我的孩子
- 课程
- 订单
- 请假
- 成长与作品

### Phase 3：老师主链

- 工作台
- 班级
- 课表
- 请假处理
- 发帖消课

### Phase 4：工作室轻量端

- 概览
- 订单
- 退款
- 资料
- 学员
- 老师

### Phase 5：增强项

- 消息
- 上传
- Socket
- 页面性能优化
- 深色模式与动画细节

## 10. Android 命名约定

### 10.1 页面命名

- 页面入口：`XXXRoute`
- 页面：`XXXScreen`
- 状态：`XXXUiState`
- 事件：`XXXAction`
- ViewModel：`XXXViewModel`

### 10.2 组件命名

- 通用组件前缀：`Together`
- 例如：`TogetherTopBar`、`TogetherCard`、`TogetherTag`

### 10.3 路由命名

- 登录：`login`
- 首页：`home`
- 我的孩子：`children`
- 孩子详情：`child/detail/{id}`

## 11. 风险与约束

### 11.1 当前后端仍在推进

Android 端开发必须以现有真实接口为准，不要按 PR 中未落地的接口写死。

### 11.2 多角色不是三套 App

Android 端要复用一套账号和基础能力，通过当前角色切首页和功能入口，不要拆成多个独立工程。

### 11.3 先对齐结构，再做像素级还原

第一阶段优先级：

1. 架构正确
2. 接口可通
3. 模块边界清晰
4. 再去细调视觉和动效

## 12. 下一步执行建议

建议下一步直接进入工程初始化，优先创建以下文件：

1. `settings.gradle.kts`
2. 根 `build.gradle.kts`
3. `app/build.gradle.kts`
4. `MainActivity.kt`
5. `TogetherApplication.kt`
6. `AppTheme.kt`
7. `AppNavigator.kt`
8. `LoginScreen.kt`
9. `MainTabScreen.kt`

完成这一步后，Android Studio 就能先跑起来一个最小可用原生骨架。
