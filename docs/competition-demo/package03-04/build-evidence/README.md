# 建置證據（尚未燒錄）

這些 binary 由 manifest 所列的乾淨 source commit 建置。後續 evidence commit 只增加本目錄，沒有改韌體專案。
可比較 source commit 與 PR head 的 `firmware/nudge_competition_demo` Git tree，應與 manifest.source_tree 相同。

- 五個 Orbit 輸出為 GC9A01／Seeed Round Display，詳細用途與命令見[韌體說明](../../../../firmware/nudge_competition_demo/README.md)。
- station_diagnostic_only.bin 只有序列診斷，不是 Station LCD 展示，不可作為方屏驗收。
- manifest.json 記錄 bytes、SHA-256、內嵌 build identity；physical_verified 全為 false。
- build-output.txt 完整保留六種編譯輸出，只將操作者本機路徑改成 `<operator-home>`。
- web-tests.txt 為本機 113 項 root Node 測試結果，其中新測試實際編譯執行 C++。
- binary 不能證明已 upload、面板正常或 10 圈成功；實機依使用者指示稍後驗收。
- binary 是各自的 application image，不能把 firmware.bin 單獨當完整 flash image 直接寫入 0x0。
  應從同一 source 使用 PlatformIO 的 upload 流程（處理 bootloader／partitions）與已核對的 USB port。
