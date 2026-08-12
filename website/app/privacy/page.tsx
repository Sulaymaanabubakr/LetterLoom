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
          <p className="legal-updated">Last Updated: August 12, 2026</p>
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
                    Offline solo play is designed to work without an account. Online features, sign-in, purchases, rewarded ads, push notifications, and the website use the services described below.
                  </p>
                </>
              ),
            },
            {
              title: "2. Information Collection and Use",
              content: (
                <>
                  <p><strong>A. Account information:</strong> If you choose to sign in with Google, we receive and store the account identifier needed to authenticate you and the profile information you provide or authorize for your LetterLoom profile, such as display name and avatar. We do not request your contacts, address, or phone number.</p>
                  <p style={{ marginTop: 8 }}><strong>B. Game and purchase data:</strong> Offline solo-game progress and settings are stored on your device. When you use online features, we store the profile, room code, match state, scores, turn history, ranked results, daily-challenge progress, and hint or purchase records necessary to operate those features and prevent duplicate fulfilment.</p>
                  <p style={{ marginTop: 8 }}><strong>C. Device and notification data:</strong> If you allow notifications, we store a Firebase Cloud Messaging token, platform, and last-seen time so we can send game-related notifications. Apple, Google, and Firebase may process device and delivery information under their own policies.</p>
                  <p style={{ marginTop: 8 }}><strong>D. Advertising and billing:</strong> The app includes Google Mobile Ads for optional rewarded ads and uses Apple App Store / Google Play billing for purchases. Those providers may process advertising identifiers, device information, transaction information, and fraud-prevention signals under their own privacy policies. LetterLoom does not sell personal information.</p>
                </>
              ),
            },
            {
              title: "3. Network Communications & Offline Functionality",
              content: (
                <p>
                  LetterLoom bundles the ENABLE1 English dictionary in the app. Offline solo matches do not require a network connection; however, your device may still contact Apple, Google, Firebase, or ad services when you enable features that use them.
                </p>
              ),
            },
            {
              title: "4. Children's Privacy",
              content: (
                <p>
                  LetterLoom is not directed to children where a parent or guardian&apos;s consent is required for online accounts, personalized advertising, or purchases. If you believe a child has provided personal information through an online account without appropriate consent, contact us and we will review and delete the information where required by applicable law.
                </p>
              ),
            },
            {
              title: "5. Data Security",
              content: (
                <p>
                  We use HTTPS and authenticated backend access for online services. No method of transmission or storage is completely secure, so please protect your account and device and contact us promptly if you suspect unauthorized access.
                </p>
              ),
            },
            {
              title: "6. Third-Party Services",
              content: (
                <p>
                  LetterLoom relies on Google Sign-In, Supabase (authentication and game data), Firebase Cloud Messaging, Google Mobile Ads, and Apple App Store / Google Play services where applicable. Each provider processes information under its own privacy policy. We retain online account and game records for as long as needed to provide the feature, resolve disputes, prevent fraud, or meet legal obligations. You can request access to or deletion of your LetterLoom account data by contacting us below.
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
