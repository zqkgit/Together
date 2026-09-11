import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Input } from "@tarojs/components";
import { getOrderDetail, type OrderItem } from "../../services/order";
import { request } from "../../services/request";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

const REASONS = ["课程不适合孩子", "时间安排冲突", "工作室原因", "其他"];

export default function RefundPage() {
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const [order, setOrder] = useState<OrderItem | null>(null);
  const [lessons, setLessons] = useState("");
  const [reason, setReason] = useState("");
  const [customReason, setCustomReason] = useState("");
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (!isLoggedIn) {
      Taro.reLaunch({ url: "/pages/login/index" });
      return;
    }
    const id = Taro.getCurrentInstance().router?.params?.order_id;
    if (id) {
      getOrderDetail(id).then((d) => {
        setOrder(d);
        setLessons(String(d.balance?.remaining_lessons ?? d.total_lessons ?? 0));
      }).catch(() => undefined);
    }
  }, [isLoggedIn]);

  const submit = async () => {
    if (!order) return;
    const n = Number(lessons);
    const remaining = order.balance?.remaining_lessons ?? order.total_lessons;
    if (!n || n <= 0) {
      Taro.showToast({ title: "请输入退款课时数", icon: "none" });
      return;
    }
    if (n > remaining) {
      Taro.showToast({ title: `最多可退 ${remaining} 课时`, icon: "none" });
      return;
    }
    setSubmitting(true);
    try {
      await request({
        url: `/orders/${order.order_id}/refunds`,
        method: "POST",
        data: { lessons: n, reason: reason === "其他" ? customReason.trim() || reason : reason }
      });
      Taro.showToast({ title: "退款申请已提交", icon: "success" });
      setTimeout(() => Taro.navigateBack(), 800);
    } catch {
      // 拦截器已提示
    } finally {
      setSubmitting(false);
    }
  };

  if (!order) {
    return <View className="empty-tip">加载中...</View>;
  }

  const remaining = order.balance?.remaining_lessons ?? order.total_lessons;

  return (
    <View className="refund">
      <View className="card order-card">
        <View className="course-name">{order.course?.title || "课程"}</View>
        <View className="order-sub">
          {order.studio?.name ? `${order.studio.name} · ` : ""}
          {order.child?.nickname ? `${order.child.nickname} · ` : ""}
          订单号 {order.order_no}
        </View>
      </View>

      <View className="card form-card">
        <View className="form-label">退款课时</View>
        <View className="lessons-row">
          <Input
            className="lessons-input"
            type="number"
            value={lessons}
            onInput={(e) => setLessons(e.detail.value)}
            placeholder="请输入"
          />
          <Text className="lessons-unit">课时（剩余 {remaining} 课时）</Text>
        </View>

        <View className="form-label">退款原因</View>
        <View className="reason-grid">
          {REASONS.map((r) => (
            <View
              key={r}
              className={`reason-item ${reason === r ? "active" : ""}`}
              onClick={() => setReason(r)}
            >
              {r}
            </View>
          ))}
        </View>
        {reason === "其他" && (
          <Input
            className="reason-input"
            placeholder="请说明退款原因"
            value={customReason}
            onInput={(e) => setCustomReason(e.detail.value)}
            maxlength={255}
          />
        )}
      </View>

      <View className="card tips">
        <View className="tip-title">退款说明</View>
        <View className="tip-text">· 按剩余课时比例退回实付金额</View>
        <View className="tip-text">· 提交后由工作室审核，审核通过后原路退回</View>
      </View>

      <View className="submit-wrap">
        <View className={`btn-primary submit-btn ${submitting ? "disabled" : ""}`} onClick={submit}>
          {submitting ? "提交中..." : "提交退款申请"}
        </View>
      </View>
    </View>
  );
}
