import re
import os

def fix_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find ScaffoldMessenger.of(context).showSnackBar(...)
    # We want to match:
    # ScaffoldMessenger.of(context).showSnackBar(
    #   const SnackBar(content: Text('...'), backgroundColor: Colors.orange),
    # );
    
    # Let's match the block
    pattern = re.compile(
        r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*'
        r'(?:const\s+)?SnackBar\(\s*'
        r'content:\s*Text\(([^)]+)\)\s*'
        r'(?:,\s*backgroundColor:\s*([^)]+)\s*)?'
        r'\)\s*,?\s*\);', re.DOTALL)

    def replacer(match):
        text = match.group(1).strip()
        color = match.group(2)
        
        if color:
            color = color.strip()
            if 'Colors.red' in color:
                toast_type = 'ToastType.failure'
            elif 'Colors.orange' in color:
                toast_type = 'ToastType.warning'
            elif 'Colors.green' in color:
                toast_type = 'ToastType.success'
            else:
                toast_type = 'ToastType.help'
        else:
            toast_type = 'ToastType.help'
            
        return f"ToastMessage.show(context: context, message: {text}, type: {toast_type});"
        
    new_content = pattern.sub(replacer, content)
    
    if new_content != content:
        if 'custom_toast.dart' not in new_content:
            new_content = "import 'package:primhub/ui/Shared_Custom/custom_toast.dart';\n" + new_content
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {file_path}")

for root, _, files in os.walk('lib/ui/pages'):
    for file in files:
        if file.endswith('.dart'):
            fix_file(os.path.join(root, file))
