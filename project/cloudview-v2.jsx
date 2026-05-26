// CloudView v2 — the simplified single-screen hero.
// Live camera feed of the sky + a glass drawer that swipes up to reveal
// weather details and a quip about the AI-drawn shape.

const { useState, useEffect, useRef, useMemo, useCallback } = React;

const CV2_DEFAULTS = /*EDITMODE-BEGIN*/{
  "theme": "airy",
  "aiStyle": "thin",
  "quipTone": "witty",
  "mood": "day",
  "shape": "dragon",
  "drawerState": "peek"
}/*EDITMODE-END*/;

// Short label-style caption that sits directly under the drawing.
const CV2_CAPTIONS = {
  dragon: 'a dragon, mid-yawn',
  whale: 'a whale, drifting',
  dog: 'a sleeping pup',
  castle: 'a small castle',
  heart: 'a soft heart',
  spaceship: 'a parked UFO',
};

// Combo quips: shape × tone, with a weather hook baked in. Two beats:
// short setup + a weather-aware punchline.
// Today's mock weather: 72°, light cumulus, rain incoming in ~2h, wind 6 SW.
const CV2_QUIPS = {
  witty: {
    dragon: {
      title: 'Dragon situation',
      body: 'Better find cover, big guy — there’s rain in 2 hours and a wet flame is just an embarrassed lizard.',
    },
    whale: {
      title: 'Whale watch',
      body: 'A whale taking a 72° vacation. Migrating south at a brisk 6 mph, which for a whale is basically sprinting.',
    },
    dog: {
      title: 'Good boy',
      body: 'A pug napping on cumulus class. Will be gently rained on around 1pm. Will not notice.',
    },
    castle: {
      title: 'Castle in the air',
      body: 'Architecturally ambitious. Structural integrity rated: 6 mph SW. Drawbridge closes when the rain rolls in.',
    },
    heart: {
      title: 'A heart, suspiciously',
      body: 'Romance, but only until precipitation. 72° is statistically the warmest a sky has ever been emotional.',
    },
    spaceship: {
      title: 'Unidentified, mostly',
      body: 'A UFO refusing to parallel-park. Probably waiting out the 1pm rain like the rest of us.',
    },
  },
  whimsical: {
    dragon: {
      title: 'A small dragon',
      body: 'Learning the names of streets below. The rain at 1pm will teach it the word “umbrella.”',
    },
    whale: {
      title: 'A whale, drifting',
      body: 'Ferrying songs from one breeze to the next. The 6 mph wind is its slow conveyor belt south.',
    },
    dog: {
      title: 'Someone’s lost pup',
      body: 'Asleep on a pillow of weather. Will be tucked in by light rain at one.',
    },
    castle: {
      title: 'A castle, briefly',
      body: 'Built only on Tuesdays at 72°. Will dissolve politely when the showers arrive.',
    },
    heart: {
      title: 'A heart, then nothing',
      body: 'Briefly a heart, then a swan, then mist. The wind is doing the editing.',
    },
    spaceship: {
      title: 'A quiet traveler',
      body: 'Asking the southwest wind for directions. The wind, polite as ever, says “down, in two hours.”',
    },
  },
  punny: {
    dragon: {
      title: 'Mist-ical creature',
      body: 'High-altitude dragon. Forecast: partly fire-y, with a chance of damp pride at 1pm.',
    },
    whale: {
      title: 'Whale, whale, whale',
      body: 'What do we have here — a humpback in a humpfront? Cumulonimbus inbound. Spout up.',
    },
    dog: {
      title: 'Bark-a-cumulus',
      body: 'A very good boy of the upper troposphere. Currently 72° and a 6 mph belly rub.',
    },
    castle: {
      title: 'Air B-and-B',
      body: 'Castle in the air. Literally. Light showers will be checking in around one.',
    },
    heart: {
      title: 'Atmos-fond of you',
      body: 'Heart-shaped, 92% sure. Forecast: warm, with a 100% chance of feelings.',
    },
    spaceship: {
      title: 'U.F.O.',
      body: 'Unidentified Floating Object. Stationary until precipitation — even aliens hate damp upholstery.',
    },
  },
};

function cv2Quip(s, t) {
  const set = (CV2_QUIPS[t] || CV2_QUIPS.witty)[s];
  return set || { title: '', body: '' };
}
function cv2Caption(s) { return CV2_CAPTIONS[s] || ''; }

