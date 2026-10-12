import { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Input, ScrollView, Image } from "@tarojs/components";
import { request } from "../../../services/request";
import { getPublicStudios, getPublicTeachers, type StudioItem, type TeacherItem } from "../../../services/explore";
import "./index.scss";

type SearchTab = "courses" | "studios" | "teachers";

interface CourseItem {
  course_id: string;
  title: string;
  cover: string | null;
  price_text: string;
  original_price_text: string;
  studio_name: string;
  tags: string[];
}

const TAB_LABELS: Record<SearchTab, string> = {
  courses: "课程",
  studios: "工作室",
  teachers: "老师",
};

export default function SearchPage() {
  const [keyword, setKeyword] = useState("");
  const [tab, setTab] = useState<SearchTab>("courses");
  const [hotKeywords, setHotKeywords] = useState<string[]>([]);
  const [history, setHistory] = useState<string[]>([]);
  const [searched, setSearched] = useState(false);

  // 结果
  const [courses, setCourses] = useState<CourseItem[]>([]);
  const [studios, setStudios] = useState<StudioItem[]>([]);
  const [teachers, setTeachers] = useState<TeacherItem[]>([]);
  const [loading, setLoading] = useState(false);
  const [page, setPage] = useState(1);
  const [finished, setFinished] = useState(false);

  useEffect(() => {
    loadHotKeywords();
    loadHistory();
  }, []);

  const loadHotKeywords = async () => {
    try {
      const data = await request<any>({ url: "/search/hot-keywords", method: "GET" });
      setHotKeywords(data?.list || []);
    } catch {
      // 忽略
    }
  };

  const loadHistory = () => {
    try {
      const saved = Taro.getStorageSync("global_search_history") || [];
      setHistory(Array.isArray(saved) ? saved.slice(0, 10) : []);
    } catch {
      // 忽略
    }
  };

  const saveHistory = (kw: string) => {
    const clean = kw.trim();
    if (!clean) return;
    const next = [clean, ...history.filter((h) => h !== clean)].slice(0, 10);
    setHistory(next);
    try {
      Taro.setStorageSync("global_search_history", next);
    } catch {
      // 忽略
    }
  };

  const clearHistory = () => {
    setHistory([]);
    try {
      Taro.removeStorageSync("global_search_history");
    } catch {
      // 忽略
    }
  };

  const doSearch = (kw: string) => {
    const clean = kw.trim();
    if (!clean) return;
    setKeyword(clean);
    setSearched(true);
    saveHistory(clean);
    setPage(1);
    setFinished(false);
    setCourses([]);
    setStudios([]);
    setTeachers([]);
    loadResults(clean, tab, 1);
  };

  const loadResults = async (kw: string, t: SearchTab, p: number) => {
    setLoading(true);
    try {
      if (t === "courses") {
        const params = `page=${p}&page_size=10&keyword=${encodeURIComponent(kw)}`;
        const data = await request<any>({ url: `/courses?${params}`, method: "GET" });
        const list = data?.list || [];
        setCourses((prev) => (p === 1 ? list : [...prev, ...list]));
        setFinished(p * 10 >= (data?.total || 0));
      } else if (t === "studios") {
        const res = await getPublicStudios({ page: p, page_size: 10, keyword: kw });
        setStudios((prev) => (p === 1 ? res.list : [...prev, ...res.list]));
        setFinished(p * 10 >= res.total);
      } else {
        const res = await getPublicTeachers({ page: p, page_size: 10, keyword: kw });
        setTeachers((prev) => (p === 1 ? res.list : [...prev, ...res.list]));
        setFinished(p * 10 >= res.total);
      }
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const switchTab = (t: SearchTab) => {
    setTab(t);
    if (searched && keyword.trim()) {
      setPage(1);
      setFinished(false);
      setCourses([]);
      setStudios([]);
      setTeachers([]);
      loadResults(keyword, t, 1);
    }
  };

  const onSearch = () => {
    doSearch(keyword);
  };

  const loadMore = () => {
    if (loading || finished || !searched) return;
    const next = page + 1;
    setPage(next);
    loadResults(keyword, tab, next);
  };

  const goCourse = (id: string) => {
    Taro.navigateTo({ url: `/packageCourses/pages/course-detail/index?id=${id}` });
  };

  const goStudio = (id: string) => {
    Taro.navigateTo({ url: `/packageSocial/pages/studio-homepage/index?id=${id}` });
  };

  const goTeacher = (id: string) => {
    Taro.navigateTo({ url: `/packageSocial/pages/teacher-homepage/index?id=${id}` });
  };

  const showPanel = !searched;

  return (
    <View className="search-page">
      {/* 搜索栏 */}
      <View className="search-header">
        <View className="search-bar">
          <Text className="search-icon">🔍</Text>
          <Input
            className="search-input"
            placeholder="搜索课程、工作室、老师"
            placeholderClass="search-placeholder"
            value={keyword}
            focus
            onInput={(e) => setKeyword(e.detail.value)}
          />
          {keyword && (
            <Text className="search-clear" onClick={() => { setKeyword(""); setSearched(false); }}>✕</Text>
          )}
        </View>
        <View className="search-btn" onClick={onSearch}><Text>搜索</Text></View>
      </View>

      {/* Tab 切换 */}
      <View className="tab-bar">
        {(Object.keys(TAB_LABELS) as SearchTab[]).map((t) => (
          <View
            key={t}
            className={`tab-item ${tab === t ? "active" : ""}`}
            onClick={() => switchTab(t)}
          >
            {TAB_LABELS[t]}
          </View>
        ))}
      </View>

      {/* 搜索前：热词 + 历史 */}
      {showPanel && (
        <ScrollView className="search-panel" scrollY>
          {hotKeywords.length > 0 && (
            <View className="panel-block card">
              <View className="panel-title">🔥 搜索热词</View>
              <View className="kw-wrap">
                {hotKeywords.map((kw) => (
                  <Text key={kw} className="kw-pill kw-hot" onClick={() => doSearch(kw)}>
                    {kw}
                  </Text>
                ))}
              </View>
            </View>
          )}
          {history.length > 0 && (
            <View className="panel-block card">
              <View className="panel-title-row">
                <Text className="panel-title">搜索历史</Text>
                <Text className="clear-btn" onClick={clearHistory}>清空</Text>
              </View>
              <View className="kw-wrap">
                {history.map((kw) => (
                  <Text key={kw} className="kw-pill" onClick={() => doSearch(kw)}>
                    {kw}
                  </Text>
                ))}
              </View>
            </View>
          )}
        </ScrollView>
      )}

      {/* 搜索结果 */}
      {searched && (
        <ScrollView
          className="result-scroll"
          scrollY
          onScrollToLower={loadMore}
        >
          {tab === "courses" && (
            <View className="result-list">
              {courses.length === 0 && !loading && (
                <View className="empty-tip">暂无相关课程</View>
              )}
              {courses.map((c) => (
                <View key={c.course_id} className="course-row card" onClick={() => goCourse(c.course_id)}>
                  <Image className="row-cover" src={c.cover || ""} mode="aspectFill" />
                  <View className="row-body">
                    <Text className="row-name">{c.title}</Text>
                    <Text className="row-studio">{c.studio_name}</Text>
                    <View className="row-tags">
                      {c.tags?.map((t) => <Text key={t} className="row-tag">{t}</Text>)}
                    </View>
                    <View className="row-price">
                      <Text className="price-now">{c.price_text}</Text>
                      {c.original_price_text && c.original_price_text !== c.price_text && (
                        <Text className="price-original">{c.original_price_text}</Text>
                      )}
                    </View>
                  </View>
                </View>
              ))}
            </View>
          )}

          {tab === "studios" && (
            <View className="result-list">
              {studios.length === 0 && !loading && (
                <View className="empty-tip">暂无相关工作室</View>
              )}
              {studios.map((s) => (
                <View key={s.studio_id} className="studio-row card" onClick={() => goStudio(s.studio_id)}>
                  <Image className="row-cover" src={s.cover || ""} mode="aspectFill" />
                  <View className="row-body">
                    <Text className="row-name">{s.name}</Text>
                    <View className="row-tags">
                      {s.type_tags?.map((t) => <Text key={t} className="row-tag">{t}</Text>)}
                    </View>
                    <Text className="row-address">{s.address || ""}</Text>
                  </View>
                </View>
              ))}
            </View>
          )}

          {tab === "teachers" && (
            <View className="result-list">
              {teachers.length === 0 && !loading && (
                <View className="empty-tip">暂无相关老师</View>
              )}
              {teachers.map((t) => (
                <View key={t.teacher_id} className="teacher-row card" onClick={() => goTeacher(t.teacher_id)}>
                  <Image className="teacher-avatar" src={t.avatar || ""} mode="aspectFill" />
                  <View className="row-body">
                    <Text className="row-name">{t.nickname}</Text>
                    <Text className="row-studio">{t.studios?.[0]?.name || ""}</Text>
                  </View>
                </View>
              ))}
            </View>
          )}

          {loading && <View className="loading-tip">加载中...</View>}
          {finished && <View className="loading-tip">没有更多了</View>}
        </ScrollView>
      )}
    </View>
  );
}