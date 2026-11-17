
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

class GaleriaScreen extends StatefulWidget {
  const GaleriaScreen({super.key});

  @override
  State<GaleriaScreen> createState() => _GaleriaScreenState();
}

class _GaleriaScreenState extends State<GaleriaScreen> {
  late Future<List<File>> archivos;

  @override
  void initState() {
    super.initState();
    archivos = cargarArchivos();
  }

  Future<List<File>> cargarArchivos() async {
    final directorio = await getApplicationDocumentsDirectory();
    final carpeta = Directory(p.join(directorio.path, 'multimedia'));

    if (!await carpeta.exists()) {
      return [];
    }

    final lista = await carpeta.list().where((archivo) {
      if (archivo is! File) return false;

      final extension = p.extension(archivo.path).toLowerCase();
      return extension == '.jpg' || extension == '.mp4';
    }).cast<File>().toList();

    lista.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));

    return lista;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis archivos'),
      ),
      body: FutureBuilder<List<File>>(
        future: archivos,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('No se pudieron cargar los archivos'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final lista = snapshot.data!;

          if (lista.isEmpty) {
            return const Center(
              child: Text('No hay fotos ni videos guardados'),
            );
          }

          return ListView.builder(
            itemCount: lista.length,
            itemBuilder: (context, index) {
              final archivo = lista[index];
              final esVideo = p.extension(archivo.path).toLowerCase() == '.mp4';

              return ListTile(
                leading: esVideo
                    ? const Icon(Icons.videocam, size: 40)
                    : Image.file(
                  archivo,
                  width: 55,
                  height: 55,
                  fit: BoxFit.cover,
                ),
                title: Text(p.basename(archivo.path)),
                subtitle: Text(esVideo ? 'Video' : 'Fotografía'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VerArchivoScreen(
                        archivo: archivo,
                        esVideo: esVideo,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class VerArchivoScreen extends StatefulWidget {
  final File archivo;
  final bool esVideo;

  const VerArchivoScreen({
    super.key,
    required this.archivo,
    required this.esVideo,
  });

  @override
  State<VerArchivoScreen> createState() => _VerArchivoScreenState();
}

class _VerArchivoScreenState extends State<VerArchivoScreen> {
  VideoPlayerController? reproductor;

  @override
  void initState() {
    super.initState();

    if (widget.esVideo) {
      iniciarVideo();
    }
  }

  Future<void> iniciarVideo() async {
    final video = VideoPlayerController.file(widget.archivo);
    reproductor = video;

    try {
      await video.initialize();
      await video.setLooping(true);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al abrir el video')),
        );
      }
    }
  }

  void reproducirVideo() {
    final video = reproductor;

    if (video == null || !video.value.isInitialized) return;

    if (video.value.isPlaying) {
      video.pause();
    } else {
      video.play();
    }

    setState(() {});
  }

  @override
  void dispose() {
    reproductor?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = reproductor;

    return Scaffold(
      appBar: AppBar(
        title: Text(p.basename(widget.archivo.path)),
      ),
      body: Center(
        child: widget.esVideo
            ? video != null && video.value.isInitialized
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AspectRatio(
              aspectRatio: video.value.aspectRatio,
              child: VideoPlayer(video),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: reproducirVideo,
              icon: Icon(
                video.value.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
              label: Text(
                video.value.isPlaying
                    ? 'Pausar'
                    : 'Reproducir',
              ),
            ),
          ],
        )
            : const CircularProgressIndicator()
            : InteractiveViewer(
          child: Image.file(widget.archivo),
        ),
      ),
    );
  }
}
