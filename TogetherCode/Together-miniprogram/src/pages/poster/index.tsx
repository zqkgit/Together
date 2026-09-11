import React, { useEffect, useState } from "react";
import Taro, { useRouter } from "@tarojs/taro";
import { View, Text, Canvas, Button } from "@tarojs/components";
import { getCourseDetail, fenToYuan } from "../../services/course";
import { getPostDetail } from "../../services/post";
import { fetchWxacode } from "../../services/poster";
import { useAuthStore } from "../../store/auth";
import "./index.scss";

const W = 750;
const H = 1200;

interface PosterData {
  title: string;
  cover: string;
  price: string;
  nickname: string;
}

export default function PosterPage() {
  const router = useRouter();
  const type = router.params.type || "course"; // course | post
  const id = router.params.id || "";
  const code = router.params.code || "";
  const user = useAuthStore((s) => s.user);
  const [data, setData] = useState<PosterData | null>(null);
  const [qrcodeUrl, setQrcodeUrl] = useState("");
  const [qrcodeAvailable, setQrcodeAvailable] = useState(false);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    if (!id) return;
    loadData();
  }, [id]);

  // 数据就绪后自动绘制（依赖 data / qrcodeUrl 变化触发）
  useEffect(() => {
    if (data) {
      const t = setTimeout(draw, 100);
      return () => clearTimeout(t);
    }
  }, [data, qrcodeUrl]);

  const loadData = async () => {
    try {
      let d: PosterData;
      if (type === "post") {
        const post = await getPostDetail(id);
        const course = post.course;
        const priceNum = Number(course?.price);
        d = {
          title: course?.title || String(post.content || "").slice(0, 30),
          cover: post.images?.[0] || course?.cover || "",
          price: !isNaN(priceNum) && priceNum > 0 ? `¥${fenToYuan(priceNum)}` : "",
          nickname: user?.nickname || post.author?.nickname || "艺启用户"
        };
      } else {
        const course = await getCourseDetail(id);
        const pkg = (course.packages || []).find((p: any) => Number(p.status) === 1) || course.packages?.[0];
        d = {
          title: course.title,
          cover: course.cover || "",
          price: `¥${fenToYuan(pkg?.price ?? course.price)}`,
          nickname: user?.nickname || "艺启用户"
        };
      }
      setData(d);
      await loadQrcode();
    } catch {
      // 拦截器已提示
    }
  };

  const loadQrcode = async () => {
    if (!code) return;
    try {
      const res = await fetchWxacode(code);
      setQrcodeAvailable(Boolean(res.available));
      setQrcodeUrl(res.qrcode_url || "");
    } catch {
      // 忽略
    }
  };

  const loadImage = (url: string): Promise<HTMLImageElement | { path: string } | null> => {
    if (!url) return Promise.resolve(null);
    return new Promise((resolve) => {
      if (process.env.TARO_ENV === "weapp") {
        Taro.getImageInfo({ src: url })
          .then((info) => resolve({ path: info.path }))
          .catch(() => resolve(null));
      } else {
        const img = new Image();
        img.crossOrigin = "anonymous";
        img.onload = () => resolve(img);
        img.onerror = () => resolve(null);
        img.src = url;
      }
    });
  };

  const getCanvasCtx = (): Promise<CanvasRenderingContext2D | null> => {
    return new Promise((resolve) => {
      if (process.env.TARO_ENV === "weapp") {
        Taro.createSelectorQuery()
          .select("#poster")
          .fields({ node: true, size: true })
          .exec((res) => {
            const canvas = res?.[0]?.node as HTMLCanvasElement | undefined;
            if (!canvas) return resolve(null);
            canvas.width = W;
            canvas.height = H;
            const ctx = canvas.getContext("2d") as CanvasRenderingContext2D | null;
            resolve(ctx);
          });
      } else {
        // Taro H5：Canvas 组件可能包裹自定义元素，取内部原生 <canvas>
        const el =
          (document.querySelector("#poster canvas") as HTMLCanvasElement | null) ||
          (document.getElementById("poster") as HTMLCanvasElement | null);
        if (!el) return resolve(null);
        el.width = W;
        el.height = H;
        resolve(el.getContext("2d"));
      }
    });
  };

  const draw = async () => {
    if (!data) return;
    const ctx = await getCanvasCtx();
    if (!ctx) return;

    // 背景
    const bg = ctx.createLinearGradient(0, 0, 0, H);
    bg.addColorStop(0, "#2f5d45");
    bg.addColorStop(0.45, "#3f7458");
    bg.addColorStop(0.46, "#f7f4ec");
    bg.addColorStop(1, "#f7f4ec");
    ctx.fillStyle = bg;
    ctx.fillRect(0, 0, W, H);

    // 品牌区
    ctx.fillStyle = "#ffffff";
    ctx.font = "600 44px sans-serif";
    ctx.textAlign = "left";
    ctx.fillText("艺启 · 儿童艺术教育", 60, 110);
    ctx.font = "28px sans-serif";
    ctx.fillStyle = "rgba(255,255,255,0.85)";
    ctx.fillText(`${data.nickname} 邀请你一起学`, 60, 160);

    // 封面
    const cover = await loadImage(data.cover);
    const coverW = 630;
    const coverH = 400;
    const coverX = (W - coverW) / 2;
    const coverY = 220;
    ctx.fillStyle = "#efe9db";
    roundRect(ctx, coverX, coverY, coverW, coverH, 20);
    ctx.fill();
    if (cover) {
      ctx.save();
      roundRectPath(ctx, coverX, coverY, coverW, coverH, 20);
      ctx.clip();
      ctx.drawImage(cover, coverX, coverY, coverW, coverH);
      ctx.restore();
    } else {
      ctx.fillStyle = "#a8c3b4";
      ctx.font = "600 64px sans-serif";
      ctx.textAlign = "center";
      ctx.fillText((data.title || "艺").slice(0, 1), W / 2, coverY + coverH / 2 + 22);
    }

    // 标题
    ctx.fillStyle = "#2f2b26";
    ctx.font = "600 40px sans-serif";
    ctx.textAlign = "left";
    wrapText(ctx, data.title, 60, coverY + coverH + 70, W - 120, 52, 2);

    // 价格
    if (data.price) {
      ctx.fillStyle = "#c0392b";
      ctx.font = "700 44px sans-serif";
      ctx.fillText(data.price, 60, coverY + coverH + 190);
    }

    // 二维码区
    const qrSize = 200;
    const qrX = W - 60 - qrSize;
    const qrY = H - 260;
    if (qrcodeAvailable && qrcodeUrl) {
      const qr = await loadImage(qrcodeUrl);
      ctx.fillStyle = "#ffffff";
      roundRect(ctx, qrX - 14, qrY - 14, qrSize + 28, qrSize + 28, 16);
      ctx.fill();
      if (qr) {
        ctx.drawImage(qr, qrX, qrY, qrSize, qrSize);
      }
      ctx.fillStyle = "#2f5d45";
      ctx.font = "26px sans-serif";
      ctx.textAlign = "right";
      ctx.fillText("长按识别小程序码", qrX + qrSize, qrY + qrSize + 44);
    } else {
      ctx.fillStyle = "#ffffff";
      roundRect(ctx, qrX - 14, qrY - 14, qrSize + 28, qrSize + 28, 16);
      ctx.fill();
      ctx.fillStyle = "#d8d2c4";
      ctx.strokeStyle = "#d8d2c4";
      ctx.lineWidth = 4;
      ctx.strokeRect(qrX + 20, qrY + 20, qrSize - 40, qrSize - 40);
      ctx.font = "26px sans-serif";
      ctx.textAlign = "center";
      ctx.fillText("小程序码", qrX + qrSize / 2, qrY + qrSize / 2 + 10);
      ctx.fillStyle = "#9a938a";
      ctx.font = "22px sans-serif";
      ctx.fillText("配置微信后生成", qrX + qrSize / 2, qrY + qrSize / 2 + 48);
      ctx.fillStyle = "#2f5d45";
      ctx.textAlign = "right";
      ctx.font = "26px sans-serif";
      ctx.fillText("扫码报名 · 享推荐返利", qrX + qrSize, qrY + qrSize + 44);
    }

    setReady(true);
  };

  const roundRectPath = (ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) => {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.arcTo(x + w, y, x + w, y + h, r);
    ctx.arcTo(x + w, y + h, x, y + h, r);
    ctx.arcTo(x, y + h, x, y, r);
    ctx.arcTo(x, y, x + w, y, r);
    ctx.closePath();
  };

  const roundRect = (ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number) => {
    roundRectPath(ctx, x, y, w, h, r);
  };

  const wrapText = (
    ctx: CanvasRenderingContext2D,
    text: string,
    x: number,
    y: number,
    maxWidth: number,
    lineHeight: number,
    maxLines: number
  ) => {
    const lines: string[] = [];
    let line = "";
    for (const ch of text) {
      if (ctx.measureText(line + ch).width > maxWidth) {
        lines.push(line);
        line = ch;
        if (lines.length >= maxLines - 1) break;
      } else {
        line += ch;
      }
    }
    if (line) lines.push(line);
    lines.slice(0, maxLines).forEach((l, i) => ctx.fillText(l, x, y + i * lineHeight));
  };

  const save = () => {
    if (process.env.TARO_ENV === "weapp") {
      Taro.canvasToTempFilePath({
        canvasId: "poster",
        success: (res) => {
          Taro.saveImageToPhotosAlbum({
            filePath: res.tempFilePath,
            success: () => Taro.showToast({ title: "已保存到相册", icon: "success" }),
            fail: () => Taro.showToast({ title: "保存失败，请授权相册", icon: "none" })
          });
        }
      });
      return;
    }
    const canvas = (document.querySelector("#poster canvas") as HTMLCanvasElement | null) ||
      (document.getElementById("poster") as HTMLCanvasElement | null);
    if (!canvas) return;
    const link = document.createElement("a");
    link.download = "poster.png";
    link.href = canvas.toDataURL("image/png");
    link.click();
  };

  return (
    <View className="poster-page">
      <Canvas canvasId="poster" id="poster" className="poster-canvas" />
      <View className="poster-actions">
        <Button className="btn-primary save-btn" disabled={!ready} onClick={save}>
          保存海报
        </Button>
        <Button className="btn-plain" onClick={() => Taro.navigateBack()}>
          返回
        </Button>
      </View>
      {!code && <View className="poster-tip">分享卡片会自动带上返利码，无需手动操作</View>}
    </View>
  );
}
