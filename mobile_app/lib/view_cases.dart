import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'case_details_page.dart';


class ViewCasesPage extends StatefulWidget {
  final int? shelterId;
  final String? role;

  const ViewCasesPage({super.key, this.shelterId, this.role});

  @override
  State<ViewCasesPage> createState() => _ViewCasesPageState();
}

class _ViewCasesPageState extends State<ViewCasesPage> {
  List cases = [];
  bool loading = true;

  final String baseUrl = apiBaseUrl;

  String selectedFilter = "all";
  String selectedVaccinatedFilter = "all";

  final List<String> shelterStatuses = [
    "reported",
    "rescued",
    "under_treatment",
    "ready_for_adoption",
    "adopted"
  ];

  final List<String> vetStatuses = [
    "under_treatment",
    "treated",
    "vaccinated"
  ];

  final List<String> filterOptions = [
    "all",
    "reported",
    "rescued",
    "under_treatment",
    "ready_for_adoption",
    "adopted",
    "treated",
    "vaccinated"
  ];

  final List<String> vaccinationOptions = [
    "all",
    "yes",
    "no"
  ];

  @override
  void initState() {
    super.initState();
    fetchCases();
  }

  Future<void> fetchCases() async {
    try {
      String url = "$baseUrl/cases";
      if (widget.shelterId != null) {
        url += "?shelter_id=${widget.shelterId}";
      }

      final res = await http.get(Uri.parse(url));

      if (res.statusCode == 200) {
        setState(() {
          cases = jsonDecode(res.body);
          loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => loading = false);
    }
  }

  String formatDate(String rawDate) {
    DateTime dt = DateTime.parse(rawDate);
    return "${dt.day}/${dt.month}/${dt.year}  ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
  }

  Future<void> _openMap(dynamic lat, dynamic lng) async {
    if (lat == null || lng == null) return;
    final Uri url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      await launchUrl(url);
    } catch (e) {
      debugPrint('Could not launch $url : $e');
    }
  }

  Future<void> updateStatus(int id, String status, String initialBreed, {bool skipDialog = false}) async {
    try {
      if (status == "ready_for_adoption" && !skipDialog) {
        showMoveToAdoptionDialog(id, initialBreed);
        return;
      }

      final res = await http.put(
        Uri.parse("$baseUrl/cases/$id"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"case_status": status}),
      );

      if (res.statusCode == 200) {
        fetchCases();
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> moveToAdoption(int id, Map<String, dynamic> dogData, {XFile? imageFile}) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse("$baseUrl/move_to_adoption"));
      request.fields['source'] = 'case';
      request.fields['id'] = id.toString();
      request.fields['dog_name'] = dogData['dog_name'] ?? '';
      request.fields['breed'] = dogData['breed'] ?? '';
      request.fields['color'] = dogData['color'] ?? '';
      request.fields['age'] = dogData['age']?.toString() ?? '';
      request.fields['gender'] = dogData['gender'] ?? '';
      request.fields['vaccination_status'] = dogData['vaccination_status'] ?? '';
      request.fields['behavior_description'] = dogData['behavior_description'] ?? '';

      if (imageFile != null) {
        final bytes = await imageFile.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: imageFile.name));
      }

