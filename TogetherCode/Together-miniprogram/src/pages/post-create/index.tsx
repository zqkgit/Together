import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image, Textarea, Input } from "@tarojs/components";
import { createPost } from "../../services/post";
import { listCourses, type CourseItem } from "../../services/course";
import { listChildren, type ChildItem } from "../../services/child";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

const BASE_URL = "http://127.0.0.1:3001/v1";

export default function PostCreatePage() {
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);
  const [content, setContent] = useState("");
  const [images, setImages] = useState<string[]>([]);
  const [mode, setMode] = useState<"share" | "course">("share");
  const [courses, setCourses] = useState<CourseItem[]>([]);
  const [children, setChildren] = useState<ChildItem[]>([]);
  const [coursePicker, setCoursePicker] = useState(false);
  const [selectedCourse, setSelectedCourse] = useState<CourseItem | null>(null);
  const [selectedChild, setSelectedChild] = useState("");
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (!isLoggedIn) {
      Taro.reLaunch({ url: "/pages/login/index" });
      return;
    }
    listChildren().then(setChildren).catch(() => undefined);
  }, [isLoggedIn]);

  const loadCourses = async () => {
    try {
      const data = await listCourses({ page: 1, page_size: 50 });
      setCourses(data.list);
      setCoursePicker(true);
    } catch {
      // 拦截器已提示
    }
  };

  const chooseImage = async () => {
    if (images.length >= 9) {
      Taro.showToast({ title: "最多 9 张图片", icon: "none" });
      return;
    }
    try {
      const res = await Taro.chooseImage({ count: 9 - images.length, sizeType: ["compressed"] });
      const files = res.tempFilePaths || [];
      const urls: string[] = [];
      for (const file of files) {
        const url = await uploadImage(file);
        if (url) urls.push(url);
      }
      setImages((prev) => [...prev, ...urls].slice(0, 9));
    } catch {
      // 用户取消或失败
    }
  };

  const uploadImage = (filePath: string): Promise<string | null> => {
    return new Promise((resolve) => {
      const token = Taro.getStorageSync("together_wx_access_token");
      Taro.uploadFile({
        url: `${BASE_URL}/upload`,
        filePath,
        name: "files",
        formData: { folder: "post" },
        header: { Authorization: `Bearer ${token}` },
        success: (res) => {
          try {
            const body = JSON.parse(res.data);
            if (body.code === 0 && body.data?.urls?.length) {
              resolve(body.data.urls[0]);
              return;
            }
            Taro.showToast({ title: body.message || "上传失败", icon: "none" });
          } catch {
            Taro.showToast({ title: "上传失败", icon: "none" });
          }
          resolve(null);
        },
        fail: () => {
          Taro.showToast({ title: "上传失败", icon: "none" });
          resolve(null);
        }
      });
    });
  };

  const removeImage = (idx: number) => {
    setImages((prev) => prev.filter((_, i) => i !== idx));
  };

  const submit = async () => {
    if (!content.trim() && images.length === 0) {
      Taro.showToast({ title: "写点内容或加张图片吧", icon: "none" });
      return;
    }
    if (mode === "course" && !selectedCourse) {
      Taro.showToast({ title: "请选择要推荐的课程", icon: "none" });
      return;
    }
    setSubmitting(true);
    try {
      const payload: any = {
        content: content.trim(),
        images,
        type: mode === "course" ? 1 : 2
      };
      if (mode === "course") {
        payload.course_id = selectedCourse!.course_id;
        if (selectedChild) payload.child_id = selectedChild;
      }
      await createPost(payload);
      Taro.showToast({ title: "发布成功", icon: "success" });
      setTimeout(() => Taro.navigateBack(), 800);
    } catch {
      // 拦截器已提示
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <View className="post-create">
      <View className="mode-switch">
        <View className={`mode-item ${mode === "share" ? "active" : ""}`} onClick={() => setMode("share")}>纯分享</View>
        <View className={`mode-item ${mode === "course" ? "active" : ""}`} onClick={() => setMode("course")}>推荐课程</View>
      </View>

      <View className="card editor">
        <Textarea
          className="content-input"
          placeholder="分享孩子/工作室的美好瞬间…"
          value={content}
          onInput={(e) => setContent(e.detail.value)}
          maxlength={2000}
        />
        <View className="image-grid">
          {images.map((img, i) => (
            <View key={i} className="img-wrap">
              <Image className="img-item" src={img} mode="aspectFill" />
              <View className="img-del" onClick={() => removeImage(i)}>×</View>
            </View>
          ))}
          {images.length < 9 && (
            <View className="img-add" onClick={chooseImage}>+</View>
          )}
        </View>
        <View className="img-hint">{images.length}/9</View>
      </View>

      {mode === "course" && (
        <View className="card course-picker">
          <View className="picker-row" onClick={loadCourses}>
            <Text className="picker-label">推荐课程</Text>
            <Text className={`picker-value ${selectedCourse ? "" : "placeholder"}`}>
              {selectedCourse ? selectedCourse.title : "点击选择课程"}
            </Text>
            <Text className="picker-arrow">›</Text>
          </View>
          {selectedCourse && (
            <View className="picker-row" onClick={() => setCoursePicker(true)}>
              <Text className="picker-label">关联孩子</Text>
              <Text className={`picker-value ${selectedChild ? "" : "placeholder"}`}>
                {selectedChild ? children.find((c) => c.child_id === selectedChild)?.nickname || "已选孩子" : "选填，指定孩子后展示报名"}
              </Text>
              <Text className="picker-arrow">›</Text>
            </View>
          )}
        </View>
      )}

      <View className="submit-wrap">
        <View className={`btn-primary submit-btn ${submitting ? "disabled" : ""}`} onClick={submit}>
          {submitting ? "发布中..." : "发布"}
        </View>
      </View>

      {coursePicker && (
        <View className="mask" onClick={() => setCoursePicker(false)}>
          <View className="picker-panel" onClick={(e) => e.stopPropagation()}>
            <View className="panel-title">选择课程</View>
            <View className="panel-list">
              {courses.map((c) => (
                <View
                  key={c.course_id}
                  className={`panel-item ${selectedCourse?.course_id === c.course_id ? "active" : ""}`}
                  onClick={() => {
                    setSelectedCourse(c);
                    setSelectedChild("");
                    setCoursePicker(false);
                  }}
                >
                  <Image className="panel-cover" src={c.cover || ""} mode="aspectFill" />
                  <View className="panel-body">
                    <View className="panel-name">{c.title}</View>
                    <View className="panel-sub">{c.studio?.name || ""}</View>
                  </View>
                </View>
              ))}
              {courses.length === 0 && <View className="empty-tip">暂无课程</View>}
            </View>
          </View>
        </View>
      )}

      {selectedCourse && (
        <View className="mask" onClick={() => setSelectedChild("")}>
          <View className="picker-panel" onClick={(e) => e.stopPropagation()}>
            <View className="panel-title">选择孩子</View>
            <View className="panel-list">
              {children.map((c) => (
                <View
                  key={c.child_id}
                  className={`panel-item ${selectedChild === c.child_id ? "active" : ""}`}
                  onClick={() => {
                    setSelectedChild(c.child_id);
                    setCoursePicker(false);
                  }}
                >
                  <View className="panel-body">
                    <View className="panel-name">{c.nickname}</View>
                  </View>
                </View>
              ))}
              {children.length === 0 && <View className="empty-tip">还没有孩子，可先跳过</View>}
            </View>
          </View>
        </View>
      )}
    </View>
  );
}
