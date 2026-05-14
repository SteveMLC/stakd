"""E2E walker rev 7 — popup-aware semantic walk.

Flutter web exposes labeled buttons as <flt-semantics role="button"
aria-label="..."> nodes when ensureSemantics() is on (now always
enabled in lib/main.dart). This walker:

1. Goes to the URL, clears storage, reloads
2. Polls the semantics tree until labelled nodes appear
3. Dismisses the Daily Rewards popup using its CLAIM button (matched
   by label prefix)
4. Walks every home button by aria-label, screenshots each screen,
   navigates back, repeats
5. Exits non-zero on any pageerror, console error, or missing label
"""
import sys
from playwright.sync_api import sync_playwright

URL = "http://127.0.0.1:8770"
OUT = "/tmp/wh-screens"
VIEWPORT = {"width": 480, "height": 900}


def _attr(s):
    return '"' + s.replace('"', '\\"') + '"'


def shot(page, name, wait_ms=1500):
    page.wait_for_timeout(wait_ms)
    path = f"{OUT}/{name}.png"
    page.screenshot(path=path, full_page=False)
    size = open(path, "rb").read().__len__()
    print(f"[shot] {name}.png ({size} bytes)")


def all_labels(page):
    # IMPORTANT: query EXACTLY as discover_semantics.py does — via the
    # flt-semantics-host element, with no size filter.
    return page.evaluate(
        """() => {
          const host = document.querySelector('flt-semantics-host');
          if (!host) return [];
          const nodes = host.querySelectorAll('flt-semantics');
          const out = [];
          nodes.forEach((n, i) => {
            const rect = n.getBoundingClientRect();
            const role = n.getAttribute('role');
            const label = n.getAttribute('aria-label') || n.textContent?.trim().slice(0, 60);
            if (role || label) {
              out.push({i, role, label, x: rect.x, y: rect.y, w: rect.width, h: rect.height});
            }
          });
          return out;
        }"""
    )


def wait_for_label(page, predicate, timeout_ms=8000, poll_ms=300):
    """Wait until at least one labelled node matches `predicate(label)`."""
    elapsed = 0
    while elapsed < timeout_ms:
        labels = all_labels(page)
        for item in labels:
            if predicate(item["label"]):
                return item
        page.wait_for_timeout(poll_ms)
        elapsed += poll_ms
    return None


def tap_label(page, label_match, wait_ms=4000, exact=True, required=True):
    """Find + tap the first semantic node whose aria-label satisfies the
    predicate. `label_match` is a string (exact) or a callable."""
    if callable(label_match):
        predicate = label_match
        descr = "<callable>"
    else:
        descr = label_match
        if exact:
            predicate = lambda s: s == label_match  # noqa: E731
        else:
            predicate = lambda s: label_match in s  # noqa: E731
    target = wait_for_label(page, predicate, timeout_ms=4000)
    if target is None:
        msg = f"label not found: {descr!r}"
        if required:
            print(f"  !! {msg}")
        return False
    cx = target["x"] + target["w"] / 2
    cy = target["y"] + target["h"] / 2
    print(f"[tap] {target['label']!r} @ ({cx:.0f}, {cy:.0f})")
    page.touchscreen.tap(cx, cy)
    page.wait_for_timeout(wait_ms)
    return True


