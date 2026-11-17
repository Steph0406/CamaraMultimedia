
import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'media_service.dart';
import 'galeria_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cámara Multimedia',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const CamaraScreen(),
    );
  }
}

class CamaraScreen extends StatefulWidget {
  const CamaraScreen({super.key});

  @override
  State<CamaraScreen> createState() => _CamaraScreenState();
}

class _CamaraScreenState extends State<CamaraScreen>
    with WidgetsBindingObserver {
  final MediaService _media = MediaService();

  CameraController? _camara;
  Timer? _timer;

  bool _video = false;
  bool _grabando = false;
  bool _ocupado = false;
  bool _enConfirmacion = false;
  bool _activo = true;

  int _segundos = 0;
  int _sesion = 0;
  String _error = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _iniciar();
  }

  Future<void> _iniciar() async {
    try {
      await _media.limpiarTemporales();
      if (mounted && _activo) {
        await _iniciarCamara();
      }
    } catch (e) {
      _mostrarError(e);
    }
  }

  Future<void> _iniciarCamara() async {
    final sesion = ++_sesion;

    try {
      final camaras = await availableCameras();

      if (camaras.isEmpty) {
        throw Exception('No hay cámaras disponibles');
      }

      final camara = CameraController(
        camaras.first,
        ResolutionPreset.medium,
        enableAudio: true,
      );

      await camara.initialize();

      if (!mounted || !_activo || sesion != _sesion) {
        await camara.dispose();
        return;
      }

      setState(() {
        _camara = camara;
        _error = '';
      });
    } catch (e) {
      _mostrarError(e);
    }
  }

  Future<void> _liberarCamara() async {
    _sesion++;
    _timer?.cancel();
    final camara = _camara;
    _camara = null;

    if (mounted) {
      setState(() {});
    }

    if (camara != null) {
      await camara.dispose();
    }
  }

  void _mostrarError(Object error) {
    if (!mounted) return;

    setState(() {
      _error = error.toString();
      _ocupado = false;
    });
  }


  Future<void> _abrirGaleria() async {
    if (_ocupado || _grabando || _enConfirmacion) return;

    _enConfirmacion = true;

    try {
      await _liberarCamara();

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const GaleriaScreen(),
        ),
      );
    } finally {
      _enConfirmacion = false;

      if (mounted && _activo) {
        await _iniciarCamara();
      }
    }
  }

  void _cambiarModo(bool video) {
    if (_grabando || _ocupado) return;

    setState(() {
      _video = video;
    });
  }

  Future<void> _capturar() async {
    final camara = _camara;

    if (camara == null || _ocupado || _grabando) return;

    setState(() => _ocupado = true);

    try {
      final foto = await camara.takePicture();
      await _confirmarArchivo(foto.path, false);
    } catch (e) {
      _mostrarError(e);
    } finally {
      if (mounted) {
        setState(() => _ocupado = false);
      }
    }
  }

  Future<void> _grabarVideo() async {
    final camara = _camara;

    if (camara == null || _ocupado) return;

    setState(() => _ocupado = true);

    try {
      if (!_grabando) {
        await camara.startVideoRecording();

        _segundos = 0;
        _timer?.cancel();

        _timer = Timer.periodic(
          const Duration(seconds: 1),
              (_) {
            if (mounted) {
              setState(() => _segundos++);
            }
          },
        );

        setState(() => _grabando = true);
      } else {
        _timer?.cancel();

        final video = await camara.stopVideoRecording();

        setState(() => _grabando = false);

        await _confirmarArchivo(video.path, true);
      }
    } catch (e) {
      _timer?.cancel();
      if (mounted) {
        setState(() => _grabando = false);
      }
      _mostrarError(e);
    } finally {
      if (mounted) {
        setState(() => _ocupado = false);
      }
    }
  }

  Future<void> _confirmarArchivo(
      String ruta,
      bool esVideo,
      ) async {
    final archivo = await _media.prepararArchivo(ruta, esVideo);

    _enConfirmacion = true;
    await _liberarCamara();

    if (!mounted) {
      await _media.eliminarArchivo(archivo);
      return;
    }

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConfirmacionScreen(
            archivo: archivo,
            esVideo: esVideo,
            media: _media,
          ),
        ),
      );
    } finally {
      _enConfirmacion = false;

      await _media.eliminarArchivo(archivo);

      if (mounted && _activo) {
        await _iniciarCamara();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _activo = true;

      if (!_enConfirmacion && _camara == null) {
        _iniciarCamara();
      }
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _activo = false;

      if (_grabando) {
        _timer?.cancel();
        _grabando = false;

        final camara = _camara;
        if (camara != null && camara.value.isRecordingVideo) {
          camara.stopVideoRecording().then((archivo) async {
            await _media.eliminarArchivo(File(archivo.path));
          }).catchError((_) {});
        }
      }

      _liberarCamara();

      if (state == AppLifecycleState.detached) {
        _media.limpiarTemporales();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _sesion++;
    _camara?.dispose();
    _media.limpiarTemporales();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camara = _camara;
    final lista = camara != null && camara.value.isInitialized;

    return Scaffold(

      appBar: AppBar(
        title: const Text('Cámara Multimedia'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _ocupado || _grabando ? null : _abrirGaleria,
            icon: const Icon(Icons.photo_library),
            tooltip: 'Mis archivos',
          ),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.black,
              width: double.infinity,
              child: lista
                  ? Center(child: CameraPreview(camara))
                  : Center(
                child: _error.isNotEmpty
                    ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _error,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                    ),
                  ),
                )
                    : const CircularProgressIndicator(),
              ),
            ),
          ),
          if (_grabando)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Grabando: ${_segundos ~/ 60}:'
                    '${(_segundos % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('Foto'),
                      icon: Icon(Icons.photo_camera),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Video'),
                      icon: Icon(Icons.videocam),
                    ),
                  ],
                  selected: {_video},
                  onSelectionChanged:
                  _grabando || _ocupado
                      ? null
                      : (valores) => _cambiarModo(valores.first),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: lista && !_ocupado
                      ? (_video ? _grabarVideo : _capturar)
                      : null,
                  icon: Icon(
                    _video
                        ? (_grabando ? Icons.stop : Icons.fiber_manual_record)
                        : Icons.camera_alt,
                  ),
                  label: Text(
                    _video
                        ? (_grabando ? 'Detener video' : 'Grabar video')
                        : 'Tomar fotografía',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ConfirmacionScreen extends StatefulWidget {
  final File archivo;
  final bool esVideo;
  final MediaService media;

  const ConfirmacionScreen({
    super.key,
    required this.archivo,
    required this.esVideo,
    required this.media,
  });

  @override
  State<ConfirmacionScreen> createState() =>
      _ConfirmacionScreenState();
}

class _ConfirmacionScreenState extends State<ConfirmacionScreen> {
  final TextEditingController _nombre = TextEditingController();

  VideoPlayerController? _reproductor;
  bool _guardando = false;
  String _error = '';

  @override
  void initState() {
    super.initState();

    if (widget.esVideo) {
      _iniciarVideo();
    }
  }

  Future<void> _iniciarVideo() async {
    final reproductor = VideoPlayerController.file(widget.archivo);
    _reproductor = reproductor;

    try {
      await reproductor.initialize();

      if (mounted) {
        setState(() {});
        await reproductor.setLooping(true);
        await reproductor.play();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  Future<void> _cancelar() async {
    if (_guardando) return;

    setState(() => _guardando = true);

    try {
      await _reproductor?.pause();
      await _reproductor?.dispose();
      _reproductor = null;

      await widget.media.eliminarArchivo(widget.archivo);

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _guardando = false;
        });
      }
    }
  }

  Future<void> _aceptar() async {
    if (_nombre.text.trim().isEmpty || _guardando) {
      setState(() => _error = 'Escribe un nombre para el archivo');
      return;
    }

    setState(() {
      _guardando = true;
      _error = '';
    });

    try {
      await _reproductor?.pause();
      await _reproductor?.dispose();
      _reproductor = null;

      final guardado = await widget.media.guardarArchivo(
        widget.archivo,
        _nombre.text,
        widget.esVideo,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Archivo guardado: ${guardado.path}'),
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _guardando = false;
        });

        if (widget.esVideo) {
          _iniciarVideo();
        }
      }
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _reproductor?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reproductor = _reproductor;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _cancelar();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Confirmar archivo'),
          automaticallyImplyLeading: false,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: widget.esVideo
                      ? reproductor != null &&
                      reproductor.value.isInitialized
                      ? AspectRatio(
                    aspectRatio: reproductor.value.aspectRatio,
                    child: VideoPlayer(reproductor),
                  )
                      : const CircularProgressIndicator()
                      : Image.file(widget.archivo),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nombre,
                decoration: const InputDecoration(
                  labelText: 'Nombre del archivo',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    _error,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _guardando ? null : _cancelar,
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _guardando ? null : _aceptar,
                      child: const Text('Aceptar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
