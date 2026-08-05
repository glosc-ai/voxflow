package ai.glosc.voxflow

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

internal class ExternalLinkHandler(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val channel = MethodChannel(messenger, CHANNEL_NAME).also {
        it.setMethodCallHandler(::handleMethodCall)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != OPEN_METHOD) {
            result.notImplemented()
            return
        }

        val url = call.argument<String>("url")
        val uri = url?.let(Uri::parse)
        if (!isAllowed(url, uri)) {
            result.error(
                "invalid_url",
                "Only valid HTTPS links can be opened.",
                null,
            )
            return
        }

        try {
            val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                addCategory(Intent.CATEGORY_BROWSABLE)
            }
            activity.startActivity(intent)
            result.success(null)
        } catch (_: ActivityNotFoundException) {
            sendUnavailable(result)
        } catch (_: SecurityException) {
            sendUnavailable(result)
        } catch (_: Exception) {
            sendUnavailable(result)
        }
    }

    private fun isAllowed(url: String?, uri: Uri?): Boolean {
        if (url != ALLOWED_URL || uri == null) {
            return false
        }
        return uri.isHierarchical &&
            uri.scheme == "https" &&
            uri.host == "www.glosc.ai" &&
            uri.path == "/keys" &&
            uri.query == null &&
            uri.fragment == null &&
            uri.userInfo == null &&
            uri.port == -1
    }

    private fun sendUnavailable(result: MethodChannel.Result) {
        result.error(
            "cannot_open_url",
            "The system browser could not open this link.",
            null,
        )
    }

    private companion object {
        const val CHANNEL_NAME = "ai.glosc.voxflow/external_links/v1"
        const val OPEN_METHOD = "open"
        const val ALLOWED_URL = "https://www.glosc.ai/keys"
    }
}
