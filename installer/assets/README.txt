Place these files here before compiling DeltaErp.iss:

1. vc_redist.x64.exe (required)
   Download: https://aka.ms/vs/17/release/vc_redist.x64.exe

2. favicon.ico (optional — used only if windows\runner\resources\app_icon.ico is missing)

Build steps:
  flutter build windows --release
  Open installer\DeltaErp.iss in Inno Setup Compiler and click Compile.
  Output: installer\output\DeltaERP_Setup_1.0.0.exe

Send only the Setup.exe to the customer — they do not need the Release folder.
