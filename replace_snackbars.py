import re
import os
import glob

def refactor_snackbars(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find patterns like:
    # ScaffoldMessenger.of(context).showSnackBar(
    #   SnackBar(content: Text('...'), backgroundColor: Colors.red),
    # );
    
    # We will use regex to find ScaffoldMessenger and its content.
    # It's better to just manually fix the 2 files with a script.
    
    pattern = re.compile(r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*(?:const\s*)?SnackBar\(\s*content:\s*Text\((.*?)\)(?:,\s*backgroundColor:\s*([^)]*))?\s*\),?\s*\);', re.DOTALL)
    
    def replacer(match):
        text = match.group(1).strip()
        color = match.group(2)
        
        # Determine type
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
        # Check if custom_toast is imported
        if 'custom_toast.dart' not in new_content:
            new_content = "import 'package:primhub/ui/Shared_Custom/custom_toast.dart';\n" + new_content
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {file_path}")

for root, _, files in os.walk('lib/ui/pages'):
    for file in files:
        if file.endswith('.dart'):
            refactor_snackbars(os.path.join(root, file))

print("Done")
