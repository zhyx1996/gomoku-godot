# -*- coding: utf-8 -*-
src = open('gomoku.gd', encoding='utf-8').read()
NL = chr(10)
T = chr(9)

def rep(old, new, name):
    global src
    assert src.count(old) == 1, 'PATCH FAILED: ' + name
    src = src.replace(old, new)
    print('ok', name)

# 1) 分析文字自动换行（不再撑宽面板）
rep("\tanalysis_label = Label.new()" + NL +
    "\tanalysis_label.text = \"等待引擎响应…\"" + NL +
    "\tanalysis_label.add_theme_font_size_override(\"font_size\", 12)" + NL +
    "\tanalysis_label.add_theme_color_override(\"font_color\", Color(\"9db4d8\"))" + NL +
    "\tanalysis_label.add_theme_constant_override(\"line_spacing\", 3)" + NL +
    "\tanalysis_label.custom_minimum_size = Vector2(0, 70)",
    "\tanalysis_label = Label.new()" + NL +
    "\tanalysis_label.text = \"等待引擎响应…\"" + NL +
    "\tanalysis_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # 长行折行，防止把面板撑宽（宽度跳动的根源）" + NL +
    "\tanalysis_label.add_theme_font_size_override(\"font_size\", 12)" + NL +
    "\tanalysis_label.add_theme_color_override(\"font_color\", Color(\"9db4d8\"))" + NL +
    "\tanalysis_label.add_theme_constant_override(\"line_spacing\", 3)" + NL +
    "\tanalysis_label.custom_minimum_size = Vector2(0, 70)", 'autowrap')

# 2) 面板锁宽：内容最小宽再也不会超过 264
rep("\tpanel.position = Vector2(_board_origin().x + 656.0 + 12.0, SIDE_PANEL_POSITION.y)" + NL +
    "\tpanel.size = SIDE_PANEL_SIZE",
    "\tpanel.custom_minimum_size = SIDE_PANEL_SIZE  # 锁定面板宽度：内容（分析文字等）不再撑宽/抖动" + NL +
    "\tpanel.position = Vector2(_board_origin().x + 656.0 + 12.0, SIDE_PANEL_POSITION.y)" + NL +
    "\tpanel.size = SIDE_PANEL_SIZE", 'panel lock')

# 3) PV 坐标限长（超出的以 … 截断）
rep("\t\t\tvar parts := []" + NL +
    "\t\t\tfor c in bl:" + NL +
    "\t\t\t\tif c is Vector2i:" + NL +
    "\t\t\t\t\tparts.append(\"%s%d\" % [char(65 + c.x), c.y + 1])",
    "\t\t\tvar parts := []" + NL +
    "\t\t\tfor c in bl:" + NL +
    "\t\t\t\tif parts.size() >= 12:" + NL +
    "\t\t\t\t\tparts.append(\"…\")" + NL +
    "\t\t\t\t\tbreak" + NL +
    "\t\t\t\tif c is Vector2i:" + NL +
    "\t\t\t\t\tparts.append(\"%s%d\" % [char(65 + c.x), c.y + 1])", 'pv cap')

open('gomoku.gd', 'w', encoding='utf-8').write(src)
print('PANEL FIX APPLIED')
