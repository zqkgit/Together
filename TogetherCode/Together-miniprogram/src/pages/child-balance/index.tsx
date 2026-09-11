import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image } from "@tarojs/components";
import { listBalances, listLessonLogs, type BalanceChild, type LessonLogItem } from "../../services/balance";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

export default function ChildBalancePage() {
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const [children, setChildren] = useState<BalanceChild[]>([]);
  const [activeChild, setActiveChild] = useState("");
  const [logs, setLogs] = useState<LessonLogItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<"balance" | "logs">("balance");

  useEffect(() => {
    if (!isLoggedIn) {
      Taro.reLaunch({ url: "/pages/login/index" });
      return;
    }
    load();
  }, [isLoggedIn]);

  const load = async () => {
    try {
      const data = await listBalances();
      setChildren(data);
      if (data.length > 0) setActiveChild(data[0].child_id);
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (tab === "logs" && activeChild) {
      listLessonLogs({ child_id: activeChild, page: 1, page_size: 50 })
        .then((r) => setLogs(r.list))
        .catch(() => undefined);
    }
  }, [tab, activeChild]);

  const logText = (l: LessonLogItem) => {
    if (l.delta > 0) return `+${l.delta} 课时`;
    return `${l.delta} 课时`;
  };

  return (
    <View className="child-balance">
      <View className="tab-switch">
        <View className={`tab-item ${tab === "balance" ? "active" : ""}`} onClick={() => setTab("balance")}>课时余额</View>
        <View className={`tab-item ${tab === "logs" ? "active" : ""}`} onClick={() => setTab("logs")}>消课记录</View>
      </View>

      {tab === "balance" ? (
        loading ? (
          <View className="empty-tip">加载中...</View>
        ) : children.length === 0 ? (
          <View className="empty-tip">还没有孩子，先去添加学员吧</View>
        ) : (
          children.map((child) => (
            <View key={child.child_id} className="child-block">
              <View className="child-head">
                <View className="child-avatar">{child.nickname.slice(0, 1)}</View>
                <View className="child-name">
                  {child.nickname}
                  <Text className="child-count">共 {child.total_packages} 个课时包</Text>
                </View>
                <View
                  className="child-growth-btn"
                  onClick={() =>
                    Taro.navigateTo({
                      url: `/pages/child-growth/index?id=${child.child_id}&nickname=${encodeURIComponent(child.nickname)}`
                    })
                  }
                >
                  成长档案
                </View>
              </View>
              {child.balances.map((b) => (
                <View key={b.balance_id} className="card balance-card">
                  <View className="b-course">
                    <Image className="b-cover" src={b.course_cover || ""} mode="aspectFill" />
                    <View className="b-info">
                      <View className="b-title">{b.course_title}</View>
                      <View className="b-studio">{b.studio_name}</View>
                    </View>
                  </View>
                  <View className="b-stats">
                    <View className="b-stat">
                      <View className="b-num">{b.remaining_lessons}</View>
                      <View className="b-label">剩余</View>
                    </View>
                    <View className="b-stat">
                      <View className="b-num">{b.total_lessons}</View>
                      <View className="b-label">总课时</View>
                    </View>
                    <View className="b-stat">
                      <View className="b-num">{b.consumed_lessons}</View>
                      <View className="b-label">已消</View>
                    </View>
                  </View>
                  {b.valid_to && (
                    <View className="b-valid">有效期至 {String(b.valid_to).slice(0, 10)}</View>
                  )}
                </View>
              ))}
            </View>
          ))
        )
      ) : (
        <View className="logs">
          {logs.length === 0 ? (
            <View className="empty-tip">暂无消课记录</View>
          ) : (
            logs.map((l) => (
              <View key={l.log_id} className="card log-item">
                <View className="log-body">
                  <View className="log-title">{l.course_title}</View>
                  <View className="log-sub">
                    {l.child_name} · {l.studio_name}
                    {l.lesson_date ? ` · ${l.lesson_date} ${l.start_time || ""}` : ""}
                    {l.is_makeup ? " · 补课" : ""}
                  </View>
                  <View className="log-note">{l.note}</View>
                </View>
                <View className={`log-delta ${l.delta > 0 ? "plus" : "minus"}`}>{logText(l)}</View>
              </View>
            ))
          )}
        </View>
      )}
    </View>
  );
}
