// CloudView — shared tokens, sky scenes, AI overlay drawings, icons.
// All exports go to window so other Babel files can use them.

// ─────────────────────────────────────────────────────────────
// Themes — 4 aesthetic variants exposed via Tweaks
// ─────────────────────────────────────────────────────────────
const CV_THEMES = {
  airy: {
    name: 'Airy',
    bg: '#F6F7F9',
    surface: '#FFFFFF',
    ink: '#0B1220',
    inkSoft: 'rgba(11,18,32,0.62)',
    inkMute: 'rgba(11,18,32,0.42)',
    line: 'rgba(11,18,32,0.08)',
    lineSoft: 'rgba(11,18,32,0.05)',
    accent: 'oklch(0.62 0.13 230)',     // sky blue
    accentSoft: 'oklch(0.94 0.04 230)',
    warm: 'oklch(0.78 0.12 60)',         // sunset peach
    warmSoft: 'oklch(0.96 0.04 60)',
    chipBg: '#EEF0F4',
    dark: false,
  },
  editorial: {
    name: 'Editorial',
    bg: '#F2EFE8',
    surface: '#FBF8F1',
    ink: '#1A1612',
    inkSoft: 'rgba(26,22,18,0.6)',
    inkMute: 'rgba(26,22,18,0.4)',
    line: 'rgba(26,22,18,0.1)',
    lineSoft: 'rgba(26,22,18,0.06)',
    accent: 'oklch(0.55 0.14 35)',       // terracotta
    accentSoft: 'oklch(0.93 0.04 35)',
    warm: 'oklch(0.68 0.12 80)',
    warmSoft: 'oklch(0.94 0.05 80)',
    chipBg: '#EAE5DA',
    dark: false,
  },
  dusk: {
    name: 'Dusk',
    bg: '#0B1018',
    surface: '#141B27',
    ink: '#F4F6FA',
    inkSoft: 'rgba(244,246,250,0.65)',
    inkMute: 'rgba(244,246,250,0.42)',
    line: 'rgba(244,246,250,0.1)',
    lineSoft: 'rgba(244,246,250,0.06)',
    accent: 'oklch(0.74 0.13 250)',
    accentSoft: 'oklch(0.32 0.08 250)',
    warm: 'oklch(0.78 0.13 50)',
    warmSoft: 'oklch(0.35 0.08 50)',
    chipBg: '#1C2433',
    dark: true,
  },
  dreamy: {
    name: 'Dreamy',
    bg: '#F4EEF7',
    surface: '#FFFFFF',
    ink: '#251A30',
    inkSoft: 'rgba(37,26,48,0.62)',
    inkMute: 'rgba(37,26,48,0.4)',
    line: 'rgba(37,26,48,0.08)',
    lineSoft: 'rgba(37,26,48,0.05)',
    accent: 'oklch(0.7 0.13 320)',       // soft magenta
    accentSoft: 'oklch(0.94 0.04 320)',
    warm: 'oklch(0.82 0.1 70)',
    warmSoft: 'oklch(0.95 0.04 70)',
    chipBg: '#ECE2F1',
    dark: false,
  },
};

// ─────────────────────────────────────────────────────────────
// Sky scenes — drawn with gradients + soft cloud blobs. Each scene
// has a slug, a "background" gradient pair, and cloud paths/positions.
// The clouds are simple ellipses combined to make a puffy silhouette.
// ─────────────────────────────────────────────────────────────

