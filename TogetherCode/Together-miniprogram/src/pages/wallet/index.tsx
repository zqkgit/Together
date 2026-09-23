import React, { useEffect, useState } from "react";
import Taro, { useDidShow } from "@tarojs/taro";
import { View, Text, Image, ScrollView } from "@tarojs/components";
import {
  getCommissionSummary,
  requestWithdraw,
  type CommissionSummary,
  type StudioGroup,
  PAY_METHODS,
  yuan,
} from "../../services/commission";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

export default function WalletPage() {
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const [summary, setSummary] = useState<CommissionSummary | null>(null);
  const [loading, setLoading] = useState(false);
  const [withdrawing, setWithdrawing] = useState(false);
  const [methodVisible, setMethodVisible] = useState(false);
  const [activeStudioId, setActiveStudioId] = useState("");

  const load = async () => {
    if (!isLoggedIn) return;
    try {
      const s = await getCommissionSummary();
      setSummary(s);
    } catch {
      // 拦截器已提示
    }
  };

  useDidShow(() => {
    if (!isLoggedIn) {
      Taro.reLaunch({ url: "/pages/login/index" });
      return;
    }
    load();
  });

  const goStudioDetail = (studioId: string) => {
    Taro.navigateTo({ url: `/pages/studio-commission-detail/index?id=${studioId}` });
  };

  const goWithdrawals = () => {
    Taro.navigateTo({ url: "/pages/commission-withdrawals/index" });
  };

  const startWithdraw = (studioId: string) => {
    setActiveStudioId(studioId);
    setMethodVisible(true);
  };

  const pickMethod = async (method: string) => {
    setMethodVisible(false);
    setWithdrawing(true);
    try {
      await requestWithdraw(activeStudioId, method);
      Taro.showToast({ title: "领取申请已提交，等待工作室打款", icon: "none" });
      load();
    } catch {
      // 拦截器已提示
    } finally {
      setWithdrawing(false);
    }
  };

  const stats = summary?.stats;
  const studios = summary?.studios ?? [];

  return (
    <View className="wallet">
      {/* 收益总览深色卡 */}
      <View className="overview-card">
        <View className="ov-label">累计佣金（元）</View>
        <View className="ov-amount">{yuan(stats?.total_commission)}</View>
        <View className="ov-stats">
          <View className="ov-stat">
            <View className="ov-num">{yuan(stats?.receivable_commission)}</View>
            <View className="ov-desc">待申请</View>
          </View>
          <View className="ov-stat">
            <View className="ov-num">{yuan(stats?.applying_commission)}</View>
            <View className="ov-desc">申请中</View>
          </View>
          <View className="ov-stat">
            <View className="ov-num">{yuan(stats?.settled_commission)}</View>
            <View className="ov-desc">已到账</View>
          </View>
        </View>
      </View>

      {/* 工作室收益卡片 */}
      {studios.length === 0 ? (
        <View className="card empty-card">
          <View className="empty-icon">📦</View>
          <View className="empty-text">还没有推广收益，分享课程或海报即可获得佣金</View>
        </View>
      ) : (
        studios.map((s) => (
          <StudioCard
            key={s.studio_id}
            group={s}
            onTap={() => goStudioDetail(s.studio_id)}
            onWithdraw={() => startWithdraw(s.studio_id)}
          />
        ))
      )}

      {/* 领取记录入口 */}
      <View className="card entry-card" onClick={goWithdrawals}>
        <Text className="entry-title">领取记录</Text>
        <Text className="entry-arrow">›</Text>
      </View>

      {/* 收款方式选择弹窗 */}
      {methodVisible && (
        <View className="mask" onClick={() => setMethodVisible(false)}>
          <View className="method-sheet" onClick={(e) => e.stopPropagation()}>
            <View className="sheet-title">选择收款方式（线下结算，平台不经手资金）</View>
            {PAY_METHODS.map((m) => (
              <View
                key={m.value}
                className="sheet-item"
                onClick={() => pickMethod(m.value)}
              >
                {m.label}
              </View>
            ))}
          </View>
        </View>
      )}

      {withdrawing && (
        <View className="loading-mask">
          <View className="loading-text">提交中...</View>
        </View>
      )}
    </View>
  );
}

function StudioCard({
  group,
  onTap,
  onWithdraw,
}: {
  group: StudioGroup;
  onTap: () => void;
  onWithdraw: () => void;
}) {
  const canWithdraw = group.receivable > 0;
  return (
    <View className="card studio-card">
      <View className="studio-header" onClick={onTap}>
        <View className="studio-cover-wrap">
          {group.cover ? (
            <Image className="studio-cover" src={group.cover} mode="aspectFill" />
          ) : (
            <View className="studio-cover studio-cover-placeholder">🏠</View>
          )}
        </View>
        <View className="studio-name">{group.name || "工作室"}</View>
        <View className="studio-chevron">›</View>
      </View>
      <View className="studio-divider" />
      <View className="studio-stats">
        <View className="studio-stat">
          <View className={`studio-num ${canWithdraw ? "highlight" : ""}`}>
            {yuan(group.receivable)}
          </View>
          <View className="studio-label">待申请</View>
        </View>
        <View className="studio-stat">
          <View className="studio-num">{yuan(group.applying)}</View>
          <View className="studio-label">申请中</View>
        </View>
        <View className="studio-stat">
          <View className="studio-num">{yuan(group.settled)}</View>
          <View className="studio-label">已到账</View>
        </View>
      </View>
      {canWithdraw && (
        <View className="withdraw-btn" onClick={onWithdraw}>
          一键领取 {yuan(group.receivable)}
        </View>
      )}
    </View>
  );
}