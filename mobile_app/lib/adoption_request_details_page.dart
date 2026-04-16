import 'package:flutter/material.dart';
import 'api_config.dart';

class AdoptionRequestDetailsPage extends StatelessWidget {
  final Map requestData;
  final String baseUrl = apiBaseUrl;

  const AdoptionRequestDetailsPage({super.key, required this.requestData});

  String formatDate(String? rawDate) {
    if (rawDate == null) return "Unknown";
    try {
      DateTime dt = DateTime.parse(rawDate);
      return "${dt.day}/${dt.month}/${dt.year}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return rawDate;
    }
  }

  Widget _infoCard(String title, String value, IconData icon, {Color iconColor = const Color(0xFF00695C)}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF78909C), fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 15, color: Color(0xFF1A2E35), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = requestData['image_path'] != null ? "$baseUrl/uploads/${requestData['image_path']}" : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("Adoption Request"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF00695C), Color(0xFF26A69A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Image Header
            Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.black, // Dark background for letterboxing
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.contain, // Fix aspect ratio issues
                      errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.pets, size: 80, color: Colors.grey)),
                    )
                  : const Center(child: Icon(Icons.pets, size: 80, color: Colors.grey)),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Request Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A2E35))),
                  const SizedBox(height: 16),
                  _infoCard("Dog ID", requestData['adoption_id']?.toString() ?? 'N/A', Icons.pets),
                  _infoCard("Applicant Name", requestData['user_name'] ?? 'Unknown', Icons.person),
                  _infoCard("Phone", requestData['phone'] ?? 'Not provided', Icons.phone),
                  _infoCard("Address", requestData['address'] ?? 'Not provided', Icons.home),
                  _infoCard("Status", requestData['status']?.toUpperCase() ?? 'UNKNOWN', Icons.info_outline, iconColor: const Color(0xFFF97316)),
                  _infoCard("Submitted Date", formatDate(requestData['created_at']), Icons.calendar_today_rounded),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
