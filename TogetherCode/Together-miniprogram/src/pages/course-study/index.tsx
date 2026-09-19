import React, { useEffect, useMemo, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Textarea } from "@tarojs/components";
import {
  getCourseSchedules,
  listMyLeaves,
  submitLeave,
  cancelLeave,
  type CourseScheduleItem,
  type CourseScheduleSummary,
  type MyLeaveItem
} from "../../services/course";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

const WEEK_LABELS = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"];

function weekdayText(date: string): string {
  if (!date) return "";
  const d = new Date(`${date}T00:00:00`);
  return WEEK_LABELS[d.getDay()] || "";
}

function mmdd(date: string): string {
  if (!date || date.length < 10) return date;
  return date.slice(5, 10);
}

export default function CourseStudyPage() {
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const params = useMemo(() => {
    const p = Taro.getCurrentInstance().router?.params || {};
    return {
      child_id: p.child_id || "",
      course_id: p.course_id || "",
      course_title: decodeURIComponent(p.course_title || "")
    };
  }, []);

  const [summary, setSummary] = useState<CourseScheduleSummary | null>(null);
  const [schedules, setSchedules] = useState<CourseScheduleItem[]>([]);
  const [leaveMap, setLeaveMap] = useState<Record<string, MyLeaveItem>>({});
  const [loading, setLoading] = useState(true);

  // 请假弹层
  const [showLeave, setShowLeave] = useState(false);
  const [leaveReason, setLeaveReason] = useState("");
  const [targetSchedule, setTargetSchedule] = useState<CourseScheduleItem | null>(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    Taro.setNavigationBarTitle({ title: params.course_title || "课程学习" });
    if (!isLoggedIn) {
      Taro.reLaunch({ url: "/pages/login/index" });
      return;
    }
    load();
  }, [isLoggedIn]);

  const load = async () => {
    setLoading(true);
    try {
      const [data, leaves] = await Promise.all([
        getCourseSchedules({ child_id: params.child_id, course_id: params.course_id }),
        listMyLeaves()
          .then((r) => r.list)
          .catch(() => [])
      ]);
      setSummary(data);
      setSchedules(data.list || []);

      // schedule_id -> 请假单（状态优先级：0待审批 > 1已同意 > 2已婉拒 > 3已取消）
      const map: Record<string, MyLeaveItem> = {};
      const rank = [0, 1, 2, 3];
      for (const item of leaves) {
        if (!item.schedule_id) continue;
        if (item.child_id && item.child_id !== params.child_id) continue;
        const old = map[item.schedule_id];
        if (old) {
          const oldRank = rank.indexOf(old.status) >= 0 ? rank.indexOf(old.status) : 9;
          const newRank = rank.indexOf(item.status) >= 0 ? rank.indexOf(item.status) : 9;
          if (newRank >= oldRank) continue;
        }
        map[item.schedule_id] = item;
      }
      setLeaveMap(map);
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const openLeave = (s: CourseScheduleItem) => {
    setTargetSchedule(s);
    setLeaveReason("");
    setShowLeave(true);
  };

  const doSubmitLeave = async () => {
    if (!targetSchedule || !summary) return;
    const reason = leaveReason.trim();
    if (!reason) {
      Taro.showToast({ title: "请填写请假原因", icon: "none" });
      return;
    }
    setSubmitting(true);
    try {
      await submitLeave({
        class_id: summary.class_id || "",
        child_id: params.child_id,
        schedule_id: targetSchedule.schedule_id,
        reason
      });
      Taro.showToast({ title: "请假已提交", icon: "success" });
      setShowLeave(false);
      load();
    } catch {
      // 拦截器已提示
    } finally {
      setSubmitting(false);
    }
  };

  const doCancelLeave = (item: MyLeaveItem) => {
    Taro.showModal({
      title: "撤销请假",
      content: "确认撤销这条请假申请吗？",
      confirmColor: "#2f5d45",
      success: async (res) => {
        if (!res.confirm) return;
        try {
          await cancelLeave(item.leave_id);
          Taro.showToast({ title: "已撤销", icon: "success" });
          load();
        } catch {
          // 拦截器已提示
        }
      }
    });
  };

  // 请假状态（对齐 app：leaveMap.status+1，与 item.leave_status 语义一致）
  // 1 请假中 / 2 已请假 / 3 婉拒 / 4 已取消
  const leaveStatusOf = (s: CourseScheduleItem): number => {
    const leave = leaveMap[s.schedule_id];
    if (leave) return (leave.status ?? 0) + 1;
    return s.leave_status || 0;
  };

  // 右侧状态胶囊（对齐 app configure）
  const pillOf = (s: CourseScheduleItem): { text: string; cls: string } => {
    const ls = leaveStatusOf(s);
    if (ls === 1) return { text: "请假中", cls: "pill-leave" };
    if (ls === 2) return { text: "已请假", cls: "pill-approved" };
    if (s.status === 3) return { text: "待排课", cls: "pill-pending" };
    if (s.status === 1) return { text: "已上", cls: "pill-approved" };
    if (s.status === 2) return { text: "今天", cls: "pill-today" };
    return { text: "待上", cls: "pill-pending" };
  };

  // 左侧操作按钮（对齐 app：撤销请假 / 请假）
  const actionOf = (s: CourseScheduleItem) => {
    const ls = leaveStatusOf(s);
    const leave = leaveMap[s.schedule_id];
    if (ls === 1 && leave) {
      return { type: "cancel" as const, text: "撤销请假" };
    }
    if (s.status === 3) return null;
    const canLeave = (s.status === 0 || s.status === 2) && (ls === 0 || ls === 3 || ls === 4);
    if (canLeave) return { type: "leave" as const, text: "请假" };
    return null;
  };

  return (
    <View className="course-study">
      {loading ? (
        <View className="state-tip">加载中...</View>
      ) : schedules.length === 0 ? (
        <View className="state-tip">暂无课时安排</View>
      ) : (
        <>
          <View className="study-head">
            <View className="head-body">
              <Text className="head-title" numberOfLines={1}>{summary?.course_title || params.course_title}</Text>
              <Text className="head-sub" numberOfLines={1}>
                {summary?.studio_name || ""}
                {summary?.teacher_name && summary.teacher_name !== "-" ? `·${summary.teacher_name}` : ""}
              </Text>
            </View>
            <Text className="head-pill">
              已学 {summary?.consumed_lessons ?? 0}/{summary?.total_lessons ?? 0} 节
            </Text>
          </View>

          <View className="lesson-list">
            {schedules.map((s) => {
              const pill = pillOf(s);
              const action = actionOf(s);
              const leave = leaveMap[s.schedule_id];
              const pending = s.status === 3;
              return (
                <View key={s.schedule_id || `pending-${s.lesson_no}`} className={`lesson-card${pending ? " pending-card" : ""}`}>
                  <View className="lesson-main">
                    <Text className="lesson-name" numberOfLines={1}>
                      {pending
                        ? s.lesson_title && s.lesson_title !== `第${s.lesson_no}课`
                          ? `第${s.lesson_no || "-"}课·${s.lesson_title}`
                          : `第${s.lesson_no || "-"}课`
                        : `第${s.lesson_no || "-"}课·${s.lesson_title || "未命名课次"}`}
                    </Text>
                    <View className="lesson-row">
                      {action && (
                        <Text
                          className={`op-btn ${action.type === "cancel" ? "op-cancel" : "op-leave"}`}
                          onClick={() => {
                            if (action.type === "cancel" && leave) doCancelLeave(leave);
                            else openLeave(s);
                          }}
                        >
                          {action.text}
                        </Text>
                      )}
                      {pending ? (
                        <Text className="lesson-date">待排课</Text>
                      ) : (
                        <>
                          <Text className="lesson-date">{mmdd(s.lesson_date)} {weekdayText(s.lesson_date)}</Text>
                          <Text className="lesson-time">
                            {s.start_time || ""}
                            {s.end_time ? `-${s.end_time}` : ""}
                          </Text>
                        </>
                      )}
                    </View>
                  </View>
                  <Text className={`pill ${pill.cls}`}>{pill.text}</Text>
                </View>
              );
            })}
          </View>
        </>
      )}

      {/* 请假弹层 */}
      {showLeave && (
        <View className="mask" onClick={() => setShowLeave(false)}>
          <View className="leave-sheet" onClick={(e) => e.stopPropagation()}>
            <Text className="sheet-title">请假申请</Text>
            <Text className="sheet-desc">
              {targetSchedule ? `第${targetSchedule.lesson_no}课·${targetSchedule.lesson_title || ""}` : ""}
            </Text>
            <Textarea
              className="sheet-textarea"
              style={{ height: "220rpx", minHeight: "220rpx" }}
              placeholder="请填写请假原因（必填）"
              placeholderStyle="color:#9c948a"
              value={leaveReason}
              maxlength={100}
              onInput={(e) => setLeaveReason(e.detail.value)}
            />
            <View className="sheet-actions">
              <Text className="sheet-cancel" onClick={() => setShowLeave(false)}>
                取消
              </Text>
              <Text
                className={`sheet-confirm ${submitting ? "sheet-disabled" : ""}`}
                onClick={() => !submitting && doSubmitLeave()}
              >
                {submitting ? "提交中..." : "提交"}
              </Text>
            </View>
          </View>
        </View>
      )}
    </View>
  );
}
