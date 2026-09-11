import React, { useEffect, useState } from "react";
import Taro, { useRouter } from "@tarojs/taro";
import { View, Text, Button, RadioGroup, Radio } from "@tarojs/components";
import { getCourseDetail, fenToYuan } from "../../services/course";
import { listChildren, type ChildItem } from "../../services/child";
import { createOrder } from "../../services/order";
import "./index.scss";

export default function OrderConfirmPage() {
  const router = useRouter();
  const courseId = router.params.course_id || "";
  const packageId = router.params.package_id || "";
  const [course, setCourse] = useState<any>(null);
  const [pkg, setPkg] = useState<any>(null);
  const [children, setChildren] = useState<ChildItem[]>([]);
  const [selectedChild, setSelectedChild] = useState("");
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    if (courseId) loadData();
  }, [courseId]);

  const loadData = async () => {
    try {
      const [courseData, childData] = await Promise.all([getCourseDetail(courseId), listChildren()]);
      setCourse(courseData);
      const available = (courseData.packages || []).filter((p: any) => Number(p.status) === 1);
      setPkg(available.find((p: any) => p.package_id === packageId) || available[0]);
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

  const submit = async () => {
    if (!selectedChild) {
      Taro.showToast({ title: "请选择上课学员", icon: "none" });
      return;
    }
    if (!pkg) return;
    setSubmitting(true);
    try {
      const order = await createOrder({
        child_id: selectedChild,
        course_id: courseId,
        package_id: pkg.package_id
      });
      Taro.redirectTo({ url: `/pages/order-pay/index?order_id=${order.order_id}` });
    } catch {
      // 拦截器已提示
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <View className="confirm">
      <View className="card">
        <View className="section-label">确认课程</View>
        <View className="confirm-course">
          <View className="confirm-title">{course?.title || "加载中..."}</View>
          {pkg && (
            <View className="confirm-pkg">
              <Text>{pkg.name}（{pkg.lessons} 课时）</Text>
              <Text className="confirm-price">¥{fenToYuan(pkg.price)}</Text>
            </View>
          )}
        </View>
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
          <Text className="amount-value">¥{pkg ? fenToYuan(pkg.price) : "0.00"}</Text>
        </View>
      </View>

      <View className="submit-bar">
        <Button className="btn-primary submit-btn" loading={submitting} disabled={!pkg} onClick={submit}>
          提交订单
        </Button>
      </View>
    </View>
  );
}