      await request.send();
    } catch (e) {
      debugPrint("Move error: $e");
    }
  }

  void showMoveToAdoptionDialog(int id, String initialBreed) {
    final nameController = TextEditingController();
    final breedController = TextEditingController(text: initialBreed);
    final colorController = TextEditingController();
    final ageController = TextEditingController();
    String selectedGender = "Female";
    String selectedVaccination = "Yes";
    final behaviorController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    
    XFile? selectedImage;
    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Move to Adoption 🐾", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A2E35))),
                    const SizedBox(height: 4),
                    const Text("Add final dog details", style: TextStyle(color: Color(0xFF78909C), fontSize: 13)),
                    const SizedBox(height: 20),
                    _dialogField(nameController, "Dog Name", Icons.pets_rounded),
                    _dialogField(breedController, "Breed", Icons.category_rounded),
                    _dialogField(colorController, "Color", Icons.color_lens_rounded),
                    _dialogField(ageController, "Age", Icons.cake_rounded),
                    _dialogDropdown(
                      "Gender",
                      Icons.transgender_rounded,
                      selectedGender,
                      ["Male", "Female", "Unknown"],
                      (val) => selectedGender = val!,
                    ),
                    _dialogDropdown(
                      "Vaccination Status",
                      Icons.vaccines_rounded,
                      selectedVaccination,
                      ["Yes", "No", "Unknown"],
                      (val) => selectedVaccination = val!,
                    ),
                    _dialogField(behaviorController, "Behavior Description", Icons.psychology_rounded),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final image = await picker.pickImage(source: ImageSource.gallery);
                        if (image != null) {
                          setState(() {
                            selectedImage = image;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: selectedImage != null ? const Color(0xFFE8F5E9) : const Color(0xFFF0F4F8),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: selectedImage != null ? const Color(0xFF22C55E) : const Color(0xFF00695C).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Icon(selectedImage != null ? Icons.check_circle_rounded : Icons.add_photo_alternate_rounded, size: 28, color: selectedImage != null ? const Color(0xFF22C55E) : const Color(0xFF00695C)),
                            const SizedBox(height: 8),
                            Text(selectedImage != null ? "New Image Selected" : "Upload New Photo (Optional)", style: TextStyle(fontSize: 13, color: selectedImage != null ? const Color(0xFF15803D) : const Color(0xFF00695C), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Color(0xFFB0BEC5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text("Cancel", style: TextStyle(color: Color(0xFF546E7A))),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (!formKey.currentState!.validate()) return;
                              final nav = Navigator.of(dialogContext);

                              showDialog(
                                context: dialogContext,
                                barrierDismissible: false,
                                builder: (loadingContext) => const Center(child: CircularProgressIndicator(color: Color(0xFF00695C))),
                              );

                              await moveToAdoption(id, {
                                "dog_name": nameController.text,
                                "breed": breedController.text,
                                "color": colorController.text,
                                "age": ageController.text,
                                "gender": selectedGender,
                                "vaccination_status": selectedVaccination,
                                "behavior_description": behaviorController.text,
                              }, imageFile: selectedImage);

                              nav.pop();
                              nav.pop();
                              updateStatus(id, "ready_for_adoption", breedController.text, skipDialog: true);
                            },
                            child: const Text("Submit"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
            );
          },
        );
      },
    );
  }

  Widget _dialogField(TextEditingController ctrl, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF00695C), size: 20),
        ),
        validator: (value) => value!.isEmpty ? "Required" : null,
      ),
    );
  }

  Widget _dialogDropdown(String label, IconData icon, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF00695C), size: 20),
        ),
        items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget statusChip(String status) {
    Color color;
    switch (status) {
      case "reported": color = const Color(0xFF546E7A); break;
      case "rescued": color = const Color(0xFF0284C7); break;
      case "under_treatment": color = const Color(0xFFF97316); break;
      case "treated": color = const Color(0xFF22C55E); break;
      case "vaccinated": color = const Color(0xFF0284C7); break;
      case "ready_for_adoption": color = const Color(0xFF7C3AED); break;
      case "adopted": color = const Color(0xFF10B981); break;
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
        status.replaceAll("_", " ").toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
      ),
    );
  }

  Widget buildCaseList(List casesList) {
    if (casesList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(22)),
              child: const Icon(Icons.assignment_outlined, size: 36, color: Color(0xFFB0BEC5)),
            ),
            const SizedBox(height: 16),
            const Text("No Cases Found", style: TextStyle(color: Color(0xFF78909C), fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchCases,
      color: const Color(0xFF00695C),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedFilter,
                    decoration: const InputDecoration(
                      labelText: "Status",
                      prefixIcon: Icon(Icons.filter_list_rounded, color: Color(0xFF00695C), size: 20),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: filterOptions.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status.replaceAll("_", " "), style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() { selectedFilter = value!; });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedVaccinatedFilter,
                    decoration: const InputDecoration(
                      labelText: "Vaccinated",
                      prefixIcon: Icon(Icons.vaccines_rounded, color: Color(0xFF00695C), size: 20),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: vaccinationOptions.map((v) {
                      return DropdownMenuItem(
                        value: v,
                        child: Text(v == "all" ? "All" : v == "yes" ? "Yes" : "No", style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() { selectedVaccinatedFilter = value!; });
                    },
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              itemCount: casesList.length,
              itemBuilder: (context, index) {
                final c = casesList[index];
                final status = c['case_status'];
                final isAdopted = status == "adopted";

                final imageUrl = c['image_path'] != null
                    ? "$baseUrl/uploads/${c['image_path']}"
                    : null;

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CaseDetailsPage(caseData: c, role: widget.role)),
                    ).then((_) => fetchCases());
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
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
                        // Top row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: imageUrl != null
                                  ? Image.network(
                                      imageUrl, width: 90, height: 90, fit: BoxFit.cover,
                                      errorBuilder: (_, e, s) => _placeholder(),
                                    )
                                  : _placeholder(),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("Case #${c['id']}", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1A2E35))),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Wrap(
                                          alignment: WrapAlignment.end,
                                          spacing: 4,
                                          runSpacing: 4,
                                          children: [
                                            if (c['priority'] == 'HIGH')
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                                                ),
                                                child: const Text(
                                                  "⚠️ HIGH",
                                                  style: TextStyle(color: Color(0xFFB91C1C), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                                                ),
                                              ),
                                            statusChip(status),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  _caseInfoRow(Icons.pets_rounded, c['predicted_breed'] ?? 'Unknown'),
                                  // Fused injury assessment
                                  () {
                                    final aiRaw = (c['ai_injury_status'] ?? c['injury_status'] ?? '').toString().toLowerCase();
                                    final userRaw = (c['reported_injury_status'] ?? '').toString().toLowerCase();

                                    if (userRaw.isEmpty) {
                                      // Standalone report — show AI result only
                                      return _caseInfoRow(Icons.medical_services_rounded, c['injury_status'] ?? 'N/A');
                                    }

                                    final aiInjured = aiRaw.contains('injured') && !aiRaw.contains('not');
                                    final userInjured = userRaw == 'yes';
                                    final userUnsure = userRaw == 'not sure';

                                    if (aiInjured && userInjured) {
                                      return _caseInfoRowColored(
                                        Icons.medical_services_rounded,
                                        "Injury Confirmed",
                                        const Color(0xFFEF4444),
                                      );
                                    } else if (!aiInjured && !userInjured && !userUnsure) {
                                      return _caseInfoRowColored(
                                        Icons.check_circle_rounded,
                                        "No Injury Detected",
                                        const Color(0xFF22C55E),
                                      );
                                    } else {
                                      // Conflict or uncertainty — show neutral verification needed
                                      return _caseInfoRowColored(
                                        Icons.manage_search_rounded,
                                        "Needs Field Verification",
                                        const Color(0xFFF59E0B),
                                      );
                                    }
                                  }(),
                                  const SizedBox(height: 4),
                                  if (c['latitude'] != null && c['longitude'] != null)
                                    InkWell(
                                      onTap: () => _openMap(c['latitude'], c['longitude']),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.location_on_rounded, size: 14, color: Color(0xFF0284C7)),
                                            SizedBox(width: 4),
                                            Text("View on Maps", style: TextStyle(color: Color(0xFF0284C7), fontSize: 12, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ),
                                    )
                                  else
                                    const Text("Location unavailable", style: TextStyle(color: Color(0xFFB0BEC5), fontSize: 12, fontStyle: FontStyle.italic)),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Reported: ${formatDate(c['created_at'])}",
                                    style: const TextStyle(fontSize: 11, color: Color(0xFFB0BEC5)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Status update row
                        Row(
                          children: [
                            Expanded(
                              child: Builder(builder: (context) {
                                final currentStatuses = widget.role == "vet" ? vetStatuses : shelterStatuses;
                                final isAdopted = status == "adopted";
                                final canUpdate = !isAdopted && (widget.role != "vet" || currentStatuses.contains(status) || status == "rescued");

                                return DropdownButtonFormField(
                                  value: currentStatuses.contains(status) ? status : (widget.role == "vet" ? "under_treatment" : status),
                                  decoration: const InputDecoration(
                                    labelText: "Update Status",
                                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  ),
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF1A2E35)),
                                  items: currentStatuses.map((s) {
                                    return DropdownMenuItem(value: s, child: Text(s.replaceAll("_", " ")));
                                  }).toList(),
                                  onChanged: !canUpdate ? null : (val) {
                                    setState(() { c['case_status'] = val; });
                                  },
                                );
                              }),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              child: ElevatedButton(
                                onPressed: !(!isAdopted && (widget.role != "vet" || (widget.role == "vet" ? vetStatuses : shelterStatuses).contains(status) || status == "rescued"))
                                    ? null
                                    : () {
                                        if (c['case_status'] == 'ready_for_adoption') {
                                          showMoveToAdoptionDialog(c['id'], c['predicted_breed'] ?? '');
                                        } else {
                                          updateStatus(c['id'], c['case_status']!, c['predicted_breed'] ?? '');
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: !(!isAdopted && (widget.role != "vet" || (widget.role == "vet" ? vetStatuses : shelterStatuses).contains(status) || status == "rescued")) ? const Color(0xFFB0BEC5) : const Color(0xFF00695C),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                                ),
                                child: Text(isAdopted ? "Closed" : "Update", style: const TextStyle(fontSize: 14)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            ),
          ),
        ],
      ),
    );
  }

  Widget _caseInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: const Color(0xFF00695C)),
          const SizedBox(width: 4),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: Color(0xFF546E7A)), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _caseInfoRowColored(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 90, height: 90,
      decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(14)),
      child: const Icon(Icons.pets_rounded, size: 36, color: Color(0xFFB0BEC5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rescue Cases')),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF00695C))),
      );
    }

    var filteredCases = selectedFilter == "all"
        ? cases
        : cases.where((c) => c['case_status'] == selectedFilter).toList();

    if (selectedVaccinatedFilter != "all") {
      filteredCases = filteredCases.where((c) => (c['vaccination_status'] == null ? 'no' : c['vaccination_status'].toString().toLowerCase()) == selectedVaccinatedFilter).toList();
    }

    final injuredCases = filteredCases.where((c) {
      final aiStatus = (c['ai_injury_status'] ?? c['injury_status'] ?? '').toString().toLowerCase();
      final userStatus = (c['reported_injury_status'] ?? '').toString().toLowerCase();
      return aiStatus == 'injured' || userStatus == 'yes';
    }).toList();
    
    final nonInjuredCases = filteredCases.where((c) {
      final aiStatus = (c['ai_injury_status'] ?? c['injury_status'] ?? '').toString().toLowerCase();
      final userStatus = (c['reported_injury_status'] ?? '').toString().toLowerCase();
      return aiStatus != 'injured' && userStatus != 'yes';
    }).toList();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F4F8),
        appBar: AppBar(
          title: const Text('Rescue Cases'),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF00695C), Color(0xFF26A69A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          bottom: TabBar(
            tabs: [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.list_rounded, size: 16),
                    const SizedBox(width: 4),
                    Text("All (${filteredCases.length})"),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_rounded, size: 16),
                    const SizedBox(width: 4),
                    Text("Injured (${injuredCases.length})"),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 16),
                    const SizedBox(width: 4),
                    Text("Safe (${nonInjuredCases.length})"),
                  ],
                ),
              ),
            ],
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
        body: TabBarView(
          children: [
            buildCaseList(filteredCases),
            buildCaseList(injuredCases),
            buildCaseList(nonInjuredCases),
          ],
        ),
      ),
    );
  }
}