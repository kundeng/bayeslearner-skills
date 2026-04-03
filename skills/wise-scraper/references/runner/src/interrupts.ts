/**
 * Interrupt handler — deterministic side-MDP for common page interruptions.
 *
 * Handles: cookie banners, newsletter popups, confirmation dialogs, age gates,
 * notification permission prompts, GDPR consent, and similar visual blockers.
 *
 * Runs as a check-and-dismiss loop that the engine calls before/after actions.
 * Each rule is a simple (trigger CSS, dismiss action) pair — no AI needed.
 *
 * For hard CAPTCHAs, drag-to-match, or image challenges: out of scope.
 * Those belong in a separate system with visual AI capabilities.
 */

import type { BrowserDriver } from "./driver.js";
import { escapeJs } from "./driver.js";

export interface InterruptRule {
  /** Human-readable name for logging. */
  name: string;
  /** CSS selector — if this element exists, the interrupt is active. */
  trigger: string;
  /** How to dismiss it. */
  dismiss:
    | { click: string }            // click this CSS selector
    | { script: string }           // run this JS in browser context
    | { close_overlay: true }      // press Escape + remove fixed overlays
    | "pause";                     // stop execution, require human
  /** Only fire once? Default true — most banners don't reappear. */
  once?: boolean;
  /** Max times to fire (for recurring popups). Default 3. */
  max_fires?: number;
}

// ── shipped rules (common patterns) ─────────────────────

export const COMMON_RULES: InterruptRule[] = [
  {
    name: "cookie-consent",
    trigger: [
      "[class*='cookie'] button[class*='accept']",
      "[class*='cookie'] button[class*='agree']",
      "[id*='cookie'] button[class*='accept']",
      "#onetrust-accept-btn-handler",
      ".cc-btn.cc-dismiss",
      "[data-testid='cookie-accept']",
      "button[aria-label*='Accept cookies']",
      "button[aria-label*='Accept all']",
    ].join(", "),
    dismiss: { click: "SELF" },
    once: true,
  },
  {
    name: "gdpr-consent",
    trigger: [
      "[class*='gdpr'] button[class*='accept']",
      "[class*='consent'] button[class*='accept']",
      ".cmp-btn-accept",
      "#didomi-notice-agree-button",
    ].join(", "),
    dismiss: { click: "SELF" },
    once: true,
  },
  {
    name: "newsletter-popup",
    trigger: [
      "[class*='newsletter'] [class*='close']",
      "[class*='popup'] [class*='close']",
      "[class*='modal'] [class*='close']",
      "[class*='subscribe'] button[class*='close']",
    ].join(", "),
    dismiss: { click: "SELF" },
    once: true,
  },
  {
    name: "notification-prompt",
    trigger: [
      "[class*='notification'] [class*='deny']",
      "[class*='notification'] [class*='no']",
      "[class*='push'] [class*='close']",
      "[class*='allow-notifications'] [class*='close']",
    ].join(", "),
    dismiss: { click: "SELF" },
    once: true,
  },
  {
    name: "age-gate",
    trigger: [
      "[class*='age-gate'] button[class*='yes']",
      "[class*='age-verify'] button[class*='enter']",
      "[class*='age-check'] button[class*='confirm']",
    ].join(", "),
    dismiss: { click: "SELF" },
    once: true,
  },
  {
    name: "generic-overlay-close",
    trigger: [
      // Only match truly blocking modals — require aria-modal or .modal.show
      ".modal.show [data-dismiss='modal']",
      "[aria-modal='true'] button[aria-label='Close']",
      "[aria-modal='true'] button[class*='close']",
    ].join(", "),
    dismiss: { click: "SELF" },
    once: false,
    max_fires: 3,
  },
];

function splitSelectorList(trigger: string): string[] {
  const selectors: string[] = [];
  let current = "";
  let parenDepth = 0;
  let bracketDepth = 0;
  let quote: "'" | '"' | null = null;
  let escaped = false;

  for (const ch of trigger) {
    if (escaped) {
      current += ch;
      escaped = false;
      continue;
    }

    if (ch === "\\") {
      current += ch;
      escaped = true;
      continue;
    }

    if (quote) {
      current += ch;
      if (ch === quote) quote = null;
      continue;
    }

    if (ch === "'" || ch === '"') {
      quote = ch;
      current += ch;
      continue;
    }

    if (ch === "[") {
      bracketDepth++;
      current += ch;
      continue;
    }

    if (ch === "]" && bracketDepth > 0) {
      bracketDepth--;
      current += ch;
      continue;
    }

    if (ch === "(") {
      parenDepth++;
      current += ch;
      continue;
    }

    if (ch === ")" && parenDepth > 0) {
      parenDepth--;
      current += ch;
      continue;
    }

    if (ch === "," && parenDepth === 0 && bracketDepth === 0) {
      const trimmed = current.trim();
      if (trimmed) selectors.push(trimmed);
      current = "";
      continue;
    }

    current += ch;
  }

  const trimmed = current.trim();
  if (trimmed) selectors.push(trimmed);
  return selectors;
}

