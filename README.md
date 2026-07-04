# stream-magnet

`stream-magnet` 是一个为 Google Antigravity CLI (`agycli` / `agy`) 定制的自定义一键化 Skill。它支持在 Windows 系统下全自动配置环境并一键流式边下边播磁力链接。

## 🌟 核心特性

- **🚀 全自动环境准备**：自动检测系统内是否安装了 `qBittorrent` 和 `PotPlayer`。如未安装，利用 Windows `winget` 命令行工具进行静默安装（无弹窗干扰）。
- **🔧 自动配置文件注入**：自动定位并修改 `%APPDATA%\qBittorrent\qBittorrent.ini`，注入 `Session\SequentialDownload=true` 和 `Session\FirstLastPiecePriority=true`，实现免配置顺序下载。
- **🎬 一键流式边下边播**：
  - 后台添加磁力链接至 `qBittorrent`。
  - 定时轮询下载目录，一旦检测到新产生的视频文件（支持 `.mp4`, `.mkv`, `.avi` 等，并自适应 `.!qB` 未完成扩展名）且有数据写入（> 2MB），立即自动调起本地的 `PotPlayer` 播放该文件，实现边下边播。

## 📁 目录结构

```text
stream-magnet/
├── .agents/
│   └── skills/
│       └── stream-magnet/
│           ├── SKILL.md          # 技能描述文件
│           └── scripts/
│               └── stream.ps1    # 自动化执行脚本
└── README.md                     # 项目说明
```

## 🛠️ 安装与注册

如果你想在你的 `agycli` 中使用该 Skill，你可以将其克隆到你的项目根目录下的 `.agents` 文件夹中，或者全局注册：

### 全局注册（推荐）

将 `.agents/skills/stream-magnet` 文件夹复制到 `agycli` 的全局配置目录中：

- **Windows**: `C:\Users\<YourUsername>\.gemini\config\skills\stream-magnet`

复制后，当你在 `agy` 交互界面中输入磁力链接并发出流式播放请求时，`agycli` 会自动识别并加载该 Skill，运行 `stream.ps1` 进行流式播放。

## 📖 使用示例

在 `agy` 交互中直接输入：

> 帮我流式播放这个磁力链接：magnet:?xt=urn:btih:XXXXX...

或者你也可以在 PowerShell 中直接以命令行方式独立运行脚本：

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\sj929\.gemini\config\skills\stream-magnet\scripts\stream.ps1" -Magnet "magnet:?xt=urn:btih:XXXXX..."
```

## 📝 许可证

[MIT License](LICENSE)
