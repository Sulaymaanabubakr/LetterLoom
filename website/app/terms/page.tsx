import type { Metadata } from "next";
import Link from "next/link";
import Nav from "@/components/Nav";
import FadeIn from "@/components/FadeIn";

export const metadata: Metadata = {
  title: "Terms of Service - LetterLoom",
  description: "Terms of Service and End User License Agreement for LetterLoom.",
};

export default function TermsPage() {
  return (
    <>
      <Nav isLegal />

      <main className="legal-page">
        <FadeIn delay={0.1}>
          <div className="legal-eyebrow">
            <span>✦</span> Legal &amp; Compliance <span>✦</span>
          </div>
          <h1 className="legal-title gold-text">Terms of Service</h1>
          <p className="legal-updated">Last Updated: August 13, 2026</p>
        </FadeIn>

        <div className="legal-body">
          {[
            {
              title: "1. Agreement to Terms",
              content: (
                <p>
                  By downloading, installing, accessing, or using the LetterLoom application or website, you agree to be bound by these Terms of Service (&quot;Terms&quot;). If you do not agree to these Terms, please do not use the application or website.
                </p>
              ),
            },
            {
              title: "2. License & Intellectual Property",
              content: (
                <>
                  <p>
                    Subject to your compliance with these Terms, LetterLoom grants you a limited, non-exclusive, non-transferable, revocable license to download and play the LetterLoom application for entertainment. The original source code published in the LetterLoom repository is separately licensed under the MIT License; that source-code license does not grant rights to LetterLoom branding, screenshots, music, dictionary data, or other excluded media.
                  </p>
                  <p style={{ marginTop: 8 }}>
                    All original visual assets, UI design, branding, logo, code, and custom soundscapes (excluding open-source or CC-licensed media attributed in-app) are the intellectual property of Sulaymaan Abubakr and LetterLoom.
                  </p>
                </>
              ),
            },
            {
              title: "3. Lexicon & Word Verification",
              content: (
                <p>
                  Word verification in LetterLoom relies on the ENABLE1 (Enhanced North American Benchmark LExicon) reference list containing over 173,000 words. The inclusion or exclusion of any word is determined strictly by the reference dictionary standards and does not constitute endorsement of any specific terminology.
                </p>
              ),
            },
            {
              title: "4. Code of Conduct in Online Play",
              content: (
                <>
                  <p>When participating in online multiplayer rooms, you agree to:</p>
                  <ul>
                    <li>Refrain from attempting to reverse-engineer, exploit, or tamper with network protocol packets.</li>
                    <li>Not use automated software (bots, solver engines, or cheats) to manipulate online competitive matches.</li>
                    <li>Maintain respectful and fair sportsmanship.</li>
                  </ul>
                </>
              ),
            },
            {
              title: "5. Voice Chat & Multiplayer Rooms",
              content: (
                <>
                  <p>Multiplayer rooms may support 2–4 players and may include optional real-time voice chat. You are responsible for granting or denying microphone permission and for muting yourself when you do not wish to transmit audio. Voice chat is transported through Agora and is not recorded or stored by LetterLoom.</p>
                  <p style={{ marginTop: 8 }}>Volume and active-speaker indicators are gameplay signals used to highlight the player card of the person currently speaking. Do not use voice chat to harass, threaten, impersonate, or share unlawful, abusive, private, or harmful content.</p>
                  <p style={{ marginTop: 8 }}>A room owner may end a casual match. When that happens, the room&apos;s other players are removed from the match and returned to Multiplayer setup. Room state, player membership, avatars, scores, and move validation are controlled by the authoritative online service and may update in real time.</p>
                </>
              ),
            },
            {
              title: "6. Daily Features, Ranked Play & Fair Play",
              content: (
                <>
                  <p>Daily Challenge and Word of the Day content changes over time. A Daily Challenge has a time limit and may be marked failed when that time expires; leaving the challenge pauses its timer until you return. Scores, ranks, rewards, match outcomes, and availability are determined by the game&apos;s authoritative online services where applicable.</p>
                  <p style={{ marginTop: 8 }}>We may investigate, reverse, withhold, or reset progress, boosts, rankings, or access where we reasonably believe there has been cheating, exploitation, automation, fraud, or a technical error. This does not limit any rights you may have under applicable law.</p>
                </>
              ),
            },
            {
              title: "7. Boosts, Rewarded Ads & Purchases",
              content: (
                <>
                  <p>LetterLoom may offer optional rewarded ads and optional boost purchases. A rewarded ad only grants its stated in-game reward after the advertising provider confirms completion. Purchases are processed by the Apple App Store or Google Play, not directly by LetterLoom, and are subject to the applicable store&apos;s billing terms and refund policies.</p>
                  <p style={{ marginTop: 8 }}>Boosts are digital, non-transferable, have no cash value, and may not be sold, exchanged, or redeemed outside the app. We do not guarantee that rewarded ads will always be available.</p>
                </>
              ),
            },
            {
              title: "8. Notifications and Service Changes",
              content: (
                <p>With your permission, LetterLoom may send notifications about multiplayer turns, ranked matches, and Daily Challenges. You can manage categories in the app&apos;s Settings and can disable notifications in your device settings. Online features, content, and notifications may change, be unavailable, or be discontinued as we maintain and improve the service.</p>
              ),
            },
            {
              title: "9. Disclaimer of Warranties",
              content: (
                <p>
                  LetterLoom is provided on an &quot;AS IS&quot; and &quot;AS AVAILABLE&quot; basis without warranties of any kind, whether express or implied. We do not warrant that the application will operate uninterrupted or error-free at all times.
                </p>
              ),
            },
            {
              title: "10. Limitation of Liability",
              content: (
                <p>
                  To the fullest extent permitted by applicable law, LetterLoom and its creator shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising out of or related to your use of the application.
                </p>
              ),
            },
            {
              title: "11. Governing Law & Contact",
              content: (
                <p>
                  These Terms shall be governed by and construed in accordance with applicable laws, without regard to its conflict of law principles. For account, data, billing, or Terms questions, contact us using the address below.
                </p>
              ),
            },
          ].map((sec, i) => (
            <FadeIn key={sec.title} delay={0.1 + i * 0.08} direction="up">
              <div className="legal-section">
                <h2>{sec.title}</h2>
                {sec.content}
              </div>
            </FadeIn>
          ))}

          <FadeIn delay={0.3} direction="up">
            <div className="legal-contact">
              <h2>Questions or Inquiries?</h2>
              <p>
                If you have any questions regarding these Terms, please reach out to us at:
              </p>
              <p style={{ marginTop: 8 }}>
                <a href="mailto:sulaymaanabubakr@gmail.com">sulaymaanabubakr@gmail.com</a>
              </p>
            </div>
          </FadeIn>
        </div>
      </main>

      <footer>
        <div className="footer-inner">
          <div className="footer-links">
            <Link href="/">Home</Link>
            <Link href="/privacy">Privacy Policy</Link>
            <Link href="/terms">Terms of Service</Link>
          </div>
          <p className="footer-copy">
            © {new Date().getFullYear()} LetterLoom. Handcrafted by Sulaymaan Abubakr.
          </p>
        </div>
      </footer>
    </>
  );
}
