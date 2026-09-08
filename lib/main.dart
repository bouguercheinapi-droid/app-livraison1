import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

Future<Position> _determinePosition() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('Les services de localisation sont désactivés.');
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error('Les permissions de localisation sont refusées.');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return Future.error('Les permissions de localisation sont définitivement refusées.');
  }

  return await Geolocator.getCurrentPosition();
}

void main() {
  runApp(const DeliveryApp());
}

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Trieur de Livraisons',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _locationController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;
  String _result = '';

  final ImagePicker _picker = ImagePicker();
  final String _apiKey = 'VOTRE_CLE_API_ICI';

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _analyzeAndSort() async {
    if (_selectedImage == null) return;

    setState(() {
      _isLoading = true;
      _result = '';
    });

    try {
      final bytes = await _selectedImage!.readAsBytes();
      final base64Image = base64Encode(bytes);

      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$_apiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': 'Extraire les adresses de livraisons et les trier par proximité avec la position suivante : ${_locationController.text}'
                },
                {
                  'inline_data': {
                    'mime_type': 'image/jpeg',
                    'data': base64Image,
                  }
                }
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _result = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? 'Aucun résultat.';
        });
      } else {
        setState(() {
          _result = 'Erreur ${response.statusCode}: ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _result = 'Erreur lors du traitement : $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trieur de Livraisons'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Ma position / Point de départ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image),
              label: Text(_selectedImage == null ? 'Charger la capture' : 'Changer l\'image'),
            ),
            if (_selectedImage != null) ...[
              const SizedBox(height: 16),
              Image.file(_selectedImage!, height: 150, fit: BoxFit.cover),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _analyzeAndSort,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Calculer l\'itinéraire le plus proche'),
            ),
            const SizedBox(height: 24),
            if (_result.isNotEmpty)
              Text(
                _result,
                style: const TextStyle(fontSize: 16),
              ),
          ],
        ),
      ),
    );
  }
}
