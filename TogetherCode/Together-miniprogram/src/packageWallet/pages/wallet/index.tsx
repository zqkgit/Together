import React, { useState } from "react";
import Taro, { useDidShow, usePullDownRefresh } from "@tarojs/taro";
import { View, Text, Image, Picker } from "@tarojs/components";
import {
  getCommissionSummary,
  requestWithdraw,
  type CommissionSummary,
  type StudioGroup,
  PAY_METHODS,
  yuan,
} from "../../../services/commission";
import { useAuthStore } from "../../../store/auth";
import "./index.scss";

type PresetKey = "thisMonth" | "lastMonth" | "last3Months" | "custom";
const PRESET_ORDER: Exclude<PresetKey, "custom">[] = ["thisMonth", "lastMonth", "last3Months"];
const PRESET_TITLES: Record<Exclude<PresetKey, "custom">, string> = {
  thisMonth: "本月",
  lastMonth: "上月",
  last3Months: "近3月",
};

function fmt(d: Date): string {
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${d.getFullYear()}-${m}-${day}`;
}

/** 日期区间，逻辑对齐 iOS DateRangePreset */
function presetDates(key: Exclude<PresetKey, "custom">): [string, string] {
  const now = new Date();
  const first = new Date(now.getFullYear(), now.getMonth(), 1);
  if (key === "thisMonth") return [fmt(first), fmt(now)];
  if (key === "lastMonth") {
    return [fmt(new Date(now.getFullYear(), now.getMonth() - 1, 1)),
            fmt(new Date(now.getFullYear(), now.getMonth(), 0))];
  }
  // 近 3 月：三个月前月初 ~ 上月末
  return [fmt(new Date(now.getFullYear(), now.getMonth() - 3, 1)),
          fmt(new Date(now.getFullYear(), now.getMonth(), 0))];
}

const initialRange = presetDates("thisMonth");

export default function WalletPage() {
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const [summary, setSummary] = useState<CommissionSummary | null>(null);
  const [withdrawing, setWithdrawing] = useState(false);
  const [methodVisible, setMethodVisible] = useState(false);
  const [activeStudioId, setActiveStudioId] = useState("");

  const [preset, setPreset] = useState<PresetKey>("thisMonth");
  const [startDate, setStartDate] = useState(initialRange[0]);
  const [endDate, setEndDate] = useState(initialRange[1]);
  const [customVisible, setCustomVisible] = useState(false);
  const [customStart, setCustomStart] = useState(initialRange[0]);
  const [customEnd, setCustomEnd] = useState(initialRange[1]);

  const load = async (s = startDate, e = endDate) => {
    if (!isLoggedIn) return;
    try {
      const data = await getCommissionSummary({ start_date: s, end_date: e });
      setSummary(data);
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

  usePullDownRefresh(async () => {
    await load();
    Taro.stopPullDownRefresh();
  });

  const periodLabel =
    preset === "custom" ? `${startDate.slice(5)}~${endDate.slice(5)}` : PRESET_TITLES[preset as Exclude<PresetKey, "custom">];

  const onTapPeriod = async () => {
    try {
      const res = await Taro.showActionSheet({
        itemList: ["本月", "上月", "近3月", "自定义"],
      });
      const idx = res.tapIndex;
      if (idx <= 2) {
        const key = PRESET_ORDER[idx];
        const [s, e] = presetDates(key);
        setPreset(key);
        setStartDate(s);
        setEndDate(e);
        load(s, e);
      } else {
        setCustomStart(startDate);
        setCustomEnd(endDate);
        setCustomVisible(true);
      }
    } catch {
      // 取消
    }
  };

  const confirmCustom = () => {
    if (!customStart || !customEnd) {
      Taro.showToast({ title: "请选择起止日期", icon: "none" });
      return;
    }
    if (customStart > customEnd) {
      Taro.showToast({ title: "开始日期不能晚于结束日期", icon: "none" });
      return;
    }
    setPreset("custom");
    setStartDate(customStart);
    setEndDate(customEnd);
    setCustomVisible(false);
    load(customStart, customEnd);
  };

  const goStudioDetail = (studioId: string) => {
    Taro.navigateTo({ url: `/packageWallet/pages/studio-commission-detail/index?id=${studioId}` });
  };

  const goWithdrawals = () => {
    Taro.navigateTo({ url: "/packageWallet/pages/commission-withdrawals/index" });
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
      {/* 收益总览渐变卡（点击进入领取记录） */}
      <View className="w-overview" onClick={goWithdrawals}>
        <View className="w-ov-top">
          <Text className="w-ov-label">累计佣金（元）</Text>
          <View className="w-ov-period" onClick={(e) => { e.stopPropagation(); onTapPeriod(); }}>
            <Text className="w-ov-period-text">{periodLabel}</Text>
            <Text className="w-ov-period-arrow">▾</Text>
          </View>
        </View>
        <View className="w-ov-amount">{yuan(stats?.total_commission)}</View>
        <View className="w-ov-stats">
          <View className="w-ov-stat">
            <Text className="w-ov-stat-label">待申请</Text>
            <Text className="w-ov-stat-value">{yuan(stats?.receivable_commission)}</Text>
          </View>
          <View className="w-ov-stat">
            <Text className="w-ov-stat-label">申请中</Text>
            <Text className="w-ov-stat-value">{yuan(stats?.applying_commission)}</Text>
          </View>
          <View className="w-ov-stat">
            <Text className="w-ov-stat-label">已到账</Text>
            <Text className="w-ov-stat-value">{yuan(stats?.settled_commission)}</Text>
          </View>
        </View>
      </View>

      {/* 工作室收益卡片 */}
      {studios.length === 0 ? (
        <View className="w-empty">
          <View className="w-empty-badge">
            <Text className="w-empty-badge-text">¥</Text>
          </View>
          <Text className="w-empty-text">还没有推广收益{"\n"}分享课程或海报即可获得佣金</Text>
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

      {/* 自定义日期区间弹层 */}
      {customVisible && (
        <View className="w-mask" onClick={() => setCustomVisible(false)}>
          <View className="w-date-sheet" onClick={(e) => e.stopPropagation()}>
            <View className="w-sheet-title">选择时间范围</View>
            <Picker mode="date" value={customStart} onChange={(e) => setCustomStart(e.detail.value)}>
              <View className="w-date-row">
                <Text className="w-date-row-label">开始日期</Text>
                <Text className="w-date-row-value">{customStart || "请选择"}</Text>
              </View>
            </Picker>
            <Picker mode="date" value={customEnd} onChange={(e) => setCustomEnd(e.detail.value)}>
              <View className="w-date-row">
                <Text className="w-date-row-label">结束日期</Text>
                <Text className="w-date-row-value">{customEnd || "请选择"}</Text>
              </View>
            </Picker>
            <View className="w-date-confirm" onClick={confirmCustom}>确定</View>
          </View>
        </View>
      )}

      {/* 收款方式选择弹窗 */}
      {methodVisible && (
        <View className="w-mask" onClick={() => setMethodVisible(false)}>
          <View className="w-method-sheet" onClick={(e) => e.stopPropagation()}>
            <View className="w-sheet-title w-sheet-title-tip">选择收款方式（线下结算，平台不经手资金）</View>
            {PAY_METHODS.map((m) => (
              <View key={m.value} className="w-sheet-item" onClick={() => pickMethod(m.value)}>
                {m.label}
              </View>
            ))}
          </View>
        </View>
      )}

      {withdrawing && (
        <View className="w-loading">
          <View className="w-loading-text">提交中...</View>
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
  const placeholder = (group.name || "工").trim().charAt(0);
  return (
    <View className="w-studio" onClick={onTap}>
      <View className="w-st-head">
        {group.cover ? (
          <Image className="w-st-cover" src={group.cover} mode="aspectFill" />
        ) : (
          <View className="w-st-cover w-st-cover-ph">
            <Text className="w-st-cover-text">{placeholder}</Text>
          </View>
        )}
        <Text className="w-st-name">{group.name || "工作室"}</Text>
        <Text className="w-st-chevron">›</Text>
      </View>
      <View className="w-st-divider" />
      <View className="w-st-stats">
        <View className="w-st-stat">
          <Text className={`w-st-num ${canWithdraw ? "is-hot" : ""}`}>{yuan(group.receivable)}</Text>
          <Text className="w-st-label">待申请</Text>
        </View>
        <View className="w-st-stat">
          <Text className="w-st-num">{yuan(group.applying)}</Text>
          <Text className="w-st-label">申请中</Text>
        </View>
        <View className="w-st-stat">
          <Text className="w-st-num">{yuan(group.settled)}</Text>
          <Text className="w-st-label">已到账</Text>
        </View>
      </View>
      {canWithdraw && (
        <View
          className="w-withdraw"
          onClick={(e) => { e.stopPropagation(); onWithdraw(); }}
        >
          一键领取 {yuan(group.receivable)}
        </View>
      )}
    </View>
  );
}
