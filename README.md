# Kraken MoneyMoney Extension (fork)

This repository is a **fork** of:
https://github.com/aaronk6/Kraken-MoneyMoney

The original project appears to be unmaintained. This fork stays intentionally close
to upstream and only fixes real-world breakage observed in 2025/2026 (stability and
asset-transition handling).

## 🔐 MoneyMoney signing status

> **Status: Unsigned extension**
>
> This extension is currently **not signed by MoneyMoney**.
> When installing it, MoneyMoney will display a security warning and ask you to
> explicitly allow the extension. This is expected for community forks.
>
> Only the MoneyMoney developer can sign extensions. A signing request may be
> submitted after some real-world usage.

This repository contains a **MoneyMoney** extension to import **Kraken** balances and value them in **EUR**.

It is a fork of a community extension that is no longer maintained upstream. This fork focuses on being **stable** and **boring**.

## What's different in this fork

### ✅ Fix: Missing `WebBanking{}` registration block (v1.12)

The fork was missing the `WebBanking{...}` block that MoneyMoney requires to recognise
a Lua file as a valid extension. This caused the error:

> *„Für diese Bank ist keine Web-Scraping-Unterstützung vorhanden."*

Also fixed in the same pass:
- `apiVersion`, `url` and `currency` variables were undefined
- `AccountTypePortfolio` was used as a bare identifier instead of the required string `"AccountTypePortfolio"`

### ✅ Fix: Kraken / Cloudflare `HTTP 520`

Some users hit `HTTP 520` (often Cloudflare) because the extension requested a **massive** ticker list.
This fork changes the ticker selection so it only requests pairs that are **actually needed** for assets you hold.

### ✅ EOS → Vaulta (A) / `AEUR` handling

Kraken's EOS→Vaulta situation (and Germany/DLT restrictions) can lead to balances/valuation placeholders such as `AEUR`.
This fork:

- labels `A` as **"Vaulta (A)"**
- treats `AEUR` as **EUR-like (1:1)** for valuation purposes (so your portfolio doesn't "vanish")

> Note: `AEUR` is treated as EUR-like **for display/valuation only**. Kraken may restrict trading/withdrawal.

## Installation (MoneyMoney on macOS)

1. Download the Lua file: `Kraken.lua`
2. Open **MoneyMoney** → **Help** → **Show Database in Finder**
3. Copy the Lua file into:
   - `MoneyMoney/Extensions/`  
     (create the folder if it does not exist)
4. Restart MoneyMoney
5. Add a new account:
   - **Type:** "Kraken Account"
   - **Username:** Kraken API Key
   - **Password:** Kraken API Secret

### Recommended Kraken API key permissions

- `Query Funds` (required)
- (Optional) `Query Ledger Entries` if you later extend it to fetch transactions  
  No trading or withdrawal permissions are needed.

**Note:** MoneyMoney will show a warning because the extension is **unsigned**. Confirm the prompt to enable it.

## Troubleshooting

### "Für diese Bank ist keine Web-Scraping-Unterstützung vorhanden."

Make sure you are using `Kraken.lua` from this repo at version 1.12 or later.

### Still getting HTTP 520?

- Confirm you are running the forked Lua file, not the old one.
- If you hold many assets and still see issues, we can add chunking for the ticker requests.

### "0 price" / missing valuation

- Kraken sometimes uses alternative pair names (e.g. `XBT` vs `XXBT` style prefixes).
- Open an issue with:
  - the asset code shown in MoneyMoney
  - the pair that is missing (if you can find it in Kraken's UI / API)

## Development

This is a single-file MoneyMoney extension.

PRs welcome:

- Better asset/pair normalisation (Kraken's aliases can be… creative)
- Optional "ticker chunking" for very large portfolios
- Optional transaction import

## Credits

- Original community extension authors (see Git history / original repo)
- This fork: Vaulta/AEUR and HTTP 520 stability fixes, missing WebBanking{} block fix

## License

MIT — see [LICENSE](LICENSE).
