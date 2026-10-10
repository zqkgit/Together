import React, { useState } from "react";
import Taro, { useDidShow, usePullDownRefresh } from "@tarojs/taro";
import { View, Text, Image } from "@tarojs/components";
import {
  getCommissionSummary,
  getCommissionRecords,
  requestWithdraw,
  type CommissionRecord,
  type StudioGroup,
  PAY_METHODS,
  yuan,
} from "../../../services/commission";
import "./index.scss";

/** 按课程聚合 */
interface CourseGroup {
  courseId: string;
  course: CommissionRecord["course"];
  items: CommissionRecord[];
  total: number;
  count: number;
}

export default function StudioCommissionDetailPage() {
  const params = Taro.getCurrentInstance().router?.params || {};
  const studioId = params.id || "";

  const [group, setGroup] = useState<StudioGroup | null>(null);
  const [courseGroups, setCourseGroups] = useState<CourseGroup[]>([]);
  const [hasLoaded, setHasLoaded] = useState(false);
  const [methodVisible, setMethodVisible] = useState(false);
  const [withdrawing, setWithdrawing] = useState(false);

  const buildGroups = (records: CommissionRecord[]): CourseGroup[] => {
    const order: string[] = [];
    const map: Record<string, CommissionRecord[]> = {};
    for (const item of records) {
      const cid = item.course?.course_id || "unknown";
      if (!map[cid]) {
        map[cid] = [];
        order.push(cid);
      }
      map[cid].push(item);
    }
    return order.map((cid) => ({
      courseId: cid,
      course: map[cid][0]?.course || null,
      items: map[cid],
      total: map[cid].reduce((sum, r) => sum + (r.amount || 0), 0),
      count: map[cid].length,
    }));
  };

  const load = async () => {
    if (!studioId) return;
    try {
      const [summary, records] = await Promise.all([
        getCommissionSummary(),
        getCommissionRecords({ studio_id: studioId, page_size: 100 }),
      ]);
      const studio = summary.studios?.find((s) => s.studio_id === studioId) || null;
      setGroup(studio);
      setCourseGroups(buildGroups(records.list));
      setHasLoaded(true);
      if (studio?.name) {
        Taro.setNavigationBarTitle({ title: studio.name });
      }
    } catch {
      // 拦截器已提示
    }
  };

  useDidShow(() => {
    load();
  });

  usePullDownRefresh(async () => {
    await load();
    Taro.stopPullDownRefresh();
  });

  const pickMethod = async (method: string) => {
    setMethodVisible(false);
    setWithdrawing(true);
    try {
      await requestWithdraw(studioId, method);
      Taro.showToast({ title: "领取申请已提交，等待工作室打款", icon: "none" });
      load();
    } catch {
      // 拦截器已提示
    } finally {
      setWithdrawing(false);
    }
  };

  const receivable = group?.receivable ?? 0;
  const studioPlaceholder = (group?.name || "工").trim().charAt(0);

  return (
    <View className={`scd-page ${receivable > 0 ? "has-bar" : ""}`}>
      {/* 工作室汇总卡 */}
      {group && (
        <View className="scd-sum">
          <View className="scd-sum-head">
            {group.cover ? (
              <Image className="scd-sum-cover" src={group.cover} mode="aspectFill" />
            ) : (
              <View className="scd-sum-cover scd-sum-cover-ph">
                <Text className="scd-sum-cover-text">{studioPlaceholder}</Text>
              </View>
            )}
            <Text className="scd-sum-name">{group.name || "工作室"}</Text>
          </View>
          <View className="scd-sum-divider" />
          <View className="scd-sum-stats">
            <View className="scd-sum-stat">
              <Text className={`scd-sum-num ${receivable > 0 ? "is-hot" : ""}`}>{yuan(group.receivable)}</Text>
              <Text className="scd-sum-label">待申请</Text>
            </View>
            <View className="scd-sum-stat">
              <Text className="scd-sum-num">{yuan(group.applying)}</Text>
              <Text className="scd-sum-label">申请中</Text>
            </View>
            <View className="scd-sum-stat">
              <Text className="scd-sum-num">{yuan(group.settled)}</Text>
              <Text className="scd-sum-label">已到账</Text>
            </View>
          </View>
        </View>
      )}

      {/* 按课程分组 */}
      {!hasLoaded ? null : courseGroups.length === 0 ? (
        <View className="scd-empty">
          <View className="scd-empty-badge">
            <Text className="scd-empty-badge-text">课</Text>
          </View>
          <Text className="scd-empty-text">暂无课程推广</Text>
        </View>
      ) : (
        courseGroups.map((cg) => {
          const coursePlaceholder = (cg.course?.title || "课").trim().charAt(0);
          return (
            <View key={cg.courseId} className="scd-course">
              <View className="scd-c-head">
                {cg.course?.cover ? (
                  <Image className="scd-c-cover" src={cg.course.cover} mode="aspectFill" />
                ) : (
                  <View className="scd-c-cover scd-c-cover-ph">
                    <Text className="scd-c-cover-text">{coursePlaceholder}</Text>
                  </View>
                )}
                <View className="scd-c-info">
                  <Text className="scd-c-title">{cg.course?.title || "未知课程"}</Text>
                  <Text className="scd-c-count">带来 {cg.count} 人报名</Text>
                </View>
                <Text className="scd-c-total">{yuan(cg.total)}</Text>
              </View>
              <View className="scd-c-divider" />
              {cg.items.map((item) => (
                <View key={item.commission_id} className="scd-record">
                  <Text className="scd-r-order">
                    订单 ****{String(item.order_id || "").slice(-6)} · {item.rate || 0}% 返
                  </Text>
                  <Text className={`scd-r-status scd-st-${item.status || 0}`}>{item.status_text || ""}</Text>
                  <Text className="scd-r-amount">{yuan(item.amount)}</Text>
                </View>
              ))}
            </View>
          );
        })
      )}

      {/* 底部领取按钮 */}
      {receivable > 0 && (
        <View className="scd-bar">
          <View className="scd-bar-btn" onClick={() => setMethodVisible(true)}>
            一键领取 {yuan(receivable)}
          </View>
        </View>
      )}

      {/* 收款方式选择弹窗 */}
      {methodVisible && (
        <View className="scd-mask" onClick={() => setMethodVisible(false)}>
          <View className="scd-sheet" onClick={(e) => e.stopPropagation()}>
            <View className="scd-sheet-title">选择收款方式（线下结算，平台不经手资金）</View>
            {PAY_METHODS.map((m) => (
              <View key={m.value} className="scd-sheet-item" onClick={() => pickMethod(m.value)}>
                {m.label}
              </View>
            ))}
          </View>
        </View>
      )}

      {withdrawing && (
        <View className="scd-loading">
          <View className="scd-loading-text">提交中...</View>
        </View>
      )}
    </View>
  );
}
