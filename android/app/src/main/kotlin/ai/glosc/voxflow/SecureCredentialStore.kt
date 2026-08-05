package ai.glosc.voxflow

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.nio.ByteBuffer
import java.nio.charset.StandardCharsets
import java.security.GeneralSecurityException
import java.security.KeyStore
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Stores the API key encrypted by a non-exportable Android Keystore key. */
internal class SecureCredentialStore(context: Context) {
    private val preferences = context.applicationContext.getSharedPreferences(
        PREFERENCES_NAME,
        Context.MODE_PRIVATE,
    )

    fun readApiKey(): String? {
        val encodedEnvelope = try {
            preferences.getString(ENCRYPTED_API_KEY_ENTRY, null)
        } catch (_: ClassCastException) {
            throw corruptedStorage()
        } ?: return null

        val envelope = try {
            parseEnvelope(Base64.decode(encodedEnvelope, Base64.NO_WRAP))
        } catch (_: IllegalArgumentException) {
            throw corruptedStorage()
        }

        val secretKey = loadExistingKey() ?: throw corruptedStorage()
        val plaintext = try {
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(
                Cipher.DECRYPT_MODE,
                secretKey,
                GCMParameterSpec(GCM_TAG_LENGTH_BITS, envelope.initializationVector),
            )
            cipher.updateAAD(ASSOCIATED_DATA)
            cipher.doFinal(envelope.ciphertext)
        } catch (_: AEADBadTagException) {
            throw corruptedStorage()
        } catch (_: GeneralSecurityException) {
            throw unavailableStorage()
        }

        return try {
            if (plaintext.isEmpty() || plaintext.size > MAX_API_KEY_BYTES) {
                throw corruptedStorage()
            }
            String(plaintext, StandardCharsets.UTF_8)
        } finally {
            plaintext.fill(0)
        }
    }

    fun writeApiKey(value: String) {
        val plaintext = value.toByteArray(StandardCharsets.UTF_8)
        try {
            if (plaintext.isEmpty() || plaintext.size > MAX_API_KEY_BYTES) {
                throw invalidArgument()
            }

            val envelope = try {
                val cipher = Cipher.getInstance(TRANSFORMATION)
                cipher.init(Cipher.ENCRYPT_MODE, loadOrCreateKey())
                cipher.updateAAD(ASSOCIATED_DATA)
                encodeEnvelope(cipher.iv, cipher.doFinal(plaintext))
            } catch (error: SecureCredentialStoreException) {
                throw error
            } catch (_: GeneralSecurityException) {
                throw unavailableStorage()
            }

            val committed = preferences.edit()
                .putString(
                    ENCRYPTED_API_KEY_ENTRY,
                    Base64.encodeToString(envelope, Base64.NO_WRAP),
                )
                .commit()
            if (!committed) {
                throw unavailableStorage()
            }
        } finally {
            plaintext.fill(0)
        }
    }

    fun deleteApiKey() {
        // Remove the ciphertext first. If deleting the key later fails, retrying
        // remains safe and never leaves undecryptable ciphertext behind.
        if (!preferences.edit().remove(ENCRYPTED_API_KEY_ENTRY).commit()) {
            throw unavailableStorage()
        }

        try {
            val keyStore = loadKeyStore()
            if (keyStore.containsAlias(KEY_ALIAS)) {
                keyStore.deleteEntry(KEY_ALIAS)
            }
        } catch (_: GeneralSecurityException) {
            throw unavailableStorage()
        }
    }

