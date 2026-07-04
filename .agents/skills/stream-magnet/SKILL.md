---
name: stream-magnet
description: >-
  利用 qBittorrent 和 PotPlayer 在 Windows 上一键流式播放磁力链接。
  当用户提供磁力链接或种子并希望边下边播时使用此技能。
  该技能会自动检查并静默安装 qBittorrent 和 PotPlayer，修改配置文件为顺序下载，并在检测到视频文件开始写入后自动调起 PotPlayer 进行播放。
---

# Stream Magnet

该 Skill 用于在 Windows 系统上实现磁力链接/种子文件的一键流式边下边播。

## 核心功能

1. **全自动环境准备**：自动检测系统内是否安装了 qBittorrent 和 PotPlayer。如未安装，调用 `winget` 命令行工具进行静默安装。
2. **自动配置文件注入**：自动定位并修改 `%APPDATA%\qBittorrent\qBittorrent.ini`，注入 `Session\SequentialDownload=true` 和 `Session\FirstLastPiecePriority=true` 以开启顺序下载。
3. **一键流式播放**：后台调起 qBittorrent 开始下载，并在下载目录轮询检测新创建的视频文件，一旦文件大于 2MB，立即启动 PotPlayer 播放该文件。

## 运行方式

通过执行 [stream.ps1](./scripts/stream.ps1) 脚本启动流式下载与播放。

在提示词中接收到磁力链接时，可运行如下命令：

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\sj929\.gemini\config\skills\stream-magnet\scripts\stream.ps1" -Magnet "<磁力链接>"
```
