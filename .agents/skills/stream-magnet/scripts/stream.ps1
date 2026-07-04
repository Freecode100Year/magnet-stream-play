<#
.SYNOPSIS
    Stream magnet links using qBittorrent and PotPlayer.
.PARAMETER Magnet
    The magnet link to download and play.
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$Magnet
)

$ErrorActionPreference = "Stop"

# ==========================================
# 1. 辅助函数定义
# ==========================================

# 获取 PotPlayer 路径
function Get-PotPlayerPath {
    $paths = @(
        "C:\Program Files\DAUM\PotPlayer\PotPlayerMini64.exe",
        "C:\Program Files (x86)\DAUM\PotPlayer\PotPlayerMini.exe",
        "C:\Program Files\DAUM\PotPlayer\PotPlayer.exe",
        "C:\Program Files (x86)\DAUM\PotPlayer\PotPlayer.exe"
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }
    
    # 尝试从注册表获取
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\PotPlayer",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\PotPlayer"
    )
    foreach ($rp in $regPaths) {
        if (Test-Path $rp) {
            $loc = Get-ItemProperty -Path $rp -Name "InstallLocation" -ErrorAction SilentlyContinue
            if ($loc) {
                $p64 = Join-Path $loc.InstallLocation "PotPlayerMini64.exe"
                if (Test-Path $p64) { return $p64 }
                $p32 = Join-Path $loc.InstallLocation "PotPlayerMini.exe"
                if (Test-Path $p32) { return $p32 }
            }
        }
    }
    
    # 尝试从 PATH 中获取
    $cmd = Get-Command "PotPlayerMini64.exe" -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $cmd = Get-Command "PotPlayerMini.exe" -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    return $null
}

# 获取 qBittorrent 路径
function Get-qBittorrentPath {
    $paths = @(
        "C:\Program Files\qBittorrent\qbittorrent.exe",
        "C:\Program Files (x86)\qBittorrent\qbittorrent.exe"
    )
    foreach ($p in $paths) {
        if (Test-Path $p) { return $p }
    }
    
    # 尝试从注册表获取
    $regPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\qBittorrent",
        "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\qBittorrent"
    )
    foreach ($rp in $regPaths) {
        if (Test-Path $rp) {
            $loc = Get-ItemProperty -Path $rp -Name "InstallLocation" -ErrorAction SilentlyContinue
            if ($loc) {
                $qb = Join-Path $loc.InstallLocation "qbittorrent.exe"
                if (Test-Path $qb) { return $qb }
            }
        }
    }
    
    # 尝试从 PATH 中获取
    $cmd = Get-Command "qbittorrent.exe" -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    return $null
}

# 获取下载目录
function Get-DownloadsPath {
    $qbIni = Join-Path $env:APPDATA "qBittorrent\qBittorrent.ini"
    if (Test-Path $qbIni) {
        $lines = Get-Content $qbIni
        $inSection = $false
        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            if ($trimmed -eq "[BitTorrent]") {
                $inSection = $true
            } elseif ($trimmed.StartsWith("[")) {
                $inSection = $false
            }
            if ($inSection) {
                $pair = $trimmed -split '=', 2
                if ($pair.Count -eq 2 -and $pair[0].Trim() -eq "Session\DefaultSavePath") {
                    $path = $pair[1].Trim()
                    if ($path) { return $path }
                }
            }
        }
    }
    
    # 注册表 Downloads
    $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"
    $downloads = Get-ItemProperty -Path $regPath -Name "{374DE290-123F-4565-9164-39C4925E467B}" -ErrorAction SilentlyContinue
    if ($downloads) {
        return $downloads."{374DE290-123F-4565-9164-39C4925E467B}"
    }
    
    return Join-Path $env:USERPROFILE "Downloads"
}

# 更新 INI 配置文件
function Update-IniFile {
    param (
        [string]$filePath,
        [string]$section,
        [hashtable]$settings
    )
    
    if (!(Test-Path $filePath)) {
        $dir = Split-Path $filePath
        if (!(Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        $lines = @("[$section]")
        foreach ($key in $settings.Keys) {
            $lines += "$key=$($settings[$key])"
        }
        Set-Content -Path $filePath -Value $lines -Encoding utf8
        return
    }

    $lines = Get-Content -Path $filePath
    $newLines = @()
    $inSection = $false
    $sectionFound = $false
    $updatedKeys = @{}
    foreach ($k in $settings.Keys) {
        $updatedKeys[$k] = $false
    }

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed.StartsWith("[") -and $trimmed.EndsWith("]")) {
            if ($inSection) {
                foreach ($k in $settings.Keys) {
                    if (-not $updatedKeys[$k]) {
                        $newLines += "$k=$($settings[$k])"
                        $updatedKeys[$k] = $true
                    }
                }
                $inSection = $false
            }
            if ($trimmed -eq "[$section]") {
                $inSection = $true
                $sectionFound = $true
            }
            $newLines += $line
        } else {
            if ($inSection) {
                $pair = $trimmed -split '=', 2
                if ($pair.Count -eq 2) {
                    $key = $pair[0].Trim()
                    if ($settings.ContainsKey($key)) {
                        $newLines += "$key=$($settings[$key])"
                        $updatedKeys[$key] = $true
                        continue
                    }
                }
            }
            $newLines += $line
        }
    }

    if ($inSection) {
        foreach ($k in $settings.Keys) {
            if (-not $updatedKeys[$k]) {
                $newLines += "$k=$($settings[$k])"
                $updatedKeys[$k] = $true
            }
        }
    } elseif (-not $sectionFound) {
        $newLines += ""
        $newLines += "[$section]"
        foreach ($k in $settings.Keys) {
            $newLines += "$k=$($settings[$k])"
        }
    }

    Set-Content -Path $filePath -Value $newLines -Encoding utf8
}

