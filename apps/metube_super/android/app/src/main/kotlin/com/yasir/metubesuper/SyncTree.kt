package com.yasir.metubesuper

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.DocumentsContract
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * A folder the user chose through the system picker, read and written by
 * path inside it. Android 11+ hides files other apps made in shared
 * storage, and the sync program is another app, so the folder is reached
 * through the Storage Access Framework with a permission kept across
 * restarts, never through a file path.
 */
class SyncTree(private val activity: Activity) {
    companion object {
        const val CHANNEL = "mtf/sync_tree"
        const val PICK = 4701
    }

    private var pending: MethodChannel.Result? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            val tree = call.argument<String>("tree")?.let(Uri::parse)
            val path = call.argument<List<String>>("path") ?: emptyList()
            try {
                when (call.method) {
                    "pick" -> pick(result)
                    "granted" -> result.success(tree != null && granted(tree))
                    "persisted" -> result.success(
                        activity.contentResolver.persistedUriPermissions
                            .filter { it.isReadPermission && it.isWritePermission }
                            .map { it.uri.toString() },
                    )
                    "list" -> background(result) { list(tree!!, path) }
                    "read" -> background(result) { read(tree!!, path) }
                    "write" -> background(result) {
                        write(tree!!, path, call.argument<String>("text")!!)
                    }
                    "delete" -> background(result) { delete(tree!!, path) }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("sync_tree", e.message, null)
            }
        }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        Thread {
            try {
                val value = work()
                activity.runOnUiThread { result.success(value) }
            } catch (e: Exception) {
                activity.runOnUiThread { result.error("sync_tree", e.message, null) }
            }
        }.start()
    }

    private fun pick(result: MethodChannel.Result) {
        pending = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        activity.startActivityForResult(intent, PICK)
    }

    /** Called from the activity; true when it was this picker's answer. */
    fun onResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK) return false
        val result = pending ?: return true
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        // Kept across restarts: without this the grant ends with the process.
        activity.contentResolver.takePersistableUriPermission(
            uri,
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
        )
        result.success(uri.toString())
        return true
    }

    private fun granted(tree: Uri): Boolean =
        activity.contentResolver.persistedUriPermissions.any {
            it.uri == tree && it.isReadPermission && it.isWritePermission
        }

    private data class Doc(val id: String, val name: String, val dir: Boolean, val modified: Long, val size: Long)

    private fun children(tree: Uri, parentId: String): List<Doc> {
        val uri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentId)
        val columns = arrayOf(
            DocumentsContract.Document.COLUMN_DOCUMENT_ID,
            DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            DocumentsContract.Document.COLUMN_MIME_TYPE,
            DocumentsContract.Document.COLUMN_LAST_MODIFIED,
            DocumentsContract.Document.COLUMN_SIZE,
        )
        val out = mutableListOf<Doc>()
        activity.contentResolver.query(uri, columns, null, null, null)?.use { c ->
            while (c.moveToNext()) {
                out.add(
                    Doc(
                        id = c.getString(0),
                        name = c.getString(1),
                        dir = c.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR,
                        modified = if (c.isNull(3)) 0 else c.getLong(3),
                        size = if (c.isNull(4)) 0 else c.getLong(4),
                    ),
                )
            }
        }
        return out
    }

    /** The document id at [path] inside the tree, or null when missing. */
    private fun find(tree: Uri, path: List<String>, create: Boolean = false): String? {
        var id = DocumentsContract.getTreeDocumentId(tree)
        for (name in path) {
            val next = children(tree, id).firstOrNull { it.name == name }
            id = when {
                next != null -> next.id
                create -> {
                    val parent = DocumentsContract.buildDocumentUriUsingTree(tree, id)
                    val made = DocumentsContract.createDocument(
                        activity.contentResolver, parent,
                        DocumentsContract.Document.MIME_TYPE_DIR, name,
                    ) ?: return null
                    DocumentsContract.getDocumentId(made)
                }
                else -> return null
            }
        }
        return id
    }

    private fun list(tree: Uri, path: List<String>): List<Map<String, Any>> {
        val id = find(tree, path) ?: return emptyList()
        return children(tree, id).map {
            mapOf("name" to it.name, "dir" to it.dir, "modified" to it.modified, "size" to it.size)
        }
    }

    private fun read(tree: Uri, path: List<String>): String? {
        val id = find(tree, path) ?: return null
        val uri = DocumentsContract.buildDocumentUriUsingTree(tree, id)
        return activity.contentResolver.openInputStream(uri)?.use {
            it.readBytes().toString(Charsets.UTF_8)
        }
    }

    /**
     * Writes under a temporary name and swaps it in, so the sync program
     * never sends half a file.
     */
    private fun write(tree: Uri, path: List<String>, text: String): Boolean {
        val dirId = find(tree, path.dropLast(1), create = true) ?: return false
        val name = path.last()
        val dir = DocumentsContract.buildDocumentUriUsingTree(tree, dirId)
        val resolver = activity.contentResolver
        val temp = DocumentsContract.createDocument(
            resolver, dir, "application/octet-stream", "$name.tmp",
        ) ?: return false
        resolver.openOutputStream(temp, "wt")?.use { it.write(text.toByteArray(Charsets.UTF_8)) }
        children(tree, dirId).firstOrNull { it.name == name }?.let {
            DocumentsContract.deleteDocument(
                resolver, DocumentsContract.buildDocumentUriUsingTree(tree, it.id),
            )
        }
        return DocumentsContract.renameDocument(resolver, temp, name) != null
    }

    private fun delete(tree: Uri, path: List<String>): Boolean {
        val id = find(tree, path) ?: return false
        return DocumentsContract.deleteDocument(
            activity.contentResolver,
            DocumentsContract.buildDocumentUriUsingTree(tree, id),
        )
    }
}
