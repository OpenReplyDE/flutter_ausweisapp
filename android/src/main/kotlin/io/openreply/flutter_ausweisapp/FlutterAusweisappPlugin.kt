package io.openreply.flutter_ausweisapp

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Moves JSON strings between Dart and the AusweisApp SDK and switches NFC
 * reader mode for the foreground Activity.
 *
 * Flutter calls every handler here on the main thread; [SdkConnection] and
 * [NfcReaderMode] report on the main thread, so the event sink and method
 * results are only ever used there.
 */
class FlutterAusweisappPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var sdk: SdkConnection
    private var eventSink: EventChannel.EventSink? = null
    private val readerMode = NfcReaderMode(onTag = { tag -> sdk.updateNfcTag(tag) })

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        sdk = SdkConnection(
            binding.applicationContext,
            onMessage = { json -> eventSink?.success(mapOf("type" to "message", "json" to json)) },
            onDisconnected = {
                readerMode.sdkRunning = false
                eventSink?.success(mapOf("type" to "disconnected"))
            },
        )
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        eventSink = null
        sdk.stop()
        readerMode.sdkRunning = false
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> sdk.start { outcome ->
                outcome.fold(
                    onSuccess = {
                        readerMode.sdkRunning = true
                        result.success(null)
                    },
                    onFailure = { reportFailure(result, it) },
                )
            }
            "stop" -> {
                sdk.stop()
                readerMode.sdkRunning = false
                result.success(null)
            }
            "send" -> {
                val json = call.arguments as? String
                if (json == null) {
                    result.error(SdkConnection.SEND_FAILED, "The command must be a string.", null)
                    return
                }
                try {
                    sdk.send(json)
                    result.success(null)
                } catch (e: SdkException) {
                    reportFailure(result, e)
                }
            }
            "isRunning" -> result.success(sdk.isRunning)
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        // A second listen (hot restart) replaces the sink; the SDK keeps running.
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        readerMode.attach(binding.activity)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        readerMode.detach()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        readerMode.attach(binding.activity)
    }

    override fun onDetachedFromActivity() {
        readerMode.detach()
    }

    private fun reportFailure(result: MethodChannel.Result, failure: Throwable) {
        if (failure is SdkException) {
            result.error(failure.code, failure.message, null)
        } else {
            result.error(SdkConnection.START_FAILED, "The AusweisApp SDK could not be started.", null)
        }
    }

    private companion object {
        const val METHOD_CHANNEL = "flutter_ausweisapp/methods"
        const val EVENT_CHANNEL = "flutter_ausweisapp/events"
    }
}
