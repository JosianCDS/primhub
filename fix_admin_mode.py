import re

def process_file(path):
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Import AdminModeViews if not present
    if "admin_mode_views.dart" not in content:
        content = "import 'package:primhub/ui/Shared_Custom/admin_mode_views.dart';\n" + content

    # 1. Remove _showAdminModeSelectionDialog
    content = re.sub(r'  void _showAdminModeSelectionDialog\([^}]*\}\n', '', content, flags=re.DOTALL)
    # The regex above is too brittle. Let's find it more reliably.
    
    # 2. Replace the usages.
    pass
