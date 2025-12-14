import 'package:firebase_app/features/home_feature/presentation/widgets/custom_drawer.dart';
import 'package:firebase_app/gen/assets.gen.dart';
import 'package:firebase_app/theme/dimens.dart';
import 'package:firebase_app/widgets/app_svg_viewer.dart';
import 'package:firebase_app/features/home_feature/presentation/bloc/bottom_navigation_cubit.dart';
import 'package:firebase_app/features/home_feature/presentation/widgets/main_app_bar.dart';
import 'package:firebase_app/features/home_feature/presentation/widgets/tabs/history_tab.dart';
import 'package:firebase_app/features/home_feature/presentation/widgets/tabs/home_tab.dart';
import 'package:firebase_app/features/home_feature/presentation/widgets/tabs/profile_tab.dart';
import 'package:firebase_app/features/home_feature/presentation/widgets/tabs/search_tab.dart';
import 'package:firebase_app/features/home_feature/presentation/widgets/tabs/map_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app/features/home_feature/presentation/screens/redirect_page.dart';

class HomeScreen extends StatefulWidget {
  final int? initialTab;
  final bool scrollToFavorites;
  final bool skipRedirect;
  final String? scrollToFavoriteCarId;
  const HomeScreen({
    super.key,
    this.initialTab,
    this.scrollToFavorites = false,
    this.skipRedirect = false,
    this.scrollToFavoriteCarId,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _dialogShown = false;
  String? _username;
  String? _profileImageUrl;
  String? _role;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final username = doc.data()?['fullName'] ?? user.email ?? 'User';
      final profileImageUrl = doc.data()?['profileImage'] ?? null;
      final isAdmin = doc.data()?['isAdmin'] == true;
      final userRole = doc.data()?['role'] ?? 'user';
      // Set role to 'user' if the user is an admin and not corporate
      final role = (isAdmin && userRole != 'corporate') ? 'user' : userRole;
      setState(() {
        _username = username;
        _profileImageUrl = profileImageUrl;
        _role = role;
      });
    }
  }

  void _showRedirectDialog(
    BuildContext context,
    BottomNavigationCubit navigationCubit,
  ) {
    if (!_dialogShown && _role == 'user') {
      _dialogShown = true;
      showModalBottomSheet(
        context: context,
        isDismissible: false,
        enableDrag: false,
        backgroundColor: Colors.transparent,
        builder:
            (context) => RedirectCard(
              username: _username ?? 'User',
              profileImageUrl: _profileImageUrl,
              onBookNow: () {
                Navigator.of(context).pop();
                navigationCubit.onItemTap(index: 4); // Map tab
              },
              onMakeReservation: () {
                Navigator.of(context).pop();
                navigationCubit.onItemTap(index: 0); // Home tab
              },
              onClose: () {
                Navigator.of(context).pop();
                navigationCubit.onItemTap(index: 0); // Home tab
              },
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BottomNavigationCubit>(
      create:
          (context) =>
              BottomNavigationCubit()..onItemTap(index: widget.initialTab ?? 0),
      child: Builder(
        builder: (context) {
          final navigationCubit = context.read<BottomNavigationCubit>();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!widget.skipRedirect) {
              _showRedirectDialog(context, navigationCubit);
            }
          });
          return _HomeScreen(
            role: _role,
            scrollToFavoriteCarId: widget.scrollToFavoriteCarId,
          );
        },
      ),
    );
  }
}

class _HomeScreen extends StatelessWidget {
  final String? role;
  final String? scrollToFavoriteCarId;
  const _HomeScreen({this.role, this.scrollToFavoriteCarId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final List<Widget> tabs = [
      const HomeTab(),
      const SearchTab(),
      HistoryTab(scrollToFavoriteCarId: scrollToFavoriteCarId),
      const ProfileTab(),
    ];
    final List<BottomNavigationBarItem> items = [
      BottomNavigationBarItem(
        icon: Padding(
          padding: const EdgeInsets.symmetric(vertical: Dimens.largePadding),
          child: AppSvgViewer(Assets.icons.home, color: colorScheme.secondary),
        ),
        label: 'Home',
      ),
      BottomNavigationBarItem(
        icon: Padding(
          padding: const EdgeInsets.only(
            top: Dimens.padding,
            bottom: Dimens.largePadding,
          ),
          child: AppSvgViewer(
            Assets.icons.search,
            color: colorScheme.secondary,
          ),
        ),
        label: 'Search',
      ),
      BottomNavigationBarItem(
        icon: Padding(
          padding: const EdgeInsets.only(
            top: Dimens.padding,
            bottom: Dimens.largePadding,
          ),
          child: AppSvgViewer(
            Assets.icons.history,
            color: colorScheme.secondary,
          ),
        ),
        label: 'History',
      ),
      BottomNavigationBarItem(
        icon: Padding(
          padding: const EdgeInsets.only(
            top: Dimens.padding,
            bottom: Dimens.largePadding,
          ),
          child: AppSvgViewer(Assets.icons.user, color: colorScheme.secondary),
        ),
        label: 'Profile',
      ),
    ];
    if (role == 'user') {
      tabs.add(const MapTab());
      items.add(
        BottomNavigationBarItem(
          icon: Padding(
            padding: const EdgeInsets.only(
              top: Dimens.padding,
              bottom: Dimens.largePadding,
            ),
            child: AppSvgViewer(
              Assets.icons.location,
              color: colorScheme.secondary,
            ),
          ),
          label: 'Map',
        ),
      );
    }
    final watch = context.watch<BottomNavigationCubit>();
    final read = context.read<BottomNavigationCubit>();
    return Scaffold(
      appBar: const MainAppBar(),
      drawer: const CustomDrawer(),
      body: tabs[watch.state.selectedIndex],
      bottomNavigationBar: ColoredBox(
        color: colorScheme.background,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Dimens.corners * 2),
          child: BottomNavigationBar(
            backgroundColor: colorScheme.surface,
            currentIndex: watch.state.selectedIndex,
            onTap: (final int index) {
              read.onItemTap(index: index);
            },
            type: BottomNavigationBarType.fixed,
            selectedItemColor: colorScheme.secondary,
            unselectedItemColor: colorScheme.onSurface.withOpacity(0.6),
            items: items,
          ),
        ),
      ),
    );
  }
}