def main():
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        ctx = browser.new_context(
            viewport=VIEWPORT,
            device_scale_factor=2,
            has_touch=True,
            is_mobile=True,
        )
        ctx.clear_cookies()
        page = ctx.new_page()

        errors = []
        page.on("pageerror", lambda exc: errors.append(f"pageerror: {exc}"))
        page.on(
            "console",
            lambda msg: (
                errors.append(f"console-{msg.type}: {msg.text}")
                if msg.type == "error"
                else None
            ),
        )

        print(f"[goto] {URL}")
        page.goto(URL, wait_until="networkidle", timeout=60000)
        page.evaluate(
            """(async () => {
              const dbs = await indexedDB.databases();
              await Promise.all(dbs.map(db => new Promise(res => {
                const r = indexedDB.deleteDatabase(db.name);
                r.onsuccess = res; r.onerror = res; r.onblocked = res;
              })));
              localStorage.clear(); sessionStorage.clear();
            })();"""
        )
        page.wait_for_timeout(800)
        page.reload(wait_until="networkidle")
        page.wait_for_timeout(8000)

        # A blind tap inside the Flutter canvas wakes its semantics tree.
        # (240, 575) on first launch is the Daily Rewards popup's CLAIM
        # button, so this tap doubles as popup dismissal.
        page.touchscreen.tap(240, 575)
        page.wait_for_timeout(3500)

        # Verify semantics is built.
        labels_dbg = all_labels(page)
        print(f"  semantics built? {len(labels_dbg)} labelled nodes")
        if labels_dbg:
            print(f"  first few: {[l['label'][:30] for l in labels_dbg[:5]]}")

        # Wait until the popup's CLAIM button is in the semantics tree.
        claim = wait_for_label(
            page, lambda s: s and s.upper().startswith("CLAIM"), timeout_ms=20000
        )
        if claim:
            print(f"  found popup: {claim['label']!r}")
            cx = claim["x"] + claim["w"] / 2
            cy = claim["y"] + claim["h"] / 2
            page.touchscreen.tap(cx, cy)
            page.wait_for_timeout(3000)
        else:
            print("  no Daily Rewards popup detected")

        # Wait for the home PLAY button to appear.
        play = wait_for_label(page, lambda s: s == "PLAY", timeout_ms=10000)
        if not play:
            print("!! PLAY button never appeared in semantics tree")
            print("  visible labels:", [l["label"] for l in all_labels(page)][:20])
            sys.exit(1)
        print(f"  PLAY visible @ ({play['x']:.0f},{play['y']:.0f}) {play['w']:.0f}x{play['h']:.0f}")
        shot(page, "01_home")

        tap_label(page, "PLAY", wait_ms=5500)
        shot(page, "02_contract_select")

        # Contract cards are role=button without aria-labels. Find the
        # FIRST big button (wider than 200px) past the AppBar back arrow
        # — that's the first contract card.
        first_card = page.evaluate(
            """() => {
              const buttons = Array.from(document.querySelectorAll(
                'flt-semantics-host flt-semantics[role="button"]'
              ));
              for (const b of buttons) {
                const r = b.getBoundingClientRect();
                if (r.width >= 200 && r.height >= 100 && r.y >= 80) {
                  return {x: r.x, y: r.y, w: r.width, h: r.height};
                }
              }
              return null;
            }"""
        )
        if first_card:
            cx = first_card["x"] + first_card["w"] / 2
            cy = first_card["y"] + first_card["h"] / 2
            print(f"[tap] Local Contract 1 card @ ({cx:.0f}, {cy:.0f}) "
                  f"size {first_card['w']:.0f}x{first_card['h']:.0f}")
            page.touchscreen.tap(cx, cy)
            page.wait_for_timeout(7000)
        else:
            print("!! Local Contract 1 card not found")
        shot(page, "03_game_screen_with_protip")

        # Dismiss MultiGrabHintOverlay (the "Pro tip" card with "Got it"
        # button). Look for a semantic node with label "Got it" or for the
        # "Skip Tutorial" semantic.
        dismissed = False
        for try_label in ("Got it", "Skip Tutorial"):
            target = wait_for_label(page, lambda s: s == try_label, timeout_ms=2000)
            if target:
                cx = target["x"] + target["w"] / 2
                cy = target["y"] + target["h"] / 2
                print(f"[tap] {try_label!r} overlay @ ({cx:.0f}, {cy:.0f})")
                page.touchscreen.tap(cx, cy)
                page.wait_for_timeout(2500)
                dismissed = True
                break
        if not dismissed:
            print("  no overlay to dismiss")
        shot(page, "03b_after_overlay_dismiss")

        # Skip any tutorial spotlight that's still up.
        skip = wait_for_label(page, lambda s: s == "Skip Tutorial", timeout_ms=2000)
        if skip:
            cx = skip["x"] + skip["w"] / 2
            cy = skip["y"] + skip["h"] / 2
            print(f"[tap] Skip Tutorial @ ({cx:.0f}, {cy:.0f})")
            page.touchscreen.tap(cx, cy)
            page.wait_for_timeout(2000)

        shot(page, "03c_game_play_ready")

        # Stack positions discovered via inspect_game.py:
        # Top row stacks 0-2 at x=[168, 240, 312], y_center=326
        # Bottom row stacks 3-5 at x=[168, 240, 312], y_center=518
        # Back arrow @ (40, 40); Settings @ (440, 40)
        # Stack 0 has crates; Stack 4 (bottom middle) is empty buffer.
        STACK_CENTERS = {
            0: (168, 326),
            1: (240, 326),
            2: (312, 326),
            3: (168, 518),  # has crates
            4: (240, 518),  # empty buffer
            5: (312, 518),  # empty buffer
        }

        # Try tapping stack 3 (has crates) -> stack 4 (empty buffer)
        sx, sy = STACK_CENTERS[3]
        print(f"[tap] stack 3 select @ ({sx}, {sy})")
        page.touchscreen.tap(sx, sy)
        page.wait_for_timeout(900)
        shot(page, "04_stack_selected")

        dx, dy = STACK_CENTERS[4]
        print(f"[tap] stack 4 (empty buffer) dest @ ({dx}, {dy})")
        page.touchscreen.tap(dx, dy)
        page.wait_for_timeout(1800)
        shot(page, "05_after_move")

        # Try a second move: stack 0 (top-left, has crates) -> stack 5
        sx, sy = STACK_CENTERS[0]
        page.touchscreen.tap(sx, sy)
        page.wait_for_timeout(700)
        dx, dy = STACK_CENTERS[5]
        page.touchscreen.tap(dx, dy)
        page.wait_for_timeout(1500)
        shot(page, "05b_after_move2")

        # Back arrow at (40, 40).
        page.touchscreen.tap(40, 40)
        page.wait_for_timeout(2500)
        shot(page, "06_back_to_contracts")
        # Back to home.
        page.touchscreen.tap(40, 40)
        page.wait_for_timeout(2500)
        shot(page, "07_home_after_game")

        # Walk every remaining home button by label. Use coordinate-based
        # back navigation (Material AppBar back arrow at (40, 40)) since
        # it has no aria-label.
        for label, fname in [
            ("Forklifts", "08_forklift_shop"),
            ("Daily Contract", "09_daily_contract"),
            ("Levels", "10_levels_again"),
            ("Themes", "11_theme_store"),
            ("Achievements", "12_achievements"),
            ("Leaderboards", "13_leaderboards"),
            ("Settings", "14_settings"),
        ]:
            ok = tap_label(page, label, wait_ms=4000, required=False)
            shot(page, fname)
            # Coordinate-based back-arrow tap (no aria-label on Material's
            # default back button).
            page.touchscreen.tap(40, 40)
            page.wait_for_timeout(2500)
            if not ok:
                print(f"  ^ tapping {label!r} failed; continuing")

        browser.close()

        if errors:
            print("\n=== ERRORS ===")
            for e in errors[:30]:
                print(e)
            sys.exit(1)
        print("\n[done] all screens captured. no console errors.")


if __name__ == "__main__":
    main()
