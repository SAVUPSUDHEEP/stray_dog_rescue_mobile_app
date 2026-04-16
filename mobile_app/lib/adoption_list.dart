import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'dog_details_page.dart';

class AdoptionListPage extends StatefulWidget {
  final String username;

  const AdoptionListPage({super.key, required this.username});

  @override
  State<AdoptionListPage> createState() => _AdoptionListPageState();
}

class _AdoptionListPageState extends State<AdoptionListPage> {
  List allDogs = [];
  List filteredDogs = [];
  bool isLoading = true;

  final TextEditingController breedController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController genderController = TextEditingController();

  final String baseUrl = apiBaseUrl;

  @override
  void initState() {
    super.initState();
    fetchDogs();
  }

  Future<void> fetchDogs() async {
    final response = await http.get(Uri.parse("$baseUrl/adoptions"));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (!mounted) return;
      setState(() {
        allDogs = data;
        filteredDogs = data;
        isLoading = false;
      });
    }
  }

  void applyFilter() {
    String breed = breedController.text.toLowerCase();
    String age = ageController.text;
    String gender = genderController.text.toLowerCase();

    setState(() {
      filteredDogs = allDogs.where((dog) {
        bool breedMatch = breed.isEmpty || (dog['breed'] ?? "").toLowerCase().contains(breed);
        bool ageMatch = age.isEmpty || (dog['age'] ?? "").toString() == age;
        bool genderMatch = gender.isEmpty || (dog['gender'] ?? "").toLowerCase().contains(gender);
        return breedMatch && ageMatch && genderMatch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: CustomScrollView(
        slivers: [
          // Gradient AppBar
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: const Color(0xFF00695C),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Adopt a Dog 🐾', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF00695C), Color(0xFF26A69A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),

          // Filter Section
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 15, offset: const Offset(0, 5)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Find Your Match",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1A2E35)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: breedController,
                          decoration: const InputDecoration(
                            labelText: "Breed",
                            prefixIcon: Icon(Icons.search_rounded, size: 20, color: Color(0xFF00695C)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ageController,
                          decoration: const InputDecoration(
                            labelText: "Age",
                            prefixIcon: Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF00695C)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          style: const TextStyle(fontSize: 14),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: genderController,
                          decoration: const InputDecoration(
                            labelText: "Gender",
                            prefixIcon: Icon(Icons.transgender_rounded, size: 18, color: Color(0xFF00695C)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: applyFilter,
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text("Apply Filter"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Results label
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  "${filteredDogs.length} dog${filteredDogs.length == 1 ? '' : 's'} available",
                  style: const TextStyle(color: Color(0xFF546E7A), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),

          // Dog List
          isLoading
              ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: Color(0xFF00695C))))
              : filteredDogs.isEmpty
                  ? const SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.pets_rounded, size: 64, color: Color(0xFFB0BEC5)),
                            SizedBox(height: 16),
                            Text("No dogs match your preference", style: TextStyle(color: Color(0xFF78909C), fontSize: 16)),
                          ],
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final dog = filteredDogs[index];
                            final imagePaths = (dog['image_path'] ?? "").toString().split(',');
                            final firstImage = imagePaths.isNotEmpty && imagePaths.first.isNotEmpty ? imagePaths.first : null;

                            final imageUrl = firstImage != null
                                ? "$baseUrl/uploads/$firstImage"
                                : null;

                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DogDetailsPage(dog: dog, username: widget.username),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    children: [
                                      // Image
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: imageUrl != null
                                            ? Image.network(
                                                imageUrl,
                                                width: 85,
                                                height: 85,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, e, s) => _placeholderImage(),
                                              )
                                            : _placeholderImage(),
                                      ),
                                      const SizedBox(width: 14),
                                      // Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              dog['dog_name'] != null && dog['dog_name'].toString().toLowerCase() != 'unknown'
                                                  ? "${dog['dog_name']}"
                                                  : "Adorable ${dog['breed'] ?? 'Dog'}",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 16,
                                                color: Color(0xFF1A2E35),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                            if (dog['dog_name'] != null && dog['dog_name'] != 'Unknown')
                                              Text(
                                                dog['breed'] ?? 'Unknown Breed',
                                                style: const TextStyle(color: Color(0xFF78909C), fontSize: 13),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 4,
                                              children: [
                                                _infoChip(Icons.cake_rounded, "${dog['age']} yrs"),
                                                _infoChip(Icons.transgender_rounded, dog['gender'] ?? '-'),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF0F4F8),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: Color(0xFF546E7A)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: filteredDogs.length,
                        ),
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      width: 85,
      height: 85,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.pets_rounded, size: 36, color: Color(0xFFB0BEC5)),
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