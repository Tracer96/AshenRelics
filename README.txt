Ashen Relics v0.6.8-q1-strongboxes

Install:
1. Put the AshenRelics folder into Interface\AddOns\
2. Restart the client or /reload

Commands:
/ar or /ashenrelics - open the quest log
/ar complete        - debug-complete selected quest
/ar next            - select/accept the next unlocked quest
/ar reset           - reset saved Ashen Relics progress
/ar dev or /ar record - dev-only Human search location recorder
/ar beat            - dev-only story return /say point recorder
/ar dialogue        - dev-only browser for accept/progress/completion dialogue
/ar soundtest       - debug-play the Introlude WAV
/reliquary or /br   - open the Banner Reliquary

Changes in v0.6.8:
- Replaced the Introlude copy with the new Ratchet/Emberfall narration text.
- Replaced Introlude playback with one mixed WAV:
  Sounds\Ashen_Banner_Introlude_Final_Mixed_8sec_Tail.wav
- Quest 1 now requires a 15% Buccaneer's Cargo Key drop from Southsea sailors/pirates.
- Quest 1 strongbox unlocks require the key, proximity, and the Buccaneer's Strongbox tooltip.
- Unlocking a strongbox plays the search sound, kneels, stands, and awards one Moldy Shipping Manifest.
- Quest 1 strongbox progress uses a fresh saved key so old ship-cache test progress will not block new unlocks.
- Strongbox interaction buttons now appear beside the cursor with a short hover grace window.
- Strongboxes now repair mismatched saved progress if searches got ahead of actual recovered manifests, so the last box can still be opened until all 3 manifests are recovered.
- Moldy Shipping Manifest popups now show quest-style progress: 1/3, 2/3, 3/3.
- Added one-time story hover/proximity thoughts for Human search and kill quests.
- Added recorded return-point /say triggers for Human quest turn-ins.
- Added /ar beat for recording, staging, force-testing, clearing, and dumping return /say trigger points.
- Added /ar dialogue for reviewing all staged accept, progress, and completion dialogue without changing saved quest progress.
- Custom completion dialogue is saved into the quest log under an Evidence Recovered row.
- Added a crossfaded 24-frame flame overlay over the quest log crest, with an Options-panel Header Flame mover for dev positioning.
- Added quiet custom fireplace ambience while the quest log is open, plus custom page-turn and hover-click sounds for quest browsing.
- Opening the quest log no longer changes game music; only Introlude Play fades game music and game sound down, waits 1 second, then fades the mixed dialogue/music track in louder. Stop fades the custom track out and restores game audio.
- Finishing the Introlude now starts The First Trail, a short handoff quest to speak with Gazlowe in Ratchet, before A Name in the Ash begins.
- Expanded /ar dev so it can pick, record, clear, and dump every Human search location, not only Quest 1 strongboxes.
- /ar dev now shows the selected search point's clue/result text and dumps those clue fields for hardcoding.
- /ar dev now has Radius - / Radius + controls; Shift-click uses a finer step, and recorded radius changes affect live search-button testing.
- The Living Measure now flows from two failed Ratchet salvage searches, to a Suspicious Goblin interrogation, to searching the hold on his nearby skimmer for the Cracked Survey Lens.
- Added the Sputtervalve-to-Dizzywig bridge quest, Where the Paper Sleeps, before Paid Past the Road.
- Evidence popups now have a top-right X close button, and the Cracked Survey Lens no longer reveals its meaning through a loot popup.

What changed in v0.2.0:
- Rebuilt Human Relic pages to use the new QuestPageTemplate_Human TGA tiles.
- Quest text, objectives, progress counters, target names, reward names, and rep amounts are rendered with Lua.
- Target/reward icons use the new quest-specific TGAs.
- Added the new entry quest: A Name in the Ash.
- Added scrollable description text for longer quest copy.
- Removed old full text-baked quest page images from the addon package.

Changes in v0.2.1:
- Fixed Vanilla 1.12 error: FontString:GetStringHeight() is not available/reliable.
- Replaced it with a safe text-height estimate for the scrollable quest description.

Changes in v0.2.2:
- Fixed missing custom TGAs by moving them into short Vanilla-safe texture paths.
- Resized all target/reward icon TGAs to 256x256 power-of-two dimensions.
- Renamed quest page tiles to short filenames: Textures\ARPage\page_r01_c01.tga, etc.
- Updated Lua to use the short paths without file extensions.

