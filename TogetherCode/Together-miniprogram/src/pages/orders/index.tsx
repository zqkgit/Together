import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, ScrollView } from "@tarojs/components";
import { listOrders, fenToYuan, type OrderItem } from "../../services/order";
import "./index.scss";

/** 订单 Tab 定义（对齐 iOS MyOrdersViewController.Tab） */
const ORDER_TABS: Array<{ key: number | ""; label: string }> = [
  { key: "", label: "全部" },
  { key: 0, label: "待付款" },
  { key: 1, label: "待确认" },
  { key: 2, label: "已报名" },
  { key: 6, label: "已取消" },
  { key: 5, label: "已退款" },
];

/** 状态 badge 样式映射（对齐 iOS OrderCell.configure） */
function getBadgeStyle(order: OrderItem): { text: string; color: string; bg: string } {
  // 退款聚合优先
  if (order.refund_status === 1) return { text: "退款中", color: "#A87A3E", bg: "#F4EFE6" };
  if (order.refund_status === 2) return { text: "已退款", color: "#14A640", bg: "#E4F7EA" };
  if (order.refund_status === 3) return { text: "退款驳回", color: "#B03A2B", bg: "#FDE8E5" };

  switch (order.status) {
    case 0: return { text: "待付款", color: "#A87A3E", bg: "#F4EFE6" };
    case 1: return { text: "待确认", color: "#A87A3E", bg: "#F4EFE6" };
    case 2: return { text: "已报名", color: "#14A640", bg: "#E4F7EA" };
    case 3: return { text: "退款审核中", color: "#A87A3E", bg: "#F4EFE6" };
    case 4: return { text: "待确认退款", color: "#A87A3E", bg: "#F4EFE6" };
    case 5: return { text: "已退款", color: "#14A640", bg: "#E4F7EA" };
    case 6: return { text: "已取消", color: "#9C948A", bg: "#F4EFE6" };
    default: return { text: order.status_text || "未知", color: "#9C948A", bg: "#F4EFE6" };
  }
}

/** 是否存在被驳回的付款凭证（对齐 iOS OrderItem.rejectedPayment） */
function hasRejectedPayment(order: OrderItem): boolean {
  return !!(order.payments && order.payments.some((p) => p.status === 2));
}

/** 提示文案（对齐 iOS OrderCell.configure hint） */
function getHint(order: OrderItem): { text: string; color: string } | null {
  // 退款聚合
  if (order.refund_status === 1) return { text: "退款处理中，请留意机构线下退款", color: "#A87A3E" };
  if (order.refund_status === 3) return { text: "退款未通过，可在订单详情再次申请", color: "#B03A2B" };
  if (order.refund_status === 2) return null;

  switch (order.status) {
    case 0: {
      if (hasRejectedPayment(order)) {
        return { text: "付款凭证未通过，请重新上传", color: "#B03A2B" };
      }
      return { text: "请线下付款后上传凭证，机构确认后发课时", color: "#A87A3E" };
    }
    case 1: return { text: "凭证已提交，等待机构确认", color: "#A87A3E" };
    case 2: return { text: "报名成功，课时已到账", color: "#14A640" };
    case 3: return { text: "退款审核中，请等待机构处理", color: "#A87A3E" };
    case 4: return { text: "请确认退款信息", color: "#A87A3E" };
    default: return null;
  }
}

/** 按钮列表（对齐 iOS OrderCell.buttonActions） */
function getButtons(order: OrderItem): Array<{ action: string; label: string; primary: boolean }> {
  if (order.refund_status && order.refund_status > 0) {
    return [{ action: "refundDetail", label: "查看退款", primary: false }];
  }
  switch (order.status) {
    case 0: return [
      { action: "cancel", label: "取消", primary: false },
      { action: "voucher", label: "上传凭证", primary: true },
    ];
    case 1: return []; // 审核中无操作
    case 2: return [{ action: "study", label: "去学习", primary: true }];
    case 3:
    case 4: return [{ action: "refundDetail", label: "查看退款", primary: false }];
    case 5: return [];
    case 6: return [{ action: "reorder", label: "重新报名", primary: true }];
    default: return [];
  }
}

