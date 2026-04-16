import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'adoption_request_details_page.dart';

String formatDate(String rawDate) {
  DateTime dt = DateTime.parse(rawDate);
  return "${dt.day}/${dt.month}/${dt.year}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
}

class ViewAdoptionRequestsPage extends StatefulWidget {
  const ViewAdoptionRequestsPage({super.key});

  @override
  State<ViewAdoptionRequestsPage> createState() =>
      _ViewAdoptionRequestsPageState();
}

class _ViewAdoptionRequestsPageState extends State<ViewAdoptionRequestsPage> {
  List requests = [];
  bool isLoading = true;

  final String baseUrl = apiBaseUrl;

  @override
  void initState() {
    super.initState();
    fetchRequests();
  }

  Future<void> fetchRequests() async {
    final res = await http.get(Uri.parse("$baseUrl/adoption_requests"));

    if (res.statusCode == 200) {
      setState(() {
        requests = jsonDecode(res.body);
        isLoading = false;
      });
    }
  }

  Future<void> updateStatus(int id, String status) async {
    await http.put(
      Uri.parse("$baseUrl/adoption_requests/$id"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"status": status}),
    );
    fetchRequests();
  }

  Widget _statusChip(String status) {
    Color color;
    switch (status) {
      case "pending": color = const Color(0xFFF97316); break;
      case "approved": color = const Color(0xFF22C55E); break;
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

  Widget _placeholder() {
    return Container(
      width: 80, height: 80,
      decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(14)),
      child: const Icon(Icons.pets_rounded, size: 34, color: Color(0xFFB0BEC5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("Adoption Requests"),
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
          : requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72, height: 72,
                        decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(22)),
                        child: const Icon(Icons.mail_outline_rounded, size: 36, color: Color(0xFFB0BEC5)),
                      ),
                      const SizedBox(height: 16),
                      const Text("No Adoption Requests", style: TextStyle(color: Color(0xFF78909C), fontSize: 16, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final r = requests[index];
                    final status = r["status"];
                    final isPending = status == "pending";

                    final imageUrl = r['image_path'] != null
                        ? "$baseUrl/uploads/${r['image_path']}"
                        : null;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AdoptionRequestDetailsPage(requestData: r)),
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
                                      ? Image.network(imageUrl, width: 80, height: 80, fit: BoxFit.cover,
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
                                            "Dog #${r['adoption_id']}",
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1A2E35)),
                                          ),
                                          _statusChip(status),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      _infoRow(Icons.person_outline_rounded, r['user_name'] ?? 'N/A'),
                                      _infoRow(Icons.phone_outlined, r['phone'] ?? 'N/A'),
                                      _infoRow(Icons.home_outlined, r['address'] ?? 'N/A'),
                                      const SizedBox(height: 4),
                                      Text(
                                        "Submitted: ${formatDate(r['created_at'])}",
                                        style: const TextStyle(fontSize: 11, color: Color(0xFFB0BEC5)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            if (isPending) ...[
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
                                      onPressed: () => updateStatus(r['id'], "rejected"),
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
                                      icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                                      label: const Text("Approve", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                      onPressed: () => updateStatus(r['id'], "approved"),
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
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: const Color(0xFF00695C)),
          const SizedBox(width: 5),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF546E7A)), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}