import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:primhub/ui/pages/Support/Requests/my_requests.dart';
import 'package:primhub/ui/pages/Support/Requests/request_updates_page.dart';
import 'package:primhub/ui/pages/Support/support_dashboard.dart';

Widget buildSupportPage() =>
    const _QuillLocalizations(child: SupportDashboardPage());
Widget buildMyRequestsPage() =>
    const _QuillLocalizations(child: MyRequestsPage());
Widget buildRequestUpdatesPage(int id, String docNo) =>
    _QuillLocalizations(child: RequestUpdatesPage(requestId: id, docNo: docNo));

class _QuillLocalizations extends StatelessWidget {
  const _QuillLocalizations({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Localizations.override(
        context: context,
        delegates: const [FlutterQuillLocalizations.delegate],
        child: child,
      );
}