// ─────────────────────────────────────────────────────────────
// Drawer drag hook — returns translateY ratio (0 = closed/peek, 1 = full)
// and bindings to mount on the handle. Supports snap to 0, 0.55, 1.
// ─────────────────────────────────────────────────────────────
function useDrawer(initial = 0) {
  const [pos, setPos] = useState(initial);  // 0..1
  const [dragging, setDragging] = useState(false);
  const drag = useRef(null);
  const containerH = useRef(0);

  const onStart = (e) => {
    e.preventDefault();
    const y = e.touches ? e.touches[0].clientY : e.clientY;
    drag.current = { startY: y, startPos: pos };
    setDragging(true);
    const ct = e.currentTarget.closest('[data-cv2-stage]');
    if (ct) containerH.current = ct.getBoundingClientRect().height;
  };
  const onMove = useCallback((e) => {
    if (!drag.current) return;
    const y = e.touches ? e.touches[0].clientY : e.clientY;
    const dy = drag.current.startY - y;
    // pos in [0..1] where 1 means top of stage
    const range = containerH.current * 0.72; // travel
    const next = Math.max(0, Math.min(1, drag.current.startPos + dy / range));
    setPos(next);
  }, []);
  const onEnd = useCallback(() => {
    if (!drag.current) return;
    // snap
    setPos((p) => p < 0.22 ? 0 : p < 0.78 ? 0.55 : 1);
    drag.current = null;
    setDragging(false);
  }, []);

  useEffect(() => {
    if (!dragging) return;
    window.addEventListener('mousemove', onMove);
    window.addEventListener('mouseup', onEnd);
    window.addEventListener('touchmove', onMove, { passive: false });
    window.addEventListener('touchend', onEnd);
    return () => {
      window.removeEventListener('mousemove', onMove);
      window.removeEventListener('mouseup', onEnd);
      window.removeEventListener('touchmove', onMove);
      window.removeEventListener('touchend', onEnd);
    };
  }, [dragging, onMove, onEnd]);

  return { pos, setPos, dragging, handle: { onMouseDown: onStart, onTouchStart: onStart } };
}

