#!/usr/bin/env python3
"""Genera gitflow-v2.svg (y se renderiza a PNG con Chrome headless)."""
W, H = 1160, 1710
LANE = 70
COLS = [("Entorno Develop", 70, 430), ("Entorno Pre-producción", 430, 790), ("Entorno Producción", 790, 1150)]
ROWS = [("feature/*", 56, 340, "#0b6fd6", "#ffffff", "#ffffff"),
        ("develop", 340, 770, "#b3d4f7", "#1b2a3a", "#ffffff"),
        ("release/*", 770, 1010, "#fde0cd", "#1b2a3a", "#ffffff"),
        ("hotfix/*", 1010, 1230, "#f4a96d", "#1b2a3a", "#ffffff"),
        ("main", 1230, 1700, "#e0710f", "#ffffff", "#ffffff")]
o = []
a = o.append
a(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="Helvetica, Arial, sans-serif">')
a('<defs><marker id="ar" markerWidth="10" markerHeight="10" refX="8" refY="5" orient="auto"><path d="M1,1 L9,5 L1,9" fill="none" stroke="#1b2a3a" stroke-width="1.6"/></marker></defs>')
a(f'<rect width="{W}" height="{H}" fill="#fff"/>')
for name, y0, y1, fill, tc, _ in ROWS:
    a(f'<rect x="0" y="{y0}" width="{LANE}" height="{y1-y0}" fill="{fill}"/>')
    a(f'<text transform="translate(40,{(y0+y1)/2}) rotate(-90)" text-anchor="middle" font-size="17" font-weight="700" fill="{tc}">{name}</text>')
    a(f'<line x1="{LANE}" x2="{W}" y1="{y0}" y2="{y0}" stroke="#d5d9de"/>')
for t, x0, x1 in COLS:
    a(f'<rect x="{x0}" y="0" width="{x1-x0}" height="56" fill="#1b2a3a"/><text x="{x0+16}" y="34" font-size="18" font-weight="700" fill="#fff">{t}</text>')
    a(f'<line x1="{x1}" x2="{x1}" y1="56" y2="{H}" stroke="#d5d9de"/>')
a(f'<rect x="{LANE}" y="0" width="0" height="56"/>')

def pill(cx, cy, w, text, fill, stroke, sub=None):
    h = 38 if not sub else 46
    a(f'<rect x="{cx-w/2}" y="{cy-h/2}" width="{w}" height="{h}" rx="{h/2}" fill="{fill}" stroke="{stroke}" stroke-width="1.6"/>')
    if sub:
        a(f'<text x="{cx}" y="{cy-3}" text-anchor="middle" font-size="14" font-weight="700" fill="#1b2a3a">{text}</text>')
        a(f'<text x="{cx}" y="{cy+13}" text-anchor="middle" font-size="11" fill="#33475b">{sub}</text>')
    else:
        a(f'<text x="{cx}" y="{cy+5}" text-anchor="middle" font-size="14" font-weight="700" fill="#1b2a3a">{text}</text>')
def chip(cx, cy, w, text):
    a(f'<rect x="{cx-w/2}" y="{cy-12}" width="{w}" height="24" rx="4" fill="#efe8fb" stroke="#7c4dca" stroke-dasharray="4 3"/>')
    a(f'<text x="{cx}" y="{cy+4}" text-anchor="middle" font-size="12" font-weight="700" fill="#4b2a99">{text}</text>')
def node(cx, cy, fill, label, r=26):
    a(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}" stroke="#1b2a3a" stroke-width="2"/>')
    a(f'<g stroke="#1b2a3a" stroke-width="2" fill="none"><circle cx="{cx-6}" cy="{cy+8}" r="3.5"/><circle cx="{cx+8}" cy="{cy-5}" r="3.5"/><path d="M{cx-6},{cy+4.5} V{cy-12}"/><path d="M{cx+8},{cy-1.5} C{cx+8},{cy+3} {cx-6},{cy+0} {cx-6},{cy+4.5}"/></g>')
    a(f'<text x="{cx}" y="{cy+r+18}" text-anchor="middle" font-size="14" font-weight="700" fill="#1b2a3a">{label}</text>')
def person(cx, cy, label, w=170):
    a(f'<g stroke="#1b2a3a" stroke-width="1.8" fill="#fff"><circle cx="{cx}" cy="{cy-14}" r="9"/><path d="M{cx-15},{cy+10} a15,15 0 0 1 30,0 z"/></g>')
    a(f'<text x="{cx}" y="{cy+28}" text-anchor="middle" font-size="13" font-weight="700" fill="#1b2a3a">{label}</text>')
def arrow(pts, dash=False):
    d = " ".join(f"{x},{y}" for x, y in pts)
    a(f'<polyline points="{d}" fill="none" stroke="#1b2a3a" stroke-width="1.8" {"stroke-dasharray=\"6 4\"" if dash else ""} marker-end="url(#ar)"/>')
def num(cx, cy, t):
    a(f'<circle cx="{cx}" cy="{cy}" r="12" fill="#1b2a3a"/><text x="{cx}" y="{cy+4.5}" text-anchor="middle" font-size="12" font-weight="700" fill="#fff">{t}</text>')

BL = ("#cfe3fb", "#1f6fd1"); BD = ("#b3d4f7", "#1f6fd1"); OR = ("#fde0cd", "#d9772e"); HF = ("#f7be90", "#d9772e"); MN = ("#fde0cd", "#c25e00")
DX, PX, RX = 250, 610, 970

# ── feature ──
node(120, 120, "#0b6fd6", "feature/*")
pill(DX+40, 110, 190, "Push", *BL); pill(DX+40, 170, 190, "Unit tests", *BL); pill(DX+40, 230, 190, "SonarQube", *BL)
arrow([(146, 120), (DX-55, 110)]); arrow([(DX+40, 129), (DX+40, 151)]); arrow([(DX+40, 189), (DX+40, 211)])
num(DX+175, 110, "1")
person(PX+10, 150, "PR a develop (squash)")
a(f'<text x="{PX+10}" y="{112}" text-anchor="middle" font-size="11" fill="#33475b">título válido: Conventional Commits</text>')
arrow([(DX+135, 230), (PX+10, 230), (PX+10, 196)], dash=True)
arrow([(PX+10, 232), (PX+10, 385), (DX+30, 385)], dash=True)
# ── develop ──
node(DX, 385, "#b3d4f7", "develop"); num(DX-50, 370, "2")
ys = [490, 546, 610, 674, 738]
items = [("Unit tests", None), ("SonarQube", None), ("Build + push imagen", "imagen X.Y.Z-prerelease.N"), ("Tag git", "vX.Y.Z-prerelease.N"), ("Deploy DEV (helm)", "helm upgrade --atomic --wait")]
arrow([(DX, 440), (DX, 471)])
for (t, sub), yy in zip(items, ys): pill(DX, yy, 210, t, *BD, sub=sub)
hs = [19, 19, 23, 23, 23]
for i in range(4): arrow([(DX, ys[i]+hs[i]), (DX, ys[i+1]-hs[i+1])])
person(PX+10, 470, "Botón «Cut release»")
a(f'<text x="{PX+10}" y="{432}" text-anchor="middle" font-size="11" fill="#33475b">calcula X.Y.Z y crea release/X.Y.Z</text>')
arrow([(DX+30, 392), (PX-45, 462)], dash=True); num(PX-90, 480, "3")
# ── release ──
node(120, 815, "#fde0cd", "release/X.Y.Z"); num(78, 790, "4")
arrow([(PX+10, 520), (PX+10, 775), (140, 775), (128, 775)], dash=True)
pill(DX+30, 815, 200, "Build + push imagen", *OR, sub="imagen X.Y.Z-rc.N")
arrow([(148, 815), (DX-70, 815)]); chip(DX+30, 865, 130, "vX.Y.Z-rc.N")
pill(PX+10, 815, 200, "Deploy PRE (helm)", *OR, sub="imagen X.Y.Z-rc.N"); arrow([(DX+130, 815), (PX-90, 815)]); num(PX+130, 790, "5")
pill(PX+10, 890, 210, "Abre PR a main (auto)", *OR, sub="solo si Deploy PRE OK"); arrow([(PX+10, 839), (PX+10, 867)])
a(f'<text x="{DX+30}" y="915" text-anchor="middle" font-size="11" fill="#33475b">sin tests/Sonar: ya pasaron en develop</text>')
person(PX+10, 960, "Merge PR a main (merge commit)"); arrow([(PX+10, 913), (PX+10, 943)], dash=True); num(PX+190, 955, "6")
arrow([(PX+10, 990), (PX+10, 1262)], dash=True)
# ── hotfix ──
person(DX-120, 1060, "Botón «Cut hotfix»")
node(DX+25, 1085, "#f7be90", "hotfix/X.Y.Z+1"); num(DX-25, 1062, "HF1")
arrow([(DX-90, 1068), (DX-5, 1080)], dash=True)
pill(PX-100, 1085, 180, "Build + push", *HF, sub="imagen X.Y.Z+1-rc.N"); chip(PX-100, 1135, 140, "vX.Y.Z+1-rc.N")
arrow([(DX+52, 1085), (PX-192, 1085)])
pill(PX+170, 1085, 200, "Deploy PRE (helm)", *HF, sub="luego PR auto y merge a main"); arrow([(PX-8, 1085), (PX+68, 1085)]); num(PX+295, 1085, "HF2")
arrow([(PX+170, 1109), (PX+170, 1175), (PX+34, 1175), (PX+34, 1272)], dash=True)
a(f'<text x="{DX+30}" y="{1195}" text-anchor="middle" font-size="11" fill="#33475b">hotfix sale de main · mismo camino que release</text>')
# ── main ──
node(PX+10, 1290, "#e0710f", "main"); chip(PX+80, 1325, 80, "vX.Y.Z")
pill(PX+10, 1400, 230, "Retag imagen (sin rebuild)", *MN, sub="X.Y.Z-rc.N → X.Y.Z (mismo digest)"); arrow([(PX+10, 1345), (PX+10, 1377)])
num(PX-135, 1400, "7")
pill(PX+10, 1485, 230, "Deploy PRE (helm)", *MN, sub="imagen X.Y.Z"); arrow([(PX+10, 1424), (PX+10, 1462)])
person(RX, 1480, "Gated approval"); arrow([(PX+127, 1485), (RX-40, 1485)]); num(RX+95, 1470, "8")
pill(RX, 1565, 200, "Deploy PRO (helm)", *MN, sub="imagen X.Y.Z"); arrow([(RX, 1512), (RX, 1542)])
pill(RX, 1632, 230, "Tag vX.Y.Z + Release", *MN, sub="solo tras Deploy PRO OK"); arrow([(RX, 1589), (RX, 1609)]); num(RX+135, 1585, "9")
a(f'<rect x="{RX-100}" y="1665" width="200" height="30" rx="15" fill="{MN[0]}" stroke="{MN[1]}" stroke-width="1.6"/><text x="{RX}" y="1685" text-anchor="middle" font-size="14" font-weight="700" fill="#1b2a3a">Merge main → develop</text>')
arrow([(RX, 1656), (RX, 1665)]); num(RX+135, 1645, "10")
arrow([(RX+100, 1680), (1135, 1680), (1135, 392), (DX+30, 392)], dash=True)
a(f'<text transform="translate(1122,1000) rotate(-90)" text-anchor="middle" font-size="12" fill="#33475b">sync automático (directo, o PR sync/main-vX.Y.Z si hay conflicto) y re-dispara develop</text>')
a('</svg>')
open("gitflow-v2.svg", "w").write("\n".join(o))
