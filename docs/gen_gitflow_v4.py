#!/usr/bin/env python3
"""Genera gitflow-v4.svg (se renderiza a PNG con Chrome headless)."""
W, H = 1160, 1690
LANE = 70
COLS = [("Entorno Develop", 70, 430), ("Entorno Pre-producción", 430, 790), ("Entorno Producción", 790, 1150)]
ROWS = [("feature/*", 56, 340, "#0b6fd6", "#ffffff"), ("develop", 340, 770, "#b3d4f7", "#1b2a3a"),
        ("release/*", 770, 1060, "#fde0cd", "#1b2a3a"), ("hotfix/*", 1060, 1310, "#f4a96d", "#1b2a3a"),
        ("main", 1310, 1690, "#e0710f", "#ffffff")]
o = []; a = o.append
a(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="Helvetica, Arial, sans-serif">')
a('<defs><marker id="ar" markerWidth="10" markerHeight="10" refX="8" refY="5" orient="auto"><path d="M1,1 L9,5 L1,9" fill="none" stroke="#1b2a3a" stroke-width="1.6"/></marker></defs>')
a(f'<rect width="{W}" height="{H}" fill="#fff"/>')
for name, y0, y1, fill, tc in ROWS:
    a(f'<rect x="0" y="{y0}" width="{LANE}" height="{y1-y0}" fill="{fill}"/>')
    a(f'<text transform="translate(40,{(y0+y1)/2}) rotate(-90)" text-anchor="middle" font-size="17" font-weight="700" fill="{tc}">{name}</text>')
    a(f'<line x1="{LANE}" x2="{W}" y1="{y0}" y2="{y0}" stroke="#d5d9de"/>')
for t, x0, x1 in COLS:
    a(f'<rect x="{x0}" y="0" width="{x1-x0}" height="56" fill="#1b2a3a"/><text x="{x0+16}" y="34" font-size="18" font-weight="700" fill="#fff">{t}</text>')
    a(f'<line x1="{x1}" x2="{x1}" y1="56" y2="{H}" stroke="#d5d9de"/>')

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
def person(cx, cy, label):
    a(f'<g stroke="#1b2a3a" stroke-width="1.8" fill="#fff"><circle cx="{cx}" cy="{cy-14}" r="9"/><path d="M{cx-15},{cy+10} a15,15 0 0 1 30,0 z"/></g>')
    a(f'<text x="{cx}" y="{cy+28}" text-anchor="middle" font-size="13" font-weight="700" fill="#1b2a3a">{label}</text>')
def note(x, y, t, anchor="middle"):
    a(f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-size="11" fill="#33475b">{t}</text>')
def arrow(pts, dash=False, head=True):
    d = " ".join(f"{x},{y}" for x, y in pts)
    st = ' stroke-dasharray="6 4"' if dash else ""
    mk = ' marker-end="url(#ar)"' if head else ""
    a(f'<polyline points="{d}" fill="none" stroke="#1b2a3a" stroke-width="1.8"{st}{mk}/>')
def num(cx, cy, t):
    r = 12 if len(t) < 3 else 15
    a(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="#1b2a3a"/><text x="{cx}" y="{cy+4}" text-anchor="middle" font-size="{12 if len(t) < 3 else 10}" font-weight="700" fill="#fff">{t}</text>')

BL = ("#cfe3fb", "#1f6fd1"); BD = ("#b3d4f7", "#1f6fd1"); OR = ("#fde0cd", "#d9772e"); HF = ("#f7be90", "#d9772e"); MN = ("#fde0cd", "#c25e00")
DX, PX = 250, 610; RA, RB = 880, 1050

# ── feature ──
node(120, 120, "#0b6fd6", "feature/*")
pill(DX+40, 110, 190, "Push", *BL); pill(DX+40, 170, 190, "Unit tests", *BL); pill(DX+40, 230, 190, "SonarQube", *BL)
arrow([(146, 120), (DX-55, 110)]); arrow([(DX+40, 129), (DX+40, 151)]); arrow([(DX+40, 189), (DX+40, 211)])
num(DX+175, 110, "1")
person(PX+10, 150, "Merge request"); note(PX+10, 112, "a develop (squash) · título Conventional Commits")
arrow([(DX+135, 230), (PX+10, 230), (PX+10, 196)], dash=True); num(PX+90, 150, "2")
arrow([(PX+10, 232), (PX+10, 385), (DX+30, 385)], dash=True)
# ── develop (dev + pre) ──
node(DX, 385, "#b3d4f7", "develop"); num(DX-50, 370, "3")
items = [("Unit tests", None, 478), ("SonarQube", None, 526), ("Build + push imagen", "imagen X.Y.Z-prerelease.N", 584),
         ("Scan imagen · anchore/scan", None, 636), ("Deploy DEV", "imagen X.Y.Z-prerelease.N", 690)]
arrow([(DX, 440), (DX, 459)])
for (t, sub, yy) in items: pill(DX, yy, 230, t, *BD, sub=sub)
for k in range(4):
    h0 = 23 if items[k][1] else 19; h1 = 23 if items[k+1][1] else 19
    arrow([(DX, items[k][2]+h0), (DX, items[k+1][2]-h1)])
num(DX+135, 636, "4"); num(DX+135, 668, "5")
pill(PX+10, 672, 250, "Clone imagen dev → pre", *BD, sub="X.Y.Z-rc.N + sha-xxxxxxx (mismo digest)")
arrow([(DX+115, 690), (480, 690), (480, 672), (PX-115, 672)]); chip(PX+10, 626, 240, "rc.N = tag de imagen (ACR), no de git"); num(PX+150, 650, "6")
pill(PX+10, 733, 250, "Deploy PRE", *BD, sub="OK = commit validado en PRE"); arrow([(PX+10, 695), (PX+10, 710)]); num(PX+150, 733, "7")
note(115, 748, "cada merge a develop actualiza DEV y PRE", "start"); note(115, 762, "(PRE congelado si hay release/hotfix abierto)", "start")
# ── release (promocion a PRO desde la rama) ──
node(150, 830, "#fde0cd", "release/X.Y.Z"); num(110, 800, "8")
arrow([(DX-24, 395), (100, 395), (100, 830), (124, 830)], dash=True)
pill(PX+10, 830, 250, "Clone imagen pre → pro", *OR, sub="sha-xxxxxxx → X.Y.Z (sin rebuild)")
arrow([(176, 830), (PX-115, 830)]); arrow([(PX+10, 756), (PX+10, 807)], dash=True); num(PX+150, 805, "9")
person(RA, 830, "Gated approval"); arrow([(PX+135, 830), (RA-30, 830)]); num(RA+55, 815, "10")
pill(RA, 940, 150, "Deploy PRO", *OR, sub="imagen X.Y.Z"); arrow([(RA, 862), (RA, 917)]); num(RA+100, 925, "11")
note(215, 905, "«Release» corta en el último commit validado en PRE", "start")
note(215, 921, "(deployment OK en pre): no construye, promueve esa imagen", "start")
note(215, 945, "fix en release/*: tests + sonar + build + scan → rc.N+1 → PRE", "start")
# ── hotfix ──
node(150, 1130, "#f7be90", "hotfix/X.Y.Z+1"); num(110, 1100, "HF1")
arrow([(914, 1430), (100, 1430), (100, 1130), (124, 1130)], dash=True)
pill(262, 1130, 130, "Tests + Sonar", *HF); arrow([(176, 1130), (197, 1130)]); num(262, 1098, "HF2")
pill(410, 1130, 130, "Build + push", *HF, sub="imagen X.Y.Z+1-rc.N"); arrow([(327, 1130), (345, 1130)]); num(410, 1098, "HF3")
chip(410, 1182, 190, "rc.N = tag de imagen (ACR)")
pill(555, 1130, 120, "Scan imagen", *HF, sub="anchore/scan"); arrow([(475, 1130), (495, 1130)]); num(555, 1098, "HF4")
pill(700, 1130, 130, "Deploy PRE", *HF, sub="imagen X.Y.Z+1-rc.N"); arrow([(615, 1130), (635, 1130)]); num(700, 1098, "HF5")
person(RB, 1130, "Gated approval"); arrow([(765, 1130), (RB-30, 1130)]); num(RB-75, 1110, "HF6")
pill(RB, 1240, 150, "Deploy PRO", *HF, sub="imagen X.Y.Z+1"); arrow([(RB, 1162), (RB, 1217)]); num(RB-100, 1215, "HF7")
note(115, 1272, "se despliega a PRO desde su propia rama y se sincroniza", "start"); note(115, 1288, "con develop y con la release abierta", "start")
# ── main (solo tras PRO OK) ──
arrow([(RA, 963), (RA, 1385), (970, 1385), (970, 1404)], dash=True)
arrow([(RB, 1263), (RB, 1385), (975, 1385)], dash=True, head=False)
note(RA-12, 1372, "merge a main solo si PRO OK", "end")
node(970, 1430, "#e0710f", "main"); num(1020, 1405, "12"); chip(1075, 1430, 90, "vX.Y.Z")
pill(970, 1530, 220, "Tag vX.Y.Z + Release", *MN, sub="sobre el merge commit"); arrow([(970, 1478), (970, 1507)])
pill(970, 1620, 220, "Merge to develop", *MN, sub="sync main → develop"); arrow([(970, 1553), (970, 1597)]); num(1100, 1620, "13")
arrow([(1080, 1620), (1135, 1620), (1135, 392), (DX+30, 392)], dash=True)
a(f'<text transform="translate(1150,1000) rotate(-90)" text-anchor="middle" font-size="12" fill="#33475b">solo tras Deploy OK en PRO (release y hotfix)</text>')
a(f'<rect x="{PX-140}" y="1470" width="330" height="130" rx="8" fill="#fff7ee" stroke="#c25e00"/>')
a(f'<text x="{PX+25}" y="1498" text-anchor="middle" font-size="14" font-weight="700" fill="#1b2a3a">main = siempre lo desplegado en PRO</text>')
note(PX+25, 1522, "· DEV y PRE se actualizan desde develop (sin tags git)")
note(PX+25, 1540, "· PRO se despliega desde release/* y hotfix/*")
note(PX+25, 1558, "· único tag git: vX.Y.Z, tras el deploy OK en PRO")
note(PX+25, 1576, "· si PRO falla, ni main ni tags se tocan")
a('</svg>')
open("gitflow-v4.svg", "w").write("\n".join(o))