// ─────────────────────────────────────────────────────────────
// The hero screen — interactive.
// ─────────────────────────────────────────────────────────────
function CV2Hero({ theme, aiStyle, quipTone, mood, shape, drawerInitial = 0, onChangeShape, onChangeMood }) {
  const drawer = useDrawer(drawerInitial === 'open' ? 0.55 : drawerInitial === 'full' ? 1 : 0);

  // Trigger draw-in animation when shape changes (key remount)
  const animKey = useMemo(() => shape + '|' + aiStyle, [shape, aiStyle]);

  // Sky mood determines colors for status text
  const onDarkSky = mood === 'dusk' || mood === 'stormy';
  const statusColor = onDarkSky ? '#fff' : '#0B1220';
  const muted = onDarkSky ? 'rgba(255,255,255,0.85)' : 'rgba(11,18,32,0.75)';

  // Drawer transforms
  const peekHeight = 220;
  // pos 0..1 → drawer fills from peekHeight to 95% of stage height
  const fullHeight = (h) => peekHeight + (h * 0.95 - peekHeight) * drawer.pos;

  // Weather + AI status mock
  const detected = {
    dragon: { conf: 0.94, type: 'cumulus humilis', class: 'animal' },
    whale: { conf: 0.91, type: 'altocumulus', class: 'animal' },
    dog: { conf: 0.88, type: 'cumulus mediocris', class: 'animal' },
    castle: { conf: 0.85, type: 'cumulus congestus', class: 'architecture' },
    heart: { conf: 0.92, type: 'altocumulus floccus', class: 'symbol' },
    spaceship: { conf: 0.83, type: 'lenticularis', class: 'vehicle' },
  }[shape];

  const drawingLabel = CV_DRAWINGS[shape].label;

  return (
    <div data-cv2-stage style={{
      position: 'relative',
      width: 402, height: 874,
      background: '#000',
      overflow: 'hidden',
      fontFamily: '"Geist", -apple-system, system-ui, sans-serif',
      color: theme.ink,
      borderRadius: 48,
      boxShadow: '0 40px 90px -20px rgba(0,0,0,0.35), 0 0 0 1px rgba(0,0,0,0.12)',
    }}>
      {/* ── Camera feed ───────────────────────────────────── */}
      <CVSkyPhoto mood={mood} style={{ position: 'absolute', inset: 0 }} />

      {/* subtle camera vignette */}
      <div style={{
        position: 'absolute', inset: 0,
        background: 'radial-gradient(120% 80% at 50% 35%, transparent 55%, rgba(0,0,0,0.32) 100%)',
        pointerEvents: 'none',
      }} />

      {/* Dynamic island */}
      <div style={{
        position: 'absolute', top: 11, left: '50%', transform: 'translateX(-50%)',
        width: 122, height: 35, borderRadius: 24, background: '#000', zIndex: 80,
      }} />

      {/* Status bar */}
      <div style={{
        position: 'absolute', top: 0, left: 0, right: 0,
        height: 47, display: 'flex', alignItems: 'center', justifyContent: 'space-between',
        padding: '15px 28px 0', zIndex: 60, color: statusColor,
      }}>
        <span style={{ fontWeight: 600, fontSize: 16, letterSpacing: -0.2 }}>9:41</span>
        <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
          <svg width="17" height="11" viewBox="0 0 19 12"><rect x="0" y="7.5" width="3.2" height="4.5" rx="0.7" fill={statusColor}/><rect x="4.8" y="5" width="3.2" height="7" rx="0.7" fill={statusColor}/><rect x="9.6" y="2.5" width="3.2" height="9.5" rx="0.7" fill={statusColor}/><rect x="14.4" y="0" width="3.2" height="12" rx="0.7" fill={statusColor}/></svg>
          <svg width="15" height="11" viewBox="0 0 17 12"><path d="M8.5 3.2C10.8 3.2 12.9 4.1 14.4 5.6L15.5 4.5C13.7 2.7 11.2 1.5 8.5 1.5C5.8 1.5 3.3 2.7 1.5 4.5L2.6 5.6C4.1 4.1 6.2 3.2 8.5 3.2Z" fill={statusColor}/><circle cx="8.5" cy="10.5" r="1.5" fill={statusColor}/></svg>
          <svg width="25" height="12" viewBox="0 0 27 13"><rect x="0.5" y="0.5" width="23" height="12" rx="3.5" stroke={statusColor} strokeOpacity="0.4" fill="none"/><rect x="2" y="2" width="20" height="9" rx="1.5" fill={statusColor}/></svg>
        </div>
      </div>

      {/* Top floating controls: location pill (L) + AI toggle (R) */}
      <div style={{
        position: 'absolute', top: 64, left: 16, right: 16,
        display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', zIndex: 30,
      }}>
        <CV2GlassPill onDark={onDarkSky}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 12px' }}>
            <span style={{ width: 6, height: 6, borderRadius: 3, background: '#34D399', display: 'inline-block' }} />
            <span style={{ fontSize: 13, fontWeight: 600, color: statusColor }}>New York</span>
            <span style={{ fontSize: 12, color: muted, fontFamily: '"JetBrains Mono", monospace' }}>72°</span>
          </div>
        </CV2GlassPill>

        <CV2GlassPill onDark={onDarkSky}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, padding: '8px 12px' }}>
            <div style={{ width: 14, height: 14 }}>{CVIcon.sparkle(statusColor)}</div>
            <span style={{ fontSize: 12.5, fontWeight: 600, color: statusColor, fontFamily: '"JetBrains Mono", monospace', letterSpacing: 0.4 }}>AI</span>
          </div>
        </CV2GlassPill>
      </div>

      {/* AI drawing layer on the sky — auto-draws when shape changes */}
      <div key={animKey} style={{
        position: 'absolute', top: 130, left: 32, right: 32, height: 340,
        zIndex: 10, pointerEvents: 'none',
      }}>
        <CVAIOverlay drawing={shape} aiStyle={aiStyle} theme={theme} animate />
      </div>

      {/* Caption directly under the drawing — fades out as drawer rises so
          the glass shows only sky + drawing through it. */}
      <div key={'cap-' + animKey} style={{
        position: 'absolute', top: 480, left: 0, right: 0,
        zIndex: 11, textAlign: 'center',
        pointerEvents: 'none',
        opacity: Math.max(0, 1 - drawer.pos * 5),
        transition: drawer.dragging ? 'none' : 'opacity 220ms ease',
      }}>
        <div className="cv2-cap-anim" style={{
          display: 'inline-flex', flexDirection: 'column', alignItems: 'center', gap: 8,
        }}>
          {/* Tick line connecting drawing to caption */}
          <div style={{
            width: 1, height: 16,
            background: onDarkSky ? 'rgba(255,255,255,0.5)' : 'rgba(11,18,32,0.35)',
          }} />
          <div style={{
            fontFamily: '"JetBrains Mono", monospace', fontSize: 10, letterSpacing: 2,
            textTransform: 'uppercase',
            color: onDarkSky ? 'rgba(255,255,255,0.75)' : 'rgba(11,18,32,0.6)',
            textShadow: onDarkSky ? '0 1px 2px rgba(0,0,0,0.4)' : '0 1px 2px rgba(255,255,255,0.4)',
          }}>
            I think I see
          </div>
          <div style={{
            fontFamily: '"Instrument Serif", serif', fontStyle: 'italic',
            fontSize: 30, lineHeight: 1.05, letterSpacing: -0.4,
            color: onDarkSky ? '#fff' : '#0B1220',
            textShadow: onDarkSky
              ? '0 2px 12px rgba(0,0,0,0.5), 0 1px 2px rgba(0,0,0,0.4)'
              : '0 1px 12px rgba(255,255,255,0.55), 0 1px 2px rgba(255,255,255,0.4)',
          }}>{cv2Caption(shape)}</div>
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 6,
            padding: '4px 10px', borderRadius: 999,
            background: onDarkSky ? 'rgba(20,20,30,0.5)' : 'rgba(255,255,255,0.78)',
            backdropFilter: 'blur(10px)',
            WebkitBackdropFilter: 'blur(10px)',
            border: onDarkSky ? '0.5px solid rgba(255,255,255,0.15)' : '0.5px solid rgba(255,255,255,0.6)',
            fontSize: 10.5, fontWeight: 600,
            color: onDarkSky ? '#fff' : '#0B1220',
            fontFamily: '"JetBrains Mono", monospace', letterSpacing: 0.4,
          }}>
            <span style={{ width: 5, height: 5, borderRadius: 3, background: theme.accent }} />
            CloudView AI · {Math.round(detected.conf * 100)}%
          </div>
        </div>
      </div>
      <style>{`
        @keyframes cv2-cap-in {
          0%   { transform: translateY(8px); }
          60%  { transform: translateY(8px); }
          100% { transform: translateY(0); }
        }
        .cv2-cap-anim { animation: cv2-cap-in 2.4s cubic-bezier(0.32,0.72,0.18,1) both; }
      `}</style>

      {/* ── Glass drawer ───────────────────────────────────── */}
      <CV2Drawer
        theme={theme}
        pos={drawer.pos}
        dragging={drawer.dragging}
        handleBind={drawer.handle}
        peekHeight={peekHeight}
        stageHeight={874}
      >
        <CV2DrawerContent
          theme={theme}
          quip={cv2Quip(shape, quipTone)}
          caption={cv2Caption(shape)}
          shape={shape}
          aiStyle={aiStyle}
          detected={detected}
          drawingLabel={drawingLabel}
          mood={mood}
          pos={drawer.pos}
          onPick={onChangeShape}
        />
      </CV2Drawer>

      {/* Home indicator */}
      <div style={{
        position: 'absolute', bottom: 8, left: '50%', transform: 'translateX(-50%)',
        width: 134, height: 5, borderRadius: 100,
        background: 'rgba(0,0,0,0.3)', zIndex: 90,
      }} />
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Glass pill primitive (top-floating)
// ─────────────────────────────────────────────────────────────
function CV2GlassPill({ children, onDark = false }) {
  return (
    <div style={{
      borderRadius: 999, position: 'relative', overflow: 'hidden',
      background: onDark ? 'rgba(20,20,30,0.42)' : 'rgba(255,255,255,0.65)',
      backdropFilter: 'blur(20px) saturate(160%)',
      WebkitBackdropFilter: 'blur(20px) saturate(160%)',
      boxShadow: onDark
        ? '0 4px 18px rgba(0,0,0,0.25), inset 0 1px 0 rgba(255,255,255,0.1)'
        : '0 4px 18px rgba(0,0,0,0.08), inset 0 1px 0 rgba(255,255,255,0.5)',
      border: onDark ? '0.5px solid rgba(255,255,255,0.12)' : '0.5px solid rgba(255,255,255,0.5)',
    }}>{children}</div>
  );
}

