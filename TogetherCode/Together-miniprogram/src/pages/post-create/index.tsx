import React, { useEffect, useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text, Image, Textarea, ScrollView } from "@tarojs/components";
import { createPost, fetchTopics } from "../../services/post";
import { listChildren, type ChildItem, type ChildBalance } from "../../services/child";
import { uploadImages } from "../../services/upload";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

/** 默认话题兜底（对齐 iOS） */
const DEFAULT_TOPICS = ["成长记录", "作品秀", "育儿经", "探店"];

export default function PostCreatePage() {
  const isLoggedIn = useAuthStore((s) => s.isLoggedIn);

  // ── 表单状态（对齐 iOS ParentPostCreateViewController） ──
  const [content, setContent] = useState("");
  const [images, setImages] = useState<string[]>([]);   // 已上传的 URL
  const [localImages, setLocalImages] = useState<string[]>([]); // 本地临时路径（预览用）
  const [childList, setChildList] = useState<ChildItem[]>([]);
  const [selectedChildId, setSelectedChildId] = useState<string>("");
  const [selectedCourseIndex, setSelectedCourseIndex] = useState<number | null>(null);
  const [topics, setTopics] = useState<string[]>(DEFAULT_TOPICS);
  const [selectedTopic, setSelectedTopic] = useState("");
  const [visibility, setVisibility] = useState(2); // 2=公开 1=仅好友
  const [submitting, setSubmitting] = useState(false);
  const [uploading, setUploading] = useState(false);

  // ── 关闭（对齐 iOS didTapClose：有内容时弹确认） ──
  const handleClose = async () => {
    if (content.trim() || localImages.length > 0) {
      const res = await Taro.showModal({
        title: "放弃编辑",
        content: "还有未发布的内容，确定退出吗？",
        confirmText: "退出",
        confirmColor: "#e74c3c",
      });
      if (!res.confirm) return;
    }
    Taro.switchTab({ url: "/pages/home/index" });
  };

  // ── 加载数据 ──
  useEffect(() => {
    if (!isLoggedIn) {
      Taro.reLaunch({ url: "/pages/login/index" });
      return;
    }
    loadFormData();
  }, [isLoggedIn]);

  const loadFormData = async () => {
    // 并行加载孩子列表和话题
    const [children] = await Promise.all([
      listChildren().catch(() => [] as ChildItem[]),
      fetchTopics().then((t) => { if (t.length > 0) setTopics(t); }).catch(() => {}),
    ]);
    setChildList(children);
    if (children.length > 0 && !selectedChildId) {
      setSelectedChildId(children[0].child_id);
    }
  };

  // ── 孩子有效课程（对齐 iOS activeBalances：排除已退款/已过期） ──
  const activeBalances: ChildBalance[] = (() => {
    const child = childList.find((c) => c.child_id === selectedChildId);
    if (!child?.balances) return [];
    return child.balances.filter((b) => b.status === 1 || b.status === 2);
  })();

  const selectedCourseTitle = (() => {
    if (activeBalances.length === 0) return null;
    if (selectedCourseIndex !== null && selectedCourseIndex < activeBalances.length) {
      return activeBalances[selectedCourseIndex].course_title;
    }
    return activeBalances[0]?.course_title || null;
  })();

  const selectedCourseId = (() => {
    if (selectedCourseIndex !== null && selectedCourseIndex < activeBalances.length) {
      return activeBalances[selectedCourseIndex].course_id;
    }
    return activeBalances[0]?.course_id || null;
  })();

  // ── 图片操作（对齐 iOS ImageGridCell） ──
  const chooseImage = async () => {
    if (localImages.length >= 9) {
      Taro.showToast({ title: "最多 9 张图片", icon: "none" });
      return;
    }
    try {
      const res = await Taro.chooseImage({
        count: 9 - localImages.length,
        sizeType: ["compressed"],
        sourceType: ["album", "camera"],
      });
      const temps = res.tempFilePaths || [];
      setLocalImages((prev) => [...prev, ...temps].slice(0, 9));
    } catch { /* 用户取消 */ }
  };

  const removeImage = (idx: number) => {
    setLocalImages((prev) => prev.filter((_, i) => i !== idx));
    setImages((prev) => prev.filter((_, i) => i !== idx));
  };

  const previewImage = (index: number) => {
    Taro.previewImage({ urls: localImages, current: localImages[index] });
  };

  // ── 关联课程选择（对齐 iOS presentParentCoursePicker） ──
  const showCoursePicker = () => {
    if (activeBalances.length === 0) {
      Taro.showToast({ title: "该孩子暂无课程", icon: "none" });
      return;
    }
    const items = activeBalances.map((b) => b.course_title).concat(["不关联"]);
    Taro.showActionSheet({ itemList: items }).then((res) => {
      if (res.tapIndex < activeBalances.length) {
        setSelectedCourseIndex(res.tapIndex);
      } else {
        setSelectedCourseIndex(null);
      }
    }).catch(() => {});
  };

  // ── 发布（对齐 iOS ParentPostCreateViewController.publish） ──
  const submit = async () => {
    if (!selectedChildId) {
      Taro.showToast({ title: "请选择关联孩子", icon: "none" });
      return;
    }
    if (localImages.length === 0) {
      Taro.showToast({ title: "请至少上传一张作品图片", icon: "none" });
      return;
    }

    setSubmitting(true);
    setUploading(true);
    try {
      // 先上传未上传的图片
      let allUrls = [...images];
      const newPaths = localImages.filter((p) => !p.startsWith("http"));
      if (newPaths.length > 0) {
        const newUrls = await uploadImages(newPaths, "post");
        allUrls = [...allUrls, ...newUrls];
      }
      setUploading(false);

      const payload: any = {
        content: content.trim(),
        images: allUrls,
        child_id: selectedChildId,
        visibility,
        topic: selectedTopic || undefined,
        // 关联课程 = 孩子作品(type=2)；无课程 = 动态(type=1)
        type: selectedCourseId ? 2 : 1,
      };
      if (selectedCourseId) {
        payload.course_id = selectedCourseId;
      }
      await createPost(payload);
      Taro.showToast({ title: "发布成功", icon: "success" });
      setTimeout(() => Taro.switchTab({ url: "/pages/home/index" }), 800);
    } catch {
      /* 拦截器已提示 */
    } finally {
      setSubmitting(false);
      setUploading(false);
    }
  };

  // ── 渲染 ──
  return (
    <View className="post-create">
      {/* 自定义导航栏（对齐 iOS：标题 + 右上角 × 关闭） */}
      <View className="custom-nav">
        <View className="nav-status" />
        <View className="nav-bar">
          <Text className="nav-title">发布</Text>
          <View className="close-btn" onClick={handleClose}>×</View>
        </View>
      </View>

      {/* Section 0: 正文（对齐 iOS TextCell） */}
      <View className="card">
        <Textarea
          className="content-input"
          placeholder="分享孩子的成长瞬间，老师和其他家长都能看到并点赞。"
          value={content}
          onInput={(e) => setContent(e.detail.value)}
          maxlength={100}
        />
        <Text className="char-count">{content.length}/100</Text>
      </View>

      {/* Section 1: 图片九宫格（对齐 iOS ImageGridCell：横向滚动） */}
      <View className="card">
        <ScrollView className="image-scroll" scrollX>
          <View className="image-row">
            {localImages.map((img, i) => (
              <View key={i} className="img-wrap" onClick={() => previewImage(i)}>
                <Image className="img-item" src={img} mode="aspectFill" />
                <View className="img-del" onClick={(e) => { e.stopPropagation(); removeImage(i); }}>×</View>
              </View>
            ))}
            {localImages.length < 9 && (
              <View className="img-add" onClick={chooseImage}>
                <Text className="add-icon">+</Text>
                <Text className="add-label">添加图片</Text>
              </View>
            )}
          </View>
        </ScrollView>
      </View>

      {/* Section 2: 关联孩子（对齐 iOS TagSelectView 单选） */}
      <View className="card">
        <Text className="section-label">关联孩子</Text>
        <View className="tag-row">
          {childList.map((child) => (
            <View
              key={child.child_id}
              className={`tag-chip ${selectedChildId === child.child_id ? "active" : ""}`}
              onClick={() => {
                setSelectedChildId(child.child_id);
                setSelectedCourseIndex(null);
              }}
            >
              {child.nickname}
            </View>
          ))}
          {childList.length === 0 && (
            <Text className="tag-empty">暂无孩子信息</Text>
          )}
        </View>
      </View>

      {/* Section 3: 关联课程（对齐 iOS PickerCell：仅当孩子有课程时显示） */}
      {activeBalances.length > 0 && (
        <View className="card picker-card" onClick={showCoursePicker}>
          <Text className="picker-title">关联课程</Text>
          <Text className="picker-detail">{selectedCourseTitle || "不关联"}</Text>
          <Text className="picker-chevron">›</Text>
        </View>
      )}

      {/* Section 4: 选择话题（对齐 iOS topicCell：TagSelectView 单选） */}
      <View className="card">
        <Text className="section-label">选择话题</Text>
        <View className="tag-row">
          {topics.map((t) => (
            <View
              key={t}
              className={`tag-chip ${selectedTopic === t ? "active" : ""}`}
              onClick={() => setSelectedTopic(selectedTopic === t ? "" : t)}
            >
              #{t}
            </View>
          ))}
        </View>
      </View>

      {/* Section 5: 谁可以看（对齐 iOS VisibilityCell：公开/仅好友） */}
      <View className="card">
        <Text className="section-label">谁可以看</Text>
        <View className="visibility-row">
          <View
            className={`vis-btn ${visibility === 2 ? "active" : ""}`}
            onClick={() => setVisibility(2)}
          >
            公开
          </View>
          <View
            className={`vis-btn ${visibility === 1 ? "active" : ""}`}
            onClick={() => setVisibility(1)}
          >
            仅好友
          </View>
        </View>
      </View>

      {/* 底部发布栏（对齐 iOS bottomBar：胶囊发布按钮） */}
      <View className="bottom-bar">
        <View
          className={`publish-btn ${submitting ? "disabled" : ""}`}
          onClick={submit}
        >
          {uploading ? "上传图片中..." : submitting ? "发布中..." : "发布"}
        </View>
      </View>
    </View>
  );
}