// Re-usable cloud silhouette path — a chain of bumps; size with viewBox 0 0 200 80.
function CVCloudShape({ variant = 'puffy', fill = '#fff', opacity = 0.92 }) {
  // Each variant is hand-tuned for a different overall outline.
  const shapes = {
    puffy: 'M30 60 Q15 60 14 46 Q14 30 30 30 Q34 16 50 16 Q60 6 76 14 Q88 6 102 16 Q120 14 124 32 Q140 30 142 46 Q142 60 126 60 Z',
    long: 'M20 56 Q8 56 8 44 Q8 32 22 32 Q30 22 48 24 Q60 14 78 22 Q96 16 110 26 Q128 22 142 32 Q160 28 174 36 Q188 36 188 50 Q188 60 174 60 Z',
    cluster: 'M40 64 Q20 64 22 48 Q14 42 22 32 Q28 22 42 26 Q50 12 70 18 Q86 8 102 22 Q120 18 124 36 Q140 34 142 50 Q150 62 132 64 Z',
    wispy: 'M14 40 Q10 32 22 30 Q30 22 46 28 Q60 18 78 26 Q100 22 110 32 Q126 30 134 40 Q146 40 146 50 Q146 56 134 56 Q120 60 100 54 Q80 60 60 52 Q40 58 24 50 Q14 50 14 40 Z',
    tower: 'M28 70 Q14 68 16 54 Q8 44 18 36 Q14 22 30 22 Q36 8 56 12 Q70 0 82 14 Q98 8 100 26 Q116 24 116 42 Q128 42 128 56 Q132 70 116 70 Z',
  };
  return <path d={shapes[variant] || shapes.puffy} fill={fill} opacity={opacity} />;
}