    private fun loadOrCreateKey(): SecretKey {
        loadExistingKey()?.let { return it }
        return try {
            val generator = KeyGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_AES,
                ANDROID_KEY_STORE,
            )
            generator.init(
                KeyGenParameterSpec.Builder(
                    KEY_ALIAS,
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                )
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(AES_KEY_SIZE_BITS)
                    .setRandomizedEncryptionRequired(true)
                    .setUserAuthenticationRequired(false)
                    .build(),
            )
            generator.generateKey()
        } catch (_: GeneralSecurityException) {
            throw unavailableStorage()
        }
    }

    private fun loadExistingKey(): SecretKey? {
        return try {
            loadKeyStore().getKey(KEY_ALIAS, null) as? SecretKey
        } catch (_: GeneralSecurityException) {
            throw unavailableStorage()
        }
    }

    private fun loadKeyStore(): KeyStore {
        return KeyStore.getInstance(ANDROID_KEY_STORE).apply { load(null) }
    }

    private fun encodeEnvelope(
        initializationVector: ByteArray,
        ciphertext: ByteArray,
    ): ByteArray {
        if (initializationVector.size !in MIN_IV_BYTES..MAX_IV_BYTES ||
            ciphertext.size < GCM_TAG_LENGTH_BYTES
        ) {
            throw unavailableStorage()
        }
        return ByteBuffer.allocate(
            ENVELOPE_HEADER_BYTES + initializationVector.size + ciphertext.size,
        )
            .put(ENVELOPE_VERSION)
            .put(initializationVector.size.toByte())
            .putInt(ciphertext.size)
            .put(initializationVector)
            .put(ciphertext)
            .array()
    }

    private fun parseEnvelope(bytes: ByteArray): EncryptedEnvelope {
        if (bytes.size < ENVELOPE_HEADER_BYTES + MIN_IV_BYTES + GCM_TAG_LENGTH_BYTES ||
            bytes.size > MAX_ENVELOPE_BYTES
        ) {
            throw corruptedStorage()
        }

        val buffer = ByteBuffer.wrap(bytes)
        val version = buffer.get()
        val initializationVectorSize = buffer.get().toInt() and 0xff
        val ciphertextSize = buffer.int
        if (version != ENVELOPE_VERSION ||
            initializationVectorSize !in MIN_IV_BYTES..MAX_IV_BYTES ||
            ciphertextSize < GCM_TAG_LENGTH_BYTES ||
            buffer.remaining() != initializationVectorSize + ciphertextSize
        ) {
            throw corruptedStorage()
        }

        val initializationVector = ByteArray(initializationVectorSize)
        val ciphertext = ByteArray(ciphertextSize)
        buffer.get(initializationVector)
        buffer.get(ciphertext)
        return EncryptedEnvelope(initializationVector, ciphertext)
    }

    private data class EncryptedEnvelope(
        val initializationVector: ByteArray,
        val ciphertext: ByteArray,
    )

    private companion object {
        const val ANDROID_KEY_STORE = "AndroidKeyStore"
        const val KEY_ALIAS = "ai.glosc.voxflow.api_key.v1"
        const val PREFERENCES_NAME = "voxflow_secure_credentials"
        const val ENCRYPTED_API_KEY_ENTRY = "api_key_v1"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
        const val AES_KEY_SIZE_BITS = 256
        const val GCM_TAG_LENGTH_BITS = 128
        const val GCM_TAG_LENGTH_BYTES = GCM_TAG_LENGTH_BITS / 8
        const val MIN_IV_BYTES = 12
        const val MAX_IV_BYTES = 32
        const val MAX_API_KEY_BYTES = 64 * 1024
        const val MAX_ENVELOPE_BYTES = MAX_API_KEY_BYTES + 1024
        const val ENVELOPE_HEADER_BYTES = 6
        const val ENVELOPE_VERSION: Byte = 1
        val ASSOCIATED_DATA =
            "ai.glosc.voxflow/api-key/v1".toByteArray(StandardCharsets.UTF_8)
    }
}

internal class SecureCredentialStoreException(
    val errorCode: String,
    val publicMessage: String,
) : RuntimeException()

private fun invalidArgument() = SecureCredentialStoreException(
    errorCode = "invalid_argument",
    publicMessage = "The API key is invalid.",
)

private fun unavailableStorage() = SecureCredentialStoreException(
    errorCode = "secure_storage_unavailable",
    publicMessage = "Secure credential storage is unavailable.",
)

private fun corruptedStorage() = SecureCredentialStoreException(
    errorCode = "secure_storage_corrupt",
    publicMessage = "Secure credential storage is corrupted.",
)
