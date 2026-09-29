// The site header's menu button, as on every page of chambersandlight.com.
//
// A copy of the script in site/src/components/SiteHeader.astro in
// bchambers67/briantchambers.com — the source of truth; when that changes,
// this is updated by hand. Plain script, no module: the tool ships plain
// files and the utilities CSP is `script-src 'self'`, which this satisfies.
//
// Three things beyond the toggle itself, each the thing a person reaches for
// next: Escape closes it and puts focus back on the button; a tap anywhere
// outside closes it; and growing past the phone breakpoint closes it, so a
// rotated tablet does not keep a stale panel. Collapsed is the stylesheet's
// default — this only toggles it — and without JavaScript the <noscript>
// sheet puts the wrapped row back, so the nav is never unreachable.
(function () {
  "use strict";
  var header = document.querySelector(".site-header");
  var button = header && header.querySelector(".menu-toggle");
  var nav = header && header.querySelector("#site-nav");
  if (!header || !button || !nav) return;

  function set(open) {
    header.classList.toggle("menu-open", open);
    button.setAttribute("aria-expanded", String(open));
  }
  function isOpen() {
    return header.classList.contains("menu-open");
  }

  button.addEventListener("click", function () {
    set(!isOpen());
  });

  document.addEventListener("keydown", function (e) {
    if (e.key !== "Escape" || !isOpen()) return;
    set(false);
    button.focus();
  });

  document.addEventListener("pointerdown", function (e) {
    if (!isOpen()) return;
    if (e.target instanceof Node && header.contains(e.target)) return;
    set(false);
  });

  // Same breakpoint as the stylesheet. Above it the panel is never shown,
  // so an open state left behind would only reappear on the next shrink.
  var wide = matchMedia("(min-width: 621px)");
  wide.addEventListener("change", function () {
    if (wide.matches) set(false);
  });
})();
