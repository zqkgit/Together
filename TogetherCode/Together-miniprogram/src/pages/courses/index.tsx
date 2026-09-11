import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image, Input, ScrollView } from "@tarojs/components";
import { request } from "../../services/request";
import "./index.scss";

interface CourseItem {
  course_id: string;
  title: string;
  cover: string | null;
  price_text: string;
  original_price_text: string;
  studio_name: string;
  tags: string[];
}

export default function CoursesPage() {
  const [courses, setCourses] = useState<CourseItem[]>([]);
  const [keyword, setKeyword] = useState("");
  const [tag, setTag] = useState("");
  const [tags, setTags] = useState<string[]>([]);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    loadTags();
    loadData();
  }, []);

  const loadTags = async () => {
    try {
      const data = await request<any>({ url: "/tags", method: "GET" });
      setTags((data?.list || data || []).map((t: any) => t.name));
    } catch {
      // 忽略
    }
  };

  const loadData = async () => {
    setLoading(true);
    try {
      const params: any = { page, page_size: 10 };
      if (keyword.trim()) params.keyword = keyword.trim();
      if (tag) params.tag = tag;
      const query = Object.keys(params)
        .map((k) => `${k}=${encodeURIComponent(params[k])}`)
        .join("&");
      const data = await request<any>({ url: `/courses?${query}`, method: "GET" });
      const list = data?.list || [];
      setCourses((prev) => (page === 1 ? list : [...prev, ...list]));
      setTotal(data?.total || list.length);
    } catch {
      // 拦截器已提示
    } finally {
      setLoading(false);
    }
  };

  const onSearch = () => {
    setPage(1);
    loadData();
  };

  const onSelectTag = (name: string) => {
    setTag(tag === name ? "" : name);
    setPage(1);
    setTimeout(loadData, 0);
  };

  const onReachBottom = () => {
    if (courses.length < total) {
      setPage(page + 1);
    }
  };

  useEffect(() => {
    if (page > 1) loadData();
  }, [page]);

  const goCourse = (id: string) => {
    Taro.navigateTo({ url: `/pages/course-detail/index?id=${id}` });
  };

  return (
    <View className="courses">
      <View className="search-bar">
        <Input
          className="search-input"
          placeholder="搜索课程 / 工作室"
          value={keyword}
          confirmType="search"
          onInput={(e) => setKeyword(e.detail.value)}
          onConfirm={onSearch}
        />
        <Text className="search-btn" onClick={onSearch}>搜索</Text>
      </View>

      <ScrollView className="tag-scroll" scrollX>
        <View className="tag-row">
          {tags.map((t) => (
            <Text
              key={t}
              className={`tag-item ${tag === t ? "tag-active" : ""}`}
              onClick={() => onSelectTag(t)}
            >
              {t}
            </Text>
          ))}
        </View>
      </ScrollView>

      <View className="course-list">
        {courses.map((item) => (
          <View key={item.course_id} className="course-row card" onClick={() => goCourse(item.course_id)}>
            <Image className="row-cover" src={item.cover || ""} mode="aspectFill" />
            <View className="row-body">
              <View className="row-name">{item.title}</View>
              <View className="row-studio">{item.studio_name}</View>
              <View className="row-tags">
                {(item.tags || []).map((t) => (
                  <Text key={t} className="row-tag">#{t}</Text>
                ))}
              </View>
              <View className="row-price">
                <Text className="price-now">{item.price_text}</Text>
                {item.original_price_text && (
                  <Text className="price-original">{item.original_price_text}</Text>
                )}
              </View>
            </View>
          </View>
        ))}
      </View>

      {loading && <View className="empty-tip">加载中...</View>}
      {courses.length === 0 && !loading && <View className="empty-tip">暂无课程</View>}
    </View>
  );
}
