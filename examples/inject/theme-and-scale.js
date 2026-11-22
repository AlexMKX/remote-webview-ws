// User inject script for Remote WebView Server: set it as INJECT_JS_URL, e.g.
// hosted in Home Assistant's /config/www and served as
// https://ha.example.com/local/theme-and-scale.js. It forces the Home Assistant
// theme light/dark (fixed or on a daily schedule) and optionally scales the
// page horizontally for panels that stretch the dashboard. It runs in EVERY
// page the server renders - keep secrets out of this file.
const CONFIG = {
  origins: ["https://ha.example.com"], // only these origins are touched
  mode: "light",         // "light" | "dark" | "schedule"
  darkFrom: 20,          // schedule: hour (0-23) to switch to dark
  lightFrom: 8,          // schedule: hour to switch to light; darkFrom === lightFrom = always dark
  timeZone: undefined,   // IANA zone for the schedule, e.g. "Europe/Berlin"; undefined = container time
  scaleX: 1,             // horizontal CSS scale; 1 = off
};

(() => {
  // A failure here must not break the page.
  try {
    if (!CONFIG.origins.includes(location.origin)) return;
    const ls = window.localStorage;
    const wantDark = () => {
      if (CONFIG.mode !== "schedule") return CONFIG.mode === "dark";
      if (CONFIG.darkFrom === CONFIG.lightFrom) return true;
      const h = Number(new Intl.DateTimeFormat("en-GB", { hour: "2-digit", hourCycle: "h23", timeZone: CONFIG.timeZone || undefined }).format(new Date()));
      // Schedules may cross midnight: 20->8 means dark from 20:00 to 08:00.
      return CONFIG.darkFrom > CONFIG.lightFrom ? (h >= CONFIG.darkFrom || h < CONFIG.lightFrom) : (h >= CONFIG.darkFrom && h < CONFIG.lightFrom);
    };
    const theme = () => { try { return JSON.parse(ls.getItem("selectedTheme")) || {}; } catch { return {}; } };
    const applyTheme = () => {
      const t = theme(), dark = wantDark();
      if (t.dark === dark) return false;
      ls.setItem("selectedTheme", JSON.stringify({ theme: "default", ...t, dark }));
      return true;
    };
    applyTheme();
    // HA only re-reads selectedTheme on load: reload when the schedule flips.
    setInterval(() => { if (applyTheme()) location.reload(); }, 60000);
    if (Math.abs(CONFIG.scaleX - 1) > 0.001) {
      const css = `html{transform-origin:top left!important;transform:scaleX(${CONFIG.scaleX})!important;width:${100 / CONFIG.scaleX}%!important;overflow-x:hidden!important}body{overflow-x:hidden!important}`;
      // Returns true once the style exists; false while the document has no root yet.
      const add = () => {
        if (document.getElementById("rwv-scale")) return true;
        const root = document.head || document.documentElement;
        if (!root) return false;
        const s = document.createElement("style");
        s.id = "rwv-scale";
        s.textContent = css;
        root.appendChild(s);
        return true;
      };
      if (!add()) {
        const mo = new MutationObserver(() => { if (add()) mo.disconnect(); });
        mo.observe(document, { childList: true, subtree: true });
      }
    }
  } catch (e) {
    console.warn("[rwv-theme] injected script failed:", e);
  }
})();
