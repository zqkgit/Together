import React, { useEffect, useState } from "react";
import Taro, { useRouter } from "@tarojs/taro";
import { View, Text, Button } from "@tarojs/components";
import { getOrderDetail, payOrder, fenToYuan } from "../../services/order";
import "./index.scss";

export default function OrderPayPage() {
  const router = useRouter();
  const orderId = router.params.order_id || "";
  const [order, setOrder] = useState<any>(null);
  const [paying, setPaying] = useState(false);

  useEffect(() => {
    if (orderId) loadData();
  }, [orderId]);

  const loadData = async () => {
    try {
      const data = await getOrderDetail(orderId);
      setOrder(data);
    } catch {
      // 拦截器已提示
    }
  };

  const handlePay = async () => {
    setPaying(true);
    try {
      const paid = await payOrder(orderId, "wechat_mini");
      setOrder(paid);
      Taro.showToast({ title: "支付成功", icon: "success" });
      setTimeout(() => {
        Taro.redirectTo({ url: `/pages/order-detail/index?id=${orderId}` });
      }, 600);
    } catch {
      // 拦截器已提示
    } finally {
      setPaying(false);
    }
  };

  return (
    <View className="pay-page">
      <View className="pay-amount">
        <Text className="pay-label">支付金额</Text>
        <View className="pay-value">
          ¥{order ? fenToYuan(order.total_amount) : "0.00"}
        </View>
      </View>

      <View className="card pay-order-info">
        {order && (
          <>
            <View className="info-row">
              <Text className="info-label">课程</Text>
              <Text className="info-value">{order.course?.title || "-"}</Text>
            </View>
            <View className="info-row">
              <Text className="info-label">学员</Text>
              <Text className="info-value">{order.child?.nickname || "-"}</Text>
            </View>
            <View className="info-row">
              <Text className="info-label">课时</Text>
              <Text className="info-value">{order.total_lessons} 课时</Text>
            </View>
            <View className="info-row">
              <Text className="info-label">订单号</Text>
              <Text className="info-value">{order.order_no}</Text>
            </View>
          </>
        )}
      </View>

      <View className="pay-btn-wrap">
        <Button className="btn-primary pay-btn" loading={paying} disabled={order?.status !== 0} onClick={handlePay}>
          {order?.status !== 0 ? "已支付" : "微信支付"}
        </Button>
      </View>
      <Text className="pay-hint">测试环境为模拟支付，正式环境将调起微信支付</Text>
    </View>
  );
}