Changes in v0.2.3:
- Re-exported custom page/icon TGAs as 24-bit RGB power-of-two textures.
- Uses explicit .tga file paths for the new custom textures.
- Uses lowercase, short filenames:
  Textures\ARPage\arpage_r01_c01.tga
  Textures\ARIcons\manifest.tga, lens.tga, meter.tga, ledger.tga, contract.tga, coin.tga, rep.tga
- Draws the quest page template on ARTWORK layer instead of BACKGROUND.
- Added /ar textures to print the exact texture paths being used.
IMPORTANT: Delete the old AshenRelics folder before installing this build. Do not merge folders.

Changes in v0.2.4:
- Fixed layering: all Lua text and icons now live on a high-level overlay frame above the tiled page template.
- Target and reward icons now use separate higher-frame icon holders.
- Icons use extensionless custom TGA paths again, matching the working custom TGA pattern.
- Added a separate red Ashen stamp overlay on the right side of the page.

Changes in v0.2.5:
- Rebuilt the dynamic page layer as a sibling frame above the TGA page template, not a child frame.
- Target/reward icons are now direct OVERLAY textures on the high-level content frame.
- Icon paths use explicit .tga again.
- /ar textures now toggles a visible manifest texture test square in the top-right of the quest page.

Changes in v0.2.6:
- Fixed crash: EstimateTextHeight nil.
- Target/reward icons now sit in high frame-level holder frames above the page template.
- Reward text now has a fallback to q.rewardRep .. " Banner Reputation".
- /ar textures also forces manifest/rep textures into the current icon slots for testing.

Changes in v0.2.7:
- Removed white/checkerboard backgrounds from target/reward icon TGAs using transparent alpha.
- Added an Options button to the main quest log.
- Added /ar options.
- Options lets you select and customize:
  Whole Quest Page, Title, Subtitle, Objective Text, Description Scroll Area,
  Target Icon, Target Text, Right Stamp, Reward Icon, Reward Text.
- Each selected piece can be moved up/down/left/right, resized, scaled, and reset.
- Layout is saved in AshenRelicsDB.layout.

Changes in v0.2.8:
- Fixed crash: SetScale nil in Vanilla 1.12.
- Options Scale+ / Scale- now resize the selected piece instead of calling SetScale.
- Kept transparent icon TGAs from v0.2.7.

Changes in v0.2.9:
- Added a Dump button to the Options panel.
- Added /ar dump to open a copyable layout dump window.
- Dump output is formatted as AR.defaultLayout code so positioning can be hardcoded later.
- Added built-in WoW themed fonts:
  Title/header use Fonts\MORPHEUS.TTF.
  Body text uses Fonts\FRIZQT__.TTF.
- No custom font files are included.

Changes in v0.3.0:
- Quest title is now left-anchored and larger.
- Subtitle is now left-anchored.
- Objective progress lines now use checkbox UI instead of dash prefixes.
- Completed objectives show a green check mark automatically when the quest is marked complete.
- /ar complete still marks the selected quest complete for testing.

Changes in v0.3.1:
- Added addon-safe quest row TGAs:
  Textures\ARRows\row.tga
  Textures\ARRows\rowsel.tga
- Row textures are 256x32 power-of-two TGAs with transparent edges.
- Quest rows now use the custom row TGA instead of a plain red rectangle.
- Removed quest numbers from the left side.
- Quest rows are right-aligned inside the left side panel.

Changes in v0.3.2:
- Fixed quest row TGA layering.
- Row TGAs now draw on ARTWORK above the left quest-log panel but below quest wording.
- Quest row frame levels were raised so the TGA is not hidden behind the sidebar art.
- Added /ar rows to force row textures visible for testing.


Changes in v0.3.3:
- Anchored left quest row TGAs to the left side of the sidebar.
- Removed the small green/gold circles on the right side of quest rows.
- Added a new Human intro/interlude entry: Listen Closely.
- Added Play and Show Text buttons for the intro narration page.
- Intro text now reveals progressively to simulate narrated quest text.
- Prepared a sound path for a future narrator WAV: Interface\AddOns\AshenRelics\Sounds\human_intro.wav

