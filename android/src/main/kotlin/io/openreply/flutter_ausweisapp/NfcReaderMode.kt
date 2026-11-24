package io.openreply.flutter_ausweisapp

import android.app.Activity
import android.app.Application
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.IsoDep
import android.os.Bundle
import android.os.Handler
import android.os.Looper

/**
 * Switches NFC reader mode of the attached Activity and forwards IsoDep tags.
 *
 * Reader mode is on exactly while [sdkRunning] holds and the Activity is
 * resumed. Without an NFC adapter it stays off. Every member must be called on
 * the main thread; [onTag] runs on the main thread.
 */
internal class NfcReaderMode(private val onTag: (Tag) -> Unit) {
    private val mainHandler = Handler(Looper.getMainLooper())

    private var activity: Activity? = null
    private var adapter: NfcAdapter? = null
    private var resumed = false
    private var enabled = false

    /** Whether the SDK has a session; set by the plugin. */
    var sdkRunning: Boolean = false
        set(value) {
            field = value
            update()
        }

    // Called by NFC on a binder thread.
    private val readerCallback = NfcAdapter.ReaderCallback { tag ->
        if (tag.techList.contains(IsoDep::class.java.name)) {
            mainHandler.post { onTag(tag) }
        }
    }

    private val lifecycleCallbacks = object : Application.ActivityLifecycleCallbacks {
        override fun onActivityResumed(activity: Activity) {
            if (activity !== this@NfcReaderMode.activity) return
            resumed = true
            update()
        }

        override fun onActivityPaused(activity: Activity) {
            if (activity !== this@NfcReaderMode.activity) return
            resumed = false
            update()
        }

        override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit

        override fun onActivityStarted(activity: Activity) = Unit

        override fun onActivityStopped(activity: Activity) = Unit

        override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit

        override fun onActivityDestroyed(activity: Activity) = Unit
    }

    /**
     * Follows [activity] from now on. Flutter attaches plugins while the
     * Activity is created, so reader mode waits for its next resume.
     */
    fun attach(activity: Activity) {
        detach()
        this.activity = activity
        adapter = NfcAdapter.getDefaultAdapter(activity)
        activity.application.registerActivityLifecycleCallbacks(lifecycleCallbacks)
    }

    /** Switches reader mode off and stops following the Activity. */
    fun detach() {
        val current = activity ?: return
        resumed = false
        update()
        current.application.unregisterActivityLifecycleCallbacks(lifecycleCallbacks)
        activity = null
        adapter = null
    }

    private fun update() {
        val activity = activity ?: return
        val adapter = adapter ?: return
        val wanted = sdkRunning && resumed
        if (wanted == enabled) return
        // Recorded only after the call succeeded, so that a failed enable is
        // tried again on the next change.
        enabled = try {
            if (wanted) {
                adapter.enableReaderMode(activity, readerCallback, READER_FLAGS, null)
            } else {
                adapter.disableReaderMode(activity)
            }
            wanted
        } catch (e: IllegalStateException) {
            // The Activity is already destroyed; NFC dropped its reader mode.
            false
        }
    }

    private companion object {
        const val READER_FLAGS = NfcAdapter.FLAG_READER_NFC_A or
            NfcAdapter.FLAG_READER_NFC_B or
            NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK
    }
}
