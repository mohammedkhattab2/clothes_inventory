# Activation Code Command

Use this command when a user sends you their device Machine Hash from the activation screen.

Important:
- The script expects Machine Hash (not Machine Code).
- PRIVATE_KEY_BASE64 must be your secret signing key.

## PowerShell

$env:PRIVATE_KEY_BASE64="zEsK/4F+Q+1kFCW14t0yrDrUAr5HzQOgBl+HDdTTTC8="
dart run tool/generate_license.dart "18ae31bcd09b450b31543c8789bc5fdaa0791520b46b4ee984bc6362d8f5c832" "ElBorHamy" "LIC-2026-002" "2027-04-10T23:59:59Z"

## Example

$env:PRIVATE_KEY_BASE64="YOUR_REAL_PRIVATE_KEY"
dart run tool/generate_license.dart "9a1f0f2c3d4e5f6a7b8c9d0e1f2a3b4c" "Shop A" "LIC-2026-001" "2027-04-10T23:59:59Z"

Output:
- The command prints a JSON activation code.
- Send that JSON to the customer to paste into the activation page.