Changes in v0.3.4:
- Fixed Lua error: unfinished string near "Listen closely".
- Intro/interlude narration now uses a safe Lua long-bracket string.

Changes in v0.3.5:
- Fixed Lua 5.0 compatibility error: replaced [=[...]=] string with [[...]].
- This fixes: unexpected symbol near '[' on the intro text.

Changes in v0.3.6:
- Interlude no longer uses the quest-page TGA template. It now sits on the regular right-side parchment.
- Interlude title changed to "Introlude:".
- Added Options target: Left Quest Row TGAs.
- You can now move/resize all left-side quest row backgrounds from the Options panel.
- Default left quest row TGAs moved farther left and widened.

Changes in v0.3.7:
- Added Options target: Left Quest Row Text.
- You can now move the left-side quest names independently from the row TGA backgrounds.
- Added Options target: Introlude Body Text.
- Added Options target: Introlude Buttons.
- Moving Introlude Body Text now affects the special interlude page instead of the normal quest description layout.

Changes in v0.3.8:
- Added narrator WAV to Sounds\human_intro.wav.
- Added music WAV to Sounds\human_intro_music.wav.
- The Introlude Play button now starts both narrator voice and music together.
- The typewriter/unfold text reveal still starts at the same time.

Changes in v0.3.9:
- Text reveal speed is now based on the narrator WAV duration: about 132.2 seconds.
- The intro text auto-scrolls downward as the revealed text passes the bottom.
- Pressing Play fades down the normal in-game music while narrator/music plays.
- Normal in-game music volume is restored when the narration ends or when leaving the interlude.

Changes in v0.4.0:
- Interlude narration text area now continues much farther down the parchment.
- Auto-scroll no longer moves early; it stays at the top until the revealed text passes the visible bottom.
- During Play, the Play / Show Text buttons hide so the unfolding text has more visual room.
- Buttons reappear after narration ends.

Changes in v0.4.1:
- Interlude text area is larger and uses more of the parchment.
- Existing saved layouts are migrated so the larger interlude text box applies.
- Human quests are now gated: each quest unlocks only after the previous one is completed.
- Reading/showing the Introlude marks it complete and unlocks the first real quest.
- The Banner Reliquary no longer starts full of quest items.
- Quest item progress now comes from AshenRelicsDB.items.
- Added basic custom loot tables with all drop chances capped at 45%.
- Added custom loot window framework.
- Debug/test commands:
  /ar loot southsea
  /ar loot venture
  /ar loot bloodsail
  /ar loot hired
  /ar loot cozzle
  /ar additem manifest

Changes in v0.4.2:
- Added Stop button during Introlude playback.
- Stop cancels the text reveal and attempts to hard-stop narrator/music audio.
- Closing the quest log also cancels the Introlude playback.
- Quest log can now be closed with ESC through UISpecialFrames.
- Banner Reliquary now anchors to the right side of the quest log.
- Added Ashen Relics minimap button using the Banner/reputation icon.
- Banner Reliquary search box now filters visible relic/quest items by name.

Changes in v0.4.3:
- Fixed Lua error: missing Sound_EnableSFX CVar.
- Removed unsafe sound-channel CVar toggles.
- Backing music now uses PlayMusic, so Stop/close can stop the music with StopMusic.
- Stop/close cancels the text reveal and stops controlled music.
- Note: Vanilla 1.12 PlaySoundFile does not provide a handle to stop a specific narrator WAV once started; this build avoids crashing and stops everything the client exposes safely.

Changes in v0.4.4:
- Removed ALL sound CVar calls, including Sound_EnableSFX.
- Created Sounds\human_intro_mix.wav, a premixed narrator + music track.
- Play now uses PlayMusic on the mixed track.
- Stop and closing the quest log use StopMusic, so the full premixed narration/music can be cancelled.
- This avoids Vanilla's PlaySoundFile limitation where individual WAV sound handles cannot be stopped.

Changes in v0.4.5:
- Added custom Gazlowe dialogue window.
- Added /ar talk command. Target Gazlowe and use /ar talk to force-open the custom dialogue.
- Added GOSSIP_SHOW listener to try opening the custom dialogue automatically when talking to Gazlowe.
- Custom dialogue sends you to the next Human Relic quest if the Introlude has been read.
- Cleaned up a lingering broken sound CVar conditional.

