import re
with open('lib/ui/pages/Support/Requests/product_chip_form_dialog.dart', 'r') as f:
    lines = f.readlines()
new_lines = []
for line in lines:
    if line.strip() == ',':
        continue
    new_lines.append(line)
with open('lib/ui/pages/Support/Requests/product_chip_form_dialog.dart', 'w') as f:
    f.writelines(new_lines)
