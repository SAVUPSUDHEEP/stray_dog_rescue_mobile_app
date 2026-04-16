import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'package:url_launcher/url_launcher.dart';

class CaseDetailsPage extends StatefulWidget {
  final Map caseData;
  final String? role;

  const CaseDetailsPage({super.key, required this.caseData, this.role});

  @override
  State<CaseDetailsPage> createState() => _CaseDetailsPageState();
}

class _CaseDetailsPageState extends State<CaseDetailsPage> {
  final String baseUrl = apiBaseUrl;
  
  late String currentStatus;
  late String vaccinationStatus;
  late TextEditingController notesController;
  bool isUpdating = false;

  @override
  void initState() {
    super.initState();
    currentStatus = widget.caseData['case_status'] ?? 'reported';
    vaccinationStatus = widget.caseData['vaccination_status'] ?? 'no';
    notesController = TextEditingController(text: widget.caseData['medical_notes'] ?? '');
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  Future<void> updateMedicalRecord() async {
    setState(() => isUpdating = true);
    try {
      final res = await http.put(
        Uri.parse("$baseUrl/cases/${widget.caseData['id']}"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "case_status": currentStatus,
          "vaccination_status": vaccinationStatus,
          "medical_notes": notesController.text,
        }),
      );

      if (!mounted) return;
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Medical record updated successfully! 🏥"), backgroundColor: Color(0xFF22C55E)),
        );
      } else {
        throw Exception("Failed to update");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: const Color(0xFFEF4444)),
      );
    } finally {
      if (mounted) setState(() => isUpdating = false);
    }
  }

  String formatDate(String? rawDate) {
    if (rawDate == null) return "Unknown";
    try {
      DateTime dt = DateTime.parse(rawDate);
      return "${dt.day}/${dt.month}/${dt.year}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return rawDate;
    }
  }

  Future<void> _openMap(dynamic lat, dynamic lng) async {
    if (lat == null || lng == null) return;
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      await launchUrl(url);
    } catch (e) {
      debugPrint('Could not launch Google Maps: $e');
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
    final imageUrl = widget.caseData['image_path'] != null ? "$baseUrl/uploads/${widget.caseData['image_path']}" : null;
    final lat = widget.caseData['latitude'];
    final lng = widget.caseData['longitude'];
    final isVet = widget.role == "vet";

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: Text("Case #${widget.caseData['id']}"),
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
                color: Colors.black,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.pets, size: 80, color: Colors.grey)),
                    )
                  : const Center(child: Icon(Icons.pets, size: 80, color: Colors.grey)),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.caseData['priority'] != null) ...[
                    _priorityBadge(widget.caseData['priority']),
                    const SizedBox(height: 16),
                  ],

                  // ─── MEDICAL RECORD (VET ONLY) ───
                  if (isVet) ...[
                    const Text("Update Medical Record 🏥", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A2E35))),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 5))],
                      ),
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: ["under_treatment", "treated", "vaccinated"].contains(currentStatus) ? currentStatus : "under_treatment",
                            decoration: const InputDecoration(labelText: "Clinical Status", prefixIcon: Icon(Icons.medical_information_rounded, color: Color(0xFF00695C))),
                            items: const [
                              DropdownMenuItem(value: "under_treatment", child: Text("Under Treatment")),
                              DropdownMenuItem(value: "treated", child: Text("Treated")),
                              DropdownMenuItem(value: "vaccinated", child: Text("Vaccinated")),
                            ],
                            onChanged: (val) => setState(() => currentStatus = val!),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: vaccinationStatus,
                            decoration: const InputDecoration(labelText: "Vaccination Status", prefixIcon: Icon(Icons.vaccines_rounded, color: Color(0xFF00695C))),
                            items: const [
                              DropdownMenuItem(value: "yes", child: Text("Vaccinated")),
                              DropdownMenuItem(value: "no", child: Text("Not Vaccinated")),
                            ],
                            onChanged: (val) => setState(() => vaccinationStatus = val!),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: notesController,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: "Medical Notes",
                              hintText: "Add treatment details, medications...",
                              alignLabelWithHint: true,
                              prefixIcon: Padding(padding: EdgeInsets.only(bottom: 40), child: Icon(Icons.notes_rounded, color: Color(0xFF00695C))),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00695C),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: isUpdating ? null : updateMedicalRecord,
                              child: isUpdating
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text("Save Medical Record", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],

                  const Text("Case Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A2E35))),
                  const SizedBox(height: 12),
                  _infoCard("Predicted Breed", widget.caseData['predicted_breed'] ?? 'Unknown', Icons.pets),
                  _infoCard("Case Status", currentStatus.replaceAll("_", " ").toUpperCase(), Icons.info_outline),
                  if (widget.caseData['medical_notes'] != null && !isVet)
                    _infoCard("Medical Notes", widget.caseData['medical_notes'], Icons.medical_services_rounded, iconColor: const Color(0xFFF97316)),
                  _infoCard("Reported Date", formatDate(widget.caseData['created_at']), Icons.calendar_today_rounded),
                  _infoCard("Location", lat != null && lng != null ? "$lat, $lng" : "Not Provided", Icons.location_on_rounded, iconColor: const Color(0xFF0284C7)),

                  const SizedBox(height: 20),
                  const Text("Injury Assessment", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A2E35))),
                  const SizedBox(height: 12),

                  () {
                    final aiRaw = (widget.caseData['ai_injury_status'] ?? widget.caseData['injury_status'] ?? '').toString().toLowerCase();
                    final userRaw = (widget.caseData['reported_injury_status'] ?? '').toString().toLowerCase();

                    if (userRaw.isEmpty) {
                      return _infoCard("Injury Status", (widget.caseData['injury_status'] ?? 'Unknown').toUpperCase(), Icons.medical_services_rounded, iconColor: const Color(0xFFE53935));
                    }

                    final aiInjured = aiRaw.contains('injured') && !aiRaw.contains('not');
                    final userInjured = userRaw == 'yes';
                    final userUnsure = userRaw == 'not sure';

                    if (aiInjured && userInjured) {
                      return _infoCard("Assessment", "Injury Confirmed", Icons.medical_services_rounded, iconColor: const Color(0xFFEF4444));
                    } else if (!aiInjured && !userInjured && !userUnsure) {
                      return _infoCard("Assessment", "No Injury Detected", Icons.check_circle_rounded, iconColor: const Color(0xFF22C55E));
                    } else {
                      return _infoCard("Assessment", "Needs Field Verification", Icons.manage_search_rounded, iconColor: const Color(0xFFF59E0B));
                    }
                  }(),

                  if (widget.caseData['reported_injury_type'] != null)
                    _infoCard("Reporter Observed", widget.caseData['reported_injury_type'].toString(), Icons.visibility_rounded, iconColor: const Color(0xFF0284C7)),
                  if (widget.caseData['reported_severity'] != null)
                    _infoCard("Reported Severity", widget.caseData['reported_severity'].toString().toUpperCase(), Icons.warning_amber_rounded, iconColor: const Color(0xFFF97316)),

                  const SizedBox(height: 24),
                  if (lat != null && lng != null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.map_rounded, color: Colors.white),
                        label: const Text("Open in Google Maps", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600)),
                        onPressed: () => _openMap(lat, lng),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _priorityBadge(String? priority) {
    final isHigh = priority == "HIGH";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isHigh ? const Color(0xFFEF4444).withValues(alpha: 0.1) : const Color(0xFF22C55E).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isHigh ? const Color(0xFFEF4444).withValues(alpha: 0.4) : const Color(0xFF22C55E).withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isHigh ? Icons.priority_high_rounded : Icons.check_circle_rounded, color: isHigh ? const Color(0xFFEF4444) : const Color(0xFF22C55E), size: 18),
          const SizedBox(width: 8),
          Text(isHigh ? "⚠️ HIGH PRIORITY CASE" : "✅ NORMAL PRIORITY", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isHigh ? const Color(0xFFB91C1C) : const Color(0xFF15803D), letterSpacing: 0.4)),
        ],
      ),
    );
  }
}
