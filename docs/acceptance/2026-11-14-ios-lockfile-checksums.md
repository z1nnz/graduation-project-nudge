# iOS lockfile 校驗失敗：上游 deprecation metadata

2026-11-14（Asia/Taipei）。範圍：修復 `iOS dependency lock`，保留 CocoaPods 1.16.2
與 `pod install --deployment`。不修改 Podfile、套件版本或 CI gate。

## 原因與證據

[PR #19 的失敗 job](https://github.com/z1nnz/graduation-project-nudge/actions/runs/43550906468/job/132312877532)
及 [PR #20 的失敗 job](https://github.com/z1nnz/graduation-project-nudge/actions/runs/43551301346/job/132314122159)
都在 deployment mode 回報三筆 SPEC CHECKSUMS 不符，沒有版本解析差異。

CocoaPods 官方 Specs 在 2026-11-10 UTC 為這三個已發布版本加入
`"deprecated": true`。逐欄解析 JSON 比對，唯一變更就是該欄位；`source`、tag、
依賴與其他欄位皆相同。舊 podspec 原始檔 SHA-1 完全對應 main 的舊 checksum，
deprecation commit 的原始檔 SHA-1 完全對應 CI 回報的新 checksum。

| Pod／鎖定版本 | 原始發布 commit | 加入 deprecation 的 commit |
| --- | --- | --- |
| AppAuth 2.1.0 | [24a4403](https://github.com/CocoaPods/Specs/commit/24a4403f24ffbed639434ceed6f18b7093d7a4dd) | [8f48a33](https://github.com/CocoaPods/Specs/commit/8f48a332201cea6c31eeeeda4f148deaada2b548) |
| GoogleSignIn 9.2.0 | [8d57526](https://github.com/CocoaPods/Specs/commit/8d5752648e0221faac14eafe0893a6953c15ee76) | [ea21120](https://github.com/CocoaPods/Specs/commit/ea21120381a0554288dc27af584761eab5ec23df) |
| GTMAppAuth 5.0.0 | [1e39bcb](https://github.com/CocoaPods/Specs/commit/1e39bcb354f29a88908b241fd1c9cab123e49015) | [fd8ca83](https://github.com/CocoaPods/Specs/commit/fd8ca834492e570dddaffabba6a5a1c12b5e92c3) |

這解釋了舊 CI 成功、11/14 文件 PR 失敗的原因。依
[CocoaPods Core 1.16.2 的 checksum 實作](https://github.com/CocoaPods/Core/blob/1.16.2/lib/cocoapods-core/specification.rb#L685)，
校驗碼計算涵蓋整份 podspec 原始檔，因此 metadata 變更也會觸發嚴格檢查。

## 修復與驗證

只更新 `ios/Podfile.lock` 中 AppAuth、GoogleSignIn、GTMAppAuth 的三筆
SPEC CHECKSUMS。版本、PODS、DEPENDENCIES、SPEC REPOS、EXTERNAL SOURCES、
PODFILE CHECKSUM、CocoaPods 版本與其餘 checksum 均保持相同。

本次以歷史／deprecation commit 的官方原始檔，重新計算三組 SHA-1 並確認 JSON
只有 `deprecated` 差異；去除三筆預期 checksum 修改後，lockfile 與 main 位元組相同。
沒有刪除 lockfile、執行 `pod update` 或放寬 deployment 驗證。

本機 Flutter 3.47.8 與 CI 鎖定的 3.41.7 不同，`flutter pub get --enforce-lockfile`
因四個 SDK 相依差異停止，未修改 pubspec.lock；正式回歸結果以 PR 最新 commit 的
六項 GitHub Actions 為準，其中 iOS job 使用原有命令：

```sh
flutter pub get
sudo gem install cocoapods -v 1.16.2 --no-document
pod _1.16.2_ install --deployment --project-directory=ios
```

上游 deprecation 標記仍會顯示；本次不更換登入套件或遷移套件管理方式。
回復方式為 revert 本次三筆 checksum 更新；在目前 Specs metadata 下將再次觸發同一錯誤。
