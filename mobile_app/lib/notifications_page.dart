import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

import 'view_cases.dart';
import 'view_adoption_requests.dart';
import 'view_surrenders.dart';

class NotificationsPage extends StatefulWidget {
  final String username;
  final String? role;

  const NotificationsPage({super.key, required this.username, this.role});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchNotifications();
  }

  Future<void> fetchNotifications() async {
    final res = await http.get(
      Uri.parse("$apiBaseUrl/notifications/${widget.username}"),
    );

    if (res.statusCode == 200) {
      if (!mounted) return;
      setState(() {
        notifications = jsonDecode(res.body);
        isLoading = false;
      });
    }
  }

  Future<void> markAsRead(int id) async {
    await http.put(Uri.parse("$apiBaseUrl/notifications/read/$id"));
  }

  void handleNavigation(Map n) async {
    final navigator = Navigator.of(context);

    if (n['is_read'] == 0) {
      await markAsRead(n['id']);
    }
    if (!mounted) return;

    if (n['type'] == "case") {
      navigator.push(MaterialPageRoute(builder: (_) => ViewCasesPage(role: widget.role)));
    } else if (n['type'] == "adoption_request") {
      navigator.push(MaterialPageRoute(builder: (_) => ViewAdoptionRequestsPage()));
    } else if (n['type'] == "surrender_request") {
      navigator.push(MaterialPageRoute(builder: (_) => ViewSurrenders()));
    } else if (n['type'] == "adoption_status") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(n['message']),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else if (n['type'] == "surrender_status") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(n['message']),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    fetchNotifications();
  }

  IconData _getNotifIcon(String? type) {
    switch (type) {
      case "case": return Icons.assignment_rounded;
      case "adoption_request": return Icons.pets_rounded;
      case "adoption_status": return Icons.favorite_rounded;
      case "surrender_request": return Icons.volunteer_activism_rounded;
      case "surrender_status": return Icons.check_circle_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _getNotifColor(String? type) {
    switch (type) {
      case "case": return const Color(0xFF00695C);
      case "adoption_request": return const Color(0xFF7C3AED);
      case "adoption_status": return const Color(0xFF22C55E);
      case "surrender_request": return const Color(0xFFF97316);
      case "surrender_status": return const Color(0xFF0284C7);
      default: return const Color(0xFF546E7A);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text("Notifications"),
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
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "${notifications.where((n) => n['is_read'] == 0).length} new",
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00695C)))
          : notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4F8),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(Icons.notifications_off_outlined, size: 40, color: Color(0xFFB0BEC5)),
                      ),
                      const SizedBox(height: 16),
                      const Text("No notifications yet", style: TextStyle(color: Color(0xFF78909C), fontSize: 16, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final n = notifications[index];
                    final isUnread = n['is_read'] == 0;
                    final color = _getNotifColor(n['type']);

                    return GestureDetector(
                      onTap: () => handleNavigation(n),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isUnread ? Colors.white : Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(18),
                          border: isUnread
                              ? Border.all(color: color.withValues(alpha: 0.3), width: 1.5)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isUnread ? 0.07 : 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(_getNotifIcon(n['type']), color: color, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            n['title'],
                                            style: TextStyle(
                                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                                              fontSize: 15,
                                              color: const Color(0xFF1A2E35),
                                            ),
                                          ),
                                        ),
                                        if (isUnread)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      n['message'],
                                      style: const TextStyle(color: Color(0xFF78909C), fontSize: 13),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      n['created_at'],
                                      style: const TextStyle(fontSize: 11, color: Color(0xFFB0BEC5)),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFFB0BEC5)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}