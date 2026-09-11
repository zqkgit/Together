#!/usr/bin/env python3
"""生成艺启小程序 tabBar 图标：4 tab × 2 状态（未选中/选中），81×81 透明底"""
from PIL import Image, ImageDraw

SIZE = 81
OUT = "/Users/shide/Desktop/qzCode/Together/TogetherCode/Together-miniprogram/src/assets/tabbar"

# 品牌色
GREY = (154, 147, 138, 255)   # #9a938a 未选中
GREEN = (47, 93, 69, 255)     # #2f5d45 选中


def draw_home(d, color):
    # 房子：屋顶 + 墙体 + 门
    d.polygon([(40, 12), (68, 36), (13, 36)], fill=color)  # 屋顶
    d.rounded_rectangle([(16, 36), (65, 68)], radius=4, fill=color)  # 墙体
    d.rounded_rectangle([(34, 48), (47, 68)], radius=3, fill=(247, 244, 236, 255))  # 门


def draw_courses(d, color):
    # 课程：翻开的书本
    d.polygon([(14, 22), (40, 18), (40, 62), (14, 66)], fill=color)
    d.polygon([(67, 22), (41, 18), (41, 62), (67, 66)], fill=color)
    d.line([(40, 18), (40, 62)], fill=(247, 244, 236, 255), width=3)  # 书脊


def draw_plaza(d, color):
    # 广场：对话气泡
    d.rounded_rectangle([(12, 16), (69, 52)], radius=10, fill=color)
    d.polygon([(24, 52), (24, 66), (40, 52)], fill=color)  # 气泡尾巴
    d.ellipse([(28, 28), (36, 36)], fill=(247, 244, 236, 255))
    d.ellipse([(45, 28), (53, 36)], fill=(247, 244, 236, 255))


def draw_mine(d, color):
    # 我的：人形
    d.ellipse([(28, 14), (53, 39)], fill=color)  # 头
    d.pieslice([(14, 40), (67, 90)], 180, 360, fill=color)  # 肩


ICONS = {
    "home": draw_home,
    "courses": draw_courses,
    "plaza": draw_plaza,
    "mine": draw_mine,
}

for name, fn in ICONS.items():
    for suffix, color in (("", GREY), ("-active", GREEN)):
        img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        fn(d, color)
        path = f"{OUT}/{name}{suffix}.png"
        img.save(path)
        print("saved", path)
