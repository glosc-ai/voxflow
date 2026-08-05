package ai.glosc.voxflow

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var secureCredentialsChannel: MethodChannel? = null
    private var externalLinkHandler: ExternalLinkHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val credentialStore = SecureCredentialStore(applicationContext)
        secureCredentialsChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SECURE_CREDENTIALS_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "readApiKey" -> result.success(credentialStore.readApiKey())
                        "writeApiKey" -> {
                            val value = call.argument<String>("value")
                            if (value.isNullOrEmpty()) {
                                result.error(
                                    "invalid_argument",
                                    "The API key must be a non-empty string.",
                                    null,
                                )
                            } else {
                                credentialStore.writeApiKey(value)
                                result.success(null)
                            }
                        }
                        "deleteApiKey" -> {
                            credentialStore.deleteApiKey()
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (error: SecureCredentialStoreException) {
                    result.error(error.errorCode, error.publicMessage, null)
                } catch (_: Exception) {
                    result.error(
                        "secure_storage_unavailable",
                        "Secure credential storage is unavailable.",
                        null,
                    )
                }
            }
        }
        externalLinkHandler = ExternalLinkHandler(
            this,
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        externalLinkHandler?.dispose()
        externalLinkHandler = null
        secureCredentialsChannel?.setMethodCallHandler(null)
        secureCredentialsChannel = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private companion object {
        const val SECURE_CREDENTIALS_CHANNEL =
            "ai.glosc.voxflow/secure_credentials/v1"
    }
}
