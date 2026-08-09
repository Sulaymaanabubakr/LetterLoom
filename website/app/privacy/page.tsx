import type { Metadata } from "next";
import Link from "next/link";
import Nav from "@/components/Nav";
import FadeIn from "@/components/FadeIn";

export const metadata: Metadata = {
  title: "Privacy Policy - LetterLoom",
  description: "Privacy Policy for LetterLoom mobile application and website.",
};

export default function PrivacyPage() {
  return (
    <>
      <Nav isLegal />

      <main className="legal-page">
        <FadeIn delay={0.1}>
          <div className="legal-eyebrow">
            <span>✦</span> Legal &amp; Compliance <span>✦</span>
          </div>
          <h1 className="legal-title gold-text">Privacy Policy</h1>
          <p className="legal-updated">Last Updated: August 9, 2026</p>
        </FadeIn>

        <div className="legal-body">
          {[
            {
              title: "1. Overview",
              content: (
                <>
                  <p>
                    LetterLoom (&quot;we&quot;, &quot;our&quot;, or &quot;us&quot;) respects your privacy. This Privacy Policy describes how information is collected, used, and safeguarded when you use our mobile application (LetterLoom for iOS and Android) and our official website.
                  </p>
                  <p style={{ marginTop: 8 }}>
                    LetterLoom is designed with a privacy-first approach: single-player mode operates entirely offline without sending personal data to any server.
                  </p>
                </>
              ),
            },
            {
              title: "2. Information Collection and Use",
              content: (
                <>
                  <p><strong>A. Personal Information:</strong> We do not collect, request, store, or sell any personally identifiable information (PII) such as your name, email address, physical address, phone number, or contacts.</p>
                  <p style={{ marginTop: 8 }}><strong>B. Game Data &amp; Statistics:</strong> Game statistics (e.g. total matches played, high scores, win/loss record, best words played) are stored locally on your device using standard local storage mechanisms. This data never leaves your device.</p>
                  <p style={{ marginTop: 8 }}><strong>C. Online Multiplayer Data:</strong> When playing in Online Multiplayer mode, transient game state data (e.g. room codes, tile placements, scores, and turn sequence) is transmitted over secure WebSocket connections solely to synchronize the game session between players. Room data is ephemeral and is not permanently retained or linked to your identity after the match ends.</p>
                  <p style={{ marginTop: 8 }}><strong>D. Analytics &amp; Advertising:</strong> LetterLoom does not contain third-party advertising SDKs, behavioral tracking scripts, or cross-app tracking mechanisms.</p>
                </>
              ),
            },
            {
              title: "3. Network Communications & Offline Functionality",
              content: (
                <p>
                  LetterLoom bundles the complete ENABLE1 English dictionary directly within the application package. Offline solo matches against the AI do not require an active internet connection and execute zero network requests.
                </p>
              ),
            },
            {
              title: "4. Children's Privacy",
              content: (
                <p>
                  LetterLoom is suitable for players of all ages. Because we do not collect personal information from any user, we do not knowingly collect or solicit personal information from children under the age of 13 (or 16 in certain jurisdictions), in compliance with COPPA and GDPR regulations.
                </p>
              ),
            },
            {
              title: "5. Data Security",
              content: (
                <p>
                  We implement industry-standard encryption protocols (HTTPS / Secure WebSockets) for all live network traffic during multiplayer sessions. Local data resides strictly within your device secure application sandbox.
                </p>
              ),
            },
            {
              title: "6. Third-Party Services",
              content: (
                <p>
                  Our application may be distributed through platforms such as Apple App Store and Google Play Store. These platforms may collect anonymous device metrics or crash logs according to their respective privacy policies.
                </p>
              ),
            },
            {
              title: "7. Changes to This Policy",
              content: (
                <p>
                  We may update our Privacy Policy from time to time. Any changes will be posted on this page with an updated Last Updated date. Continued use of LetterLoom following any updates indicates acceptance of the modified policy.
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
              <h2>Contact Us</h2>
              <p>
                If you have any questions or concerns regarding this Privacy Policy, please contact our support team at:
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
