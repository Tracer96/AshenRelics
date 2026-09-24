Ashen Relics 0.7.6 Copy Editor Patch

Changes:
- Relic whispers fire 30 seconds after receiving the specific relic.
- First relic whisper also prints: "Oh my dog, is this item speaking to me? Am I hearing things?"
- Added /dev dialogue as a dialogue/copy browser.
- In /dev dialogue:
  - Edit NPC edits the current NPC dialogue title/subtitle/button/body.
  - Edit Quest edits the related quest title/subtitle/objective lines/description/target/reward copy.
  - Dump opens a copy/paste window containing all saved edits.
- Saved edits are stored in AshenRelicsDB.copyEdits and survive /reload.
- Saved edits are runtime overrides, not physical edits to AshenRelics.lua. Use Dump to send the edited copy to be hardcoded.

Commands:
/dev dialogue
/dev dump
/ar copydump
/ar editquest 3
