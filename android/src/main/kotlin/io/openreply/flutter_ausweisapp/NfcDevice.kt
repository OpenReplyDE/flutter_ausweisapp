package io.openreply.flutter_ausweisapp

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.nfc.NfcAdapter
import android.provider.Settings

/**
 * The NFC state of the device and the way to its NFC settings. Independent of
 * the SDK: nothing here needs a bound service or a session.
 */
internal object NfcDevice {
    const val UNSUPPORTED = "unsupported"
    const val DISABLED = "disabled"
    const val AVAILABLE = "available"

    /**
     * [UNSUPPORTED] without an NFC adapter, [DISABLED] while NFC is switched
     * off, else [AVAILABLE]. Needs no Activity; [context] may be the
     * application context.
     */
    fun status(context: Context): String {
        val adapter = NfcAdapter.getDefaultAdapter(context) ?: return UNSUPPORTED
        return if (adapter.isEnabled) AVAILABLE else DISABLED
    }

    /**
     * Opens the NFC settings of the system. Returns false if the device has no
     * such screen. Without an [activity] the settings open as a new task from
     * [context].
     */
    fun openSettings(context: Context, activity: Activity?): Boolean {
        val intent = Intent(Settings.ACTION_NFC_SETTINGS)
        return try {
            if (activity != null) {
                activity.startActivity(intent)
            } else {
                context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }
            true
        } catch (e: ActivityNotFoundException) {
            false
        }
    }
}
