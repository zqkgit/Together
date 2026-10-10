import React, { useState } from "react";
import Taro from "@tarojs/taro";
import { View, Text } from "@tarojs/components";
import { setPayPassword } from "../../../services/auth";
import "./form-page.scss";

const PIN_LENGTH = 6;

export default function SetPayPasswordPage() {
  const [step, setStep] = useState<1 | 2>(1); // 1=输入, 2=确认
  const [firstPin, setFirstPin] = useState("");
  const [secondPin, setSecondPin] = useState("");
  const [saving, setSaving] = useState(false);

  const handleDigit = (d: string) => {
    const setter = step === 1 ? setFirstPin : setSecondPin;
    const current = step === 1 ? firstPin : secondPin;
    if (current.length >= PIN_LENGTH) return;
    const next = current + d;
    setter(next);
    if (next.length === PIN_LENGTH) {
      if (step === 1) {
        setTimeout(() => setStep(2), 200);
      } else {
        handleConfirm(next);
      }
    }
  };

  const handleDelete = () => {
    const setter = step === 1 ? setFirstPin : setSecondPin;
    const current = step === 1 ? firstPin : secondPin;
    setter(current.slice(0, -1));
  };

  const handleConfirm = async (pin: string) => {
    if (firstPin !== pin) {
      Taro.showToast({ title: "两次输入不一致，请重试", icon: "none" });
      setSecondPin("");
      setStep(1);
      setFirstPin("");
      return;
    }
    setSaving(true);
    try {
      await setPayPassword(firstPin);
      Taro.showToast({ title: "支付密码设置成功", icon: "success" });
      setTimeout(() => Taro.navigateBack(), 800);
    } catch (e: any) {
      Taro.showToast({ title: e?.message || "设置失败", icon: "none" });
      setFirstPin("");
      setSecondPin("");
      setStep(1);
    } finally {
      setSaving(false);
    }
  };

  const currentPin = step === 1 ? firstPin : secondPin;
  const digits = Array.from({ length: PIN_LENGTH }, (_, i) => i < currentPin.length ? "●" : "");

  return (
    <View className="form-page">
      <View className="fp-title">{step === 1 ? "请输入 6 位数字支付密码" : "请再次输入以确认"}</View>
      <View className="fp-pin-row">
        {digits.map((d, i) => (
          <View key={i} className={`fp-pin-cell ${d ? "fp-pin-cell--filled" : ""}`}>
            <Text className="fp-pin-dot">{d}</Text>
          </View>
        ))}
      </View>
      <Text className="fp-hint fp-hint--center">支付密码用于佣金提现等操作时校验</Text>
      <View className="fp-keyboard">
        {["1","2","3","4","5","6","7","8","9","","0","del"].map((k) => {
          if (k === "") return <View key="blank" className="fp-key fp-key--blank" />;
          if (k === "del") return <View key="del" className="fp-key fp-key--del" onClick={handleDelete}><Text className="fp-key-text">⌫</Text></View>;
          return <View key={k} className="fp-key" onClick={() => handleDigit(k)}><Text className="fp-key-text">{k}</Text></View>;
        })}
      </View>
    </View>
  );
}