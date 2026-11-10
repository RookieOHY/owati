# demo 目录说明

图标设计草稿与生成工具。菜单栏图标选用**水滴方案**（`owati.svg`），水杯方案保留作 App 图标备选。

| 文件名 | 描述 |
|---|---|
| `owati.svg` | 菜单栏图标源稿：水滴 + 水位波浪线，22×22 viewBox，2pt 描边模板图风格（已选用） |
| `glass.svg` | App 图标草稿 v2.2：水杯 + 弯头吸管 + 卡在杯沿的柠檬轮（备选，将来做 512px 细节版） |
| `glass-lean.svg` | 简化水杯草稿：去掉柠檬片的对照版本（22px 下仍偏糊，已弃用） |
| `make_icons.swift` | 图标生成脚本：把 SVG 光栅化为 22px/44px PNG 并输出亮暗背景预览图，用法 `swift demo/make_icons.swift <文件名>.svg` |
| `png/owati-22.png` | 水滴 @1x 模板图（22px） |
| `png/owati-44.png` | 水滴 @2x 模板图（44px），**main.swift 当前实际加载的文件** |
| `png/owati-preview.png` | 水滴在亮/暗背景下的效果预览 |
| `png/glass-22.png` | 水杯方案 @1x |
| `png/glass-44.png` | 水杯方案 @2x |
| `png/glass-preview.png` | 水杯方案亮暗背景预览 |
| `png/glass-lean-22.png` | 简化水杯 @1x |
| `png/glass-lean-44.png` | 简化水杯 @2x |
| `png/glass-lean-preview.png` | 简化水杯亮暗背景预览 |
