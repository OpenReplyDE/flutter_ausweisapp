package io.openreply.flutter_ausweisapp

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.nfc.Tag
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.RemoteException
import com.governikus.ausweisapp2.IAusweisApp2Sdk
import com.governikus.ausweisapp2.IAusweisApp2SdkCallback

/** A failure with a channel error code and a fixed text that never contains a command. */
internal class SdkException(val code: String, override val message: String) : Exception(message)

/**
 * Binds the AusweisApp SDK service, holds its session and hands commands and
 * NFC tags to it.
 *
 * Every public member must be called on the main thread. Callbacks of the SDK
 * and of the service connection are moved to the main thread as well, so all
 * state lives on one thread. [onMessage] and [onDisconnected] run on the main
 * thread.
 */
internal class SdkConnection(
    private val context: Context,
    private val onMessage: (String) -> Unit,
    private val onDisconnected: () -> Unit,
) {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val pendingStarts = mutableListOf<(Result<Unit>) -> Unit>()

    /** The current binding; null while stopped. */
    private var binding: Binding? = null

    /**
     * The service of the last released binding. The SDK process exits once
     * its service is unbound. Android treats a bind during that exit as a
     * crashed service and restarts it only after a back-off of seconds, so the
     * next start waits for the exit first.
     */
    private var exitingService: IBinder? = null

    /** Set while a start waits for [exitingService] to exit. */
    private var exitWait: ExitWait? = null

    /** Whether a session is established, so commands can be sent. */
    val isRunning: Boolean
        get() = binding?.sessionId != null

    /**
     * Binds the service and opens a session. [onResult] is called once the
     * session id arrives or the start fails. Succeeds at once if a session is
     * already established; joins a start that is still pending.
     */
    fun start(onResult: (Result<Unit>) -> Unit) {
        val current = binding
        if (current?.sessionId != null) {
            onResult(Result.success(Unit))
            return
        }
        pendingStarts += onResult
        if (current != null || exitWait != null) return

        val exiting = exitingService
        exitingService = null
        if (exiting != null && waitForExit(exiting)) return
        bind()
    }

    /**
     * Unbinds the service and drops the session. A pending start fails with
     * `start_failed`. Does nothing if nothing is running.
     */
    fun stop() {
        exitWait?.let { wait ->
            cancelExitWait(wait)
            exitingService = wait.service
        }
        binding?.let(::release)
        finishStarts(failure(START_FAILED, "The start was cancelled by stop."))
    }

    /**
     * Hands [json] to the SDK. The char array is overwritten afterwards
     * because the command can hold a PIN, CAN or PUK.
     *
     * @throws SdkException `not_running` without a session, `send_failed` if
     *   the SDK does not take the command.
     */
    fun send(json: String) {
        val current = binding
        val sdk = current?.sdk
        val sessionId = current?.sessionId
        if (sdk == null || sessionId == null) {
            throw SdkException(NOT_RUNNING, "The AusweisApp SDK is not running.")
        }
        val chars = json.toCharArray()
        val sent = try {
            sdk.transmit(sessionId, chars)
        } catch (e: RemoteException) {
            false
        } finally {
            chars.fill('\u0000')
        }
        if (!sent) {
            throw SdkException(SEND_FAILED, "The command could not be handed to the AusweisApp SDK.")
        }
    }

    /** Hands a discovered NFC tag to the SDK. Ignored without a session. */
    fun updateNfcTag(tag: Tag) {
        val current = binding ?: return
        val sdk = current.sdk ?: return
        val sessionId = current.sessionId ?: return
        try {
            sdk.updateNfcTag(sessionId, tag)
        } catch (e: RemoteException) {
            // A dead service is reported through the service connection.
        }
    }

    private fun bind() {
        val next = Binding()
        binding = next
        val intent = Intent(START_SERVICE_ACTION).setPackage(context.packageName)
        val bound = try {
            context.bindService(intent, next, Context.BIND_AUTO_CREATE)
        } catch (e: SecurityException) {
            false
        }
        if (!bound) {
            release(next)
            finishStarts(failure(START_FAILED, "The AusweisApp SDK service could not be bound."))
        }
    }

    /** Returns false if [service] is already gone, so the bind can go ahead. */
    private fun waitForExit(service: IBinder): Boolean {
        val wait = ExitWait(service)
        try {
            service.linkToDeath(wait, 0)
        } catch (e: RemoteException) {
            return false
        }
        exitWait = wait
        mainHandler.postDelayed(wait, EXIT_TIMEOUT_MS)
        return true
    }

    private fun cancelExitWait(wait: ExitWait) {
        exitWait = null
        mainHandler.removeCallbacks(wait)
        try {
            wait.service.unlinkToDeath(wait, 0)
        } catch (e: NoSuchElementException) {
            // The link is already gone with the process.
        }
    }

    /** The old SDK process exited, or the wait timed out. */
    private fun handleExited(wait: ExitWait) {
        if (wait !== exitWait) return
        cancelExitWait(wait)
        if (pendingStarts.isNotEmpty()) bind()
    }

    private fun handleConnected(owner: Binding, service: IBinder?) {
        if (owner !== binding) return
        owner.service = service
        val sdk = IAusweisApp2Sdk.Stub.asInterface(service)
        val accepted = try {
            sdk?.connectSdk(owner.callback) == true
        } catch (e: RemoteException) {
            false
        }
        if (!accepted) {
            release(owner)
            finishStarts(failure(START_FAILED, "The AusweisApp SDK did not accept the session."))
            return
        }
        owner.sdk = sdk
    }

    private fun handleSessionId(owner: Binding, sessionId: String?) {
        if (owner !== binding) return
        if (sessionId.isNullOrEmpty()) {
            release(owner)
            finishStarts(failure(START_FAILED, "The AusweisApp SDK did not open a session."))
            return
        }
        owner.sessionId = sessionId
        finishStarts(Result.success(Unit))
    }

    private fun handleMessage(owner: Binding, json: String?) {
        if (owner !== binding || json == null) return
        onMessage(json)
    }

    /** The SDK dropped the session, its process died or the binding died. */
    private fun handleLost(owner: Binding) {
        if (owner !== binding) return
        release(owner)
        finishStarts(failure(START_FAILED, "The connection to the AusweisApp SDK was lost."))
        onDisconnected()
    }

    private fun release(owner: Binding) {
        if (binding === owner) binding = null
        exitingService = owner.service
        owner.service = null
        owner.sdk = null
        owner.sessionId = null
        try {
            context.unbindService(owner)
        } catch (e: IllegalArgumentException) {
            // Not bound (any more).
        }
    }

    private fun finishStarts(result: Result<Unit>) {
        val callbacks = pendingStarts.toList()
        pendingStarts.clear()
        callbacks.forEach { it(result) }
    }

    private fun failure(code: String, message: String): Result<Unit> =
        Result.failure(SdkException(code, message))

    /** Runs [handleExited] on the main thread once, on exit or on timeout. */
    private inner class ExitWait(val service: IBinder) : IBinder.DeathRecipient, Runnable {
        override fun binderDied() {
            mainHandler.post(this)
        }

        override fun run() {
            handleExited(this)
        }
    }

    /**
     * One bind of the service. Callbacks of an old binding are ignored, so a
     * late callback after stop() cannot touch a newer start.
     */
    private inner class Binding : ServiceConnection {
        var service: IBinder? = null
        var sdk: IAusweisApp2Sdk? = null
        var sessionId: String? = null

        val callback = object : IAusweisApp2SdkCallback.Stub() {
            override fun sessionIdGenerated(sessionId: String?) {
                mainHandler.post { handleSessionId(this@Binding, sessionId) }
            }

            override fun receive(json: String?) {
                mainHandler.post { handleMessage(this@Binding, json) }
            }

            override fun sdkDisconnected() {
                mainHandler.post { handleLost(this@Binding) }
            }
        }

        override fun onServiceConnected(name: ComponentName?, service: IBinder?) {
            mainHandler.post { handleConnected(this, service) }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            mainHandler.post { handleLost(this) }
        }

        override fun onBindingDied(name: ComponentName?) {
            mainHandler.post { handleLost(this) }
        }

        override fun onNullBinding(name: ComponentName?) {
            mainHandler.post { handleLost(this) }
        }
    }

    companion object {
        const val START_FAILED = "start_failed"
        const val NOT_RUNNING = "not_running"
        const val SEND_FAILED = "send_failed"

        private const val START_SERVICE_ACTION = "com.governikus.ausweisapp2.START_SERVICE"

        /** Upper bound for waiting on the old SDK process; it usually exits within 100 ms. */
        private const val EXIT_TIMEOUT_MS = 3_000L
    }
}
