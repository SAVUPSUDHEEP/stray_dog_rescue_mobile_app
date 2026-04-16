import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'dog_details_page.dart';

class ViewAdoptionsPage extends StatefulWidget {
  const ViewAdoptionsPage({super.key});

  @override
  State<ViewAdoptionsPage> createState() => _ViewAdoptionsPageState();
}

class _ViewAdoptionsPageState extends State<ViewAdoptionsPage> {
  List dogs = [];
  bool isLoading = true;

  final String baseUrl = apiBaseUrl;

  @override
  void initState() {
    super.initState();
    fetchDogs();
  }

  Future<void> fetchDogs() async {
    final response = await http.get(Uri.parse("$baseUrl/adoptions"));

    if (response.statusCode == 200) {
      setState(() {
        dogs = jsonDecode(response.body);
        isLoading = false;
      });
    }
  }

  Future<void> markAdopted(int id) async {
    await http.put(
      Uri.parse("$baseUrl/adoptions/$id"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"status": "adopted"}),
    );
    fetchDogs();
  }

  Future<void> deleteAdoption(int id) async {
    final response = await http.delete(Uri.parse("$baseUrl/adoptions/$id"));
    if (response.statusCode == 200) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Listing removed successfully")),
        );
      }
      fetchDogs();
    }
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case "available": color = const Color(0xFF0284C7); break;
      case "adopted": color = const Color(0xFF22C55E); break;
      default: color = const Color(0xFF546E7A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 85, height: 85,
      decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(14)),
      child: const Icon(Icons.pets_rounded, size: 36, color: Color(0xFFB0BEC5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("Admin – Adoption List"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00695C), Color(0xFF26A69A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00695C)))
          : dogs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(22)),
                        child: const Icon(Icons.pets_outlined, size: 36, color: Color(0xFFB0BEC5)),
                      ),
                      const SizedBox(height: 16),
                      const Text("No dogs available", style: TextStyle(color: Color(0xFF78909C), fontSize: 16, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: dogs.length,
                  itemBuilder: (context, index) {
                    final dog = dogs[index];
                    final status = dog["status"] ?? "available";
                    final isAvailable = status == "available";

                    final imagePaths = (dog['image_path'] ?? "").toString().split(',');
                    final firstImage = imagePaths.isNotEmpty && imagePaths.first.isNotEmpty ? imagePaths.first : null;

                    final imageUrl = firstImage != null
                        ? "$baseUrl/uploads/$firstImage"
                        : null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 15, offset: const Offset(0, 5))],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DogDetailsPage(
                                          dog: dog,
                                          username: "admin",
                                          isAdmin: true,
                                        ),
                                      ),
                                    );
                                  },
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: imageUrl != null
                                        ? Image.network(imageUrl, width: 85, height: 85, fit: BoxFit.cover,
                                            errorBuilder: (_, e, s) => _placeholder())
                                        : _placeholder(),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              dog['dog_name'] != null && dog['dog_name'].toString().toLowerCase() != 'unknown'
                                                  ? dog['dog_name']
                                                  : "Adorable ${dog['breed'] ?? 'Dog'}",
                                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1A2E35)),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          _statusChip(status),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _infoChip(Icons.cake_rounded, "${dog['age'] ?? '?'} yrs"),
                                          _infoChip(Icons.transgender_rounded, dog['gender'] ?? '?'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (isAvailable)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => markAdopted(dog["id"]),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF22C55E),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                      icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                                      label: const Text("Adopted", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                if (isAvailable) const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text("Delete Listing?"),
                                          content: const Text("Are you sure you want to remove this dog from the adoption list?"),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                deleteAdoption(dog["id"]);
                                              },
                                              child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFFEF4444),
                                      side: const BorderSide(color: Color(0xFFEF4444)),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                    label: const Text("Remove"),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF00695C)),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF546E7A), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}