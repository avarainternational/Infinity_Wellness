# AI Workflow Rules

Read `AGENTS.md` and the context files that apply to each change. Verify runtime claims against code and tests. Keep architecture, product language, UI, and implementation status in their owning context files.

Preserve the GetX base/view/binding pattern and public Wallet SDK boundary. Do not treat presentation prototypes as live transactions. Keep source SDK protocol identifiers and protected-storage keys intact unless a separate migration is approved. Never put real keys, seeds, signed payloads, or private account data in the repository.

Run `flutter pub get`, `flutter analyze`, and `flutter test` independently; format changed Dart files. Build a native artifact when platform configuration changes. Record unverified device or release gates explicitly.
