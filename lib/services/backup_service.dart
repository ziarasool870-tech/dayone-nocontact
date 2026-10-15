/// Encrypted backup: export all user data to one file, import it back.
///
/// Format: JSON {version, exported_at, settings, tables} → AES-256-CBC
/// encrypted with a key derived (SHA-256) from the user's passphrase →
/// base64(iv + ciphertext) written to a `.dayonebackup` file.
///
/// Honest crypto notes:
/// - Key derivation is plain SHA-256(passphrase) — adequate for a personal
///   backup file, not a substitute for a proper KDF. A wrong passphrase
///   fails loudly at import time.
/// - Export sharing uses the system share sheet (user picks Drive, WhatsApp,
///   Files…). Import uses the system file picker.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database.dart';
import '../data/prefs.dart';

class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const backupExtension = 'dayonebackup';
  static const backupVersion = 1;

  /// Builds the encrypted backup bytes. Throws on failure.
  Future<Uint8List> buildBackup(String passphrase) async {
    if (passphrase.isEmpty) {
      throw ArgumentError('Passphrase must not be empty.');
    }
    final db = DayOneDatabase.instance;
    final prefs = await PrefsService.instance();
    final payload = {
      'version': backupVersion,
      'exported_at': DateTime.now().millisecondsSinceEpoch,
      'app': 'day_one_nocontact',
      'settings': prefs.exportSettings(),
      'tables': await db.dumpAll(),
    };
    final plain = utf8.encode(jsonEncode(payload));

    final key = enc.Key(_deriveKey(passphrase));
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(plain, iv: iv);

    final out = BytesBuilder()
      ..add(iv.bytes)
      ..add(encrypted.bytes);
    return out.toBytes();
  }

  /// Writes the backup to a temp file and opens the system share sheet.
  /// Returns true when the share sheet was opened.
  Future<bool> exportWithShareSheet(String passphrase) async {
    final bytes = await buildBackup(passphrase);
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final file =
        File('${dir.path}/dayone-backup-$stamp.$backupExtension');
    await file.writeAsBytes(bytes, flush: true);
    final result = await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/octet-stream')],
      subject: 'Day One backup',
      text: 'Your Day One backup. Keep it safe — it is encrypted.',
    ));
    return result.status == ShareResultStatus.success;
  }

  /// Lets the user pick a backup file, decrypts with [passphrase], and
  /// restores settings + tables. Returns a human-readable result message.
  ///
  /// The caller MUST confirm with the user first: restore wipes current data.
  Future<String> importFromPicker(String passphrase) async {
    if (passphrase.isEmpty) {
      return 'Please enter the passphrase you used for the backup.';
    }
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [backupExtension],
      withData: true,
    );
    final data = picked?.files.singleOrNull?.bytes;
    if (data == null || data.isEmpty) {
      return 'No backup file selected.';
    }
    try {
      final payload = _decrypt(data, passphrase);
      final version = payload['version'];
      if (version != backupVersion) {
        return 'This backup was made by a newer version of Day One. Please update the app first.';
      }
      if (payload['app'] != 'day_one_nocontact') {
        return 'This file is not a Day One backup.';
      }
      final db = DayOneDatabase.instance;
      final prefs = await PrefsService.instance();
      final settings = payload['settings'];
      final tables = payload['tables'];
      if (settings is Map<String, dynamic> && tables is Map<String, dynamic>) {
        await prefs.importSettings(settings);
        await db.restoreAll(tables);
        return 'Backup restored. Welcome back — your journey continues.';
      }
      return 'Backup file is damaged and could not be read.';
    } on ArgumentError catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not decrypt — wrong passphrase or damaged file.';
    }
  }

  // ------------------------------------------------------------- internals

  Uint8List _deriveKey(String passphrase) =>
      Uint8List.fromList(sha256.convert(utf8.encode(passphrase)).bytes);

  Map<String, dynamic> _decrypt(Uint8List data, String passphrase) {
    if (data.length < 17) {
      throw ArgumentError('Backup file is damaged and could not be read.');
    }
    final key = enc.Key(_deriveKey(passphrase));
    final iv = enc.IV(data.sublist(0, 16));
    final cipher = data.sublist(16);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final plain =
        encrypter.decryptBytes(enc.Encrypted(cipher), iv: iv);
    return jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
  }
}

extension<T> on List<T> {
  T? get singleOrNull => length == 1 ? single : null;
}
