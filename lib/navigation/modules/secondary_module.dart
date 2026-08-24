import 'package:flutter/widgets.dart';
import 'package:primhub/ui/pages/BPartner/bpartner_documents_page.dart';
import 'package:primhub/ui/pages/OnDevelop/knowledge_base.dart';
import 'package:primhub/ui/pages/OnDevelop/marketplace.dart';
import 'package:primhub/ui/pages/OnDevelop/profile_page.dart';

Widget buildKnowledgeBasePage() => const KnowledgeBasePage();
Widget buildMarketplacePage() => const MarketplacePage();
Widget buildProfilePage() => const ProfilePage();
Widget buildBPartnerDocumentsPage(String viewType) =>
    BPartnerDocumentsPage(viewType: viewType);
