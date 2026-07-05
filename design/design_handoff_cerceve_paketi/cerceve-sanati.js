// Himbil - Cerceve Paketi SVG uretim kodu
// Tuval 72x72, merkez (36,36), avatar deligi r~26 (cerceve bandi r 26-34)
// Kullanim: svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 72 72">' + ART.alev() + '</svg>'

function skStar4(x, y, r, f, o) {
  return '<path d="M' + x + ' ' + (y - r) + ' C' + (x + r * .22) + ' ' + (y - r * .22) + ' ' + (x + r * .22) + ' ' + (y - r * .22) + ' ' + (x + r) + ' ' + y
    + ' C' + (x + r * .22) + ' ' + (y + r * .22) + ' ' + (x + r * .22) + ' ' + (y + r * .22) + ' ' + x + ' ' + (y + r)
    + ' C' + (x - r * .22) + ' ' + (y + r * .22) + ' ' + (x - r * .22) + ' ' + (y + r * .22) + ' ' + (x - r) + ' ' + y
    + ' C' + (x - r * .22) + ' ' + (y - r * .22) + ' ' + (x - r * .22) + ' ' + (y - r * .22) + ' ' + x + ' ' + (y - r) + ' Z" fill="' + f + '"' + (o ? ' opacity="' + o + '"' : '') + '/>';
}
function afRing(r, color, w) { return '<circle cx="36" cy="36" r="' + r + '" fill="none" stroke="' + color + '" stroke-width="' + w + '"/>'; }
function afPt(deg, r) { const a = (deg - 90) * Math.PI / 180; return { x: Math.round((36 + r * Math.cos(a)) * 10) / 10, y: Math.round((36 + r * Math.sin(a)) * 10) / 10 }; }
function afDots(n, r, rad, color, offset, opacity) {
  let s = '';
  for (let i = 0; i < n; i++) { const p = afPt((offset || 0) + i * 360 / n, r); s += '<circle cx="' + p.x + '" cy="' + p.y + '" r="' + rad + '" fill="' + color + '"' + (opacity ? ' opacity="' + opacity + '"' : '') + '/>'; }
  return s;
}
function afDia(x, y, rx, ry, color, rot) {
  const d = 'M' + x + ' ' + (y - ry) + ' L' + (x + rx) + ' ' + y + ' L' + x + ' ' + (y + ry) + ' L' + (x - rx) + ' ' + y + ' Z';
  return '<path d="' + d + '" fill="' + color + '"' + (rot ? ' transform="rotate(' + rot + ' ' + x + ' ' + y + ')"' : '') + '/>';
}
function afDiaRing(n, r, rx, ry, colors, offset, align) {
  let s = '';
  for (let i = 0; i < n; i++) { const deg = (offset || 0) + i * 360 / n; const p = afPt(deg, r); s += afDia(p.x, p.y, rx, ry, colors[i % colors.length], align ? deg : 0); }
  return s;
}
function afHex(x, y, r, color, sw) {
  let d = '';
  for (let i = 0; i < 6; i++) { const a = Math.PI / 3 * i - Math.PI / 6; d += (i ? 'L' : 'M') + Math.round((x + r * Math.cos(a)) * 10) / 10 + ' ' + Math.round((y + r * Math.sin(a)) * 10) / 10; }
  return '<path d="' + d + 'Z" fill="none" stroke="' + color + '" stroke-width="' + sw + '"/>';
}

