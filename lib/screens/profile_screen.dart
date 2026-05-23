import 'package:flutter/material.dart';
import 'package:aaspas/services/auth_service.dart';
import 'package:aaspas/models/user_model.dart';
import 'package:aaspas/services/cache_service.dart';
import 'package:aaspas/screens/profile/my_events_screen.dart';
import 'package:aaspas/screens/profile/saved_events_screen.dart';
import 'package:aaspas/screens/profile/favorite_categories_screen.dart';
import 'package:aaspas/screens/profile/edit_profile_screen.dart';
import 'package:aaspas/screens/admin/admin_panel_screen.dart';
import 'package:aaspas/widgets/email_verification_banner.dart';
import 'package:aaspas/services/fcm_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_storage/firebase_storage.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AutomaticKeepAliveClientMixin{

  @override
  bool get wantKeepAlive => true;

  final AuthService _authService = AuthService();
  final CacheService _cacheService = CacheService();
  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    final uid = _authService.getCurrentUserId();
    if (uid != null) {
      // Try cache first
      final cachedUser = await _cacheService.getCachedUser(uid);
      if (cachedUser != null) {
        setState(() {
          _currentUser = cachedUser;
          _isLoading = false;
        });
        // Refresh from Firestore in background
        _refreshUserFromFirestore(uid);
      } else {
        // No cache - fetch from Firestore
        await _refreshUserFromFirestore(uid);
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshUserFromFirestore(String uid) async {
    final userData = await _authService.getUserData(uid);
    if (userData != null) {
      await _cacheService.cacheUser(userData);
      if (mounted) {
        setState(() {
          _currentUser = userData;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      try {
        final uid = _authService.getCurrentUserId();
        if (uid != null) {
          await _cacheService.clearUserCache(uid);
        }
        await _authService.logout();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logged out successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error logging out: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              );
              if (result == true) {
                _loadUserData(); // Refresh profile
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
          ? _buildErrorState()
          : RefreshIndicator(
        onRefresh: _loadUserData,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const EmailVerificationBanner(),
            const SizedBox(height: 16),
            _buildProfileHeader(),
            const SizedBox(height: 32),
            _buildStatsSection(),
            const SizedBox(height: 32),
            _buildProfileOptions(),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Failed to load user data'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadUserData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final email = _authService.getCurrentUserEmail() ?? 'No email';

    return Center(
      child: Column(
        children: [
          // Profile Picture
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blue[100],
                backgroundImage: _currentUser?.photoURL != null && _currentUser!.photoURL!.isNotEmpty
                    ? NetworkImage(_currentUser!.photoURL!)
                    : null,
                child: (_currentUser?.photoURL == null || _currentUser!.photoURL!.isEmpty)
                    ? Icon(
                  Icons.person,
                  size: 50,
                  color: Colors.blue[800],
                )
                    : null,
              ),
              // Optional: Add edit icon on the profile picture (small pencil)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                      );
                      if (result == true) {
                        _loadUserData();
                      }
                    },
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _currentUser!.username,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            email,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Member since ${_formatDate(_currentUser!.createdAt)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Activity',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatCard(
              count: _currentUser!.eventsAttended.toString(),
              label: 'Events\nAttended',
              icon: Icons.event_available,
            ),
            _buildStatCard(
              count: _currentUser!.eventsSaved.toString(),
              label: 'Events\nSaved',
              icon: Icons.bookmark,
            ),
            _buildStatCard(
              count: _currentUser!.eventsCreated.toString(),
              label: 'Events\nCreated',
              icon: Icons.create,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String count,
    required String label,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[100]!),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: Colors.blue),
          const SizedBox(height: 8),
          Text(
            count,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.blue,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildProfileOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Options',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        _buildOptionTile(
          icon: Icons.bookmark,
          title: 'Saved Events',
          subtitle: 'View your saved events',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SavedEventsScreen(),
              ),
            ).then((_) => _loadUserData()); // Refresh after returning
          },
        ),
        _buildOptionTile(
          icon: Icons.calendar_today,
          title: 'My Events',
          subtitle: 'Events you created',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MyEventsScreen(),
              ),
            ).then((_) => _loadUserData());
          },
        ),
        _buildOptionTile(
          icon: Icons.favorite,
          title: 'Favorite Categories',
          subtitle: _currentUser!.favoriteCategories.isEmpty
              ? 'Set your preferences'
              : _currentUser!.favoriteCategories.join(', '),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FavoriteCategoriesScreen(),
              ),
            ).then((_) => _loadUserData());
          },
        ),

        // Admin Panel - Only visible to admin users
        if (_authService.getCurrentUserEmail() == 'adminaaspaas@gmail.com')
          _buildOptionTile(
            icon: Icons.admin_panel_settings,
            title: 'Admin Panel',
            subtitle: 'Manage all events',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminPanelScreen(),
                ),
              );
            },
          ),
        _buildOptionTile(
          icon: Icons.help,
          title: 'Help & Support',
          subtitle: 'Get help or report issues',
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Help & Support'),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('For help or support, contact us:'),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.email, size: 16, color: Colors.blue),
                        SizedBox(width: 8),
                        Text('adminaaspaas@gmail.com'),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'We typically respond within 24 hours.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          },
        ),

        _buildOptionTile(
          icon: Icons.info,
          title: 'About Aaspas',
          subtitle: 'App version and information',
          onTap: () {
            _showAboutDialog(context);
          },
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Aaspas'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Aaspas v1.0.0'),
            SizedBox(height: 12),
            Text(
              'A hyperlocal event discovery platform for Nepal.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              'Discover nearby community events, submit your own, and connect with local communities.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}