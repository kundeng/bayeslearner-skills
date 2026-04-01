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
      // Catch-all: any fixed/absolute overlay with a close button
      ".modal.show .close",
      ".modal.show [data-dismiss='modal']",
      "[role='dialog'] button[aria-label='Close']",
      "[role='dialog'] button[class*='close']",
    ].join(", "),
    dismiss: { click: "SELF" },
    once: false,
    max_fires: 3,
  },
];

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
        // Press Escape, then forcibly remove fixed-position overlays
        this.driver.eval(`
          document.dispatchEvent(new KeyboardEvent('keydown', {key: 'Escape', bubbles: true}));
        `);
        this.driver.wait({ ms: 300 });
        this.driver.eval(`
          document.querySelectorAll('[style*="position: fixed"], [style*="position:fixed"]')
            .forEach(el => { if (el.offsetHeight > 200) el.remove(); });
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
   * Find the first matching element for a (possibly compound) CSS selector.
   * Returns the narrowest matching selector, or null.
   */
  private findTrigger(trigger: string): string | null {
    // The trigger may be a comma-separated list — check each
    const selectors = trigger.split(",").map((s) => s.trim());
    for (const sel of selectors) {
      const exists = this.driver.evalJson<boolean>(`
        (() => document.querySelector('${escapeJs(sel)}') !== null)()
      `);
      if (exists) return sel;
    }
    return null;
  }
}
