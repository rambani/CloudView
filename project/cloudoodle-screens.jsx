// Cloudoodle — screens. Each screen is a self-contained React component
// that receives { theme, aiStyle, quipTone } and renders inside a CVPhone.

// ─────────────────────────────────────────────────────────────
// Quips by tone
// ─────────────────────────────────────────────────────────────
const CV_QUIPS = {
  witty: {
    dragon: 'A dragon procrastinating its first appointment of the day.',
    whale: 'A whale that took a wrong turn at Saturn.',
    dog: 'Pug arguing with its accountant. Cumulus class.',
    castle: 'A castle commissioned by a slightly anxious king.',
    heart: 'Romance, but suspiciously well-funded.',
    spaceship: 'Visitor refuses to parallel-park. Again.',
  },
  whimsical: {
    dragon: 'A small dragon, learning the names of things below.',
    whale: 'A whale ferrying songs from one breeze to the next.',
    dog: 'Someone’s lost dog, asleep on a pillow of weather.',
    castle: 'A castle built only on Tuesdays.',
    heart: 'A heart, briefly, then a swan, then nothing.',
    spaceship: 'A traveler asking the wind for directions.',
  },
  punny: {
    dragon: 'High-altitude dragon. Strictly mist-ical.',
    whale: 'Whale, whale, whale — what do we have here?',
    dog: 'Bark-a-cumulus.',
    castle: 'Castle in the air. Literally this time.',
    heart: 'Atmos-fond of you.',
    spaceship: 'UFO — Unidentified Floating Object.',
  },
};

function cvQuip(drawing, tone) {
  const t = CV_QUIPS[tone] || CV_QUIPS.witty;
  return t[drawing] || t.dragon;
}

// ─────────────────────────────────────────────────────────────
// 1 · Onboarding — welcome
// ─────────────────────────────────────────────────────────────
function CVScreenWelcome({ theme }) {
  return (
    <CVPhone theme={theme}>
      <CVSkyPhoto mood="dawn" style={{ position: 'absolute', inset: 0, height: '100%' }} />
      <div style={{
        position: 'absolute', inset: 0, padding: '120px 32px 60px',
        display: 'flex', flexDirection: 'column', justifyContent: 'space-between',
        color: '#1A1612',
      }}>
        <div>
          <div style={{
            fontFamily: '"JetBrains Mono", monospace', fontSize: 11, letterSpacing: 2,
            textTransform: 'uppercase', opacity: 0.7, marginBottom: 24,
          }}>Cloudoodle · v1.0</div>
          <h1 style={{
            fontFamily: '"Instrument Serif", serif', fontWeight: 400,
            fontSize: 56, lineHeight: 1.02, letterSpacing: -1.2, margin: 0,
            textWrap: 'pretty',
          }}>
            Look up.<br/>
            <span style={{ fontStyle: 'italic', opacity: 0.7 }}>What do you see?</span>
          </h1>
          <p style={{
            marginTop: 22, fontSize: 17, lineHeight: 1.42, color: 'rgba(26,22,18,0.7)',
            maxWidth: 280, textWrap: 'pretty',
          }}>
            A pocket field guide for the imagination. Scan the sky and we&rsquo;ll find what&rsquo;s hiding in the clouds.
          </p>
        </div>

        <div>
          <button style={{
            width: '100%', height: 56, borderRadius: 28, border: 'none',
            background: '#1A1612', color: '#FBF8F1', fontSize: 17, fontWeight: 600,
            letterSpacing: -0.2, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
            fontFamily: 'inherit',
          }}>
            Start watching
            <div style={{ width: 18, height: 18 }}>{CVIcon.arrow('#FBF8F1')}</div>
          </button>
          <div style={{
            marginTop: 16, fontSize: 13, textAlign: 'center', color: 'rgba(26,22,18,0.55)',
          }}>I already have an account</div>
        </div>
      </div>
    </CVPhone>
  );
}

// ─────────────────────────────────────────────────────────────
// 2 · Onboarding — permissions
// ─────────────────────────────────────────────────────────────
function CVScreenPermissions({ theme }) {
  const rows = [
    { icon: CVIcon.camera, title: 'Camera', sub: 'To scan the sky above you', state: 'granted' },
    { icon: CVIcon.map, title: 'Location', sub: 'To aggregate finds by city', state: 'granted' },
    { icon: CVIcon.bell, title: 'Notifications', sub: '“Sky&rsquo;s playful today — step outside&rdquo;', state: 'pending' },
  ];
  return (
    <CVPhone theme={theme}>
      <div style={{ padding: '32px 28px 0' }}>
        <div style={{
          fontFamily: '"JetBrains Mono", monospace', fontSize: 11, letterSpacing: 2,
          textTransform: 'uppercase', color: theme.inkMute, marginBottom: 16,
        }}>02 / 03 · Setup</div>
        <h2 style={{
          fontFamily: '"Instrument Serif", serif', fontWeight: 400,
          fontSize: 38, lineHeight: 1.05, letterSpacing: -0.6, margin: 0, color: theme.ink,
        }}>
          A few <span style={{ fontStyle: 'italic' }}>small</span> permissions.
        </h2>
        <p style={{
          marginTop: 12, fontSize: 15, lineHeight: 1.45, color: theme.inkSoft, maxWidth: 280,
        }}>We only use these to make the app useful. Photos stay on your device unless you share.</p>

        <div style={{ marginTop: 32, display: 'flex', flexDirection: 'column', gap: 10 }}>
          {rows.map((r, i) => (
            <div key={i} style={{
              background: theme.surface, borderRadius: 20, padding: '16px 18px',
              display: 'flex', alignItems: 'center', gap: 14,
              border: `0.5px solid ${theme.line}`,
            }}>
              <div style={{
                width: 40, height: 40, borderRadius: 12,
                background: theme.chipBg, display: 'flex', alignItems: 'center', justifyContent: 'center',
                flexShrink: 0,
              }}>
                <div style={{ width: 22, height: 22 }}>{r.icon(theme.ink)}</div>
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 15.5, fontWeight: 600, color: theme.ink }}>{r.title}</div>
                <div style={{ fontSize: 12.5, color: theme.inkSoft, marginTop: 1 }}>{r.sub}</div>
              </div>
              {r.state === 'granted' ? (
                <div style={{
                  width: 26, height: 26, borderRadius: 13, background: theme.ink, color: theme.bg,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                }}>
                  <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
                    <path d="M3 7l3 3 5-5" stroke={theme.bg} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
                  </svg>
                </div>
              ) : (
                <button style={{
                  height: 30, padding: '0 14px', borderRadius: 15, border: 'none',
                  background: theme.accent, color: theme.surface, fontSize: 13, fontWeight: 600,
                  fontFamily: 'inherit',
                }}>Enable</button>
              )}
            </div>
          ))}
        </div>
      </div>

      <div style={{
        position: 'absolute', bottom: 36, left: 28, right: 28,
      }}>
        <button style={{
          width: '100%', height: 54, borderRadius: 27, border: 'none',
          background: theme.ink, color: theme.bg, fontSize: 16, fontWeight: 600, fontFamily: 'inherit',
        }}>Continue</button>
      </div>
    </CVPhone>
  );
}

