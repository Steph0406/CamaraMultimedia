
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MediaService {
  Future<Directory> get tempFolder async {
    final temp = await getTemporaryDirectory();
    final folder = Directory(p.join(temp.path, 'camara_multimedia'));
    await folder.create(recursive: true);
    return folder;
  }

  Future<void> limpiarTemporales() async {
    final folder = await tempFolder;

    if (await folder.exists()) {
      await for (final archivo in folder.list()) {
        await archivo.delete(recursive: true);
      }
    }
  }

  Future<File> prepararArchivo(String ruta, bool video) async {
    final folder = await tempFolder;
    final extension = video ? '.mp4' : '.jpg';
    final nombre = DateTime.now().microsecondsSinceEpoch;

    final destino = p.join(folder.path, '$nombre$extension');
    final archivo = await File(ruta).copy(destino);

    if (ruta != destino) {
      await File(ruta).delete();
    }

    return archivo;
  }

  Future<File> guardarArchivo(
      File temporal,
      String nombre,
      bool video,
      ) async {
    final directorio = await getApplicationDocumentsDirectory();
    final carpeta = Directory(p.join(directorio.path, 'multimedia'));
    await carpeta.create(recursive: true);

    final extension = video ? '.mp4' : '.jpg';
    final nombreLimpio = nombre.trim().replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );

    if (nombreLimpio.isEmpty) {
      throw Exception('Ingresa un nombre válido');
    }

    final destino = File(
      p.join(carpeta.path, '$nombreLimpio$extension'),
    );

    if (await destino.exists()) {
      throw Exception('Ya existe un archivo con ese nombre');
    }

    return temporal.rename(destino.path);
  }

  Future<void> eliminarArchivo(File archivo) async {
    if (await archivo.exists()) {
      await archivo.delete();
    }
  }
}
