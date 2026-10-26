// The site header's one script, as on every page of chambersandlight.com.
//
// A copy of the script in site/src/components/SiteHeader.astro in
// bchambers67/briantchambers.com — the source of truth; when that changes,
// this is updated by hand. Plain script, no module: the tool ships plain
// files and the utilities CSP is `script-src 'self'`, which this satisfies.
//
// The menu is a popover (`popover` on the nav, `popovertarget` on the
// button): the browser owns the toggle, Escape with focus back on the
// button, closing on a tap outside, and the expanded state for assistive
// tech — with or without JavaScript. The one thing left to a script is
// closing the drawer when the viewport grows past the phone breakpoint,
// where the nav is the inline row again and an open popover would otherwise
// stay in the top layer over the page — same breakpoint as the stylesheet,
// they have to move together — and, while the drawer is open, putting the
// page out of play for everyone, not only the pointer: inert on everything
// but the drawer and its button, so Tab from the last item comes back to the
// button rather than going on to the shifted page, and assistive tech reads
// the drawer alone. The stylesheet's pointer-events rule is the floor
// without this. Never on body: the drawer and the button are inside it.
// (The site's script for the header over the home page's hero has no
// counterpart here: the tool has no hero.)
(function () {
  "use strict";
  var nav = document.getElementById("site-nav");
  if (!nav || !("hidePopover" in nav)) return;
  var wide = matchMedia("(min-width: 621px)");
  wide.addEventListener("change", function () {
    if (wide.matches && nav.matches(":popover-open")) nav.hidePopover();
  });
  // iOS Safari keeps a fast path for a page with no touch or pointer
  // listeners: the tap is recognised in the browser's own process and a
  // click is synthesised from there, and the popover's light dismiss, which
  // rides on pointerdown and pointerup, never ran on it (WebKit bug 267688,
  // fixed in Safari 18.3 — by adding exactly this kind of listener, reports
  // said). A listener on the document, doing nothing, takes the page off
  // that path everywhere, so a tap on the cross or on the shifted page is
  // the same sequence of events it is on a mouse.
  document.addEventListener("pointerdown", function () {}, { passive: true });

  // A swipe in from the right edge opens the drawer, as the button does: a
  // touch that starts in the last 64px, edge included, crosses 48px
  // leftward more across than along, and is still 48px out when it lifts.
  // The outer part of that band is often the system's — Android's back
  // gesture takes about 30dp from the edge (up to 40 at its high setting),
  // Safari's forward swipe takes the edge when there is a page to go
  // forward to — and a start it claims arrives here as a touchstart and
  // then a touchcancel; the band reaches past it so a thumb still has
  // room. Opened at the lift, not during the move: a pointerup that
  // outlives the move (under a touch-action that keeps the pointer alive)
  // comes before touchend and would light-dismiss a drawer opened on the
  // move. Touch events, not pointer: once the page scrolls, iOS turns a
  // pointer sequence into a pointercancel, and this only watches. Passive
  // throughout, so the page scrolls as it did. A strip that scrolls across
  // under the finger, or has claimed the sideways move with touch-action,
  // keeps its own swipe, and a dialog keeps its gestures; the walk stops
  // below body, so a touch-action on the page root leaves the swipe
  // alone. (The tool has no strip or dialog; the walk is the site's, kept
  // in step.)
  function ownsAcross(from) {
    for (var el = from; el && el !== document.body; el = el.parentElement) {
      var style = getComputedStyle(el);
      var overflowX = style.overflowX;
      var touchAction = style.touchAction;
      var scrolls =
        (overflowX === "auto" || overflowX === "scroll") && el.scrollWidth > el.clientWidth;
      var claims =
        touchAction !== "auto" &&
        touchAction !== "manipulation" &&
        !/pan-(x|left|right)/.test(touchAction);
      if (scrolls || claims) return true;
    }
    return false;
  }
  var swipe = null;
  document.addEventListener(
    "touchstart",
    function (e) {
      swipe = null;
      if (wide.matches || nav.matches(":popover-open") || e.touches.length !== 1) return;
      var t = e.touches[0];
      if (t.clientX < innerWidth - 64) return;
      var target = e.target instanceof Element ? e.target : null;
      if ((target && target.closest("dialog")) || ownsAcross(target)) return;
      swipe = { x: t.clientX, y: t.clientY, open: false };
    },
    { passive: true }
  );
  document.addEventListener(
    "touchmove",
    function (e) {
      if (!swipe) return;
      var t = e.touches[0];
      var dx = swipe.x - t.clientX;
      var dy = Math.abs(t.clientY - swipe.y);
      // Along more than across: a scroll. Let it be one.
      if (dy > 24 && dy > dx) {
        swipe = null;
        return;
      }
      // The direction is decided where the swipe crosses 48px; after that
      // only the distance is read again, so out and back opens nothing.
      swipe.open = dx >= 48 && (swipe.open || dx > dy * 1.5);
    },
    { passive: true }
  );
  document.addEventListener(
    "touchend",
    function () {
      if (swipe && swipe.open && !wide.matches && !nav.matches(":popover-open")) {
        nav.showPopover();
      }
      swipe = null;
    },
    { passive: true }
  );
  document.addEventListener(
    "touchcancel",
    function () {
      swipe = null;
    },
    { passive: true }
  );

  var aside = document.querySelectorAll(".skip, main, footer, .site-header .bar > .home");
  nav.addEventListener("toggle", function (e) {
    var open = e.newState === "open";
    aside.forEach(function (el) {
      el.inert = open;
    });
  });
})();
