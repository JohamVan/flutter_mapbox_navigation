package com.eopeter.flutter_mapbox_navigation.factory

import android.app.Activity
import android.content.Context
import android.util.Log
import com.eopeter.flutter_mapbox_navigation.utilities.PluginUtilities
import com.eopeter.flutter_mapbox_navigation.views.EmbeddedNavigationMapView
import eopeter.flutter_mapbox_navigation.R
import eopeter.flutter_mapbox_navigation.databinding.NavigationActivityBinding

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import timber.log.Timber

class EmbeddedNavigationViewFactory(private val messenger: BinaryMessenger, private val activity: Activity) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context?, viewId: Int, args: Any?): PlatformView {
        Log.d("EmbeddedNavigation", "viewId: " + viewId)
        val binding = NavigationActivityBinding.inflate(this.activity.layoutInflater)
        val accessToken = PluginUtilities.getResourceFromContext( context!!,"mapbox_access_token")
        val view = EmbeddedNavigationMapView(context!!, activity, binding, messenger, 0, args, accessToken)
        activity.setTheme(R.style.Theme_AppCompat_NoActionBar)
        return view
    }
}