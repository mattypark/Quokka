# Save to Quokka

A Chrome extension that works like Cosmos's "Save to Cosmos": right-click anything on the web
and choose **Save to Quokka**.

- **Images, links, videos, selected text and whole pages**, from the right-click menu.
- **The toolbar popup** saves the current page and shows everything saved so far, as the same
  two-column grid the app uses.
- **Alt+Shift+S** saves the current page.

A small card confirms each save on the page itself. It lives in a closed shadow root, so it
cannot restyle the page or be restyled by it.

## Where saves go

**Nowhere yet.** They wait in this browser (`chrome.storage.local`, up to 5,000) until a way to
reach the phone is chosen. The two candidates are in `docs/DECISIONS.md`. Each record already
has the share extension's inbox shape, so the sync only has to carry it.

## Install (unpacked)

1. Open `chrome://extensions` (in Comet, `comet://extensions`).
2. Turn on **Developer mode**.
3. Click **Load unpacked** and pick this `extension/` folder.
4. Pin Quokka from the puzzle-piece menu so the popup is one click away.

## Test

```sh
cd extension && npm test        # node --test, no dependencies
```

## Files

| | |
|---|---|
| `manifest.json` | MV3. `contextMenus`, `storage`, `activeTab`, `scripting` -- no host permissions |
| `background.js` | The service worker: menu, shortcut, popup message, one save path |
| `lib/record.js` | Pure: builds and validates a record, dedupes the queue. Tested |
| `lib/toast.js` | The on-page confirmation. Self-contained, because `executeScript` serialises it |
| `popup.*` | The toolbar popup |
| `icons/` | Rendered by `scripts/render-icon.swift`, the same mark as the app icon |

`activeTab` is granted by the click that triggers a save, which is why the extension needs no
access to any site until someone uses it there.
