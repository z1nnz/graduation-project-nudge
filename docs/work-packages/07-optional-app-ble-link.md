# 07｜App／BLE 選配連動工作包

## 優先級

P2。只有兩台 P0-B、視覺一致與 10 次自動重播都完成後才開始。BLE 失敗不得影響
裝置離線 Demo，也不得讓硬體組員先去完成整套 Cloud。

## 最小有價值的連動

只做 App → 裝置的展示控制：

- 掃描並辨認 `Nudge Orbit Demo` 或 `Nudge Station Demo`。
- 連線。
- 傳送 `next`。
- 傳送 `restart`。
- 可選傳送 `startFocus`。

這已足以讓教授看見 App 可以觸發實體畫面。不要為競賽 Demo 加入帳號轉移、
正式 DeviceAssignment、Cloud Receipt、OTA 或完整同步衝突。

## Demo 協定

若沿用現有 BLE service，新增清楚的 Demo command，並在韌體只於
`NUDGE_DEMO=1` 接受：

```json
{"v":1,"type":"demo","action":"next"}
```

```json
{"v":1,"type":"demo","action":"restart"}
```

```json
{"v":1,"type":"demo","action":"startFocus"}
```

裝置回報：

```json
{"v":1,"mode":"demo","device":"orbit","scene":"focus","index":3}
```

資料不得包含真實使用者、家庭、群組或健康紀錄。

## App 最小畫面

- 兩張裝置卡：Orbit、Station。
- 狀態：未連線／連線中／已連線。
- 三個按鈕：Next、Start Focus、Restart。
- 明顯標題：`Prototype Demo Controller`。
- 連線失敗時顯示「改用裝置自動展示」，不要卡住。

## 一次只連一台

競賽前的最安全方案是 App 一次控制一台。雙連線與跨裝置同步容易引入更多
手機／BLE 差異；只有單台已穩定後才嘗試雙連線。

## 驗收

- [ ] 真實手機能掃描到指定 Demo 名稱。
- [ ] 連線後 Next 連續 10 次，沒有跳兩幕。
- [ ] Restart 連續 5 次。
- [ ] 手機關閉藍牙後，裝置繼續自動 Demo。
- [ ] App 關閉後，裝置不黑屏、不停住。
- [ ] 影片同時拍到 App 按鍵與裝置畫面改變。

## 停止條件

遇到下列任一情況立即停止 P2，回到 P0-A／P0-B 排練：

- 需要改動現有 Cloud security model。
- 需要真實帳號或 Firebase 才能顯示。
- BLE 造成裝置重啟或畫面卡頓。
- 連線在不同手機上無法重現。
- 距離比賽少於 3 天且尚未連續成功 10 次。

## 沒完成時的說法

> 本次實機展示先驗證兩種裝置的互動與畫面；App／BLE 是下一階段整合，不把網路
> 或手機穩定性綁成原型展示的單點故障。

這是正確的原型範圍，不需要假裝已同步。
