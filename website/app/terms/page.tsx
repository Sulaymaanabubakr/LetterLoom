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
          <p className="legal-updated">Last Updated: August 9, 2026</p>
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
              title: "5. Disclaimer of Warranties",
              content: (
                <p>
                  LetterLoom is provided on an &quot;AS IS&quot; and &quot;AS AVAILABLE&quot; basis without warranties of any kind, whether express or implied. We do not warrant that the application will operate uninterrupted or error-free at all times.
                </p>
              ),
            },
            {
              title: "6. Limitation of Liability",
              content: (
                <p>
                  To the fullest extent permitted by applicable law, LetterLoom and its creator shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising out of or related to your use of the application.
                </p>
              ),
            },
            {
              title: "7. Governing Law",
              content: (
                <p>
                  These Terms shall be governed by and construed in accordance with applicable laws, without regard to its conflict of law principles.
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
