import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/category_helper.dart';

class FavoriteCategoriesScreen extends StatefulWidget {
  const FavoriteCategoriesScreen({Key? key}) : super(key: key);

  @override
  State<FavoriteCategoriesScreen> createState() =>
      _FavoriteCategoriesScreenState();
}

class _FavoriteCategoriesScreenState extends State<FavoriteCategoriesScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();

  final List<String> _allCategories = [
    'Tech',
    'Health',
    'Culture',
    'Sports',
    'Volunteer',
    'Other'
  ];

  List<String> _favoriteCategories = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteCategories();
  }

  Future<void> _loadFavoriteCategories() async {
    setState(() {
      _isLoading = true;
    });

    final userId = _authService.getCurrentUserId();
    if (userId != null) {
      final favorites = await _userService.getFavoriteCategories(userId);
      setState(() {
        _favoriteCategories = favorites;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveFavoriteCategories() async {
    setState(() {
      _isSaving = true;
    });

    final userId = _authService.getCurrentUserId();
    if (userId != null) {
      final success =
      await _userService.updateFavoriteCategories(userId, _favoriteCategories);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Favorites updated successfully')),
        );
        Navigator.pop(context);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update favorites')),
        );
      }
    }

    setState(() {
      _isSaving = false;
    });
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_favoriteCategories.contains(category)) {
        _favoriteCategories.remove(category);
      } else {
        _favoriteCategories.add(category);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorite Categories'),
        elevation: 0,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _saveFavoriteCategories,
              child: _isSaving
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Save'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Your Interests',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose categories you\'re interested in. We\'ll use this to recommend events you might like.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ..._allCategories.map((category) {
              final isSelected = _favoriteCategories.contains(category);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: CheckboxListTile(
                  value: isSelected,
                  onChanged: (value) => _toggleCategory(category),
                  title: Row(
                    children: [
                      Icon(
                        CategoryHelper.getIconForCategory(category),
                        color:
                        CategoryHelper.getColorForCategory(category),
                        size: 28,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(left: 44.0),
                    child: Text(
                      _getCategoryDescription(category),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  secondary: isSelected
                      ? const Icon(Icons.favorite, color: Colors.red)
                      : const Icon(Icons.favorite_border,
                      color: Colors.grey),
                  activeColor:
                  CategoryHelper.getColorForCategory(category),
                ),
              );
            }).toList(),
            const SizedBox(height: 24),
            if (_favoriteCategories.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Select at least one category to get personalized recommendations',
                        style: TextStyle(color: Colors.orange[900]),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[700]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${_favoriteCategories.length} categor${_favoriteCategories.length == 1 ? 'y' : 'ies'} selected',
                        style: TextStyle(
                          color: Colors.green[900],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getCategoryDescription(String category) {
    switch (category) {
      case 'Tech':
        return 'Workshops, hackathons, tech talks';
      case 'Health':
        return 'Blood drives, health camps, wellness';
      case 'Culture':
        return 'Music, art, poetry, performances';
      case 'Sports':
        return 'Tournaments, matches, fitness';
      case 'Volunteer':
        return 'Community service, cleanup drives';
      case 'Other':
        return 'Miscellaneous events';
      default:
        return '';
    }
  }
}