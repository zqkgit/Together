import React, { useEffect, useState } from "react";
import Taro, { useRouter } from "@tarojs/taro";
import { View, Text, Button, RadioGroup, Radio } from "@tarojs/components";
import { getCourseDetail, fenToYuan } from "../../services/course";
import { listChildren, type ChildItem } from "../../services/child";
import { createOrder } from "../../services/order";
import { getDistFromParams } from "../../utils/share";
import "./index.scss";

export default function OrderConfirmPage() {
  const router = useRouter();
  const courseId = router.params.course_id || "";
  // 分销归因码：由分享链接带过来，下单时提交 → 支付成功后返利给分享人
  const distributionCode = getDistFromParams();
  const [course, setCourse] = useState<any>(null);
  const [classes, setClasses] = useState<any[]>([]);
  const [children, setChildren] = useState<ChildItem[]>([]);
  const [selectedChild, setSelectedChild] = useState("");
  const [selectedClass, setSelectedClass] = useState("");
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (courseId) loadData();
  }, [courseId]);

  const loadData = async () => {
    try {
      const [courseData, childData] = await Promise.all([getCourseDetail(courseId), listChildren()]);
      setCourse(courseData);
      const classList = courseData.classes || [];
      setClasses(classList);
      // 默认选第一个未满员的班级
      const firstAvailable = classList.find((c: any) => Number(c.enrolled) < Number(c.capacity));
      if (firstAvailable) setSelectedClass(firstAvailable.class_id);
      setChildren(childData);
      if (childData.length > 0) setSelectedChild(childData[0].child_id);
    } catch {
      // 拦截器已提示
    }
  };

  const goAddChild = () => {
    Taro.showToast({ title: "请先在“我的孩子”中添加", icon: "none" });
    setTimeout(() => Taro.navigateTo({ url: "/pages/children/index" }), 800);
  };

  const isFull = (item: any) => Number(item.enrolled) >= Number(item.capacity);

  const submit = async () => {
    if (!selectedChild) {
      Taro.showToast({ title: "请选择上课学员", icon: "none" });
      return;
    }
    if (!selectedClass) {
      Taro.showToast({ title: "请选择上课班级", icon: "none" });
      return;
    }
    setSubmitting(true);
    try {
      const order = await createOrder({
        child_id: selectedChild,
        course_id: courseId,
        class_id: selectedClass,
        distribution_code: distributionCode || undefined
      });
      Taro.redirectTo({ url: `/pages/order-pay/index?order_id=${order.order_id}` });
    } catch {
      // 拦截器已提示
    } finally {
      setSubmitting(false);
    }
  };

  const amountText = course ? fenToYuan(course.price) : "0.00";
  const canSubmit = !!selectedChild && !!selectedClass;

  return (
    <View className="confirm">
      <View className="card">
        <View className="section-label">确认课程</View>
        <View className="confirm-course">
          <View className="confirm-title">{course?.title || "加载中..."}</View>
          {course && (
            <View className="confirm-pkg">
              <Text>{course.total_lessons} 课时</Text>
              <Text className="confirm-price">¥{amountText}</Text>
            </View>
          )}
        </View>
      </View>

      <View className="card">
        <View className="section-label">选择上课班级</View>
        {classes.length === 0 ? (
          <View className="empty-child">该课程暂无可报名班级</View>
        ) : (
          <RadioGroup onChange={(e) => setSelectedClass(e.detail.value)}>
            {classes.map((item) => {
              const full = isFull(item);
              const active = selectedClass === item.class_id;
              return (
                <View
                  key={item.class_id}
                  className={`class-row ${active ? "class-row--active" : ""} ${full ? "class-row--full" : ""}`}
                  onClick={() => {
                    if (!full) setSelectedClass(item.class_id);
                  }}
                >
                  <Radio value={item.class_id} checked={active} color="#2f5d45" disabled={full}>
                    <View className="class-main">
                      <Text className="class-name">{item.name || "未命名班级"}</Text>
                      <Text className="class-meta">
                        {[item.teacher_name, item.time, `${item.enrolled}/${item.capacity}`].filter(Boolean).join(" · ")}
                      </Text>
                    </View>
                  </Radio>
                  {full && <Text className="class-full-tag">已满员</Text>}
                </View>
              );
            })}
          </RadioGroup>
        )}
      </View>

      <View className="card">
        <View className="section-label">选择上课学员</View>
        {children.length === 0 ? (
          <View className="empty-child" onClick={goAddChild}>
            还没有学员，去添加
          </View>
        ) : (
          <RadioGroup
            onChange={(e) => setSelectedChild(e.detail.value)}
          >
            {children.map((child) => (
              <View key={child.child_id} className="child-row">
                <Radio value={child.child_id} checked={selectedChild === child.child_id} color="#2f5d45">
                  <Text className="child-name">{child.nickname}</Text>
                </Radio>
              </View>
            ))}
          </RadioGroup>
        )}
      </View>

      <View className="card">
        <View className="section-label">金额</View>
        <View className="amount-row">
          <Text>应付金额</Text>
          <Text className="amount-value">¥{amountText}</Text>
        </View>
      </View>

      <View className="submit-bar">
        <Button className="btn-primary submit-btn" loading={submitting} disabled={!canSubmit} onClick={submit}>
          提交订单
        </Button>
      </View>
    </View>
  );
}