Changes in v0.4.6:
- Gazlowe custom dialogue now attempts to open automatically when you interact with him.
- Added QUEST_GREETING and QUEST_DETAIL handling in addition to GOSSIP_SHOW.
- Added GossipFrame/QuestFrame OnShow fallback hooks for private client differences.
- Custom dialogue only appears if you are actually on the Gazlowe quest step.
- Normal WoW gossip/quest windows are hidden when the custom dialogue opens.
- /ar talk remains only as a debug fallback.

Changes in v0.4.7:
- Added Reset Quests button to the Options panel.
- Reset Quests clears quest completion, custom relic/quest items, active quest state, and refreshes the Reliquary.
- /ar reset now uses the same full reset behavior.

Changes in v0.4.8:
- Moldy Shipping Manifest now rolls from Southsea Brigand and Southsea Cannoneer deaths near Ratchet.
- Southsea Ratchet pirate loot table drops only Moldy Shipping Manifest at 45%.
- Custom loot rolls only while Paid in Advance is unlocked, incomplete, and you still need manifests.
- Added CHAT_MSG_COMBAT_HOSTILE_DEATH listener for custom loot detection.
- If no custom relic drops, the addon shows a small chat message instead of opening an empty loot window.

Changes in v0.4.9:
- Gazlowe now has quest-state dialogue:
  - first lead dialogue
  - during-manifest hunting dialogue
  - return dialogue after 3/3 manifests
- Southsea pirate kills now feel like searching bodies for evidence.
- No-drop result shows immersive flavor text instead of a loot window.
- Custom loot window now says Recovered Evidence and shows the source mob.
- Taking manifests shows evidence toasts with different clue text at 1/3, 2/3, and 3/3.
- Completing Paid in Advance adds an Evidence Note to the Banner Reliquary.
- Ratchet/Barrens flavor message added while on the manifest quest.
- Southsea Brigand and Southsea Cannoneer manifest drops remain capped at 45%.

Changes in v0.5.0:
- Added one-time private mutter lines for the Southsea manifest quest.
- One-time when close to/targeting/mousing over Southsea Brigand or Southsea Cannoneer.
- One-time when a relevant pirate does not drop evidence.
- One-time when the first manifest is picked up.
- One-time when 3/3 manifests are collected.
- Lines change slightly if a party member is nearby.
- Flavor flags reset when using Reset Quests or /ar reset.

Changes in v0.5.1:
- Adjusted Southsea mutter system to exactly three one-time moments:
  1) once when close to / targeting / mousing over the pirates
  2) once when a relevant pirate does not drop the manifest
  3) once when all 3 manifests are collected
- Removed the first-manifest pickup mutter.
- Evidence toast still appears for manifest progress, but the spoken/self-talk line no longer fires on first pickup.

Changes in v0.5.2:
- Added one-time /say line when returning to Gazlowe with all 3 manifests.
- Solo line: "I'm back. Found 'em."
- Party nearby line: "We're back. Found the manifests."
- Triggers only if Paid in Advance is active, 3/3 manifests are collected, and the quest is not complete.
- The line fires when targeting/mousing over Gazlowe or when his dialogue opens.

Changes in v0.5.3:
- Made the next Human quest, A Broker's Memory, interactive.
- Added Sputtervalve custom dialogue states:
  1) sends you after the tools
  2) changes dialogue once both tools are recovered
  3) completes the quest and unlocks the next step
- Added active quest loot gates for the next quest.
- Cracked Survey Lens drops from Southsea Privateer / Southsea Freebooter at 35%.
- Broken Brass Meter drops from Venture Co. Peon / Overseer / Enforcer / Mechanic at 35%.
- Added one-time self-talk lines for nearby next-quest mobs.
- Added one-time /say return line when approaching Sputtervalve with both tools.
- Added clue toasts when the Lens and Meter are recovered.

Changes in v0.5.4:
- Reworked A Broker's Memory so it no longer copies the first quest cadence.
- New flow: Sputtervalve -> Lens -> return to Sputtervalve -> Meter -> return to Sputtervalve -> reveal.
- Broken Brass Meter cannot drop until Sputtervalve has examined the Cracked Survey Lens.
- Removed quest-2 no-drop mutter cadence.
- Removed quest-2 proximity mutter cadence around mobs.
- Kept item pickup moments for the Lens and Meter.
- Added lens-review state saved in AshenRelicsDB.flags.
- Reset Quests now clears staged investigation flags.

