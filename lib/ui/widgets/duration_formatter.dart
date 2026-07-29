class DurationFormatter {
  static String format(double totalHours) {
    if (totalHours == 0) return "0h";

    bool isNegative = totalHours < 0;
    double absHours = totalHours.abs();

    int hours = absHours.truncate();
    int minutes = ((absHours - hours) * 60).round();

    if (hours == 0 && minutes == 0) return "0h";

    List<String> parts = [];
    if (hours > 0) parts.add("${hours}h");
    if (minutes > 0) parts.add("${minutes}m");

    String result = parts.join(" ");
    return isNegative ? "-$result" : result;
  }
}
