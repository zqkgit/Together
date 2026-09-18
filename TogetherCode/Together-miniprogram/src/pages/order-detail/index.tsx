import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image } from "@tarojs/components";
import { getOrderDetail, payOrder, payCountdownText, type OrderItem } from "../../services/order";
import { fenToYuan } from "../../services/course";
import "./index.scss";

const STATUS_TEXT: Record<number, string> = { 0: "待支付", 1: "已支付", 2: "已取消", 3: "已退款" };
const REFUND_TEXT: Record<number, string> = { 1: "退款中", 2: "已退款", 3: "退款已驳回" };

export default function OrderDetailPage() {
  const [order, setOrder] = useState<OrderItem | null>(null);
  const [loading, setLoading] = useState(true);
  const [paying, setPaying] = useState(false);
  const [now, setNow] = useState(Date.now());
  const [expired, setExpired] = useState(false);

  useEffect(() => {
    const id = Taro.getCurrentInstance().router?.params?.id;
    if (id) load(id);
    const timer = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(timer);
  }, []);

  const load = async (id: string) => {
    try {
      const data = await getOrderDetail(id);
      setOrder(data);
      setExpired(false);
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const goPay = async () => {
    if (!order || paying) return;
    setPaying(true);
    try {
      await payOrder(order.order_id);
      Taro.showToast({ title: "支付成功", icon: "success" });
      load(order.order_id);
    } catch {
      // 拦截器已提示
    } finally {
      setPaying(false);
    }
  };

  const goRefund = () => {
    if (!order) return;
    Taro.navigateTo({ url: `/pages/refund/index?order_id=${order.order_id}` });
  };

  const goRefundDetail = () => {
    if (!order) return;
    // 聚合状态 → 对应退款单：退款中=0/1，已退款=3，已驳回=2
    const refundStatus = order.refund_status || 0;
    const targets = refundStatus === 2 ? [3] : refundStatus === 3 ? [2] : [0, 1];
    const refundId = order.refunds?.find((r) => targets.includes(r.status))?.refund_id;
    if (refundId) {
      Taro.navigateTo({ url: `/pages/refund-detail/index?id=${refundId}` });
    } else {
      goRefund();
    }
  };

  // 退款聚合状态：0 无 / 1 退款中 / 2 已退款 / 3 已驳回（与 iOS 对齐）
  const refundStatus = order?.refund_status || 0;
  const statusTitle = refundStatus > 0 ? REFUND_TEXT[refundStatus] : STATUS_TEXT[order?.status ?? 0] || "未知状态";
  const statusSub = refundStatus === 1
    ? "退款处理中，到账后将自动更新"
    : refundStatus === 2
      ? "退款已原路退回"
      : refundStatus === 3
        ? "退款申请未通过，如有疑问请联系机构"
        : order?.status === 0
          ? payCountdownText(order, now)
          : order?.status === 1
            ? "课时已到账，可在「我的孩子」中查看"
            : order?.status === 3
              ? "本订单已退款"
              : "";

  useEffect(() => {
    if (order?.status === 0 && order.pay_expire_at && new Date(order.pay_expire_at).getTime() <= now && !expired) {
      setExpired(true);
      Taro.showToast({ title: "支付超时，订单已取消", icon: "none" });
      load(order.order_id);
    }
  }, [now]);

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
          <Text className="info-label">支付金额</Text>
          <Text className="info-value">¥{fenToYuan(order.paid_amount || order.total_amount)}</Text>
        </View>
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

      {order.status === 0 && (
        <View className="action-bar">
          <View className="btn-plain action-btn" onClick={() => Taro.navigateBack()}>稍后支付</View>
          <View className="btn-primary action-btn" onClick={goPay}>{paying ? "支付中..." : "去支付"}</View>
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
      {order.status === 1 && refundStatus === 0 && order.can_apply_refund !== false && (
        <View className="action-bar">
          <View className="btn-primary action-btn" onClick={goRefund}>申请退款</View>
        </View>
      )}
      {order.status === 3 && refundStatus === 0 && (
        <View className="action-bar">
          <View className="btn-primary action-btn" onClick={goRefundDetail}>查看退款</View>
        </View>
      )}
    </View>
  );
}
