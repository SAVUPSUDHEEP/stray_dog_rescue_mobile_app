import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'package:flutter/services.dart';

class DogDetailsPage extends StatelessWidget {
  final Map dog;
  final String username;
  final bool isAdmin;

  const DogDetailsPage({
    super.key,
    required this.dog,
    required this.username,
    this.isAdmin = false,
  });

  final String baseUrl = apiBaseUrl;

  void showAdoptionDialog(BuildContext context) {
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Adoption Request 🐾",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A2E35)),
                  ),
                  const SizedBox(height: 4),
                  const Text("Fill in your contact details", style: TextStyle(color: Color(0xFF78909C), fontSize: 14)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: "Phone",
                      prefixIcon: Icon(Icons.phone_outlined, color: Color(0xFF00695C)),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) return "Phone required";
                      if (value.length != 10) return "Enter 10 digit number";
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: "Address",
                      prefixIcon: Icon(Icons.home_outlined, color: Color(0xFF00695C)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return "Address required";
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
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

                            final navigator = Navigator.of(context);
                            final messenger = ScaffoldMessenger.of(context);

                            await http.post(
                              Uri.parse("$baseUrl/adoption_request"),
                              headers: {"Content-Type": "application/json"},
                              body: jsonEncode({
                                "adoption_id": dog['id'],
                                "username": username,
                                "phone": phoneController.text,
                                "address": addressController.text,
                              }),
                            );

                            navigator.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: const Text("Request Sent Successfully! 🎉"),
                                backgroundColor: const Color(0xFF22C55E),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: const Color(0xFF00695C),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                dog['dog_name'] != null && dog['dog_name'] != 'Unknown'
                    ? dog['dog_name']
                    : (dog['breed'] ?? "Dog"),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              background: Builder(
                builder: (context) {
                  final imagePaths = (dog['image_path'] ?? "").toString().split(',');
                  final validPaths = imagePaths.where((p) => p.isNotEmpty).toList();

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Colors.black),
                      if (validPaths.isNotEmpty)
                        PageView.builder(
                          itemCount: validPaths.length,
                          itemBuilder: (context, index) {
                            return Image.network(
                              "$baseUrl/uploads/${validPaths[index]}",
                              fit: BoxFit.contain, // Maintain original aspect ratio
                              errorBuilder: (_, e, s) => Container(
                                color: const Color(0xFF00695C),
                                child: const Icon(Icons.pets_rounded, size: 80, color: Colors.white30),
                              ),
                            );
                          },
                        )
                      else
                        Container(
                          color: const Color(0xFF00695C),
                          child: const Icon(Icons.pets_rounded, size: 80, color: Colors.white30),
                        ),
                      // Gradient overlay
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0x77000000)],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick stats row
                  Row(
                    children: [
                      _statCard(Icons.cake_rounded, "Age", "${dog['age'] ?? 'N/A'}"),
                      const SizedBox(width: 12),
                      _statCard(Icons.transgender_rounded, "Gender", dog['gender'] ?? 'N/A'),
                      const SizedBox(width: 12),
                      _statCard(Icons.color_lens_rounded, "Color", dog['color'] ?? 'N/A'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _sectionCard("About", [
                    _infoRow(Icons.pets_rounded, "Breed", dog['breed'] ?? 'Unknown'),
                    _infoRow(Icons.location_on_rounded, "Location", dog['location'] ?? 'Not provided'),
                    _infoRow(Icons.vaccines_rounded, "Vaccinated", dog['vaccination_status'] ?? dog['vaccinated'] ?? 'Not provided'),
                  ]),
                  const SizedBox(height: 14),

                  _sectionCard("Behavior & Health", [
                    _infoRow(Icons.psychology_rounded, "Behavior", dog['behavior_description'] ?? dog['behavior'] ?? 'Not provided'),
                    _infoRow(Icons.no_meals_rounded, "Allergies", dog['allergies'] ?? 'Not provided'),
                    _infoRow(Icons.restaurant_rounded, "Food", dog['food'] ?? 'Not provided'),
                  ]),
                  const SizedBox(height: 14),

                  if ((dog['notes'] ?? '').isNotEmpty) ...[
                    _sectionCard("Notes", [
                      _infoRow(Icons.notes_rounded, "Additional Info", dog['notes'] ?? 'Not provided'),
                    ]),
                    const SizedBox(height: 14),
                  ],

                  // Adopt button
                  if (!isAdmin)
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
                          onTap: () => showAdoptionDialog(context),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.favorite_rounded, color: Colors.white, size: 20),
                                  SizedBox(width: 10),
                                  Text(
                                    "Request Adoption",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
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
            Icon(icon, color: const Color(0xFF00695C), size: 22),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF78909C))),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A2E35)), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(String title, List<Widget> rows) {
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
          ...rows,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF00695C)),
          const SizedBox(width: 10),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF546E7A), fontSize: 14)),
          Expanded(child: Text(value, style: const TextStyle(color: Color(0xFF1A2E35), fontSize: 14))),
        ],
      ),
    );
  }
}