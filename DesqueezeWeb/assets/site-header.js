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
// stay in the top layer over the page. Same breakpoint as the stylesheet.
// They have to move together. (The site's second script, for the header
// over the home page's hero, has no counterpart here: the tool has no hero.)
(function () {
  "use strict";
  var nav = document.getElementById("site-nav");
  if (!nav || !("hidePopover" in nav)) return;
  var wide = matchMedia("(min-width: 621px)");
  wide.addEventListener("change", function () {
    if (wide.matches && nav.matches(":popover-open")) nav.hidePopover();
  });
})();