// ─────────────────────────────────────────────────────────────
// 3 · Home / Today
// ─────────────────────────────────────────────────────────────
function CVScreenHome({ theme, aiStyle, quipTone }) {
  return (
    <CVPhone theme={theme}>
      {/* Hero photo strip */}
      <div style={{ position: 'absolute', top: 0, left: 0, right: 0, height: 360 }}>
        <CVSkyPhoto mood="day" style={{ position: 'absolute', inset: 0 }} />
        {/* Top scrim */}
        <div style={{
          position: 'absolute', inset: 0,
          background: 'linear-gradient(180deg, rgba(0,0,0,0.2) 0%, rgba(0,0,0,0) 30%, rgba(246,247,249,0) 70%, ' + theme.bg + ' 100%)',
        }} />
        {/* Overlay copy */}
        <div style={{ position: 'absolute', top: 64, left: 24, right: 24, color: '#fff' }}>
          <div style={{
            fontFamily: '"JetBrains Mono", monospace', fontSize: 11, letterSpacing: 2,
            textTransform: 'uppercase', opacity: 0.85,
          }}>New York · Wed 11:24</div>
          <div style={{
            marginTop: 6, fontFamily: '"Instrument Serif", serif', fontWeight: 400,
            fontSize: 40, lineHeight: 1.05, letterSpacing: -0.6,
          }}>
            Skies are <span style={{ fontStyle: 'italic' }}>uncommonly</span><br/>playful today.
          </div>
        </div>

        {/* Temp + condition pill */}
        <div style={{ position: 'absolute', top: 64, right: 24, display: 'flex', flexDirection: 'column', gap: 6, alignItems: 'flex-end' }}>
          <div style={{ color: '#fff', fontSize: 14, fontFamily: '"JetBrains Mono", monospace' }}>72° · light cumulus</div>
        </div>
      </div>

      {/* Scrollable content */}
      <div style={{ position: 'absolute', top: 280, left: 0, right: 0, bottom: 0, paddingBottom: 100, overflow: 'hidden' }}>
        {/* "What we're seeing" card */}
        <div style={{ padding: '12px 16px 0' }}>
          <div style={{
            background: theme.surface, borderRadius: 24, padding: 18,
            border: `0.5px solid ${theme.line}`,
            boxShadow: `0 1px 0 ${theme.lineSoft}, 0 24px 60px -30px rgba(11,18,32,0.18)`,
          }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <div style={{
                fontFamily: '"JetBrains Mono", monospace', fontSize: 10, letterSpacing: 1.5,
                textTransform: 'uppercase', color: theme.inkMute,
              }}>What the city is seeing</div>
              <CVChip theme={theme} tone="accent">
                <span style={{ width: 6, height: 6, borderRadius: 3, background: theme.accent, display: 'inline-block' }} />
                live
              </CVChip>
            </div>

            <div style={{ marginTop: 14, display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
              {[
                { d: 'dragon', n: 38 },
                { d: 'dog', n: 22 },
                { d: 'whale', n: 16 },
              ].map((item, i) => (
                <div key={i} style={{
                  position: 'relative', aspectRatio: '1 / 1.1', borderRadius: 14, overflow: 'hidden',
                  background: theme.chipBg,
                }}>
                  <CVSkyPhoto mood="day" style={{ position: 'absolute', inset: 0 }} />
                  <CVAIOverlay drawing={item.d} aiStyle={aiStyle} theme={theme} />
                  <div style={{
                    position: 'absolute', left: 8, bottom: 8, right: 8,
                    color: '#fff', fontSize: 11, fontWeight: 500,
                    textShadow: '0 1px 4px rgba(0,0,0,0.4)',
                  }}>
                    {CV_DRAWINGS[item.d].label}
                    <div style={{ fontFamily: '"JetBrains Mono", monospace', fontSize: 9, opacity: 0.85 }}>× {item.n}</div>
                  </div>
                </div>
              ))}
            </div>

            <div style={{
              marginTop: 14, fontSize: 13, color: theme.inkSoft, lineHeight: 1.4,
              borderTop: `0.5px solid ${theme.lineSoft}`, paddingTop: 12,
            }}>
              <span style={{ color: theme.ink, fontWeight: 600 }}>247 scans</span> from <span style={{ color: theme.ink, fontWeight: 600 }}>89 watchers</span> in the last hour.
            </div>
          </div>
        </div>

        {/* Forecast strip */}
        <div style={{ padding: '20px 16px 0' }}>
          <div style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10,
          }}>
            <div style={{
              fontFamily: '"JetBrains Mono", monospace', fontSize: 10, letterSpacing: 1.5,
              textTransform: 'uppercase', color: theme.inkMute,
            }}>Watchability hours</div>
            <span style={{ fontSize: 12, color: theme.inkSoft }}>next 12h</span>
          </div>
          <div style={{ display: 'flex', gap: 6 }}>
            {[
              { h: '12p', v: 0.6 }, { h: '1', v: 0.85 }, { h: '2', v: 0.95 },
              { h: '3', v: 0.78 }, { h: '4', v: 0.65 }, { h: '5', v: 0.5 },
              { h: '6', v: 0.32 }, { h: '7', v: 0.18 }, { h: '8', v: 0.1 },
            ].map((b, i) => (
              <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6 }}>
                <div style={{
                  height: 64, width: '100%', borderRadius: 6,
                  background: theme.chipBg, position: 'relative', overflow: 'hidden',
                }}>
                  <div style={{
                    position: 'absolute', bottom: 0, left: 0, right: 0,
                    height: `${b.v * 100}%`,
                    background: i === 2
                      ? theme.accent
                      : theme.dark ? 'rgba(244,246,250,0.22)' : 'rgba(11,18,32,0.25)',
                  }} />
                </div>
                <span style={{ fontSize: 10, color: theme.inkMute, fontFamily: '"JetBrains Mono", monospace' }}>{b.h}</span>
              </div>
            ))}
          </div>
        </div>
      </div>

      <CVTabBar theme={theme} active="home" />
    </CVPhone>
  );
}

