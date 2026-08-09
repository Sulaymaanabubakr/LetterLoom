"use client";

import { useState, useRef, useEffect } from "react";
import Image from "next/image";
import Link from "next/link";

interface NavProps {
  isLegal?: boolean;
}

export default function Nav({ isLegal = false }: NavProps) {
  const [isOpen, setIsOpen] = useState(false);
  const navRef = useRef<HTMLElement>(null);

  useEffect(() => {
    if (!isOpen) return;

    const handleClickOutside = (e: MouseEvent | TouchEvent) => {
      if (navRef.current && !navRef.current.contains(e.target as Node)) {
        setIsOpen(false);
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    document.addEventListener("touchstart", handleClickOutside);

    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
      document.removeEventListener("touchstart", handleClickOutside);
    };
  }, [isOpen]);

  return (
    <nav className="nav" ref={navRef}>
      <Link href="/" className="nav-brand" onClick={() => setIsOpen(false)}>
        <Image src="/logo.png" alt="LetterLoom Logo" width={38} height={38} className="nav-logo" />
        <span className="nav-title gold-text">LetterLoom</span>
      </Link>

      {/* Desktop Links */}
      <ul className="nav-links">
        {isLegal ? (
          <>
            <li><Link href="/">Home</Link></li>
            <li><Link href="/privacy">Privacy Policy</Link></li>
            <li><Link href="/terms">Terms of Service</Link></li>
          </>
        ) : (
          <>
            <li><a href="#features">Features</a></li>
            <li><a href="#how-to-play">How to Play</a></li>
            <li><a href="#modes">Game Modes</a></li>
            <li><a href="#download">Download</a></li>
            <li><Link href="/privacy">Privacy</Link></li>
          </>
        )}
      </ul>

      {/* Desktop Download Button */}
      <div className="nav-right-desktop">
        <a href="#download" className="btn-nav-download">Download App</a>
      </div>

      {/* Mobile Hamburger Button */}
      <button
        className="mobile-hamburger"
        onClick={() => setIsOpen(!isOpen)}
        aria-label="Toggle menu"
        aria-expanded={isOpen}
      >
        <span className={`bar ${isOpen ? "open" : ""}`} />
        <span className={`bar ${isOpen ? "open" : ""}`} />
        <span className={`bar ${isOpen ? "open" : ""}`} />
      </button>

      {/* Mobile Menu Dropdown Card */}
      {isOpen && (
        <div className="mobile-menu-card">
          <ul className="mobile-menu-links">
            {isLegal ? (
              <>
                <li><Link href="/" onClick={() => setIsOpen(false)}>Home</Link></li>
                <li><Link href="/privacy" onClick={() => setIsOpen(false)}>Privacy Policy</Link></li>
                <li><Link href="/terms" onClick={() => setIsOpen(false)}>Terms of Service</Link></li>
              </>
            ) : (
              <>
                <li><a href="#features" onClick={() => setIsOpen(false)}>Features</a></li>
                <li><a href="#how-to-play" onClick={() => setIsOpen(false)}>How to Play</a></li>
                <li><a href="#modes" onClick={() => setIsOpen(false)}>Game Modes</a></li>
                <li><a href="#download" onClick={() => setIsOpen(false)}>Download</a></li>
                <li><Link href="/privacy" onClick={() => setIsOpen(false)}>Privacy Policy</Link></li>
                <li><Link href="/terms" onClick={() => setIsOpen(false)}>Terms of Service</Link></li>
              </>
            )}
          </ul>
        </div>
      )}
    </nav>
  );
}
