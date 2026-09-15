import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
s = open(r'C:\Users\Blats\Documents\flutter\packages\flutter\lib\src\widgets\scroll_view.dart', encoding='utf-8').read()
lines = s.splitlines()
for i, l in enumerate(lines):
    if l.strip() == 'ListView({' or l.strip().startswith('ListView(') and 'class' not in l:
        j = i
        depth = 0
        out = []
        for k in range(j, min(j+30, len(lines))):
            out.append(lines[k])
            depth += lines[k].count('{') - lines[k].count('}')
            if depth <= 0 and k > j:
                break
        print('\n'.join(out))
        print('---')
        break