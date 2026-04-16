import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'package:geolocator/geolocator.dart';
import 'chatbot_page.dart';

class ReportDogPage extends StatefulWidget {
  const ReportDogPage({super.key});

  @override
  State<ReportDogPage> createState() => _ReportDogPageState();
}

class _ReportDogPageState extends State<ReportDogPage> {
  Uint8List? selectedImage;
  bool uploading = false;
  String result = "";
  bool resultSuccess = false;

  double? latitude;
  double? longitude;

  final picker = ImagePicker();

  /*Future<void> getLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() { result = "Please enable location services."; resultSuccess = false; });
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      setState(() { result = "Location permission permanently denied."; resultSuccess = false; });
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    setState(() {
      latitude = position.latitude;
      longitude = position.longitude;
    });
  }*/
  Future<void> getLocation() async {
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    setState(() {
      result = "Please turn on phone location/GPS.";
      resultSuccess = false;
    });
    return;
  }

  permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.denied) {
    setState(() {
      result = "Location permission denied.";
      resultSuccess = false;
    });
    return;
  }

  if (permission == LocationPermission.deniedForever) {
    setState(() {
      result = "Location permission permanently denied. Please enable it in settings.";
      resultSuccess = false;
    });
    return;
  }

  try {
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    setState(() {
      latitude = position.latitude;
      longitude = position.longitude;
      result = "Location captured successfully.";
      resultSuccess = true;
    });
  } catch (e) {
    setState(() {
      result = "Location error: $e";
      resultSuccess = false;
    });
  }
}

  Future<void> pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      await getLocation();
      setState(() {
        selectedImage = bytes;
        result = "";
      });
    }
  }

  Future<void> uploadImage() async {
    if (selectedImage == null) return;

    if (latitude == null || longitude == null) {
      setState(() { result = "Location not available."; resultSuccess = false; });
      return;
    }

    setState(() { uploading = true; result = ""; });

    final url = Uri.parse('$apiBaseUrl/report');
    final request = http.MultipartRequest('POST', url);

    request.files.add(
      http.MultipartFile.fromBytes('file', selectedImage!, filename: 'dog.jpg'),
    );
    request.fields['latitude'] = latitude.toString();
    request.fields['longitude'] = longitude.toString();

    try {
      final response = await request.send();
      final resBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(resBody);
        final caseId = data['case_id'] != null ? data['case_id'].toString() : "N/A";
        setState(() {
          result = "Report Submitted!\nCase ID: $caseId\nThe rescue team will take action soon.";
          resultSuccess = true;
          selectedImage = null;
        });
      } else {
        setState(() { result = "Upload failed. Please try again."; resultSuccess = false; });
      }
    } catch (e) {
      setState(() { result = "Error: $e"; resultSuccess = false; });
    }

    setState(() { uploading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: const Color(0xFF00695C),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Report Injured Dog', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00695C), Color(0xFF26A69A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.pets_rounded, size: 48, color: Colors.white24),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Image Upload Zone
                  GestureDetector(
                    onTap: uploading ? null : pickImage,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: selectedImage != null ? 220 : 180,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selectedImage != null ? const Color(0xFF00695C) : const Color(0xFFB0BEC5),
                          width: selectedImage != null ? 2 : 1.5,
                          style: selectedImage != null ? BorderStyle.solid : BorderStyle.solid,
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(19),
                        child: selectedImage != null
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Container(color: const Color(0xFFF0F4F8)), // Neutral background
                                  Image.memory(selectedImage!, fit: BoxFit.contain), // Fix aspect ratio
                                  Positioned(
                                    bottom: 10,
                                    right: 10,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                                          SizedBox(width: 4),
                                          Text("Change", style: TextStyle(color: Colors.white, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0F4F8),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Icon(Icons.camera_alt_rounded, size: 32, color: Color(0xFF00695C)),
                                  ),
                                  const SizedBox(height: 14),
                                  const Text("Tap to Upload Image", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1A2E35))),
                                  const SizedBox(height: 4),
                                  const Text("Take a photo or pick from gallery", style: TextStyle(color: Color(0xFF78909C), fontSize: 13)),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Location indicator
                  if (latitude != null && longitude != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00695C).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_rounded, color: Color(0xFF00695C), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            "Location captured  •  ${latitude!.toStringAsFixed(4)}, ${longitude!.toStringAsFixed(4)}",
                            style: const TextStyle(color: Color(0xFF00695C), fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),

                  if (latitude != null) const SizedBox(height: 16),

                  // Submit Button
                  if (selectedImage != null)
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF00695C), Color(0xFF26A69A)]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF00695C).withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: uploading ? null : uploadImage,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: uploading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.send_rounded, color: Colors.white, size: 20),
                                        SizedBox(width: 10),
                                        Text("Submit Report", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Result
                  if (result.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: resultSuccess ? const Color(0xFF22C55E).withValues(alpha: 0.1) : const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: resultSuccess ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            resultSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                            color: resultSuccess ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              result,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: resultSuccess ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotPage()));
        },
        backgroundColor: const Color(0xFF00695C),
        tooltip: "Virtual Assistant",
        child: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white),
      ),
    );
  }
}