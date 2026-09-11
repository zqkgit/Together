import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image } from "@tarojs/components";
import { listOrders, fenToYuan, type OrderItem } from "../../services/order";
import "./index.scss";

const STATUS_TEXT: Record<number, string> = {
  0: "待支付",
  1: "已支付",
  2: "已取消",
  3: "已完成"
};

export default function OrdersPage() {
  const [orders, setOrders] = useState<OrderItem[]>([]);
  const [status, setStatus] = useState<number | "">("");
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    loadData();
  }, []);

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
        {[["", "全部"], [0, "待支付"], [1, "已支付"], [3, "已完成"]].map(([key, label]) => (
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
              <Text className="order-status">{STATUS_TEXT[order.status] || order.status_text}</Text>
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
