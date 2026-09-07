import 'package:intl/intl.dart';

class DateUtil {
  static String formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    if (now.year == time.year) {
      return DateFormat('MM-dd HH:mm').format(time);
    }
    return DateFormat('yyyy-MM-dd HH:mm').format(time);
  }

  static String formatDate(DateTime date) {
    final now = DateTime.now();
    if (now.year == date.year) {
      return DateFormat('M月d日').format(date);
    }
    return DateFormat('yyyy年M月d日').format(date);
  }

  static String formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
