import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image, ScrollView } from "@tarojs/components";
import {
  getRefundDetail,
  confirmRefundReceived,
  type RefundDetail
} from "../../services/order";
import { APP_CONFIG } from "../../config";
import "./index.scss";

/** 后端本地存储返回 /uploads/... 相对路径，开发环境补全为后端域名；OSS 完整 URL 原样返回 */
function resolveImg(p?: string | null): string {
  if (!p) return "";
  if (/^https?:\/\//.test(p)) return p;
  const origin = APP_CONFIG.BASE_URL.replace(/\/v1\/?$/, "");
  return `${origin}${p.startsWith("/") ? "" : "/"}${p}`;
}

type RefundStep = RefundDetail["steps"][number];

/** 状态卡描述文案（对齐 iOS RefundStatusCell） */
const STATUS_DESC: Record<number, string> = {
  0: "退款申请已提交，等待机构审核",
  1: "机构已登记线下退款，请核对下方凭证后，点击底部「确认收到退款」",
  2: "申请未通过，可查看驳回原因后在订单详情重新申请",
  3: "退款已完成，相应课时已扣减"
};

interface InfoRow {
  label: string;
  value: string;
  color?: string;
}

export default function RefundDetailPage() {
  const [detail, setDetail] = useState<RefundDetail | null>(null);
  const [confirming, setConfirming] = useState(false);

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

  const fmt = (t: string | null | undefined) => {
    if (!t) return "";
    const d = new Date(t);
    if (Number.isNaN(d.getTime())) return String(t).slice(0, 16).replace("T", " ");
    const p = (n: number) => String(n).padStart(2, "0");
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
  };

  const previewVoucher = (idx: number) => {
    const urls = (detail?.voucher_images || []).map(resolveImg);
    if (!urls.length) return;
    Taro.previewImage({ urls, current: urls[idx] });
  };

  const onConfirm = async () => {
    if (!detail || confirming) return;
    const modal = await Taro.showModal({
      title: "请确认已收到退款",
      content:
        "请确认你已在线下实际收到机构退回的款项。确认后将扣减相应课时、订单转为已退款，且不可撤销。",
      confirmText: "已收到，确认",
      cancelText: "再想想",
      confirmColor: "#14A640"
    });
    if (!modal.confirm) return;
    setConfirming(true);
    try {
      const latest = await confirmRefundReceived(detail.refund_id);
      setDetail(latest);
      Taro.showToast({ title: "已确认收款", icon: "success" });
    } catch {
      // 拦截器已提示
    } finally {
      setConfirming(false);
    }
  };

  if (!detail) {
    return <View className="refund-detail"><View className="empty-tip">加载中...</View></View>;
  }

  // 状态卡
  const statusColor = detail.status === 2 ? "#B03A2B" : "#14A640";
  const statusDesc = STATUS_DESC[detail.status] || "退款处理中，请留意到账通知";

  // 退款信息行（对齐 iOS infoRows）
  const reduced =
    detail.approved_lessons != null && detail.approved_lessons < detail.requested_lessons;
  const rows: InfoRow[] = [];
  rows.push({ label: "申请课时", value: `${detail.requested_lessons}节（可退 ${detail.refundable_lessons}节）` });
  if (detail.approved_lessons != null) {
    rows.push(
      reduced
        ? {
            label: "本次实退",
            value: `${detail.approved_lessons}节（申请${detail.requested_lessons}节，期间已上课）`,
            color: "#A87A3E"
          }
        : { label: "本次实退", value: `${detail.approved_lessons}节`, color: "#14A640" }
    );
  }
  if (detail.refund_method_text) {
    rows.push({ label: "退款方式", value: detail.refund_method_text });
  }
  if (detail.unit_price_text) {
    rows.push({ label: "课时单价", value: detail.unit_price_text });
  }
  rows.push({ label: "退款金额", value: detail.amount_text, color: "#14A640" });
  if (detail.status === 2 && detail.reject_reason) {
    rows.push({ label: "驳回原因", value: detail.reject_reason, color: "#B03A2B" });
  }
  if (detail.reason) {
    rows.push({ label: "退款原因", value: detail.reason });
  }
  if (fmt(detail.created_at)) rows.push({ label: "申请时间", value: fmt(detail.created_at) });
  if (fmt(detail.reviewed_at)) rows.push({ label: "审核时间", value: fmt(detail.reviewed_at) });
  if (fmt(detail.confirmed_at)) rows.push({ label: "确认时间", value: fmt(detail.confirmed_at) });

  const vouchers = detail.voucher_images || [];

  const stepTime = (s: RefundStep) => {
    const t = fmt(s.time);
    if (t) return t;
    return s.current ? "等待处理中" : "-";
  };

  return (
    <View className={`refund-detail ${detail.can_confirm ? "has-action" : ""}`}>
      {/* 状态卡 */}
      <View className="section section-first">
        <View className="card status-card">
          <Text className="status-name" style={{ color: statusColor }}>
            {detail.status_text || "退款"}
          </Text>
          <Text className="status-amount">{detail.amount_text || "-"}</Text>
          <Text className="status-desc">{statusDesc}</Text>
        </View>
      </View>

      {/* 退款信息 */}
      <View className="section">
        <View className="section-title">退款信息</View>
        <View className="card info-card">
          {rows.map((r, i) => (
            <View key={i} className="info-row">
              <Text className="info-label">{r.label}</Text>
              <Text
                className="info-value"
                style={r.color ? { color: r.color } : undefined}
              >
                {r.value}
              </Text>
            </View>
          ))}
        </View>
      </View>

      {/* 机构打款凭证（仅有凭证时） */}
      {vouchers.length > 0 && (
        <View className="section">
          <View className="section-title">机构打款凭证</View>
          <View className="card voucher-card">
            <ScrollView scrollX className="voucher-scroll" enhanced showScrollbar={false}>
              <View className="voucher-row">
                {vouchers.map((img, idx) => (
                  <Image
                    key={img}
                    className="voucher-img"
                    src={resolveImg(img)}
                    mode="aspectFill"
                    onClick={() => previewVoucher(idx)}
                  />
                ))}
              </View>
            </ScrollView>
          </View>
        </View>
      )}

      {/* 退款进度 */}
      <View className="section">
        <View className="section-title">退款进度</View>
        <View className="card steps-card">
          {detail.steps.map((s, i) => {
            const active = s.done || s.current;
            const last = i === detail.steps.length - 1;
            return (
              <View key={s.key} className={`step ${active ? "active" : ""}`}>
                <View className="step-dot" />
                {!last && <View className="step-line" />}
                <View className="step-text">
                  <Text className="step-name">{s.title}</Text>
                  <Text className="step-time">{stepTime(s)}</Text>
                </View>
              </View>
            );
          })}
        </View>
      </View>

      {/* 底部固定操作：待家长确认 */}
      {detail.can_confirm && (
        <View className="action-bar">
          <View className={`action-btn ${confirming ? "loading" : ""}`} onClick={onConfirm}>
            {confirming ? "提交中…" : "确认收到退款"}
          </View>
        </View>
      )}
    </View>
  );
}
