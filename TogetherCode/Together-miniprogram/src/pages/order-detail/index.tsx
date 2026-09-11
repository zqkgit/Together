import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image } from "@tarojs/components";
import { getOrderDetail, payOrder, type OrderItem } from "../../services/order";
import { fenToYuan } from "../../services/course";
import "./index.scss";

const STATUS_TEXT: Record<number, string> = { 0: "待支付", 1: "已支付", 2: "已取消", 3: "已完成" };

export default function OrderDetailPage() {
  const [order, setOrder] = useState<OrderItem | null>(null);
  const [loading, setLoading] = useState(true);
  const [paying, setPaying] = useState(false);

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

  if (loading) {
    return <View className="empty-tip">加载中...</View>;
  }
  if (!order) {
    return <View className="empty-tip">订单不存在</View>;
  }

  return (
    <View className="order-detail">
      <View className="status-banner">
        <View className="status-text">{order.status_text || STATUS_TEXT[order.status] || "未知状态"}</View>
        <View className="status-sub">
          {order.status === 0 && "请尽快完成支付，锁定课时"}
          {order.status === 1 && "课时已到账，可在「我的孩子」中查看"}
          {order.status === 3 && "本订单已结课完成"}
        </View>
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
      {order.status === 1 && (
        <View className="action-bar">
          <View className="btn-plain action-btn" onClick={goRefund}>申请退款</View>
        </View>
      )}
    </View>
  );
}
