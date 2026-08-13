import Image from "next/image";
import Link from "next/link";
import Nav from "@/components/Nav";
import StoreBadges from "@/components/StoreBadges";
import FadeIn from "@/components/FadeIn";

export default function HomePage() {
  return (
    <>
      <Nav />

      <main>
        {/* HERO */}
        <section className="hero">
          <div className="hero-glow" aria-hidden />

          <FadeIn direction="down" delay={0.1}>
            <Image
              src="/logo.png"
              alt="LetterLoom App Icon"
              width={140}
              height={140}
              className="hero-logo"
              priority
            />
          </FadeIn>

          <FadeIn delay={0.2}>
            <div className="hero-badge">
              <span>★</span> Premium Word Game
            </div>
          </FadeIn>

          <FadeIn delay={0.3}>
            <h1 className="hero-title gold-text">LetterLoom</h1>
          </FadeIn>

          <FadeIn delay={0.4}>
            <p className="hero-sub">
              <span className="arrow">➔</span>
              Solo Offline &nbsp;•&nbsp; Online Play
              <span className="arrow">➔</span>
            </p>
          </FadeIn>

          <FadeIn delay={0.5}>
            <p className="hero-desc">
              Thread letters together on a 15x15 board, craft high-scoring words, and
              outplay your opponent. Play alone against a clever AI or challenge
              someone from anywhere in the world.
            </p>
          </FadeIn>

          <FadeIn delay={0.6}>
            <div className="hero-cta">
              <a href="#download" className="btn-gold">Download Free →</a>
              <a href="#how-to-play" className="btn-outline">How to Play</a>
            </div>
          </FadeIn>
        </section>

        {/* TILE SHOWCASE */}
        <FadeIn delay={0.2} direction="up">
          <div className="tiles-showcase" aria-label="Letter tiles">
            {[
              ["L","1"],["E","1"],["T","1"],["T","1"],["E","1"],["R","1"],["S","1"],
            ].map(([letter, score], i) => (
              <div key={i} className="tile" style={{ animationDelay: `${i * 0.15}s`, animationDuration: "3s" }}>
                <span className="tile-letter">{letter}</span>
                <span className="tile-score">{score}</span>
              </div>
            ))}
          </div>
        </FadeIn>

        {/* FEATURES */}
        <section className="section" id="features">
          <FadeIn delay={0.1}>
            <p className="section-eyebrow">✦ &nbsp;What Sets Us Apart&nbsp; ✦</p>
            <h2 className="section-title gold-text">Crafted for Word Masters</h2>
            <p className="section-sub">
              Every detail of LetterLoom is built for an authentic, premium experience from the board to the soundtrack.
            </p>
          </FadeIn>

          <div className="features-grid">
            {[
              { icon: "🤖", title: "Smart AI Opponent", desc: "Three difficulty levels: Easy, Medium, and Hard. Strategic lookahead without requiring an internet connection." },
              { icon: "🌐", title: "Live Online Play", desc: "Create a room and invite anyone. Real-time turn-based play over a live connection." },
              { icon: "📖", title: "173,000+ Words", desc: "Powered by the ENABLE1 dictionary with over 173,000 verified English words bundled in-app." },
              { icon: "🎵", title: "Harmonic Soundscapes", desc: "Unwind with Midsummer Sky across the app, then settle into Sapphire Isle during games and Daily Challenge." },
              { icon: "⭐", title: "Premium Board", desc: "Classic 15x15 grid with Double/Triple multipliers, golden centre star, and mahogany wood aesthetics." },
              { icon: "📊", title: "Statistics & Progress", desc: "Track your wins, word scores, highest-scoring words, and streaks across all matches." },
            ].map((f, i) => (
              <FadeIn key={i} delay={0.1 + i * 0.1} direction="up">
                <div className="feature-card">
                  <div className="feature-icon">{f.icon}</div>
                  <h3 className="feature-title">{f.title}</h3>
                  <p className="feature-desc">{f.desc}</p>
                </div>
              </FadeIn>
            ))}
          </div>
        </section>

        {/* BOARD PREMIUM SPACES */}
        <section className="section" style={{ paddingTop: 0 }}>
          <FadeIn delay={0.1}>
            <div style={{ textAlign: "center" }}>
              <p className="section-eyebrow">✦ &nbsp;Board Multipliers&nbsp; ✦</p>
              <h2 className="section-title">Master the Premium Spaces</h2>
              <p className="section-sub">
                Strategic placement on bonus cells is the difference between a good word and a game-winning move.
              </p>
            </div>
          </FadeIn>
          
          <FadeIn delay={0.2} direction="up">
            <div className="cells-row">
              <span className="cell-badge" style={{ background: "#2A9080" }}>DL: Double Letter</span>
              <span className="cell-badge" style={{ background: "#1C6CB3" }}>TL: Triple Letter</span>
              <span className="cell-badge" style={{ background: "#D8753C" }}>DW: Double Word</span>
              <span className="cell-badge" style={{ background: "#C63B30" }}>TW: Triple Word</span>
              <span className="cell-badge" style={{ background: "#D4AF37", color: "#1A1A1A" }}>★ Centre Star</span>
            </div>
          </FadeIn>
        </section>

        {/* HOW TO PLAY */}
        <section className="section" id="how-to-play">
          <FadeIn delay={0.1}>
            <p className="section-eyebrow">✦ &nbsp;The Rules&nbsp; ✦</p>
            <h2 className="section-title gold-text">How to Play</h2>
            <p className="section-sub">
              LetterLoom follows classic word-game rules. Simple to learn, deep to master.
            </p>
          </FadeIn>

          <div className="steps-grid">
            {[
              {
                n: "1",
                title: "Place Your First Word",
                desc: "The opening word must cross the golden centre star cell (★). All tiles in a turn must be in a single row or column with no gaps. As you place tiles, LetterLoom validates the pending move in real time.",
              },
              {
                n: "2",
                title: "Connect to the Board",
                desc: "Every subsequent word must connect to at least one tile already on the board. Build an interlocking web of words.",
              },
              {
                n: "3",
                title: "Score with Multipliers",
                desc: "Letter scores are totalled, boosted by DL/TL cells, then multiplied by DW/TW cells. Using all 7 tiles earns a 50-point Bingo Bonus!",
              },
              {
                n: "4",
                title: "Exchange or Pass",
                desc: "Swap any number of tiles with the bag (if 7 or more remain) or pass your turn. Six consecutive passes ends the game.",
              },
              {
                n: "5",
                title: "Use Blank Tiles Wisely",
                desc: "Blank tiles can represent any letter but score 0 points. Choose wisely to unlock high-value word placements.",
              },
              {
                n: "6",
                title: "Play Together",
                desc: "Create or join a 2–4-player room, then use the microphone beside Play Word for voice chat. The player card of whoever is speaking highlights in green, while avatars and scores stay visible throughout the match.",
              },
            ].map((s, i) => (
              <FadeIn key={s.n} delay={0.1 + i * 0.1} direction="right">
                <div className="step-card">
                  <div className="step-num">{s.n}</div>
                  <div>
                    <p className="step-body-title">{s.title}</p>
                    <p className="step-body-desc">{s.desc}</p>
                  </div>
                </div>
              </FadeIn>
            ))}
          </div>

          <FadeIn delay={0.3} direction="up">
            <div style={{ marginTop: 28, padding: "18px 24px", borderRadius: 16, background: "linear-gradient(180deg, #0A3022, #031610)", border: "1px solid rgba(212,175,55,0.35)", display: "flex", alignItems: "center", gap: 16 }}>
              <div style={{ width: 10, height: 10, minWidth: 10, background: "#1B895C", border: "1.5px solid #D4AF37", transform: "rotate(45deg)", flexShrink: 0 }} />
              <p style={{ fontSize: 14, color: "var(--muted-ivory)", lineHeight: 1.6, fontStyle: "italic" }}>
                <strong style={{ color: "var(--ivory-text)" }}>Tip: </strong>
                Plan ahead, use premium spaces wisely, and keep your rack flexible. The best words are woven with strategy.
              </p>
            </div>
          </FadeIn>
        </section>

        {/* GAME MODES */}
        <section className="section" id="modes" style={{ paddingTop: 0 }}>
          <FadeIn delay={0.1}>
            <p className="section-eyebrow">✦ &nbsp;Play Your Way&nbsp; ✦</p>
            <h2 className="section-title gold-text">Two Ways to Play</h2>
            <p className="section-sub">
              Whether you prefer solitude or competition, LetterLoom has a mode for you.
            </p>
          </FadeIn>

          <div className="modes-grid">
            <FadeIn delay={0.1} direction="right" fullWidth>
              <div className="mode-card primary">
                <div className="mode-icon">♟️</div>
                <h3 className="mode-title" style={{ color: "#1E1402" }}>Solo vs AI</h3>
                <p className="mode-desc" style={{ color: "#4E3705" }}>
                  Play offline against a smart computer opponent. Three difficulty levels: Easy, Medium, and Hard. No Wi-Fi needed.
                </p>
                <span className="mode-tag" style={{ background: "rgba(30,20,2,0.2)", color: "#1E1402", fontSize: 10, fontWeight: 700, letterSpacing: "1.5px", textTransform: "uppercase", padding: "5px 14px", borderRadius: 999 }}>
                  Fully Offline
                </span>
              </div>
            </FadeIn>

            <FadeIn delay={0.2} direction="left" fullWidth>
              <div className="mode-card">
                <div className="mode-icon">🌐</div>
                <h3 className="mode-title">Multiplayer</h3>
                <p className="mode-desc">
                  Create a 2–4-player room and share the code. Challenge friends or family anywhere in the world with real-time turns, voice chat, avatars, scores, and green speaking indicators. If the owner ends a casual room, guests are returned to Multiplayer setup automatically.
                </p>
                <span className="mode-tag outline">
                  Live Multiplayer
                </span>
              </div>
            </FadeIn>
          </div>
        </section>

        {/* DOWNLOAD CTA */}
        <div className="cta-section" id="download">
          <FadeIn delay={0.1} direction="up">
            <div className="cta-banner">
              <h2 className="cta-title gold-text">Ready to Weave Words?</h2>
              <p className="cta-sub">
                Download LetterLoom free on iOS and Android. No ads, no subscriptions, just pure word-game excellence.
              </p>
              <StoreBadges />
            </div>
          </FadeIn>
        </div>
      </main>

      {/* FOOTER */}
      <footer>
        <div className="footer-inner">
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            <Image src="/logo.png" alt="LetterLoom" width={28} height={28} style={{ borderRadius: 7, border: "1px solid rgba(212,175,55,0.4)" }} />
            <span style={{ fontFamily: "Lora, serif", fontSize: 16, fontWeight: 700 }} className="gold-text">LetterLoom</span>
          </div>
          <nav className="footer-links" aria-label="Footer navigation">
            <Link href="/">Home</Link>
            <Link href="/privacy">Privacy Policy</Link>
            <Link href="/terms">Terms of Service</Link>
            <a href="mailto:sulaymaanabubakr@gmail.com">Contact</a>
          </nav>
          <p className="footer-copy">
            © {new Date().getFullYear()} LetterLoom. Handcrafted by Sulaymaan Abubakr. Version 1.0.0
          </p>
        </div>
      </footer>
    </>
  );
}
