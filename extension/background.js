// Save to Quokka -- the service worker.
//
// Three ways in, one path through: the right-click menu, the toolbar popup's "Save this
// page", and Alt+Shift+S. Each builds a record, puts it at the front of the local queue, and
// shows a confirmation on the page.
//
// The queue stays in this browser until a sync path to the phone exists (see
// docs/DECISIONS.md). Nothing is sent anywhere.

import { buildRecord, enqueue, hostOf } from "./lib/record.js";
import { showToast } from "./lib/toast.js";

const MENU_ID = "save-to-quokka";
const QUEUE_KEY = "queue";

chrome.runtime.onInstalled.addListener(() => {
  // removeAll first: onInstalled also fires on update, and creating an id that already
  // exists is an error.
  chrome.contextMenus.removeAll(() => {
    chrome.contextMenus.create({
      id: MENU_ID,
      title: "Save to Quokka",
      contexts: ["image", "link", "page", "selection", "video"],
    });
  });
});

chrome.contextMenus.onClicked.addListener((info, tab) => {
  if (info.menuItemId === MENU_ID) save(info, tab);
});

chrome.commands.onCommand.addListener((command, tab) => {
  if (command === "save-page") save({ pageUrl: tab?.url }, tab);
});

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.type !== "save-page") return false;
  chrome.tabs
    .query({ active: true, currentWindow: true })
    .then(([tab]) => save({ pageUrl: tab?.url }, tab))
    .then(sendResponse, (error) => sendResponse({ ok: false, error: String(error) }));
  // Keeps the channel open for the async response.
  return true;
});

async function save(info, tab) {
  const record = buildRecord(info, tab);
  if (!record) {
    await confirm(tab, {
      ok: false,
      title: "Nothing to save here",
      detail: "Quokka saves web pages, links, images and text.",
    });
    return { ok: false };
  }

  const stored = await chrome.storage.local.get(QUEUE_KEY);
  const { queue, duplicate } = enqueue(stored[QUEUE_KEY], record);
  await chrome.storage.local.set({ [QUEUE_KEY]: queue });

  await confirm(tab, {
    ok: true,
    image: record.kind === "image" ? record.srcURL : null,
    title: duplicate ? "Already saved — moved to the top" : "Saved to Quokka",
    detail: record.pageTitle ?? hostOf(record.rawURL ?? ""),
  });
  return { ok: true, record, duplicate };
}

/**
 * Shows the card on the page, or falls back to a badge where pages cannot be scripted --
 * chrome:// pages, the Web Store, PDFs. activeTab is granted by the click that got us here,
 * so no host permission is needed for the normal case.
 */
async function confirm(tab, model) {
  if (tab?.id !== undefined) {
    try {
      await chrome.scripting.executeScript({
        target: { tabId: tab.id },
        func: showToast,
        args: [model],
      });
      return;
    } catch {
      // Unscriptable page. Fall through to the badge.
    }
  }
  await chrome.action.setBadgeBackgroundColor({ color: model.ok ? "#0A0A0A" : "#6B6B6B" });
  await chrome.action.setBadgeText({ text: model.ok ? "✓" : "×" });
  setTimeout(() => chrome.action.setBadgeText({ text: "" }), 2000);
}
