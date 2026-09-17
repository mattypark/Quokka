# The portal work, as a prompt

Two things have to exist before the App Store Connect MCP can do anything: two App IDs and an
app record. Neither is in the API — the MCP has no `apps_create` and no `provisioning_*`, and
every tool it does have takes an existing `app_id` as a required parameter.

Paste the block below into a Claude session that has Chrome access. Be signed in to both
portals first, and handle the 2FA prompt yourself — Claude will not, and should not, type a
password or a verification code.

---

```
I'm signed in to my Apple Developer account and App Store Connect in Chrome, on the team
HMU, INC. (team ID R43H5332KH). I need you to create three identifiers and one app record for
an iOS app called Quokka. Work through it in this exact order and stop at each confirmation
step to show me what you're about to submit before you submit it.

RULES
- Do not type any password, verification code, or 2FA code. If a login or 2FA screen appears,
  stop and tell me — I'll do it and tell you to continue.
- Do not accept, sign, or agree to any agreement, contract, or terms.
- Do not change any other account setting, and do not go near anything involving banking, tax,
  payments, or pricing.
- Do not submit anything for review.
- If a screen doesn't match what I've described, stop and show me a screenshot rather than
  guessing. Apple moves this UI around.

STEP 1 — the App Group (do this FIRST, the App IDs need it to already exist)
Go to developer.apple.com/account/resources/identifiers/list
Click +, choose "App Groups", Continue.
  Description: Quokka Group
  Identifier:  group.com.matthewpark.quokka
Continue, then Register.

STEP 2 — the app's App ID
Identifiers → + → "App IDs" → Continue → select type "App" → Continue.
  Description: Quokka
  Bundle ID:   Explicit →  com.matthewpark.quokka
Under Capabilities, tick "App Groups", then click its Configure / Edit button and tick
  group.com.matthewpark.quokka
Continue, then Register.

STEP 3 — the share extension's App ID
Identifiers → + → "App IDs" → Continue → select type "App" → Continue.
  Description: Quokka Share
  Bundle ID:   Explicit →  com.matthewpark.quokka.share
Under Capabilities, tick "App Groups", Configure, and tick the SAME group:
  group.com.matthewpark.quokka

This part matters more than it looks. If the two App IDs end up in different app groups, the
share extension writes into a container the app cannot read, and every save the user makes
vanishes silently with no error anywhere. Before you click Register, show me a screenshot of
the configured group on this one.

STEP 4 — the app record
Go to appstoreconnect.apple.com/apps → click the + → New App.
  Platforms:        iOS  (tick iOS only)
  Name:             Quokka
  Primary Language: English (U.S.)
  Bundle ID:        com.matthewpark.quokka   (pick it from the dropdown)
  SKU:              quokka-001
  User Access:      Full Access
Show me the filled form before you hit Create.

If Apple says the name "Quokka" is already taken, STOP. Do not invent a variation — tell me
the exact message and wait. The name is a branding decision, not a form field.

WHEN YOU'RE DONE
Report back with: the three identifiers you registered, whether the app group is attached to
both App IDs, and the Apple ID number of the new app record (the long number in the App Store
Connect URL). If anything failed, quote Apple's exact error text rather than paraphrasing it.
```

---

## What happens after

Tell the Quokka session it's done. It re-checks with `apps_search` rather than taking your
word for it, then runs the chain in [`ASC-SETUP.md`](ASC-SETUP.md) — content rights
declaration, TestFlight localization, review details, export compliance, the build upload, and
the beta group — in one pass.
