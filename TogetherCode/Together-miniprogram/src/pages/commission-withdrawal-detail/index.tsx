import React, { useState, useEffect } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image } from "@tarojs/components";
import {
  getWithdrawalDetail,
  confirmWithdrawal,
  type CommissionWithdrawal,
  type WithdrawalStep,
  type WithdrawalCommission,
  yuan,
  fmtFull,
} from "../../services/commission";
import "./index.scss";

export default function CommissionWithdrawalDetailPage() {
  const [item, setItem] = useState<CommissionWithdrawal | null>(null);

  const id = Taro.getCurrentInstance().router?.params?.id || "";

  const load = async () => {
    if (!id) return;
    try {
      const res = await getWithdrawalDetail(id);
      setItem(res);
    } catch {
      // 拦截器已提示
    }
  };

  useEffect(() => {
    load();
  }, [id]);

  const doConfirm = async () => {
    if (!item) return;
    const res = await Taro.showModal({
      title: "确认收到佣金",
      content: `请确认你已在线下实际收到「${item.studio?.name || "工作室"}」打款的 ${item.amount_text || yuan(item.amount)}。确认后将标记为已完成。`,
      confirmText: "确认已收到",
      cancelText: "再核对一下",
    });
    if (!res.confirm) return;
    try {
      const latest = await confirmWithdrawal(item.withdraw_id);
      setItem(latest);
      Taro.showToast({ title: "已确认，佣金标记为到账", icon: "none" });
    } catch {
      // 拦截器已提示
    }
  };

  if (!item) {
    return (
      <View className="wd-detail">
        <View className="loading-text">加载中...</View>
      </View>
    );
  }

  const steps = item.steps || [];
  const commissions = item.commissions || [];
  const isRejected = item.status === 2;
  const showConfirm = item.can_confirm;

  return (
    <View className="wd-detail">
      {/* 进度步骤卡 */}
      <View className="card steps-card">
        <View className="steps-header">
          <Text className="steps-status">{item.status_text || ""}</Text>
          <Text className="steps-amount">{item.amount_text || yuan(item.amount)}</Text>
        </View>
        {steps.length > 0 && (
          <View className="steps-track">
            {steps.map((s: WithdrawalStep, i: number) => (
              <View
                key={i}
                className={`step-item ${s.done ? "done" : ""} ${s.current ? "current" : ""}`}
              >
                <View className="step-dot">
                  {s.done && <Text className="step-check">✓</Text>}
                </View>
                <Text className="step-title">{s.title || ""}</Text>
                {i < steps.length - 1 && <View className="step-line" />}
              </View>
            ))}
          </View>
        )}
      </View>

      {/* 打款信息卡 */}
      <View className="card payment-card">
        <Text className="section-title">打款信息</Text>
        {item.status !== null && item.status >= 1 ? (
          <View className="payment-rows">
            {item.method_text && (
              <View className="info-row">
                <Text className="info-label">打款方式</Text>
                <Text className="info-value">{item.method_text}</Text>
              </View>
            )}
            {item.account && (
              <View className="info-row">
                <Text className="info-label">收款账号</Text>
                <Text className="info-value">{item.account}</Text>
              </View>
            )}
            {item.processed_at && (
              <View className="info-row">
                <Text className="info-label">打款时间</Text>
                <Text className="info-value">{fmtFull(item.processed_at)}</Text>
              </View>
            )}
            {item.confirmed_at && (
              <View className="info-row">
                <Text className="info-label">确认时间</Text>
                <Text className="info-value">{fmtFull(item.confirmed_at)}</Text>
              </View>
            )}
          </View>
        ) : (
          <Text className="payment-wait">
            等待工作室在线下完成打款，打款后会在此展示方式与凭证
          </Text>
        )}
        {item.voucher_images && item.voucher_images.length > 0 && (
          <View className="voucher-scroll">
            {item.voucher_images.map((url, i) => (
              <Image
                key={i}
                className="voucher-thumb"
                src={url}
                mode="aspectFill"
                onClick={() =>
                  Taro.previewImage({ current: url, urls: item.voucher_images || [] })
                }
              />
            ))}
          </View>
        )}
      </View>

      {/* 驳回原因卡 */}
      {isRejected && item.reject_reason && (
        <View className="card reject-card">
          <Text className="section-title">驳回原因</Text>
          <Text className="reject-reason">{item.reject_reason}</Text>
        </View>
      )}

      {/* 佣金明细卡 */}
      <View className="card commissions-card">
        <Text className="section-title">佣金明细</Text>
        {commissions.length === 0 ? (
          <Text className="empty-commissions">无明细（历史数据）</Text>
        ) : (
          commissions.map((c: WithdrawalCommission, i: number) => (
            <View key={c.commission_id || i} className="commission-line">
              <View className="cl-left">
                <Text className="cl-order">订单 {c.order_id || "-"}</Text>
                <Text className="cl-rate">费率 {Math.round(c.rate || 0)}%</Text>
              </View>
              <View className="cl-right">
                <Text className="cl-amount">{yuan(c.amount)}</Text>
              </View>
            </View>
          ))
        )}
      </View>

      {/* 底部确认按钮 */}
      {showConfirm && (
        <View className="bottom-bar">
          <View className="confirm-btn" onClick={doConfirm}>
            确认已收到佣金
          </View>
        </View>
      )}
    </View>
  );
}