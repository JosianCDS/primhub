import re

with open('lib/ui/pages/Support/Requests/product_chip_form_dialog.dart', 'r') as f:
    content = f.read()

# insert isMobile
content = content.replace("final bPartners = GlobalCache.bPartners;", "final bPartners = GlobalCache.bPartners;\n    final isMobile = MediaQuery.of(context).size.width < 600;\n\n    Widget buildPair(Widget w1, Widget w2) {\n      if (isMobile) {\n        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [w1, const SizedBox(height: 16), w2]);\n      }\n      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: w1), const SizedBox(width: 16), Expanded(child: w2)]);\n    }")

# Fila 1
content = re.sub(
    r'Row\(\s*crossAxisAlignment: CrossAxisAlignment\.start,\s*children: \[\s*Expanded\(\s*flex: 1,\s*child: (.*?)\n\s*\),\s*const SizedBox\(width: 16\),\s*Expanded\(\s*flex: 1,\s*child: (.*?)\n\s*\),\s*\],\s*\)',
    r'buildPair(\n\1\n,\n\2\n)',
    content,
    flags=re.DOTALL
)

with open('lib/ui/pages/Support/Requests/product_chip_form_dialog.dart', 'w') as f:
    f.write(content)
