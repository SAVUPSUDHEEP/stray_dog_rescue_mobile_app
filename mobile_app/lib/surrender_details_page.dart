import 'package:flutter/material.dart';
import 'api_config.dart';

class SurrenderDetailsPage extends StatelessWidget {
  final Map surrender;

  const SurrenderDetailsPage({super.key, required this.surrender});

  final String baseUrl = apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final status = surrender['status'] ?? 'pending';
    final imagePaths = (surrender['image_path'] ?? "").toString().split(',');
    final validPaths = imagePaths.where((p) => p.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: CustomScrollView(
        slivers: [
          // Hero image app bar
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: const Color(0xFFF97316),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                surrender['breed'] ?? "Surrender Details",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                   Container(color: Colors.black), // Black background
                  if (validPaths.isNotEmpty)
                    PageView.builder(
                      itemCount: validPaths.length,
                      itemBuilder: (context, index) {
                        return Image.network(
                          "$baseUrl/uploads/${validPaths[index]}",
                          fit: BoxFit.contain, // Fix aspect ratio issues
                          errorBuilder: (_, e, s) => Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(colors: [Color(0xFFF97316), Color(0xFFFB923C)]),
                            ),
                            child: const Icon(Icons.pets_rounded, size: 80, color: Colors.white30),
                          ),
                        );
                      },
                    )
                  else
                    Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFFF97316), Color(0xFFFB923C)]),
                      ),
                      child: const Icon(Icons.pets_rounded, size: 80, color: Colors.white30),
                    ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x77000000)], // Subtler gradient
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status + date row
                  Row(
                    children: [
                      _buildStatusChip(status),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Submitted: ${surrender['created_at'] ?? 'N/A'}",
                          style: const TextStyle(color: Color(0xFF78909C), fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Quick stats
                  Row(
                    children: [
                      _statCard(Icons.cake_rounded, "Age", "${surrender['age'] ?? 'N/A'} yrs"),
                      const SizedBox(width: 12),
                      _statCard(Icons.transgender_rounded, "Gender", surrender['gender'] ?? 'N/A'),
                      const SizedBox(width: 12),
                      _statCard(Icons.vaccines_rounded, "Vaccinated", surrender['vaccinated'] ?? 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _sectionCard("Owner Contact", [
                    _infoRow(Icons.phone_outlined, "Phone", surrender['phone'] ?? 'N/A'),
                    if (surrender['latitude'] != null && surrender['longitude'] != null)
                      _infoRow(Icons.location_on_outlined, "Location", "${surrender['latitude']}, ${surrender['longitude']}"),
                  ]),
                  const SizedBox(height: 14),

                  _sectionCard("Behavior & Health", [
                    _detailBlock("Behavior", surrender['behavior']),
                    _detailBlock("Allergies", surrender['allergies']),
                    _detailBlock("Food Habits", surrender['food']),
                  ]),
                  const SizedBox(height: 14),

                  _sectionCard("Surrender Context", [
                    _detailBlock("Reason for Surrender", surrender['reason']),
                    _detailBlock("Additional Notes", surrender['notes']),
                  ]),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case "pending": color = const Color(0xFFF97316); break;
      case "completed":
      case "approved": color = const Color(0xFF22C55E); break;
      case "rejected": color = const Color(0xFFEF4444); break;
      default: color = const Color(0xFF546E7A);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
    );
  }

  Widget _statCard(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFF97316), size: 22),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF78909C))),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A2E35)), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A2E35))),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFFF97316)),
          const SizedBox(width: 10),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF546E7A), fontSize: 14)),
          Expanded(child: Text(value, style: const TextStyle(color: Color(0xFF1A2E35), fontSize: 14))),
        ],
      ),
    );
  }

  Widget _detailBlock(String label, dynamic value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF546E7A), letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(
            (value == null || value.toString().isEmpty) ? "Not provided" : value.toString(),
            style: const TextStyle(fontSize: 14, color: Color(0xFF1A2E35), height: 1.4),
          ),
        ],
      ),
    );
  }
}
