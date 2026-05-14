"""Dump full semantic tree of contracts screen."""
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
    page.goto(URL, wait_until="networkidle")
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
    page.wait_for_timeout(10000)
    # Wake semantics + dismiss popup
    page.touchscreen.tap(240, 575)
    page.wait_for_timeout(3500)
    # Tap PLAY
    page.touchscreen.tap(240, 572)
    page.wait_for_timeout(5500)
    page.screenshot(path="/tmp/wh-screens/dbg_contracts.png")

    nodes = page.evaluate("""() => {
      const host = document.querySelector('flt-semantics-host');
      if (!host) return [];
      const items = [];
      host.querySelectorAll('flt-semantics').forEach((n, i) => {
        const rect = n.getBoundingClientRect();
        const role = n.getAttribute('role');
        const label = n.getAttribute('aria-label');
        if (label || role) {
          items.push({i, role, label: label?.slice(0, 80), x: rect.x, y: rect.y, w: rect.width, h: rect.height});
        }
      });
      return items;
    }""")
    print(f"contracts: {len(nodes)} labelled nodes")
    for n in nodes:
        print(f"  [{n['i']:3}] role={(n['role'] or '-'):8} @({n['x']:.0f},{n['y']:.0f}) {n['w']:.0f}x{n['h']:.0f}  {n['label']!r}")
    browser.close()
