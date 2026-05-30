// Cloudoodle — app entry. Mounts the design canvas with all screens.

const { useState, useEffect } = React;

const CV_DEFAULTS = /*EDITMODE-BEGIN*/{
  "theme": "airy",
  "aiStyle": "thin",
  "quipTone": "witty"
}/*EDITMODE-END*/;

function CVTweaks({ t, setTweak }) {
  return (
    <TweaksPanel title="Cloudoodle · Tweaks">
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
  );
}

function App() {
  const [t, setTweak] = useTweaks(CV_DEFAULTS);
  const theme = CV_THEMES[t.theme] || CV_THEMES.airy;
  const aiStyle = t.aiStyle || 'thin';
  const quipTone = t.quipTone || 'witty';
  const common = { theme, aiStyle, quipTone };

  return (
    <>
      <DesignCanvas minScale={0.1} maxScale={3}>
        {/* ── Intro card ────────────────────────────────────── */}
        <DCSection id="intro" title="Cloudoodle" subtitle="A pocket field guide for the imagination · scan the sky, find what's hiding">
          <DCArtboard id="cover" label="Concept" width={760} height={874}>
            <div style={{
              width: '100%', height: '100%', background: theme.bg, color: theme.ink,
              padding: '64px 56px', boxSizing: 'border-box', position: 'relative', overflow: 'hidden',
              fontFamily: '"Geist", "Inter Tight", -apple-system, system-ui, sans-serif',
            }}>
              {/* big sky photo with AI overlay as preview */}
              <div style={{
                position: 'absolute', right: -120, top: 80, width: 540, height: 540,
                borderRadius: 270, overflow: 'hidden',
                boxShadow: '0 30px 80px -30px rgba(11,18,32,0.3)',
              }}>
                <CVSkyPhoto mood="day" style={{ position: 'absolute', inset: 0 }} />
                <CVAIOverlay drawing="dragon" aiStyle={aiStyle} theme={theme} />
              </div>

              <div style={{
                fontFamily: '"JetBrains Mono", monospace', fontSize: 12, letterSpacing: 2.5,
                textTransform: 'uppercase', color: theme.inkMute,
              }}>Cloudoodle · iOS · v1.0</div>
              <h1 style={{
                marginTop: 18, fontFamily: '"Instrument Serif", serif', fontWeight: 400,
                fontSize: 88, lineHeight: 0.95, letterSpacing: -2.5, color: theme.ink, maxWidth: 460,
                textWrap: 'pretty',
              }}>
                Look up.<br/>
                <span style={{ fontStyle: 'italic' }}>Find</span> what&rsquo;s up.
              </h1>
              <p style={{
                marginTop: 26, fontSize: 17, lineHeight: 1.5, color: theme.inkSoft, maxWidth: 380,
              }}>
                Scan a patch of sky. Cloudoodle traces the shapes hiding in the clouds, writes a small caption for what it sees, and aggregates everyone&rsquo;s finds by city &mdash; so a sky worth stepping outside for never goes unnoticed.
              </p>

              <div style={{
                position: 'absolute', bottom: 64, left: 56, right: 56,
                display: 'flex', gap: 36, alignItems: 'flex-end', justifyContent: 'space-between',
              }}>
                <div style={{ display: 'flex', gap: 28 }}>
                  {[
                    { n: '11', l: 'screens' },
                    { n: '4', l: 'themes' },
                    { n: '4', l: 'overlay styles' },
                    { n: '3', l: 'quip tones' },
                  ].map((s, i) => (
                    <div key={i}>
                      <div style={{
                        fontFamily: '"Instrument Serif", serif', fontSize: 36, lineHeight: 1, color: theme.ink, letterSpacing: -0.8,
                      }}>{s.n}</div>
                      <div style={{ fontSize: 11, color: theme.inkMute, marginTop: 4, textTransform: 'uppercase', letterSpacing: 1.4, fontFamily: '"JetBrains Mono", monospace' }}>{s.l}</div>
                    </div>
                  ))}
                </div>
                <div style={{
                  fontSize: 12, color: theme.inkMute, fontFamily: '"JetBrains Mono", monospace',
                  textAlign: 'right',
                }}>open Tweaks &rarr;<br/>to switch theme + AI style</div>
              </div>
            </div>
          </DCArtboard>
        </DCSection>

        {/* ── Onboarding ────────────────────────────────────── */}
        <DCSection id="onboarding" title="01 · Onboarding" subtitle="First impression · setup">
          <DCArtboard id="welcome" label="Welcome" width={402} height={874}>
            <CVScreenWelcome {...common} />
          </DCArtboard>
          <DCArtboard id="permissions" label="Permissions" width={402} height={874}>
            <CVScreenPermissions {...common} />
          </DCArtboard>
        </DCSection>

        {/* ── Hero flow: capture → scan → result ───────────── */}
        <DCSection id="scanflow" title="02 · The scan" subtitle="The hero flow · capture → analyze → reveal">
          <DCArtboard id="capture" label="A · Viewfinder" width={402} height={874}>
            <CVScreenCapture {...common} />
          </DCArtboard>
          <DCArtboard id="scanning" label="B · Scanning (live)" width={402} height={874}>
            <CVScreenScanning {...common} />
          </DCArtboard>
          <DCArtboard id="result-dragon" label="C · Result · dragon" width={402} height={874}>
            <CVScreenResult {...common} drawing="dragon" />
          </DCArtboard>
          <DCArtboard id="result-whale" label="C · Result · whale" width={402} height={874}>
            <CVScreenResult {...common} drawing="whale" />
          </DCArtboard>
          <DCArtboard id="result-castle" label="C · Result · castle" width={402} height={874}>
            <CVScreenResult {...common} drawing="castle" />
          </DCArtboard>
        </DCSection>

        {/* ── Daily home ────────────────────────────────────── */}
        <DCSection id="home" title="03 · Today" subtitle="Daily home · what the city is seeing right now">
          <DCArtboard id="home-main" label="Home" width={402} height={874}>
            <CVScreenHome {...common} />
          </DCArtboard>
        </DCSection>

        {/* ── City view: feed + map ─────────────────────────── */}
        <DCSection id="city" title="04 · The city" subtitle="Aggregated finds across New York">
          <DCArtboard id="feed" label="Feed" width={402} height={874}>
            <CVScreenFeed {...common} />
          </DCArtboard>
          <DCArtboard id="map" label="Map" width={402} height={874}>
            <CVScreenMap {...common} />
          </DCArtboard>
        </DCSection>

        {/* ── Notification ──────────────────────────────────── */}
        <DCSection id="notif" title="05 · Step outside" subtitle="Lock-screen nudge when the sky gets good">
          <DCArtboard id="lock" label="Lock screen push" width={402} height={874}>
            <CVScreenNotification {...common} />
          </DCArtboard>
        </DCSection>

        {/* ── Personal: collection + profile ────────────────── */}
        <DCSection id="personal" title="06 · You" subtitle="Personal scrapbook · streaks · badges">
          <DCArtboard id="collection" label="Scrapbook" width={402} height={874}>
            <CVScreenCollection {...common} />
          </DCArtboard>
          <DCArtboard id="profile" label="Profile" width={402} height={874}>
            <CVScreenProfile {...common} />
          </DCArtboard>
        </DCSection>
      </DesignCanvas>

      <CVTweaks t={t} setTweak={setTweak} />
    </>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />);
