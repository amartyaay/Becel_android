package com.becel.becel

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class PermissionsRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(28, 28, 28, 28)
            setBackgroundColor(Color.rgb(10, 15, 13))
        }
        val title = TextView(this).apply {
            text = "How Becel uses health data"
            textSize = 24f
            setTextColor(Color.rgb(242, 244, 236))
            setPadding(0, 0, 0, 18)
        }
        val body = TextView(this).apply {
            text =
                "Becel requests read-only access to steps, heart-rate samples, " +
                    "sleep sessions, and workouts so it can show them in your " +
                    "dashboard. Data is read from Health Connect on this device. " +
                    "This build does not upload your health data. You can change " +
                    "access at any time in Health Connect settings."
            textSize = 16f
            setTextColor(Color.rgb(190, 202, 194))
            setLineSpacing(4f, 1f)
        }
        val done = Button(this).apply {
            text = "Done"
            setOnClickListener { finish() }
        }

        root.addView(title)
        root.addView(body)
        root.addView(done)
        setContentView(root)
    }
}
