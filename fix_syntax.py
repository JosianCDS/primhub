import re
import os

def fix_file(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Fix ,, type:
    content = re.sub(r',\s*,', ',', content)
    
    # Fix extraneous characters before type:
    # Example: ToastMessage.show(context: context, message: '...',), type: ToastType.failure);
    # Example: message: '...'), backgroundColor: Colors.red
    # The previous regex captured '...' including some parenthesis or trailing commas.
    # Let's just fix the files manually or use regex to fix specific broken syntaxes.
    
    # Replace single quote followed by ), type: with ', type:
    content = re.sub(r"'\s*\),\s*type:", "', type:", content)
    content = re.sub(r"'\s*\)\s*,\s*type:", "', type:", content)
    
    # Sometimes it matched: message: Text('...'), type: 
    # Wait, my regex was text = match.group(1).strip() which was INSIDE Text()
    # So if it was Text('...'), text is `'...'`
    # If it was Text('...' + var), text is `'...' + var`
    # Then `ToastMessage.show(context: context, message: {text}, type: {toast_type});`
    # So it should be `message: '...', type: ToastType.help);`
    # BUT wait, the original might have had `Text('...', style: ...)` or something?
    # No, my regex matched `Text((.*?))` lazy until the first `)`!
    # So if it was `Text('hola', style: ...)` it might have broken.
    
    # Let's fix the `,,` issue
    content = re.sub(r',,+', ',', content)
    
    # Let's fix `ToastMessage.show(context: context, message: '...',, type: ToastType.failure)`
    # The ,, was already fixed by above.
    
    # Fix `message: '...'\n                      ),` -> we want to remove `\n                      ),`
    # Actually, let's look at the errors.
    # `Unexpected text ')'. Try removing the text.`
    # `The named parameter 'type' is required, but there's no corresponding argument.`
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)

for root, _, files in os.walk('lib/ui/pages'):
    for file in files:
        if file.endswith('.dart'):
            fix_file(os.path.join(root, file))

print("Fixed double commas")
