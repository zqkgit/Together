import React, { useState, useRef, useEffect } from "react";
import Taro, { useRouter } from "@tarojs/taro";
import { View, Text, Input } from "@tarojs/components";
import { sendCode, loginWithCode, register } from "../../services/auth";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

export default function VerifyCodePage() {
  const router = useRouter();
  const phone = router.params.phone || "";
  const purpose = router.params.purpose || "register";
  const setSession = useAuthStore((s) => s.setSession);

  const [codes, setCodes] = useState(["", "", "", ""]);
  const inputRefs = useRef<any[]>([]);
  const [countdown, setCountdown] = useState(60);
  const [submitting, setSubmitting] = useState(false);
  const timerRef = useRef<ReturnType<typeof setInterval> | null>(null);

  useEffect(() => {
    timerRef.current = setInterval(() => {
      setCountdown((prev) => {
        if (prev <= 1) {
          if (timerRef.current) clearInterval(timerRef.current);
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
    return () => {
      if (timerRef.current) clearInterval(timerRef.current);
    };
  }, []);

  const currentCode = codes.join("");

  const handleInput = (index: number, value: string) => {
    // 只允许数字
    const digit = value.replace(/\D/g, "").slice(-1);
    const newCodes = [...codes];
    newCodes[index] = digit;
    setCodes(newCodes);

    // 自动跳下一格
    if (digit && index < 3) {
      inputRefs.current[index + 1]?.focus?.();
    }
    // 4位填满自动收起键盘
    if (newCodes.every((c) => c !== "")) {
      inputRefs.current[index]?.blur?.();
    }
  };

  const handleFocus = (index: number) => {
    // 选中当前格内容方便覆盖
  };

  const handleResend = async () => {
    if (countdown > 0 || !phone) return;
    try {
      await sendCode(phone);
      Taro.showToast({ title: "验证码已重新发送", icon: "success" });
      setCountdown(60);
      timerRef.current = setInterval(() => {
        setCountdown((prev) => {
          if (prev <= 1) {
            if (timerRef.current) clearInterval(timerRef.current);
            return 0;
          }
          return prev - 1;
        });
      }, 1000);
    } catch {
      // 拦截器已提示
    }
  };

  const handleNext = async () => {
    if (currentCode.length < 4 || submitting) return;
    setSubmitting(true);
    try {
      if (purpose === "register") {
        const session = await register(phone, currentCode);
        setSession(session);
        Taro.showToast({ title: "注册成功", icon: "success" });
      } else {
        const session = await loginWithCode(phone, currentCode);
        setSession(session);
        Taro.showToast({ title: "登录成功", icon: "success" });
      }
      setTimeout(() => Taro.switchTab({ url: "/pages/home/index" }), 400);
    } catch {
      // 拦截器已提示
    } finally {
      setSubmitting(false);
    }
  };

  const isFilled = currentCode.length === 4;

  return (
    <View className="verify-code">
      <Text className="vc-title">验证码已发送</Text>
      <Text className="vc-desc">已发送至 +86 {phone}，请查收短信</Text>

      {/* 4格输入框 */}
      <View className="vc-fields">
        {codes.map((c, i) => (
          <Input
            key={i}
            ref={(ref) => { inputRefs.current[i] = ref; }}
            className={`vc-field ${c ? "vc-field-filled" : ""}`}
            type="number"
            maxlength={1}
            value={c}
            onInput={(e) => handleInput(i, e.detail.value)}
            onFocus={() => handleFocus(i)}
            focus={i === 0}
          />
        ))}
      </View>

      {/* 倒计时 / 重发 */}
      <View className="vc-resend-row">
        {countdown > 0 ? (
          <Text className="vc-countdown">{countdown}s后可重新发送 ·</Text>
        ) : null}
        <Text
          className={`vc-resend ${countdown > 0 ? "vc-resend-disabled" : ""}`}
          onClick={handleResend}
        >
          重新发送
        </Text>
      </View>

      {/* 下一步按钮 */}
      <View
        className={`vc-next-btn ${isFilled ? "vc-next-active" : "vc-next-disabled"}`}
        onClick={handleNext}
      >
        <Text className="vc-next-text">下一步</Text>
      </View>
    </View>
  );
}