"use client";

import { useState } from "react";

export default function StoreBadges() {
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  const handleAppStoreClick = (e: React.MouseEvent) => {
    e.preventDefault();
    setToastMessage("iOS App Store version coming soon!");
    setTimeout(() => {
      setToastMessage(null);
    }, 3000);
  };

  return (
    <div className="store-badges-container">
      <div className="store-badges">
        {/* Google Play Store (Available Now) */}
        <a
          href="https://play.google.com/store/apps/details?id=com.letter.loom"
          target="_blank"
          rel="noopener noreferrer"
          className="store-badge play-store"
          aria-label="Get it on Google Play"
        >
          <svg className="store-badge-svg" viewBox="0 0 24 24" fill="currentColor">
            <path d="M3.609 1.814L13.792 12 3.61 22.186a1.53 1.53 0 01-.61-.225 1.503 1.503 0 01-.5-.544 1.572 1.572 0 01-.176-.732V3.315c0-.262.06-.51.176-.732.115-.223.284-.407.5-.544.216-.138.423-.213.61-.225zm11.597 11.6L18.47 11.8a1.455 1.455 0 00.354-.366.862.862 0 00.122-.434.862.862 0 00-.122-.434 1.455 1.455 0 00-.354-.366l-3.264-1.614-2.227 2.228 2.227 2.228zm-2.482 2.482L4.62 23.957a1.42 1.42 0 00.732.072c.264-.038.513-.153.732-.336l9.64-7.797-2.999-2.999zm0-7.792l2.999-2.999-9.64-7.797a1.597 1.597 0 00-.732-.336 1.42 1.42 0 00-.732.072l8.105 11.06z" />
          </svg>
          <div className="store-badge-text">
            <div className="store-badge-sup">GET IT ON</div>
            <div className="store-badge-name">Google Play</div>
          </div>
        </a>

        {/* Apple App Store (Coming Soon) */}
        <a
          href="#"
          onClick={handleAppStoreClick}
          className="store-badge app-store"
          aria-label="Download on the App Store"
        >
          <svg className="store-badge-svg" viewBox="0 0 24 24" fill="currentColor">
            <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.85c.66-.8 1.11-1.92.99-3.04-.96.04-2.12.64-2.81 1.44-.61.71-1.14 1.86-1 2.97 1.07.08 2.16-.57 2.82-1.37z" />
          </svg>
          <div className="store-badge-text">
            <div className="store-badge-sup">DOWNLOAD ON THE</div>
            <div className="store-badge-name">App Store</div>
          </div>
          <span className="coming-soon-tag">Coming Soon</span>
        </a>
      </div>

      {/* Floating Toast Notification */}
      {toastMessage && (
        <div className="toast-notification">
          <span className="toast-icon">📱</span>
          <span>{toastMessage}</span>
        </div>
      )}
    </div>
  );
}
