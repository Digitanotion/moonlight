package com.app.moonlightstream

import android.view.LayoutInflater
import android.view.View
import android.widget.Button
import android.widget.ImageView
import android.widget.TextView
import com.google.android.gms.ads.nativead.MediaView
import com.google.android.gms.ads.nativead.NativeAd
import com.google.android.gms.ads.nativead.NativeAdView
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin

/**
 * Renders an AdMob native ad as a full page in the short-video feed, the
 * same size as the videos around it (see native_reel_ad.xml).
 */
class NativeReelAdFactory(private val inflater: LayoutInflater) :
    GoogleMobileAdsPlugin.NativeAdFactory {

    override fun createNativeAd(
        nativeAd: NativeAd,
        customOptions: MutableMap<String, Any>?
    ): NativeAdView {
        val view = inflater.inflate(R.layout.native_reel_ad, null) as NativeAdView

        val media = view.findViewById<MediaView>(R.id.reel_ad_media)
        media.setImageScaleType(ImageView.ScaleType.FIT_CENTER)
        nativeAd.mediaContent?.let { media.mediaContent = it }
        view.mediaView = media

        val headline = view.findViewById<TextView>(R.id.reel_ad_headline)
        headline.text = nativeAd.headline
        view.headlineView = headline

        val advertiser = view.findViewById<TextView>(R.id.reel_ad_advertiser)
        advertiser.text = nativeAd.advertiser ?: nativeAd.store ?: ""
        advertiser.visibility = if (advertiser.text.isNullOrEmpty()) View.GONE else View.VISIBLE
        view.advertiserView = advertiser

        val body = view.findViewById<TextView>(R.id.reel_ad_body)
        body.text = nativeAd.body ?: ""
        body.visibility = if (nativeAd.body.isNullOrEmpty()) View.GONE else View.VISIBLE
        view.bodyView = body

        val icon = view.findViewById<ImageView>(R.id.reel_ad_icon)
        val drawable = nativeAd.icon?.drawable
        if (drawable != null) {
            icon.setImageDrawable(drawable)
            icon.visibility = View.VISIBLE
        } else {
            icon.visibility = View.GONE
        }
        view.iconView = icon

        val cta = view.findViewById<Button>(R.id.reel_ad_cta)
        cta.text = nativeAd.callToAction ?: "Learn more"
        view.callToActionView = cta

        view.setNativeAd(nativeAd)
        return view
    }
}
