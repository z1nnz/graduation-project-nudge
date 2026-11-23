# Nudge development environment check (Windows PowerShell 5.1+).
# Usage: powershell -ExecutionPolicy Bypass -File tool\doctor.ps1
# Reports every tool the six CI gates and the firmware tests need, with the
# version CI uses. It never installs or changes anything.

$ErrorActionPreference = 'Continue'
$failures = 0

function Check($name, $command, $versionArgs, $pattern, $hint) {
  $cmd = Get-Command $command -ErrorAction SilentlyContinue
  if (-not $cmd) {
    Write-Host ("[缺少] {0,-14} {1}" -f $name, $hint) -ForegroundColor Red
    $script:failures++
    return
  }
  $out = (& $command @versionArgs 2>&1 | Out-String).Trim()
  $line = ($out -split "`n")[0].Trim()
  if ($pattern -and $out -notmatch $pattern) {
    Write-Host ("[版本] {0,-14} {1}  -> 需要 {2}。{3}" -f $name, $line, $pattern, $hint) -ForegroundColor Yellow
    $script:failures++
  } else {
    Write-Host ("[ OK ] {0,-14} {1}" -f $name, $line) -ForegroundColor Green
  }
}

Check 'Git'        git     @('--version')           ''                 'https://git-scm.com/'
Check 'Flutter'    flutter @('--version')           '3\.41\.7'         'CI 使用 Flutter 3.41.7'
Check 'Node.js'    node    @('--version')           '^v22\.'           'CI 使用 Node 22'
Check 'Java'       java    @('-version')            'version "21'      'Rules emulator 與 Android 需要 JDK 21（JAVA_HOME 也要指向它）'
Check 'Firebase'   firebase @('--version')          '^15\.'           'CI 釘選 15.18.0：npm install --global firebase-tools@15.18.0'
Check 'python3'    python3 @('--version')           '3\.1[0-9]'        '比賽工具以 python3 呼叫；Windows 可複製 python.exe 為 python3.exe'
Check 'C++'        g++     @('--version')           ''                 'MSYS2: pacman -S mingw-w64-ucrt-x86_64-gcc，並把 msys64\ucrt64\bin 加到 PATH'
Check 'make'       make    @('--version')           ''                 'MSYS2: pacman -S make，並把 msys64\usr\bin 加到 PATH 尾端'
Check 'PlatformIO' pio     @('--version')           ''                 'pip install platformio（韌體建置）'
Check 'gh'         gh      @('--version')           ''                 'https://cli.github.com/ ，再執行 gh auth login'

if ($env:PYTHONUTF8 -ne '1') {
  Write-Host '[設定] PYTHONUTF8     未設為 1；Windows 中文系統會以 Big5 讀取 UTF-8 檔案。setx PYTHONUTF8 1' -ForegroundColor Yellow
  $failures++
} else {
  Write-Host '[ OK ] PYTHONUTF8     1' -ForegroundColor Green
}

$autocrlf = (git config --get core.autocrlf) 2>$null
if ($autocrlf -eq 'true') {
  Write-Host '[提示] core.autocrlf  true；本 repo 的 .gitattributes 已固定 LF。舊的 checkout 請先 commit 或 stash 自己的修改，再執行一次：git rm --cached -r -q . ; git reset --hard' -ForegroundColor Cyan
}

if ($failures -eq 0) {
  Write-Host "`n環境齊全，可以跑完整六項 gate 與韌體原生測試。" -ForegroundColor Green
} else {
  Write-Host "`n共有 $failures 項需要處理（見上方）。" -ForegroundColor Red
  exit 1
}