export default function OrdersPage() {
  const [orders, setOrders] = useState<OrderItem[]>([]);
  const [activeTab, setActiveTab] = useState<number | "">("");
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);

  // 显式传入 tab / 页码，避免读取闭包里的旧 state（否则切 tab 第一次请求的还是上一个状态）
  const loadData = async (tabKey: number | "", pageNum: number) => {
    setLoading(true);
    try {
      const params: any = { page: pageNum, page_size: 10 };
      if (tabKey !== "") params.status = tabKey;
      const data = await listOrders(params);
      setOrders((prev) => (pageNum === 1 ? data.list : [...prev, ...data.list]));
      setTotal(data.total);
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData("", 1);
  }, []);

  const onFilter = (key: number | "") => {
    if (key === activeTab) return; // 已在该 tab，不重复请求
    setActiveTab(key);
    setPage(1);
    loadData(key, 1);
  };

  const goDetail = (id: string) => {
    Taro.navigateTo({ url: "/pages/order-detail/index?id=" + id });
  };

  const handleAction = (action: string, order: OrderItem, e: any) => {
    e.stopPropagation();
    switch (action) {
      case "cancel":
        Taro.showModal({
          title: "取消订单",
          content: "确定取消该待付款订单吗？",
          confirmText: "取消订单",
          cancelText: "再想想",
          success: (res) => {
            if (res.confirm) {
              // TODO: 调用取消订单 API
            }
          },
        });
        break;
      case "voucher":
        Taro.navigateTo({ url: "/pages/payment-voucher/index?order_id=" + order.order_id });
        break;
      case "study":
        if (order.course?.course_id && order.child?.child_id) {
          Taro.navigateTo({
            url: "/pages/course-study/index?child_id=" + order.child.child_id + "&course_id=" + order.course.course_id,
          });
        }
        break;
      case "refundDetail": {
        // 以后端「当前退款单」为准，兜底取第一条（后端已按时间倒序，第一条即最新）
        const refundId = order.current_refund_id || (order.refunds && order.refunds.length > 0 ? order.refunds[0].refund_id : "");
        if (refundId) {
          Taro.navigateTo({ url: "/pages/refund-detail/index?id=" + refundId });
        }
        break;
      }
      case "reorder":
        if (order.course?.course_id) {
          Taro.navigateTo({ url: "/pages/order-confirm/index?course_id=" + order.course.course_id });
        }
        break;
    }
  };

  return (
    <View className="orders">
      {/* 筛选条：对齐 iOS TagChipRow（胶囊标签） */}
      <ScrollView scrollX className="order-chip-scroll" showScrollbar={false}>
        <View className="order-chip-row">
          {ORDER_TABS.map((tab) => (
            <View
              key={String(tab.key)}
              className={"order-chip" + (activeTab === tab.key ? " chip-active" : "")}
              onClick={() => onFilter(tab.key)}
            >
              <Text>{tab.label}</Text>
            </View>
          ))}
        </View>
      </ScrollView>

      {/* 订单列表 */}
      <View className="order-list">
        {orders.map((order) => {
          const badge = getBadgeStyle(order);
          const hint = getHint(order);
          const buttons = getButtons(order);
          const studioName = order.studio?.name || "";
          const totalLessons = order.total_lessons || 0;
          const subtitle = studioName + (totalLessons ? (" · " + totalLessons + "课时") : "");

          return (
            <View key={order.order_id} className="order-card" onClick={() => goDetail(order.order_id)}>
              {/* 行1：课程标题 + 状态 badge */}
              <View className="card-row1">
                <Text className="order-title" numberOfLines={2}>{order.course?.title || "未命名课程"}</Text>
                <View className="status-badge" style={{ color: badge.color, backgroundColor: badge.bg }}>
                  <Text className="badge-text">{"  " + badge.text + "  "}</Text>
                </View>
              </View>

              {/* 行2：副标题（工作室·课时） */}
              {subtitle && (
                <Text className="order-subtitle" numberOfLines={1}>{subtitle}</Text>
              )}

              {/* 行3：提示行（对齐 iOS hintLabel） */}
              {hint && (
                <Text className="order-hint" style={{ color: hint.color }}>{hint.text}</Text>
              )}

              {/* 行4：金额 + 操作按钮 */}
              <View className="card-bottom">
                <Text className="order-amount">{"¥" + fenToYuan(order.total_amount)}</Text>
                <View className="btn-row">
                  {buttons.map((btn) => (
                    <View
                      key={btn.action}
                      className={"order-btn" + (btn.primary ? " btn-primary-action" : " btn-secondary-action")}
                      onClick={(e) => handleAction(btn.action, order, e)}
                    >
                      <Text>{btn.label}</Text>
                    </View>
                  ))}
                </View>
              </View>
            </View>
          );
        })}
      </View>

      {loading && <View className="empty-tip">加载中...</View>}
      {orders.length === 0 && !loading && <View className="empty-tip">暂无订单</View>}
    </View>
  );
}