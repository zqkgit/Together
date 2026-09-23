import React, { useEffect, useState } from "react";
import Taro, { useDidShow } from "@tarojs/taro";
import { View, Text, Image, ScrollView } from "@tarojs/components";
import {
  getCommissionSummary,
  getCommissionRecords,
  requestWithdraw,
  type CommissionSummary,
  type CommissionRecord,
  type StudioGroup,
  PAY_METHODS,
  yuan,
  fmtTime,
} from "../../services/commission";
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
    } catch {
      // 拦截器已提示
    }
  };

  useDidShow(() => {
    load();
  });

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

  const startWithdraw = () => {
    setMethodVisible(true);
  };

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

  return (
    <View className="studio-detail">
      {/* 工作室汇总卡 */}
      {group && (
        <View className="card summary-card">
          <View className="sum-header">
            <View className="sum-cover-wrap">
              {group.cover ? (
                <Image className="sum-cover" src={group.cover} mode="aspectFill" />
              ) : (
                <View className="sum-cover sum-cover-placeholder">🏠</View>
              )}
            </View>
            <Text className="sum-name">{group.name || "工作室"}</Text>
          </View>
          <View className="sum-divider" />
          <View className="sum-stats">
            <View className="sum-stat">
              <View className={`sum-num ${receivable > 0 ? "highlight" : ""}`}>
                {yuan(group.receivable)}
              </View>
              <View className="sum-label">待申请</View>
            </View>
            <View className="sum-stat">
              <View className="sum-num">{yuan(group.applying)}</View>
              <View className="sum-label">申请中</View>
            </View>
            <View className="sum-stat">
              <View className="sum-num">{yuan(group.settled)}</View>
              <View className="sum-label">已到账</View>
            </View>
          </View>
        </View>
      )}

      {/* 按课程分组 */}
      {!hasLoaded ? null : courseGroups.length === 0 ? (
        <View className="card empty-card">
          <View className="empty-icon">📚</View>
          <View className="empty-text">暂无课程推广</View>
        </View>
      ) : (
        courseGroups.map((cg) => (
          <View key={cg.courseId} className="card course-card">
            <View className="course-header">
              <View className="course-cover-wrap">
                {cg.course?.cover ? (
                  <Image className="course-cover" src={cg.course.cover} mode="aspectFill" />
                ) : (
                  <View className="course-cover course-cover-placeholder">📖</View>
                )}
              </View>
              <View className="course-info">
                <Text className="course-title">{cg.course?.title || "未知课程"}</Text>
                <Text className="course-count">带来 {cg.count} 人报名</Text>
              </View>
              <Text className="course-total">{yuan(cg.total)}</Text>
            </View>
            <View className="course-divider" />
            {cg.items.map((item) => (
              <View key={item.commission_id} className="record-row">
                <View className="r-left">
                  <Text className="r-order">
                    订单 ****{String(item.order_id || "").slice(-6)} · {item.rate || 0}% 返
                  </Text>
                </View>
                <Text className={`r-status status-${item.status || 0}`}>
                  {item.status_text || ""}
                </Text>
                <Text className="r-amount">{yuan(item.amount)}</Text>
              </View>
            ))}
          </View>
        ))
      )}

      {/* 底部领取按钮 */}
      {receivable > 0 && (
        <View className="bottom-bar">
          <View className="bottom-btn" onClick={startWithdraw}>
            一键领取 {yuan(receivable)}
          </View>
        </View>
      )}

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