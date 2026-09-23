---
name: 工作室端收益中心 iOS 实现
description: iOS 工作室端收益中心页面（订单营收统计+佣金审核）的实现细节和关键决策
type: project
---

## 工作室端收益中心（StudioRevenueViewController）

**与家长/老师端差异**：工作室是佣金发放方，需审核/驳回推广人的领取申请，而非申请领取。

**页面结构**：
- 顶部：TagChipRow 分段切换（待审核/待确认/已驳回/已完成）
- 第 0 行：StudioFinanceHeaderCell 深色营收概览卡（累计营收+本月营收/累计退款/分销支出/净收入）
- 后续行：StudioCommissionCell 佣金领取单卡片（含审核操作按钮）

**API 路由**：
- GET /studio/finance → StudioFinanceData（period/summary/orders）
- GET /studio/commissions → 佣金领取单列表（支持 status 分页）
- PUT /studio/commissions/:id →审核（approve 需 method，reject 需 reject_reason）

**关键修复记录**：
- PaddingLabel 已在 StudioRefundViewController 中定义（internal），无需重复
- CommissionWithdrawal.UserBrief 无 avatar 字段，使用昵称首字生成主题色圆形占位头像
- fetchCommissionWithdrawals 返回 labeled tuple `(total: Int, list: [CommissionWithdrawal])，需匹配类型
- StudioService.swift 需 import SwiftyJSON（使用 JSON 下标访问）