package org.haxe.extension;

import android.app.Activity;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.provider.OpenableColumns;

import org.haxe.lime.HaxeObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.OutputStream;

public class AndroidFilePicker extends Extension {

    private static final int REQUEST_OPEN_DOCUMENT = 43192;
    private static final int REQUEST_CREATE_DOCUMENT = 43193;
    private static HaxeObject callback;
    private static String pendingExtension = "";
    private static String pendingSaveSource = null;

    public static void setCallback(HaxeObject object) {
        callback = object;
    }

    public static void browseFile(final String title, final String extension) {
        final Activity activity = mainActivity;
        if (activity == null) {
            dispatchError("No encontré la actividad principal de Android.");
            return;
        }

        pendingExtension = extension == null ? "" : extension.trim().toLowerCase();

        activity.runOnUiThread(new Runnable() {
            @Override public void run() {
                try {
                    Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
                    intent.addCategory(Intent.CATEGORY_OPENABLE);
                    intent.setType(resolveMimeType(pendingExtension));
                    intent.putExtra(Intent.EXTRA_LOCAL_ONLY, true);
                    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                    intent.addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION);

                    if (title != null && !title.isEmpty()) {
                        intent.putExtra(Intent.EXTRA_TITLE, title);
                    }

                    activity.startActivityForResult(intent, REQUEST_OPEN_DOCUMENT);
                } catch (Exception e) {
                    dispatchError("No pude abrir el explorador del teléfono: " + e.getMessage());
                }
            }
        });
    }

    public static void saveFileToUser(final String title, final String suggestedName, final String sourcePath) {
        final Activity activity = mainActivity;
        if (activity == null) {
            dispatchError("No encontré la actividad principal de Android.");
            return;
        }

        if (sourcePath == null || sourcePath.trim().isEmpty()) {
            dispatchError("No encontré el ZIP temporal para guardar.");
            return;
        }

        File source = new File(sourcePath);
        if (!source.exists() || source.isDirectory()) {
            dispatchError("No encontré el archivo temporal: " + sourcePath);
            return;
        }

        pendingSaveSource = source.getAbsolutePath();

        activity.runOnUiThread(new Runnable() {
            @Override public void run() {
                try {
                    Intent intent = new Intent(Intent.ACTION_CREATE_DOCUMENT);
                    intent.addCategory(Intent.CATEGORY_OPENABLE);
                    intent.setType(resolveMimeTypeFromName(suggestedName));
                    intent.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION);

                    if (title != null && !title.isEmpty()) {
                        intent.putExtra(Intent.EXTRA_TITLE, suggestedName == null || suggestedName.isEmpty() ? title : suggestedName);
                    } else if (suggestedName != null && !suggestedName.isEmpty()) {
                        intent.putExtra(Intent.EXTRA_TITLE, suggestedName);
                    }

                    activity.startActivityForResult(intent, REQUEST_CREATE_DOCUMENT);
                } catch (Exception e) {
                    dispatchError("No pude abrir el selector para guardar: " + e.getMessage());
                }
            }
        });
    }

    public static String getWorkspaceRoot() {
        Activity activity = mainActivity;
        if (activity == null) {
            return "";
        }
        return getWorkspaceDir(activity).getAbsolutePath();
    }

    public static void clearWorkspace() {
        Activity activity = mainActivity;
        if (activity == null) {
            return;
        }

        File workspace = getWorkspaceDir(activity);
        deleteRecursively(workspace);
    }

    @Override public boolean onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == REQUEST_OPEN_DOCUMENT) {
            return handleOpenResult(resultCode, data);
        }

        if (requestCode == REQUEST_CREATE_DOCUMENT) {
            return handleSaveResult(resultCode, data);
        }

        return true;
    }

    private boolean handleOpenResult(int resultCode, Intent data) {
        if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null) {
            dispatchCancel();
            return true;
        }

        Activity activity = mainActivity;
        Uri uri = data.getData();

        try {
            try {
                activity.getContentResolver().takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION);
            } catch (Exception ignored) {
            }

            String displayName = resolveDisplayName(activity, uri);
            if (displayName == null || displayName.trim().isEmpty()) {
                displayName = buildFallbackName(pendingExtension);
            }

            File targetDir = new File(getWorkspaceDir(activity), "picked-files");
            if (!targetDir.exists()) {
                targetDir.mkdirs();
            }

            File target = makeUniqueFile(targetDir, sanitizeName(displayName));
            InputStream input = activity.getContentResolver().openInputStream(uri);
            if (input == null) {
                dispatchError("No pude leer el archivo seleccionado.");
                return true;
            }

            FileOutputStream output = new FileOutputStream(target, false);
            copyStream(input, output);

            if (callback != null) {
                callback.call1("onPathSelected", target.getAbsolutePath());
            }
        } catch (Exception e) {
            dispatchError("Error procesando archivo: " + e.getMessage());
        }

        return true;
    }

    private boolean handleSaveResult(int resultCode, Intent data) {
        if (resultCode != Activity.RESULT_OK || data == null || data.getData() == null) {
            dispatchCancel();
            return true;
        }

        Activity activity = mainActivity;
        Uri uri = data.getData();

        if (pendingSaveSource == null || pendingSaveSource.isEmpty()) {
            dispatchError("No encontré el archivo temporal para guardar.");
            return true;
        }

        try {
            File source = new File(pendingSaveSource);
            if (!source.exists() || source.isDirectory()) {
                dispatchError("El ZIP temporal ya no existe.");
                return true;
            }

            InputStream input = new FileInputStream(source);
            OutputStream output = activity.getContentResolver().openOutputStream(uri, "w");
            if (output == null) {
                dispatchError("No pude escribir el archivo destino.");
                return true;
            }

            copyStream(input, output);
            pendingSaveSource = null;

            if (callback != null) {
                callback.call1("onFileSaved", uri.toString());
            }
        } catch (Exception e) {
            dispatchError("No pude guardar el ZIP: " + e.getMessage());
        }

        return true;
    }

    private static void copyStream(InputStream input, OutputStream output) throws Exception {
        byte[] buffer = new byte[8192];
        int read;

        try {
            while ((read = input.read(buffer)) != -1) {
                output.write(buffer, 0, read);
            }
            output.flush();
        } finally {
            try {
                output.close();
            } catch (Exception ignored) {
            }
            try {
                input.close();
            } catch (Exception ignored) {
            }
        }
    }

    private static void dispatchCancel() {
        pendingSaveSource = null;
        if (callback != null) {
            callback.call0("onPickerCancelled");
        }
    }

    private static void dispatchError(String message) {
        if (callback != null) {
            callback.call1("onPickerError", message == null ? "Error desconocido." : message);
        }
    }

    private static String resolveDisplayName(Activity activity, Uri uri) {
        Cursor cursor = null;

        try {
            cursor = activity.getContentResolver().query(uri, null, null, null, null);
            if (cursor != null && cursor.moveToFirst()) {
                int index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME);
                if (index >= 0) {
                    return cursor.getString(index);
                }
            }
        } catch (Exception ignored) {
        } finally {
            if (cursor != null) {
                cursor.close();
            }
        }

        String last = uri.getLastPathSegment();
        return last != null ? last : null;
    }

    private static String buildFallbackName(String extension) {
        if (extension == null || extension.isEmpty()) {
            return "picked_file";
        }
        return "picked_file." + extension;
    }

    private static String sanitizeName(String value) {
        String out = value.replace("/", "_").replace("\\", "_").replace(":", "_");
        if (out.isEmpty()) {
            out = buildFallbackName(pendingExtension);
        }
        return out;
    }

    private static String resolveMimeType(String extension) {
        if (extension == null || extension.isEmpty()) {
            return "*/*";
        }

        if (extension.equals("json")) return "application/json";
        if (extension.equals("xml")) return "text/xml";
        if (extension.equals("png")) return "image/png";
        if (extension.equals("jpg") || extension.equals("jpeg")) return "image/jpeg";
        if (extension.equals("zip")) return "application/zip";
        return "*/*";
    }

    private static String resolveMimeTypeFromName(String name) {
        if (name == null) {
            return "application/octet-stream";
        }

        String lower = name.toLowerCase();
        if (lower.endsWith(".zip")) return "application/zip";
        if (lower.endsWith(".png")) return "image/png";
        if (lower.endsWith(".json")) return "application/json";
        if (lower.endsWith(".xml")) return "text/xml";
        return "application/octet-stream";
    }

    private static File getWorkspaceDir(Activity activity) {
        File workspace = new File(activity.getFilesDir(), "spritemap-to-funky");
        if (!workspace.exists()) {
            workspace.mkdirs();
        }
        return workspace;
    }

    private static File makeUniqueFile(File directory, String fileName) {
        File candidate = new File(directory, fileName);
        if (!candidate.exists()) {
            return candidate;
        }

        String name = fileName;
        String extension = "";
        int dot = fileName.lastIndexOf('.');
        if (dot >= 0) {
            name = fileName.substring(0, dot);
            extension = fileName.substring(dot);
        }

        int suffix = 1;
        while (candidate.exists()) {
            candidate = new File(directory, name + "_" + suffix + extension);
            suffix++;
        }

        return candidate;
    }

    private static void deleteRecursively(File file) {
        if (file == null || !file.exists()) {
            return;
        }

        if (file.isDirectory()) {
            File[] children = file.listFiles();
            if (children != null) {
                for (File child : children) {
                    deleteRecursively(child);
                }
            }
        }

        file.delete();
    }
}
