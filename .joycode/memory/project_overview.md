---
name: 艺启平台项目总览
description: YIQI 艺启儿童艺术教育平台的多端架构、目录分工、演示账号与当前进度
type: project
---

# 艺启（YIQI）儿童艺术教育平台 monorepo

**Why:** 工作区含原型 + 多端代码，了解目录分工是协作前提。
**How to apply:** 定位需求到对应目录，避免重复探索。

- `TogetherPr/`：原型与规划（HTML）。App 46 屏三角色、平台后台、backend-design（DB+API）、YIQI设计系统v2（奶油底 #FAF7F1、松绿 #2F5D45、木色 #A87A3E）。
- `TogetherCode/Together_api/`：Node + Express + Sequelize + MySQL + Redis，Docker 启动，端口 3001。路由：`/v1/*` C 端（家长/老师/工作室 App）、`/admin/*` 平台治理、`/studio/*` 工作室后台。业务已很完整：认证、订单/支付/退款、排课消课、请假补课、发帖互动、分销返利、结算、极光推送、OSS。
- `TogetherCode/Together_admin-web/`：Vue3 + Element Plus + Pinia，平台端 + 工作室端两套视图。
- `TogetherCode/Together-miniprogram/`：Taro + React + TS，约 40 页（交易闭环 + 分销海报）。
- `Together_ios/`：SwiftUI 全功能主端；Android/Harmony 仅说明待环境。
- 根 `配置清单.md`：上线配置（微信/OSS/极光）。

演示账号：家长 13800000000/123456；平台 platform_admin/123456；工作室 studio_owner_1/123456；验证码 123456。