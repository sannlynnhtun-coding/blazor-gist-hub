package com.example.gist_hub_flutter

import android.content.Context
import android.content.Intent
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class PreviewFactory : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val web = WebView(context)
        web.settings.javaScriptEnabled = true
        web.settings.allowFileAccess = true
        web.settings.allowContentAccess = false
        web.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                if (request.isForMainFrame && request.url.scheme in listOf("https", "http")) {
                    try { context.startActivity(Intent(Intent.ACTION_VIEW, request.url).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }
                    catch (_: Exception) { }
                }
                return true
            }
        }
        web.loadDataWithBaseURL("file:///android_asset/flutter_assets/assets/preview/", args as String, "text/html", "UTF-8", null)
        return object : PlatformView {
            override fun getView() = web
            override fun dispose() { web.stopLoading(); web.destroy() }
        }
    }
}