// Render a stylized photo of sky+clouds at a given mood
function CVSkyPhoto({ mood = 'day', children, style = {} }) {
  const moods = {
    day: {
      grad: 'linear-gradient(180deg, #7CB7E5 0%, #B7DAF2 55%, #DCEDF7 100%)',
      clouds: [
        { variant: 'cluster', x: 6, y: 18, w: 58, op: 0.96 },
        { variant: 'puffy', x: 52, y: 42, w: 44, op: 0.9 },
        { variant: 'long', x: 0, y: 65, w: 60, op: 0.7 },
        { variant: 'wispy', x: 50, y: 10, w: 36, op: 0.5 },
      ],
    },
    golden: {
      grad: 'linear-gradient(180deg, #F4B27C 0%, #F6CC9C 40%, #FAE1C2 75%, #F8E9D4 100%)',
      clouds: [
        { variant: 'long', x: 4, y: 32, w: 70, op: 0.88, fill: '#FFF6E8' },
        { variant: 'cluster', x: 40, y: 52, w: 50, op: 0.9, fill: '#FBD4A8' },
        { variant: 'wispy', x: 0, y: 70, w: 60, op: 0.7, fill: '#F2A968' },
      ],
    },
    dusk: {
      grad: 'linear-gradient(180deg, #2A3654 0%, #4A4368 35%, #826388 70%, #C68A82 100%)',
      clouds: [
        { variant: 'long', x: 0, y: 40, w: 80, op: 0.7, fill: '#3A4368' },
        { variant: 'cluster', x: 35, y: 60, w: 56, op: 0.75, fill: '#5B526E' },
        { variant: 'wispy', x: 8, y: 25, w: 50, op: 0.5, fill: '#E8B89F' },
      ],
    },
    stormy: {
      grad: 'linear-gradient(180deg, #4A5566 0%, #6A7585 50%, #8A95A5 100%)',
      clouds: [
        { variant: 'tower', x: 8, y: 18, w: 60, op: 0.85, fill: '#2F3845' },
        { variant: 'cluster', x: 45, y: 35, w: 55, op: 0.78, fill: '#3F4858' },
        { variant: 'long', x: 0, y: 70, w: 70, op: 0.6, fill: '#5A6575' },
      ],
    },
    dawn: {
      grad: 'linear-gradient(180deg, #B8C8E8 0%, #E0CDD8 45%, #F4D9C8 80%, #F8E4D2 100%)',
      clouds: [
        { variant: 'puffy', x: 10, y: 30, w: 50, op: 0.88, fill: '#FFF' },
        { variant: 'long', x: 35, y: 50, w: 65, op: 0.75, fill: '#FBE0D4' },
        { variant: 'wispy', x: 5, y: 70, w: 55, op: 0.55, fill: '#F4C9B0' },
      ],
    },
  };
  const m = moods[mood] || moods.day;
  return (
    <div style={{ position: 'relative', overflow: 'hidden', background: m.grad, ...style }}>
      {/* Cloud layer */}
      <svg width="100%" height="100%" viewBox="0 0 100 100" preserveAspectRatio="none"
        style={{ position: 'absolute', inset: 0, display: 'block' }}>
        {m.clouds.map((c, i) => (
          <g key={i} transform={`translate(${c.x},${c.y}) scale(${c.w / 200},${c.w / 200})`}>
            <CVCloudShape variant={c.variant} fill={c.fill || '#FFFFFF'} opacity={c.op} />
          </g>
        ))}
      </svg>
      {/* Subtle film grain */}
      <div style={{
        position: 'absolute', inset: 0, mixBlendMode: 'overlay', opacity: 0.18, pointerEvents: 'none',
        backgroundImage: "url(\"data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' width='160' height='160'><filter id='n'><feTurbulence type='fractalNoise' baseFrequency='0.9' stitchTiles='stitch'/></filter><rect width='100%25' height='100%25' filter='url(%23n)' opacity='0.6'/></svg>\")",
      }} />
      {children}
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// AI line-drawing overlays. Each is a normalised SVG path in 0–100
// coords (viewBox 0 0 100 100). The component handles stroke style
// per the active aiStyle.
// ─────────────────────────────────────────────────────────────
const CV_DRAWINGS = {
  dragon: {
    label: 'a dragon',
    paths: [
      // Body S-curve
      'M12 70 C 25 55, 38 75, 48 60 S 70 40, 84 50',
      // Head
      'M84 50 q 6 -4 10 -2 q 2 2 0 6 q -2 4 -8 4',
      // Eye
      'M88 53 m -1 0 a 1 1 0 1 0 2 0 a 1 1 0 1 0 -2 0',
      // Wing
      'M50 58 q 6 -18 22 -16 q -8 6 -10 16',
      // Tail spikes
      'M14 70 l -3 4 M18 68 l -2 5 M22 66 l -1 5',
    ],
    dots: [],
  },
  whale: {
    label: 'a whale',
    paths: [
      // Body
      'M18 62 q 0 -22 30 -22 q 30 0 36 18 q -4 6 -12 6 q -28 4 -54 -2 z',
      // Tail
      'M14 60 q -6 -6 -10 -14 q 6 0 14 8',
      // Eye
      'M70 54 m -1 0 a 1 1 0 1 0 2 0 a 1 1 0 1 0 -2 0',
      // Smile
      'M64 58 q 4 3 10 1',
      // Spout
      'M44 38 q -2 -8 2 -16 M50 38 q 0 -8 4 -14 M56 38 q 2 -8 8 -12',
    ],
    dots: [],
  },
  dog: {
    label: 'a sleepy pup',
    paths: [
      // Head
      'M30 56 q 0 -20 22 -20 q 22 0 22 20 q 0 12 -22 12 q -22 0 -22 -12 z',
      // Ears
      'M30 46 q -8 -2 -10 8 q 4 4 12 0',
      'M74 46 q 8 -2 10 8 q -4 4 -12 0',
      // Eyes (closed lines for sleeping)
      'M42 52 q 3 2 6 0',
      'M58 52 q 3 2 6 0',
      // Snout
      'M48 60 q 4 4 8 0',
      'M52 58 v 2',
    ],
    dots: [],
  },
  castle: {
    label: 'a tiny castle',
    paths: [
      // Base wall
      'M20 70 L 20 50 L 26 50 L 26 44 L 32 44 L 32 50 L 38 50 L 38 38 L 50 38 L 50 50 L 56 50 L 56 44 L 62 44 L 62 50 L 68 50 L 68 70 Z',
      // Flag pole
      'M50 38 L 50 26',
      // Flag
      'M50 26 L 60 30 L 50 32 Z',
      // Door
      'M42 70 L 42 60 q 2 -4 4 -4 q 2 0 4 4 L 50 70',
      // Windows
      'M28 56 h 4 v 4 h -4 z',
      'M60 56 h 4 v 4 h -4 z',
    ],
    dots: [],
  },
  heart: {
    label: 'a soft heart',
    paths: [
      'M50 76 C 20 60, 14 36, 30 28 C 42 22, 50 32, 50 38 C 50 32, 58 22, 70 28 C 86 36, 80 60, 50 76 Z',
    ],
    dots: [],
  },
  spaceship: {
    label: 'a parked UFO',
    paths: [
      // Saucer
      'M18 56 q 16 -10 36 -10 q 20 0 36 10 q -16 8 -36 8 q -20 0 -36 -8 z',
      // Dome
      'M40 46 q 0 -14 20 -14 q 20 0 20 14',
      // Lights
      'M24 58 m -1 0 a 1 1 0 1 0 2 0 a 1 1 0 1 0 -2 0',
      'M40 60 m -1 0 a 1 1 0 1 0 2 0 a 1 1 0 1 0 -2 0',
      'M56 60 m -1 0 a 1 1 0 1 0 2 0 a 1 1 0 1 0 -2 0',
      'M72 60 m -1 0 a 1 1 0 1 0 2 0 a 1 1 0 1 0 -2 0',
      // Beam
      'M50 64 L 44 84 M50 64 L 56 84 M50 64 L 50 84',
    ],
    dots: [],
  },
};

// Stroke style by AI overlay mode
function cvStrokeProps(aiStyle, t) {
  switch (aiStyle) {
    case 'bold':
      return { stroke: t.accent, strokeWidth: 2.6, strokeDasharray: 'none', fill: 'none' };
    case 'dotted':
      return { stroke: '#FFFFFF', strokeWidth: 1.6, strokeDasharray: '0.1 3', strokeLinecap: 'round', fill: 'none' };
    case 'marker':
      return { stroke: 'rgba(255,255,255,0.95)', strokeWidth: 3.6, strokeLinecap: 'round', strokeLinejoin: 'round', fill: 'none', filter: 'url(#cv-rough)' };
    case 'thin':
    default:
      return { stroke: '#FFFFFF', strokeWidth: 1.8, strokeLinecap: 'round', strokeLinejoin: 'round', fill: 'none' };
  }
}

function CVAIOverlay({ drawing = 'dragon', aiStyle = 'thin', animate = false, theme, opacity = 1, label = true }) {
  const d = CV_DRAWINGS[drawing] || CV_DRAWINGS.dragon;
  const sp = cvStrokeProps(aiStyle, theme);
  // Drop-shadow so white strokes don't disappear against bright sky.
  // Bold (colored) overlay gets a lighter shadow so the color stays punchy.
  const shadow = aiStyle === 'bold'
    ? 'drop-shadow(0 1px 2px rgba(0,0,0,0.25))'
    : 'drop-shadow(0 1px 3px rgba(0,0,0,0.45)) drop-shadow(0 0 1px rgba(0,0,0,0.25))';
  return (
    <svg viewBox="0 0 100 100" preserveAspectRatio="none"
      style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', opacity, pointerEvents: 'none', filter: shadow }}>
      <defs>
        <filter id="cv-rough">
          <feTurbulence type="fractalNoise" baseFrequency="0.05" numOctaves="2" />
          <feDisplacementMap in="SourceGraphic" scale="1.2" />
        </filter>
      </defs>
      {d.paths.map((p, i) => (
        <path key={i} d={p} {...sp}
          style={animate ? {
            strokeDasharray: 220,
            strokeDashoffset: 220,
            animation: `cv-draw 1.8s ${i * 0.15}s cubic-bezier(0.65,0,0.35,1) forwards`,
          } : {}}
        />
      ))}
      {aiStyle === 'dotted' && d.paths.map((p, i) => (
        // For dotted/constellation style, add small "stars" at path corners
        <circle key={'c' + i} r="1.2" fill="#FFFFFF" cx={20 + i * 12} cy={50 + (i % 2) * 6} opacity="0.9" />
      ))}
    </svg>
  );
}

// ─────────────────────────────────────────────────────────────
// Icons — minimal line, 24x24
// ─────────────────────────────────────────────────────────────
const CVIcon = {
  cloud: (c = 'currentColor') => (
    <svg viewBox="0 0 24 24" width="100%" height="100%" fill="none" stroke={c} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M7 18a4 4 0 010-8 5 5 0 019.5-1.5A4.5 4.5 0 0117 18H7z" />
    </svg>
  ),
  camera: (c = 'currentColor') => (
    <svg viewBox="0 0 24 24" width="100%" height="100%" fill="none" stroke={c} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 8h3l2-2h6l2 2h3v11H4z" />
      <circle cx="12" cy="13.5" r="3.5" />
    </svg>
  ),
  map: (c = 'currentColor') => (
    <svg viewBox="0 0 24 24" width="100%" height="100%" fill="none" stroke={c} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M3 6l6-2 6 2 6-2v14l-6 2-6-2-6 2zM9 4v14M15 6v14" />
    </svg>
  ),
  profile: (c = 'currentColor') => (
    <svg viewBox="0 0 24 24" width="100%" height="100%" fill="none" stroke={c} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="8" r="4" />
      <path d="M4 20a8 8 0 0116 0" />
    </svg>
  ),
  bell: (c = 'currentColor') => (
    <svg viewBox="0 0 24 24" width="100%" height="100%" fill="none" stroke={c} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M6 16V11a6 6 0 0112 0v5l2 2H4l2-2zM10 20a2 2 0 004 0" />
    </svg>
  ),
  sparkle: (c = 'currentColor') => (
    <svg viewBox="0 0 24 24" width="100%" height="100%" fill="none" stroke={c} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 3v6M12 15v6M3 12h6M15 12h6" />
      <path d="M6 6l3 3M15 15l3 3M18 6l-3 3M9 15l-3 3" />
    </svg>
  ),
  arrow: (c = 'currentColor') => (
    <svg viewBox="0 0 24 24" width="100%" height="100%" fill="none" stroke={c} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M5 12h14M13 6l6 6-6 6" />
    </svg>
  ),
  grid: (c = 'currentColor') => (
    <svg viewBox="0 0 24 24" width="100%" height="100%" fill="none" stroke={c} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <rect x="3" y="3" width="7" height="7" /><rect x="14" y="3" width="7" height="7" />
      <rect x="3" y="14" width="7" height="7" /><rect x="14" y="14" width="7" height="7" />
    </svg>
  ),
  search: (c = 'currentColor') => (
    <svg viewBox="0 0 24 24" width="100%" height="100%" fill="none" stroke={c} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="11" cy="11" r="7" /><path d="M20 20l-3.5-3.5" />
    </svg>
  ),
  heart: (c = 'currentColor') => (
    <svg viewBox="0 0 24 24" width="100%" height="100%" fill="none" stroke={c} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 20s-7-4.5-7-10a4 4 0 017-2.6A4 4 0 0119 10c0 5.5-7 10-7 10z" />
    </svg>
  ),
  flash: (c = 'currentColor') => (
    <svg viewBox="0 0 24 24" width="100%" height="100%" fill="none" stroke={c} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M13 3L4 14h7l-1 7 9-11h-7l1-7z" />
    </svg>
  ),
  swap: (c = 'currentColor') => (
    <svg viewBox="0 0 24 24" width="100%" height="100%" fill="none" stroke={c} strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
      <path d="M7 4l-3 3 3 3M4 7h13a4 4 0 014 4M17 20l3-3-3-3M20 17H7a4 4 0 01-4-4" />
    </svg>
  ),
};

// ─────────────────────────────────────────────────────────────
// Generic helpers
// ─────────────────────────────────────────────────────────────
function CVChip({ children, theme, tone = 'neutral', style = {} }) {
  const bg = tone === 'accent' ? theme.accentSoft : tone === 'warm' ? theme.warmSoft : theme.chipBg;
  const fg = tone === 'accent' ? theme.accent : tone === 'warm' ? theme.warm : theme.inkSoft;
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      padding: '5px 10px', borderRadius: 999, background: bg, color: fg,
      fontSize: 12, fontWeight: 500, letterSpacing: 0.2,
      ...style,
    }}>{children}</span>
  );
}