Changes in v0.5.5:
- Added 7% Banner Reputation item drop chance to active custom loot tables.
- Banner Rep item can drop into the Banner Reliquary; right-click rep integration is not active yet.
- Made The Coin Trail interactive.
- Added Baron Revilgaz / Revilgaz custom dialogue states:
  1) accepts a deal and unlocks Bloodsail ledger hunting
  2) reminds you to find the stolen ledger
  3) reveals the payment route when the ledger is returned
- Blackwater Payment Ledger now drops from Bloodsail Swashbuckler, Raider, Sea Dog, Mage, and Warlock at 35%.
- Bloodsail no-drop stays quiet to avoid repeating the first quest cadence.
- Added one-time /say return line when approaching Revilgaz with the ledger.

Changes in v0.5.6:
- Made The Name Vale interactive.
- Added Marla Vale custom dialogue with a different cadence from prior quests.
- This is a social interrogation quest, not a mob drop quest.
- Three-stage dialogue:
  1) Marla denies and deflects House Vale
  2) asking about Caelan forces the payment mark reveal
  3) pressing the mark reveals Caelan's role and completes the quest
- Added one-time /say line when approaching Marla Vale.
- Added evidence toast for The Name Vale completion.

Changes in v0.5.7:
- Restored Introlude playback to start the narrator WAV and dedicated music WAV together.
- Normal in-game music is ducked with guarded music-volume CVar calls, then restored when playback stops or the addon unloads.
- Stop/close uses StopSound handles when the client provides them, and still avoids hard errors on Vanilla clients without those handles.

Changes in v0.5.8:
- Stop now fades out the Introlude narrator/music WAVs through guarded SFX volume CVars, then restores the player's sound settings.
- If a client plays WAVs without returning sound handles, Stop safely toggles the SFX channel after the fade when that CVar exists so the custom audio does not return.
- Game music is restored as soon as Stop begins, so the zone music continues while the custom audio fades away.
- Added the Ashen quest dialogue TGA atlas and rebuilt NPC quest popups to use the new artwork.
- Removed the older duplicate NPC dialogue override so Gazlowe, Sputtervalve, Revilgaz, and Marla use their staged quest dialogue again.

Changes in v0.5.9:
- Rebuilt the Ashen quest dialogue popup from 256x256 TGA tiles instead of the oversized atlas, matching the working custom texture pattern used by the quest pages.
- Moved NPC dialogue text and buttons onto a higher content frame so the tiled art cannot cover them.
- Nudged Accept Lead and Close labels upward inside their buttons.
- Introlude playback now uses the premixed narrator/music WAV on the controllable music channel so Stop and close can fade it down and call StopMusic reliably.
- After stopping the premixed track, the addon safely nudges the game music toggle so zone music can resume without enabling music for players who had it turned off.

Changes in v0.6.0:
- Rebuilt the premixed Introlude WAV from the narrator and backing-music WAVs so the controllable PlayMusic track contains both voice and music.
- Custom evidence drop chances now sit between 10% and 20%.
- Mob kills now queue searchable remains; click the dead mob target to search and roll custom evidence instead of auto-looting on death.
- Added accepted-quest gating so turn-ins do not automatically unlock the next quest; retalk to the appropriate NPC lead to accept the next step.
- Gazlowe's "I'm back" /say line can now trigger from Ratchet proximity when the manifest return is ready, not only from target/mouseover.

Changes in v0.6.1:
- Introlude playback now plays the premixed narrator/music WAV through PlaySoundFile instead of PlayMusic for older-client reliability.
- Rebalanced the premixed Introlude WAV so the backing music is louder under the narrator.
- Added quest accepted and quest completed sounds.
- Added red minimap overlays: ! for available Ashen leads, ? for turn-ins, and red objective-area hints for active mob hunts.
- Removed the corpse-search chat hint/spam; clicking the dead target is the search action.
- Gazlowe's return /say now requires close map-coordinate proximity to Gazlowe instead of firing anywhere in Ratchet.

