import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

// ─────────────────────────────────────────────
// Data models
// ─────────────────────────────────────────────
class ChatMessage {
  final String text;
  final bool isUser;
  final List<String>? chips; // quick-reply options
  final bool isTriagePrompt;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.chips,
    this.isTriagePrompt = false,
  });
}

// ─────────────────────────────────────────────
// Triage state
// ─────────────────────────────────────────────
enum TriageStep { idle, askInjured, askType, askSeverity, awaitingImage }

// ─────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────
class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage>
    with SingleTickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  // ── Triage state ──
  TriageStep _triageStep = TriageStep.idle;
  String? _reportedInjuryStatus; // yes / no / not sure
  String? _reportedInjuryType;
  String? _reportedSeverity;

  // ── Camera glow animation ──
  late AnimationController _cameraGlowController;
  late Animation<double> _cameraGlowAnimation;

  final String baseUrl = apiBaseUrl;
  final ImagePicker _picker = ImagePicker();

  // ─── Rescue trigger keywords ───────────────
  static final List<RegExp> _rescuePatterns = [
    RegExp(r'\b(stray|street)\s+dog\b', caseSensitive: false),
    RegExp(r'\bfound\s+a\s+dog\b', caseSensitive: false),
    RegExp(r'\bdog\s+(on|near|by|at)\b', caseSensitive: false),
    RegExp(r'\bdog\s+needs\s+help\b', caseSensitive: false),
    RegExp(r'\binjured\s+dog\b', caseSensitive: false),
    RegExp(r'\bi\s+see\s+a\s+dog\b', caseSensitive: false),
    RegExp(r'\bthere\s+is\s+a\s+dog\b', caseSensitive: false),
    RegExp(r'\brescue\s+(a\s+)?dog\b', caseSensitive: false),
    RegExp(r'\bdog\s+hurt\b', caseSensitive: false),
    RegExp(r'\bhurt\s+dog\b', caseSensitive: false),
    RegExp(r'\bdog\s+in\s+(pain|trouble|danger)\b', caseSensitive: false),
    RegExp(r'\bdog\s+outside\b', caseSensitive: false),
    RegExp(r'\bdog\s+on\s+road\b', caseSensitive: false),
    RegExp(r'\bdog\s+lying\b', caseSensitive: false),
    RegExp(r'\babandon(ed)?\s+dog\b', caseSensitive: false),
  ];

  bool _isRescueTrigger(String text) =>
      _rescuePatterns.any((p) => p.hasMatch(text));

  @override
  void initState() {
    super.initState();

    _cameraGlowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _cameraGlowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _cameraGlowController, curve: Curves.easeInOut),
    );

    _messages.add(ChatMessage(
      text:
          "Hello! 🐾 I am the Street Dog Rescue Assistant.\n\n"
          "I can help you:\n"
          "• 🚨 Report an injured or stray dog\n"
          "• 🐶 Browse dogs available for adoption\n"
          "• 💬 Answer pet care questions\n\n"
          "How can I help you today?",
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _cameraGlowController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  // Triage flow controller
  // ─────────────────────────────────────────
  void _startTriage() {
    // Reset state
    _reportedInjuryStatus = null;
    _reportedInjuryType = null;
    _reportedSeverity = null;
    _triageStep = TriageStep.askInjured;

    _addBotMessage(
      "Got it! 🐾 Let me help you report this.\n\nIs the dog injured?",
      chips: ["Yes 🤕", "No ✅", "Not sure 🤔"],
      isTriagePrompt: true,
    );
  }

  void _handleTriageChip(String chip) {
    // Show user's choice as a normal message
    setState(() {
      _messages.add(ChatMessage(text: chip, isUser: true));
    });
    _scrollToBottom();

    switch (_triageStep) {
      case TriageStep.askInjured:
        if (chip.startsWith("Yes")) {
          _reportedInjuryStatus = "yes";
          _triageStep = TriageStep.askType;
          _addBotMessage(
            "What kind of injury do you notice?",
            chips: [
              "Bleeding 🩸",
              "Broken leg 🦴",
              "Limping 🐕",
              "Wound",
              "Fracture",
              "Skin issue",
              "Unable to walk",
              "Unknown",
            ],
            isTriagePrompt: true,
          );
        } else if (chip.startsWith("No")) {
          _reportedInjuryStatus = "no";
          _triageStep = TriageStep.awaitingImage;
          _addBotMessage(
            "Understood! 📋 The dog appears safe.\n\nPlease tap the 📷 camera button below to upload a photo so we can log the case and dispatch a team.",
            chips: null,
          );
        } else {
          // Not sure
          _reportedInjuryStatus = "not sure";
          _triageStep = TriageStep.askType;
          _addBotMessage(
            "No worries! Let's gather more info.\n\nDo you notice anything that looks like an injury? Pick the closest match:",
            chips: [
              "Bleeding 🩸",
              "Broken leg 🦴",
              "Limping 🐕",
              "Wound",
              "Fracture",
              "Skin issue",
              "Unable to walk",
              "Unknown",
            ],
            isTriagePrompt: true,
          );
        }
        break;

      case TriageStep.askType:
        // Strip emoji from chip for cleaner DB value
        _reportedInjuryType =
            chip.replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();
        _triageStep = TriageStep.askSeverity;
        _addBotMessage(
          "How severe does it look?",
          chips: ["Mild", "Moderate", "Severe 🚨", "Critical 🆘", "Not sure"],
          isTriagePrompt: true,
        );
        break;

      case TriageStep.askSeverity:
        _reportedSeverity =
            chip.replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();
        _triageStep = TriageStep.awaitingImage;
        _addBotMessage(
          "Thank you for those details! 📋\n\n"
          "Here's what we've recorded:\n"
          "• Injured: ${_reportedInjuryStatus ?? 'not specified'}\n"
          "• Type: ${_reportedInjuryType ?? 'not specified'}\n"
          "• Severity: ${_reportedSeverity ?? 'not specified'}\n\n"
          "Now please tap the 📷 camera button below to upload a photo of the dog. "
          "Our AI will scan it and alert the nearest rescue team immediately!",
          chips: null,
        );
        break;

      default:
        break;
    }
  }

  // ─────────────────────────────────────────
  // Image report (after triage or direct)
  // ─────────────────────────────────────────
  Future<void> _reportViaImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();

    setState(() {
      _messages.add(ChatMessage(
          text: "📷 Image selected. Getting your location and submitting report...",
          isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    // Location
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _addBotMessage("Please enable location services to submit a report.");
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      _addBotMessage("Location permission denied. Cannot submit report.");
      return;
    }

    Position position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (e) {
      _addBotMessage("Failed to get your location. Please try again.");
      return;
    }

    // Build multipart request with triage fields if available
    final url = Uri.parse('$baseUrl/report');
    final request = http.MultipartRequest('POST', url);
    request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: 'chat_dog.jpg'));
    request.fields['latitude'] = position.latitude.toString();
    request.fields['longitude'] = position.longitude.toString();

    if (_reportedInjuryStatus != null) {
      request.fields['reported_injury_status'] = _reportedInjuryStatus!;
    }
    if (_reportedInjuryType != null) {
      request.fields['reported_injury_type'] = _reportedInjuryType!;
    }
    if (_reportedSeverity != null) {
      request.fields['reported_severity'] = _reportedSeverity!;
    }

    try {
      final response = await request.send();
      final resBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(resBody);
        final caseId =
            data['case_id'] != null ? data['case_id'].toString() : "N/A";
        final priority = data['priority'] ?? "NORMAL";
        final priorityBadge =
            priority == "HIGH" ? " ⚠️ High Priority" : " ✅ Normal Priority";

        _addBotMessage(
          "✅ Report Submitted Successfully!\n\n"
          "📌 Case ID: $caseId\n"
          "🏥 Priority: $priorityBadge\n\n"
          "The nearest rescue team has been alerted. Thank you for helping this dog! 🐾",
        );

        // Reset triage after successful report
        setState(() {
          _triageStep = TriageStep.idle;
          _reportedInjuryStatus = null;
          _reportedInjuryType = null;
          _reportedSeverity = null;
        });
      } else {
        _addBotMessage("❌ Upload failed. Please try again.\n$resBody");
      }
    } catch (e) {
      _addBotMessage("❌ Network error: $e");
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  // ─────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────
  void _addBotMessage(String text,
      {List<String>? chips, bool isTriagePrompt = false}) {
    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(
          text: text,
          isUser: false,
          chips: chips,
          isTriagePrompt: isTriagePrompt,
        ));
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─────────────────────────────────────────
  // Text submit (routes to triage OR Gemini)
  // ─────────────────────────────────────────
  Future<void> _handleSubmitted(String text) async {
    _textController.clear();
    if (text.trim().isEmpty) return;

    // If actively in triage, treat text as free-form triage response
    if (_triageStep != TriageStep.idle &&
        _triageStep != TriageStep.awaitingImage) {
      setState(() {
        _messages.add(ChatMessage(text: text, isUser: true));
      });
      _scrollToBottom();
      // Map the text response to the appropriate triage handler
      _handleFreeFormTriage(text);
      return;
    }

    // Check for rescue trigger keyword
    if (_triageStep == TriageStep.idle && _isRescueTrigger(text)) {
      setState(() {
        _messages.add(ChatMessage(text: text, isUser: true));
      });
      _scrollToBottom();
      _startTriage();
      return;
    }

    // --- Regular Gemini chat ---
    List<Map<String, dynamic>> historyObj = _messages
        .where((m) => !m.isTriagePrompt) // exclude triage prompts from AI ctx
        .map((m) => {"isUser": m.isUser, "text": m.text})
        .toList();

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final res = await http.post(
        Uri.parse("$baseUrl/chat"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": text, "history": historyObj}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final responseText = data['response'] as String;

        // If Gemini tells the user to report, intercept and start triage
        if (_isRescueTrigger(text) || _isRescueTrigger(responseText)) {
          _startTriage();
        } else {
          _addBotMessage(responseText);
        }
      } else {
        _addBotMessage("Sorry, I'm having trouble connecting to the server.");
      }
    } catch (e) {
      if (mounted) _addBotMessage("Network error occurred: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Handle free-form text typed during triage (instead of chip tap)
  void _handleFreeFormTriage(String text) {
    switch (_triageStep) {
      case TriageStep.askInjured:
        final lower = text.toLowerCase();
        if (lower.contains("yes") || lower.contains("injur") || lower.contains("hurt")) {
          _handleTriageChip("Yes 🤕");
        } else if (lower.contains("no") || lower.contains("fine") || lower.contains("safe")) {
          _handleTriageChip("No ✅");
        } else {
          _handleTriageChip("Not sure 🤔");
        }
        break;
      case TriageStep.askType:
        _reportedInjuryType = text.trim().toLowerCase();
        setState(() => _triageStep = TriageStep.askSeverity);
        _addBotMessage(
          "How severe does it look?",
          chips: ["Mild", "Moderate", "Severe 🚨", "Critical 🆘", "Not sure"],
          isTriagePrompt: true,
        );
        break;
      case TriageStep.askSeverity:
        _handleTriageChip(text.trim());
        break;
      default:
        break;
    }
  }

  // ─────────────────────────────────────────
  // Build message bubble
  // ─────────────────────────────────────────
  Widget _buildMessage(ChatMessage message) {
    final isUser = message.isUser;

    return Column(
      crossAxisAlignment:
          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
          child: Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isUser) ...[
                Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(right: 10, bottom: 2),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFF00695C), Color(0xFF26A69A)]),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.pets_rounded, color: Colors.white, size: 18),
                ),
              ],
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(
                            colors: [Color(0xFF00695C), Color(0xFF26A69A)])
                        : null,
                    color: isUser ? null : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: _buildMessageContent(message),
                ),
              ),
              if (isUser) ...[
                Container(
                  width: 36,
                  height: 36,
                  margin: const EdgeInsets.only(left: 10, bottom: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color:
                            const Color(0xFF0284C7).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: Color(0xFF0284C7), size: 20),
                ),
              ],
            ],
          ),
        ),
        // Quick-reply chips (only for bot triage messages)
        if (!isUser && message.chips != null && message.chips!.isNotEmpty)
          _buildChips(message.chips!),
      ],
    );
  }

  Widget _buildMessageContent(ChatMessage message) {
    String text = message.text;
    String? imageUrl;

    if (text.contains("IMAGE_URL:")) {
      final parts = text.split("IMAGE_URL:");
      text = parts[0].trim();
      imageUrl = parts[1].trim().split(RegExp(r'\s')).first;
    } else if (text.contains("http") &&
        (text.contains(".jpg") ||
            text.contains(".png") ||
            text.contains(".jpeg"))) {
      final urlRegex = RegExp(
          r'(https?://[^\s]+/(?:uploads/)[^\s]+\.(?:jpg|jpeg|png))');
      final match = urlRegex.firstMatch(text);
      if (match != null) {
        imageUrl = match.group(0);
        text = text
            .replaceFirst(imageUrl!, "")
            .replaceFirst("You can see her photo here:", "")
            .replaceFirst("here:", "")
            .trim();
      }
    }

    final isUser = message.isUser;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (text.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: imageUrl != null ? 8.0 : 0),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                color: isUser ? Colors.white : const Color(0xFF1A2E35),
                height: 1.4,
              ),
            ),
          ),
        if (imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 150,
                  alignment: Alignment.center,
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                    color: const Color(0xFF00695C),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                height: 100,
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image_rounded,
                    color: Colors.grey),
              ),
            ),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // Quick-reply chips
  // ─────────────────────────────────────────
  Widget _buildChips(List<String> chips) {
    return Container(
      margin: const EdgeInsets.only(left: 62, right: 16, bottom: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips.map((chip) {
          return GestureDetector(
            onTap: () => _handleTriageChip(chip),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF00695C).withValues(alpha: 0.5),
                    width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00695C).withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                chip,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF00695C),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Composer bar
  // ─────────────────────────────────────────
  Widget _buildTextComposer() {
    final bool awaitingImage = _triageStep == TriageStep.awaitingImage;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Triage progress banner
            if (_triageStep != TriageStep.idle)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: awaitingImage
                      ? const Color(0xFFFFF3CD)
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: awaitingImage
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                        : const Color(0xFF00695C).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      awaitingImage ? Icons.camera_alt_rounded : Icons.assignment_rounded,
                      size: 14,
                      color: awaitingImage
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF00695C),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        awaitingImage
                            ? "Triage complete — tap 📷 to upload the dog's photo"
                            : _triageStepLabel(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: awaitingImage
                              ? const Color(0xFF92400E)
                              : const Color(0xFF00695C),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Row(
              children: [
                // Camera button (glows when awaiting image)
                AnimatedBuilder(
                  animation: _cameraGlowAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: awaitingImage
                            ? const Color(0xFFF59E0B)
                                .withValues(alpha: 0.15 + _cameraGlowAnimation.value * 0.1)
                            : const Color(0xFFF0F4F8),
                        borderRadius: BorderRadius.circular(14),
                        border: awaitingImage
                            ? Border.all(
                                color: const Color(0xFFF59E0B).withValues(
                                    alpha: _cameraGlowAnimation.value),
                                width: 1.5,
                              )
                            : null,
                        boxShadow: awaitingImage
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFF59E0B).withValues(
                                      alpha: _cameraGlowAnimation.value * 0.4),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.camera_alt_rounded,
                          color: awaitingImage
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF00695C),
                          size: 20,
                        ),
                        tooltip: "Upload Dog Photo",
                        onPressed: _isLoading ? null : _reportViaImage,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                // Text field
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4F8),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _textController,
                      onSubmitted: _handleSubmitted,
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        hintText: awaitingImage
                            ? "Or type a message..."
                            : "Ask me anything...",
                        hintStyle:
                            const TextStyle(color: Color(0xFFB0BEC5)),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Send button
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF00695C), Color(0xFF26A69A)]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00695C).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
                    onPressed: () => _handleSubmitted(_textController.text),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _triageStepLabel() {
    switch (_triageStep) {
      case TriageStep.askInjured:
        return "Triage Step 1/3 — Is the dog injured?";
      case TriageStep.askType:
        return "Triage Step 2/3 — Type of injury?";
      case TriageStep.askSeverity:
        return "Triage Step 3/3 — Severity?";
      default:
        return "";
    }
  }

  // ─────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.pets_rounded, size: 20, color: Colors.white),
            SizedBox(width: 8),
            Text("Rescue Assistant"),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00695C), Color(0xFF26A69A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          if (_triageStep != TriageStep.idle)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _triageStep = TriageStep.idle;
                  _reportedInjuryStatus = null;
                  _reportedInjuryType = null;
                  _reportedSeverity = null;
                });
                _addBotMessage(
                    "Triage cancelled. How else can I help you? 🐾");
              },
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white70, size: 16),
              label: const Text("Cancel Report",
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) =>
                  _buildMessage(_messages[index]),
            ),
          ),
          if (_isLoading)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [Color(0xFF00695C), Color(0xFF26A69A)]),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pets_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF00695C)),
                        ),
                        SizedBox(width: 8),
                        Text("Thinking...",
                            style: TextStyle(
                                color: Color(0xFF78909C), fontSize: 14)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          _buildTextComposer(),
        ],
      ),
    );
  }
}
