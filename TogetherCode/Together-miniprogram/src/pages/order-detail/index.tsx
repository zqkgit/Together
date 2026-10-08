import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image } from "@tarojs/components";
import {
  getOrderDetail,
  cancelOrder,
  ORDER_STATUS_TEXT,
  REFUND_STATUS_TEXT,
  type OrderItem,
  type PaymentItem,
} from "../../services/order";
import { fenToYuan } from "../../services/course";
import "./index.scss";

export default function OrderDetailPage() {
  const [order, setOrder] = useState<OrderItem | null>(null);
  const [loading, setLoading] = useState(true);
  const [cancelling, setCancelling] = useState(false);

  useEffect(() => {
    const id = Taro.getCurrentInstance().router?.params?.id;
    if (id) load(id);
  }, []);

  const load = async (id: string) => {
    try {
      const data = await getOrderDetail(id);
      setOrder(data);
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const goVoucher = () => {
    if (!order) return;
    Taro.navigateTo({
      url: `/pages/payment-voucher/index?order_id=${order.order_id}&amount=${order.total_amount}`,
    });
  };

  const goRefund = () => {
    if (!order) return;
    Taro.navigateTo({ url: `/pages/refund/index?order_id=${order.order_id}` });
  };

  const goRefundDetail = () => {
    if (!order) return;
    const refundStatus = order.refund_status || 0;
    const targets = refundStatus === 2 ? [3] : refundStatus === 3 ? [2] : [0, 1];
    const refundId = order.refunds?.find((r) => targets.includes(r.status))?.refund_id;
    if (refundId) {
      Taro.navigateTo({ url: `/pages/refund-detail/index?id=${refundId}` });
    } else {
      goRefund();
    }
  };

  const handleCancel = async () => {
    if (!order || cancelling) return;
    const res = await Taro.showModal({
      title: "取消订单",
      content: "确定取消此订单吗？取消后不可恢复。",
      confirmColor: "#e74c3c",
    });
    if (!res.confirm) return;
    setCancelling(true);
    try {
      await cancelOrder(order.order_id);
      Taro.showToast({ title: "已取消", icon: "success" });
      load(order.order_id);
    } catch {
      // 拦截器已提示
    } finally {
      setCancelling(false);
    }
  };

  const goStudy = () => {
    if (!order) return;
    const courseId = order.course?.course_id;
    const childId = order.child?.child_id;
    if (courseId && childId) {
      Taro.navigateTo({ url: `/pages/course-study/index?course_id=${courseId}&child_id=${childId}` });
    }
  };

  // 退款聚合状态
  const refundStatus = order?.refund_status || 0;
  const statusTitle = refundStatus > 0
    ? REFUND_STATUS_TEXT[refundStatus]
    : ORDER_STATUS_TEXT[order?.status ?? 0] || order?.status_text || "未知状态";

  const statusSub = refundStatus === 1
    ? "退款处理中，到账后将自动更新"
    : refundStatus === 2
      ? "退款已到账"
      : refundStatus === 3
        ? "退款申请未通过，如有疑问请联系机构"
        : order?.status === 0
          ? "请线下付款后上传凭证，机构确认后发放课时"
          : order?.status === 1
            ? "凭证审核中，等待机构确认收款"
            : order?.status === 2
              ? "课时已到账，可在「我的孩子」中查看"
              : order?.status === 5
                ? "本订单已退款"
                : order?.status === 6
                  ? "订单已取消"
                  : "";

  // 凭证被驳回时提示重新上传
  const rejectedPayment = order?.payments?.find((p) => p.status === 2);
  const hasRejected = !!rejectedPayment;

  if (loading) {
    return <View className="empty-tip">加载中...</View>;
  }
  if (!order) {
    return <View className="empty-tip">订单不存在</View>;
  }

  return (
    <View className="order-detail">
      <View className="status-banner">
        <View className="status-text">{order.status_text || statusTitle}</View>
        <View className="status-sub">{statusSub}</View>
        {hasRejected && order.status === 0 && (
          <View className="reject-hint">凭证被驳回：{rejectedPayment?.reject_reason || "请重新上传"}</View>
        )}
      </View>

      <View className="card course-card" onClick={() => order.course?.course_id && Taro.navigateTo({ url: `/pages/course-detail/index?id=${order.course.course_id}` })}>
        <Image className="course-cover" src={order.course?.cover || ""} mode="aspectFill" />
        <View className="course-info">
          <View className="course-title">{order.course?.title || "课程"}</View>
          <View className="course-sub">
            {order.studio?.name ? `${order.studio.name} · ` : ""}
            {order.child?.nickname ? `${order.child.nickname} · ` : ""}
            {order.total_lessons} 课时
          </View>
          <View className="course-amount">¥{fenToYuan(order.total_amount)}</View>
        </View>
      </View>

      <View className="card info-card">
        <View className="info-row">
          <Text className="info-label">订单号</Text>
          <Text className="info-value">{order.order_no}</Text>
        </View>
        <View className="info-row">
          <Text className="info-label">下单时间</Text>
          <Text className="info-value">{String(order.created_at || "").slice(0, 16)}</Text>
        </View>
        <View className="info-row">
          <Text className="info-label">应付金额</Text>
          <Text className="info-value">¥{fenToYuan(order.paid_amount || order.total_amount)}</Text>
        </View>
        {order.pay_method_text && (
          <View className="info-row">
            <Text className="info-label">付款方式</Text>
            <Text className="info-value">{order.pay_method_text}</Text>
          </View>
        )}
        {order.balance && (
          <View className="info-row">
            <Text className="info-label">剩余课时</Text>
            <Text className="info-value">
              {order.balance.remaining_lessons} 课时
              {order.balance.valid_to ? ` · 有效期至 ${String(order.balance.valid_to).slice(0, 10)}` : ""}
            </Text>
          </View>
        )}
      </View>

      {/* 付款记录 */}
      {order.payments && order.payments.length > 0 && (
        <View className="card info-card">
          <View className="section-label">付款记录</View>
          {order.payments.map((p, i) => (
            <View key={p.payment_id || i} className="payment-item">
              <View className="info-row">
                <Text className="info-label">方式</Text>
                <Text className="info-value">{p.pay_method_text || p.pay_method || "-"}</Text>
              </View>
              <View className="info-row">
                <Text className="info-label">金额</Text>
                <Text className="info-value">¥{fenToYuan(p.amount || 0)}</Text>
              </View>
              <View className="info-row">
                <Text className="info-label">状态</Text>
                <Text className="info-value">{p.status_text || (p.status === 0 ? "待确认" : p.status === 1 ? "已确认" : "已驳回")}</Text>
              </View>
              {p.reject_reason && (
                <View className="info-row">
                  <Text className="info-label">驳回原因</Text>
                  <Text className="info-value reject-text">{p.reject_reason}</Text>
                </View>
              )}
              {p.voucher_images && p.voucher_images.length > 0 && (
                <View className="voucher-preview">
                  {p.voucher_images.map((url, j) => (
                    <Image
                      key={j}
                      className="voucher-thumb"
                      src={url}
                      mode="aspectFill"
                      onClick={() => Taro.previewImage({ current: url, urls: p.voucher_images || [] })}
                    />
                  ))}
                </View>
              )}
            </View>
          ))}
        </View>
      )}

      {/* 底部操作按钮 — 对齐 iOS OrderDetailViewController.updateBottomBar */}
      {order.status === 0 && (
        <View className="action-bar">
          <View className="btn-plain action-btn" onClick={handleCancel}>
            {cancelling ? "取消中..." : "取消订单"}
          </View>
          <View className="btn-primary action-btn" onClick={goVoucher}>
            {hasRejected ? "重新上传凭证" : "上传付款凭证"}
          </View>
        </View>
      )}
      {order.status === 1 && (
        <View className="action-bar">
          <View className="btn-primary action-btn btn-disabled">凭证审核中 · 等待机构确认</View>
        </View>
      )}
      {order.status === 2 && refundStatus === 0 && (
        <View className="action-bar">
          <View className="btn-primary action-btn" onClick={goStudy}>去学习</View>
          {order.can_apply_refund !== false && (
            <View className="btn-plain action-btn" onClick={goRefund}>申请退款</View>
          )}
        </View>
      )}
      {refundStatus === 1 && (
        <View className="action-bar">
          <View className="btn-primary action-btn" onClick={goRefundDetail}>查看退款进度</View>
        </View>
      )}
      {refundStatus === 2 && (
        <View className="action-bar">
          <View className="btn-primary action-btn" onClick={goRefundDetail}>查看退款</View>
        </View>
      )}
      {refundStatus === 3 && (
        <View className="action-bar">
          <View className="btn-plain action-btn" onClick={goRefundDetail}>查看退款</View>
          <View className="btn-primary action-btn" onClick={goRefund}>再次申请退款</View>
        </View>
      )}
      {order.status === 6 && (
        <View className="action-bar">
          <View className="btn-primary action-btn" onClick={() => {
            if (order.course?.course_id) {
              Taro.navigateTo({ url: `/pages/order-confirm/index?course_id=${order.course.course_id}` });
            }
          }}>重新报名</View>
        </View>
      )}
    </View>
  );
}