// ─────────────────────────────────────────────────────────────
// 4 · Capture viewfinder
// ─────────────────────────────────────────────────────────────
function CVScreenCapture({ theme }) {
  return (
    <CVPhone theme={{ ...theme, bg: '#000' }}>
      <CVSkyPhoto mood="day" style={{ position: 'absolute', inset: 0 }} />
      {/* Vignette */}
      <div style={{
        position: 'absolute', inset: 0,
        background: 'radial-gradient(120% 80% at 50% 40%, transparent 50%, rgba(0,0,0,0.45) 100%)',
      }} />

      {/* Reticle / framing guide */}
      <svg viewBox="0 0 100 100" preserveAspectRatio="none"
        style={{ position: 'absolute', inset: '16% 12% 24%', width: 'auto', height: 'auto' }}>
        {/* Corner brackets */}
        {[[0,0,'M0 12 V0 H12'], [100,0,'M88 0 H100 V12'], [0,100,'M0 88 V100 H12'], [100,100,'M88 100 H100 V88']].map((p, i) => (
          <path key={i} d={p[2]} fill="none" stroke="#fff" strokeWidth="0.6" />
        ))}
      </svg>

      {/* Reticle label */}
      <div style={{
        position: 'absolute', top: 90, left: 0, right: 0, textAlign: 'center',
        color: '#fff', fontFamily: '"JetBrains Mono", monospace',
        fontSize: 11, letterSpacing: 2, textTransform: 'uppercase', opacity: 0.95,
      }}>
        ○  Frame the clouds you see
      </div>

      {/* Top controls */}
      <div style={{
        position: 'absolute', top: 64, left: 24, right: 24,
        display: 'flex', justifyContent: 'space-between', alignItems: 'center',
      }}>
        <div style={{
          width: 40, height: 40, borderRadius: 20,
          background: 'rgba(255,255,255,0.15)', backdropFilter: 'blur(10px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <div style={{ width: 18, height: 18 }}>{CVIcon.flash('#fff')}</div>
        </div>
        <div style={{
          padding: '8px 14px', borderRadius: 20,
          background: 'rgba(255,255,255,0.15)', backdropFilter: 'blur(10px)',
          color: '#fff', fontSize: 13, fontWeight: 500,
        }}>HDR · Auto</div>
        <div style={{
          width: 40, height: 40, borderRadius: 20,
          background: 'rgba(255,255,255,0.15)', backdropFilter: 'blur(10px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <div style={{ width: 18, height: 18 }}>{CVIcon.swap('#fff')}</div>
        </div>
      </div>

      {/* Bottom capture controls */}
      <div style={{
        position: 'absolute', bottom: 80, left: 0, right: 0,
        display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 60,
      }}>
        {/* gallery thumb */}
        <div style={{
          width: 44, height: 44, borderRadius: 10, overflow: 'hidden',
          border: '1.5px solid rgba(255,255,255,0.5)',
        }}>
          <CVSkyPhoto mood="golden" style={{ width: '100%', height: '100%' }} />
        </div>
        {/* shutter */}
        <div style={{
          width: 76, height: 76, borderRadius: 38,
          border: '3px solid #fff',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <div style={{ width: 60, height: 60, borderRadius: 30, background: '#fff' }} />
        </div>
        {/* AI toggle */}
        <div style={{
          width: 44, height: 44, borderRadius: 22, background: 'rgba(255,255,255,0.18)',
          backdropFilter: 'blur(10px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          border: `1.5px solid ${theme.accent}`,
        }}>
          <div style={{ width: 22, height: 22 }}>{CVIcon.sparkle('#fff')}</div>
        </div>
      </div>

      {/* Mode tabs */}
      <div style={{
        position: 'absolute', bottom: 36, left: 0, right: 0,
        display: 'flex', justifyContent: 'center', gap: 24,
        color: 'rgba(255,255,255,0.55)', fontSize: 13, fontWeight: 500,
        letterSpacing: 0.4, textTransform: 'uppercase',
        fontFamily: '"JetBrains Mono", monospace',
      }}>
        <span>Manual</span>
        <span style={{ color: '#fff' }}>Scan •</span>
        <span>Timelapse</span>
      </div>
    </CVPhone>
  );
}

// ─────────────────────────────────────────────────────────────
// 5 · Scanning (HERO animation)
// Auto-loops the scan animation every ~3.5s for the demo.
// ─────────────────────────────────────────────────────────────
function CVScreenScanning({ theme, aiStyle, quipTone }) {
  return (
    <CVPhone theme={{ ...theme, bg: '#000' }}>
      <CVSkyPhoto mood="day" style={{ position: 'absolute', inset: 0 }} />
      {/* Darken */}
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.18)' }} />

      {/* Scan line — animated */}
      <div className="cv-scan-line" style={{
        position: 'absolute', left: 0, right: 0, height: 2,
        background: `linear-gradient(90deg, transparent, ${theme.accent}, transparent)`,
        boxShadow: `0 0 24px ${theme.accent}`,
        top: '20%',
      }} />

      {/* Grid mesh of detection points */}
      <svg viewBox="0 0 100 100" preserveAspectRatio="none"
        style={{ position: 'absolute', inset: 0, opacity: 0.5 }}>
        <defs>
          <pattern id="cv-mesh" x="0" y="0" width="8" height="8" patternUnits="userSpaceOnUse">
            <circle cx="4" cy="4" r="0.3" fill="#fff" opacity="0.5" />
          </pattern>
        </defs>
        <rect width="100" height="100" fill="url(#cv-mesh)" />
      </svg>

      {/* Detected bounding box */}
      <div className="cv-bbox" style={{
        position: 'absolute', top: '24%', left: '14%', width: '64%', height: '36%',
      }}>
        <svg viewBox="0 0 100 100" preserveAspectRatio="none" style={{ width: '100%', height: '100%', display: 'block' }}>
          {[[0,0,'M0 18 V0 H18'], [100,0,'M82 0 H100 V18'], [0,100,'M0 82 V100 H18'], [100,100,'M82 100 H100 V82']].map((p, i) => (
            <path key={i} d={p[2]} fill="none" stroke={theme.accent} strokeWidth="1.2" />
          ))}
        </svg>
        <div style={{
          position: 'absolute', top: -22, left: 0,
          fontFamily: '"JetBrains Mono", monospace', fontSize: 10,
          color: theme.accent, letterSpacing: 1, textTransform: 'uppercase',
        }}>cumulus cluster · 0.94</div>
      </div>

      {/* AI drawing being drawn — animated stroke */}
      <div style={{ position: 'absolute', top: '24%', left: '14%', width: '64%', height: '36%' }}>
        <CVAIOverlay drawing="dragon" aiStyle={aiStyle} theme={theme} animate />
      </div>

      {/* Status pill bottom */}
      <div style={{
        position: 'absolute', bottom: 110, left: 24, right: 24,
        background: 'rgba(0,0,0,0.55)', backdropFilter: 'blur(20px)',
        borderRadius: 18, padding: '14px 18px',
        border: '0.5px solid rgba(255,255,255,0.15)',
        color: '#fff',
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 6 }}>
          <div style={{ width: 16, height: 16 }}>{CVIcon.sparkle(theme.accent)}</div>
          <div style={{
            fontFamily: '"JetBrains Mono", monospace', fontSize: 10.5, letterSpacing: 2,
            textTransform: 'uppercase', opacity: 0.85,
          }}>analyzing the sky</div>
        </div>
        <div style={{ fontSize: 15, lineHeight: 1.35 }}>
          Found 3 shapes. Drawing the most convincing one&hellip;
        </div>
        {/* progress */}
        <div style={{
          marginTop: 12, height: 3, borderRadius: 2,
          background: 'rgba(255,255,255,0.12)', overflow: 'hidden',
        }}>
          <div className="cv-progress" style={{
            height: '100%', width: '64%', background: theme.accent, borderRadius: 2,
          }} />
        </div>
      </div>

      {/* Cancel pill */}
      <div style={{
        position: 'absolute', bottom: 36, left: 0, right: 0,
        display: 'flex', justifyContent: 'center',
      }}>
        <div style={{
          padding: '12px 22px', borderRadius: 24,
          background: 'rgba(255,255,255,0.14)', backdropFilter: 'blur(20px)',
          color: '#fff', fontSize: 14, fontWeight: 500,
        }}>Cancel</div>
      </div>

      <style>{`
        @keyframes cv-scan-move {
          0%   { top: 18%; opacity: 0; }
          12%  { opacity: 1; }
          80%  { top: 78%; opacity: 1; }
          100% { top: 78%; opacity: 0; }
        }
        .cv-scan-line { animation: cv-scan-move 3.2s cubic-bezier(0.4,0,0.2,1) infinite; }
        @keyframes cv-bbox-fade {
          0%, 30% { opacity: 0; transform: scale(0.94); }
          50%, 100% { opacity: 1; transform: scale(1); }
        }
        .cv-bbox { animation: cv-bbox-fade 3.2s ease infinite; }
        @keyframes cv-draw {
          to { stroke-dashoffset: 0; }
        }
        @keyframes cv-prog {
          0% { width: 0%; }
          100% { width: 100%; }
        }
        .cv-progress { animation: cv-prog 3.2s linear infinite; }
      `}</style>
    </CVPhone>
  );
}

// ─────────────────────────────────────────────────────────────
// 6 · Result — photo + AI overlay + quip
// ─────────────────────────────────────────────────────────────
function CVScreenResult({ theme, aiStyle, quipTone, drawing = 'dragon' }) {
  return (
    <CVPhone theme={theme}>
      {/* Hero photo block */}
      <div style={{ position: 'absolute', top: 47, left: 16, right: 16, height: 460, borderRadius: 28, overflow: 'hidden' }}>
        <CVSkyPhoto mood="day" style={{ position: 'absolute', inset: 0 }} />
        <CVAIOverlay drawing={drawing} aiStyle={aiStyle} theme={theme} />
        {/* Top scrim for chips */}
        <div style={{
          position: 'absolute', top: 0, left: 0, right: 0, height: 80,
          background: 'linear-gradient(180deg, rgba(0,0,0,0.35) 0%, rgba(0,0,0,0) 100%)',
        }} />
        {/* Top chips */}
        <div style={{
          position: 'absolute', top: 16, left: 16, right: 16,
          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        }}>
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 6,
            padding: '6px 12px', borderRadius: 999,
            background: 'rgba(255,255,255,0.92)', color: '#0B1220',
            fontSize: 12, fontWeight: 500,
          }}>
            <div style={{ width: 12, height: 12 }}>{CVIcon.sparkle('#0B1220')}</div>
            Cloudoodle AI
          </div>
          <div style={{
            padding: '6px 12px', borderRadius: 999,
            background: 'rgba(0,0,0,0.35)', backdropFilter: 'blur(12px)',
            color: '#fff', fontSize: 12, fontWeight: 500,
            fontFamily: '"JetBrains Mono", monospace',
          }}>11:24 · NYC</div>
        </div>

        {/* Bottom overlay caption — "what we see" */}
        <div style={{
          position: 'absolute', bottom: 16, left: 16, right: 16,
        }}>
          <div style={{
            background: 'rgba(0,0,0,0.42)', backdropFilter: 'blur(20px)',
            border: '0.5px solid rgba(255,255,255,0.15)',
            borderRadius: 18, padding: '14px 16px', color: '#fff',
          }}>
            <div style={{
              fontFamily: '"JetBrains Mono", monospace', fontSize: 10, letterSpacing: 1.6,
              textTransform: 'uppercase', opacity: 0.7, marginBottom: 4,
            }}>I see &hellip;</div>
            <div style={{
              fontFamily: '"Instrument Serif", serif', fontSize: 24, lineHeight: 1.15, letterSpacing: -0.3,
              textWrap: 'pretty',
            }}>
              <span style={{ fontStyle: 'italic' }}>{cvQuip(drawing, quipTone)}</span>
            </div>
          </div>
        </div>
      </div>

      {/* Lower controls */}
      <div style={{ position: 'absolute', bottom: 32, left: 16, right: 16 }}>
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          marginBottom: 14,
        }}>
          <div>
            <div style={{
              fontFamily: '"JetBrains Mono", monospace', fontSize: 10, letterSpacing: 1.5,
              textTransform: 'uppercase', color: theme.inkMute,
            }}>Tagged as</div>
            <div style={{ marginTop: 4, display: 'flex', gap: 6 }}>
              <CVChip theme={theme} tone="accent">{CV_DRAWINGS[drawing].label}</CVChip>
              <CVChip theme={theme}>cumulus</CVChip>
              <CVChip theme={theme}>11:24</CVChip>
            </div>
          </div>
          <div style={{
            width: 44, height: 44, borderRadius: 22, background: theme.surface,
            border: `0.5px solid ${theme.line}`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <div style={{ width: 22, height: 22 }}>{CVIcon.heart(theme.ink)}</div>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          <button style={{
            flex: 1, height: 52, borderRadius: 26, border: `0.5px solid ${theme.line}`,
            background: theme.surface, color: theme.ink, fontSize: 15, fontWeight: 600,
            fontFamily: 'inherit',
          }}>Try again</button>
          <button style={{
            flex: 2, height: 52, borderRadius: 26, border: 'none',
            background: theme.ink, color: theme.bg, fontSize: 15, fontWeight: 600,
            fontFamily: 'inherit',
          }}>Share with the city</button>
        </div>
      </div>
    </CVPhone>
  );
}

// ─────────────────────────────────────────────────────────────
// 7 · City feed
// ─────────────────────────────────────────────────────────────
function CVScreenFeed({ theme, aiStyle, quipTone }) {
  const items = [
    { d: 'dragon', when: '4m ago', who: 'mira.k', borough: 'Williamsburg' },
    { d: 'whale', when: '11m ago', who: 'eitan_', borough: 'Astoria' },
    { d: 'dog', when: '14m ago', who: 'lola.h', borough: 'Park Slope' },
    { d: 'castle', when: '22m ago', who: 'sam', borough: 'UWS' },
    { d: 'heart', when: '28m ago', who: 'priya', borough: 'LES' },
    { d: 'spaceship', when: '31m ago', who: 'rambani', borough: 'Bushwick' },
  ];
  return (
    <CVPhone theme={theme}>
      {/* Header */}
      <div style={{ padding: '24px 20px 16px' }}>
        <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
          <div>
            <div style={{
              fontFamily: '"JetBrains Mono", monospace', fontSize: 10, letterSpacing: 1.6,
              textTransform: 'uppercase', color: theme.inkMute,
            }}>The city is watching</div>
            <h2 style={{
              fontFamily: '"Instrument Serif", serif', fontWeight: 400,
              fontSize: 36, lineHeight: 1.02, letterSpacing: -0.6, margin: '4px 0 0', color: theme.ink,
            }}>New York, today</h2>
          </div>
          <CVChip theme={theme} tone="accent">
            <span style={{ width: 6, height: 6, borderRadius: 3, background: theme.accent, display: 'inline-block' }} />
            247
          </CVChip>
        </div>

        {/* Filter row */}
        <div style={{ marginTop: 16, display: 'flex', gap: 6, overflow: 'hidden' }}>
          {['All', 'Animals', 'Faces', 'Vehicles', 'Architecture'].map((f, i) => (
            <div key={f} style={{
              padding: '6px 12px', borderRadius: 999, fontSize: 12, fontWeight: 500,
              background: i === 0 ? theme.ink : theme.chipBg,
              color: i === 0 ? theme.bg : theme.inkSoft,
            }}>{f}</div>
          ))}
        </div>
      </div>

      {/* Feed list */}
      <div style={{ position: 'absolute', top: 184, left: 0, right: 0, bottom: 100, overflow: 'hidden' }}>
        <div style={{ padding: '0 16px', display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
          {items.map((it, i) => (
            <div key={i} style={{
              borderRadius: 20, overflow: 'hidden', background: theme.surface,
              border: `0.5px solid ${theme.line}`,
            }}>
              <div style={{ position: 'relative', aspectRatio: '1 / 1' }}>
                <CVSkyPhoto mood={i % 3 === 0 ? 'day' : i % 3 === 1 ? 'golden' : 'dawn'} style={{ position: 'absolute', inset: 0 }} />
                <CVAIOverlay drawing={it.d} aiStyle={aiStyle} theme={theme} />
              </div>
              <div style={{ padding: '10px 12px 12px' }}>
                <div style={{
                  fontFamily: '"Instrument Serif", serif', fontSize: 14.5, lineHeight: 1.2,
                  fontStyle: 'italic', color: theme.ink, textWrap: 'pretty',
                }}>{cvQuip(it.d, quipTone)}</div>
                <div style={{
                  marginTop: 6, display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                  fontSize: 10.5, color: theme.inkMute, fontFamily: '"JetBrains Mono", monospace',
                }}>
                  <span>@{it.who} · {it.borough}</span>
                  <span>{it.when}</span>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      <CVTabBar theme={theme} active="feed" />
    </CVPhone>
  );
}

// ─────────────────────────────────────────────────────────────
// 8 · Map (NYC sightings)
// ─────────────────────────────────────────────────────────────
function CVScreenMap({ theme, aiStyle }) {
  // Stylized map: rounded blocks representing Manhattan + boroughs.
  const blocks = [
    { x: 30, y: 14, w: 32, h: 18 }, // upper manhattan
    { x: 28, y: 30, w: 36, h: 26 }, // midtown
    { x: 26, y: 54, w: 36, h: 18 }, // downtown
    { x: 62, y: 8, w: 30, h: 30 }, // bronx
    { x: 64, y: 36, w: 30, h: 26 }, // queens
    { x: 50, y: 64, w: 38, h: 24 }, // brooklyn
    { x: 6, y: 36, w: 18, h: 38 }, // nj
  ];
  // Sighting markers (x%, y%, drawing)
  const pins = [
    { x: 36, y: 28, d: 'dragon' },
    { x: 44, y: 44, d: 'whale' },
    { x: 70, y: 50, d: 'dog' },
    { x: 60, y: 68, d: 'castle' },
    { x: 36, y: 64, d: 'heart' },
    { x: 75, y: 18, d: 'spaceship' },
  ];
  return (
    <CVPhone theme={theme}>
      {/* Map */}
      <div style={{
        position: 'absolute', top: 47, left: 0, right: 0, bottom: 0,
        background: theme.dark ? '#0E1722' : '#E7ECF2',
      }}>
        {/* Water */}
        <svg viewBox="0 0 100 100" preserveAspectRatio="none" style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
          <rect width="100" height="100" fill={theme.dark ? '#0E1722' : '#DCE5EF'} />
          {/* Land blocks */}
          {blocks.map((b, i) => (
            <rect key={i} x={b.x} y={b.y} width={b.w} height={b.h} rx="3"
              fill={theme.dark ? '#1A2536' : '#F0F3F7'} />
          ))}
          {/* Streets */}
          {[20, 30, 40, 50, 60, 70, 80].map((y) => (
            <line key={'h' + y} x1="0" x2="100" y1={y} y2={y}
              stroke={theme.dark ? 'rgba(244,246,250,0.04)' : 'rgba(11,18,32,0.04)'} strokeWidth="0.2" />
          ))}
          {[10, 20, 30, 40, 50, 60, 70, 80, 90].map((x) => (
            <line key={'v' + x} x1={x} x2={x} y1="0" y2="100"
              stroke={theme.dark ? 'rgba(244,246,250,0.04)' : 'rgba(11,18,32,0.04)'} strokeWidth="0.2" />
          ))}
        </svg>

        {/* Pins */}
        {pins.map((p, i) => (
          <div key={i} style={{
            position: 'absolute', left: `${p.x}%`, top: `${p.y}%`, transform: 'translate(-50%, -100%)',
          }}>
            <div style={{
              width: 56, height: 56, borderRadius: 18,
              background: theme.surface, padding: 3,
              boxShadow: '0 6px 16px rgba(0,0,0,0.18)',
              border: `0.5px solid ${theme.line}`,
              position: 'relative',
              overflow: 'hidden',
            }}>
              <div style={{ position: 'relative', width: '100%', height: '100%', borderRadius: 14, overflow: 'hidden' }}>
                <CVSkyPhoto mood="day" style={{ position: 'absolute', inset: 0 }} />
                <CVAIOverlay drawing={p.d} aiStyle={aiStyle} theme={theme} />
              </div>
            </div>
            <div style={{
              width: 0, height: 0, margin: '0 auto',
              borderLeft: '5px solid transparent',
              borderRight: '5px solid transparent',
              borderTop: `7px solid ${theme.surface}`,
            }} />
          </div>
        ))}

        {/* Cluster bubble */}
        <div style={{
          position: 'absolute', left: '54%', top: '34%',
          width: 40, height: 40, borderRadius: 20,
          background: theme.accent, color: '#fff',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: 14, fontWeight: 700, boxShadow: '0 4px 12px rgba(0,0,0,0.2)',
        }}>12</div>
      </div>

      {/* Top search */}
      <div style={{
        position: 'absolute', top: 64, left: 16, right: 16,
      }}>
        <div style={{
          background: theme.surface, borderRadius: 20, padding: '12px 16px',
          display: 'flex', alignItems: 'center', gap: 10,
          boxShadow: '0 6px 18px rgba(0,0,0,0.08)',
          border: `0.5px solid ${theme.line}`,
        }}>
          <div style={{ width: 18, height: 18 }}>{CVIcon.search(theme.inkSoft)}</div>
          <div style={{ flex: 1, fontSize: 14, color: theme.inkSoft }}>Search a neighborhood</div>
          <CVChip theme={theme} tone="accent">last hour</CVChip>
        </div>
      </div>

      {/* Bottom sheet */}
      <div style={{
        position: 'absolute', bottom: 100, left: 16, right: 16,
        background: theme.surface, borderRadius: 24, padding: 16,
        border: `0.5px solid ${theme.line}`,
        boxShadow: '0 20px 60px -20px rgba(0,0,0,0.2)',
      }}>
        <div style={{
          width: 36, height: 4, borderRadius: 2, background: theme.line,
          margin: '0 auto 12px',
        }} />
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <div style={{
              fontFamily: '"JetBrains Mono", monospace', fontSize: 10, letterSpacing: 1.6,
              textTransform: 'uppercase', color: theme.inkMute,
            }}>Hottest spot</div>
            <div style={{
              fontFamily: '"Instrument Serif", serif', fontSize: 22, lineHeight: 1.1,
              color: theme.ink, marginTop: 2,
            }}>Prospect Park</div>
            <div style={{ fontSize: 12, color: theme.inkSoft, marginTop: 2 }}>12 sightings in the last hour</div>
          </div>
          <button style={{
            height: 38, padding: '0 16px', borderRadius: 19, border: 'none',
            background: theme.ink, color: theme.bg, fontSize: 13, fontWeight: 600,
            display: 'flex', alignItems: 'center', gap: 6, fontFamily: 'inherit',
          }}>
            Take me there
            <div style={{ width: 14, height: 14 }}>{CVIcon.arrow(theme.bg)}</div>
          </button>
        </div>
      </div>

      <CVTabBar theme={theme} active="map" />
    </CVPhone>
  );
}

// ─────────────────────────────────────────────────────────────
// 9 · Notification — iOS lock screen
// ─────────────────────────────────────────────────────────────
function CVScreenNotification({ theme, aiStyle, quipTone }) {
  return (
    <CVPhone theme={{ ...theme, bg: '#000' }}>
      {/* Wallpaper sky */}
      <CVSkyPhoto mood="golden" style={{ position: 'absolute', inset: 0 }} />
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.35)' }} />

      {/* Lock icon + date/time */}
      <div style={{ position: 'absolute', top: 70, left: 0, right: 0, textAlign: 'center', color: '#fff' }}>
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" style={{ opacity: 0.85 }}>
          <rect x="5" y="11" width="14" height="10" rx="2" stroke="#fff" strokeWidth="1.6" />
          <path d="M8 11V8a4 4 0 018 0v3" stroke="#fff" strokeWidth="1.6" />
        </svg>
        <div style={{
          marginTop: 30, fontSize: 17, fontWeight: 500, opacity: 0.95,
        }}>Wednesday, May 27</div>
        <div style={{
          fontSize: 96, fontWeight: 200, letterSpacing: -4, lineHeight: 1, marginTop: 0,
          fontFamily: '-apple-system, system-ui',
        }}>5:32</div>
      </div>

      {/* Notification card */}
      <div style={{
        position: 'absolute', top: 340, left: 12, right: 12,
        background: 'rgba(40,40,40,0.5)', backdropFilter: 'blur(40px) saturate(180%)',
        WebkitBackdropFilter: 'blur(40px) saturate(180%)',
        border: '0.5px solid rgba(255,255,255,0.15)',
        borderRadius: 20, padding: 14, color: '#fff',
        boxShadow: '0 10px 30px rgba(0,0,0,0.25)',
      }}>
        <div style={{ display: 'flex', alignItems: 'flex-start', gap: 12 }}>
          <div style={{
            width: 38, height: 38, borderRadius: 9,
            background: theme.accent,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            flexShrink: 0,
          }}>
            <div style={{ width: 22, height: 22 }}>{CVIcon.cloud('#fff')}</div>
          </div>
          <div style={{ flex: 1, minWidth: 0 }}>
            <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 2 }}>
              <span style={{ fontSize: 13, fontWeight: 600, letterSpacing: -0.2 }}>CLOUDVIEW</span>
              <span style={{ fontSize: 12, opacity: 0.7 }}>now</span>
            </div>
            <div style={{ fontSize: 15, fontWeight: 600, marginBottom: 4 }}>The sky over Brooklyn looks weird in a good way.</div>
            <div style={{ fontSize: 14, opacity: 0.85, lineHeight: 1.35, textWrap: 'pretty' }}>
              12 watchers spotted a dragon, a sleepy pup, and what might be a UFO. 8° cooler outside. Wanna look up?
            </div>

            {/* Preview chip */}
            <div style={{
              marginTop: 10, display: 'flex', gap: 8,
            }}>
              <div style={{
                position: 'relative', width: 56, height: 56, borderRadius: 12, overflow: 'hidden',
              }}>
                <CVSkyPhoto mood="golden" style={{ position: 'absolute', inset: 0 }} />
                <CVAIOverlay drawing="dragon" aiStyle={aiStyle} theme={theme} />
              </div>
              <div style={{
                flex: 1, fontFamily: '"Instrument Serif", serif', fontSize: 14.5,
                fontStyle: 'italic', lineHeight: 1.3, opacity: 0.92, textWrap: 'pretty',
              }}>{cvQuip('dragon', quipTone)}</div>
            </div>
          </div>
        </div>
      </div>

      {/* Camera + flashlight pills */}
      <div style={{
        position: 'absolute', bottom: 100, left: 0, right: 0,
        display: 'flex', justifyContent: 'space-between', padding: '0 36px',
      }}>
        <div style={{
          width: 50, height: 50, borderRadius: 25,
          background: 'rgba(50,50,50,0.55)', backdropFilter: 'blur(20px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <div style={{ width: 22, height: 22 }}>{CVIcon.flash('#fff')}</div>
        </div>
        <div style={{
          width: 50, height: 50, borderRadius: 25,
          background: 'rgba(50,50,50,0.55)', backdropFilter: 'blur(20px)',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>
          <div style={{ width: 22, height: 22 }}>{CVIcon.camera('#fff')}</div>
        </div>
      </div>
    </CVPhone>
  );
}

// ─────────────────────────────────────────────────────────────
// 10 · Collection (personal grid)
// ─────────────────────────────────────────────────────────────
function CVScreenCollection({ theme, aiStyle, quipTone }) {
  const items = [
    { d: 'dragon', m: 'day' },
    { d: 'whale', m: 'golden' },
    { d: 'dog', m: 'day' },
    { d: 'castle', m: 'dawn' },
    { d: 'heart', m: 'dusk' },
    { d: 'spaceship', m: 'golden' },
    { d: 'dragon', m: 'dawn' },
    { d: 'whale', m: 'stormy' },
    { d: 'castle', m: 'day' },
  ];
  return (
    <CVPhone theme={theme}>
      {/* Header */}
      <div style={{ padding: '20px 20px 12px' }}>
        <div style={{
          fontFamily: '"JetBrains Mono", monospace', fontSize: 10, letterSpacing: 1.6,
          textTransform: 'uppercase', color: theme.inkMute,
        }}>Your scrapbook</div>
        <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginTop: 2 }}>
          <h2 style={{
            fontFamily: '"Instrument Serif", serif', fontWeight: 400,
            fontSize: 34, lineHeight: 1.02, letterSpacing: -0.6, margin: 0, color: theme.ink,
          }}>48 finds, <span style={{ fontStyle: 'italic' }}>so far</span></h2>
          <div style={{ width: 30, height: 30 }}>{CVIcon.grid(theme.ink)}</div>
        </div>
        {/* tabs */}
        <div style={{ marginTop: 16, display: 'flex', gap: 18, color: theme.inkMute, fontSize: 14 }}>
          <span style={{ color: theme.ink, fontWeight: 600 }}>All</span>
          <span>Animals · 24</span>
          <span>Faces · 11</span>
          <span>Other · 13</span>
        </div>
      </div>

      {/* Grid */}
      <div style={{
        position: 'absolute', top: 200, left: 0, right: 0, bottom: 100,
        padding: '0 16px',
      }}>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 6 }}>
          {items.map((it, i) => (
            <div key={i} style={{
              position: 'relative', aspectRatio: '1 / 1', borderRadius: 10, overflow: 'hidden',
            }}>
              <CVSkyPhoto mood={it.m} style={{ position: 'absolute', inset: 0 }} />
              <CVAIOverlay drawing={it.d} aiStyle={aiStyle} theme={theme} />
              {i === 0 && (
                <div style={{
                  position: 'absolute', top: 6, right: 6,
                  width: 14, height: 14, borderRadius: 7,
                  background: theme.warm,
                  border: '1.5px solid #fff',
                }} />
              )}
            </div>
          ))}
        </div>
      </div>

      <CVTabBar theme={theme} active="feed" />
    </CVPhone>
  );
}

// ─────────────────────────────────────────────────────────────
// 11 · Profile
// ─────────────────────────────────────────────────────────────
function CVScreenProfile({ theme }) {
  return (
    <CVPhone theme={theme}>
      {/* Header band */}
      <div style={{ padding: '24px 20px 0' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 14 }}>
          <div style={{
            width: 64, height: 64, borderRadius: 32, overflow: 'hidden',
            border: `0.5px solid ${theme.line}`,
          }}>
            <CVSkyPhoto mood="golden" style={{ width: '100%', height: '100%' }} />
          </div>
          <div style={{ flex: 1 }}>
            <div style={{
              fontFamily: '"Instrument Serif", serif', fontSize: 26, lineHeight: 1.05,
              color: theme.ink, letterSpacing: -0.3,
            }}>Mira K.</div>
            <div style={{ fontSize: 12, color: theme.inkSoft, fontFamily: '"JetBrains Mono", monospace' }}>
              Brooklyn, NY · joined Mar 2026
            </div>
          </div>
          <button style={{
            height: 32, padding: '0 14px', borderRadius: 16, border: `0.5px solid ${theme.line}`,
            background: theme.surface, color: theme.ink, fontSize: 13, fontWeight: 500, fontFamily: 'inherit',
          }}>Edit</button>
        </div>

        {/* Streak */}
        <div style={{
          marginTop: 22, background: theme.surface, borderRadius: 22, padding: 18,
          border: `0.5px solid ${theme.line}`,
          position: 'relative', overflow: 'hidden',
        }}>
          <div style={{
            position: 'absolute', right: -40, top: -40, width: 160, height: 160, borderRadius: 80,
            background: theme.warmSoft,
          }} />
          <div style={{ position: 'relative' }}>
            <div style={{
              fontFamily: '"JetBrains Mono", monospace', fontSize: 10, letterSpacing: 1.6,
              textTransform: 'uppercase', color: theme.inkMute,
            }}>Sky streak</div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 8, marginTop: 2 }}>
              <div style={{
                fontFamily: '"Instrument Serif", serif', fontSize: 48, lineHeight: 1, color: theme.ink, letterSpacing: -1,
              }}>12</div>
              <div style={{ fontSize: 14, color: theme.inkSoft }}>days looking up</div>
            </div>
            {/* week */}
            <div style={{ marginTop: 14, display: 'flex', gap: 6 }}>
              {['M','T','W','T','F','S','S'].map((d, i) => (
                <div key={i} style={{
                  flex: 1, height: 32, borderRadius: 8,
                  background: i < 5 ? theme.ink : theme.chipBg,
                  color: i < 5 ? theme.bg : theme.inkMute,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 11, fontWeight: 600,
                }}>{d}</div>
              ))}
            </div>
          </div>
        </div>

        {/* Stats row */}
        <div style={{ marginTop: 14, display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
          {[
            { n: '48', l: 'finds' },
            { n: '6', l: 'badges' },
            { n: '2.4k', l: 'cloud-miles' },
          ].map((s, i) => (
            <div key={i} style={{
              background: theme.surface, borderRadius: 18, padding: '14px 14px',
              border: `0.5px solid ${theme.line}`,
            }}>
              <div style={{
                fontFamily: '"Instrument Serif", serif', fontSize: 28, lineHeight: 1, color: theme.ink,
              }}>{s.n}</div>
              <div style={{ fontSize: 11, color: theme.inkMute, marginTop: 4 }}>{s.l}</div>
            </div>
          ))}
        </div>

        {/* Badges */}
        <div style={{ marginTop: 22 }}>
          <div style={{
            fontFamily: '"JetBrains Mono", monospace', fontSize: 10, letterSpacing: 1.6,
            textTransform: 'uppercase', color: theme.inkMute, marginBottom: 10,
          }}>Badges earned</div>
          <div style={{ display: 'flex', gap: 10 }}>
            {[
              { l: 'Dawn Patrol', e: '☀' },
              { l: 'Cumulus Connoisseur', e: '☁' },
              { l: 'First Dragon', e: '⚡' },
              { l: 'Locked', e: '?' },
            ].map((b, i) => (
              <div key={i} style={{
                flex: 1, aspectRatio: '1 / 1.1', borderRadius: 14,
                background: i === 3 ? theme.chipBg : theme.surface,
                border: `0.5px solid ${theme.line}`,
                display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: 8,
                opacity: i === 3 ? 0.6 : 1,
              }}>
                <div style={{
                  width: 32, height: 32, borderRadius: 16, background: theme.chipBg,
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 18,
                }}>{b.e}</div>
                <div style={{
                  marginTop: 6, fontSize: 9.5, textAlign: 'center', color: theme.inkSoft, letterSpacing: 0.1,
                  textWrap: 'pretty', lineHeight: 1.15,
                }}>{b.l}</div>
              </div>
            ))}
          </div>
        </div>
      </div>

      <CVTabBar theme={theme} active="profile" />
    </CVPhone>
  );
}

Object.assign(window, {
  CVScreenWelcome, CVScreenPermissions, CVScreenHome,
  CVScreenCapture, CVScreenScanning, CVScreenResult,
  CVScreenFeed, CVScreenMap, CVScreenNotification,
  CVScreenCollection, CVScreenProfile, cvQuip, CV_QUIPS,
});
