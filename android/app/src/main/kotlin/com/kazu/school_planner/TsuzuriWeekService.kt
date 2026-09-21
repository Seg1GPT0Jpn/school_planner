package com.kazu.school_planner

import android.content.Intent
import android.widget.RemoteViewsService

/// ［週］ビューのマス（7個）
class TsuzuriWeekService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        TsuzuriGridFactory(applicationContext, "wk_cells")
}