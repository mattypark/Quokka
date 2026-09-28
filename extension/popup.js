// The toolbar popup: save the current page, and see what is waiting to reach the phone.
//
// Every string from a saved page goes in with textContent and every URL is re-checked with
// isWebURL before it becomes an <img src> or a tab -- the queue is data from arbitrary
// websites, not something to trust.

import { hostOf, isWebURL, remove } from "./lib/record.js";

const QUEUE_KEY = "queue";
const SHOWN = 120;

const grid = document.getElementById("grid");
const empty = document.getElementById("empty");
const count = document.getElementById("count");
const savePage = document.getElementById("save-page");
const clear = document.getElementById("clear");

let armedToClear = false;

async function readQueue() {
  const stored = await chrome.storage.local.get(QUEUE_KEY);
  return Array.isArray(stored[QUEUE_KEY]) ? stored[QUEUE_KEY] : [];
}

function kindLabel(record) {
  switch (record.kind) {
    case "image":
      return "Image";
    case "video":
      return "Video";
    case "link":
      return "Link";
    case "text":
      return "Text";
    default:
      return "Page";
  }
}

function tileFor(record) {
  const item = document.createElement("li");
  const tile = document.createElement("button");
  tile.type = "button";
  tile.className = "tile";

  const target = [record.rawURL, record.pageURL].find(isWebURL);
  tile.setAttribute("aria-label", record.pageTitle || hostOf(target ?? "") || "Saved item");
  if (target) {
    tile.addEventListener("click", () => chrome.tabs.create({ url: target }));
  }

  if (record.kind === "image" && isWebURL(record.srcURL)) {
    const image = document.createElement("img");
    image.src = record.srcURL;
    image.alt = "";
    image.loading = "lazy";
    image.referrerPolicy = "no-referrer";
    tile.append(image);
  } else {
    const card = document.createElement("span");
    card.className = "card";

    const kind = document.createElement("span");
    kind.className = "kind";
    kind.textContent = kindLabel(record);

    const title = document.createElement("span");
    title.className = "title";
    title.textContent =
      record.kind === "text" ? `“${record.rawText}”` : record.pageTitle ?? record.rawURL ?? "";

    const host = document.createElement("span");
    host.className = "host";
    host.textContent = hostOf(target ?? "");

    card.append(kind, title, host);
    tile.append(card);
  }

  const removeButton = document.createElement("button");
  removeButton.type = "button";
  removeButton.className = "remove";
  removeButton.textContent = "×";
  removeButton.setAttribute("aria-label", "Remove");
  removeButton.addEventListener("click", async (event) => {
    event.stopPropagation();
    const queue = await readQueue();
    await chrome.storage.local.set({ [QUEUE_KEY]: remove(queue, record.id) });
  });

  item.append(tile, removeButton);
  return item;
}

function render(queue) {
  grid.replaceChildren(...queue.slice(0, SHOWN).map(tileFor));
  empty.hidden = queue.length > 0;
  clear.disabled = queue.length === 0;
  count.textContent =
    queue.length === 0 ? "" : queue.length === 1 ? "1 waiting" : `${queue.length} waiting`;
}

savePage.addEventListener("click", async () => {
  savePage.disabled = true;
  const result = await chrome.runtime.sendMessage({ type: "save-page" });
  savePage.textContent = result?.ok
    ? result.duplicate
      ? "Already saved"
      : "Saved"
    : "Can’t save this page";
  setTimeout(() => {
    savePage.textContent = "Save this page";
    savePage.disabled = false;
  }, 1400);
});

// Two taps, not a confirm() dialog: a dialog would block the popup, and clearing the queue
// is the one thing here that cannot be taken back.
clear.addEventListener("click", async () => {
  if (!armedToClear) {
    armedToClear = true;
    clear.textContent = "Tap again to clear";
    setTimeout(() => {
      armedToClear = false;
      clear.textContent = "Clear all";
    }, 2500);
    return;
  }
  armedToClear = false;
  clear.textContent = "Clear all";
  await chrome.storage.local.set({ [QUEUE_KEY]: [] });
});

chrome.storage.onChanged.addListener((changes, area) => {
  if (area === "local" && changes[QUEUE_KEY]) render(changes[QUEUE_KEY].newValue ?? []);
});

render(await readQueue());