const ART = {
  standart: () => afRing(30, '#C6BAA6', 6) + afRing(26.8, '#A89B84', 1.4),
  alev: () => afDots(12, 33, 4, '#FF6F5A') + afDots(12, 34, 2.4, '#F0A93B', 15) + afRing(30, '#E14B3B', 7) + afDots(12, 30, 1.6, '#FFD9A0', 15),
  simit: () => {
    let seeds = '';
    for (let i = 0; i < 16; i++) {
      const deg = i * 22.5 + (i % 2 ? 8 : -6);
      const p = afPt(deg, 30 + (i % 3 - 1) * 1.6);
      seeds += '<ellipse cx="' + p.x + '" cy="' + p.y + '" rx="1.9" ry="1" fill="#FFF0D0" transform="rotate(' + (deg + 40) + ' ' + p.x + ' ' + p.y + ')"/>';
    }
    return afRing(30, '#D9973F', 9) + afRing(30, '#C9862E', 1) + seeds;
  },
  karpuz: () => afRing(32.5, '#2F7A3E', 4.5) + afRing(29.8, '#CFEBB4', 2.2) + afRing(27.5, '#F25C6E', 4.5) + afDiaRing(10, 27.5, 1, 1.9, ['#4A2318'], 18, true),
  papatya: () => afDots(12, 31.5, 5.2, '#FF9FB2') + afDots(12, 32.5, 2, '#FFD9E0', 15) + afRing(27.2, '#F7C042', 4.2),
  konfeti: () => {
    let bits = '';
    const cols = ['#E14B3B', '#2F9C8F', '#F0A93B', '#8E5FC7'];
    for (let i = 0; i < 12; i++) {
      const deg = i * 30 + (i % 2 ? 10 : -4);
      const p = afPt(deg, 30 + (i % 3 - 1) * 1.5);
      const c = cols[i % 4];
      if (i % 3 === 0) bits += afDia(p.x, p.y, 1.6, 2.4, c, deg + 30);
      else if (i % 3 === 1) bits += '<circle cx="' + p.x + '" cy="' + p.y + '" r="1.9" fill="' + c + '"/>';
      else bits += '<rect x="' + (p.x - 1.7) + '" y="' + (p.y - 1.1) + '" width="3.4" height="2.2" rx=".6" fill="' + c + '" transform="rotate(' + (deg + 55) + ' ' + p.x + ' ' + p.y + ')"/>';
    }
    return afRing(30, '#F3E7CE', 8) + afRing(33.8, '#E3D2B0', 1.2) + afRing(26.2, '#E3D2B0', 1.2) + bits;
  },
  misket: () => {
    const cols = ['#E14B3B', '#F0A93B', '#2F9C8F', '#8E5FC7'];
    let s = afRing(30, '#C9BFAE', 2.4);
    for (let i = 0; i < 12; i++) { const p = afPt(i * 30, 30); s += '<circle cx="' + p.x + '" cy="' + p.y + '" r="4.4" fill="' + cols[i % 4] + '"/><circle cx="' + (p.x - 1.3) + '" cy="' + (p.y - 1.3) + '" r="1.2" fill="#FFF" opacity=".55"/>'; }
    return s;
  },
  lale: () => afRing(30, '#B93424', 6.5) + afDiaRing(8, 32.6, 2.4, 3.4, ['#FF6F5A'], 0, true) + afDots(8, 29, 1.6, '#5FA84C', 22.5),
  petek: () => {
    let s = afRing(30, '#E8A61E', 8.5);
    for (let i = 0; i < 9; i++) { const p = afPt(i * 40, 30); s += afHex(p.x, p.y, 3.4, '#B96F12', 1.4); }
    return s + afDots(9, 30, 1, '#FFD98A', 20);
  },
  kilim: () => afRing(30, '#7A3020', 9) + afDiaRing(10, 30, 2.4, 3.2, ['#E8A61E', '#2F9C8F'], 0, true) + afDots(10, 30, 1, '#F5E6C8', 18) + afRing(34.2, '#5C2416', 1.2) + afRing(25.8, '#5C2416', 1.2),
  gece: () => {
    let s = afRing(30, '#2B2258', 9);
    [[0, 3.2], [55, 2.2], [105, 2.8], [160, 2], [210, 3], [265, 2.2], [315, 2.6]].forEach(st => { const p = afPt(st[0], 30); s += skStar4(p.x, p.y, st[1], '#F0C96B'); });
    return s + afDots(14, 30, .8, '#F5E6C8', 12, '.8');
  },
  nazar: () => {
    let s = afRing(31.5, '#2E6FA8', 5.5) + afRing(28, '#FFF', 3) + afRing(25.9, '#5FA8D8', 1.6);
    for (let i = 0; i < 6; i++) { const p = afPt(i * 60, 31.5); s += '<circle cx="' + p.x + '" cy="' + p.y + '" r="3" fill="#FFF"/><circle cx="' + p.x + '" cy="' + p.y + '" r="1.4" fill="#173A5E"/>'; }
    return s;
  },
  tac: () => afDiaRing(12, 33.5, 2, 4.2, ['#F0C96B'], 0, true) + afRing(30, '#C9962A', 7) + afDots(3, 30, 1.9, '#E14B3B') + afDots(3, 30, 1.9, '#2F9C8F', 60) + afRing(26.8, '#A87718', 1.2),
  yildiz: () => {
    let s = afRing(30, '#8E5FC7', 7);
    [[20, 3.4, '#F5E0FF'], [80, 2.4, '#C9A7F5'], [135, 3, '#F5E0FF'], [200, 2.6, '#C9A7F5'], [250, 3.4, '#F5E0FF'], [310, 2.4, '#C9A7F5']].forEach(st => { const p = afPt(st[0], 30); s += skStar4(p.x, p.y, st[1], st[2]); });
    return s + afDots(12, 30, .9, '#E8D5FF', 5, '.8');
  },
  elmas: () => {
    let s = afRing(30, '#5FB9D8', 7) + afDiaRing(8, 30, 2.6, 3.4, ['#BFE9F5'], 0, true);
    [[22, 2], [112, 1.8], [202, 2], [292, 1.8]].forEach(st => { const p = afPt(st[0], 33.5); s += skStar4(p.x, p.y, st[1], '#FFF', .95); });
    return s + afRing(26.7, '#3E88B0', 1.2);
  },
};