Changes in v0.6.2:
- Quest accept and quest completion sounds are now mutually exclusive during chained dialogue handoffs.
- Stop now fades the premixed Introlude WAV and holds the SFX channel quiet until the old client would finish the no-handle WAV.
- Replaced square minimap objective areas with a circular custom TGA marker that stays clamped inside the minimap edge.
- Added hover tooltips to minimap quest markers with quest name, target name, and live objective progress.
- Added matching red !, ?, and objective-area overlays to the world map when the matching zone map is open.

Changes in v0.6.3:
- Fixed world-map stack overflow by separating minimap and world-map overlay refresh paths.
- Removed addon calls that changed Blizzard's active map while quest markers were refreshing.
- Stop now uses a short SFX-channel hold for old clients that play WAVs without returning a stoppable sound handle.

Changes in v0.6.4:
- Root cause for Introlude Stop: PlaySoundFile can play the mixed WAV, but old clients do not reliably provide a stoppable handle or fade control for it.
- The Introlude mixed track now plays on the music channel with PlayMusic so Stop can fade it out and call StopMusic.
- Stop now fades the custom Introlude music down, stops it, restarts zone music, and fades the game music back in.
- PlaySoundFile remains only as a fallback if the music-channel API is unavailable.

Changes in v0.6.5:
- Minimap quest markers no longer clamp to the edge of the minimap.
- Mob objective circles now only appear on the minimap when the actual objective area is within minimap range.
- The world map remains the place to see far-away objective areas.

Changes in v0.6.6-clarity:
- Started from the uploaded AshenRelics.zip baseline.
- Applied the Human relic quest understanding/clarity pass only.
- Rewrote Human quest log descriptions and objective text.
- Removed Reveal-style language from quest text.
- Changed vague mark language to relic/payment seal where appropriate.
- Rewrote evidence/clue toasts so each clue explains what it means.
- Clarified Gazlowe, Sputtervalve, Revilgaz, and Marla reveal dialogue.
- Did not replace the existing tiled custom dialogue texture system.
- Did not rebuild marker or texture systems.
- Follow-up audio fix: rebuilt human_intro_mix.wav with the backing music pulled farther under the narrator and kept Introlude playback on the premixed music-channel track.
- Play now fades the premixed narration/music in, while Stop/close fades the same track out before game music resumes.
- Replaced the Introlude narrator with Ashen_Banner_Introlude.wav and rebuilt the premix to the new 153.81 second duration.
- Updated the Introlude unfolding text to match the new Ashen Banner / Caelan Vale narration.
- Rebuilt the Introlude premix from Ashen_Banner_Introlude.wav plus denis-pavlov-music-suspense-dramatic-epic-dark-anxious-emotional-267044.wav, with the music layer mixed quieter beneath the narration.
- Introlude runtime audio now uses only Sounds\human_intro_mix.wav; the separate source WAVs are not played by the addon.
- Minimap quest markers now refresh continuously and re-anchor to current-zone player coordinates while the world map is closed, so turn-in ? markers stay tied to their POI.

Changes in v0.6.7-q1-search:
- Switched Play Now back to separate Vanilla-safe narrator and music-bed WAV playback with PlaySoundFile.
- Reworked the full Human relic chain around Caelan Vale, payment, guilt, and the first refusal.
- Restored Quest 1, A Name in the Ash, to three local ship record caches with no mob drops.
- Added local cache searches for The Living Measure, Paid Past the Road, The Name Vale, and The Coin Without a King.
- Reworked Cargo Under Seal to use Salt-Stained Cargo Tags from Southsea Brigands and Southsea Cannoneers.
- Reworked The Broker's Cut to use Baron Longshore, and The Contract They Burned to use Foreman Cozzle.
- Removed active objective-area minimap/world-map markers from the chain; only quest ! and ? markers are emitted.
- Added hidden dev commands /ar dev and /ar record for recording and dumping search coordinates.
- Play Now now uses only Sounds\Narration.wav and Sounds\background.wav with PlaySoundFile and prints the exact addon-relative paths.
- /ar soundtest plays the same two files directly for path/format testing.
- Stop now fades the sound-effect volume using Vanilla-era CVars, including SoundVolume, so no-handle PlaySoundFile WAVs can be muted and held after fade-out.
- Quest 1 search spots now use tiny per-spot 2D map radii, ignore subzones, and the recorder shows live distance/inside-radius debug text.
- Quest 1 ship search no longer adds an objective-area minimap/world-map marker; only normal quest !/? markers remain.
