import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image } from "@tarojs/components";
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

  const fmt = (t: string | null) => {
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
      confirmColor: "#2f5d45"
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

  const reduced =
    detail.approved_lessons != null && detail.approved_lessons < detail.requested_lessons;
  const vouchers = detail.voucher_images || [];

  return (
    <View className={`refund-detail ${detail.can_confirm ? "has-action" : ""}`}>
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

      {/* 驳回原因 */}
      {detail.status === 2 && detail.reject_reason ? (
        <View className="card reject-card">
          <Text className="reject-label">驳回原因</Text>
          <Text className="reject-text">{detail.reject_reason}</Text>
          <Text className="reject-hint">你可在订单详情重新发起退款申请</Text>
        </View>
      ) : null}

      {/* 课程信息 */}
      <View className="card course-card">
        <Image className="course-cover" src={resolveImg(detail.course_cover)} mode="aspectFill" />
        <View className="course-body">
          <View className="course-title">{detail.course_title}</View>
          <View className="course-sub">{detail.studio_name}</View>
          <View className="course-sub">学员：{detail.child_name}</View>
        </View>
      </View>

      {/* 退款信息 */}
      <View className="card info-card">
        <View className="info-row">
          <Text className="info-label">申请课时</Text>
          <Text className="info-value">{detail.requested_lessons} 课时（可退 {detail.refundable_lessons} 课时）</Text>
        </View>
        {detail.approved_lessons != null && (
          <View className="info-row">
            <Text className="info-label">本次实退</Text>
            <Text className={`info-value ${reduced ? "less" : "strong"}`}>
              {detail.approved_lessons} 课时{reduced ? `（申请 ${detail.requested_lessons}，期间已上课）` : ""}
            </Text>
          </View>
        )}
        {detail.refund_method_text && (
          <View className="info-row">
            <Text className="info-label">退款方式</Text>
            <Text className="info-value">{detail.refund_method_text}</Text>
          </View>
        )}
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
        {detail.confirmed_at && (
          <View className="info-row">
            <Text className="info-label">确认时间</Text>
            <Text className="info-value">{fmt(detail.confirmed_at)}</Text>
          </View>
        )}
      </View>

      {/* 机构打款凭证 */}
      {vouchers.length > 0 && (
        <View className="card voucher-card">
          <View className="voucher-head">机构打款凭证</View>
          <View className="voucher-grid">
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
          <View className="voucher-tip">请核对款项是否实际到账，再点击下方「确认收到退款」</View>
        </View>
      )}

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

      {/* 底部固定操作：待家长确认 */}
      {detail.can_confirm && (
        <View className="action-bar">
          <View className="action-tip">机构已登记线下退款，请确认是否收到</View>
          <View className={`action-btn ${confirming ? "loading" : ""}`} onClick={onConfirm}>
            {confirming ? "提交中..." : "确认收到退款"}
          </View>
        </View>
      )}
    </View>
  );
}
