import json
import os

with open('replay.jsonl', 'r') as f:
    for line in f:
        try:
            step = json.loads(line)
            for tool_call in step.get('tool_calls', []):
                if tool_call.get('name') in ('multi_replace_file_content', 'replace_file_content'):
                    args = tool_call.get('args', {})
                    
                    target_file = json.loads(args.get('TargetFile', '""'))
                    if not target_file.endswith('.dart'):
                        continue
                        
                    # Skip task.md or implementation_plan.md
                    if 'task.md' in target_file or 'implementation_plan' in target_file:
                        continue
                        
                    # Also, do we want to replay everything?
                    # Some files might not be in lib/ui/pages/
                    # We reverted ONLY lib/ui/pages/
                    if 'lib/ui/pages/' not in target_file:
                        continue
                    
                    print(f"Replaying on {target_file}")
                    try:
                        with open(target_file, 'r', encoding='utf-8') as tf:
                            content = tf.read()
                    except Exception as e:
                        print("Could not open", e)
                        continue
                        
                    lines = content.split('\n')
                    
                    if tool_call.get('name') == 'multi_replace_file_content':
                        chunks = json.loads(args.get('ReplacementChunks', '[]'))
                    else:
                        chunks = [{
                            'StartLine': json.loads(args.get('StartLine')),
                            'EndLine': json.loads(args.get('EndLine')),
                            'ReplacementContent': json.loads(args.get('ReplacementContent'))
                        }]
                        
                    chunks.sort(key=lambda x: x.get('StartLine'), reverse=True)
                    
                    for chunk in chunks:
                        start = chunk.get('StartLine') - 1
                        end = chunk.get('EndLine')
                        replacement = chunk.get('ReplacementContent')
                        
                        lines = lines[:start] + replacement.split('\n') + lines[end:]
                        
                    with open(target_file, 'w', encoding='utf-8') as tf:
                        tf.write('\n'.join(lines))
        except Exception as e:
            print(f"Error: {e}")
            pass

print("Done replaying")
