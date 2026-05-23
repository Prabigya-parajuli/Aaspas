class InputValidator {
  // Validate event title
  static String? validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Title is required';
    }
    if (value.trim().length < 3) {
      return 'Title must be at least 3 characters';
    }
    if (value.length > 100) {
      return 'Title must be less than 100 characters';
    }
    return null;
  }

  // Validate event description
  static String? validateDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Description is required';
    }
    if (value.trim().length < 10) {
      return 'Description must be at least 10 characters';
    }
    if (value.length > 500) {
      return 'Description must be less than 500 characters';
    }
    return null;
  }

  // Validate username
  static String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username is required';
    }
    if (value.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (value.length > 30) {
      return 'Username must be less than 30 characters';
    }
    // Only alphanumeric and underscores
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
      return 'Username can only contain letters, numbers, and underscores';
    }
    return null;
  }

  // Validate email
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    // Basic email regex
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  // Validate password
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  // Validate location name
  static String? validateLocationName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Location name is required';
    }
    if (value.length > 100) {
      return 'Location name must be less than 100 characters';
    }
    return null;
  }

  // Sanitize input (remove potentially dangerous characters)
  static String sanitizeInput(String input) {
    // Remove HTML tags
    String sanitized = input.replaceAll(RegExp(r'<[^>]*>'), '');
    // Remove script tags
    sanitized = sanitized.replaceAll(RegExp(r'<script.*?</script>', caseSensitive: false), '');
    // Trim whitespace
    sanitized = sanitized.trim();
    return sanitized;
  }

  // Check for profanity (basic list - expand as needed)
  static bool containsProfanity(String text) {
    final badWords = [
      'spam',
      'scam',
      // Add more as needed for your context
    ];

    final lowerText = text.toLowerCase();
    return badWords.any((word) => lowerText.contains(word));
  }

  // Validate URL
  static bool isValidUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
}