// ── handler ─────────────────────────────────────────────

export class InterruptHandler {
  private driver: BrowserDriver;
  private rules: InterruptRule[];
  private fireCounts = new Map<string, number>();
  private disabled = new Set<string>();

  constructor(driver: BrowserDriver, rules?: InterruptRule[]) {
    this.driver = driver;
    this.rules = rules ?? COMMON_RULES;
  }

  /** Add custom rules (from profile or hooks). */
  addRules(rules: InterruptRule[]): void {
    this.rules.push(...rules);
  }

  /**
   * Scan for active interrupts and dismiss them.
   * Call this before/after actions in the engine.
   * Returns the number of interrupts handled.
   */
  check(): number {
    let handled = 0;
    for (const rule of this.rules) {
      if (this.disabled.has(rule.name)) continue;

      const count = this.fireCounts.get(rule.name) ?? 0;
      const maxFires = rule.max_fires ?? (rule.once !== false ? 1 : 3);
      if (count >= maxFires) {
        this.disabled.add(rule.name);
        continue;
      }

      // Check if trigger element exists
      const match = this.findTrigger(rule.trigger);
      if (!match) continue;

      console.log(`  [interrupt] ${rule.name} detected`);

      if (rule.dismiss === "pause") {
        console.log(`  [interrupt] ${rule.name} requires human intervention — pausing`);
        // In a real implementation, this would signal the runner to pause
        // and wait for external input. For now, log and skip.
        this.disabled.add(rule.name);
        continue;
      }

      if ("click" in rule.dismiss) {
        const target = rule.dismiss.click === "SELF" ? match : rule.dismiss.click;
        this.driver.click({ css: target });
      } else if ("script" in rule.dismiss) {
        this.driver.eval(rule.dismiss.script);
      } else if ("close_overlay" in rule.dismiss) {
        // Press Escape, then remove only obviously blocking overlays using computed styles.
        this.driver.eval(`
          document.dispatchEvent(new KeyboardEvent('keydown', {key: 'Escape', bubbles: true}));
        `);
        this.driver.wait({ ms: 300 });
        this.driver.eval(`
          (() => {
            const selectors = [
              '[aria-modal="true"]',
              '[role="dialog"]',
              '[class*="modal"]',
              '[class*="overlay"]',
              '[class*="popup"]',
              '[class*="dialog"]',
              '[class*="backdrop"]',
            ].join(', ');
            const viewportArea = window.innerWidth * window.innerHeight;
            for (const el of document.querySelectorAll(selectors)) {
              const style = window.getComputedStyle(el);
              if (!style || style.display === 'none' || style.visibility === 'hidden') continue;
              if (style.pointerEvents === 'none') continue;
              const position = style.position;
              if (position !== 'fixed' && position !== 'sticky') continue;
              const rect = el.getBoundingClientRect();
              if (rect.width < 180 || rect.height < 120) continue;
              const area = rect.width * rect.height;
              const zIndex = Number.parseInt(style.zIndex || '', 10);
              const looksBlocking = area >= viewportArea * 0.08 || (!Number.isNaN(zIndex) && zIndex >= 1000);
              if (!looksBlocking) continue;
              el.remove();
            }
          })();
        `);
      }

      this.driver.wait({ ms: 500 });
      this.fireCounts.set(rule.name, count + 1);
      handled++;
      console.log(`  [interrupt] ${rule.name} dismissed`);
    }
    return handled;
  }

  /**
   * Find the first VISIBLE, non-zero-size matching element.
   * An element that exists in the DOM but is hidden, zero-sized, or
   * off-screen is not a blocking interrupt — skip it.
   */
  private findTrigger(trigger: string): string | null {
    const selectors = splitSelectorList(trigger);
    const selsJson = JSON.stringify(selectors);
    const idx = this.driver.evalJson<number>(`
      (() => {
        const sels = ${selsJson};
        for (let i = 0; i < sels.length; i++) {
          try {
            const el = document.querySelector(sels[i]);
            if (!el) continue;
            const rect = el.getBoundingClientRect();
            const style = window.getComputedStyle(el);
            // Must be visible: not hidden, not zero-size, not off-screen
            if (style.display === 'none' || style.visibility === 'hidden') continue;
            if (rect.width === 0 || rect.height === 0) continue;
            if (style.opacity === '0') continue;
            return i;
          } catch {}
        }
        return -1;
      })()
    `);
    return (idx !== null && idx >= 0) ? selectors[idx] : null;
  }
}
