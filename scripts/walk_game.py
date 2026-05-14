"""Walk the Warehouse Sort web build. Rev 5: corrected click coordinates
after manual visual inspection of the home screen layout.
"""
import sys
from playwright.sync_api import sync_playwright

URL = "http://127.0.0.1:8770"
OUT = "/tmp/wh-screens"
VIEWPORT = {"width": 480, "height": 900}
BACK_BTN = (28, 64)

# Manually calibrated click positions for the 480x900 home screen.
# Yellow PLAY button is in the lower middle.
PLAY_BTN = (240, 490)
DAILY_PILL = (240, 595)
ROW1_LEFT = (130, 660)   # Levels
ROW1_RIGHT = (350, 660)  # Themes
ROW2_LEFT = (130, 715)   # Achievements
ROW2_RIGHT = (350, 715)  # Leaderboards
ROW3_LEFT = (130, 770)   # Forklifts
ROW3_RIGHT = (350, 770)  # Settings


def shot(page, name, wait_ms=1500):
    page.wait_for_timeout(wait_ms)
    path = f"{OUT}/{name}.png"
    page.screenshot(path=path, full_page=False)
    size = open(path, "rb").read().__len__()
    print(f"[shot] {name}.png ({size} bytes)")


def tap(page, x, y, label, wait_ms=4500):
    print(f"[tap] {label} -> ({x}, {y})")
    # Touchscreen tap — Flutter web responds more reliably to TouchEvents
    # than to synthetic MouseEvents for canvas widgets.
    page.touchscreen.tap(x, y)
    page.wait_for_timeout(wait_ms)


def back(page, label="back", wait_ms=3500):
    tap(page, *BACK_BTN, f"BACK ({label})", wait_ms=wait_ms)


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
        try:
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
        except Exception as exc:  # noqa: BLE001
            print(f"[warn] storage clear skipped: {exc}")

        page.wait_for_timeout(10000)

        # Dismiss Daily Rewards popup.
        tap(page, 240, 575, "CLAIM 25 COINS", wait_ms=3000)
        tap(page, 30, 30, "settle", wait_ms=2000)
        shot(page, "01_home")

        tap(page, *PLAY_BTN, "PLAY", wait_ms=5500)
        shot(page, "02_contract_select")

        tap(page, 240, 360, "Local Contract 1 PLAY NEXT", wait_ms=7000)
        shot(page, "03_game_screen")

        # Game-board moves.
        tap(page, 90, 560, "stack 0 tap", wait_ms=900)
        shot(page, "04_stack_selected")
        tap(page, 240, 560, "stack 2 tap", wait_ms=2000)
        shot(page, "05_after_move")

        back(page, "game -> contracts")
        shot(page, "06_back_to_contracts")
        back(page, "contracts -> home")
        shot(page, "07_back_to_home")

        # Walk every home button.
        tap(page, *ROW3_LEFT, "Forklifts", wait_ms=5000)
        shot(page, "08_forklift_shop")
        back(page, "forklift -> home")

        tap(page, *DAILY_PILL, "Daily Contract", wait_ms=5500)
        shot(page, "09_daily_contract")
        back(page, "daily -> home")

        tap(page, *ROW1_LEFT, "Levels", wait_ms=4500)
        shot(page, "10_level_select")
        back(page, "levels -> home")

        tap(page, *ROW1_RIGHT, "Themes", wait_ms=4500)
        shot(page, "11_theme_store")
        back(page, "themes -> home")

        tap(page, *ROW2_LEFT, "Achievements", wait_ms=4500)
        shot(page, "12_achievements")
        back(page, "ach -> home")

        tap(page, *ROW2_RIGHT, "Leaderboards", wait_ms=4500)
        shot(page, "13_leaderboards")
        back(page, "lb -> home")

        tap(page, *ROW3_RIGHT, "Settings", wait_ms=4500)
        shot(page, "14_settings")

        browser.close()

        if errors:
            print("\n=== ERRORS ===")
            for e in errors[:30]:
                print(e)
            sys.exit(1)
        print("\n[done] all screens captured. no console errors.")


if __name__ == "__main__":
    main()
