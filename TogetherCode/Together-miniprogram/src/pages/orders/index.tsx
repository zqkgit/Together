import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image } from "@tarojs/components";
import { listOrders, fenToYuan, payCountdownText, type OrderItem } from "../../services/order";
import "./index.scss";

const STATUS_TEXT: Record<number, string> = {
  0: "待支付",
  1: "已支付",
  2: "已取消",
  3: "已退款"
};
const REFUND_TEXT: Record<number, string> = { 1: "退款中", 2: "已退款", 3: "退款已驳回" };

export default function OrdersPage() {
  const [orders, setOrders] = useState<OrderItem[]>([]);
  const [status, setStatus] = useState<number | "">("");
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);
  const [now, setNow] = useState(Date.now());
  const [refreshing, setRefreshing] = useState(false);

  useEffect(() => {
    loadData();
    const timer = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(timer);
  }, []);

  // 待支付订单倒计时归零 → 刷新列表（后端定时任务会置为已取消）
  useEffect(() => {
    if (refreshing) return;
    const hasExpired = orders.some(
      (o) => o.status === 0 && o.pay_expire_at && new Date(o.pay_expire_at).getTime() <= now
    );
    if (hasExpired) {
      setRefreshing(true);
      setTimeout(() => {
        loadData();
        setRefreshing(false);
      }, 500);
    }
  }, [now]);

  const loadData = async () => {
    setLoading(true);
    try {
      const params: any = { page, page_size: 10 };
      if (status !== "") params.status = status;
      const data = await listOrders(params);
      setOrders((prev) => (page === 1 ? data.list : [...prev, ...data.list]));
      setTotal(data.total);
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const onFilter = (s: number | "") => {
    setStatus(s);
    setPage(1);
    setTimeout(loadData, 0);
  };

  const goDetail = (id: string) => {
    Taro.navigateTo({ url: `/pages/order-detail/index?id=${id}` });
  };

  const goPay = (id: string) => {
    Taro.navigateTo({ url: `/pages/order-pay/index?order_id=${id}` });
  };

  return (
    <View className="orders">
      <View className="order-tabs">
        {[["", "全部"], [0, "待支付"], [1, "已支付"], [3, "已退款"]].map(([key, label]) => (
          <Text
            key={key as string}
            className={`order-tab ${status === key ? "tab-active" : ""}`}
            onClick={() => onFilter(key as number | "")}
          >
            {label as string}
          </Text>
        ))}
      </View>

      <View className="order-list">
        {orders.map((order) => (
          <View key={order.order_id} className="order-card card" onClick={() => goDetail(order.order_id)}>
            <View className="order-head">
              <Text className="order-no">{order.order_no}</Text>
              <Text className="order-status">{order.refund_status ? REFUND_TEXT[order.refund_status] : order.status === 0 ? payCountdownText(order, now) : STATUS_TEXT[order.status] || order.status_text}</Text>
            </View>
            <View className="order-main">
              <Image className="order-cover" src={order.course?.cover || ""} mode="aspectFill" />
              <View className="order-info">
                <View className="order-title">{order.course?.title || "-"}</View>
                <View className="order-sub">
                  {order.child?.nickname || "-"} · {order.total_lessons} 课时
                </View>
                <View className="order-price">¥{fenToYuan(order.total_amount)}</View>
              </View>
            </View>
            {order.status === 0 && (
              <View className="order-actions" onClick={(e) => e.stopPropagation()}>
                <Text className="pay-link" onClick={() => goPay(order.order_id)}>去支付</Text>
              </View>
            )}
          </View>
        ))}
      </View>

      {loading && <View className="empty-tip">加载中...</View>}
      {orders.length === 0 && !loading && <View className="empty-tip">暂无订单</View>}
    </View>
  );
}
