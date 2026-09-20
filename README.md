# LogVolume 🔊

Windows向けの**対数音量ミキサー（Logarithmic Volume Mixer）**です。

イヤホンや外付けアンプ使用時に、Windows標準の音量では調整しにくい小さな音量を、dB単位で細かく調整できます。

## 主な機能

- マスター音量のdB単位調整（`-60 dB`〜`0 dB`）
- アプリケーションごとの音量・ミュート調整
- マイク音量・ミュート調整
- 対応デバイスのサイドトーン調整
- リアルタイム音量ピークメーター
- 外部から変更された音量の自動同期
- Windowsテーマに応じた表示
- 常に手前に表示するオプション
- 設定の自動保存（`%APPDATA%\LogVolume\settings.json`）

## 動作要件

- Windows 10 / Windows 11（64-bit）
- Windows PowerShell 5.1 または PowerShell 7+
- 追加ランタイムやDLLは不要

## 使い方

1. リポジトリをダウンロードするか、`git clone`します。
2. PowerShellターミナルでリポジトリのフォルダーを開きます。
3. 次のコマンドで起動します。

```powershell
powershell.exe -NoProfile -STA -File ".\LogVolume.ps1"
```

PowerShell 7を使用する場合は、次のコマンドでも起動できます。

```powershell
pwsh.exe -NoProfile -STA -File ".\LogVolume.ps1"
```

`-STA` はWindows Forms UIの起動に必要です。

### ダウンロード後に実行できない場合

GitHubなどからダウンロードしたPowerShellスクリプトには、Windowsによってインターネット由来のマークが付くことがあります。信頼できるソースから取得したことを確認したうえで、必要な場合のみ次を実行してください。

```powershell
Unblock-File -Path ".\LogVolume.ps1"
```

その後、上記の起動コマンドを再実行します。

### バッチファイルから起動する場合

`LogVolume.bat` をダブルクリックして起動できます。バッチファイルはPowerShellを直接起動します。

エラーを確認しやすいため、開発中はPowerShellターミナルから直接起動することを推奨します。

## ファイル構成

```text
LogVolume/
├── LogVolume.ps1   # メインスクリプト（WinForms UI / Windows Core Audio）
├── LogVolume.bat   # PowerShellを直接起動するランチャー
├── README.md
└── screenshot.png
```

## ライセンス

本プロジェクトはMIT Licenseのもとで公開されています。