function CVStatusBar({ theme, time = '9:41' }) {
  const c = theme.dark ? '#fff' : '#000';
  return (
    <div style={{
      height: 47, display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '15px 28px 0', position: 'relative', zIndex: 10, fontFamily: 'system-ui',
    }}>
      <span style={{ fontFamily: '-apple-system', fontWeight: 600, fontSize: 16, color: c, letterSpacing: -0.2 }}>{time}</span>
      <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
        <svg width="17" height="11" viewBox="0 0 19 12"><rect x="0" y="7.5" width="3.2" height="4.5" rx="0.7" fill={c}/><rect x="4.8" y="5" width="3.2" height="7" rx="0.7" fill={c}/><rect x="9.6" y="2.5" width="3.2" height="9.5" rx="0.7" fill={c}/><rect x="14.4" y="0" width="3.2" height="12" rx="0.7" fill={c}/></svg>
        <svg width="15" height="11" viewBox="0 0 17 12"><path d="M8.5 3.2C10.8 3.2 12.9 4.1 14.4 5.6L15.5 4.5C13.7 2.7 11.2 1.5 8.5 1.5C5.8 1.5 3.3 2.7 1.5 4.5L2.6 5.6C4.1 4.1 6.2 3.2 8.5 3.2Z" fill={c}/><circle cx="8.5" cy="10.5" r="1.5" fill={c}/></svg>
        <svg width="25" height="12" viewBox="0 0 27 13"><rect x="0.5" y="0.5" width="23" height="12" rx="3.5" stroke={c} strokeOpacity="0.4" fill="none"/><rect x="2" y="2" width="20" height="9" rx="1.5" fill={c}/></svg>
      </div>
    </div>
  );
}

