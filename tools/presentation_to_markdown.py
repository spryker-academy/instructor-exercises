import re, sys, subprocess, html
src, dst = sys.argv[1], sys.argv[2]
raw = open(src).read()
body = raw[raw.index('<div class="slides">'):raw.index('<script src=')]
blocks=[]
def stash(m):
    lang = m.group(1) or ''
    code = html.unescape(m.group(2)).strip('\n')
    blocks.append((lang, code)); return f'<p>@@CODE{len(blocks)-1}@@</p>'
body = re.sub(r'<pre><code(?: class="language-([a-z]+)")?>(.*?)</code></pre>', stash, body, flags=re.S)
body = re.sub(r'<pre>(.*?)</pre>', lambda m: stash(type('M',(),{'group':lambda s,i: {1:'text',2:m.group(1)}[i]})()), body, flags=re.S)
md = subprocess.run(['pandoc','-f','html','-t','gfm','--wrap=none'],input=body,capture_output=True,text=True,check=True).stdout
out=[]; box=False; last_rule=True
for line in md.split('\n'):
    s=line.strip()
    if s.startswith('<div class="slides"'): continue
    if s.startswith('<div class="section'):
        if not last_rule: out.append(''); out.append('---'); out.append('')
        last_rule=True; continue
    if s.startswith('<div class="box'): box=True; continue
    if s.startswith('<div'): continue
    if s=='</div>': box=False; continue
    if not s and box: continue
    if box: out.append('> '+line.strip()); last_rule=False; continue
    out.append(line)
    if s: last_rule=False
text='\n'.join(out)
def unstash(m):
    lang, code = blocks[int(m.group(1))]
    return f'```{lang}\n{code}\n```'
text = re.sub(r'@@CODE(\d+)@@', unstash, text)
text = re.sub(r'\n{3,}','\n\n',text).replace('&nbsp;',' ').strip()+'\n'
text = re.sub(r'\n---\n\s*$','\n',text)
open(dst,'w').write(f"<!-- Generated from guides-html/{src.split('/')[-1]}. Edit the HTML, then run: python3 tools/presentation_to_markdown.py <html> <md> -->\n\n"+text)
print(dst, len(blocks), 'code blocks')
