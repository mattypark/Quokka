// The confirmation card that appears on the page after a save.
//
// Injected with chrome.scripting.executeScript({ func: showToast }), which serialises the
// function's source into the page -- so it must be entirely self-contained: no imports, no
// closures over module state, nothing but its one argument.
//
// It lives in a closed shadow root so the page's CSS cannot restyle it and it cannot restyle
// the page. Every string is set with textContent, never innerHTML: the title comes from
// whatever page was open.

export function showToast(model) {
  const HOST_ID = "quokka-save-toast";
  document.getElementById(HOST_ID)?.remove();

  const host = document.createElement("div");
  host.id = HOST_ID;
  host.style.all = "initial";
  host.style.position = "fixed";
  host.style.right = "20px";
  host.style.bottom = "20px";
  host.style.zIndex = "2147483647";
  const root = host.attachShadow({ mode: "closed" });

  const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  const style = document.createElement("style");
  style.textContent = `
    .card {
      display: flex;
      align-items: center;
      gap: 12px;
      width: 300px;
      box-sizing: border-box;
      padding: 12px 14px 12px 12px;
      background: #ffffff;
      border: 0.5px solid rgba(0, 0, 0, 0.1);
      border-radius: 16px;
      box-shadow: 0 8px 28px rgba(0, 0, 0, 0.12);
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", system-ui, sans-serif;
      color: #0a0a0a;
      opacity: 0;
      transform: ${reduced ? "none" : "translateY(8px)"};
      transition: opacity 180ms ease-out, transform 220ms cubic-bezier(0.2, 0.8, 0.2, 1);
    }
    .card.shown { opacity: 1; transform: none; }
    .thumb {
      flex: none;
      width: 44px;
      height: 44px;
      border-radius: 8px;
      background: #f2f2f2;
      object-fit: cover;
      display: grid;
      place-items: center;
      font-size: 18px;
      font-weight: 600;
    }
    .thumb.check { background: #0a0a0a; color: #ffffff; }
    .thumb.fail { background: #f2f2f2; color: #6b6b6b; }
    .text { min-width: 0; flex: 1; }
    .title { font-size: 14px; font-weight: 500; letter-spacing: -0.2px; line-height: 19px; }
    .detail {
      font-size: 12px;
      line-height: 16px;
      color: #6b6b6b;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
    }
  `;

  const card = document.createElement("div");
  card.className = "card";
  card.setAttribute("role", "status");
  card.setAttribute("aria-live", "polite");

  let thumb;
  if (model.ok && model.image) {
    thumb = document.createElement("img");
    thumb.className = "thumb";
    thumb.alt = "";
    thumb.referrerPolicy = "no-referrer";
    thumb.src = model.image;
  } else {
    thumb = document.createElement("div");
    thumb.className = model.ok ? "thumb check" : "thumb fail";
    thumb.textContent = model.ok ? "✓" : "×";
  }

  const text = document.createElement("div");
  text.className = "text";
  const title = document.createElement("div");
  title.className = "title";
  title.textContent = model.title;
  const detail = document.createElement("div");
  detail.className = "detail";
  detail.textContent = model.detail;
  text.append(title, detail);

  card.append(thumb, text);
  root.append(style, card);
  document.documentElement.append(host);

  requestAnimationFrame(() => card.classList.add("shown"));
  setTimeout(() => {
    card.classList.remove("shown");
    setTimeout(() => host.remove(), 260);
  }, 2400);
}
