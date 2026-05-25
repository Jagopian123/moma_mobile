package com.pikode.moma

import android.view.LayoutInflater
import android.view.View
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

class NativeAdFactoryImpl(private val layoutInflater: LayoutInflater) :
    GoogleMobileAdsPlugin.NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?,
    ): NativeAdView {
        val adView = layoutInflater.inflate(
            R.layout.native_ad_view, null
        ) as NativeAdView

        val headlineView = adView.findViewById<TextView>(R.id.ad_headline)
        val bodyView     = adView.findViewById<TextView>(R.id.ad_body)
        val iconView     = adView.findViewById<ImageView>(R.id.ad_icon)
        val ctaView      = adView.findViewById<TextView>(R.id.ad_call_to_action)

        headlineView.text = nativeAd.headline
        adView.headlineView = headlineView

        bodyView.text = nativeAd.body
        bodyView.visibility = if (nativeAd.body != null) View.VISIBLE else View.GONE
        adView.bodyView = bodyView

        val icon = nativeAd.icon
        if (icon != null) {
            iconView.setImageDrawable(icon.drawable)
            iconView.visibility = View.VISIBLE
        } else {
            iconView.visibility = View.GONE
        }
        adView.iconView = iconView

        ctaView.text = nativeAd.callToAction
        ctaView.visibility = if (nativeAd.callToAction != null) View.VISIBLE else View.GONE
        adView.callToActionView = ctaView

        adView.setNativeAd(nativeAd)
        return adView
    }
}