// ─────────────────────────────────────────────────────────────
// Drawer shell
// ─────────────────────────────────────────────────────────────
function CV2Drawer({ children, theme, pos, dragging, handleBind, peekHeight, stageHeight, drawerColor }) {
  const height = peekHeight + (stageHeight * 0.95 - peekHeight) * pos;
  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, bottom: 0,
      height,
      transition: dragging ? 'none' : 'height 380ms cubic-bezier(0.32,0.72,0.18,1)',
      borderTopLeftRadius: 32, borderTopRightRadius: 32,
      overflow: 'hidden',
      zIndex: 50,
      boxShadow: '0 -20px 50px -20px rgba(0,0,0,0.3)',
    }}>
      {/* Glass background — clearer/more transparent so the sky reads through */}
      <div style={{
        position: 'absolute', inset: 0,
        background: theme.dark
          ? 'rgba(20,27,39,0.42)'
          : 'rgba(255,255,255,0.42)',
        backdropFilter: 'blur(28px) saturate(160%)',
        WebkitBackdropFilter: 'blur(28px) saturate(160%)',
      }} />
      {/* Soft inner highlight gradient for depth */}
      <div style={{
        position: 'absolute', inset: 0,
        background: theme.dark
          ? 'linear-gradient(180deg, rgba(255,255,255,0.06) 0%, rgba(255,255,255,0) 30%)'
          : 'linear-gradient(180deg, rgba(255,255,255,0.45) 0%, rgba(255,255,255,0) 30%)',
        pointerEvents: 'none',
      }} />
      <div style={{
        position: 'absolute', inset: 0,
        borderTopLeftRadius: 32, borderTopRightRadius: 32,
        border: theme.dark ? '0.5px solid rgba(255,255,255,0.1)' : '0.5px solid rgba(255,255,255,0.6)',
        borderBottom: 'none',
        boxShadow: theme.dark
          ? 'inset 0 1px 0 rgba(255,255,255,0.08)'
          : 'inset 0 1px 0 rgba(255,255,255,0.9)',
        pointerEvents: 'none',
      }} />

      {/* Handle */}
      <div {...handleBind} style={{
        position: 'relative', height: 28, cursor: 'grab',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        touchAction: 'none',
      }}>
        <div style={{
          width: 44, height: 5, borderRadius: 100,
          background: theme.dark ? 'rgba(244,246,250,0.45)' : 'rgba(11,18,32,0.25)',
        }} />
      </div>

      <div className="cv2-drawer-scroll" style={{ position: 'relative', height: 'calc(100% - 28px)', overflowY: 'auto', overflowX: 'hidden' }}>
        {children}
      </div>
      <style>{`
        .cv2-drawer-scroll { scrollbar-width: none; -ms-overflow-style: none; }
        .cv2-drawer-scroll::-webkit-scrollbar { display: none; width: 0; height: 0; }
      `}</style>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Drawer content — fades through peek -> open -> full
