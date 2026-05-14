"""Inspect the Flutter web semantics tree to find clickable targets."""
from playwright.sync_api import sync_playwright

URL = "http://127.0.0.1:8770"

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    ctx = browser.new_context(
        viewport={"width": 480, "height": 900},
        device_scale_factor=2,
        has_touch=True,
        is_mobile=True,
    )
    page = ctx.new_page()
    page.on("pageerror", lambda exc: print(f"!! pageerror: {exc}"))

    page.goto(URL, wait_until="networkidle", timeout=60000)
    page.evaluate("""(async () => {
      const dbs = await indexedDB.databases();
      await Promise.all(dbs.map(db => new Promise(res => {
        const r = indexedDB.deleteDatabase(db.name);
        r.onsuccess = res; r.onerror = res; r.onblocked = res;
      })));
      localStorage.clear(); sessionStorage.clear();
    })();""")
    page.wait_for_timeout(800)
    page.reload(wait_until="networkidle")
    page.wait_for_timeout(12000)

    # Click an empty area to dismiss Daily Rewards popup if present
    page.touchscreen.tap(240, 575)  # CLAIM button
    page.wait_for_timeout(3000)

    # Dump the semantics tree
    result = page.evaluate("""
      (() => {
        const host = document.querySelector('flt-semantics-host');
        if (!host) return {err: "no semantics host"};
        // All flt-semantics nodes with role or aria-label
        const nodes = host.querySelectorAll('flt-semantics');
        const items = [];
        nodes.forEach((n, i) => {
          const rect = n.getBoundingClientRect();
          const role = n.getAttribute('role');
          const label = n.getAttribute('aria-label') || n.textContent?.trim().slice(0, 60);
          if (role || label) {
            items.push({
              i, role, label,
              x: Math.round(rect.x), y: Math.round(rect.y),
              w: Math.round(rect.width), h: Math.round(rect.height),
            });
          }
        });
        return {count: nodes.length, sample: items.slice(0, 30)};
      })();
    """)
    print(f"semantics nodes: {result['count']}")
    for item in result.get("sample", []):
        role = item.get('role') or '-'
        label = item.get('label') or '-'
        print(f"  [{item['i']:3}] role={role:8} label={label!r:50} @({item['x']},{item['y']}) {item['w']}x{item['h']}")

    browser.close()
