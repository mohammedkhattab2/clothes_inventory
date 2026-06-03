# Activation Code Command

Use this command when a user sends you their device Machine Hash from the activation screen.

Important:
- The script expects Machine Hash (not Machine Code).
- PRIVATE_KEY_BASE64 must be your secret signing key.
- License duration in the commands below: **10 years** (`expiresAt` = 2036-05-17 UTC). Adjust the last argument for other durations.

## PowerShell

$env:PRIVATE_KEY_BASE64="zEsK/4F+Q+1kFCW14t0yrDrUAr5HzQOgBl+HDdTTTC8="
dart run tool/generate_license.dart "5ffe30a8b64970bf0a25e73c3bac4ba673573e3ca77ca3c62b98573a3de0bfe2" "ElBorHamy" "LIC-2026-002" "2036-05-17T23:59:59Z"

## Example

$env:PRIVATE_KEY_BASE64="YOUR_REAL_PRIVATE_KEY"
dart run tool/generate_license.dart "9a1f0f2c3d4e5f6a7b8c9d0e1f2a3b4c" "Shop A" "LIC-2026-001" "2036-05-17T23:59:59Z"

Output:
- The command prints a JSON activation code.
- Send that JSON to the customer to paste into the activation page.