# ==========================================
# 2. 全自动环境准备
# ==========================================

Write-Host ">>> 步骤 1: 检查并安装环境依赖 (winget)..."

# 检查/安装 qBittorrent
$qbPath = Get-qBittorrentPath
if (-not $qbPath) {
    Write-Host "未检测到 qBittorrent，正在通过 winget 静默安装..."
    winget install --id qBittorrent.qBittorrent --silent --accept-source-agreements --accept-package-agreements
    Start-Sleep -Seconds 5
    $qbPath = Get-qBittorrentPath
    if (-not $qbPath) {
        Write-Error "qBittorrent 安装失败，请检查 winget 日志。"
        exit 1
    }
    Write-Host "qBittorrent 安装成功: $qbPath"
} else {
    Write-Host "qBittorrent 已安装: $qbPath"
}

# 检查/安装 PotPlayer
$potPath = Get-PotPlayerPath
if (-not $potPath) {
    Write-Host "未检测到 PotPlayer，正在通过 winget 静默安装..."
    winget install --id Daum.PotPlayer --silent --accept-source-agreements --accept-package-agreements
    Start-Sleep -Seconds 5
    $potPath = Get-PotPlayerPath
    if (-not $potPath) {
        Write-Error "PotPlayer 安装失败，请检查 winget 日志。"
        exit 1
    }
    Write-Host "PotPlayer 安装成功: $potPath"
} else {
    Write-Host "PotPlayer 已安装: $potPath"
}

# ==========================================
# 3. 自动配置文件注入
# ==========================================

Write-Host ">>> 步骤 2: 注入 qBittorrent 顺序下载配置..."

$qbProcess = Get-Process -Name "qbittorrent" -ErrorAction SilentlyContinue
if ($qbProcess) {
    Write-Host "检测到 qBittorrent 正在运行，将其暂时关闭以应用配置..."
    Stop-Process -Name "qbittorrent" -Force
    Start-Sleep -Seconds 2
}

$qbIni = Join-Path $env:APPDATA "qBittorrent\qBittorrent.ini"
$settings = @{
    "Session\SequentialDownload" = "true"
    "Session\FirstLastPiecePriority" = "true"
}

Update-IniFile -filePath $qbIni -section "BitTorrent" -settings $settings
Write-Host "顺序下载配置注入成功！"

# ==========================================
# 4. 一键流式播放
# ==========================================

Write-Host ">>> 步骤 3: 开始一键流式播放..."
$startTime = [DateTime]::Now
$downloadDir = Get-DownloadsPath
Write-Host "使用下载目录: $downloadDir"

# 后台启动 qBittorrent 并添加磁力
Write-Host "添加磁力链接至 qBittorrent..."
Start-Process $qbPath -ArgumentList @("`"$Magnet`"")

Write-Host "正在等待视频文件创建与数据写入..."
$videoExtensions = @(".mp4", ".mkv", ".avi", ".mov", ".flv", ".ts", ".rmvb", ".wmv")
$found = $false
$timeoutSeconds = 300 # 5分钟超时
$elapsed = 0

while (-not $found -and $elapsed -lt $timeoutSeconds) {
    Start-Sleep -Seconds 2
    $elapsed += 2
    
    if ($elapsed % 10 -eq 0) {
        Write-Host "正在轮询下载目录...已耗时 $elapsed 秒"
    }

    # 递归查找新视频文件 (先用修改时间粗筛，提高大量文件下的轮询效率)
    $files = Get-ChildItem -Path $downloadDir -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        ($_.LastWriteTime -ge $startTime -or $_.CreationTime -ge $startTime) -and (
            $fileName = $_.Name.ToLower()
            $isMatch = $false
            foreach ($ext in $videoExtensions) {
                if ($fileName.EndsWith($ext) -or $fileName.EndsWith("$ext.!qb")) {
                    $isMatch = $true
                    break
                }
            }
            $isMatch
        )
    }

    foreach ($file in $files) {
        # 只要文件大小大于 2MB，就认为开始正常下载数据并开始写入
        if ($file.Length -gt 2 * 1024 * 1024) {
            Write-Host "检测到可播放的视频文件: $($file.FullName) (大小: $([Math]::Round($file.Length/1MB, 2)) MB)"
            Write-Host "正在使用 PotPlayer 启动流式播放..."
            Start-Process $potPath -ArgumentList @("`"$($file.FullName)`"")
            $found = $true
            break
        }
    }
}

if (-not $found) {
    Write-Warning "未能在 5 分钟内检测到可用的新视频文件。请检查 qBittorrent 下载进度与连接数。"
}
