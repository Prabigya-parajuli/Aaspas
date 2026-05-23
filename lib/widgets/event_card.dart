import 'package:flutter/material.dart';
import '../models/event_model.dart';
import '../services/category_helper.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;
  final double? distance;
  final int attendanceCount;

  const EventCard({
    Key? key,
    required this.event,
    required this.onTap,
    this.distance,
    this.attendanceCount = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Image/Icon
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: CategoryHelper.getLightColorForCategory(event.category),
                border: Border(
                  bottom: BorderSide(
                    color: CategoryHelper.getColorForCategory(event.category),
                    width: 3,
                  ),
                ),
              ),
              child: event.imageUrl != null && event.imageUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: Image.network(
                        event.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildFallbackImage();
                        },
                      ),
                    )
                  : _buildFallbackImage(),
            ),
            // Event Details
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Category
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style: Theme.of(context).textTheme.titleLarge,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: CategoryHelper.getLightColorForCategory(
                            event.category,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: CategoryHelper.getColorForCategory(
                              event.category,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CategoryHelper.getIconForCategory(event.category),
                              size: 16,
                              color: CategoryHelper.getColorForCategory(
                                event.category,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              event.category,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: CategoryHelper.getColorForCategory(
                                  event.category,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Description
                  Text(
                    event.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  // Distance and Date
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (distance != null)
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 16, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(
                              '${distance!.toStringAsFixed(1)} km',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      Text(
                        _formatDate(event.dateTime),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.people_alt_outlined,
                        size: 16,
                        color: attendanceCount > 0 ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        attendanceCount == 1
                            ? '1 person attending'
                            : '$attendanceCount people attending',
                        style: TextStyle(
                          color: attendanceCount > 0 ? Colors.green[700] : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Center(
      child: Icon(
        CategoryHelper.getIconForCategory(event.category),
        size: 80,
        color: CategoryHelper.getColorForCategory(event.category),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }
}
