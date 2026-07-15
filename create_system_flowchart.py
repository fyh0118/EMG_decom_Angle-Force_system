#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
创建"肌电慧控"系统流程图 Visio 文件 —— 简洁线性指向风格
"""

import win32com.client
import pythoncom
import os, time

pythoncom.CoInitialize()

# ============== 启动 Visio ==============
visio = win32com.client.Dispatch("Visio.Application")
visio.Visible = True

doc = visio.Documents.Add("")
page = doc.Pages.Item(1)
page.Name = "系统流程图"

page.PageSheet.Cells("PageWidth").Formula = "297 mm"
page.PageSheet.Cells("PageHeight").Formula = "210 mm"

# ============== 辅助函数 ==============
def make_box(x, y, w, h, text, fill, line_c, text_c="RGB(0,0,0)",
             font_sz="10 pt", bold=False, round_mm=2):
    """创建一个矩形框"""
    x, y, w, h = float(x), float(y), float(w), float(h)
    shp = page.DrawRectangle(x/25.4, y/25.4, (x+w)/25.4, (y+h)/25.4)
    shp.Cells("FillForegnd").Formula = fill
    shp.Cells("FillPattern").Formula = "1"
    shp.Cells("LineColor").Formula = line_c
    shp.Cells("LineWeight").Formula = "1.2 pt"
    shp.Cells("LinePattern").Formula = "1"
    if round_mm > 0:
        shp.Cells("Rounding").Formula = f"{round_mm} mm"
    shp.Text = text
    shp.Cells("Char.Size").Formula = font_sz
    shp.Cells("Char.Color").Formula = text_c
    shp.Cells("Para.HorzAlign").Formula = "1"
    if bold:
        shp.Cells("Char.Style").Formula = "1"
    return shp

def arrow(x1, y1, x2, y2, clr="RGB(80,80,80)", lw="1.5 pt"):
    """画带箭头的连线"""
    ln = page.DrawLine(x1/25.4, y1/25.4, x2/25.4, y2/25.4)
    ln.Cells("LineColor").Formula = clr
    ln.Cells("LineWeight").Formula = lw
    ln.Cells("EndArrow").Formula = "5"
    ln.Cells("EndArrowSize").Formula = "4"
    return ln

# ============== 颜色 ==============
COLORS = [
    ("RGB(230,240,255)", "RGB(40,80,170)"),   # 蓝 - 登录
    ("RGB(255,245,230)", "RGB(200,120,30)"),   # 橙 - 模式选择
    ("RGB(225,245,225)", "RGB(30,130,50)"),    # 绿 - 数据采集
    ("RGB(240,225,250)", "RGB(120,40,170)"),   # 紫 - 肌电分解
    ("RGB(220,240,245)", "RGB(20,110,130)"),   # 青 - 双输出预测
    ("RGB(255,235,225)", "RGB(180,90,30)"),    # 暖橙 - 康复评估
]

# ============== 布局参数 ==============
CENTER_X = 148.5       # 页面中心 (A4横向 297/2)
BOX_W = 140            # 框宽
BOX_H = 22             # 框高
START_Y = 180          # 第一个框的顶部
GAP = 14               # 框与箭头之间的间距

# ============== 流程数据 ==============
stages = [
    (u"用户登录界面\n输入被试编号，选择动作类型", 0),
    (u"模式选择\n模型验证模式  |  康复评估模式", 1),
    (u"数据采集\n加载 HD-sEMG 信号 (屈肌/伸肌 64ch) + 标签数据 (角度/力)", 2),
    (u"肌电分解 (核心模块)\n离线模板加载 → 在线快速分解 (ICA+模板匹配) → MUAP 波形计算", 3),
    (u"双输出预测 (CNN-BiLSTM)\n特征提取 (累计脉冲计数 + sqrt变换) → 共享主干 + 角度/力双分支输出", 4),
    (u"康复评估与数据管理 (仅康复评估模式)\nROM/力量/稳定性综合评分 + 记录自动保存 + 查询/筛选/趋势图", 5),
]

# ============== 绘制 ==============
# 标题
make_box(CENTER_X - 120, START_Y + 10, 240, 16,
    u"肌电慧控  ——  基于高密度肌电分解的腕关节运动解码与康复评估系统",
    "RGB(25,70,140)", "RGB(25,70,140)", "RGB(255,255,255)",
    "11 pt", True, 2)

y = START_Y

for i, (text, color_idx) in enumerate(stages):
    fill, line = COLORS[color_idx]
    y_top = y - BOX_H
    make_box(CENTER_X - BOX_W/2, y_top, BOX_W, BOX_H, text, fill, line)

    if i < len(stages) - 1:
        # 箭头：从当前框底部指向下一个框顶部
        arrow_y1 = y_top
        arrow_y2 = y_top - GAP
        arrow(CENTER_X, arrow_y1, CENTER_X, arrow_y2)

    y = y_top - GAP

# ============== 保存 ==============
output = r"F:\EMG_decom_angle_system\肌电慧控_系统流程图.vsdx"
for _ in range(3):
    try:
        if os.path.exists(output):
            os.remove(output)
        break
    except:
        time.sleep(0.5)

if os.path.exists(output):
    output = r"F:\EMG_decom_angle_system\肌电慧控_系统流程图_v2.vsdx"

doc.SaveAs(output)
print(f"===== 系统流程图已保存 =====")
print(f"文件: {output}")
print(f"请在 Visio 中打开，Ctrl+Shift+W 适应窗口")
