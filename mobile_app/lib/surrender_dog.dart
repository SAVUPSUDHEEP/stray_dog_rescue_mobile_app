import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'package:flutter/services.dart';
import 'dart:convert';

class SurrenderDogPage extends StatefulWidget {
  final String username;
  const SurrenderDogPage({super.key, required this.username});

  @override
  State<SurrenderDogPage> createState() => _SurrenderDogPageState();
}

class _SurrenderDogPageState extends State<SurrenderDogPage> {
  List<Uint8List> selectedImages = [];
  bool uploading = false;
  String result = "";
  bool resultSuccess = false;

  final picker = ImagePicker();
  final formKey = GlobalKey<FormState>();

  final reasonCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final behaviorCtrl = TextEditingController();
  final allergiesCtrl = TextEditingController();
  final foodCtrl = TextEditingController();
  final ageCtrl = TextEditingController();
  final genderCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final breedCtrl = TextEditingController();
  final vaccinatedCtrl = TextEditingController();

  Future<void> pickImage() async {
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      List<Uint8List> newBytes = [];
      for (var file in pickedFiles) {
        newBytes.add(await file.readAsBytes());
      }
      
      setState(() { uploading = true; });

      // Validate the first image for clarity
      final bytesToValidate = newBytes.first;

      // 1. AI Output Validation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Validating image clarity with AI..."), duration: Duration(seconds: 2)),
        );
      }

      try {
        final validateUrl = Uri.parse("$apiBaseUrl/validate_photo");
        final validateReq = http.MultipartRequest("POST", validateUrl);
        validateReq.files.add(http.MultipartFile.fromBytes("file", bytesToValidate, filename: "dog_val.jpg"));
        
        final validateRes = await validateReq.send();
        if (validateRes.statusCode == 200) {
          final resBody = await validateRes.stream.bytesToString();
          final data = jsonDecode(resBody);
          if (data["valid"] == false) {
            setState(() { uploading = false; });
            if (mounted) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Color(0xFFF97316)),
                      SizedBox(width: 10),
                      Text("Unclear Photo"),
                    ],
                  ),
                  content: Text(data["reason"] ?? "Please upload a clearer picture of the dog."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Try Again", style: TextStyle(color: Color(0xFFF97316), fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              );
            }
            return; // Stop here if invalid
          }
        }
      } catch (e) {
        debugPrint("Image validation error: $e");
      }

      setState(() { selectedImages.addAll(newBytes); uploading = false; });

      // 2. Auto-detect breed based on the first selected image
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Auto-detecting dog breed..."), duration: Duration(seconds: 2)),
        );
      }

      try {
        final url = Uri.parse("$apiBaseUrl/predict_breed");
        final request = http.MultipartRequest("POST", url);
        request.files.add(http.MultipartFile.fromBytes("file", bytesToValidate, filename: "dog.jpg"));
        
        final response = await request.send();
        if (response.statusCode == 200) {
          final resBody = await response.stream.bytesToString();
          final data = jsonDecode(resBody);
          if (data["breed"] != null && mounted) {
            breedCtrl.text = data["breed"];
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Breed detected: ${data['breed']}")),
            );
          }
        }
      } catch (e) {
        debugPrint("Error detecting breed: $e");
      }
    }
  }

  Future<void> submitSurrender() async {
    if (!formKey.currentState!.validate()) return;

    if (selectedImages.isEmpty) {
      setState(() { result = "Please select at least one image."; resultSuccess = false; });
      return;
    }

    setState(() { uploading = true; result = ""; });

    final url = Uri.parse("$apiBaseUrl/surrender");
    debugPrint("DEBUG: Submitting surrender for user: ${widget.username}");
    final request = http.MultipartRequest("POST", url);

    for (int i = 0; i < selectedImages.length; i++) {
      request.files.add(
        http.MultipartFile.fromBytes("files", selectedImages[i], filename: "dog_$i.jpg"),
      );
    }

    request.fields["username"] = widget.username;
    request.fields["reason"] = reasonCtrl.text;
    request.fields["phone"] = phoneCtrl.text;
    request.fields["Name"] = nameCtrl.text;
    request.fields["behavior"] = behaviorCtrl.text;
    request.fields["allergies"] = allergiesCtrl.text;
    request.fields["food"] = foodCtrl.text;
    request.fields["age"] = ageCtrl.text;
    request.fields["gender"] = genderCtrl.text;
    request.fields["notes"] = notesCtrl.text;
    request.fields["breed"] = breedCtrl.text;
    request.fields["vaccinated"] = vaccinatedCtrl.text;

    final response = await request.send();

    setState(() {
      uploading = false;
      resultSuccess = response.statusCode == 200;
      result = resultSuccess ? "Surrender submitted successfully!" : "Submission failed. Please try again.";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            backgroundColor: const Color(0xFFF97316),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Surrender a Pet 🐕', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFF97316), Color(0xFFFB923C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image picker
                    selectedImages.isNotEmpty
                        ? SizedBox(
                            height: 140,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: selectedImages.length + 1,
                              itemBuilder: (context, index) {
                                if (index == selectedImages.length) {
                                  return GestureDetector(
                                    onTap: pickImage,
                                    child: Container(
                                      width: 100,
                                      margin: const EdgeInsets.only(left: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFFF97316).withAlpha(100), width: 1.5),
                                        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4))],
                                      ),
                                      child: const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.add_photo_alternate_rounded, color: Color(0xFFF97316), size: 28),
                                          SizedBox(height: 5),
                                          Text("Add More", style: TextStyle(color: Color(0xFFF97316), fontSize: 11, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                                return Stack(
                                  children: [
                                    Container(
                                      width: 140,
                                      margin: EdgeInsets.only(left: index == 0 ? 0 : 10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0xFFF97316), width: 1.5),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: Image.memory(selectedImages[index], fit: BoxFit.cover),
                                      ),
                                    ),
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            selectedImages.removeAt(index);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          )
                        : GestureDetector(
                            onTap: pickImage,
                            child: Container(
                              height: 130,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFB0BEC5), width: 1.5),
                                boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Icon(Icons.add_photo_alternate_rounded, size: 36, color: Color(0xFFF97316)),
                                  SizedBox(height: 8),
                                  Text("Upload Pet Photos", textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1A2E35))),
                                  SizedBox(height: 2),
                                  Text("Add at least one clear image", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),
                          ),
                    const SizedBox(height: 24),

                    _sectionHeader("Owner Info"),
                    const SizedBox(height: 12),
                    _styledField("Your Name", nameCtrl, icon: Icons.person_outline_rounded),
                    _styledPhoneField(),

                    _sectionHeader("About the Pet"),
                    const SizedBox(height: 12),
                    _requiredField("Breed", breedCtrl, icon: Icons.pets_rounded),
                    _requiredField("Reason for Surrender", reasonCtrl, icon: Icons.info_outline_rounded),

                    Row(
                      children: [
                        Expanded(
                          child: _ageField(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _styledField("Gender", genderCtrl, icon: Icons.transgender_rounded),
                        ),
                      ],
                    ),

                    _sectionHeader("Health & Behavior"),
                    const SizedBox(height: 12),
                    _styledField("Behavior", behaviorCtrl, icon: Icons.psychology_rounded),
                    _styledField("Allergies", allergiesCtrl, icon: Icons.no_meals_rounded),
                    _styledField("Food Preference", foodCtrl, icon: Icons.restaurant_rounded),
                    _styledField("Vaccinated", vaccinatedCtrl, icon: Icons.vaccines_rounded),

                    _sectionHeader("Additional Notes"),
                    const SizedBox(height: 12),
                    _styledField("Notes", notesCtrl, icon: Icons.notes_rounded, maxLines: 3),

                    const SizedBox(height: 24),

                    // Submit button
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFFB923C)]),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFFF97316).withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: uploading ? null : submitSurrender,
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
                                        Text("Submit Surrender", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
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
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: resultSuccess ? const Color(0xFF22C55E).withValues(alpha: 0.1) : const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: resultSuccess ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(resultSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                                color: resultSuccess ? const Color(0xFF22C55E) : const Color(0xFFEF4444)),
                            const SizedBox(width: 10),
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
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 2),
      child: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A2E35)),
      ),
    );
  }

  Widget _styledField(String label, TextEditingController ctrl, {IconData? icon, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: const Color(0xFFF97316), size: 20) : null,
        ),
      ),
    );
  }

  Widget _requiredField(String label, TextEditingController ctrl, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon, color: const Color(0xFFF97316), size: 20) : null,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return "$label required";
          return null;
        },
      ),
    );
  }

  Widget _styledPhoneField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: phoneCtrl,
        decoration: const InputDecoration(
          labelText: "Phone",
          prefixIcon: Icon(Icons.phone_outlined, color: Color(0xFFF97316), size: 20),
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
    );
  }

  Widget _ageField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ageCtrl,
        decoration: const InputDecoration(
          labelText: "Age",
          prefixIcon: Icon(Icons.cake_rounded, color: Color(0xFFF97316), size: 20),
        ),
        keyboardType: TextInputType.number,
      ),
    );
  }
}