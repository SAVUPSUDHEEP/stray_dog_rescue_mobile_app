import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

import 'view_cases.dart';
import 'view_surrenders.dart';
import 'view_adoptions.dart';
import 'login_page.dart';
import 'notifications_page.dart';
import 'view_adoption_requests.dart';

class AdminHome extends StatefulWidget {
  final String role;
  final String username;
  final int? shelterId;

  const AdminHome({
    super.key,
    required this.role,
    required this.username,
    this.shelterId,
  });

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int unreadCount = 0;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    fetchUnreadCount();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      fetchUnreadCount();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> fetchUnreadCount() async {
    final res = await http.get(
      Uri.parse("$apiBaseUrl/notifications/unread_count/${widget.username}"),
    );
    if (!mounted) return;
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        unreadCount = data['count'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isShelter = widget.role == "shelter";

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                _sectionLabel("Management Tools"),
                const SizedBox(height: 14),

                _buildMenuCard(
                  context,
                  title: "View Rescue Cases",
                  subtitle: widget.role == "vet" ? "Record treatments & vaccinations" : "Manage and update rescue case statuses",
                  icon: Icons.assignment_rounded,
                  gradient: const LinearGradient(colors: [Color(0xFF00695C), Color(0xFF26A69A)]),
                  page: ViewCasesPage(shelterId: widget.shelterId, role: widget.role),
                ),

                if (isShelter) ...[
                  _buildMenuCard(
                    context,
                    title: "View Surrenders",
                    subtitle: "Review incoming surrender requests",
                    icon: Icons.volunteer_activism_rounded,
                    gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFFB923C)]),
                    page: const ViewSurrenders(),
                  ),
                  _buildMenuCard(
                    context,
                    title: "Adoption List",
                    subtitle: "Dogs available for adoption",
                    icon: Icons.pets_rounded,
                    gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF9F67FA)]),
                    page: const ViewAdoptionsPage(),
                  ),
                  _buildMenuCard(
                    context,
                    title: "Adoption Requests",
                    subtitle: "Approve or reject adoption applications",
                    icon: Icons.mail_outline_rounded,
                    gradient: const LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF38BDF8)]),
                    page: const ViewAdoptionRequestsPage(),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00695C), Color(0xFF009688)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.role.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Notification Bell
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 26),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NotificationsPage(username: widget.username, role: widget.role),
                            ),
                          );
                          if (!mounted) return;
                          fetchUnreadCount();
                        },
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            child: Center(
                              child: Text(
                                unreadCount.toString(),
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Colors.white70),
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text("Admin Dashboard", style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                widget.username,
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "Manage rescue operations 🐾",
                  style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF546E7A),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required Widget page,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(16)),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1A2E35))),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF78909C))),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: const Color(0xFFF0F4F8), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF546E7A)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
