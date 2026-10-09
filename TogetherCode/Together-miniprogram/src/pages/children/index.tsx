import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Button, Input, Image, Picker } from "@tarojs/components";
import { listChildren, createChild, type ChildItem } from "../../services/child";
import "./index.scss";

/** 由生日算年龄（如 "2019-03-08" → "5岁"） */
function getAgeText(birthday: string | null): string {
  if (!birthday || birthday.length < 4) return "";
  const year = parseInt(birthday.slice(0, 4), 10);
  if (isNaN(year)) return "";
  const currentYear = new Date().getFullYear();
  const age = currentYear - year;
  return age >= 0 ? `${age}岁` : "";
}

/** 性别文字 */
function getGenderText(gender: number | null): string {
  if (gender === 2) return "女";
  if (gender === 1) return "男";
  return "";
}

/** 头像 emoji 选项（对齐 iOS） */
const AVATAR_OPTIONS = ["🌻", "🦊", "🐟", "🍀", "🎀"];

/** 兴趣方向选项（对齐 iOS） */
const INTEREST_OPTIONS = ["水彩", "黏土", "书法", "国画", "儿童画", "素描"];

/** 出生年份范围 */
const currentYear = new Date().getFullYear();
const BIRTH_YEARS = Array.from({ length: currentYear - 2010 + 1 }, (_, i) => currentYear - i);

export default function ChildrenPage() {
  const [children, setChildren] = useState<ChildItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [showForm, setShowForm] = useState(false);

  // 添加孩子表单状态
  const [selectedAvatar, setSelectedAvatar] = useState("🌻");
  const [nickname, setNickname] = useState("");
  const [selectedYear, setSelectedYear] = useState(2019);
  const [selectedGender, setSelectedGender] = useState(2); // 默认女孩
  const [selectedInterests, setSelectedInterests] = useState<Set<string>>(new Set());
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    loadData();
  }, []);

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

  const submit = async () => {
    const name = nickname.trim();
    if (!name) {
      Taro.showToast({ title: "请填写孩子昵称", icon: "none" });
      return;
    }
    if (name.length > 20) {
      Taro.showToast({ title: "昵称最多20个字", icon: "none" });
      return;
    }
    setSubmitting(true);
    try {
      await createChild({
        nickname: name,
        avatar: selectedAvatar,
        birthday: `${selectedYear}-01-01`,
        gender: selectedGender,
        interests: Array.from(selectedInterests)
      });
      Taro.showToast({ title: "添加成功", icon: "success" });
      setShowForm(false);
      resetForm();
      loadData();
    } catch {
      // 拦截器已提示
    } finally {
      setSubmitting(false);
    }
  };

  const resetForm = () => {
    setSelectedAvatar("🌻");
    setNickname("");
    setSelectedYear(2019);
    setSelectedGender(2);
    setSelectedInterests(new Set());
  };

  const goChildHome = (child: ChildItem) => {
    Taro.navigateTo({ url: `/pages/child-growth/index?id=${child.child_id}` });
  };

  /** 课程标签：取 balances 中去重前 3 个 course_title */
  const getCourseTags = (child: ChildItem): string[] => {
    const titles = (child.balances || [])
      .map((b) => b.course_title)
      .filter(Boolean) as string[];
    const unique = [...new Set(titles)];
    return unique.slice(0, 3);
  };

  const toggleInterest = (item: string) => {
    const next = new Set(selectedInterests);
    if (next.has(item)) next.delete(item);
    else next.add(item);
    setSelectedInterests(next);
  };

  const yearIndex = BIRTH_YEARS.indexOf(selectedYear);
  const ageFromYear = currentYear - selectedYear;

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

      {/* ====== 添加孩子表单（对齐 iOS AddChildViewController） ====== */}
      {showForm ? (
        <View className="add-form">
          {/* 头像选择 */}
          <Text className="form-section-title">选一个头像</Text>
          <View className="avatar-row">
            {AVATAR_OPTIONS.map((emoji, i) => (
              <View
                key={i}
                className={"avatar-item" + (selectedAvatar === emoji ? " avatar-item--active" : "")}
                onClick={() => setSelectedAvatar(emoji)}
              >
                <Text className="avatar-emoji">{emoji}</Text>
              </View>
            ))}
          </View>

          {/* 昵称 */}
          <Text className="form-section-title">孩子昵称</Text>
          <View className="form-input-wrap">
            <Input
              className="form-input-field"
              placeholder="如：糖糖"
              value={nickname}
              onInput={(e) => setNickname(e.detail.value)}
            />
          </View>

          {/* 出生年份 */}
          <Text className="form-section-title">出生年份</Text>
          <Picker
            mode="selector"
            range={BIRTH_YEARS.map((y) => String(y) + "年（" + String(currentYear - y) + "岁）")}
            value={yearIndex >= 0 ? yearIndex : 0}
            onChange={(e) => setSelectedYear(BIRTH_YEARS[e.detail.value])}
          >
            <View className="birth-picker">
              <Text className="birth-picker-text">{selectedYear}年（{ageFromYear}岁）</Text>
              <Text className="birth-picker-arrow">▾</Text>
            </View>
          </Picker>

          {/* 性别 */}
          <Text className="form-section-title">性别</Text>
          <View className="gender-row">
            <View
              className={"gender-btn" + (selectedGender === 2 ? " gender-btn--active" : "")}
              onClick={() => setSelectedGender(2)}
            >
              <Text>女孩</Text>
            </View>
            <View
              className={"gender-btn" + (selectedGender === 1 ? " gender-btn--active" : "")}
              onClick={() => setSelectedGender(1)}
            >
              <Text>男孩</Text>
            </View>
          </View>

          {/* 兴趣方向 */}
          <Text className="form-section-title">兴趣方向（可多选）</Text>
          <View className="interest-row">
            {INTEREST_OPTIONS.map((item) => (
              <View
                key={item}
                className={"interest-tag" + (selectedInterests.has(item) ? " interest-tag--active" : "")}
                onClick={() => toggleInterest(item)}
              >
                <Text>{item}</Text>
              </View>
            ))}
          </View>

          {/* 操作按钮 */}
          <View className="form-btns">
            <View className="btn-cancel" onClick={() => { setShowForm(false); resetForm(); }}>
              <Text>取消</Text>
            </View>
            <Button className="btn-primary form-submit" loading={submitting} onClick={submit}>保存</Button>
          </View>
        </View>
      ) : (
        <View className="add-dashed-btn" onClick={() => setShowForm(true)}>
          <Text className="add-dashed-icon">+</Text>
          <Text className="add-dashed-text">添加孩子</Text>
        </View>
      )}
    </View>
  );
}