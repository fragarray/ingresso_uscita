import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:ui' as ui;
import '../models/work_site.dart';

class QRCodeService {
  static final QRCodeService _instance = QRCodeService._internal();
  factory QRCodeService() => _instance;
  QRCodeService._internal();

  static const String SECRET_KEY = "SinergyWork2025SecretKey";

  /// Genera i dati del QR code per un cantiere
  Map<String, dynamic> generateQRData({
    required WorkSite workSite,
    required String serverHost,
    required int serverPort,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final cantiereId = 'CANT-$timestamp-${workSite.id.toString().padLeft(3, '0')}';
    
    // Calcola firma SHA-256
    final signatureData = '$cantiereId|$timestamp|$SECRET_KEY';
    final bytes = utf8.encode(signatureData);
    final digest = sha256.convert(bytes);
    final signature = digest.toString();

    return {
      'cantiere_id': cantiereId,
      'cantiere_name': workSite.name,
      'server_host': serverHost,
      'server_port': serverPort,
      'timestamp': timestamp,
      'signature': signature,
    };
  }

  /// Genera deep link per un cantiere
  String generateDeepLink({
    required WorkSite workSite,
    required String serverHost,
    required int serverPort,
  }) {
    final qrData = generateQRData(
      workSite: workSite,
      serverHost: serverHost,
      serverPort: serverPort,
    );

    // Converti in JSON e poi Base64
    final jsonString = jsonEncode(qrData);
    final base64String = base64Encode(utf8.encode(jsonString));
    
    return 'sinergywork://scan/$base64String';
  }

  /// Widget per visualizzare il QR code
  Widget buildQRWidget({
    required WorkSite workSite,
    required String serverHost,
    required int serverPort,
    double size = 200,
  }) {
    final deepLink = generateDeepLink(
      workSite: workSite,
      serverHost: serverHost,
      serverPort: serverPort,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'QR CODE TIMBRATURA',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                workSite.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              QrImageView(
                data: deepLink,
                version: QrVersions.auto,
                size: size,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                errorCorrectionLevel: QrErrorCorrectLevel.M,
              ),
              const SizedBox(height: 12),
              Text(
                '📱 Inquadra con fotocamera',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                '✅ Timbra automaticamente',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'ID: CANT-${DateTime.now().millisecondsSinceEpoch ~/ 1000}-${workSite.id.toString().padLeft(3, '0')}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue[700],
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Salva QR code come immagine con selezione cartella
  Future<String?> saveQRAsImageWithPicker({
    required BuildContext context,
    required WorkSite workSite,
    required String serverHost,
    required int serverPort,
    double size = 500,
  }) async {
    try {
      // Su mobile, chiedi di selezionare una directory
      final String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Seleziona cartella per salvare il QR Code',
      );

      if (selectedDirectory == null) {
        // Utente ha annullato
        return null;
      }

      final fileName = 'QR_${workSite.name.replaceAll(RegExp(r'[^\w\s-]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.png';
      final outputFile = '$selectedDirectory/$fileName';

      final deepLink = generateDeepLink(
        workSite: workSite,
        serverHost: serverHost,
        serverPort: serverPort,
      );

      // Crea il painter del QR
      final qrPainter = QrPainter(
        data: deepLink,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        color: Colors.black,
        emptyColor: Colors.white,
      );

      // Crea canvas e disegna
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      
      // Sfondo bianco
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size, size),
        Paint()..color = Colors.white,
      );
      
      // Disegna QR
      qrPainter.paint(canvas, Size(size, size));
      
      // Converti in immagine
      final picture = pictureRecorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        throw Exception('Impossibile generare immagine QR');
      }

      // Salva file nel percorso scelto
      final file = File(outputFile);
      await file.writeAsBytes(byteData.buffer.asUint8List());
      
      print('[QRCode] ✅ QR salvato: ${file.path}');
      return file.path;
      
    } catch (e) {
      print('[QRCode] ❌ Errore salvataggio: $e');
      return null;
    }
  }

  /// Salva QR code come immagine (versione originale - Documents)
  Future<String?> saveQRAsImage({
    required WorkSite workSite,
    required String serverHost,
    required int serverPort,
    double size = 300,
  }) async {
    try {
      final deepLink = generateDeepLink(
        workSite: workSite,
        serverHost: serverHost,
        serverPort: serverPort,
      );

      // Crea il painter del QR
      final qrPainter = QrPainter(
        data: deepLink,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        color: Colors.black,
        emptyColor: Colors.white,
      );

      // Crea canvas e disegna
      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      
      // Sfondo bianco
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size, size),
        Paint()..color = Colors.white,
      );
      
      // Disegna QR
      qrPainter.paint(canvas, Size(size, size));
      
      // Converti in immagine
      final picture = pictureRecorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        throw Exception('Impossibile generare immagine QR');
      }

      // Salva file
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'QR_${workSite.name.replaceAll(RegExp(r'[^\w\s-]'), '_')}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsBytes(byteData.buffer.asUint8List());
      
      print('[QRCode] ✅ QR salvato: ${file.path}');
      return file.path;
      
    } catch (e) {
      print('[QRCode] ❌ Errore salvataggio: $e');
      return null;
    }
  }

  /// Mostra dialog per visualizzare e stampare QR
  void showQRDialog({
    required BuildContext context,
    required WorkSite workSite,
    required String serverHost,
    required int serverPort,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.qr_code, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'QR Code Timbratura',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildQRWidget(
                        workSite: workSite,
                        serverHost: serverHost,
                        serverPort: serverPort,
                        size: 250,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                                const SizedBox(width: 8),
                                const Text(
                                  'Come usare:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text('1. Stampa questo QR code'),
                            const Text('2. Posizionalo nel cantiere'),
                            const Text('3. I dipendenti inquadrano con fotocamera'),
                            const Text('4. Si apre automaticamente l\'app'),
                            const Text('5. Login e timbratura automatica'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('CHIUDI'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              
                              // Mostra loading
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(color: Colors.white),
                                      SizedBox(height: 16),
                                      Text(
                                        'Salvataggio QR code...',
                                        style: TextStyle(color: Colors.white, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              );

                              final filePath = await saveQRAsImageWithPicker(
                                context: context,
                                workSite: workSite,
                                serverHost: serverHost,
                                serverPort: serverPort,
                                size: 500, // Alta risoluzione per stampa
                              );

                              if (!context.mounted) return;
                              Navigator.of(context).pop(); // Chiudi loading

                              if (filePath != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('QR code salvato in:\n$filePath'),
                                    backgroundColor: Colors.green,
                                    duration: const Duration(seconds: 5),
                                    action: SnackBarAction(
                                      label: 'APRI CARTELLA',
                                      textColor: Colors.white,
                                      onPressed: () {
                                        // Apri esplora file nella cartella del file
                                        final dir = File(filePath).parent.path;
                                        Process.run('explorer', [dir]);
                                      },
                                    ),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Salvataggio annullato dall\'utente'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.save),
                            label: const Text('SALVA PNG'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ),
    );
  }
}