/**
 * 线下付款凭证页（对齐 iOS PaymentVoucherViewController）
 * 平台不经手学费：家长与机构线下结算后，选择付款方式、上传付款凭证、填写备注，
 * 机构在后台核对到账并「确认收款」后发放全部课时。
 * 现金可免凭证；微信/支付宝/银行/扫码/其他等线上转账必须上传至少 1 张凭证截图。
 */
import React, { useState } from "react";
import Taro, { useRouter } from "@tarojs/taro";
import { View, Text, Input, Image } from "@tarojs/components";
import { submitPaymentVoucher, getOrderDetail, fenToYuan, type OrderItem } from "../../../services/order";
import { uploadImages } from "../../../services/upload";
import { APP_CONFIG } from "../../../config";
import "./index.scss";

const PAY_METHODS = [
  { value: "cash", label: "现金" },
  { value: "wechat", label: "微信转账" },
  { value: "alipay", label: "支付宝转账" },
  { value: "bank", label: "银行转账" },
  { value: "qrcode", label: "扫码转账" },
  { value: "other", label: "其他" },
];

export default function PaymentVoucherPage() {
  const router = useRouter();
  const orderId = router.params.order_id || "";
  const amount = router.params.amount || "0";

  const [method, setMethod] = useState("wechat");
  const [images, setImages] = useState<string[]>([]);
  const [note, setNote] = useState("");
  const [uploading, setUploading] = useState(false);
  const [submitting, setSubmitting] = useState(false);

  const isCash = method === "cash";
  const canSubmit = isCash || images.length > 0;

  const chooseImage = async () => {
    if (images.length >= 9) {
      Taro.showToast({ title: "最多 9 张图片", icon: "none" });
      return;
    }
    try {
      const res = await Taro.chooseImage({ count: 9 - images.length, sizeType: ["compressed"] });
      const tempFiles = res.tempFilePaths || [];
      setUploading(true);
      const urls = await uploadImages(tempFiles, "voucher");
      setImages((prev) => [...prev, ...urls].slice(0, 9));
    } catch {
      // 用户取消或失败
    } finally {
      setUploading(false);
    }
  };

  const removeImage = (index: number) => {
    setImages((prev) => prev.filter((_, i) => i !== index));
  };

  const previewImage = (url: string) => {
    Taro.previewImage({ current: url, urls });
  };

  const handleSubmit = async () => {
    if (!canSubmit || submitting) return;
    if (!isCash && images.length === 0) {
      Taro.showToast({ title: "请上传付款凭证", icon: "none" });
      return;
    }
    setSubmitting(true);
    try {
      await submitPaymentVoucher(orderId, {
        pay_method: method,
        voucher_images: images,
        note: note.trim() || undefined,
      });
      Taro.showToast({ title: "凭证提交成功", icon: "success" });
      setTimeout(() => {
        Taro.navigateBack();
      }, 1000);
    } catch {
      // 拦截器已提示
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <View className="voucher-page">
      <View className="tip-card card">
        <Text className="tip-text">请线下向机构付款后，在此上传付款凭证。机构确认收款后将发放课时。</Text>
      </View>

      <View className="card">
        <View className="section-label">应付金额</View>
        <Text className="amount-text">¥{fenToYuan(Number(amount))}</Text>
      </View>

      <View className="card">
        <View className="section-label">付款方式</View>
        <View className="method-list">
          {PAY_METHODS.map((m) => (
            <View
              key={m.value}
              className={`method-row ${method === m.value ? "method-row--active" : ""}`}
              onClick={() => setMethod(m.value)}
            >
              <View className={`method-radio ${method === m.value ? "method-radio--checked" : ""}`} />
              <Text className="method-label">{m.label}</Text>
            </View>
          ))}
        </View>
      </View>

      {!isCash && (
        <View className="card">
          <View className="section-label">付款凭证</View>
          <View className="voucher-hint">线上转账请上传付款截图，至少 1 张</View>
          <View className="voucher-grid">
            {images.map((url, i) => (
              <View key={url} className="voucher-img-wrap">
                <Image className="voucher-img" src={url} mode="aspectFill" onClick={() => previewImage(url)} />
                <View className="voucher-remove" onClick={() => removeImage(i)}>×</View>
              </View>
            ))}
            {images.length < 9 && (
              <View className="voucher-add" onClick={chooseImage}>
                <Text className="voucher-add-text">+</Text>
              </View>
            )}
          </View>
        </View>
      )}

      <View className="card">
        <View className="section-label">备注（选填）</View>
        <Input
          className="note-input"
          placeholder="如有需要，可填写备注信息"
          value={note}
          onInput={(e) => setNote(e.detail.value)}
          maxlength={200}
        />
      </View>

      <View className="submit-bar">
        <View
          className={`btn-primary submit-btn ${!canSubmit || submitting ? "btn-disabled" : ""}`}
          onClick={handleSubmit}
        >
          {submitting ? "提交中..." : "提交凭证"}
        </View>
      </View>
    </View>
  );
}