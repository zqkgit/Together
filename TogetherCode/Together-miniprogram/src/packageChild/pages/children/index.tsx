import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image } from "@tarojs/components";
import { listChildren, type ChildItem } from "../../../services/child";
import "./index.scss";

/** 由生日算年龄（如 "2019-03-08" → "5岁"） */
function getAgeText(birthday: string | null): string {
  if (!birthday || birthday.length < 4) return "";
  const year = parseInt(birthday.slice(0, 4), 10);
  if (isNaN(year)) return "";
  const currentYear = new Date().getFullYear();
  const age = currentYear - year;
  return age >= 0 ? age + "岁" : "";
}

/** 性别文字 */
function getGenderText(gender: number | null): string {
  if (gender === 2) return "女";
  if (gender === 1) return "男";
  return "";
}

export default function ChildrenPage() {
  const [children, setChildren] = useState<ChildItem[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    loadData();
  }, []);

  /** 每次页面显示时刷新（从添加页返回后） */
  Taro.useDidShow(() => {
    loadData();
  });

  const loadData = async () => {
    setLoading(true);
    try {
      const data = await listChildren();
      setChildren(data);
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const goChildHome = (child: ChildItem) => {
    Taro.navigateTo({ url: "/packageChild/pages/child-growth/index?id=" + child.child_id });
  };

  const goAddChild = () => {
    Taro.navigateTo({ url: "/packageChild/pages/child-add/index" });
  };

  /** 课程标签：取 balances 中去重前 3 个 course_title */
  const getCourseTags = (child: ChildItem): string[] => {
    const titles = (child.balances || [])
      .map((b) => b.course_title)
      .filter(Boolean) as string[];
    const unique = [...new Set(titles)];
    return unique.slice(0, 3);
  };

  return (
    <View className="children">
      {/* ====== 孩子卡片列表 ====== */}
      {children.map((child) => {
        const genderText = getGenderText(child.gender);
        const ageText = getAgeText(child.birthday);
        const infoParts = [genderText, ageText].filter(Boolean);
        const courseTags = getCourseTags(child);
        const remaining = child.total_remaining_lessons ?? 0;

        return (
          <View key={child.child_id} className="child-card" onClick={() => goChildHome(child)}>
            <View className="child-avatar">
              {child.avatar && child.avatar.startsWith("http") ? (
                <Image className="child-avatar-img" src={child.avatar} mode="aspectFill" />
              ) : (
                <Text className="child-avatar-text">{child.nickname.slice(0, 1)}</Text>
              )}
            </View>
            <View className="child-content">
              <View className="child-row-top">
                <Text className="child-name">{child.nickname}</Text>
                <View className="child-view-btn" onClick={(e) => {
                  e.stopPropagation();
                  goChildHome(child);
                }}>
                  <Text className="child-view-btn-text">查看</Text>
                </View>
              </View>
              {infoParts.length > 0 && (
                <Text className="child-info">{infoParts.join("·")}</Text>
              )}
              <Text className="child-lessons">剩余课时{remaining}节</Text>
              <View className="child-tags">
                {courseTags.length > 0 ? (
                  courseTags.map((tag, i) => (
                    <View key={i} className="child-tag child-tag--wood">{tag}</View>
                  ))
                ) : (
                  <View className="child-tag child-tag--muted">未报名课程</View>
                )}
              </View>
            </View>
          </View>
        );
      })}

      {children.length === 0 && !loading && (
        <View className="empty-tip">
          <Text className="empty-tip-title">还没有孩子档案</Text>
          <Text className="empty-tip-sub">点击下方「添加孩子」创建</Text>
        </View>
      )}

      {/* 虚线添加按钮（对齐 iOS AddChildDashedButton） */}
      <View className="add-dashed-btn" onClick={goAddChild}>
        <Text className="add-dashed-icon">+</Text>
        <Text className="add-dashed-text">添加孩子</Text>
      </View>
    </View>
  );
}