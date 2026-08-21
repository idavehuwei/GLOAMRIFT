# GLOAMRIFT · 幽影深渊

> 一款基于 **Godot 4.7** 的纯 GDScript 动作 RPG（代码优先，场景由脚本生成）。

## 项目简介

《幽影深渊》（GLOAMRIFT）是一个从零搭建的 2D/2.5D 暗黑风格 RPG 原型。核心循环涵盖：世界生成、昼夜系统、怪物与动物、合成与熔炼、经验附魔、BOSS、地牢、村庄与村民交易、红石式自动化、成就系统，以及海底 / 下界两个扩展维度。

## 技术栈

- **引擎**：Godot 4.7
- **语言**：纯 GDScript（无 C#）
- **工程方式**：代码优先（code-first）——不在编辑器里手工摆放场景，`.tscn` 全部由 `tools/gen_scenes.py` 生成
- **自动加载单例**：Game / WorldState / LootData / AchData / UiKit / Assets / Sfx / ThreadPool / EventBus / Notify / DialogueManager

## 目录结构

```
godot/                Godot 工程根目录（用 Godot 4.7 打开 project.godot）
  autoload/          自动加载单例脚本
  scripts/           游戏逻辑脚本（含 ItemData 资源类）
  addons/item_dock/  物品库编辑器 Dock 插件（EditorPlugin）
  data/              游戏数据（loot.json、items/*.tres 等）
  icons/             图标资源
  project.godot      Godot 工程配置
README.md            本文件
LICENSE              许可协议（源码 / 资源 / 商用条款）
```

## 运行方式

1. 安装 [Godot 4.7](https://godotengine.org/)。
2. 用 Godot 打开 `godot/project.godot`。
3. 按 F5 运行主场景。

> 物品库编辑器 Dock 已随工程自动启用，打开编辑器后可在左下角「物品库」标签页浏览 / 新建 / 编辑 / 导入导出 `ItemData` 资源。

## 许可

详见 [LICENSE](LICENSE)：

- **源代码**（`.gd` 等）：免费用于学习、研究、修改与再分发（请保留署名）。
- **游戏资源**（模型、贴图、图标、音效、动画、关卡与物品数据等）：保留全部权利，**任何商业用途需购买授权**。
- **商用**：将本项目（含源码或资源）用于商业产品前，请先购买商业授权。

## 本地密钥

本仓库**不包含**任何密钥文件。`key.md`（本地 API Key）已被 `.gitignore` 排除，永不进入版本库。
