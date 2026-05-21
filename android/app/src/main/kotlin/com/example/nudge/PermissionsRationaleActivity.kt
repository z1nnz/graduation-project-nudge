package com.example.nudge

import android.app.Activity
import android.os.Bundle
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

class PermissionsRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val density = resources.displayMetrics.density
        fun dp(value: Int): Int = (value * density).toInt()

        val container = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(28), dp(24), dp(28))
        }

        val title = TextView(this).apply {
            text = "Nudge 健康資料用途"
            textSize = 24f
            gravity = Gravity.START
            setPadding(0, 0, 0, dp(16))
        }

        val body = TextView(this).apply {
            text = """
                Nudge 會在你授權後讀取 Health Connect 中的睡眠、步數與運動紀錄。

                這些資料只會用來：
                • 判定健康類自動追蹤任務是否完成
                • 更新今日健康總覽與自律分數
                • 同步自律房中與健康相關的目標進度

                你可以隨時在系統的 Health Connect 設定中取消授權。
            """.trimIndent()
            textSize = 16f
            setLineSpacing(dp(4).toFloat(), 1.0f)
        }

        container.addView(title)
        container.addView(body)

        val scrollView = ScrollView(this).apply {
            addView(container)
        }

        setContentView(scrollView)
    }
}
