import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image } from "@tarojs/components";
import { getRefundDetail, type RefundDetail } from "../../services/order";
import "./index.scss";

export default function RefundDetailPage() {
  const [detail, setDetail] = useState<RefundDetail | null>(null);

  useEffect(() => {
    const id = Taro.getCurrentInstance().router?.params?.id;
    if (id) load(id);
  }, []);

  const load = async (id: string) => {
    try {
      setDetail(await getRefundDetail(id));
    } catch {
      // 拦截器已提示
    }
  };

  const fmt = (t: string | null) => {
    if (!t) return "";
    const d = new Date(t);
    if (Number.isNaN(d.getTime())) return String(t).slice(0, 16).replace("T", " ");
    const p = (n: number) => String(n).padStart(2, "0");
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
  };

  if (!detail) {
    return <View className="refund-detail"><View className="empty-tip">加载中...</View></View>;
  }

  return (
    <View className="refund-detail">
      {/* 状态流转 */}
      <View className="card step-card">
        <View className="step-title">
          <Text className={`result-badge st-${detail.status}`}>{detail.status_text}</Text>
          <Text className="step-amount">{detail.amount_text}</Text>
        </View>
        <View className="steps">
          {detail.steps.map((s, i) => (
            <View key={s.key} className={`step ${s.done ? "done" : "todo"} ${s.current ? "current" : ""}`}>
              <View className="step-dot" />
              {i < detail.steps.length - 1 && <View className="step-line" />}
              <View className="step-text">
                <Text className="step-name">{s.title}</Text>
                {fmt(s.time) && <Text className="step-time">{fmt(s.time)}</Text>}
              </View>
            </View>
          ))}
        </View>
      </View>

      {/* 课程信息 */}
      <View className="card course-card">
        <Image className="course-cover" src={detail.course_cover || ""} mode="aspectFill" />
        <View className="course-body">
          <View className="course-title">{detail.course_title}</View>
          <View className="course-sub">{detail.studio_name}</View>
          <View className="course-sub">学员：{detail.child_name}</View>
        </View>
      </View>

      {/* 退款信息 */}
      <View className="card info-card">
        <View className="info-row">
          <Text className="info-label">退款课时</Text>
          <Text className="info-value">{detail.requested_lessons} 课时（可退 {detail.refundable_lessons} 课时）</Text>
        </View>
        <View className="info-row">
          <Text className="info-label">单价</Text>
          <Text className="info-value">{detail.unit_price_text}</Text>
        </View>
        <View className="info-row">
          <Text className="info-label">退款金额</Text>
          <Text className="info-value strong">{detail.amount_text}</Text>
        </View>
        {detail.reason && (
          <View className="info-row col">
            <Text className="info-label">申请原因</Text>
            <Text className="info-reason">{detail.reason}</Text>
          </View>
        )}
        <View className="info-row">
          <Text className="info-label">申请时间</Text>
          <Text className="info-value">{fmt(detail.created_at)}</Text>
        </View>
        {detail.reviewed_at && (
          <View className="info-row">
            <Text className="info-label">审核时间</Text>
            <Text className="info-value">{fmt(detail.reviewed_at)}</Text>
          </View>
        )}
      </View>

      {/* 课时账本 */}
      <View className="card ledger-card">
        <View className="ledger-head">课时账本</View>
        <View className="ledger-row">
          <Text>总课时</Text><Text>{detail.total_lessons}</Text>
        </View>
        <View className="ledger-row">
          <Text>已消</Text><Text>{detail.consumed_lessons}</Text>
        </View>
        <View className="ledger-row">
          <Text>已退</Text><Text>{detail.refunded_lessons}</Text>
        </View>
        <View className="ledger-row strong">
          <Text>剩余</Text><Text>{detail.balance_remaining}</Text>
        </View>
      </View>
    </View>
  );
}
