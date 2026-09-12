# Loopless signage assets: offline redistribution audit

Audit date: 2026-08-17. This record covers only resources added for the ThaiLife loopless signage reference page. It is an audit trail, not legal advice.

## Fonts

The unmodified static TTF files were retrieved from the official Google Fonts CDN. Google Fonts metadata identifies the exact regular face names and the upstream source repositories. Both families are licensed under SIL Open Font License 1.1 (OFL-1.1). OFL-1.1 expressly permits the font software to be embedded and bundled with software when each copy carries the copyright notice and license. The complete license text is bundled beside each font at the paths below.

| Asset | Source | Version / retrieval date | License and offline redistribution evidence | PostScript name | SHA-256 |
|---|---|---|---|---|---|
| `Fonts/Sarabun-Regular.ttf` | Official Google Fonts CDN: https://fonts.gstatic.com/s/sarabun/v17/DtVjJx26TKEr37c9WBI.ttf; Google Fonts metadata: https://fonts.google.com/metadata/fonts/Sarabun; upstream repository https://github.com/cadsondemak/Sarabun at commit `854cdb6afaf002ff8c2ce6aa7b86f99c7f71c9eb` | CDN v17; Google Fonts catalog lastModified 2025-09-11; retrieved 2026-08-17 | SIL OFL 1.1; full text in `Fonts/LICENSE-Sarabun.txt`; OFL condition 2 permits bundling with software | `Sarabun-Regular` | `5c9d6412daf0096c19356366746e0e5af10efe5f93dad67e0f76b38369310ffa` |
| `Fonts/Prompt-Regular.ttf` | Official Google Fonts CDN: https://fonts.gstatic.com/s/prompt/v12/-W__XJnvUD7dzB26Zw.ttf; Google Fonts metadata: https://fonts.google.com/metadata/fonts/Prompt; upstream repository https://github.com/cadsondemak/prompt at commit `18f813a4dea16a7ecc6f944053d3ce2cd4d7e824` | CDN v12; Google Fonts catalog lastModified 2025-09-02; retrieved 2026-08-17 | SIL OFL 1.1; full text in `Fonts/LICENSE-Prompt.txt`; OFL condition 2 permits bundling with software | `Prompt-Regular` | `3a78595458f626e22fe9f800df463c80c1d8f3e69ea1b590754de1a3c3c0dc6c` |

## Scene illustrations

The previous generic placeholder illustrations did not contain the Thai sign text and therefore could not support reading practice. They have been replaced by the five text-bearing scene images already used by the project-owned teaching document `15-泰语广告招牌与无头艺术字对照表.md`. Each asset preserves the exact teaching context described by that document.

| Asset | Source and creation method | Version / retrieval date | License | Required attribution | SHA-256 |
|---|---|---|---|---|---|
| `LooplessSignage/milk-tea.png` | Existing project teaching asset: `/Users/yaohuix/ai_quant/quant_ai_web/docs/thai-learning/images/thai_cafe_signboard.jpg` | Imported 2026-08-17 | Provided inside the project learning material for ThaiLife reuse | ThaiLife teaching material | `674a9d1235f1cc3d50a00fc87ecce325c56dc89ca8b6b78102bd07cf3dee906f` |
| `LooplessSignage/discount.png` | Existing project teaching asset: `/Users/yaohuix/ai_quant/quant_ai_web/docs/thai-learning/images/thai_store_discount.jpg` | Imported 2026-08-17 | Provided inside the project learning material for ThaiLife reuse | ThaiLife teaching material | `26fd2bd0d1a0f3c809186713421cbc4d45e35a6cacb45d6ab895e79800027d1d` |
| `LooplessSignage/open-close.png` | Existing project teaching asset: `/Users/yaohuix/ai_quant/quant_ai_web/docs/thai-learning/images/thai_open_closed.jpg` | Imported 2026-08-17 | Provided inside the project learning material for ThaiLife reuse | ThaiLife teaching material | `9e1bebadeb23c95ac3186d1dcbd15cf16bffb3f5b3e179d6910090904201cada` |
| `LooplessSignage/pharmacy.png` | Existing project teaching asset: `/Users/yaohuix/ai_quant/quant_ai_web/docs/thai-learning/images/thai_pharmacy_sign.jpg` | Imported 2026-08-17 | Provided inside the project learning material for ThaiLife reuse | ThaiLife teaching material | `1ba6680f8f3e1165b2fa51138e8db68d61e597a02cd4638b2b81f13adb2ddefb` |
| `LooplessSignage/station-exit.png` | Existing project teaching asset: `/Users/yaohuix/ai_quant/quant_ai_web/docs/thai-learning/images/thai_station_exit.jpg` | Imported 2026-08-17 | Provided inside the project learning material for ThaiLife reuse | ThaiLife teaching material | `714bfa2bb72856865f12ffaea37242425ba9e75b8c6295d59e60f4dfa0020511` |

## Verification evidence

- `file` reports both font files as TrueType Font data and all five scene files as PNG image data.
- `fc-scan` reports `Sarabun-Regular` and `Prompt-Regular` as the PostScript names.
- The SHA-256 values above were computed from the current repository bytes on the audit date.
- The Xcode target bundles the `Fonts`, `LooplessSignage`, and `Attributions` folder references. The generated app Info.plist registers `Sarabun-Regular.ttf` and `Prompt-Regular.ttf` through `UIAppFonts`.
