import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'surrender_details_page.dart';

class ViewSurrenders extends StatefulWidget {
  const ViewSurrenders({super.key});

  @override
  State<ViewSurrenders> createState() => _ViewSurrendersState();
}

class _ViewSurrendersState extends State<ViewSurrenders> {
  List surrenders = [];
  bool isLoading = true;

  final String baseUrl = apiBaseUrl;

  @override
  void initState() {
    super.initState();
    fetchSurrenders();
  }

  Future<void> fetchSurrenders() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/surrenders"));

      if (res.statusCode == 200) {
        setState(() {
          surrenders = jsonDecode(res.body);
          isLoading = false;
        });
      } else {
        debugPrint("Server Error: ${res.body}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Exception: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> moveToAdoption(int id, Map<String, dynamic> dogData) async {
    try {
      final res = await http.post(
        Uri.parse("$baseUrl/move_to_adoption"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "source": "surrender",
          "id": id,
          "dog_name": dogData["dog_name"] ?? "Unknown",
          "breed": dogData["breed"] ?? "Unknown",
          "color": dogData["color"] ?? "Unknown",
          "age": dogData["age"]?.toString() ?? "Unknown",
          "gender": dogData["gender"] ?? "Unknown",
          "vaccination_status": dogData["vaccinated"] ?? "Unknown",
          "behavior_description": dogData["behavior"] ?? "Unknown",
        }),
      );

      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Moved to Adoption Successfully 🎉"),
            backgroundColor: const Color(0xFF22C55E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        fetchSurrenders();
      }
    } catch (e) {
      debugPrint("Move error: $e");
    }
  }

  // Dialog removed completely

  Future<void> rejectSurrender(int id) async {
    try {
      final res = await http.put(
        Uri.parse("$baseUrl/surrender/$id"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"status": "rejected"}),
      );

      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Surrender Request Rejected"),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        fetchSurrenders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Exception: $e")));
      }
    }
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case "pending": color = const Color(0xFFF97316); break;
      case "completed": color = const Color(0xFF22C55E); break;
      case "rejected": color = const Color(0xFFEF4444); break;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("Surrender Requests"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF97316), Color(0xFFFB923C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF97316)))
          : surrenders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(22)),
                        child: const Icon(Icons.volunteer_activism_outlined, size: 36, color: Color(0xFFB0BEC5)),
                      ),
                      const SizedBox(height: 16),
                      const Text("No Surrender Requests", style: TextStyle(color: Color(0xFF78909C), fontSize: 16, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: fetchSurrenders,
                  color: const Color(0xFFF97316),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: surrenders.length,
                    itemBuilder: (context, index) {
                      final dog = surrenders[index];
                      final status = dog["status"] ?? "pending";
                      final isApproved = status == "completed" || status == "adopted" || status == "rejected";

                      final imagePaths = (dog['image_path'] ?? "").toString().split(',');
                      final firstImage = imagePaths.isNotEmpty && imagePaths.first.isNotEmpty ? imagePaths.first : null;

                      final imageUrl = firstImage != null
                          ? "$baseUrl/uploads/$firstImage"
                          : null;

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => SurrenderDetailsPage(surrender: dog)),
                          );
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 15, offset: const Offset(0, 5))],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: imageUrl != null
                                          ? Image.network(imageUrl, width: 85, height: 85, fit: BoxFit.cover,
                                              errorBuilder: (_, e, s) => _placeholder())
                                          : _placeholder(),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                dog["breed"] ?? "Unknown Breed",
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1A2E35)),
                                              ),
                                              _statusChip(status),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          _infoRow(Icons.phone_outlined, dog["phone"] ?? 'N/A'),
                                          _infoRow(Icons.cake_rounded, "Age: ${dog["age"] ?? 'Unknown'}"),
                                          _infoRow(Icons.transgender_rounded, dog["gender"] ?? 'Unknown'),
                                          _infoRow(Icons.info_outline_rounded, dog["reason"] ?? 'No reason given'),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (!isApproved) ...[
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFFEF4444),
                                            side: const BorderSide(color: Color(0xFFEF4444)),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          icon: const Icon(Icons.close_rounded, size: 16),
                                          label: const Text("Reject", style: TextStyle(fontWeight: FontWeight.w600)),
                                          onPressed: () => rejectSurrender(dog["id"]),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF22C55E),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          icon: const Icon(Icons.pets_rounded, size: 16, color: Colors.white),
                                          label: const Text("Put for Adoption", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                          onPressed: () async {
                                            showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (loadingContext) => const Center(child: CircularProgressIndicator(color: Color(0xFFF97316))),
                                            );
                                            await moveToAdoption(dog["id"], dog);
                                            if (context.mounted) Navigator.pop(context); // close loading
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: const Color(0xFFF97316)),
          const SizedBox(width: 5),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF546E7A)), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  // Custom text fields removed

  Widget _placeholder() {
    return Container(
      width: 85, height: 85,
      decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(14)),
      child: const Icon(Icons.pets_rounded, size: 36, color: Color(0xFFB0BEC5)),
    );
  }
}
