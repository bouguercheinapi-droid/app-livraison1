import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(const DeliveryApp());
}

class DeliveryApp extends StatelessWidget {
  const DeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Livraisons Express',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
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
  // N'oubliez pas de remplacer cette valeur par votre vraie clé Google AI Studio
  final String apiKey = "VOTRE_CLE_API_ICI"; 

  File? _selectedImage;
  final TextEditingController _locationController = TextEditingController();
  String _result = "";
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _analyzeAndSort() async {
    if (_selectedImage == null || _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une image et indiquer votre position.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _result = "";
    });

    try {
      final bytes = await _selectedImage!.readAsBytes();
      final base64Image = base64Encode(bytes);

      final url = Uri.parse(
  'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
);

      final prompt = "Lis les communes/wilayas présentes sur cette capture d'écran. "
          "Je suis actuellement à ${_locationController.text}, Alger. "
          "Classe ces communes de la plus proche à la plus éloignée selon le trajet routier. "
          "Donne la liste ordonnée avec la distance estimée et le temps de trajet pour chacune.";

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt},
                {
                  "inline_data": {
                    "mime_type": "image/jpeg",
                    "data": base64Image
                  }
                }
              ]
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final textResponse = data['candidates'][0]['content']['parts'][0]['text'];
        setState(() {
          _result = textResponse;
        });
      } else {
        setState(() {
          _result = "Erreur lors de l'analyse : ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        _result = "Une erreur est survenue : $e";
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
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Votre position actuelle (ex: Hydra, Alger Centre...)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.my_location),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library),
              label: Text(_selectedImage == null ? 'Charger la capture' : 'Changer l\'image'),
            ),
            if (_selectedImage != null) ...[
              const SizedBox(height: 10),
              Image.file(_selectedImage!, height: 150, fit: BoxFit.cover),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _analyzeAndSort,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Calculer l\'itinéraire le plus proche', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 20),
            if (_result.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _result,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
