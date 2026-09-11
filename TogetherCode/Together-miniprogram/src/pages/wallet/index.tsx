import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Input } from "@tarojs/components";
import { getCommissionSummary, getCommissionRecords, withdrawCommission, type CommissionSummary, type CommissionRecord } from "../../services/commission";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

export default function WalletPage() {
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const [summary, setSummary] = useState<CommissionSummary | null>(null);
  const [records, setRecords] = useState<CommissionRecord[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [withdrawAmount, setWithdrawAmount] = useState("");
  const [withdrawing, setWithdrawing] = useState(false);
  const [withdrawModal, setWithdrawModal] = useState(false);

  useEffect(() => {
    if (!isLoggedIn) {
      Taro.reLaunch({ url: "/pages/login/index" });
      return;
    }
    load();
  }, [isLoggedIn]);

  const load = async () => {
    try {
      const [s, r] = await Promise.all([
        getCommissionSummary(),
        getCommissionRecords({ page: 1, page_size: 20 })
      ]);
      setSummary(s);
      setRecords(r.list);
      setTotal(r.total);
    } catch {
      // 拦截器已提示
    }
  };

  const onReachBottom = () => {
    if (records.length < total) setPage(page + 1);
  };

  useEffect(() => {
    if (page > 1) {
      getCommissionRecords({ page, page_size: 20 }).then((r) => {
        setRecords((prev) => [...prev, ...r.list]);
        setTotal(r.total);
      }).catch(() => undefined);
    }
  }, [page]);

  const doWithdraw = async () => {
    const amount = Number(withdrawAmount);
    if (!amount || amount <= 0) {
      Taro.showToast({ title: "请输入正确的金额", icon: "none" });
      return;
    }
    if (summary && amount > summary.withdrawable) {
      Taro.showToast({ title: "超出可提现余额", icon: "none" });
      return;
    }
    setWithdrawing(true);
    try {
      await withdrawCommission(amount);
      Taro.showToast({ title: "提现申请已提交", icon: "success" });
      setWithdrawModal(false);
      setWithdrawAmount("");
      load();
    } catch {
      // 拦截器已提示
    } finally {
      setWithdrawing(false);
    }
  };

  const typeText = (t: string) => {
    const map: Record<string, string> = {
      sell: "课程分销佣金",
      share: "分享返利",
      withdraw: "提现",
      refund: "退款退回",
      settle: "结算"
    };
    return map[t] || "佣金";
  };

  return (
    <View className="wallet">
      <View className="balance-banner">
        <View className="balance-label">可提现余额（元）</View>
        <View className="balance-amount">{(summary?.withdrawable ?? 0).toFixed(2)}</View>
        <View className="balance-stats">
          <View className="b-stat">
            <View className="b-num">{(summary?.stats?.total_commission ?? 0).toFixed(2)}</View>
            <View className="b-label">累计收益</View>
          </View>
          <View className="b-stat">
            <View className="b-num">{(summary?.stats?.pending_commission ?? 0).toFixed(2)}</View>
            <View className="b-label">待结算</View>
          </View>
          <View className="b-stat">
            <View className="b-num">{(summary?.stats?.total_withdrawn ?? 0).toFixed(2)}</View>
            <View className="b-label">已提现</View>
          </View>
        </View>
        <View className="withdraw-btn" onClick={() => setWithdrawModal(true)}>申请提现</View>
      </View>

      <View className="card record-card">
        <View className="record-head">
          <Text className="record-title">收益明细</Text>
          <Text className="record-total">共 {total} 条</Text>
        </View>
        {records.length === 0 ? (
          <View className="empty-tip">还没有收益记录，发帖分享课程即可赚佣金</View>
        ) : (
          records.map((r) => (
            <View key={r.record_id} className="record-item">
              <View className="r-body">
                <View className="r-title">{typeText(r.type)}</View>
                <View className="r-sub">{String(r.created_at || "").slice(0, 16)}</View>
              </View>
              <View className={`r-amount ${Number(r.amount) >= 0 ? "plus" : "minus"}`}>
                {Number(r.amount) >= 0 ? "+" : ""}{Number(r.amount).toFixed(2)}
              </View>
            </View>
          ))
        )}
      </View>

      {withdrawModal && (
        <View className="mask" onClick={() => setWithdrawModal(false)}>
          <View className="withdraw-panel" onClick={(e) => e.stopPropagation()}>
            <View className="panel-title">申请提现</View>
            <View className="panel-hint">可提现余额 ¥{(summary?.withdrawable ?? 0).toFixed(2)}</View>
            <Input
              className="amount-input"
              type="digit"
              placeholder="请输入提现金额"
              value={withdrawAmount}
              onInput={(e) => setWithdrawAmount(e.detail.value)}
            />
            <View className={`btn-primary panel-btn ${withdrawing ? "disabled" : ""}`} onClick={doWithdraw}>
              {withdrawing ? "提交中..." : "确认提现"}
            </View>
          </View>
        </View>
      )}
    </View>
  );
}
