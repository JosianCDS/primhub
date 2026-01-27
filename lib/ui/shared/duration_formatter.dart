class DurationFormatter {
  static String format(double totalHours) {
    int hours = totalHours.truncate();
    int minutes = ((totalHours - hours) * 60).round();

    if (hours == 0 && minutes == 0) return "0h";

    List<String> parts = [];
    if (hours > 0) parts.add("${hours}h");
    if (minutes > 0) parts.add("${minutes}m");

    return parts.join(" ");
  }
}