// Phone container — the iOS-y rounded surface that hosts a screen.
// Used inside each design-canvas artboard so the chrome is consistent
// without re-rendering a full device frame each time.
function CVPhone({ theme, children, style = {} }) {
  return (
    <div style={{
      width: 402, height: 874,
      background: theme.bg, color: theme.ink,
      position: 'relative',
      overflow: 'hidden',
      fontFamily: '"Geist", "Inter Tight", -apple-system, system-ui, sans-serif',
      ...style,
    }}>
      {/* dynamic island */}
      <div style={{
        position: 'absolute', top: 11, left: '50%', transform: 'translateX(-50%)',
        width: 122, height: 35, borderRadius: 24, background: '#000', zIndex: 80,
      }} />
      <CVStatusBar theme={theme} />
      <div style={{ height: 'calc(100% - 47px)', position: 'relative' }}>{children}</div>
      {/* home indicator */}
      <div style={{
        position: 'absolute', bottom: 8, left: '50%', transform: 'translateX(-50%)',
        width: 134, height: 5, borderRadius: 100,
        background: theme.dark ? 'rgba(255,255,255,0.55)' : 'rgba(0,0,0,0.3)', zIndex: 90,
      }} />
    </div>
  );
}

// Bottom tab bar (used in main screens)
function CVTabBar({ theme, active = 'home' }) {
  const items = [
    { id: 'home', label: 'Today', icon: CVIcon.cloud },
    { id: 'map', label: 'Nearby', icon: CVIcon.map },
    { id: 'scan', label: '', icon: null }, // FAB slot
    { id: 'feed', label: 'Feed', icon: CVIcon.grid },
    { id: 'profile', label: 'You', icon: CVIcon.profile },
  ];
  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, bottom: 0,
      paddingBottom: 28, paddingTop: 8,
      background: theme.dark
        ? 'linear-gradient(180deg, rgba(20,27,39,0) 0%, rgba(20,27,39,0.92) 50%)'
        : 'linear-gradient(180deg, rgba(246,247,249,0) 0%, rgba(246,247,249,0.95) 50%)',
      backdropFilter: 'blur(20px)',
      WebkitBackdropFilter: 'blur(20px)',
      borderTop: `0.5px solid ${theme.line}`,
      display: 'flex', alignItems: 'center', justifyContent: 'space-around',
      zIndex: 50,
    }}>
      {items.map((it) => {
        if (it.id === 'scan') {
          return (
            <div key="scan" style={{
              width: 56, height: 56, borderRadius: 28, background: theme.ink, color: theme.bg,
              display: 'flex', alignItems: 'center', justifyContent: 'center',
              boxShadow: '0 6px 18px rgba(0,0,0,0.18), 0 1px 0 rgba(255,255,255,0.1) inset',
              marginTop: -16,
            }}>
              <div style={{ width: 24, height: 24 }}>{CVIcon.camera(theme.bg)}</div>
            </div>
          );
        }
        const isActive = active === it.id;
        const c = isActive ? theme.ink : theme.inkMute;
        return (
          <div key={it.id} style={{
            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3,
            color: c, fontSize: 10.5, fontWeight: 500, letterSpacing: 0.1, minWidth: 56,
          }}>
            <div style={{ width: 22, height: 22 }}>{it.icon(c)}</div>
            <span>{it.label}</span>
          </div>
        );
      })}
    </div>
  );
}

Object.assign(window, {
  CV_THEMES, CV_DRAWINGS, CVCloudShape, CVSkyPhoto, CVAIOverlay, cvStrokeProps,
  CVIcon, CVChip, CVStatusBar, CVPhone, CVTabBar,
});
