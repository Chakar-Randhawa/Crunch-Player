package com.craunch.player

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.craunch.player.equalizer.CraunchEqualizerPlugin
import com.craunch.player.overlay.CraunchOverlayPlugin
import com.craunch.player.pcm.PcmDecoderPlugin
import com.craunch.player.demux.DemuxPlugin
import com.craunch.player.ringtone.RingtonePlugin

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // All five plugins below are app-local native code (not
        // installable pub packages), so they're registered by hand here
        // rather than through GeneratedPluginRegistrant, which only knows
        // about actual Flutter plugin packages declared in pubspec.yaml.
        flutterEngine.plugins.add(CraunchEqualizerPlugin())
        flutterEngine.plugins.add(CraunchOverlayPlugin())
        flutterEngine.plugins.add(PcmDecoderPlugin())
        flutterEngine.plugins.add(DemuxPlugin())
        flutterEngine.plugins.add(RingtonePlugin())
    }
}