// ─────────────────────────────────────────────────────────────
function CV2DrawerContent({ theme, quip, caption, shape, aiStyle, detected, drawingLabel, mood, pos, onPick }) {
  // The "peek" view is always visible (temp + quip teaser).
  // Expanded view fades in as pos > 0.15.
  const expandedOpacity = Math.max(0, Math.min(1, (pos - 0.05) / 0.45));
  return (
    <div style={{ position: 'relative', height: '100%', color: theme.ink }}>
      {/* ── Peek strip (always visible at top of drawer) ── */}
      <div style={{ padding: '0 22px' }}>
        {/* Row: big temp + meta on the right */}
        <div style={{ display: 'flex', alignItems: 'flex-start', justifyContent: 'space-between' }}>
          <div>
            <div style={{
              fontFamily: '"Instrument Serif", serif', fontWeight: 400,
              fontSize: 56, lineHeight: 0.92, letterSpacing: -2, color: theme.ink,
            }}>72°</div>
            <div style={{
              marginTop: 4, fontSize: 12, color: theme.inkSoft,
              fontFamily: '"JetBrains Mono", monospace', letterSpacing: 0.2,
            }}>light cumulus · NYC</div>
          </div>
          <div style={{ textAlign: 'right', paddingTop: 4 }}>
            <div style={{
              fontFamily: '"JetBrains Mono", monospace', fontSize: 10, letterSpacing: 1.4,
              textTransform: 'uppercase', color: theme.accent, fontWeight: 600,
            }}>Rain in 2h</div>
            <div style={{
              marginTop: 4, fontSize: 11, color: theme.inkMute,
              fontFamily: '"JetBrains Mono", monospace',
            }}>1pm · 0.2&quot;</div>
          </div>
        </div>

        {/* The combined witty + weather quip */}
        <div style={{
          marginTop: 14,
          borderTop: `0.5px solid ${theme.line}`,
          paddingTop: 14,
        }}>
          <div style={{
            fontFamily: '"JetBrains Mono", monospace', fontSize: 10, letterSpacing: 1.5,
            textTransform: 'uppercase', color: theme.inkMute, marginBottom: 6,
            display: 'flex', alignItems: 'center', gap: 6,
          }}>
            <div style={{ width: 11, height: 11 }}>{CVIcon.sparkle(theme.accent)}</div>
            <span>{quip.title}</span>
          </div>
          <div style={{
            fontFamily: '"Instrument Serif", serif', fontStyle: 'italic',
            fontSize: 19, lineHeight: 1.25, letterSpacing: -0.2, color: theme.ink,
            textWrap: 'pretty',
          }}>{quip.body}</div>
        </div>
      </div>

      {/* ── Expanded content (fades in) ───────────────────── */}
      <div style={{
        opacity: expandedOpacity,
        pointerEvents: expandedOpacity > 0.5 ? 'auto' : 'none',
        transition: 'opacity 200ms ease',
        padding: '22px 22px 28px',
      }}>
        {/* AI detection summary — no picture, text-only */}
        <div style={{
          background: theme.dark ? 'rgba(255,255,255,0.04)' : 'rgba(11,18,32,0.03)',
          border: `0.5px solid ${theme.line}`,
          borderRadius: 18, padding: '16px 18px',
        }}>
          <div style={{
            fontFamily: '"JetBrains Mono", monospace', fontSize: 11, letterSpacing: 1.5,
            textTransform: 'uppercase', color: theme.inkMute, marginBottom: 6,
          }}>AI detection</div>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: 10 }}>
            <div style={{
              fontFamily: '"Instrument Serif", serif', fontSize: 28, lineHeight: 1.05,
              color: theme.ink, letterSpacing: -0.5,
            }}>
              {drawingLabel}
            </div>
            <div style={{
              fontFamily: '"JetBrains Mono", monospace', fontSize: 12, fontWeight: 600,
              padding: '4px 9px', borderRadius: 999,
              background: theme.accentSoft, color: theme.accent,
            }}>{Math.round(detected.conf * 100)}% sure</div>
          </div>
          <div style={{ fontSize: 14, color: theme.inkSoft, marginTop: 4, letterSpacing: -0.1 }}>
            painted on {detected.type}
          </div>
        </div>

        {/* Weather details row */}
        <div style={{
          marginTop: 18, display: 'grid', gridTemplateColumns: '1fr 1fr 1fr 1fr', gap: 8,
        }}>
          {[
            { l: 'feels', v: '70°' },
            { l: 'wind', v: '6 SW' },
            { l: 'humid', v: '54%' },
            { l: 'UV', v: '6' },
          ].map((w, i) => (
            <div key={i} style={{
              background: theme.dark ? 'rgba(255,255,255,0.04)' : 'rgba(11,18,32,0.03)',
              border: `0.5px solid ${theme.line}`,
              borderRadius: 14, padding: '11px 12px',
            }}>
              <div style={{
                fontFamily: '"JetBrains Mono", monospace', fontSize: 10.5, letterSpacing: 1.3,
                textTransform: 'uppercase', color: theme.inkMute,
              }}>{w.l}</div>
              <div style={{
                marginTop: 6, fontFamily: '"Instrument Serif", serif',
                fontSize: 26, lineHeight: 1, color: theme.ink, letterSpacing: -0.6,
              }}>{w.v}</div>
            </div>
          ))}
        </div>

        {/* Sky details — cloud cover, visibility, dewpoint */}
        <div style={{
          marginTop: 12,
          background: theme.dark ? 'rgba(255,255,255,0.04)' : 'rgba(11,18,32,0.03)',
          border: `0.5px solid ${theme.line}`,
          borderRadius: 14, padding: '14px 16px',
        }}>
          <div style={{
            fontFamily: '"JetBrains Mono", monospace', fontSize: 10.5, letterSpacing: 1.3,
            textTransform: 'uppercase', color: theme.inkMute, marginBottom: 10,
          }}>Sky details</div>
          {[
            { l: 'Cloud cover', v: '38%', meta: 'scattered cumulus' },
            { l: 'Visibility', v: '9.8 mi', meta: 'crystalline' },
            { l: 'Dewpoint', v: '54°', meta: 'comfortable' },
          ].map((r, i) => (
            <div key={i} style={{
              display: 'flex', alignItems: 'baseline', justifyContent: 'space-between',
              padding: '8px 0',
              borderTop: i === 0 ? 'none' : `0.5px solid ${theme.lineSoft}`,
            }}>
              <span style={{ fontSize: 14.5, color: theme.ink, fontWeight: 500 }}>{r.l}</span>
              <div style={{ display: 'flex', alignItems: 'baseline', gap: 10 }}>
                <span style={{ fontSize: 13, color: theme.inkMute }}>{r.meta}</span>
                <span style={{
                  fontFamily: '"Instrument Serif", serif', fontSize: 20,
                  color: theme.ink, letterSpacing: -0.3, lineHeight: 1,
                  minWidth: 50, textAlign: 'right',
                }}>{r.v}</span>
              </div>
            </div>
          ))}
        </div>

        {/* Sunrise / sunset / golden hour timeline */}
        <CV2SunBar theme={theme} />

        {/* Hourly watchability */}
        <div style={{ marginTop: 22 }}>
          <div style={{
            display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 10,
          }}>
            <div style={{
              fontFamily: '"JetBrains Mono", monospace', fontSize: 10.5, letterSpacing: 1.3,
              textTransform: 'uppercase', color: theme.inkMute,
            }}>Watchability · next 8h</div>
            <div style={{ fontSize: 13, color: theme.inkSoft }}>
              peak <strong style={{ color: theme.ink, fontWeight: 600 }}>2pm</strong>
            </div>
          </div>
          <div style={{ display: 'flex', gap: 6, alignItems: 'flex-end' }}>
            {[0.4, 0.62, 0.95, 0.82, 0.68, 0.5, 0.36, 0.22].map((v, i) => (
              <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
                <div style={{
                  width: '100%', height: 56, borderRadius: 6,
                  background: theme.dark ? 'rgba(255,255,255,0.07)' : 'rgba(11,18,32,0.05)',
                  position: 'relative', overflow: 'hidden',
                }}>
                  <div style={{
                    position: 'absolute', bottom: 0, left: 0, right: 0,
                    height: `${v * 100}%`,
                    background: i === 2 ? theme.accent : theme.dark ? 'rgba(244,246,250,0.32)' : 'rgba(11,18,32,0.32)',
                    borderRadius: 6,
                  }} />
                </div>
                <span style={{
                  fontSize: 11, color: i === 2 ? theme.ink : theme.inkMute, fontWeight: i === 2 ? 600 : 400,
                  fontFamily: '"JetBrains Mono", monospace',
                }}>{['11', '12', '1', '2', '3', '4', '5', '6'][i]}</span>
              </div>
            ))}
          </div>
        </div>

        {/* Spotted nearby — TEXT list, not picture grid */}
        <div style={{ marginTop: 26 }}>
          <div style={{
            display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 12,
          }}>
            <div style={{
              fontFamily: '"JetBrains Mono", monospace', fontSize: 10.5, letterSpacing: 1.3,
              textTransform: 'uppercase', color: theme.inkMute,
            }}>Others nearby spotted</div>
            <div style={{ fontSize: 13, color: theme.accent, fontWeight: 600 }}>see all 247</div>
          </div>

          <div style={{
            background: theme.dark ? 'rgba(255,255,255,0.04)' : 'rgba(11,18,32,0.03)',
            border: `0.5px solid ${theme.line}`,
            borderRadius: 14, padding: '4px 16px',
          }}>
            {[
              { who: 'Mira',  where: 'Prospect Park',  saw: 'a sleeping pup',        when: '4m' },
              { who: 'Eitan', where: 'Astoria',        saw: 'a whale, drifting east', when: '11m' },
              { who: 'Sam',   where: '3 blocks west',  saw: 'a small castle',         when: '18m' },
              { who: 'Priya', where: 'Lower East Side',saw: 'a heart, briefly',       when: '24m' },
              { who: 'Lola',  where: 'Williamsburg',   saw: 'something like a turtle',when: '31m' },
            ].map((r, i, arr) => (
              <div key={i} style={{
                padding: '12px 0',
                borderTop: i === 0 ? 'none' : `0.5px solid ${theme.lineSoft}`,
                display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: 12,
              }}>
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{
                    fontFamily: '"Instrument Serif", serif', fontSize: 19, fontStyle: 'italic',
                    lineHeight: 1.2, color: theme.ink, letterSpacing: -0.2,
                  }}>
                    &ldquo;{r.saw}&rdquo;
                  </div>
                  <div style={{
                    marginTop: 4, fontSize: 12.5, color: theme.inkMute,
                    fontFamily: '"JetBrains Mono", monospace', letterSpacing: 0.2,
                  }}>
                    {r.who} · {r.where}
                  </div>
                </div>
                <div style={{
                  fontFamily: '"JetBrains Mono", monospace', fontSize: 12, color: theme.inkMute,
                  flexShrink: 0,
                }}>{r.when}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Tomorrow teaser */}
        <div style={{ marginTop: 22 }}>
          <div style={{
            fontFamily: '"JetBrains Mono", monospace', fontSize: 10.5, letterSpacing: 1.3,
            textTransform: 'uppercase', color: theme.inkMute, marginBottom: 10,
          }}>The week ahead</div>
          <div style={{
            background: theme.dark ? 'rgba(255,255,255,0.04)' : 'rgba(11,18,32,0.03)',
            border: `0.5px solid ${theme.line}`,
            borderRadius: 14, padding: '12px 16px',
          }}>
            {[
              { d: 'Tomorrow', sky: 'overcast all day', best: '\u2014',       hi: 68 },
              { d: 'Friday',   sky: 'lively cumulus',   best: '11a \u2013 2p', hi: 74 },
              { d: 'Saturday', sky: 'golden, breezy',   best: '5p \u2013 7p',  hi: 71 },
            ].map((r, i) => (
              <div key={i} style={{
                padding: '10px 0',
                borderTop: i === 0 ? 'none' : `0.5px solid ${theme.lineSoft}`,
                display: 'grid', gridTemplateColumns: '88px 1fr 64px 40px', alignItems: 'baseline', gap: 8,
              }}>
                <span style={{ fontSize: 14, fontWeight: 600, color: theme.ink }}>{r.d}</span>
                <span style={{ fontSize: 13.5, color: theme.inkSoft }}>{r.sky}</span>
                <span style={{
                  fontFamily: '"JetBrains Mono", monospace', fontSize: 12, color: theme.accent, fontWeight: 600,
                  textAlign: 'right',
                }}>{r.best}</span>
                <span style={{
                  fontFamily: '"Instrument Serif", serif', fontSize: 19, color: theme.ink, letterSpacing: -0.3,
                  textAlign: 'right',
                }}>{r.hi}°</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Sunrise / sunset bar — daylight progress + golden hour markers
// ─────────────────────────────────────────────────────────────
function CV2SunBar({ theme }) {
  // Mock: sunrise 5:46a, sunset 8:14p, now is 9:41a.
  const total = 14 * 60 + 28; // minutes of daylight
  const elapsed = (9 * 60 + 41) - (5 * 60 + 46);
  const progress = elapsed / total;
  // Golden-hour windows: first hour after sunrise, last hour before sunset.
  const goldenAm = 60 / total;
  const goldenPmStart = (total - 60) / total;
  return (
    <div style={{ marginTop: 14 }}>
      <div style={{
        display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 10,
      }}>
        <div style={{
          fontFamily: '"JetBrains Mono", monospace', fontSize: 10.5, letterSpacing: 1.3,
          textTransform: 'uppercase', color: theme.inkMute,
        }}>Light today</div>
        <div style={{ fontSize: 13, color: theme.inkSoft }}>
          golden hour at <strong style={{ color: theme.ink, fontWeight: 600 }}>7:14p</strong>
        </div>
      </div>
      <div style={{
        background: theme.dark ? 'rgba(255,255,255,0.04)' : 'rgba(11,18,32,0.03)',
        border: `0.5px solid ${theme.line}`,
        borderRadius: 14, padding: '16px 18px',
      }}>
        {/* Bar */}
        <div style={{ position: 'relative', height: 8, borderRadius: 4, background: theme.dark ? 'rgba(255,255,255,0.07)' : 'rgba(11,18,32,0.06)' }}>
          {/* Golden hour AM */}
          <div style={{
            position: 'absolute', left: 0, top: 0, bottom: 0, width: `${goldenAm * 100}%`,
            background: 'linear-gradient(90deg, oklch(0.82 0.12 60), oklch(0.86 0.06 80))',
            borderRadius: 4,
          }} />
          {/* Golden hour PM */}
          <div style={{
            position: 'absolute', left: `${goldenPmStart * 100}%`, right: 0, top: 0, bottom: 0,
            background: 'linear-gradient(90deg, oklch(0.86 0.06 80), oklch(0.72 0.14 40))',
            borderRadius: 4,
          }} />
          {/* Current sun */}
          <div style={{
            position: 'absolute', left: `${progress * 100}%`, top: '50%',
            transform: 'translate(-50%, -50%)',
            width: 18, height: 18, borderRadius: 9,
            background: '#fff',
            border: `2px solid ${theme.ink}`,
            boxShadow: `0 0 0 4px ${theme.bg}`,
          }} />
        </div>
        {/* Labels */}
        <div style={{
          marginTop: 12, display: 'flex', alignItems: 'baseline', justifyContent: 'space-between',
        }}>
          <div>
            <div style={{
              fontFamily: '"JetBrains Mono", monospace', fontSize: 10, letterSpacing: 1.3,
              textTransform: 'uppercase', color: theme.inkMute,
            }}>Sunrise</div>
            <div style={{ fontFamily: '"Instrument Serif", serif', fontSize: 18, color: theme.ink, letterSpacing: -0.3, marginTop: 2 }}>5:46a</div>
          </div>
          <div style={{ textAlign: 'center' }}>
            <div style={{
              fontFamily: '"JetBrains Mono", monospace', fontSize: 10, letterSpacing: 1.3,
              textTransform: 'uppercase', color: theme.inkMute,
            }}>Daylight left</div>
            <div style={{ fontFamily: '"Instrument Serif", serif', fontSize: 18, color: theme.ink, letterSpacing: -0.3, marginTop: 2 }}>10h 33m</div>
          </div>
          <div style={{ textAlign: 'right' }}>
            <div style={{
              fontFamily: '"JetBrains Mono", monospace', fontSize: 10, letterSpacing: 1.3,
              textTransform: 'uppercase', color: theme.inkMute,
            }}>Sunset</div>
            <div style={{ fontFamily: '"Instrument Serif", serif', fontSize: 18, color: theme.ink, letterSpacing: -0.3, marginTop: 2 }}>8:14p</div>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// App shell — single centered phone in a soft canvas
// ─────────────────────────────────────────────────────────────
function CV2App() {
  const [t, setTweak] = useTweaks(CV2_DEFAULTS);
  const theme = CV_THEMES[t.theme] || CV_THEMES.airy;
  const aiStyle = t.aiStyle || 'thin';
  const quipTone = t.quipTone || 'witty';
  const mood = t.mood || 'day';
  const shape = t.shape || 'dragon';

  // Stage canvas color depends on theme
  const canvasBg = theme.dark ? '#0A0E15' : '#E8E5DE';
  const canvasInk = theme.dark ? 'rgba(244,246,250,0.7)' : 'rgba(40,30,20,0.7)';

  return (
    <>
      <div style={{
        minHeight: '100vh', width: '100vw',
        background: canvasBg,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        position: 'relative', overflow: 'hidden',
      }}>
        {/* corner labels */}
        <div style={{
          position: 'absolute', top: 32, left: 40,
          fontFamily: '"JetBrains Mono", monospace', fontSize: 11, letterSpacing: 2,
          textTransform: 'uppercase', color: canvasInk,
        }}>
          CloudView · v2 · single hero
        </div>
        <div style={{
          position: 'absolute', top: 32, right: 40, textAlign: 'right',
          fontFamily: '"JetBrains Mono", monospace', fontSize: 11, letterSpacing: 2,
          textTransform: 'uppercase', color: canvasInk,
        }}>
          drag the handle · swipe up ↑
        </div>

        <div style={{
          position: 'absolute', bottom: 32, left: 40, maxWidth: 380,
          color: canvasInk,
        }}>
          <div style={{
            fontFamily: '"Instrument Serif", serif', fontSize: 28, lineHeight: 1.05,
            color: theme.dark ? '#F4F6FA' : '#1A1612', letterSpacing: -0.4,
            textWrap: 'pretty',
          }}>
            The whole app is one screen: <span style={{ fontStyle: 'italic' }}>the sky.</span>
          </div>
          <div style={{ marginTop: 10, fontSize: 13.5, lineHeight: 1.5 }}>
            A live camera feed with an AI tracing what it sees in the clouds.
            Pull the glass drawer up for weather + a quip about what you&rsquo;re looking at.
          </div>
        </div>

        <div style={{
          position: 'absolute', bottom: 32, right: 40, textAlign: 'right',
          fontFamily: '"JetBrains Mono", monospace', fontSize: 11, letterSpacing: 2,
          textTransform: 'uppercase', color: canvasInk,
        }}>
          tap a thumbnail to swap shapes →
        </div>

        {/* The phone */}
        <CV2Hero
          theme={theme}
          aiStyle={aiStyle}
          quipTone={quipTone}
          mood={mood}
          shape={shape}
          drawerInitial={t.drawerState}
          onChangeShape={(s) => setTweak('shape', s)}
          onChangeMood={(m) => setTweak('mood', m)}
        />
      </div>

      {/* Tweaks */}
      <TweaksPanel title="CloudView · Tweaks">
        <TweakSection label="Aesthetic" />
        <TweakRadio
          label="Theme"
          value={t.theme}
          onChange={(v) => setTweak('theme', v)}
          options={[
            { value: 'airy', label: 'Airy' },
            { value: 'editorial', label: 'Editorial' },
            { value: 'dusk', label: 'Dusk' },
            { value: 'dreamy', label: 'Dreamy' },
          ]}
        />
        <TweakRadio
          label="Sky mood"
          value={t.mood}
          onChange={(v) => setTweak('mood', v)}
          options={[
            { value: 'day', label: 'Day' },
            { value: 'golden', label: 'Golden' },
            { value: 'dusk', label: 'Dusk' },
            { value: 'dawn', label: 'Dawn' },
            { value: 'stormy', label: 'Stormy' },
          ]}
        />
        <TweakSection label="AI overlay" />
        <TweakRadio
          label="Drawing"
          value={t.aiStyle}
          onChange={(v) => setTweak('aiStyle', v)}
          options={[
            { value: 'thin', label: 'Thin sketch' },
            { value: 'bold', label: 'Bold outline' },
            { value: 'dotted', label: 'Constellation' },
            { value: 'marker', label: 'Marker' },
          ]}
        />
        <TweakRadio
          label="Shape"
          value={t.shape}
          onChange={(v) => setTweak('shape', v)}
          options={[
            { value: 'dragon', label: 'Dragon' },
            { value: 'whale', label: 'Whale' },
            { value: 'dog', label: 'Dog' },
            { value: 'castle', label: 'Castle' },
            { value: 'heart', label: 'Heart' },
            { value: 'spaceship', label: 'UFO' },
          ]}
        />
        <TweakSection label="Voice" />
        <TweakRadio
          label="Quip tone"
          value={t.quipTone}
          onChange={(v) => setTweak('quipTone', v)}
          options={[
            { value: 'witty', label: 'Witty' },
            { value: 'whimsical', label: 'Whimsical' },
            { value: 'punny', label: 'Punny' },
          ]}
        />
      </TweaksPanel>
    </>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<CV2App />);
