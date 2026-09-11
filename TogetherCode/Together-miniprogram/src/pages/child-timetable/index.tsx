import React, { useEffect, useMemo, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text } from "@tarojs/components";
import { getChildCalendar, type CalendarEvent, type ChildCalendar } from "../../services/balance";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

const WEEK_LABELS = ["日", "一", "二", "三", "四", "五", "六"];

export default function ChildTimetablePage() {
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const now = new Date();
  const [year, setYear] = useState(now.getFullYear());
  const [month, setMonth] = useState(now.getMonth() + 1);
  const [calendar, setCalendar] = useState<ChildCalendar | null>(null);
  const [selectedDate, setSelectedDate] = useState("");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!isLoggedIn) {
      Taro.reLaunch({ url: "/pages/login/index" });
      return;
    }
    const today = `${year}-${String(month).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
    setSelectedDate(today);
    loadMonth();
  }, [isLoggedIn, year, month]);

  const loadMonth = async () => {
    setLoading(true);
    try {
      const data = await getChildCalendar({ month: `${year}-${String(month).padStart(2, "0")}` });
      setCalendar(data);
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const prevMonth = () => {
    if (month === 1) {
      setYear(year - 1);
      setMonth(12);
    } else {
      setMonth(month - 1);
    }
    resetSelected(year, month === 1 ? 12 : month - 1);
  };

  const nextMonth = () => {
    if (month === 12) {
      setYear(year + 1);
      setMonth(1);
    } else {
      setMonth(month + 1);
    }
    resetSelected(year, month === 12 ? 1 : month + 1);
  };

  // 切月后选中日期重置为当月今天（若不在当月则取 1 号）
  const resetSelected = (y: number, m: number) => {
    const today = new Date();
    const day = today.getFullYear() === y && today.getMonth() + 1 === m ? today.getDate() : 1;
    setSelectedDate(`${y}-${String(m).padStart(2, "0")}-${String(day).padStart(2, "0")}`);
  };

  // 日历格子：当月天数 + 首日偏移
  const cells = useMemo(() => {
    const firstDay = new Date(year, month - 1, 1).getDay();
    const daysInMonth = new Date(year, month, 0).getDate();
    const list: Array<{ day: number; date: string; inMonth: boolean }> = [];
    for (let i = 0; i < firstDay; i++) {
      list.push({ day: 0, date: "", inMonth: false });
    }
    for (let d = 1; d <= daysInMonth; d++) {
      list.push({
        day: d,
        date: `${year}-${String(month).padStart(2, "0")}-${String(d).padStart(2, "0")}`,
        inMonth: true
      });
    }
    return list;
  }, [year, month]);

  // 日期 → 事件映射
  const eventsByDate = useMemo(() => {
    const map: Record<string, CalendarEvent[]> = {};
    (calendar?.list || []).forEach((entry) => {
      map[entry.date] = entry.events || [];
    });
    return map;
  }, [calendar]);

  const selectedEvents = eventsByDate[selectedDate] || [];
  const todayStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;

  return (
    <View className="timetable-page">
      <View className="month-bar">
        <View className="month-arrow" onClick={prevMonth}>‹</View>
        <View className="month-title">{year} 年 {month} 月</View>
        <View className="month-arrow" onClick={nextMonth}>›</View>
      </View>

      <View className="card calendar-card">
        <View className="week-row">
          {WEEK_LABELS.map((w) => (
            <Text key={w} className="week-cell">{w}</Text>
          ))}
        </View>
        <View className="day-grid">
          {cells.map((cell, idx) => {
            if (!cell.inMonth) {
              return <View key={`empty-${idx}`} className="day-cell" />;
            }
            const hasEvent = (eventsByDate[cell.date] || []).length > 0;
            const isToday = cell.date === todayStr;
            const isSelected = cell.date === selectedDate;
            return (
              <View
                key={cell.date}
                className={`day-cell ${isToday ? "day-today" : ""} ${isSelected ? "day-selected" : ""}`}
                onClick={() => setSelectedDate(cell.date)}
              >
                <Text className="day-num">{cell.day}</Text>
                {hasEvent && <View className="day-dot" />}
              </View>
            );
          })}
        </View>
      </View>

      <View className="day-title">
        {selectedDate} · {selectedEvents.length > 0 ? `${selectedEvents.length} 节课` : "无课"}
      </View>

      <View className="card">
        {loading ? (
          <View className="empty-tip">加载中...</View>
        ) : selectedEvents.length === 0 ? (
          <View className="empty-tip">这一天没有课程安排</View>
        ) : (
          selectedEvents.map((ev) => (
            <View key={ev.schedule_id} className="event-row">
              <View className="event-time">
                <Text className="event-start">{String(ev.start_time || "").slice(0, 5)}</Text>
                <Text className="event-end">{String(ev.end_time || "").slice(0, 5)}</Text>
              </View>
              <View className="event-info">
                <View className="event-title">
                  {ev.course_title}
                  {ev.is_makeup && <Text className="event-makeup">补课</Text>}
                </View>
                <View className="event-meta">
                  {ev.class_name !== "-" && <Text>{ev.class_name}</Text>}
                  <Text>{ev.teacher_name}</Text>
                  <Text>{ev.studio_name}</Text>
                </View>
                {ev.location && <View className="event-loc">📍 {ev.location}</View>}
                {ev.children && ev.children.length > 0 && (
                  <View className="event-children">学员：{ev.children.map((c) => c.nickname).join("、")}</View>
                )}
              </View>
            </View>
          ))
        )}
      </View>
    </View>
  );
}
