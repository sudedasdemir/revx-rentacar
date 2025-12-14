import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app/features/home_feature/presentation/screens/home_screen.dart';

class RedirectCard extends StatefulWidget {
  final String username;
  final String? profileImageUrl;
  final VoidCallback onBookNow;
  final VoidCallback onMakeReservation;
  final VoidCallback onClose;
  const RedirectCard({
    Key? key,
    required this.username,
    this.profileImageUrl,
    required this.onBookNow,
    required this.onMakeReservation,
    required this.onClose,
  }) : super(key: key);

  @override
  State<RedirectCard> createState() => _RedirectCardState();
}

class _RedirectCardState extends State<RedirectCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final red = theme.colorScheme.secondary;
    final width = MediaQuery.of(context).size.width;
    final cardWidth = width < 420 ? width * 0.98 : 400.0;
    final buttonSize = (cardWidth - 80) / 2;
    return FadeTransition(
      opacity: _fadeAnim,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: cardWidth,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.profileImageUrl != null &&
                          widget.profileImageUrl!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: CircleAvatar(
                            radius: 18,
                            backgroundImage: NetworkImage(
                              widget.profileImageUrl!,
                            ),
                            backgroundColor: Colors.grey[200],
                          ),
                        ),
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 230),
                        child: Text(
                          'Hello, ${widget.username}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 28),
                    onPressed: widget.onClose,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 2.0, bottom: 4.0),
                child: Text(
                  'Find your dream car',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 2.0, bottom: 10.0),
                child: Text(
                  'Choose an action to get started.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    width: buttonSize,
                    height: buttonSize,
                    child: ElevatedButton(
                      onPressed: widget.onBookNow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: red,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                        padding: EdgeInsets.zero,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.directions_car,
                            color: Colors.white,
                            size: 28,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Book Now',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  SizedBox(
                    width: buttonSize,
                    height: buttonSize,
                    child: ElevatedButton(
                      onPressed: widget.onMakeReservation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: red,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                        padding: EdgeInsets.zero,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.calendar_month,
                            color: Colors.black,
                            size: 28,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Make a Reservation',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
