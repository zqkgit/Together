import React, { useEffect, useState } from "react";
import Taro, { useRouter } from "@tarojs/taro";
import { View, Text, Image, Input } from "@tarojs/components";
import { getPublicStudios, getPublicTeachers, type StudioItem, type TeacherItem } from "../../services/explore";
import "./index.scss";

type Tab = "studios" | "teachers";

export default function StudiosPage() {
  const router = useRouter();
  const [tab, setTab] = useState<Tab>((router.params.tab as Tab) || "studios");
  const [keyword, setKeyword] = useState("");
  const [page, setPage] = useState(1);
  const [studios, setStudios] = useState<StudioItem[]>([]);
  const [teachers, setTeachers] = useState<TeacherItem[]>([]);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(true);
  const [finished, setFinished] = useState(false);

  useEffect(() => {
    setPage(1);
    setStudios([]);
    setTeachers([]);
    setFinished(false);
    load(1);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [tab]);

  const load = async (p: number) => {
    setLoading(true);
    try {
      if (tab === "studios") {
        const res = await getPublicStudios({ page: p, page_size: 10, keyword: keyword || undefined });
        setStudios((prev) => (p === 1 ? res.list : [...prev, ...res.list]));
        setTotal(res.total);
        setFinished(p * 10 >= res.total);
      } else {
        const res = await getPublicTeachers({ page: p, page_size: 10, keyword: keyword || undefined });
        setTeachers((prev) => (p === 1 ? res.list : [...prev, ...res.list]));
        setTotal(res.total);
        setFinished(p * 10 >= res.total);
      }
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const onSearch = () => {
    setPage(1);
    setStudios([]);
    setTeachers([]);
    load(1);
  };

  const loadMore = () => {
    if (loading || finished) return;
    const next = page + 1;
    setPage(next);
    load(next);
  };

  const onReachBottom = () => loadMore();

  return (
    <View className="studios-page">
      <View className="tab-bar">
        <View className={`tab-item ${tab === "studios" ? "active" : ""}`} onClick={() => setTab("studios")}>
          找画室
        </View>
        <View className={`tab-item ${tab === "teachers" ? "active" : ""}`} onClick={() => setTab("teachers")}>
          找老师
        </View>
      </View>

      <View className="search-row">
        <Input
          className="search-input"
          placeholder={tab === "studios" ? "搜索画室名称 / 地址" : "搜索老师姓名"}
          value={keyword}
          onInput={(e) => setKeyword(e.detail.value)}
          onConfirm={onSearch}
          confirmType="search"
        />
        <View className="search-btn" onClick={onSearch}>搜索</View>
      </View>

      {tab === "studios" ? (
        <View className="list">
          {studios.map((s) => (
            <View
              key={s.studio_id}
              className="item"
              onClick={() => Taro.navigateTo({ url: `/pages/studio-homepage/index?id=${s.studio_id}` })}
            >
              <Image className="item-cover" src={s.cover || ""} mode="aspectFill" />
              <View className="item-body">
                <View className="item-name">{s.name}</View>
                <View className="item-tags">
                  {s.type_tags && s.type_tags.length > 0
                    ? s.type_tags.slice(0, 3).map((t, i) => (
                        <Text key={i} className="tag-pill">{t}</Text>
                      ))
                    : null}
                </View>
                <View className="item-meta">⭐ {s.rating || "—"} · {s.course_count} 门课 · {s.teacher_count} 位老师</View>
                {s.address && <View className="item-loc">📍 {s.address}</View>}
              </View>
            </View>
          ))}
          {studios.length === 0 && !loading && <View className="empty-tip">没有找到画室</View>}
          {loading && <View className="empty-tip">加载中...</View>}
          {!loading && studios.length > 0 && finished && <View className="empty-tip">没有更多了</View>}
        </View>
      ) : (
        <View className="list">
          {teachers.map((t) => (
            <View
              key={t.teacher_id}
              className="item"
              onClick={() => Taro.navigateTo({ url: `/pages/teacher-homepage/index?id=${t.user_id}` })}
            >
              <Image className="item-avatar" src={t.avatar || ""} mode="aspectFill" />
              <View className="item-body">
                <View className="item-name">{t.nickname}</View>
                <View className="item-tags">
                  {(t.subjects || []).slice(0, 3).map((s, i) => (
                    <Text key={i} className="tag-pill">{s}</Text>
                  ))}
                </View>
                <View className="item-meta">⭐ {t.rating || "—"} · 教龄 {t.years || 0} 年 · {(t.studios || []).map((st) => st.name).filter(Boolean).join("、") || "待入驻"}</View>
                {t.intro && <View className="item-intro">{t.intro}</View>}
              </View>
            </View>
          ))}
          {teachers.length === 0 && !loading && <View className="empty-tip">没有找到老师</View>}
          {loading && <View className="empty-tip">加载中...</View>}
          {!loading && teachers.length > 0 && finished && <View className="empty-tip">没有更多了</View>}
        </View>
      )}
    </View>
  );
}
