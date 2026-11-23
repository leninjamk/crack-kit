#!/usr/bin/env python3
"""triage.py - faz o relatorio do loot capturado (Linux)"""
import os, sys, re, math, hashlib, struct, glob

LOOT = sys.argv[1] if len(sys.argv) > 1 else "."
REPORT = os.path.join(LOOT, "TRIAGE.md")

def magic(b):
    if len(b) < 4: return "tiny"
    h = b[:4].hex().upper()
    if h.startswith("4D5A"): return "PE (MZ)"
    if h.startswith("7F454C46"): return "ELF"
    if h.startswith("504B0304"): return "ZIP"
    if h.startswith("52617221"): return "RAR"
    if h.startswith("1F8B"): return "gzip"
    if h.startswith("89504E47"): return "PNG"
    if h.startswith("FFD8FF"): return "JPEG"
    if h.startswith("25504446"): return "PDF"
    if h.startswith("3C3F786D"): return "XML"
    if b[:1] == b"{": return "JSON?"
    return f"unk {h}"

def entropy(b):
    if not b: return 0.0
    c = [0]*256
    for x in b: c[x] += 1
    e = 0.0
    for n in c:
        if n:
            p = n/len(b); e -= p*math.log2(p)
    return round(e,2)

def carve_pes(raw, outdir, origin):
    n = 0
    i = 0
    L = len(raw)
    while i < L - 0x400:
        if raw[i] == 0x4D and raw[i+1] == 0x5A:
            try:
                e_lfanew = struct.unpack_from("<I", raw, i+0x3C)[0]
                if 0 < e_lfanew < 0x1000 and i+e_lfanew+4 < L:
                    if raw[i+e_lfanew] == 0x50 and raw[i+e_lfanew+1] == 0x45:
                        size_img = struct.unpack_from("<I", raw, i+e_lfanew+0x50)[0]
                        if 0x400 < size_img < 50*1024*1024 and i+size_img <= L:
                            name = f"pe_{i:08x}_{size_img:x}.bin"
                            with open(os.path.join(outdir,name),"wb") as f:
                                f.write(raw[i:i+size_img])
                            n += 1
                            i += size_img
                            continue
            except: pass
        i += 1
    return n

lines = [f"# Triage  (Linux/Wine)\n"]

# ------------- files capturados -------------
lines.append("## Arquivos capturados")
for fp in sorted(glob.glob(os.path.join(LOOT,"files","*"))):
    try:
        sz = os.path.getsize(fp)
        if sz == 0: continue
        with open(fp,"rb") as f: head = f.read(8192)
        lines.append(f"- `{os.path.basename(fp)}` size={sz} magic={magic(head)} entropy={entropy(head)}")
    except Exception as e:
        lines.append(f"- {fp}: erro {e}")

# ------------- candidatos a payload -------------
lines.append("\n## Candidatos a payload (PE ou entropia >= 7.0)")
for fp in sorted(glob.glob(os.path.join(LOOT,"files","*"))):
    try:
        sz = os.path.getsize(fp)
        if sz < 1024: continue
        with open(fp,"rb") as f: head = f.read(8192)
        m = magic(head); e = entropy(head)
        if m == "PE (MZ)" or e >= 7.0:
            lines.append(f"- **{os.path.basename(fp)}** magic={m} entropy={e} size={sz}")
    except: pass

# ------------- URLs / hostnames (de tudo: files, strace, pcap) -------------
lines.append("\n## URLs e hostnames encontrados")
url_rx = re.compile(rb'(?i)https?://[A-Za-z0-9._\-/:%?=&#]{6,200}')
dns_rx = re.compile(rb'(?i)\b([a-z0-9][a-z0-9\-]{0,62}\.){1,4}(com|net|org|io|xyz|cc|me|dev|app|cloud|gg|club|shop|store|site|online|top|ru|br)\b')
hits_url = set(); hits_dns = set()
for root, _, files in os.walk(LOOT):
    for f in files:
        fp = os.path.join(root,f)
        try:
            if os.path.getsize(fp) > 500*1024*1024: continue
            with open(fp,"rb") as fh: raw = fh.read()
            for m in url_rx.findall(raw): hits_url.add(m.decode(errors="replace"))
            for m in dns_rx.findall(raw): pass
            for m in dns_rx.finditer(raw):
                hits_dns.add(m.group(0).decode(errors="replace"))
            # utf16
            try:
                u = raw.decode("utf-16le", errors="ignore").encode()
                for m in url_rx.findall(u): hits_url.add(m.decode(errors="replace"))
                for m in dns_rx.finditer(u): hits_dns.add(m.group(0).decode(errors="replace"))
            except: pass
        except: pass

for u in sorted(hits_url): lines.append(f"- {u}")
if hits_dns:
    lines.append("\n### Hostnames")
    for d in sorted(hits_dns): lines.append(f"- {d}")

# ------------- strace: conexoes + arquivos abertos -------------
lines.append("\n## strace: connect() destinos (IPs/portas)")
conn_rx = re.compile(r'connect\([^,]+,\s*\{sa_family=AF_INET6?,\s*(?:sin6?_port=htons\((\d+)\))?[^,]*,\s*(?:sin6?_addr=inet_pton\([^"]*"([^"]+)"|inet_addr\("([^"]+)"\))')
conns = set()
for tracefp in glob.glob(os.path.join(LOOT,"strace","trace*")):
    try:
        with open(tracefp,"r",errors="ignore") as f:
            for ln in f:
                if "connect(" in ln and "AF_INET" in ln:
                    conns.add(ln.strip()[:300])
    except: pass
for c in sorted(conns)[:200]: lines.append(f"- `{c}`")

# ------------- strace: writes de arquivo grandes -------------
lines.append("\n## strace: openat() de arquivos criados (tops)")
opens = {}
for tracefp in glob.glob(os.path.join(LOOT,"strace","trace*")):
    try:
        with open(tracefp,"r",errors="ignore") as f:
            for ln in f:
                m = re.search(r'open(?:at)?\([^"]*"([^"]+)"[^)]*O_(?:CREAT|WRONLY|RDWR)', ln)
                if m:
                    opens[m.group(1)] = opens.get(m.group(1),0)+1
    except: pass
for path, c in sorted(opens.items(), key=lambda x:-x[1])[:60]:
    lines.append(f"- ({c}x) {path}")

# ------------- carve de PEs em todo blob >= 50KB -------------
lines.append("\n## Carve de PEs em arquivos capturados")
carved_dir = os.path.join(LOOT,"carved"); os.makedirs(carved_dir, exist_ok=True)
for fp in glob.glob(os.path.join(LOOT,"files","*")) + glob.glob(os.path.join(LOOT,"strace","trace*")):
    try:
        if os.path.getsize(fp) < 50*1024: continue
        with open(fp,"rb") as f: raw = f.read()
        n = carve_pes(raw, carved_dir, os.path.basename(fp))
        if n > 0:
            lines.append(f"- {os.path.basename(fp)}: {n} PEs extraidos")
    except: pass

# ------------- pcap -------------
pcap = os.path.join(LOOT,"net","capture.pcap")
if os.path.exists(pcap):
    lines.append(f"\n## Rede\n- {pcap} ({os.path.getsize(pcap)} bytes)")
    lines.append("- Abre no Wireshark pra ver TLS SNI (nome do host de download).")
    lines.append("- Dica rapida: `tshark -r capture.pcap -Y 'tls.handshake.type == 1' -T fields -e tls.handshake.extensions_server_name | sort -u`")

with open(REPORT,"w") as f:
    f.write("\n".join(lines))
print(f"[OK] {REPORT}")
