/// Human-friendly relative time: "now", "4m", "3h", "2d", "Mar 4".
String timeAgo(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 45) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  const months = [
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
    'Dec',
  ];
  return '${months[time.month - 1]} ${time.day}';
}

/// A short, single-line title derived from the first user message.
String titleFromMessage(String text) {
  final line = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (line.isEmpty) return 'New chat';
  if (line.length <= 44) return line;
  return '${line.substring(0, 44).trimRight()}…';
}
