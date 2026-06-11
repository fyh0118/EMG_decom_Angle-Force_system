#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
创建"肌电慧控"整体技术路线图 Visio 文件 v3
使用 Visio 内置 Stencil 的 Master 确保形状可正确渲染
"""

import win32com.client
import pythoncom

pythoncom.CoInitialize()

# ============== 启动 Visio ==============
visio = win32com.client.Dispatch("Visio.Application")
visio.Visible = True

# 创建空白文档
doc = visio.Documents.Add("")
page = doc.Pages.Item(1)
page.Name = "整体技术路线"

# 页面设置 A4横向
page.PageSheet.Cells("PageWidth").Formula = "297 mm"
page.PageSheet.Cells("PageHeight").Formula = "210 mm"

# ============== 打开基本形状模具(Stencil)获取 Master ==============
# Visio内置模具: BASIC_U.VSSX, BASIC_M.VSSX (美制/公制)
stencil = None
for stencil_name in ["BASIC_M.VSSX", "BASIC_U.VSSX", "BASFLO_M.VSSX",
                      "BASIC_M.VSS", "BASIC_U.VSS", "BASFLO_M.VSS"]:
    try:
        stencil = visio.Documents.OpenEx(stencil_name, 0x40)  # visOpenCopy + visOpenDocked
        print(f"Opened stencil: {stencil_name}")
        break
    except:
        pass

# 获取 Rectangle master
rect = None
if stencil:
    for m_name in ["Rectangle", "Rounded Rectangle", "Square", "Box"]:
        try:
            rect = stencil.Masters.ItemU(m_name)
            print(f"Found master: {m_name}")
            break
        except:
            pass

if rect is None:
    # 尝试文档内部masters
    for i in range(1, doc.Masters.Count + 1):
        m = doc.Masters.Item(i)
        print(f"Doc master {i}: {m.Name}")
        if m.Name and 'rect' in m.Name.lower():
            rect = m
            break

if rect is None:
    # 最后的fallback: 创建一个简单位图形状
    print("WARNING: No Rectangle master found, creating shapes with Page.DrawRectangle")
    use_masters = False
else:
    print(f"Using master: {rect.Name}")
    use_masters = True

# ============== 辅助函数 ==============
def new_shape(x_mm, y_mm, w_mm, h_mm, text,
              fill="RGB(255,255,255)", line_color="RGB(0,0,0)",
              line_w="0.8 pt", font_sz="8 pt", round_mm=0,
              bold=False, text_color="RGB(0,0,0)",
              fill_pat="1", line_pat="1"):
    """使用 Master 创建形状 (mm单位)"""
    if use_masters:
        # Drop master: 形状以 PinX/PinY 为中心
        shp = page.Drop(rect, x_mm / 25.4, y_mm / 25.4)
        # 重新定位: 使 Pin 在左下角
        shp.Cells("LocPinX").Formula = "Width*0"
        shp.Cells("LocPinY").Formula = "Height*0"
        shp.Cells("PinX").Formula = f"{x_mm} mm"
        shp.Cells("PinY").Formula = f"{y_mm} mm"
        shp.Cells("Width").Formula = f"{w_mm} mm"
        shp.Cells("Height").Formula = f"{h_mm} mm"
    else:
        # inch 单位
        x_in = x_mm / 25.4
        y_in = y_mm / 25.4
        w_in = w_mm / 25.4
        h_in = h_mm / 25.4
        shp = page.DrawRectangle(x_in, y_in, x_in + w_in, y_in + h_in)

    # 填充
    shp.Cells("FillForegnd").Formula = fill
    shp.Cells("FillPattern").Formula = fill_pat
    if fill_pat == "1":
        shp.Cells("FillBkgnd").Formula = "RGB(255,255,255)"

    # 线条
    shp.Cells("LineColor").Formula = line_color
    shp.Cells("LineWeight").Formula = line_w
    shp.Cells("LinePattern").Formula = line_pat

    # 圆角
    if round_mm > 0:
        shp.Cells("Rounding").Formula = f"{round_mm} mm"

    # 文本
    shp.Text = text
    shp.Cells("Char.Size").Formula = font_sz
    shp.Cells("Char.Color").Formula = text_color
    shp.Cells("Para.HorzAlign").Formula = "1"  # center
    if bold:
        shp.Cells("Char.Style").Formula = "1"  # bold

    return shp

def add_v_arrow(cx_mm, y1_mm, y2_mm):
    """垂直箭头 (mm -> inch)"""
    cx = cx_mm / 25.4
    y1 = y1_mm / 25.4
    y2 = y2_mm / 25.4
    ln = page.DrawLine(cx, y1, cx, y2)
    ln.Cells("LineColor").Formula = "RGB(80,80,80)"
    ln.Cells("LineWeight").Formula = "1.2 pt"
    ln.Cells("EndArrow").Formula = "5"
    ln.Cells("EndArrowSize").Formula = "3"
    return ln

def add_h_arrow(x1_mm, x2_mm, y_mm, txt="", clr="RGB(130,130,130)",
                lw="0.8 pt"):
    """水平箭头"""
    ln = page.DrawLine(x1_mm/25.4, y_mm/25.4, x2_mm/25.4, y_mm/25.4)
    ln.Cells("LineColor").Formula = clr
    ln.Cells("LineWeight").Formula = lw
    ln.Cells("EndArrow").Formula = "5"
    ln.Cells("EndArrowSize").Formula = "2"
    if txt:
        ln.Text = txt
        ln.Cells("Char.Size").Formula = "7 pt"
    return ln

# ============== 颜色方案 ==============
C_BLUE = "RGB(210,225,245)"
C_BLUE_BO = "RGB(60,100,180)"
C_GREEN = "RGB(210,240,220)"
C_GREEN_BO = "RGB(40,130,80)"
C_ORANGE = "RGB(255,235,215)"
C_ORANGE_BO = "RGB(200,120,40)"
C_PURPLE = "RGB(230,220,245)"
C_PURPLE_BO = "RGB(120,60,160)"
C_TEAL = "RGB(210,235,235)"
C_TEAL_BO = "RGB(25,115,125)"
C_WHITE = "RGB(255,255,255)"
C_DARK = "RGB(40,40,40)"
C_TITLE_BG = "RGB(30,80,150)"

# ============== 布局 (mm, 底部为原点) ==============
PW = 297
PH = 210
LEFT = 15
CW = PW - 30  # 267
CX = LEFT + CW / 2  # 中心 X
GAP = 6  # 层间间距

# 从下往上排列
y_title = PH - 24
y_1 = 135
y_2 = 95
y_3 = 50
y_4 = 5
# 每层高度
h_title = 16
h_1 = 32
h_2 = 20
h_3 = 38
h_4 = 32
h_5 = 26

# ============== 标题 ==============
new_shape(LEFT, y_title, CW, h_title,
    u"肌电慧控 —— 基于高密度肌电分解的腕关节运动解码与康复评估系统  |  整体技术路线图",
    C_TITLE_BG, C_TITLE_BG, "0 pt", "14 pt", 4, True, "RGB(255,255,255)",
    "1", "0")

# ============== 第1层: 数据采集 ==============
new_shape(LEFT, y_1, CW, h_1,
    u"一、数据采集层 —— HD-sEMG信号与运动数据同步采集",
    C_BLUE, C_BLUE_BO, "1.2 pt", "11 pt", 3, True, C_BLUE_BO, "1", "3")

sw1 = (CW - 30) / 3
g1 = 7
sy1 = y_1 + 6
sh1 = h_1 - 14

new_shape(LEFT + g1, sy1, sw1, sh1,
    u"64通道 HD-sEMG 电极阵列\n  8x8阵列, 桡侧腕屈肌+指屈肌\n  采样率 2000 Hz",
    C_WHITE, C_BLUE_BO, "0.8 pt", "8 pt", 2, text_color=C_DARK)

new_shape(LEFT + g1*2 + sw1, sy1, sw1, sh1,
    u"多模态运动范式采集\n  腕屈伸 | 腕旋转\n  指屈伸 | 指旋转\n  5级力度 (10%~50%MVC)",
    C_WHITE, C_BLUE_BO, "0.8 pt", "8 pt", 2, text_color=C_DARK)

new_shape(LEFT + g1*3 + sw1*2, sy1, sw1, sh1,
    u"同步辅助信号采集\n  LeapC运动捕捉 -> 角度真值\n  压力传感器 -> 力信号真值\n  单次试次 20s (5+10+5)",
    C_WHITE, C_BLUE_BO, "0.8 pt", "8 pt", 2, text_color=C_DARK)

add_v_arrow(CX, y_1 - 3, y_1 - 9)

# ============== 第2层: 预处理 ==============
new_shape(LEFT, y_2, CW, h_2,
    u"二、信号预处理层",
    C_GREEN, C_GREEN_BO, "1.2 pt", "11 pt", 3, True, C_GREEN_BO, "1", "3")

sw2 = (CW - 25) / 3
g2 = 5
sy2 = y_2 + 4
sh2 = h_2 - 8

new_shape(LEFT + g2, sy2, sw2, sh2,
    u"4阶 Butterworth 带通滤波\n通带: 20 ~ 500 Hz",
    C_WHITE, C_GREEN_BO, "0.8 pt", "8 pt", 2, text_color=C_DARK)

new_shape(LEFT + g2*2 + sw2, sy2, sw2, sh2,
    u"梳状陷波滤波\n50 Hz + 谐波 (100/150/.../500 Hz)",
    C_WHITE, C_GREEN_BO, "0.8 pt", "8 pt", 2, text_color=C_DARK)

new_shape(LEFT + g2*3 + sw2*2, sy2, sw2, sh2,
    u"异常通道检测与剔除\n信号质量检验 + 归一化",
    C_WHITE, C_GREEN_BO, "0.8 pt", "8 pt", 2, text_color=C_DARK)

add_v_arrow(CX, y_2 - 3, y_2 - 9)

# ============== 第3层: 肌电分解(核心) ==============
new_shape(LEFT, y_3, CW, h_3,
    u"三、肌电分解层 —— 从HD-sEMG到运动单元脉冲序列 (核心算法)",
    C_ORANGE, C_ORANGE_BO, "1.2 pt", "11 pt", 3, True, C_ORANGE_BO, "1", "3")

off_w = CW * 0.42
on_w = CW * 0.52
g3 = 6
sy3 = y_3 + 5
sh3 = h_3 - 14

s3a = new_shape(LEFT + g3, sy3, off_w, sh3,
    u"【离线阶段】个性化MU模板构建\n\n  FastICA 盲源分离\n  -> 运动单元(MU)分解\n  -> 提取 MUAP 波形\n  -> 构建个性化MU模板库",
    C_WHITE, C_ORANGE_BO, "1 pt", "8 pt", 2, text_color=C_DARK)

s3b = new_shape(LEFT + g3*2 + off_w, sy3, on_w, sh3,
    u"【在线阶段】实时肌电分解\n\n  新用户 -> 匹配个性化模板\n  -> 模板匹配 + 在线盲源分离\n  -> 实时输出运动单元脉冲序列\n     (Spike Train, 多MU同步放电)",
    C_WHITE, C_ORANGE_BO, "1 pt", "8 pt", 2, text_color=C_DARK)

# 内部水平箭头
y3mid = sy3 + sh3 / 2
add_h_arrow(LEFT + g3 + off_w + 2, LEFT + g3*2 + off_w - 2, y3mid,
            u"模板加载", C_ORANGE_BO, "1 pt")

add_v_arrow(CX, y_3 - 3, y_3 - 9)

# ============== 第4层: 特征提取与预测 ==============
new_shape(LEFT, y_4, CW, h_4,
    u"四、特征提取与双输出预测层",
    C_PURPLE, C_PURPLE_BO, "1.2 pt", "11 pt", 3, True, C_PURPLE_BO, "1", "3")

sw4 = (CW - 22) / 3
g4 = 5
sy4 = y_4 + 4
sh4 = h_4 - 11

new_shape(LEFT + g4, sy4, sw4, sh4,
    u"时空脉冲特征提取\n\n  滑动时间窗 (200ms)\n  MU放电率统计\n  时空脉冲密度特征",
    C_WHITE, C_PURPLE_BO, "0.8 pt", "8 pt", 2, text_color=C_DARK)

new_shape(LEFT + g4*2 + sw4, sy4, sw4, sh4,
    u"CNN-BiLSTM 深度网络\n\n  CNN: 局部空间特征提取\n  BiLSTM: 前后向时序依赖\n  注意力机制特征融合",
    C_WHITE, C_PURPLE_BO, "0.8 pt", "8 pt", 2, text_color=C_DARK)

new_shape(LEFT + g4*3 + sw4*2, sy4, sw4, sh4,
    u"双输出同步预测\n\n  * 腕关节角度\n     屈伸角度 + 旋转角度\n  * 力信号\n     握力 / 捏力预测",
    C_WHITE, C_PURPLE_BO, "0.8 pt", "8 pt", 2, text_color=C_DARK)

y4mid = sy4 + sh4 / 2
add_h_arrow(LEFT + g4 + sw4 + 1, LEFT + g4*2 + sw4 - 1, y4mid)
add_h_arrow(LEFT + g4*2 + sw4*2 + 1, LEFT + g4*3 + sw4*2 - 1, y4mid)

add_v_arrow(CX, y_4 - 3, y_4 - 9)

# ============== 第5层: 康复系统 ==============
y_5 = y_4 - 42
new_shape(LEFT, y_5, CW, h_5,
    u"五、康复评估与可视化系统层 —— MATLAB GUI 集成平台",
    C_TEAL, C_TEAL_BO, "1.2 pt", "11 pt", 3, True, C_TEAL_BO, "1", "3")

sw5 = (CW - 25) / 4
g5 = 4
sy5 = y_5 + 3
sh5 = h_5 - 9

new_shape(LEFT + g5, sy5, sw5, sh5,
    u"数据导入模块\nHD-sEMG/角度/力\n数据加载与回放",
    C_WHITE, C_TEAL_BO, "0.8 pt", "7 pt", 2, text_color=C_DARK)

new_shape(LEFT + g5*2 + sw5, sy5, sw5, sh5,
    u"肌电分解模块\n在线分解引擎\nSpike Train 输出",
    C_WHITE, C_TEAL_BO, "0.8 pt", "7 pt", 2, text_color=C_DARK)

new_shape(LEFT + g5*3 + sw5*2, sy5, sw5, sh5,
    u"运动预测模块\n角度+力双输出\n实时预测曲线显示",
    C_WHITE, C_TEAL_BO, "0.8 pt", "7 pt", 2, text_color=C_DARK)

new_shape(LEFT + g5*4 + sw5*3, sy5, sw5, sh5,
    u"康复评估模块\n运动范围/力量稳定性\n肌肉激活度综合评分",
    C_WHITE, C_TEAL_BO, "0.8 pt", "7 pt", 2, text_color=C_DARK)

y5mid = sy5 + sh5 / 2
add_h_arrow(LEFT + g5 + sw5 + 1, LEFT + g5*2 + sw5 - 1, y5mid)
add_h_arrow(LEFT + g5*2 + sw5*2 + 1, LEFT + g5*3 + sw5*2 - 1, y5mid)
add_h_arrow(LEFT + g5*3 + sw5*3 + 1, LEFT + g5*4 + sw5*3 - 1, y5mid)

# ============== 右侧标签 ==============
tx = PW - 55

new_shape(tx, y_3 + 20, 48, 32,
    u"【关键技术】\n  FastICA 盲源分离\n  个性化MU模板匹配\n  CNN-BiLSTM 双输出\n  MATLAB GUI 集成",
    "RGB(252,252,255)", "RGB(130,130,180)", "0.6 pt", "7 pt", 3,
    False, "RGB(60,60,60)", "1", "2")

new_shape(tx, y_3 - 20, 48, 30,
    u"【预期指标】\n  R平方 > 0.9\n  角度 RMSE < 5度\n  力 RMSE < 3%MVC",
    "RGB(252,255,252)", "RGB(130,180,130)", "0.6 pt", "7 pt", 3,
    False, "RGB(60,60,60)", "1", "2")

# ============== 保存 ==============
output = r"F:\EMG_decom_angle_system\肌电慧控_技术路线图.vsdx"
import os, time
# 先尝试删除旧文件
for _ in range(3):
    try:
        if os.path.exists(output):
            os.remove(output)
        break
    except:
        time.sleep(1)
# fallback 文件名
if os.path.exists(output):
    output = r"F:\EMG_decom_angle_system\肌电慧控_技术路线图_v2.vsdx"
    print(f"原文件被占用, 使用备用名: {output}")
doc.SaveAs(output)
print(f"\n===== 技术路线图已保存 =====")
print(f"文件: {output}")
print(f"页数: {doc.Pages.Count}, 形状: {page.Shapes.Count}")
print(f"请在 Visio 中按 Ctrl+Shift+W 适应窗口查看")
