--[[
Ashen Relics v0.7.5-whisper-30s
Vanilla WoW 1.12 / Lua 5.0 addon

Commands:
  /ar or /ashenrelics       - Toggle quest log
  /ar complete              - Debug-complete selected quest
  /ar reset                 - Reset Ashen Relics saved progress
  /ar talk                  - Debug fallback: force custom dialogue for targeted NPC
  /ar dev or /ar record     - Dev-only Human search location recorder
  /ar soundtest             - Debug-play the Introlude WAV
  /ar rows                  - Force row textures for testing
  Play Now button           - Starts the mixed narrator/music WAV
  /reliquary or /br         - Toggle Banner Reliquary

This build uses:
- Large quest log frame tiles from the original Ashen Relics UI.
- New dynamic Human quest page template TGA tiles.
- Lua-rendered quest copy, objectives, target names, rewards, and progress counters.
- Per-quest target icon TGAs.
]]

AshenRelicsDB = AshenRelicsDB or {}

local AR = {}
AR.frames = {}
AR.activeCategory = 1
AR.activeQuest = 1
AR.pendingMobSearches = {}

AR.coreBase = "Interface\\AddOns\\AshenRelics\\Textures\\Core\\AshenRelics_TGA_Assets_256\\"
AR.pageBase = "Interface\\AddOns\\AshenRelics\\Textures\\ARPage\\"
AR.iconBase = "Interface\\AddOns\\AshenRelics\\Textures\\ARIcons\\"
AR.rowBase = "Interface\\AddOns\\AshenRelics\\Textures\\ARRows\\"
AR.dialogueBase = "Interface\\AddOns\\AshenRelics\\Textures\\Dialogue\\"
AR.questOverlayBase = "Interface\\AddOns\\AshenRelics\\Textures\\QuestOverlay\\"
AR.flameBase = "Interface\\AddOns\\AshenRelics\\Textures\\FlameEmblemClean\\"
AR.headerFlameFrameCount = 24
AR.headerFlameFrameDuration = 0.115
AR.headerFlameAlpha = 0.64

AR.assets = {
  main = { base=AR.coreBase, folder="ashen_relics_main_frame", prefix="ashen_relics_main_frame", w=1092, h=1161, cols=5, rows=5 },
  bag  = { base=AR.coreBase, folder="banner_reliquary_frame", prefix="banner_reliquary_frame", w=959, h=1343, cols=4, rows=6 },
  cats = {
    human    = { base=AR.coreBase, folder="human_relics_category", prefix="human_relics_category", w=1919, h=322, cols=8, rows=2 },
    dwarven  = { base=AR.coreBase, folder="dwarven_relics_category", prefix="dwarven_relics_category", w=1846, h=307, cols=8, rows=2 },
    nightelf = { base=AR.coreBase, folder="night_elf_relics_category", prefix="night_elf_relics_category", w=1839, h=275, cols=8, rows=2 },
    gnome    = { base=AR.coreBase, folder="gnome_relics_category", prefix="gnome_relics_category", w=1822, h=299, cols=8, rows=2 },
    orc      = { base=AR.coreBase, folder="orc_relics_category", prefix="orc_relics_category", w=1851, h=315, cols=8, rows=2 },
    troll    = { base=AR.coreBase, folder="troll_relics_category", prefix="troll_relics_category", w=1785, h=302, cols=7, rows=2 },
    tauren   = { base=AR.coreBase, folder="tauren_relics_category", prefix="tauren_relics_category", w=1703, h=299, cols=7, rows=2 },
  },
  pageTemplateHuman = {
    base=AR.pageBase,
    folder="",
    prefix="arpage",
    w=1086,
    h=1448,
    cols=5,
    rows=6,
    naming="plain"
  },
  dialogue = { base=AR.dialogueBase, folder="AshenQuestDialogue_256", prefix="ashen_dialogue", w=1321, h=951, cols=6, rows=4, naming="plain" },
  close = AR.coreBase .. "ashen_close_button\\ashen_close_button_256",
  arrowRight = AR.coreBase .. "ashen_arrow_right\\ashen_arrow_right_256",
  arrowLeft  = AR.coreBase .. "ashen_arrow_left\\ashen_arrow_left_256",
}

AR.icons = {
  manifest = AR.iconBase .. "manifest.tga",
  lens = AR.iconBase .. "lens.tga",
  meter = AR.iconBase .. "meter.tga",
  ledger = AR.iconBase .. "ledger.tga",
  contract = AR.iconBase .. "contract.tga",
  coinArtifact = AR.iconBase .. "coin.tga",
  rep = AR.iconBase .. "rep.tga",
  stamp = AR.iconBase .. "stamp.tga",
  cargoKey = "Interface\\Icons\\INV_Misc_Key_03",
}

AR.rowTextures = {
  normal = AR.rowBase .. "row.tga",
  selected = AR.rowBase .. "rowsel.tga",
}

AR.questOverlayTextures = {
  areaCircle = AR.questOverlayBase .. "area_circle.tga",
}

AR.introNarrationPath = "Interface\\AddOns\\AshenRelics\\Sounds\\Ashen_Banner_Introlude_Final_Mixed_8sec_Tail.wav"
AR.introMusicPath = ""
AR.introNarrationEnabled = 1
AR.introMusicEnabled = 0
AR.questAcceptSoundPath = "Interface\\AddOns\\AshenRelics\\Sounds\\quest_accept.wav"
AR.questCompleteSoundPath = "Interface\\AddOns\\AshenRelics\\Sounds\\quest_complete.wav"
AR.searchSoundPath = "Sound\\Interface\\PickUp\\PickUpParchment_Paper.wav"
AR.searchSoundFallback = "igBackPackOpen"
AR.fireplaceLoopSoundPath = "Interface\\AddOns\\AshenRelics\\Sounds\\flame_10s_loop.wav"
AR.fireplaceLoopSeconds = 10.0
AR.pageTurnSoundPath = "Interface\\AddOns\\AshenRelics\\Sounds\\page_flip.wav"
AR.questHoverSoundPath = "Interface\\AddOns\\AshenRelics\\Sounds\\click_21156.wav"
AR.introNarrationSeconds = 145.25
AR.introCharsPerSecond = 13
AR.introMusicFadeSeconds = 1.5
AR.introGameMusicFadeInSeconds = 1.5
AR.introDuckedGameMusicVolume = 0.08
AR.introStopFadeSeconds = 1.25
AR.introMusicChannelVolume = 1.0
AR.introStartDelaySeconds = 0
AR.introStartFadeSeconds = 0

AR.whisperBase = "Interface\\AddOns\\AshenRelics\\Sounds\\Whispers\\"
AR.relicWhisperMinDelay = 30
AR.relicWhisperMaxDelay = 30
AR.relicWhisperDelaySeconds = 30
AR.relicWhisperEnabledDefault = 1
AR.relicWhispers = {
  {
    key="manifest",
    itemName="Moldy Shipping Manifest",
    requiredCount=3,
    sound=AR.whisperBase .. "manifest_whisper.wav",
    line="The supplies were waiting for us before the contract ink had dried, tools for a road no honest map had named.",
  },
  {
    key="lens",
    itemName="Cracked Survey Lens",
    sound=AR.whisperBase .. "lens_whisper.wav",
    line="I remember holding it to the light and realizing the road was not being discovered. It was being followed.",
  },
  {
    key="meter",
    itemName="Broken Brass Meter",
    sound=AR.whisperBase .. "meter_whisper.wav",
    line="That brass thing never cared for north or south. It only trembled when we drew closer to what someone had hidden from us.",
  },
  {
    key="continuation_ledger",
    itemName="Blackwater Payment Ledger",
    sound=AR.whisperBase .. "ledger_whisper.wav",
    line="The numbers were too clean. Whoever paid for our new beginning had counted the cost long before we named our price.",
  },
  {
    key="contract",
    itemName="Burned Contract Scrap",
    sound=AR.whisperBase .. "contract_whisper.wav",
    line="We signed for work, for coin, for escape. None of us understood that a promise could be made to carry more than words.",
  },
  {
    key="coin",
    itemName="The Coin Without a King",
    sound=nil,
    line="No crown marked the coin in my palm, yet it weighed like command. Someone had bought the road without ever showing their face.",
  },
}

AR.minimapPOIs = {
  gazlowe = { zone="The Barrens", map="TheBarrens", x=0.625, y=0.367, label="Gazlowe" },
  sputtervalve = { zone="The Barrens", map="TheBarrens", x=0.628, y=0.371, label="Sputtervalve" },
  dizzywig = { zone="The Barrens", map="TheBarrens", x=0.626, y=0.384, label="Wharfmaster Dizzywig" },
  revilgaz = { zone="Stranglethorn Vale", map="Stranglethorn", x=0.274, y=0.770, label="Baron Revilgaz" },
  southseaRatchet = { zone="The Barrens", map="TheBarrens", x=0.625, y=0.485, radius=0.035, label="Southsea Pirates" },
  longshore = { zone="The Barrens", map="TheBarrens", x=0.628, y=0.492, radius=0.024, label="Baron Longshore" },
  cozzle = { zone="Stranglethorn Vale", map="Stranglethorn", x=0.433, y=0.205, radius=0.030, label="Foreman Cozzle" },
  ventureBarrens = { zone="The Barrens", map="TheBarrens", x=0.585, y=0.435, radius=0.035, label="Venture Co. Salvage" },
  bloodsailBooty = { zone="Stranglethorn Vale", map="Stranglethorn", x=0.288, y=0.705, radius=0.040, label="Bloodsail Pirates" },
}

AR.humanQ1SearchSpots = {
  -- NOTE: Ship interiors are still 2D map coordinates in Vanilla.
  -- Do not place vertically stacked ship spots at the same X/Y. Vanilla Lua
  -- cannot distinguish deck height. Strongbox hover text is also required.
  [1] = {
    name="Buccaneer's Strongbox 1",
    zone="The Barrens",
    x=64.96,
    y=45.50,
    radius=0.0024,
    buttonText="Unlock Strongbox",
    tooltipName="Buccaneer's Strongbox",
    tooltipHelp="Use the Buccaneer's Cargo Key on this strongbox.",
    requiredItemKey="cargo_key",
    itemKey="manifest",
    resultTitle="Moldy Shipping Manifest recovered. 1/3",
    resultBody="The strongbox opens to a packet of old cargo copies. The route marks a paid expedition shipment leaving Ratchet under sealed orders.",
  },
  [2] = {
    name="Buccaneer's Strongbox 2",
    zone="The Barrens",
    x=65.07,
    y=45.45,
    radius=0.0024,
    buttonText="Unlock Strongbox",
    tooltipName="Buccaneer's Strongbox",
    tooltipHelp="Use the Buccaneer's Cargo Key on this strongbox.",
    requiredItemKey="cargo_key",
    itemKey="manifest",
    resultTitle="Moldy Shipping Manifest recovered. 2/3",
    resultBody="This copy lists ordinary expedition stores: tools, lantern oil, spare braces, and sealed crates. The packing reads like a real journey, but several entries are copied too thinly to explain what was actually sealed.",
  },
  [3] = {
    name="Buccaneer's Strongbox 3",
    zone="The Barrens",
    x=64.94,
    y=45.45,
    radius=0.0038,
    buttonText="Unlock Strongbox",
    tooltipName="Buccaneer's Strongbox",
    tooltipHelp="Use the Buccaneer's Cargo Key on this strongbox.",
    requiredItemKey="cargo_key",
    itemKey="manifest",
    resultTitle="Moldy Shipping Manifest recovered. 3/3",
    resultBody="The ledger's first lead was true: Emberfall passed through Ratchet as paid work, and the payer is still hidden.",
  },
}

AR.humanQ1ThirdManifestFallbackRadius = 0.0065

AR.humanQ1ManifestResults = {
  [1] = {
    title="Moldy Shipping Manifest recovered. 1/3",
    body="The strongbox opens to a packet of old cargo copies. The route marks a paid expedition shipment leaving Ratchet under sealed orders.",
  },
  [2] = {
    title="Moldy Shipping Manifest recovered. 2/3",
    body="This copy lists ordinary expedition stores: tools, lantern oil, spare braces, and sealed crates. The packing reads like a real journey, but several entries are copied too thinly to explain what was actually sealed.",
  },
  [3] = {
    title="Moldy Shipping Manifest recovered. 3/3",
    body="The ledger's first lead was true: Emberfall passed through Ratchet as paid work, and the payer is still hidden.",
  },
}

AR.humanQ1KeyMobs = {
  "Southsea Sailor",
  "Southsea Brigand",
  "Southsea Cannoneer",
  "Southsea Buccaneer",
  "Southsea Privateer",
  "Southsea Freebooter",
}

AR.humanLocalSearchSpots = {
  living_measure_cache = {
    questIndex=5,
    itemKey="lens",
    noAutoAward=1,
    searchGroup="living_measure_salvage",
    name="Ratchet Salvage Pile",
    zone="The Barrens",
    x=62.91,
    y=38.56,
    radius=0.002,
    buttonText="Search Salvage Pile",
    tooltipHelp="Search the salvage for a surviving Emberfall lens.",
    resultTitle="No lens here.",
    resultBody="Bent brackets, salt-scored bolts, broken housings... but no calibrated glass. Someone picked the useful pieces clean before you arrived.",
  },
  living_measure_dockside_salvage = {
    questIndex=5,
    itemKey="lens",
    noAutoAward=1,
    searchGroup="living_measure_salvage",
    name="Ratchet Salvage Pile",
    zone="The Barrens",
    x=62.88,
    y=37.43,
    radius=0.002,
    buttonText="Search Salvage Pile",
    tooltipHelp="Search the Ratchet salvage for a surviving Emberfall lens.",
    resultTitle="No lens here.",
    resultBody="Another stripped salvage pile. Someone kept the shiny pieces and left the useless weight behind.",
  },
  living_measure_skimmer_hold = {
    questIndex=5,
    itemKey="lens",
    requiresFlag="livingMeasureGoblinRevealed",
    name="Goblin Skimmer Hold",
    zone="The Barrens",
    x=64.68,
    y=45.06,
    radius=0.0018,
    buttonText="Search Skimmer Hold",
    tooltipHelp="Search the hold on the goblin's skimmer for the Cracked Survey Lens.",
    resultTitle="Cracked Survey Lens recovered.",
    resultBody="The cracked lens is wrapped in oily cloth beneath a coil of rope. Fine marks score the rim in careful intervals. This was not made to survey land.",
  },
  continuation_ledger = {
    questIndex=7,
    itemKey="continuation_ledger",
    name="Old Renewal Records",
    zone="The Barrens",
    x=62.45,
    y=38.20,
    radius=0.006,
    buttonText="Search Renewal Records",
    tooltipHelp="Search the old harbor renewal records.",
    resultTitle="Blackwater Payment Ledger recovered.",
    resultBody="The entries continue after Emberfall's departure. The coin moved through careful hands, but the source stayed buried.",
    toastTitle="Blackwater Payment Ledger recovered.",
    toastBody="The coin kept moving after the ships did. The strange part is how much the payer already knew.",
  },
  vale_mark = {
    questIndex=9,
    itemKey="vale_mark",
    name="Blackwater Exchange Records",
    zone="Stranglethorn Vale",
    x=27.55,
    y=77.10,
    radius=0.008,
    buttonText="Search Exchange Records",
    tooltipHelp="Search the Booty Bay exchange records.",
    resultTitle="Unmarked Guarantor Seal recovered.",
    resultBody="A scraped guarantor seal appears beside Emberfall's hidden payments. The name is missing, but the seal made the shipment look clean.",
    toastTitle="Unmarked Guarantor Seal recovered.",
    toastBody="Someone with standing helped make Emberfall look proper before anyone asked why it needed cover.",
  },
  final_coin_cache = {
    questIndex=11,
    itemKey="coin",
    name="Final Emberfall Cache",
    zone="The Barrens",
    x=64.96,
    y=45.50,
    radius=0.006,
    buttonText="Search Final Cache",
    tooltipHelp="Search the final Emberfall cache.",
    resultTitle="The Coin Without a King recovered.",
    resultBody="The face has been cut away. No crown mark, no house seal, no trade stamp. Whoever paid for Emberfall made sure the coin could not point home.",
    toastTitle="Human Relic recovered: The Coin Without a King.",
    toastBody="No crown, no house, no honest owner. The hand behind Emberfall stayed hidden.",
  },
}

AR.humanLocalSearchOrder = {
  "living_measure_cache",
  "living_measure_dockside_salvage",
  "living_measure_skimmer_hold",
  "continuation_ledger",
  "vale_mark",
  "final_coin_cache",
}

AR.storyReturnBeats = {
  {
    id="q2_gazlowe_manifest_return",
    label="Gazlowe: Strongbox Return",
    questIndex=3,
    poiKey="gazlowe",
    readyType="humanQ1",
    radius=0.004,
    saySolo="Gazlowe, I'm back. These records prove Emberfall passed through Ratchet, but they raise more questions than answers.",
    sayParty="Gazlowe, we're back. These records prove Emberfall passed through Ratchet, but they raise more questions than answers.",
  },
  {
    id="q3_gazlowe_tags_return",
    label="Gazlowe: Cargo Tag Return",
    questIndex=4,
    poiKey="gazlowe",
    itemKey="cargo_tag",
    itemCount=4,
    radius=0.004,
    saySolo="Gazlowe, I brought the cargo tags. Most of this looks normal, except these marks.",
    sayParty="Gazlowe, we brought the cargo tags. Most of this looks normal, except these marks.",
  },
  {
    id="q4_sputtervalve_lens_return",
    label="Sputtervalve: Lens Return",
    questIndex=5,
    poiKey="sputtervalve",
    itemKey="lens",
    itemCount=1,
    radius=0.004,
    saySolo="Sputtervalve, I found the lens. I do not like the marks on it.",
    sayParty="Sputtervalve, we found the lens. I do not like the marks on it.",
  },
  {
    id="q5_dizzywig_sputtervalve_return",
    label="Dizzywig: Sputtervalve Lead",
    questIndex=6,
    poiKey="dizzywig",
    radius=0.004,
    saySolo="Dizzywig, Sputtervalve sent me. The lens points to more work after Emberfall left Ratchet.",
    sayParty="Dizzywig, Sputtervalve sent us. The lens points to more work after Emberfall left Ratchet.",
  },
  {
    id="q5_dizzywig_ledger_return",
    label="Dizzywig: Ledger Return",
    questIndex=7,
    poiKey="dizzywig",
    itemKey="continuation_ledger",
    itemCount=1,
    radius=0.004,
    saySolo="Dizzywig, I found the renewal records. The payments kept going after Emberfall left.",
    sayParty="Dizzywig, we found the renewal records. The payments kept going after Emberfall left.",
  },
  {
    id="q6_gazlowe_longshore_return",
    label="Gazlowe: Longshore Return",
    questIndex=8,
    poiKey="gazlowe",
    itemKey="broker_cut_ledger",
    itemCount=1,
    radius=0.004,
    saySolo="Gazlowe, Longshore had a ledger scrap. I cannot tell what it means yet.",
    sayParty="Gazlowe, Longshore had a ledger scrap. We cannot tell what it means yet.",
  },
  {
    id="q7_revilgaz_vale_return",
    label="Revilgaz: Guarantor Return",
    questIndex=9,
    poiKey="revilgaz",
    itemKey="vale_mark",
    itemCount=1,
    radius=0.004,
    saySolo="Revilgaz, I found the guarantor seal in the exchange records.",
    sayParty="Revilgaz, we found the guarantor seal in the exchange records.",
  },
  {
    id="q8_gazlowe_contract_return",
    label="Gazlowe: Contract Return",
    questIndex=10,
    poiKey="gazlowe",
    itemKey="contract",
    itemCount=1,
    radius=0.004,
    saySolo="Gazlowe, the contract scrap survived. Some of this does not read like goblin paperwork.",
    sayParty="Gazlowe, the contract scrap survived. Some of this does not read like goblin paperwork.",
  },
  {
    id="q9_gazlowe_coin_return",
    label="Gazlowe: Coin Return",
    questIndex=11,
    poiKey="gazlowe",
    itemKey="coin",
    itemCount=1,
    radius=0.004,
    saySolo="Gazlowe, I found the coin. It feels like it was left to be found.",
    sayParty="Gazlowe, we found the coin. It feels like it was left to be found.",
  },
}

AR.storyHoverBeats = {
  {
    id="q2_southsea_key_hover",
    questIndex=3,
    readyType="humanQ1Key",
    names=AR.humanQ1KeyMobs,
    lineSolo='"Ah. Southsea hands. One of them has to have the cargo key."',
    lineParty='"Southsea hands. One of them has to have the cargo key."',
  },
  {
    id="q3_southsea_tag_hover",
    questIndex=4,
    itemKey="cargo_tag",
    itemCount=4,
    names={ "Southsea Brigand", "Southsea Cannoneer" },
    lineSolo='"If Emberfall cargo washed ashore, these thieves would have kept the marks."',
    lineParty='"If Emberfall cargo washed ashore, these thieves would have kept the marks."',
  },
  {
    id="q4_suspicious_goblin_hover",
    questIndex=5,
    readyType="livingMeasureGoblin",
    names={ "Suspicious Goblin" },
    lineSolo='"That goblin keeps watching the salvage. Badly."',
    lineParty='"That goblin keeps watching the salvage. Badly."',
  },
  {
    id="q6_longshore_hover",
    questIndex=8,
    itemKey="broker_cut_ledger",
    itemCount=1,
    names={ "Baron Longshore" },
    lineSolo='"There. A captain who would keep proof if proof could become coin."',
    lineParty='"There. A captain who would keep proof if proof could become coin."',
  },
  {
    id="q8_cozzle_hover",
    questIndex=10,
    itemKey="contract",
    itemCount=1,
    names={ "Foreman Cozzle" },
    lineSolo='"Cozzle. If anyone kept burned paper for profit, it would be him."',
    lineParty='"Cozzle. If anyone kept burned paper for profit, it would be him."',
  },
}

AR.storyAreaBeats = {
  {
    id="q2_southsea_key_area",
    questIndex=3,
    readyType="humanQ1Key",
    poiKey="southseaRatchet",
    lineSolo='"They have to be around here. Southsea crews, stolen keys, old cargo."',
    lineParty='"They have to be around here. Southsea crews, stolen keys, old cargo."',
  },
  {
    id="q3_southsea_tag_area",
    questIndex=4,
    itemKey="cargo_tag",
    itemCount=4,
    poiKey="southseaRatchet",
    lineSolo='"Stolen crates, stamped slats, cargo tags. Emberfall should have left a mark here."',
    lineParty='"Stolen crates, stamped slats, cargo tags. Emberfall should have left a mark here."',
  },
  {
    id="q4_lens_area",
    questIndex=5,
    itemKey="lens",
    itemCount=1,
    localSpotKey="living_measure_cache",
    lineSolo='"Salvage piles. If the lens survived, someone stripped it down here."',
    lineParty='"Salvage piles. If the lens survived, someone stripped it down here."',
  },
  {
    id="q5_ledger_area",
    questIndex=7,
    itemKey="continuation_ledger",
    itemCount=1,
    localSpotKey="continuation_ledger",
    lineSolo='"Old docks, old debts. This is where paper survives."',
    lineParty='"Old docks, old debts. This is where paper survives."',
  },
  {
    id="q6_longshore_area",
    questIndex=8,
    itemKey="broker_cut_ledger",
    itemCount=1,
    poiKey="longshore",
    lineSolo="\"The broker's cut has to be close. Longshore would not let proof drift far.\"",
    lineParty="\"The broker's cut has to be close. Longshore would not let proof drift far.\"",
  },
  {
    id="q7_vale_area",
    questIndex=9,
    itemKey="vale_mark",
    itemCount=1,
    localSpotKey="vale_mark",
    lineSolo='"This is where clean signatures hide dirty cargo."',
    lineParty='"This is where clean signatures hide dirty cargo."',
  },
  {
    id="q8_cozzle_area",
    questIndex=10,
    itemKey="contract",
    itemCount=1,
    poiKey="cozzle",
    lineSolo='"The contract has to be near him. Burned paper still leaves ash."',
    lineParty='"The contract has to be near him. Burned paper still leaves ash."',
  },
  {
    id="q9_coin_area",
    questIndex=11,
    itemKey="coin",
    itemCount=1,
    localSpotKey="final_coin_cache",
    lineSolo='"Back where the trail began. Caelyn wanted this found."',
    lineParty='"Back where the trail began. Caelyn wanted this found."',
  },
}

AR.devDialogueScenarios = {
  { label="The First Trail - Completion", kind="Completion", npc="Gazlowe", completed={1}, accepted={2} },
  { label="The Prepared Road - Accept", kind="Accept", npc="Gazlowe", completed={1,2} },
  { label="The Prepared Road - Progress", kind="Progress", npc="Gazlowe", completed={1,2}, accepted={3} },
  { label="The Prepared Road - Completion", kind="Completion", npc="Gazlowe", completed={1,2}, accepted={3}, items={cargo_key=1, manifest=3}, q1Searches=1 },
  { label="Cargo Under Seal - Accept", kind="Accept", npc="Gazlowe", completed={1,2,3} },
  { label="Cargo Under Seal - Progress", kind="Progress", npc="Gazlowe", completed={1,2,3}, accepted={4} },
  { label="Cargo Under Seal - Completion", kind="Completion", npc="Gazlowe", completed={1,2,3}, accepted={4}, items={cargo_tag=4} },
  { label="The Surveyor's Glass - Accept", kind="Accept", npc="Sputtervalve", completed={1,2,3,4} },
  { label="The Surveyor's Glass - Progress", kind="Progress", npc="Sputtervalve", completed={1,2,3,4}, accepted={5} },
  { label="The Surveyor's Glass - Goblin Page 1", kind="Clue", npc="Suspicious Goblin", completed={1,2,3,4}, accepted={5}, localSearches={living_measure_cache=1,living_measure_dockside_salvage=1}, flags={livingMeasureGoblinStage=1} },
  { label="The Surveyor's Glass - Goblin Page 2", kind="Clue", npc="Suspicious Goblin", completed={1,2,3,4}, accepted={5}, localSearches={living_measure_cache=1,living_measure_dockside_salvage=1}, flags={livingMeasureGoblinStage=2} },
  { label="The Surveyor's Glass - Goblin Page 3", kind="Clue", npc="Suspicious Goblin", completed={1,2,3,4}, accepted={5}, localSearches={living_measure_cache=1,living_measure_dockside_salvage=1}, flags={livingMeasureGoblinStage=3} },
  { label="The Surveyor's Glass - Skimmer Hold Open", kind="Progress", npc="Suspicious Goblin", completed={1,2,3,4}, accepted={5}, localSearches={living_measure_cache=1,living_measure_dockside_salvage=1}, flags={livingMeasureGoblinRevealed=1} },
  { label="The Surveyor's Glass - Completion", kind="Completion", npc="Sputtervalve", completed={1,2,3,4}, accepted={5}, items={lens=1} },
  { label="Where the Paper Sleeps - Accept", kind="Accept", npc="Sputtervalve", completed={1,2,3,4,5} },
  { label="Where the Paper Sleeps - Completion", kind="Completion", npc="Wharfmaster Dizzywig", completed={1,2,3,4,5}, accepted={6} },
  { label="Paid Past the Road - Accept", kind="Accept", npc="Wharfmaster Dizzywig", completed={1,2,3,4,5,6} },
  { label="Paid Past the Road - Progress", kind="Progress", npc="Wharfmaster Dizzywig", completed={1,2,3,4,5,6}, accepted={7} },
  { label="Paid Past the Road - Completion", kind="Completion", npc="Wharfmaster Dizzywig", completed={1,2,3,4,5,6}, accepted={7}, items={continuation_ledger=1} },
  { label="The Broker's Cut - Accept", kind="Accept", npc="Gazlowe", completed={1,2,3,4,5,6,7} },
  { label="The Broker's Cut - Progress", kind="Progress", npc="Gazlowe", completed={1,2,3,4,5,6,7}, accepted={8} },
  { label="The Broker's Cut - Completion", kind="Completion", npc="Gazlowe", completed={1,2,3,4,5,6,7}, accepted={8}, items={broker_cut_ledger=1} },
  { label="The Guarantor's Mark - Accept", kind="Accept", npc="Baron Revilgaz", completed={1,2,3,4,5,6,7,8} },
  { label="The Guarantor's Mark - Progress", kind="Progress", npc="Baron Revilgaz", completed={1,2,3,4,5,6,7,8}, accepted={9} },
  { label="The Guarantor's Mark - Completion", kind="Completion", npc="Baron Revilgaz", completed={1,2,3,4,5,6,7,8}, accepted={9}, items={vale_mark=1} },
  { label="The Contract They Burned - Accept", kind="Accept", npc="Gazlowe", completed={1,2,3,4,5,6,7,8,9} },
  { label="The Contract They Burned - Progress", kind="Progress", npc="Gazlowe", completed={1,2,3,4,5,6,7,8,9}, accepted={10} },
  { label="The Contract They Burned - Completion", kind="Completion", npc="Gazlowe", completed={1,2,3,4,5,6,7,8,9}, accepted={10}, items={contract=1} },
  { label="The Coin Without a King - Accept", kind="Accept", npc="Gazlowe", completed={1,2,3,4,5,6,7,8,9,10} },
  { label="The Coin Without a King - Progress", kind="Progress", npc="Gazlowe", completed={1,2,3,4,5,6,7,8,9,10}, accepted={11} },
  { label="The Coin Without a King - Completion", kind="Completion", npc="Gazlowe", completed={1,2,3,4,5,6,7,8,9,10}, accepted={11}, items={coin=1} },
}

AR.categories = {
  { key="human",    title="Human Relics",     expanded=true },
  { key="dwarven",  title="Dwarven Relics",   expanded=false },
  { key="nightelf", title="Night Elf Relics", expanded=false },
  { key="gnome",    title="Gnome Relics",     expanded=false },
  { key="orc",      title="Orc Relics",       expanded=false },
  { key="troll",    title="Troll Relics",     expanded=false },
  { key="tauren",   title="Tauren Relics",    expanded=false },
}

AR.quests = {
  human = {
    {
      id="human_intro",
      title="Introlude:",
      subtitle="History is not always buried by time.",
      objectiveText="",
      objectives={},
      description=[[Before I speak of the Ashen Banner, understand this: history is not always buried by time.

Sometimes, it is buried by those who fear what the truth would awaken.

The Banner remembers its beginning as a promise made by broken people who chose to stand together when the world expected them to remain enemies.

Over time, that promise became more than words. It became a people. It became halls filled with song, names carved into stone, and empty seats kept for the founders who never returned.

Their absence became tradition.

Their silence became part of the story.

But silence is not the same as peace.

An old ledger has surfaced in Ratchet, hidden among harbor records, cargo claims, and debts no one living should have remembered. Most of its pages are ruined by salt, rot, and age... but one name survived.

Emberfall.

An expedition.

Not a legend. Not a victory. Not a tale sung beside the fire.

A Mystery.

An unknown voyage.

Filed through the hands of merchants and captains, then buried beneath ordinary ink, where no one would think to look.

The ledger does not tell us what Emberfall was.

It only proves that someone wanted it discovered.

And worse...

it points to things left behind.

Fragments. Marks. Objects touched by the founders before they vanished from the world they helped create.

If those relics still remain, then they are more than old keepsakes.

They are witnesses.

They may remember what the centuries forgot.

They may remember what the founders feared.

They may remember how Emberfall became more than an expedition... and why,

after raising the Ashen Banner,

The founders vanished without farewell.

Now the first page has opened.

The first trail leads to Ratchet.

And somewhere beneath salt, ash, and silence, the truth is waiting to be found.

Find what survived.

Follow what it remembers.

And uncover what the Banner was...

before it became a banner at all.]],
      targetName="",
      targetLocation="",
      targetIcon=nil,
      rewardName="",
      rewardDetail="",
      rewardRep=0,
      rewardIcon=nil,
      rewardType="interlude",
      isInterlude=1,
    },
    {
      id="human_intro_to_gazlowe",
      title="The First Trail",
      subtitle="The ledger points to Ratchet.",
      objectiveText="Speak with Gazlowe in Ratchet.",
      objectives={
        { text="Speak with Gazlowe", required=1, flagKey="gazlowe_intro_handoff_complete" },
      },
      description=[[The ledger points to Ratchet? Hah. Makes sense.

A lot of shady business gets done here, but good coin moves just as fast if you know how to move it.

Emberfall's an interesting stamp. I haven't heard of it before, but I know one thing: if Emberfall passed through here at any point, somebody knows something about it.

Ratchet is a city of history. Old papers turn into coin quicker than rum and ale.]],
      targetName="Gazlowe",
      targetLocation="Ratchet, The Barrens",
      targetIcon=AR.icons.ledger,
      rewardName="10 Banner Reputation",
      rewardDetail="First lead carried to Ratchet",
      rewardRep=10,
      rewardIcon=AR.icons.rep,
      rewardType="standard",
    },
    {
      id="human_00",
      title="The Prepared Road",
      subtitle="The ledger gave us a port, a lock, and a road prepared too carefully.",
      objectiveText="Recover a Buccaneer's Cargo Key from Southsea sailors, then unlock three Buccaneer's Strongboxes aboard the Ratchet trade vessel.",
      objectives={
        { text="Buccaneer's Cargo Key", required=1, itemKey="cargo_key" },
        { text="Moldy Shipping Manifest", required=3, humanQ1Searches=1 },
      },
      description=[[Gazlowe says your best bet is old shipping records. Most are a mess: half-truths, fake weights, missing crates, and anything else that turns cost into profit.

But if Emberfall passed through Ratchet, the Southsea sailors likely had something to do with it. They keep an old trade vessel south of town, and Gazlowe remembers lockboxes down in the lower hold, toward the back, where guarded records and cargo marks tend to disappear.

Find a Buccaneer's Cargo Key from one of the Southsea sailors, then unlock three Buccaneer's Strongboxes aboard the old trade vessel.]],
      targetName="Buccaneer's Cargo Key / Moldy Shipping Manifest",
      targetLocation="Southsea sailors and Ratchet Trade Vessel, The Barrens",
      targetIcon=AR.icons.manifest,
      rewardName="25 Banner Reputation",
      rewardDetail="First lead proven",
      rewardRep=25,
      rewardIcon=AR.icons.rep,
      rewardType="standard",
    },
    {
      id="human_01",
      title="Cargo Under Seal",
      subtitle="The cargo was ordinary only at a glance.",
      objectiveText="Recover 4 Salt-Stained Cargo Tags from Southsea Brigands and Southsea Cannoneers along the Merchant Coast.",
      objectives={
        { text="Salt-Stained Cargo Tag", required=4, itemKey="cargo_tag" },
      },
      description=[[The manifest proves Emberfall passed through Ratchet, but it does not tell us what the ships carried.

Goblins copy manifests because cargo can become debt. Pirates steal cargo because debt can become ransom. If Emberfall moved sealed crates through this coast, then someone along the Merchant Coast may still have a tag, a crate slat, or a stolen record they never understood.

Search the Southsea camps south of Ratchet. Do not look for treasure. Look for anything marked with Emberfall's seal.

The first record proved the expedition was real. The cargo may prove how carefully it was prepared.]],
      targetName="Salt-Stained Cargo Tag",
      targetLocation="Southsea camps along the Merchant Coast",
      targetIcon=AR.icons.manifest,
      rewardName="75 Banner Reputation",
      rewardDetail="Human Relic progress",
      rewardRep=75,
      rewardIcon=AR.icons.rep,
      rewardType="standard",
    },
    {
      id="human_02",
      title="The Surveyor's Glass",
      subtitle="Some tools are made to find what maps leave out.",
      objectiveText="Search salvage around Ratchet and recover the Cracked Survey Lens.",
      objectives={
        { text="Cracked Survey Lens", required=1, itemKey="lens" },
      },
      description=[[Gazlowe sends you to Sputtervalve, who knows machines, gauges, and goblin measuring habits well enough to know when a tool was built for the wrong job.

The cargo tags point to a calibrated survey lens packed with the Emberfall supplies. That would be ordinary enough, if not for the marks described around the rim.

Search salvage around Ratchet for the lens or anything still carrying those calibration marks. A normal survey lens helps chart new ground. This one may have been made to recognize a road already chosen.]],
      targetName="Cracked Survey Lens",
      targetLocation="Ratchet salvage piles",
      targetIcon=AR.icons.lens,
      rewardName="75 Banner Reputation",
      rewardDetail="Human Relic progress",
      rewardRep=75,
      rewardIcon=AR.icons.rep,
      rewardType="standard",
    },
    {
      id="human_02_to_dizzywig",
      title="Where the Paper Sleeps",
      subtitle="Instruments leave records somewhere.",
      objectiveText="Speak with Wharfmaster Dizzywig in Ratchet.",
      objectives={
        { text="Speak with Wharfmaster Dizzywig", required=1, flagKey="dizzywig_handoff_complete" },
      },
      description=[[Sputtervalve can tell you what the cracked lens was built to recognize, but instruments like that do not work alone. They leave handling notes, calibration changes, replacement parts, and paper trails.

If Emberfall was guided after it left Ratchet, then the trail should have continued through the harbor paperwork.

Sputtervalve sends you to Wharfmaster Dizzywig. If anyone knows where old continuation records sleep, it is the goblin paid to remember dock business.]],
      targetName="Wharfmaster Dizzywig",
      targetLocation="Ratchet, The Barrens",
      targetIcon=AR.icons.ledger,
      rewardName="25 Banner Reputation",
      rewardDetail="Lead carried to the wharfmaster",
      rewardRep=25,
      rewardIcon=AR.icons.rep,
      rewardType="standard",
    },
    {
      id="human_03",
      title="Paid Past the Road",
      subtitle="The coin kept moving after the ships did.",
      objectiveText="Search the old renewal records near Ratchet's docks and recover the Blackwater Payment Ledger.",
      objectives={
        { text="Blackwater Payment Ledger", required=1, itemKey="continuation_ledger" },
      },
      description=[[The first payment sent Emberfall out of Ratchet. The next question is not whether the gold was real. It was.

The question is why the payments continued after the expedition was already moving.

Wharfmaster Dizzywig keeps dock business moving, and dock business remembers what people would rather forget. If more payments followed Emberfall after departure, then someone was still guiding the road from behind ledgers and intermediaries.

Find the Blackwater Payment Ledger.]],
      targetName="Blackwater Payment Ledger",
      targetLocation="Old renewal records near Ratchet's docks",
      targetIcon=AR.icons.ledger,
      rewardName="75 Banner Reputation",
      rewardDetail="Human Relic progress",
      rewardRep=75,
      rewardIcon=AR.icons.rep,
      rewardType="standard",
    },
    {
      id="human_04",
      title="The Broker's Cut",
      subtitle="The middlemen remembered the gold.",
      objectiveText="Kill Baron Longshore and recover the Broker's Cut Ledger.",
      objectives={
        { text="Broker's Cut Ledger", required=1, itemKey="broker_cut_ledger" },
      },
      description=[[The money did not move cleanly. It passed through hands that knew how to make coin forget where it came from.

Gazlowe believes one of the Southsea captains took a broker's cut from the Emberfall payments. If Baron Longshore kept even a fragment of that record, it may prove the goblins were only the middlemen.

Kill Baron Longshore and recover whatever payment record he kept.]],
      targetName="Baron Longshore / Broker's Cut Ledger",
      targetLocation="Merchant Coast near Ratchet",
      targetIcon=AR.icons.ledger,
      rewardName="75 Banner Reputation",
      rewardDetail="Human Relic progress",
      rewardRep=75,
      rewardIcon=AR.icons.rep,
      rewardType="standard",
    },
    {
      id="human_05",
      title="The Guarantor's Mark",
      subtitle="A clean seal can make dirty cargo look honest.",
      objectiveText="Search the Booty Bay exchange records and recover the Unmarked Guarantor Seal.",
      objectives={
        { text="Unmarked Guarantor Seal", required=1, itemKey="vale_mark" },
      },
      description=[[The payment trail leaves Ratchet and points toward Booty Bay, where larger debts find deeper shadows.

A guarantor mark appears beside sealed transit, legal cover, and human-backed approval. The name has been scraped away, but the purpose is clear enough.

Someone with standing helped make Emberfall look legitimate.

That does not prove the founders knew the truth. It proves someone wanted the expedition to look clean before anyone asked why it needed cover.]],
      targetName="Unmarked Guarantor Seal",
      targetLocation="Booty Bay exchange records",
      targetIcon=AR.icons.ledger,
      rewardName="75 Banner Reputation",
      rewardDetail="Human Relic progress",
      rewardRep=75,
      rewardIcon=AR.icons.rep,
      rewardType="standard",
    },
    {
      id="human_06",
      title="The Contract They Burned",
      subtitle="Some promises outlive the paper that carried them.",
      objectiveText="Kill Foreman Cozzle in Stranglethorn Vale and recover the Burned Contract Scrap.",
      objectives={
        { text="Burned Contract Scrap", required=1, itemKey="contract" },
      },
      description=[[The ledgers prove payment. The instruments prove observation. The guarantor seal proves human cover.

But the contract will prove purpose.

At first, the contract may look like wages and protection. Read deeper. The old words often hide the sharpest hooks.]],
      targetName="Foreman Cozzle / Burned Contract Scrap",
      targetLocation="Stranglethorn Vale",
      targetIcon=AR.icons.contract,
      rewardName="75 Banner Reputation",
      rewardDetail="Human Relic progress",
      rewardRep=75,
      rewardIcon=AR.icons.rep,
      rewardType="standard",
    },
    {
      id="human_07",
      title="The Coin Without a King",
      subtitle="No seal. No crown. No honest owner.",
      objectiveText="Search the final Emberfall cache in Ratchet and recover the Coin Without a King.",
      objectives={
        { text="The Coin Without a King recovered", required=1, itemKey="coin" },
      },
      description=[[The contract proves Emberfall was more than hired work, but it still does not name the hand behind it.

Gazlowe has one last lead: an old coin passed through pirate hands, broker hands, and goblin hands, always tied to Emberfall records that should have had nothing to do with one another.

No crown mark. No house seal. No trade stamp. Nothing that points home.

Somewhere near the first Ratchet records, the coin was hidden where only someone following the whole paper trail would think to look.

Find the coin.]],
      targetName="Final Emberfall Cache",
      targetLocation="Ratchet records",
      targetIcon=AR.icons.coinArtifact,
      rewardName="The Coin Without a King",
      rewardDetail="100 Banner Reputation",
      rewardRep=100,
      rewardIcon=AR.icons.coinArtifact,
      rewardType="artifact",
    },
  },
  dwarven = {},
  nightelf = {},
  gnome = {},
  orc = {},
  troll = {},
  tauren = {},
}

AR.itemDefs = {
  cargo_key = { name="Buccaneer's Cargo Key", texture=AR.icons.cargoKey, kind="Quest Key" },
  manifest = { name="Moldy Shipping Manifest", texture=AR.icons.manifest, kind="Quest Item" },
  meter = { name="Broken Brass Meter", texture=AR.icons.meter, kind="Quest Item" },
  cargo_tag = { name="Salt-Stained Cargo Tag", texture=AR.icons.manifest, kind="Quest Item" },
  lens = { name="Cracked Survey Lens", texture=AR.icons.lens, kind="Quest Item" },
  continuation_ledger = { name="Blackwater Payment Ledger", texture=AR.icons.ledger, kind="Quest Item" },
  broker_cut_ledger = { name="Broker's Cut Ledger", texture=AR.icons.ledger, kind="Quest Item" },
  vale_mark = { name="Unmarked Guarantor Seal", texture=AR.icons.ledger, kind="Quest Item" },
  contract = { name="Burned Contract Scrap", texture=AR.icons.contract, kind="Quest Item" },
  coin = { name="The Coin Without a King", texture=AR.icons.coinArtifact, kind="Artifact" },
  rep = { name="Banner Reputation", texture=AR.icons.rep, kind="Reputation" },
}

AR.itemNameToKey = {
  ["Buccaneer's Cargo Key"] = "cargo_key",
  ["Moldy Shipping Manifest"] = "manifest",
  ["Salt-Stained Cargo Tag"] = "cargo_tag",
  ["Cracked Survey Lens"] = "lens",
  ["Blackwater Payment Ledger"] = "continuation_ledger",
  ["Broken Brass Meter"] = "meter",
  ["Continuation Ledger"] = "continuation_ledger",
  ["Broker's Cut Ledger"] = "broker_cut_ledger",
  ["Unmarked Guarantor Seal"] = "vale_mark",
  ["Vale Guarantor Mark"] = "vale_mark",
  ["Burned Contract Scrap"] = "contract",
  ["The Coin Without a King"] = "coin",
  ["The Coin Without a King recovered"] = "coin",
}

AR.lootTables = {
  q1_sailor_key = {
    title="Southsea Sailor's Pouch",
    drops={
      { key="cargo_key", chance=15, exactChance=1 },
    },
  },
  southsea = {
    title="Southsea Pirate Remains",
    drops={
      { key="cargo_tag", chance=15 },
      { key="rep", chance=10 },
    },
  },
  southsea_ratchet = {
    title="Southsea Pirate Remains",
    drops={
      { key="cargo_tag", chance=15 },
      { key="rep", chance=10 },
    },
  },
  cozzle = {
    title="Cozzle's Emberfall Papers",
    drops={
      { key="contract", chance=100, exactChance=1 },
      { key="rep", chance=10 },
    },
  },
  longshore = {
    title="Baron Longshore's Ledger",
    drops={
      { key="broker_cut_ledger", chance=100, exactChance=1 },
      { key="rep", chance=10 },
    },
  },
}

AR.reliquaryItems = {}
AR.mobLootTables = {
  ["Southsea Brigand"] = "southsea_ratchet",
  ["Southsea Cannoneer"] = "southsea_ratchet",

  -- The Broker's Cut
  ["Baron Longshore"] = "longshore",

  -- The Contract They Burned
  ["Foreman Cozzle"] = "cozzle",
}


local function Max(a, b)
  if a > b then return a end
  return b
end

local function Min(a, b)
  if a < b then return a end
  return b
end

local function Clamp(value, low, high)
  if value < low then return low end
  if value > high then return high end
  return value
end

local function CoreTilePath(asset, row, col)
  return asset.base .. asset.folder .. "\\" .. asset.prefix .. "_tile_r" .. string.format("%02d", row) .. "_c" .. string.format("%02d", col)
end

local function PlainTilePath(asset, row, col)
  local name = asset.prefix .. "_r" .. string.format("%02d", row) .. "_c" .. string.format("%02d", col) .. ".tga"
  if asset.folder and asset.folder ~= "" then
    return asset.base .. asset.folder .. "\\" .. name
  end
  return asset.base .. name
end

local function AddTileGrid(parent, asset, displayW, displayH, layer)
  local sx = displayW / asset.w
  local sy = displayH / asset.h
  local tiles = {}
  local r, c
  for r = 1, asset.rows do
    for c = 1, asset.cols do
      local origW = 256
      local origH = 256
      if c == asset.cols then origW = asset.w - ((c - 1) * 256) end
      if r == asset.rows then origH = asset.h - ((r - 1) * 256) end
      if origW > 0 and origH > 0 then
        local f = CreateFrame("Frame", nil, parent)
        f:SetWidth(origW * sx)
        f:SetHeight(origH * sy)
        f:SetPoint("TOPLEFT", parent, "TOPLEFT", ((c - 1) * 256) * sx, -((r - 1) * 256) * sy)
        local t = f:CreateTexture(nil, layer or "BACKGROUND")
        t:SetAllPoints(f)
        if asset.naming == "plain" then
          t:SetTexture(PlainTilePath(asset, r, c))
        t:SetBlendMode("BLEND")
        else
          t:SetTexture(CoreTilePath(asset, r, c))
        t:SetBlendMode("BLEND")
        end
        t:SetTexCoord(0, origW / 256, 0, origH / 256)
        f.tex = t
        table.insert(tiles, f)
      end
    end
  end
  return tiles
end

local function MakeFont(parent, template, x, y, w, h, color)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontNormalSmall")
  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  fs:SetWidth(w)
  fs:SetHeight(h)
  fs:SetJustifyH("LEFT")
  fs:SetJustifyV("TOP")
  if color then fs:SetTextColor(color.r, color.g, color.b) end
  return fs
end

local function SetDarkText(fs)
  fs:SetTextColor(0.08, 0.055, 0.035)
end

local function SetHeaderText(fs)
  fs:SetTextColor(0.28, 0.025, 0.02)
end

local function SetGoldText(fs)
  fs:SetTextColor(0.90, 0.66, 0.22)
end

function AR:GetQuestList(catKey)
  return AR.quests[catKey] or {}
end

function AR:GetQuestKey(catKey, questIndex)
  return catKey .. ":" .. questIndex
end

function AR:IsQuestComplete(catKey, questIndex)
  local q = AR:GetQuestList(catKey)[questIndex]
  if not q then return nil end
  return AshenRelicsDB.completed and AshenRelicsDB.completed[q.id]
end

function AR:IsQuestAccepted(catKey, questIndex)
  if questIndex <= 1 then return 1 end
  local q = AR:GetQuestList(catKey)[questIndex]
  if not q then return nil end
  if AR:IsQuestComplete(catKey, questIndex) then return 1 end
  return AshenRelicsDB.accepted and AshenRelicsDB.accepted[q.id]
end

function AR:SetQuestAccepted(catKey, questIndex, accepted)
  local q = AR:GetQuestList(catKey)[questIndex]
  if not q then return end
  if not AshenRelicsDB.accepted then AshenRelicsDB.accepted = {} end
  if accepted then
    AshenRelicsDB.accepted[q.id] = 1
  else
    AshenRelicsDB.accepted[q.id] = nil
  end
end

function AR:AcceptQuest(catKey, questIndex, silent)
  local wasAccepted = AR:IsQuestAccepted(catKey, questIndex)
  AR:SetQuestAccepted(catKey, questIndex, 1)
  if not silent and not wasAccepted then AR:PlayQuestAcceptedSound() end
  AR.activeCategory = 1
  AR.activeQuest = questIndex
  AR.activeEvidenceQuest = nil
  AR:RenderSidebar()
  AR:RenderQuestDetail()
  AR:UpdateQuestOverlays()
end

function AR:IsQuestAvailable(catKey, questIndex)
  if questIndex <= 1 then return 1 end
  local prev = AR:GetQuestList(catKey)[questIndex - 1]
  if not prev then return nil end
  return AshenRelicsDB.completed and AshenRelicsDB.completed[prev.id]
end

function AR:SetQuestComplete(catKey, questIndex, complete)
  local q = AR:GetQuestList(catKey)[questIndex]
  if not q then return end
  if not AshenRelicsDB.completed then AshenRelicsDB.completed = {} end
  if complete then
    AshenRelicsDB.completed[q.id] = 1
    AR:SetQuestAccepted(catKey, questIndex, 1)
  else
    AshenRelicsDB.completed[q.id] = nil
  end
end

function AR:GetEvidenceLogDB()
  if not AshenRelicsDB.evidenceLog then AshenRelicsDB.evidenceLog = {} end
  return AshenRelicsDB.evidenceLog
end

function AR:GetEvidenceLog(catKey, questIndex)
  if not AshenRelicsDB.evidenceLog then return nil end
  return AshenRelicsDB.evidenceLog[AR:GetQuestKey(catKey, questIndex)]
end

function AR:HasEvidenceLog(catKey, questIndex)
  local entry = AR:GetEvidenceLog(catKey, questIndex)
  if entry and entry.body and entry.body ~= "" then return 1 end
  return nil
end

function AR:SaveEvidenceLog(catKey, questIndex, state)
  if not catKey or not questIndex or not state then return end
  local q = AR:GetQuestList(catKey)[questIndex]
  if not q then return end
  local body = state.body or ""
  if body == "" then return end

  local db = AR:GetEvidenceLogDB()
  db[AR:GetQuestKey(catKey, questIndex)] = {
    title="Evidence Recovered",
    questTitle=q.title or "",
    subtitle=state.subtitle or "",
    body=body,
  }
end

function AR:CreateEvidenceToast()
  if AR.frames.toast then return end
  local f = CreateFrame("Frame", "AshenRelicsEvidenceToast", UIParent)
  f:SetWidth(360)
  f:SetHeight(82)
  f:SetPoint("TOP", UIParent, "TOP", 0, -145)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetBackdrop({
    bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",
    tile=1, tileSize=16, edgeSize=16,
    insets={left=4,right=4,top=4,bottom=4}
  })
  f:EnableMouse(true)
  f:Hide()

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.title:SetPoint("TOP", f, "TOP", 0, -12)
  f.title:SetTextColor(1, 0.72, 0.22)

  local close = CreateFrame("Button", nil, f)
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -7)
  close:SetWidth(16)
  close:SetHeight(16)
  close:SetFrameLevel(f:GetFrameLevel() + 3)
  local closeText = close:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  closeText:SetPoint("CENTER", close, "CENTER", 0, 1)
  closeText:SetText("X")
  closeText:SetTextColor(1, 0.82, 0.35)
  close:SetScript("OnClick", function() AR.frames.toast:Hide() end)
  f.close = close

  f.body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.body:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -34)
  f.body:SetWidth(324)
  f.body:SetJustifyH("CENTER")
  f.body:SetTextColor(0.95, 0.86, 0.66)

  f.elapsed = 0
  f:SetScript("OnUpdate", function()
    this.elapsed = this.elapsed + (arg1 or 0)
    if this.elapsed > (AR.evidenceToastDuration or 12) then this:Hide() end
  end)

  AR.frames.toast = f
end

function AR:ShowEvidenceToast(title, body)
  AR:CreateEvidenceToast()
  local f = AR.frames.toast
  f.title:SetText(title or "Evidence Recovered")
  f.body:SetText(body or "")
  f.elapsed = 0
  f:Show()
end


function AR:HasNearbyPartyMember()
  if not GetNumPartyMembers or GetNumPartyMembers() <= 0 then return nil end
  local i
  for i = 1, GetNumPartyMembers() do
    local unit = "party" .. i
    if UnitExists and UnitExists(unit) and not UnitIsDead(unit) then
      if CheckInteractDistance then
        -- Interaction distance 4 is usually trade/follow-style proximity.
        if CheckInteractDistance(unit, 4) then return 1 end
      else
        return 1
      end
    end
  end
  return nil
end

function AR:EnsureFlavorDB()
  if not AshenRelicsDB.flavor then AshenRelicsDB.flavor = {} end
end

function AR:SpeakMutter(key, soloLine, partyLine)
  AR:EnsureFlavorDB()
  if AshenRelicsDB.flavor[key] then return end
  AshenRelicsDB.flavor[key] = 1

  local line = soloLine
  if AR:HasNearbyPartyMember() and partyLine then line = partyLine end

  DEFAULT_CHAT_FRAME:AddMessage("|cff9f8f6a" .. line .. "|r")
end

function AR:IsSouthseaName(name)
  if not name then return nil end
  if name == "Southsea Brigand" then return 1 end
  if name == "Southsea Cannoneer" then return 1 end
  return nil
end

function AR:CheckSouthseaVicinity(unit)
  AR:CheckStoryHoverUnit(unit)
end


function AR:SpeakSayOnce(key, soloLine, partyLine)
  AR:EnsureFlavorDB()
  if AshenRelicsDB.flavor[key] then return end
  AshenRelicsDB.flavor[key] = 1

  local line = soloLine
  if AR:HasNearbyPartyMember() and partyLine then line = partyLine end

  if SendChatMessage then
    SendChatMessage(line, "SAY")
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cffffffff" .. line .. "|r")
  end
end

function AR:NameMatchesList(name, list)
  if not name or not list then return nil end
  local i
  for i = 1, table.getn(list) do
    if list[i] and string.find(name, list[i], 1, true) then return 1 end
  end
  return nil
end

function AR:IsStoryBeatQuestActive(beat)
  if not beat or not beat.questIndex then return nil end
  if not AR:IsQuestAccepted("human", beat.questIndex) then return nil end
  if AR:IsQuestComplete("human", beat.questIndex) then return nil end
  return 1
end

function AR:IsStoryBeatObjectiveReady(beat)
  if not AR:IsStoryBeatQuestActive(beat) then return nil end
  if beat.readyType == "humanQ1" then return AR:IsHumanQ1ReadyToComplete() end
  if beat.readyType == "humanQ1Key" then
    if AR:GetItemCount("cargo_key") >= 1 then return 1 end
    return nil
  end
  if beat.readyType == "livingMeasureGoblin" then
    return AR:IsLivingMeasureGoblinReady()
  end
  if beat.itemKey then
    if AR:GetItemCount(beat.itemKey) >= (beat.itemCount or 1) then return 1 end
    return nil
  end
  return 1
end

function AR:IsStoryBeatObjectivePending(beat)
  if not AR:IsStoryBeatQuestActive(beat) then return nil end
  if beat.readyType == "humanQ1Key" then return AR:IsHumanQ1KeyNeeded() end
  if beat.readyType == "humanQ1" then
    if AR:IsHumanQ1ReadyToComplete() then return nil end
    return 1
  end
  if beat.readyType == "livingMeasureGoblin" then
    return AR:IsLivingMeasureGoblinReady()
  end
  if beat.itemKey then
    if AR:GetItemCount(beat.itemKey) < (beat.itemCount or 1) then return 1 end
    return nil
  end
  return 1
end

function AR:GetStoryBeatPointDB()
  if not AshenRelicsDB.dev then AshenRelicsDB.dev = {} end
  if not AshenRelicsDB.dev.storyBeatPoints then AshenRelicsDB.dev.storyBeatPoints = {} end
  return AshenRelicsDB.dev.storyBeatPoints
end

function AR:GetStoryReturnPoint(beat)
  if not beat then return nil end
  local db = AR:GetStoryBeatPointDB()
  if db and db[beat.id] and db[beat.id].x and db[beat.id].y then return db[beat.id] end
  if beat.poiKey and AR.minimapPOIs then return AR.minimapPOIs[beat.poiKey] end
  return nil
end

function AR:GetStoryAreaPoint(beat)
  if not beat then return nil end
  if beat.localSpotKey and AR.humanLocalSearchSpots then return AR:GetRuntimeHumanLocalSearchSpot(beat.localSpotKey) end
  if beat.poiKey and AR.minimapPOIs then return AR.minimapPOIs[beat.poiKey] end
  return nil
end

function AR:GetStoryReturnRadius(beat, point)
  local radius = (beat and beat.radius) or 0.004
  if point and point.radius and point.radius < radius then radius = point.radius end
  return radius
end

function AR:IsPlayerInsideStoryPoint(point, radius)
  if not point then return nil end
  if AR:GetCurrentZoneName() ~= point.zone then return nil end
  local px, py = AR:GetPlayerMapPositionSafe()
  if not px or not py then return nil end
  local distance = AR:GetSpotDistanceFromPlayer(point, px, py)
  if not distance then return nil end
  if distance <= (radius or point.radius or 0.014) then return 1, distance end
  return nil, distance
end

function AR:CheckStoryHoverUnit(unit)
  if not UnitName or not unit then return end
  local name = UnitName(unit)
  if not name then return end

  local i
  for i = 1, table.getn(AR.storyHoverBeats or {}) do
    local beat = AR.storyHoverBeats[i]
    if AR:IsStoryBeatObjectivePending(beat) and AR:NameMatchesList(name, beat.names) then
      AR:SpeakMutter("story_hover_" .. beat.id, beat.lineSolo, beat.lineParty)
      return
    end
  end
end

function AR:CheckStoryAreaBeats()
  local i
  for i = 1, table.getn(AR.storyAreaBeats or {}) do
    local beat = AR.storyAreaBeats[i]
    if AR:IsStoryBeatObjectivePending(beat) then
      local point = AR:GetStoryAreaPoint(beat)
      if AR:IsPlayerInsideStoryPoint(point, beat.radius) then
        AR:SpeakMutter("story_area_" .. beat.id, beat.lineSolo, beat.lineParty)
      end
    end
  end
end

function AR:CheckStoryReturnBeats()
  if not AR.storyReturnInside then AR.storyReturnInside = {} end

  local i
  for i = 1, table.getn(AR.storyReturnBeats or {}) do
    local beat = AR.storyReturnBeats[i]
    local point = AR:GetStoryReturnPoint(beat)
    local inside = nil
    if point then inside = AR:IsPlayerInsideStoryPoint(point, AR:GetStoryReturnRadius(beat, point)) end

    if inside then
      if not AR.storyReturnInside[beat.id] then
        AR.storyReturnInside[beat.id] = 1
        if AR:IsStoryBeatObjectiveReady(beat) then
          AR:SpeakSayOnce("story_return_" .. beat.id, beat.saySolo, beat.sayParty)
        end
      end
    else
      AR.storyReturnInside[beat.id] = nil
    end
  end
end

function AR:CheckGazloweReturnLine(unit)
  -- Return /say lines now fire from recorded point crossings, not target hover.
end

function AR:IsGazloweReturnReady()
  if not AR:IsQuestAccepted("human", 4) then return nil end
  if AR:IsQuestComplete("human", 4) then return nil end
  if AR:GetItemCount("cargo_tag") < 4 then return nil end
  return 1
end

function AR:SpeakGazloweReturnLine()
  AR:SpeakSayOnce(
    "gazlowe_return_manifest_say_once",
    "I'm back. Found the cargo marks.",
    "We're back. Found the cargo marks."
  )
end

function AR:IsPlayerNearPOI(poi, maxDistance)
  if not poi then return nil end
  if AR:GetCurrentZoneName() ~= poi.zone then return nil end
  local x, y = AR:GetPlayerMapPositionSafe()
  if not x or not y then return nil end
  local dx = x - poi.x
  local dy = y - poi.y
  local distance = math.sqrt((dx * dx) + (dy * dy))
  return distance <= (maxDistance or 0.014)
end

function AR:CheckGazloweReturnProximity()
  AR:CheckStoryReturnBeats()
end

function AR:CreateProximityTicker()
  if AR.frames.proximityTicker then return end
  local f = CreateFrame("Frame", nil, UIParent)
  f.elapsed = 0
  f:SetScript("OnUpdate", function()
    this.elapsed = (this.elapsed or 0) + (arg1 or 0)
    if this.elapsed >= 2 then
      this.elapsed = 0
      AR:CheckStoryAreaBeats()
      AR:CheckStoryReturnBeats()
      AR:UpdateQuestOverlays()
    end
  end)
  AR.frames.proximityTicker = f
end





function AR:CheckNameValeVicinity(unit)
  return nil
end


function AR:CheckCoinTrailVicinity(unit)
  return nil
end


function AR:CheckBrokerMemoryVicinity(unit)
  AR:CheckStoryHoverUnit(unit)
end


function AR:CheckTargetVicinity()
  if AR:TrySearchTargetCorpse() then return end
  AR:CheckStoryHoverUnit("target")
end

function AR:CheckMouseoverVicinity()
  AR:CheckStoryHoverUnit("mouseover")
end


function AR:GetCargoTagClue(count)
  if count == 1 then
    AR:SpeakMutter(
      "q3_first_cargo_tag_thought",
      '"The seal matches. This tag belonged to Emberfall cargo."',
      '"The seal matches. This tag belonged to Emberfall cargo."'
    )
    return "The wood is swollen from seawater, but the stamped seal matches the Emberfall manifest."
  elseif count == 2 then
    AR:SpeakMutter(
      "q3_second_cargo_tag_thought",
      '"These are not random scraps. The same shipment broke apart along this coast."',
      '"These are not random scraps. The same shipment broke apart along this coast."'
    )
    return "The crates were not scattered by accident. They were part of the same sealed shipment."
  elseif count >= 4 then
    AR:SpeakMutter(
      "southsea_cargo_complete_once",
      '"Cargo tags complete. Back to Gazlowe."',
      '"Cargo tags complete. We take these back to Gazlowe."'
    )
    return "Most of the shipment fits a hard expedition. The calibrated lens housing and reaction marks are the pieces that do not belong."
  end
  return "The tag carries salt, splintered wood, and the Emberfall mark."
end

function AR:AddEvidenceNote(key)
  if not AshenRelicsDB.items then AshenRelicsDB.items = {} end
  if not AshenRelicsDB.items[key] or AshenRelicsDB.items[key] < 1 then
    AshenRelicsDB.items[key] = 1
    if AR.frames and AR.frames.bag then AR:RefreshBag() end
  end
end

function AR:AddItem(key, count)
  if not key then return end
  if not AshenRelicsDB.items then AshenRelicsDB.items = {} end
  AshenRelicsDB.items[key] = (AshenRelicsDB.items[key] or 0) + (count or 1)

  if key == "cargo_key" then
    AR:ShowEvidenceToast("Buccaneer's Cargo Key recovered.", "A Southsea sailor kept a key that should open the locked strongboxes aboard the Ratchet trade vessel.")
    AR:SpeakMutter(
      "q2_cargo_key_found_thought",
      '"There. A Southsea key. Now to find the boxes it still remembers."',
      '"There. A Southsea key. Now we find the boxes it still remembers."'
    )
  elseif key == "manifest" then
    local c = AshenRelicsDB.items[key] or 0
    local required = AR:GetHumanQ1SearchRequired()
    if c > required then c = required end
    AR:ShowEvidenceToast("Moldy Shipping Manifest recovered. " .. c .. "/" .. required, "The records point to supplies packed with more purpose than the founders understood.")
  elseif key == "cargo_tag" then
    local c = AshenRelicsDB.items[key] or 0
    AR:ShowEvidenceToast("Salt-Stained Cargo Tag recovered. " .. c .. "/4", AR:GetCargoTagClue(c))
  elseif key == "lens" then
    -- Sputtervalve should explain what the lens means during turn-in.
  elseif key == "continuation_ledger" then
    AR:ShowEvidenceToast("Blackwater Payment Ledger recovered.", "The coin kept moving after the ships did. The strange part is how much the payer already knew.")
    AR:SpeakMutter(
      "q5_continuation_ledger_found_thought",
      '"Payments after departure. Someone knew where the road was going before the founders did."',
      '"Payments after departure. Someone knew where the road was going before the founders did."'
    )
  elseif key == "broker_cut_ledger" then
    AR:ShowEvidenceToast("Broker's Cut Ledger recovered.", "Goblins and pirates moved the coin, but someone else kept their hand out of sight.")
    AR:SpeakMutter(
      "q6_broker_ledger_found_thought",
      '"Longshore kept proof because proof could become coin. Gazlowe needs to see this."',
      '"Longshore kept proof because proof could become coin. Gazlowe needs to see this."'
    )
  elseif key == "vale_mark" then
    AR:ShowEvidenceToast("Unmarked Guarantor Seal recovered.", "Someone with standing helped make Emberfall look proper before anyone asked why it needed cover.")
    AR:SpeakMutter(
      "q7_guarantor_mark_found_thought",
      '"A clean seal sitting in dirty paper. That is how questions get quiet."',
      '"A clean seal sitting in dirty paper. That is how questions get quiet."'
    )
  elseif key == "contract" then
    AR:ShowEvidenceToast("Burned Contract Scrap recovered.", "The words are burned, but enough remains to show the promise reached farther than work.")
    AR:SpeakMutter(
      "q8_contract_found_thought",
      '"This contract was burned for a reason. The part that survived feels worse than the ash."',
      '"This contract was burned for a reason. The part that survived feels worse than the ash."'
    )
  elseif key == "coin" then
    AR:ShowEvidenceToast("Human Relic recovered: The Coin Without a King.", "No crown, no house, no honest owner. The hand behind Emberfall stayed hidden.")
    AR:SpeakMutter(
      "q9_coin_found_thought",
      '"No crown. No house. No mark that points home."',
      '"No crown. No house. No mark that points home."'
    )
  else
    local def = AR.itemDefs[key]
    if def then AR:ShowEvidenceToast("Evidence Recovered", def.name) end
  end

  if AR.frames and AR.frames.bag then AR:RefreshBag() end
  AR:RenderQuestDetail()
  AR:UpdateQuestOverlays()
end

function AR:GetItemCount(key)
  if not AshenRelicsDB.items then return 0 end
  return AshenRelicsDB.items[key] or 0
end

function AR:GetObjectiveProgress(obj)
  if not obj then return 0 end
  if obj.spotIndex then return AR:GetHumanQ1SpotProgress(obj.spotIndex) end
  if obj.humanQ1Searches then return AR:GetHumanQ1SearchCount() end
  if obj.flagKey then
    if AR:GetFlag(obj.flagKey) then return 1 end
    return 0
  end
  if obj.itemKey then return AR:GetItemCount(obj.itemKey) end
  return 0
end

function AR:IsQuestReadyToComplete(catKey, questIndex)
  local q = AR:GetQuestList(catKey)[questIndex]
  if not q then return nil end
  if q.isInterlude then return AshenRelicsDB.completed and AshenRelicsDB.completed[q.id] end
  if not q.objectives or table.getn(q.objectives) == 0 then return nil end

  local i
  for i = 1, table.getn(q.objectives) do
    local obj = q.objectives[i]
    local current = AR:GetObjectiveProgress(obj)
    if current < (obj.required or 1) then return nil end
  end
  return 1
end

function AR:IsQuestUnlocked(catKey, questIndex)
  if questIndex <= 1 then return 1 end
  if AR:IsQuestComplete(catKey, questIndex) then return 1 end

  -- The first spoken lead appears after the interlude. All later quests must be
  -- explicitly accepted from their NPC after the previous turn-in.
  if questIndex == 2 then return AR:IsQuestAvailable(catKey, questIndex) end
  return AR:IsQuestAccepted(catKey, questIndex)
end

function AR:CompleteQuest(catKey, questIndex, silent)
  local q = AR:GetQuestList(catKey)[questIndex]
  if not q then return end
  local wasComplete = AR:IsQuestComplete(catKey, questIndex)
  AR:SetQuestComplete(catKey, questIndex, 1)
  if not silent and not wasComplete then AR:PlayQuestCompleteSound() end

  -- Reward items only enter the Reliquary when earned/looted, never all at startup.
  if q.rewardType == "artifact" and q.targetIcon == AR.icons.coinArtifact and AR:GetItemCount("coin") < 1 then
    AR:AddItem("coin", 1)
  end

  if q.id == "human_intro_to_gazlowe" then
    AR:SetFlag("gazlowe_intro_handoff_complete", 1)
  elseif q.id == "human_00" then
    AR:ShowEvidenceToast("Moldy Shipping Manifest recovered.", "Emberfall passed through Ratchet with supplies packed for a road someone already understood.")
  elseif q.id == "human_01" then
    AR:ShowEvidenceToast("Salt-Stained Cargo Tags recovered.", "Most of the cargo fits a hard expedition. A damaged brass meter and calibrated lens housing do not.")
    AR:AddEvidenceNote("meter")
  elseif q.id == "human_02" then
    -- The Surveyor's Glass reveal belongs in Sputtervalve's completion dialogue.
  elseif q.id == "human_02_to_dizzywig" then
    AR:SetFlag("dizzywig_handoff_complete", 1)
  elseif q.id == "human_03" then
    AR:ShowEvidenceToast("Blackwater Payment Ledger recovered.", "The coin kept moving after the ships did. The strange part is how much the payer already knew.")
  elseif q.id == "human_04" then
    AR:ShowEvidenceToast("Broker's Cut Ledger recovered.", "Goblins and pirates moved the coin, but someone else kept their hand out of sight.")
  elseif q.id == "human_05" then
    AR:ShowEvidenceToast("Unmarked Guarantor Seal recovered.", "Someone with standing helped make Emberfall look proper before anyone asked why it needed cover.")
  elseif q.id == "human_06" then
    AR:ShowEvidenceToast("Burned Contract Scrap recovered.", "The words are burned, but enough remains to show the promise reached farther than work.")
  elseif q.id == "human_07" then
    AR:ShowEvidenceToast("Humanity's piece of the truth:", "That was not an expedition. It was a prepared road with paperwork.")
  end

  if q.id == "human_intro" then
    AR:AcceptQuest("human", 2, 1)
  end

  AR:RenderSidebar()
  AR:RenderQuestDetail()
  AR:UpdateCategoryCounts()
  AR:UpdateQuestOverlays()
end

function AR:GetQuestCount(cat)
  local list = AR:GetQuestList(cat.key)
  local total = table.getn(list)
  local done = 0
  local i
  for i = 1, total do
    if AR:IsQuestComplete(cat.key, i) then done = done + 1 end
  end
  return done, total
end

function AR:UpdateCategoryCounts()
  local i
  for i = 1, table.getn(AR.categories) do
    local cat = AR.categories[i]
    local done, total = AR:GetQuestCount(cat)
    if cat.countText then cat.countText:SetText(done .. "/" .. total) end
  end
end

function AR:SelectCategory(index)
  local cat = AR.categories[index]
  if not cat then return end
  if AR.activeCategory == index then
    cat.expanded = not cat.expanded
  else
    local i
    for i = 1, table.getn(AR.categories) do AR.categories[i].expanded = false end
    cat.expanded = true
    AR.activeCategory = index
    AR.activeQuest = 1
    AR.activeEvidenceQuest = nil
    local qList = AR:GetQuestList(cat.key)
    local qi
    for qi = 1, table.getn(qList) do
      if AR:IsQuestUnlocked(cat.key, qi) then AR.activeQuest = qi; break end
    end
  end
  AR:RenderSidebar()
  AR:RenderQuestDetail()
  AR:UpdateCategoryCounts()
end

function AR:PlayQuestHoverSound()
  local now = 0
  if GetTime then now = GetTime() end
  if AR.lastQuestHoverSoundAt and now > 0 and (now - AR.lastQuestHoverSoundAt) < 0.08 then return end
  AR.lastQuestHoverSoundAt = now
  AR:PlayUISoundFile(AR.questHoverSoundPath, "igMainMenuOptionCheckBoxOn")
end

function AR:ApplyQuestRowVisual(row, selected, hovered)
  if not row then return end
  if row.bg then
    row.bg:SetTexture(AR.rowTextures.normal)
    row.bg:SetAlpha(1.0)
    if row.bg.SetVertexColor then row.bg:SetVertexColor(1, 1, 1) end
  end

  local glowAlpha = 0
  if hovered then
    glowAlpha = 0.26
  elseif selected then
    glowAlpha = 0.16
  end

  if row.glow then row.glow:SetAlpha(glowAlpha) end
  if row.text then
    if hovered or selected then
      row.text:SetTextColor(1.0, 1.0, 1.0)
    else
      row.text:SetTextColor(0.88, 0.86, 0.80)
    end
  end
end

function AR:RenderSidebar()
  local f = AR.frames.main
  if not f or not f.sidebar then return end
  local holder = f.sidebar
  if holder.rows then
    local old
    for old = 1, table.getn(holder.rows) do holder.rows[old]:Hide() end
  end
  holder.rows = {}

  local y = 0
  local catW, catH = 250, 34
  local rowLayout = AR:GetLayout("questRows")
  local questW, questH = rowLayout.w, rowLayout.h
  local gap = 7
  local i

  for i = 1, table.getn(AR.categories) do
    local cat = AR.categories[i]
    local b = CreateFrame("Button", nil, holder)
    b:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, y)
    b:SetWidth(catW)
    b:SetHeight(catH)
    b:SetFrameLevel(holder:GetFrameLevel() + 3)
    b.index = i

    local a = AR.assets.cats[cat.key]
    if a then AddTileGrid(b, a, catW, catH, "ARTWORK") end

    local sign = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sign:SetPoint("LEFT", b, "LEFT", 14, 0)
    sign:SetTextColor(0.88, 0.73, 0.47)
    if cat.expanded then sign:SetText("-") else sign:SetText("+") end

    cat.countText = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cat.countText:SetPoint("RIGHT", b, "RIGHT", -9, 0)
    cat.countText:SetTextColor(0.85, 0.45, 0.28)
    cat.countText:SetText("0/0")

    b:SetScript("OnClick", function() AR:SelectCategory(this.index) end)
    b:SetScript("OnEnter", function() this:SetAlpha(1.0) end)
    b:SetScript("OnLeave", function() this:SetAlpha(0.92) end)
    b:SetAlpha(0.92)
    table.insert(holder.rows, b)
    y = y - (catH + gap)

    if cat.expanded then
      local quests = AR:GetQuestList(cat.key)
      local qIndex
      for qIndex = 1, table.getn(quests) do
        local q = quests[qIndex]
        if AR:IsQuestUnlocked(cat.key, qIndex) then
        local row = CreateFrame("Button", nil, holder)
        row:SetPoint("TOPLEFT", holder, "TOPLEFT", rowLayout.x, y + rowLayout.y)
        row:SetWidth(questW)
        row:SetHeight(questH)
        row:SetFrameLevel(holder:GetFrameLevel() + 12)
        row.catIndex = i
        row.questIndex = qIndex

        local bg = row:CreateTexture(nil, "ARTWORK")
        bg:SetAllPoints(row)
        bg:SetTexture(AR.rowTextures.normal)
        bg:SetTexCoord(0, 1, 0, 1)
        bg:SetBlendMode("BLEND")
        bg:SetAlpha(1.0)
        row.bg = bg

        local glow = row:CreateTexture(nil, "OVERLAY")
        glow:SetPoint("LEFT", row, "LEFT", 10, 0)
        glow:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        glow:SetHeight(questH - 8)
        glow:SetTexture("Interface\\Buttons\\WHITE8X8")
        glow:SetBlendMode("ADD")
        glow:SetVertexColor(1, 1, 1)
        glow:SetAlpha(0)
        row.glow = glow

        local rowTextLayout = AR:GetLayout("questRowText")
        local txt = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        txt:SetPoint("LEFT", row, "LEFT", rowTextLayout.x, rowTextLayout.y)
        txt:SetWidth(rowTextLayout.w)
        txt:SetHeight(rowTextLayout.h)
        txt:SetJustifyH("LEFT")
        txt:SetText(q.title)
        row.text = txt
        AR:ApplyQuestRowVisual(row, i == AR.activeCategory and qIndex == AR.activeQuest and not AR.activeEvidenceQuest, nil)

        row:SetScript("OnClick", function()
          AR:PlayQuestPageTurnSound()
          if AR.activeCategory == this.catIndex and AR.activeQuest == this.questIndex and not AR.activeEvidenceQuest then return end
          AR.activeCategory = this.catIndex
          AR.activeQuest = this.questIndex
          AR.activeEvidenceQuest = nil
          AR:RenderSidebar()
          AR:RenderQuestDetail()
        end)
        row:SetScript("OnEnter", function()
          AR:PlayQuestHoverSound()
          AR:ApplyQuestRowVisual(this, this.catIndex == AR.activeCategory and this.questIndex == AR.activeQuest and not AR.activeEvidenceQuest, 1)
        end)
        row:SetScript("OnLeave", function()
          AR:ApplyQuestRowVisual(this, this.catIndex == AR.activeCategory and this.questIndex == AR.activeQuest and not AR.activeEvidenceQuest, nil)
        end)
        table.insert(holder.rows, row)
        y = y - (questH + 2)

        if AR:IsQuestComplete(cat.key, qIndex) and AR:HasEvidenceLog(cat.key, qIndex) then
          local evidenceRow = CreateFrame("Button", nil, holder)
          evidenceRow:SetPoint("TOPLEFT", holder, "TOPLEFT", rowLayout.x + 18, y + rowLayout.y)
          evidenceRow:SetWidth(questW - 18)
          evidenceRow:SetHeight(questH)
          evidenceRow:SetFrameLevel(holder:GetFrameLevel() + 12)
          evidenceRow.catIndex = i
          evidenceRow.questIndex = qIndex

          local evidenceBg = evidenceRow:CreateTexture(nil, "ARTWORK")
          evidenceBg:SetAllPoints(evidenceRow)
          evidenceBg:SetTexture(AR.rowTextures.normal)
          evidenceBg:SetTexCoord(0, 1, 0, 1)
          evidenceBg:SetBlendMode("BLEND")
          evidenceBg:SetAlpha(1.0)
          evidenceRow.bg = evidenceBg

          local evidenceGlow = evidenceRow:CreateTexture(nil, "OVERLAY")
          evidenceGlow:SetPoint("LEFT", evidenceRow, "LEFT", 10, 0)
          evidenceGlow:SetPoint("RIGHT", evidenceRow, "RIGHT", -8, 0)
          evidenceGlow:SetHeight(questH - 8)
          evidenceGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
          evidenceGlow:SetBlendMode("ADD")
          evidenceGlow:SetVertexColor(1, 1, 1)
          evidenceGlow:SetAlpha(0)
          evidenceRow.glow = evidenceGlow

          local evidenceText = evidenceRow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
          evidenceText:SetPoint("LEFT", evidenceRow, "LEFT", rowTextLayout.x + 4, rowTextLayout.y)
          evidenceText:SetWidth(rowTextLayout.w - 18)
          evidenceText:SetHeight(rowTextLayout.h)
          evidenceText:SetJustifyH("LEFT")
          evidenceText:SetText("Evidence Recovered")
          evidenceRow.text = evidenceText
          AR:ApplyQuestRowVisual(evidenceRow, i == AR.activeCategory and qIndex == AR.activeEvidenceQuest, nil)

          evidenceRow:SetScript("OnClick", function()
            AR:PlayQuestPageTurnSound()
            AR.activeCategory = this.catIndex
            AR.activeQuest = this.questIndex
            AR.activeEvidenceQuest = this.questIndex
            AR:RenderSidebar()
            AR:RenderQuestDetail()
          end)
          evidenceRow:SetScript("OnEnter", function()
            AR:PlayQuestHoverSound()
            AR:ApplyQuestRowVisual(this, this.catIndex == AR.activeCategory and this.questIndex == AR.activeEvidenceQuest, 1)
          end)
          evidenceRow:SetScript("OnLeave", function()
            AR:ApplyQuestRowVisual(this, this.catIndex == AR.activeCategory and this.questIndex == AR.activeEvidenceQuest, nil)
          end)
          table.insert(holder.rows, evidenceRow)
          y = y - (questH + 2)
        end
        end
      end
      y = y - 6
    end
  end
  AR:UpdateCategoryCounts()
end


AR.layoutOrder = {
  "page", "title", "subtitle", "objective", "description",
  "targetIcon", "targetText", "stamp", "rewardIcon", "rewardText",
  "questRows", "questRowText", "interludeText", "interludeButtons",
  "headerFlame"
}

AR.layoutLabels = {
  page="Whole Quest Page",
  title="Quest Title",
  subtitle="Quest Subtitle",
  objective="Objective Text",
  description="Description Scroll Area",
  targetIcon="Target Icon",
  targetText="Target Text",
  stamp="Right Stamp",
  rewardIcon="Reward Icon",
  rewardText="Reward Text",
  questRows="Left Quest Row TGAs",
  questRowText="Left Quest Row Text",
  interludeText="Introlude Body Text",
  interludeButtons="Introlude Buttons",
  headerFlame="Header Flame"
}

AR.defaultLayout = {
  page={x=292,y=-80,w=430,h=574,scale=1},
  title={x=58,y=-42,w=350,h=38,scale=1},
  subtitle={x=58,y=-78,w=350,h=26,scale=1},
  objective={x=58,y=-126,w=320,h=92,scale=1},
  description={x=58,y=-246,w=315,h=96,scale=1},
  targetIcon={x=60,y=-363,w=58,h=58,scale=1},
  targetText={x=136,y=-360,w=240,h=64,scale=1},
  stamp={x=278,y=-330,w=112,h=112,scale=1},
  rewardIcon={x=68,y=-492,w=45,h=45,scale=1},
  rewardText={x=126,y=-484,w=260,h=58,scale=1},
  questRows={x=0,y=0,w=260,h=28,scale=1},
  questRowText={x=18,y=0,w=210,h=16,scale=1},
  interludeText={x=28,y=-92,w=388,h=470,scale=1},
  interludeButtons={x=58,y=-548,w=210,h=24,scale=1},
  headerFlame={x=287,y=-8,w=72,h=72,scale=1},
}

function AR:GetLayout(name)
  if not AshenRelicsDB.layout then AshenRelicsDB.layout = {} end
  if not AshenRelicsDB.layout[name] then
    local d = AR.defaultLayout[name]
    AshenRelicsDB.layout[name] = {x=d.x,y=d.y,w=d.w,h=d.h,scale=d.scale}
  end
  return AshenRelicsDB.layout[name]
end

function AR:ApplyRegionLayout(region, parent, data)
  if not region or not data then return end
  region:ClearAllPoints()
  region:SetPoint("TOPLEFT", parent, "TOPLEFT", data.x, data.y)
  if region.SetWidth then region:SetWidth(data.w) end
  if region.SetHeight then region:SetHeight(data.h) end
end

function AR:ApplyLayout()
  local f = AR.frames.main
  if not f or not f.page then return end
  local lp = AR:GetLayout("page")
  AR:ApplyRegionLayout(f.page, f, lp)
  AR:ApplyRegionLayout(f.content, f, lp)

  AR:ApplyRegionLayout(f.titleText, f.content, AR:GetLayout("title"))
  AR:ApplyRegionLayout(f.subtitleText, f.content, AR:GetLayout("subtitle"))
  AR:ApplyRegionLayout(f.objectiveText, f.content, AR:GetLayout("objective"))

  local od = AR:GetLayout("objective")
  local i
  for i = 1, 3 do
    if f.objectiveChecks and f.objectiveChecks[i] then
      f.objectiveChecks[i]:ClearAllPoints()
      f.objectiveChecks[i]:SetPoint("TOPLEFT", f.content, "TOPLEFT", od.x + 10, od.y - 39 - ((i-1)*20))
      f.objectiveChecks[i]:SetWidth(11)
      f.objectiveChecks[i]:SetHeight(11)
    end
    if f.objectiveLines and f.objectiveLines[i] then
      f.objectiveLines[i]:ClearAllPoints()
      f.objectiveLines[i]:SetPoint("TOPLEFT", f.content, "TOPLEFT", od.x + 28, od.y - 38 - ((i-1)*20))
      f.objectiveLines[i]:SetWidth(od.w - 28)
      f.objectiveLines[i]:SetHeight(16)
    end
  end

  AR:ApplyRegionLayout(f.descriptionScroll, f.content, AR:GetLayout("description"))
  if f.descriptionChild then f.descriptionChild:SetWidth(AR:GetLayout("description").w) end
  if f.descriptionText then f.descriptionText:SetWidth(AR:GetLayout("description").w) end

  AR:ApplyRegionLayout(f.targetIconHolder, f.content, AR:GetLayout("targetIcon"))
  local ti = AR:GetLayout("targetIcon")
  if f.targetIcon then f.targetIcon:SetAllPoints(f.targetIconHolder) end
  if f.targetIcon2Holder then
    f.targetIcon2Holder:ClearAllPoints()
    f.targetIcon2Holder:SetPoint("TOPLEFT", f.content, "TOPLEFT", ti.x + 36, ti.y - 30)
    f.targetIcon2Holder:SetWidth(34)
    f.targetIcon2Holder:SetHeight(34)
  end

  local tt = AR:GetLayout("targetText")
  AR:ApplyRegionLayout(f.targetNameText, f.content, {x=tt.x,y=tt.y,w=tt.w,h=22,scale=tt.scale})
  AR:ApplyRegionLayout(f.targetLocationText, f.content, {x=tt.x,y=tt.y-24,w=tt.w,h=42,scale=tt.scale})

  AR:ApplyRegionLayout(f.stamp, f.content, AR:GetLayout("stamp"))
  AR:ApplyRegionLayout(f.rewardIconHolder, f.content, AR:GetLayout("rewardIcon"))
  if f.rewardIcon then f.rewardIcon:SetAllPoints(f.rewardIconHolder) end
  AR:ApplyRegionLayout(f.rewardTextHolder, f.content, AR:GetLayout("rewardText"))

  if AR.selectedLayoutElement == "questRows" or AR.selectedLayoutElement == "questRowText" then
    AR:RenderSidebar()
  end
  AR:ApplyHeaderFlameLayout()
  local cat = AR.categories[AR.activeCategory]
  if cat then
    local list = AR:GetQuestList(cat.key)
    local q = list[AR.activeQuest]
    if q and q.isInterlude then AR:SetInterludeMode(1) end
  end
  AR:UpdateOptionsText()
end

function AR:ResetLayout()
  AshenRelicsDB.layout = {}
  AR:ApplyLayout()
end

function AR:NudgeLayout(dx, dy)
  local name = AR.selectedLayoutElement or "page"
  local d = AR:GetLayout(name)
  d.x = d.x + dx
  d.y = d.y + dy
  AR:ApplyLayout()
end

function AR:ResizeLayout(dw, dh)
  local name = AR.selectedLayoutElement or "page"
  local d = AR:GetLayout(name)
  d.w = Max(8, d.w + dw)
  d.h = Max(8, d.h + dh)
  AR:ApplyLayout()
end

function AR:ScaleLayout(ds)
  local name = AR.selectedLayoutElement or "page"
  local d = AR:GetLayout(name)
  d.scale = d.scale + ds
  if d.scale < 0.5 then d.scale = 0.5 end
  if d.scale > 2.5 then d.scale = 2.5 end

  -- Vanilla-safe scaling: resize the selected region instead of calling SetScale.
  local changeW = 4
  local changeH = 4
  if ds < 0 then
    changeW = -4
    changeH = -4
  end
  d.w = Max(8, d.w + changeW)
  d.h = Max(8, d.h + changeH)

  AR:ApplyLayout()
end

function AR:CycleLayoutElement(step)
  local index = AR.selectedLayoutIndex or 1
  index = index + step
  if index < 1 then index = table.getn(AR.layoutOrder) end
  if index > table.getn(AR.layoutOrder) then index = 1 end
  AR.selectedLayoutIndex = index
  AR.selectedLayoutElement = AR.layoutOrder[index]
  AR:UpdateOptionsText()
end

function AR:SelectLayoutElement(name)
  local i
  for i = 1, table.getn(AR.layoutOrder) do
    if AR.layoutOrder[i] == name then
      AR.selectedLayoutIndex = i
      AR.selectedLayoutElement = name
      AR:UpdateOptionsText()
      return
    end
  end
end

function AR:UpdateOptionsText()
  local f = AR.frames.options
  if not f or not f.text then return end
  local name = AR.selectedLayoutElement or "page"
  local d = AR:GetLayout(name)
  local extra = ""
  if name == "questRows" then extra = "\nAffects every quest row TGA." end
  if name == "questRowText" then extra = "\nAffects every quest title on the left." end
  if name == "interludeText" then extra = "\nOnly affects the Introlude body text area." end
  if name == "interludeButtons" then extra = "\nOnly affects Play / Show Text buttons." end
  if name == "headerFlame" then extra = "\nMoves the animated crest flame." end
  f.text:SetText((AR.layoutLabels[name] or name) .. extra .. "\nX " .. d.x .. "  Y " .. d.y .. "\nW " .. d.w .. "  H " .. d.h .. "\nScale " .. string.format("%.2f", d.scale or 1))
end

function AR:MakeSmallButton(parent, text, x, y, w, h, func)
  local b = CreateFrame("Button", nil, parent)
  b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  b:SetWidth(w)
  b:SetHeight(h)
  b:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
  b:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
  b:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
  local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetPoint("CENTER", b, "CENTER", 0, 0)
  fs:SetText(text)
  b.text = fs
  b:SetScript("OnClick", func)
  return b
end

function AR:LuaQuote(value)
  local s = tostring(value or "")
  s = string.gsub(s, "\\", "\\\\")
  s = string.gsub(s, "\r", "\\r")
  s = string.gsub(s, "\n", "\\n")
  s = string.gsub(s, "\t", "\\t")
  s = string.gsub(s, "\"", "\\\"")
  return "\"" .. s .. "\""
end


function AR:EnsureCopyEditDB()
  if not AshenRelicsDB.copyEdits then AshenRelicsDB.copyEdits = {} end
  if not AshenRelicsDB.copyEdits.dialogue then AshenRelicsDB.copyEdits.dialogue = {} end
  if not AshenRelicsDB.copyEdits.quests then AshenRelicsDB.copyEdits.quests = {} end
  if not AshenRelicsDB.copyEdits.whispers then AshenRelicsDB.copyEdits.whispers = {} end
end

function AR:CopyEditModeForState(state)
  if not state then return "unknown" end
  if state.acceptQuest then return "accept:" .. tostring(state.acceptQuest) end
  if state.complete then return "complete" end
  if state.advanceFlag then return "advance:" .. tostring(state.advanceFlag) end
  if state.setFlag then return "setflag:" .. tostring(state.setFlag) end
  return "progress"
end

function AR:GetDialogueEditKey(npc, state)
  local n = npc or "unknown"
  local q = state and state.questIndex or ""
  local mode = AR:CopyEditModeForState(state)
  local button = state and state.button or ""
  return n .. "|q=" .. tostring(q or "") .. "|mode=" .. tostring(mode or "") .. "|button=" .. tostring(button or "")
end

function AR:ApplyDialogueCopyEdit(key, state)
  if not state then return state end
  if not key then return state end
  AR:EnsureCopyEditDB()
  state._editKey = key
  local edit = AshenRelicsDB.copyEdits.dialogue[key]
  if not edit then return state end
  if edit.title ~= nil then state.title = edit.title end
  if edit.subtitle ~= nil then state.subtitle = edit.subtitle end
  if edit.body ~= nil then state.body = edit.body end
  if edit.button ~= nil then state.button = edit.button end
  return state
end

function AR:GetQuestById(id)
  local catKey, list, i, q
  for catKey, list in pairs(AR.quests or {}) do
    for i = 1, table.getn(list) do
      q = list[i]
      if q and q.id == id then return q, catKey, i end
    end
  end
  return nil
end

function AR:ApplyQuestCopyEditById(id)
  if not id then return end
  AR:EnsureCopyEditDB()
  local edit = AshenRelicsDB.copyEdits.quests[id]
  if not edit then return end
  local q = AR:GetQuestById(id)
  if not q then return end
  local fields = {"title","subtitle","objectiveText","description","targetName","targetLocation","rewardName","rewardDetail"}
  local i, field
  for i = 1, table.getn(fields) do
    field = fields[i]
    if edit[field] ~= nil then q[field] = edit[field] end
  end
  if not q.objectives then q.objectives = {} end
  for i = 1, 3 do
    local k = "objective" .. i
    if edit[k] ~= nil and q.objectives[i] then q.objectives[i].text = edit[k] end
  end
end

function AR:ApplyAllQuestCopyEdits()
  AR:EnsureCopyEditDB()
  local id
  for id in pairs(AshenRelicsDB.copyEdits.quests or {}) do
    AR:ApplyQuestCopyEditById(id)
  end
end

function AR:SaveQuestCopyEdit(catKey, questIndex, data)
  local q = AR:GetQuestList(catKey or "human")[questIndex]
  if not q or not q.id then return end
  AR:EnsureCopyEditDB()
  AshenRelicsDB.copyEdits.quests[q.id] = data or {}
  AR:ApplyQuestCopyEditById(q.id)
  AR:RenderSidebar()
  AR:RenderQuestDetail()
  DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics Dev:|r saved quest copy edit for " .. (q.title or q.id) .. ".")
end

function AR:SaveDialogueCopyEdit(key, data)
  if not key then return end
  AR:EnsureCopyEditDB()
  AshenRelicsDB.copyEdits.dialogue[key] = data or {}
  DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics Dev:|r saved dialogue copy edit. Use /reload to verify, or Dump Edits to send it for hardcoding.")
end

function AR:CreateEditorLabel(parent, text, x, y, w, h)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  fs:SetWidth(w or 120)
  fs:SetHeight(h or 14)
  fs:SetJustifyH("LEFT")
  fs:SetText(text or "")
  return fs
end

function AR:CreateCopyEditBox(parent, x, y, w, h, multiline)
  local eb = CreateFrame("EditBox", nil, parent)
  eb:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  eb:SetWidth(w)
  eb:SetHeight(h)
  eb:SetAutoFocus(false)
  if multiline then eb:SetMultiLine(true) end
  eb:SetFontObject(GameFontHighlightSmall)
  eb:SetTextColor(1, 1, 1)
  eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
  eb:SetScript("OnEnterPressed", function()
    if not multiline then this:ClearFocus() end
  end)
  local bg = parent:CreateTexture(nil, "BACKGROUND")
  bg:SetPoint("TOPLEFT", eb, "TOPLEFT", -4, 4)
  bg:SetPoint("BOTTOMRIGHT", eb, "BOTTOMRIGHT", 4, -4)
  bg:SetTexture(0, 0, 0, 0.45)
  return eb
end

function AR:CreateDialogueCopyEditorFrame()
  if AR.frames.dialogueCopyEditor then return end
  local f = CreateFrame("Frame", "AshenRelicsDialogueCopyEditorFrame", UIParent)
  f:SetWidth(760)
  f:SetHeight(640)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetFrameStrata("DIALOG")
  f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=1, tileSize=32, edgeSize=32, insets={left=8,right=8,top=8,bottom=8}})
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:Hide()

  f.header = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.header:SetPoint("TOP", f, "TOP", 0, -18)
  f.header:SetText("Edit Dialogue Copy")

  AR:CreateEditorLabel(f, "Title", 30, -52, 80, 14)
  f.titleEdit = AR:CreateCopyEditBox(f, 110, -52, 600, 22, nil)
  AR:CreateEditorLabel(f, "Subtitle", 30, -86, 80, 14)
  f.subtitleEdit = AR:CreateCopyEditBox(f, 110, -86, 600, 22, nil)
  AR:CreateEditorLabel(f, "Button", 30, -120, 80, 14)
  f.buttonEdit = AR:CreateCopyEditBox(f, 110, -120, 600, 22, nil)
  AR:CreateEditorLabel(f, "Body", 30, -158, 80, 14)

  f.bodyScroll = CreateFrame("ScrollFrame", nil, f)
  f.bodyScroll:SetPoint("TOPLEFT", f, "TOPLEFT", 110, -158)
  f.bodyScroll:SetWidth(600)
  f.bodyScroll:SetHeight(380)
  f.bodyScroll:EnableMouseWheel(true)
  f.bodyEdit = AR:CreateCopyEditBox(f.bodyScroll, 0, 0, 580, 900, 1)
  f.bodyScroll:SetScrollChild(f.bodyEdit)
  f.bodyScroll:SetScript("OnMouseWheel", function()
    local maxScroll = 900 - this:GetHeight()
    local cur = this:GetVerticalScroll()
    if arg1 > 0 then cur = cur - 32 else cur = cur + 32 end
    this:SetVerticalScroll(Clamp(cur, 0, maxScroll))
  end)

  AR:MakeSmallButton(f, "Save", 110, -575, 82, 24, function()
    local key = AR.frames.dialogueCopyEditor.editKey
    AR:SaveDialogueCopyEdit(key, {
      title=AR.frames.dialogueCopyEditor.titleEdit:GetText() or "",
      subtitle=AR.frames.dialogueCopyEditor.subtitleEdit:GetText() or "",
      button=AR.frames.dialogueCopyEditor.buttonEdit:GetText() or "",
      body=AR.frames.dialogueCopyEditor.bodyEdit:GetText() or "",
    })
    AR.frames.dialogueCopyEditor:Hide()
    AR:RenderDevDialogue()
  end)
  AR:MakeSmallButton(f, "Dump Edits", 202, -575, 92, 24, function() AR:ShowCopyEditsDumpWindow() end)
  AR:MakeSmallButton(f, "Close", 628, -575, 82, 24, function() AR.frames.dialogueCopyEditor:Hide() end)
  AR.frames.dialogueCopyEditor = f
end

function AR:OpenDialogueCopyEditor(entry)
  if not entry then return end
  AR:CreateDialogueCopyEditorFrame()
  local f = AR.frames.dialogueCopyEditor
  f.editKey = entry._editKey
  f.header:SetText("Edit Dialogue Copy - " .. (entry.label or "Dialogue"))
  f.titleEdit:SetText(entry.title or "")
  f.subtitleEdit:SetText(entry.subtitle or "")
  f.buttonEdit:SetText(entry.button or "")
  f.bodyEdit:SetText(entry.body or "")
  f.bodyScroll:SetVerticalScroll(0)
  f:Show()
end

function AR:CreateQuestCopyEditorFrame()
  if AR.frames.questCopyEditor then return end
  local f = CreateFrame("Frame", "AshenRelicsQuestCopyEditorFrame", UIParent)
  f:SetWidth(790)
  f:SetHeight(700)
  f:SetPoint("CENTER", UIParent, "CENTER", -15, 0)
  f:SetFrameStrata("DIALOG")
  f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=1, tileSize=32, edgeSize=32, insets={left=8,right=8,top=8,bottom=8}})
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:Hide()

  f.header = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.header:SetPoint("TOP", f, "TOP", 0, -18)
  f.header:SetText("Edit Quest Copy")

  local y = -52
  AR:CreateEditorLabel(f, "Title", 28, y, 95, 14); f.titleEdit = AR:CreateCopyEditBox(f, 130, y, 610, 22, nil); y = y - 32
  AR:CreateEditorLabel(f, "Subtitle", 28, y, 95, 14); f.subtitleEdit = AR:CreateCopyEditBox(f, 130, y, 610, 22, nil); y = y - 32
  AR:CreateEditorLabel(f, "Objective Text", 28, y, 95, 14); f.objectiveTextEdit = AR:CreateCopyEditBox(f, 130, y, 610, 22, nil); y = y - 32
  AR:CreateEditorLabel(f, "Obj Line 1", 28, y, 95, 14); f.objective1Edit = AR:CreateCopyEditBox(f, 130, y, 610, 22, nil); y = y - 32
  AR:CreateEditorLabel(f, "Obj Line 2", 28, y, 95, 14); f.objective2Edit = AR:CreateCopyEditBox(f, 130, y, 610, 22, nil); y = y - 32
  AR:CreateEditorLabel(f, "Obj Line 3", 28, y, 95, 14); f.objective3Edit = AR:CreateCopyEditBox(f, 130, y, 610, 22, nil); y = y - 32
  AR:CreateEditorLabel(f, "Target", 28, y, 95, 14); f.targetNameEdit = AR:CreateCopyEditBox(f, 130, y, 285, 22, nil); AR:CreateEditorLabel(f, "Location", 430, y, 70, 14); f.targetLocationEdit = AR:CreateCopyEditBox(f, 500, y, 240, 22, nil); y = y - 32
  AR:CreateEditorLabel(f, "Reward", 28, y, 95, 14); f.rewardNameEdit = AR:CreateCopyEditBox(f, 130, y, 285, 22, nil); AR:CreateEditorLabel(f, "Reward Detail", 430, y, 95, 14); f.rewardDetailEdit = AR:CreateCopyEditBox(f, 525, y, 215, 22, nil); y = y - 38
  AR:CreateEditorLabel(f, "Description", 28, y, 95, 14)

  f.descriptionScroll = CreateFrame("ScrollFrame", nil, f)
  f.descriptionScroll:SetPoint("TOPLEFT", f, "TOPLEFT", 130, y)
  f.descriptionScroll:SetWidth(610)
  f.descriptionScroll:SetHeight(275)
  f.descriptionScroll:EnableMouseWheel(true)
  f.descriptionEdit = AR:CreateCopyEditBox(f.descriptionScroll, 0, 0, 590, 1000, 1)
  f.descriptionScroll:SetScrollChild(f.descriptionEdit)
  f.descriptionScroll:SetScript("OnMouseWheel", function()
    local maxScroll = 1000 - this:GetHeight()
    local cur = this:GetVerticalScroll()
    if arg1 > 0 then cur = cur - 32 else cur = cur + 32 end
    this:SetVerticalScroll(Clamp(cur, 0, maxScroll))
  end)

  AR:MakeSmallButton(f, "Save", 130, -646, 82, 24, function()
    local f2 = AR.frames.questCopyEditor
    AR:SaveQuestCopyEdit(f2.catKey or "human", f2.questIndex or 1, {
      title=f2.titleEdit:GetText() or "",
      subtitle=f2.subtitleEdit:GetText() or "",
      objectiveText=f2.objectiveTextEdit:GetText() or "",
      objective1=f2.objective1Edit:GetText() or "",
      objective2=f2.objective2Edit:GetText() or "",
      objective3=f2.objective3Edit:GetText() or "",
      targetName=f2.targetNameEdit:GetText() or "",
      targetLocation=f2.targetLocationEdit:GetText() or "",
      rewardName=f2.rewardNameEdit:GetText() or "",
      rewardDetail=f2.rewardDetailEdit:GetText() or "",
      description=f2.descriptionEdit:GetText() or "",
    })
    f2:Hide()
    AR:RenderDevDialogue()
  end)
  AR:MakeSmallButton(f, "Dump Edits", 222, -646, 92, 24, function() AR:ShowCopyEditsDumpWindow() end)
  AR:MakeSmallButton(f, "Close", 658, -646, 82, 24, function() AR.frames.questCopyEditor:Hide() end)
  AR.frames.questCopyEditor = f
end

function AR:OpenQuestCopyEditor(catKey, questIndex)
  local q = AR:GetQuestList(catKey or "human")[questIndex or 1]
  if not q then return end
  AR:CreateQuestCopyEditorFrame()
  local f = AR.frames.questCopyEditor
  f.catKey = catKey or "human"
  f.questIndex = questIndex or 1
  f.header:SetText("Edit Quest Copy - " .. tostring(questIndex or 1) .. ": " .. (q.title or q.id or "Quest"))
  f.titleEdit:SetText(q.title or "")
  f.subtitleEdit:SetText(q.subtitle or "")
  f.objectiveTextEdit:SetText(q.objectiveText or "")
  f.objective1Edit:SetText(q.objectives and q.objectives[1] and q.objectives[1].text or "")
  f.objective2Edit:SetText(q.objectives and q.objectives[2] and q.objectives[2].text or "")
  f.objective3Edit:SetText(q.objectives and q.objectives[3] and q.objectives[3].text or "")
  f.targetNameEdit:SetText(q.targetName or "")
  f.targetLocationEdit:SetText(q.targetLocation or "")
  f.rewardNameEdit:SetText(q.rewardName or "")
  f.rewardDetailEdit:SetText(q.rewardDetail or "")
  f.descriptionEdit:SetText(q.description or "")
  f.descriptionScroll:SetVerticalScroll(0)
  f:Show()
end

function AR:BuildCopyEditsDumpText()
  AR:EnsureCopyEditDB()
  local lines = {}
  table.insert(lines, "ASHEN RELICS EDITED COPY DUMP")
  table.insert(lines, "Paste this into ChatGPT so it can be hardcoded into AshenRelics.lua.")
  table.insert(lines, "")

  local id, edit, k, key
  table.insert(lines, "=== QUEST COPY EDITS ===")
  local anyQuest = nil
  for id, edit in pairs(AshenRelicsDB.copyEdits.quests or {}) do
    anyQuest = 1
    table.insert(lines, "")
    table.insert(lines, "[QUEST " .. tostring(id) .. "]")
    local ordered = {"title","subtitle","objectiveText","objective1","objective2","objective3","description","targetName","targetLocation","rewardName","rewardDetail"}
    local i, field
    for i = 1, table.getn(ordered) do
      field = ordered[i]
      if edit[field] ~= nil then
        table.insert(lines, field .. " = " .. AR:LuaQuote(edit[field]))
      end
    end
  end
  if not anyQuest then table.insert(lines, "No quest copy edits saved yet.") end

  table.insert(lines, "")
  table.insert(lines, "=== NPC DIALOGUE COPY EDITS ===")
  local anyDialogue = nil
  for key, edit in pairs(AshenRelicsDB.copyEdits.dialogue or {}) do
    anyDialogue = 1
    table.insert(lines, "")
    table.insert(lines, "[DIALOGUE " .. tostring(key) .. "]")
    local ordered = {"title","subtitle","button","body"}
    local i, field
    for i = 1, table.getn(ordered) do
      field = ordered[i]
      if edit[field] ~= nil then
        table.insert(lines, field .. " = " .. AR:LuaQuote(edit[field]))
      end
    end
  end
  if not anyDialogue then table.insert(lines, "No dialogue copy edits saved yet.") end

  return table.concat(lines, "\n")
end

function AR:CreateCopyEditsDumpWindow()
  if AR.frames.copyEditsDump then return end
  local f = CreateFrame("Frame", "AshenRelicsCopyEditsDumpFrame", UIParent)
  f:SetWidth(790)
  f:SetHeight(620)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  f:SetFrameStrata("DIALOG")
  f:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=1, tileSize=32, edgeSize=32, insets={left=8,right=8,top=8,bottom=8}})
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:Hide()

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", f, "TOP", 0, -18)
  title:SetText("Edited Copy Dump")
  local help = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  help:SetPoint("TOPLEFT", f, "TOPLEFT", 32, -45)
  help:SetWidth(720)
  help:SetJustifyH("LEFT")
  help:SetText("Click inside the box, Ctrl+A, then Ctrl+C. Paste it into ChatGPT for hardcoding.")

  f.scroll = CreateFrame("ScrollFrame", nil, f)
  f.scroll:SetPoint("TOPLEFT", f, "TOPLEFT", 32, -75)
  f.scroll:SetWidth(720)
  f.scroll:SetHeight(470)
  f.scroll:EnableMouseWheel(true)
  f.edit = AR:CreateCopyEditBox(f.scroll, 0, 0, 700, 1600, 1)
  f.edit:SetScript("OnEditFocusGained", function() this:HighlightText() end)
  f.scroll:SetScrollChild(f.edit)
  f.scroll:SetScript("OnMouseWheel", function()
    local maxScroll = 1600 - this:GetHeight()
    local cur = this:GetVerticalScroll()
    if arg1 > 0 then cur = cur - 42 else cur = cur + 42 end
    this:SetVerticalScroll(Clamp(cur, 0, maxScroll))
  end)
  AR:MakeSmallButton(f, "Select All", 32, -568, 92, 24, function() AR.frames.copyEditsDump.edit:SetFocus(); AR.frames.copyEditsDump.edit:HighlightText() end)
  AR:MakeSmallButton(f, "Refresh", 134, -568, 82, 24, function() AR:ShowCopyEditsDumpWindow() end)
  AR:MakeSmallButton(f, "Close", 670, -568, 82, 24, function() AR.frames.copyEditsDump:Hide() end)
  AR.frames.copyEditsDump = f
end

function AR:ShowCopyEditsDumpWindow()
  AR:CreateCopyEditsDumpWindow()
  local f = AR.frames.copyEditsDump
  f.edit:SetText(AR:BuildCopyEditsDumpText())
  f.scroll:SetVerticalScroll(0)
  f:Show()
  f.edit:SetFocus()
  f.edit:HighlightText()
end

function AR:GetHumanQ1RecorderDB()
  if not AshenRelicsDB.dev then AshenRelicsDB.dev = {} end
  if not AshenRelicsDB.dev.humanQ1SearchSpots then AshenRelicsDB.dev.humanQ1SearchSpots = {} end
  return AshenRelicsDB.dev.humanQ1SearchSpots
end

function AR:GetHumanLocalSearchRecorderDB()
  if not AshenRelicsDB.dev then AshenRelicsDB.dev = {} end
  if not AshenRelicsDB.dev.humanLocalSearchSpots then AshenRelicsDB.dev.humanLocalSearchSpots = {} end
  return AshenRelicsDB.dev.humanLocalSearchSpots
end

function AR:GetHumanSearchRecorderEntries()
  local entries = {}
  local i
  for i = 1, table.getn(AR.humanQ1SearchSpots or {}) do
    local spot = AR.humanQ1SearchSpots[i]
    table.insert(entries, {
      kind="q1",
      index=i,
      label="Q1-" .. i,
      title=(spot and spot.name) or ("Strongbox " .. i),
      spot=spot,
    })
  end

  local q4Count = 0
  for i = 1, table.getn(AR.humanLocalSearchOrder or {}) do
    local key = AR.humanLocalSearchOrder[i]
    local spot = AR.humanLocalSearchSpots and AR.humanLocalSearchSpots[key]
    if spot then
      local label = "Q" .. tostring(spot.questIndex or "?")
      if spot.questIndex == 4 then
        q4Count = q4Count + 1
        if q4Count == 1 then
          label = "Q4a"
        elseif q4Count == 2 then
          label = "Q4b"
        else
          label = "Q4c"
        end
      end
      table.insert(entries, {
        kind="local",
        key=key,
        index=i,
        label=label,
        title=spot.name or key,
        spot=spot,
      })
    end
  end
  return entries
end

function AR:GetHumanSearchRecorderEntry(slot)
  local entries = AR:GetHumanSearchRecorderEntries()
  return entries[slot or 1], entries
end

function AR:GetHumanSearchRecorderSaved(entry)
  if not entry then return nil end
  if entry.kind == "q1" then
    local db = AR:GetHumanQ1RecorderDB()
    return db[entry.index]
  end
  if entry.kind == "local" then
    local db = AR:GetHumanLocalSearchRecorderDB()
    return db[entry.key]
  end
  return nil
end

function AR:SetHumanSearchRecorderSaved(entry, value)
  if not entry then return end
  if entry.kind == "q1" then
    local db = AR:GetHumanQ1RecorderDB()
    db[entry.index] = value
  elseif entry.kind == "local" then
    local db = AR:GetHumanLocalSearchRecorderDB()
    db[entry.key] = value
  end
end

function AR:GetHumanSearchRecorderSpot(slot)
  local entry = AR:GetHumanSearchRecorderEntry(slot)
  if not entry then return nil, nil end
  local saved = AR:GetHumanSearchRecorderSaved(entry)
  if saved and saved.x and saved.y then return AR:MergeSearchSpotWithSaved(entry.spot, saved), entry end
  return entry.spot, entry
end

function AR:GetHumanSearchRecorderClueText(entry)
  if not entry then return "No search point selected." end
  local spot = entry.spot or {}
  local lines = {}
  table.insert(lines, "Clue for " .. (entry.label or "?") .. ":")

  if entry.kind == "q1" then
    table.insert(lines, "Strongbox manifest sequence:")
    local i
    for i = 1, table.getn(AR.humanQ1ManifestResults or {}) do
      local result = AR.humanQ1ManifestResults[i]
      if result and result.title then table.insert(lines, i .. ". " .. result.title) end
    end
  else
    if spot.resultTitle then table.insert(lines, spot.resultTitle) end
    if spot.resultBody then table.insert(lines, spot.resultBody) end
    if spot.searchGroup == "living_measure_salvage" then
      table.insert(lines, "After both salvage searches: Suspicious Goblin becomes the next lead.")
    end
    if spot.noAutoAward then table.insert(lines, "Dev note: this records a search clue but does not award the item.") end
    if spot.requiresFlag then table.insert(lines, "Unlocks after flag: " .. spot.requiresFlag) end
    if spot.searchGroup then table.insert(lines, "Search group: " .. spot.searchGroup) end
  end

  return table.concat(lines, "\n")
end

function AR:GetStoryAreaBeatForLocalSpot(key)
  if not key then return nil end
  local i
  for i = 1, table.getn(AR.storyAreaBeats or {}) do
    local beat = AR.storyAreaBeats[i]
    if beat and beat.localSpotKey == key then return beat end
  end
  return nil
end

function AR:UpdateHumanSearchRecorderClue()
  local f = AR.frames.humanQ1Recorder
  if not f or not f.clueText then return end
  local entry = AR:GetHumanSearchRecorderEntry(AR.humanSearchRecorderSlot or AR.humanQ1RecorderSlot or 1)
  f.clueText:SetText(AR:GetHumanSearchRecorderClueText(entry))
end

function AR:UpdateHumanQ1RecorderText()
  local f = AR.frames.humanQ1Recorder
  if not f or not f.lines then return end
  local entries = AR:GetHumanSearchRecorderEntries()
  local i
  for i = 1, table.getn(f.lines) do
    if f.lines[i] then f.lines[i]:SetText("") end
  end
  for i = 1, table.getn(entries) do
    local entry = entries[i]
    local spot = entry and entry.spot
    local saved = AR:GetHumanSearchRecorderSaved(entry)
    local prefix = (entry.label or tostring(i)) .. " = " .. (entry.title or "Search Location")
    if saved and saved.x and saved.y then
      local sx = AR:NormalizeMapCoord(saved.x) or 0
      local sy = AR:NormalizeMapCoord(saved.y) or 0
      f.lines[i]:SetText(prefix .. "\n" .. (saved.zone or "") .. "  " .. string.format("%.2f", sx * 100) .. ", " .. string.format("%.2f", sy * 100))
    else
      local zone = spot and spot.zone or ""
      local sx = AR:NormalizeMapCoord(spot and spot.x) or 0
      local sy = AR:NormalizeMapCoord(spot and spot.y) or 0
      f.lines[i]:SetText(prefix .. "\nCurrent " .. zone .. "  " .. string.format("%.2f", sx * 100) .. ", " .. string.format("%.2f", sy * 100))
    end
    if f.slotButtons and f.slotButtons[i] then
      if AR.humanSearchRecorderSlot == i then
        f.slotButtons[i].text:SetTextColor(1, 0.82, 0)
      else
        f.slotButtons[i].text:SetTextColor(0.9, 0.9, 0.9)
      end
    end
  end
end

function AR:GetHumanQ1RecorderDebugSpot(index)
  local spot = AR:GetHumanSearchRecorderSpot(index)
  return spot
end

function AR:UpdateHumanQ1RecorderDebug()
  local f = AR.frames.humanQ1Recorder
  if not f or not f.debugText then return end
  local zone = AR:GetCurrentZoneName()
  local px, py = AR:GetPlayerMapPositionSafe()
  local lines = {}

  if px and py then
    table.insert(lines, "Current: " .. zone .. "  " .. string.format("%.2f", px * 100) .. ", " .. string.format("%.2f", py * 100))
  else
    table.insert(lines, "Current: coordinates unavailable")
  end

  local selected = AR.humanSearchRecorderSlot or 1
  local entries = AR:GetHumanSearchRecorderEntries()
  local start = selected - 2
  if start < 1 then start = 1 end
  local stop = start + 5
  if stop > table.getn(entries) then stop = table.getn(entries) end
  if stop - start < 5 then
    start = stop - 5
    if start < 1 then start = 1 end
  end

  local i
  for i = start, stop do
    local spot, entry = AR:GetHumanSearchRecorderSpot(i)
    local name = (entry and entry.label or tostring(i)) .. " " .. (entry and entry.title or "Search")
    local radius = (spot and spot.radius) or 0.0018
    local state = "hide"
    local distanceText = "n/a"
    if px and py and spot and zone == spot.zone then
      local distance = AR:GetSpotDistanceFromPlayer(spot, px, py)
      if distance then
        distanceText = string.format("%.4f", distance)
        if distance <= radius then state = "SHOW" end
      end
    elseif spot and zone ~= spot.zone then
      state = "hide wrong zone"
    end
    if i == selected then name = "> " .. name end
    local proximityText = ""
    if entry and entry.kind == "local" then
      local beat = AR:GetStoryAreaBeatForLocalSpot(entry.key)
      if beat then proximityText = " prox" end
    end
    table.insert(lines, i .. " " .. name .. ": d=" .. distanceText .. " r=" .. string.format("%.4f", radius) .. " " .. state .. proximityText)
  end

  f.debugText:SetText(table.concat(lines, "\n"))
end

function AR:SelectHumanQ1RecorderSlot(index)
  AR.humanSearchRecorderSlot = index
  AR.humanQ1RecorderSlot = index
  AR:UpdateHumanQ1RecorderText()
  AR:UpdateHumanSearchRecorderClue()
  AR:UpdateHumanQ1RecorderDebug()
end

function AR:RecordHumanQ1Location()
  local slot = AR.humanSearchRecorderSlot or AR.humanQ1RecorderSlot or 1
  local entry = AR:GetHumanSearchRecorderEntry(slot)
  if not entry then return end
  local x, y = AR:GetPlayerMapPositionSafe()
  if not x or not y then
    DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics Dev:|r could not read player map coordinates.")
    return
  end

  local spot = entry.spot or {}
  local saved = AR:GetHumanSearchRecorderSaved(entry)
  AR:SetHumanSearchRecorderSaved(entry, {
    key=entry.key,
    kind=entry.kind,
    questIndex=spot.questIndex,
    name=spot.name or entry.title or ("Slot " .. slot),
    zone=AR:GetCurrentZoneName(),
    x=x,
    y=y,
    radius=(saved and saved.radiusTuned and saved.radius) or spot.radius or 0.0018,
    radiusTuned=saved and saved.radiusTuned,
  })
  AR:UpdateHumanQ1RecorderText()
  AR:UpdateHumanQ1RecorderDebug()
  DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics Dev:|r recorded " .. (entry.label or tostring(slot)) .. " at " .. string.format("%.2f", x * 100) .. ", " .. string.format("%.2f", y * 100) .. ".")
end

function AR:AdjustHumanSearchRadius(delta)
  local slot = AR.humanSearchRecorderSlot or AR.humanQ1RecorderSlot or 1
  local entry = AR:GetHumanSearchRecorderEntry(slot)
  if not entry then return end

  local saved = AR:GetHumanSearchRecorderSaved(entry)
  local base = entry.spot or {}
  local source = saved or base
  if not source.x or not source.y then
    DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics Dev:|r record the selected location before changing its radius.")
    return
  end

  local radius = (source.radius or base.radius or 0.0018) + (delta or 0)
  if radius < 0.0005 then radius = 0.0005 end
  if radius > 0.0500 then radius = 0.0500 end

  AR:SetHumanSearchRecorderSaved(entry, {
    key=entry.key,
    kind=entry.kind,
    questIndex=base.questIndex,
    name=source.name or base.name or entry.title or ("Slot " .. slot),
    zone=source.zone or base.zone,
    x=source.x,
    y=source.y,
    radius=radius,
    radiusTuned=1,
  })

  AR:UpdateHumanQ1RecorderText()
  AR:UpdateHumanQ1RecorderDebug()
  DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics Dev:|r " .. (entry.label or tostring(slot)) .. " radius now " .. string.format("%.4f", radius) .. ".")
end

function AR:ClearHumanQ1RecordedLocation()
  local slot = AR.humanSearchRecorderSlot or AR.humanQ1RecorderSlot or 1
  local entry = AR:GetHumanSearchRecorderEntry(slot)
  AR:SetHumanSearchRecorderSaved(entry, nil)
  AR:UpdateHumanQ1RecorderText()
  AR:UpdateHumanQ1RecorderDebug()
  DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics Dev:|r cleared " .. ((entry and entry.label) or tostring(slot)) .. ".")
end

function AR:DumpHumanSearchEntry(entry, slot)
  if not entry then return end
  local saved = AR:GetHumanSearchRecorderSaved(entry)
  local spot = AR:MergeSearchSpotWithSaved(entry.spot, saved) or entry.spot or {}
  local sx = AR:NormalizeMapCoord(spot.x) or 0
  local sy = AR:NormalizeMapCoord(spot.y) or 0
  local radius = spot.radius or (entry.spot and entry.spot.radius) or 0.0018

  if entry.kind == "q1" then
    local base = entry.spot or {}
    DEFAULT_CHAT_FRAME:AddMessage("  [" .. entry.index .. "] = {")
    DEFAULT_CHAT_FRAME:AddMessage("    name = " .. AR:LuaQuote(base.name or spot.name or entry.title) .. ",")
    DEFAULT_CHAT_FRAME:AddMessage("    zone = " .. AR:LuaQuote(spot.zone or base.zone or "") .. ",")
    DEFAULT_CHAT_FRAME:AddMessage("    x = " .. string.format("%.2f", sx * 100) .. ",")
    DEFAULT_CHAT_FRAME:AddMessage("    y = " .. string.format("%.2f", sy * 100) .. ",")
    DEFAULT_CHAT_FRAME:AddMessage("    radius = " .. string.format("%.4f", radius) .. ",")
    DEFAULT_CHAT_FRAME:AddMessage("    buttonText = " .. AR:LuaQuote(base.buttonText or "Unlock Strongbox") .. ",")
    DEFAULT_CHAT_FRAME:AddMessage("    tooltipName = \"Buccaneer's Strongbox\",")
    DEFAULT_CHAT_FRAME:AddMessage("    requiredItemKey = \"cargo_key\",")
    DEFAULT_CHAT_FRAME:AddMessage("    itemKey = \"manifest\",")
    DEFAULT_CHAT_FRAME:AddMessage("  },")
  elseif entry.kind == "local" then
    local base = entry.spot or {}
    DEFAULT_CHAT_FRAME:AddMessage("  " .. entry.key .. " = {")
    DEFAULT_CHAT_FRAME:AddMessage("    questIndex = " .. tostring(base.questIndex or spot.questIndex or 0) .. ",")
    DEFAULT_CHAT_FRAME:AddMessage("    itemKey = " .. AR:LuaQuote(base.itemKey or "") .. ",")
    if base.noAutoAward then DEFAULT_CHAT_FRAME:AddMessage("    noAutoAward = 1,") end
    if base.requiresFlag then DEFAULT_CHAT_FRAME:AddMessage("    requiresFlag = " .. AR:LuaQuote(base.requiresFlag) .. ",") end
    if base.searchGroup then DEFAULT_CHAT_FRAME:AddMessage("    searchGroup = " .. AR:LuaQuote(base.searchGroup) .. ",") end
    DEFAULT_CHAT_FRAME:AddMessage("    name = " .. AR:LuaQuote(base.name or spot.name or entry.title) .. ",")
    DEFAULT_CHAT_FRAME:AddMessage("    zone = " .. AR:LuaQuote(spot.zone or base.zone or "") .. ",")
    DEFAULT_CHAT_FRAME:AddMessage("    x = " .. string.format("%.2f", sx * 100) .. ",")
    DEFAULT_CHAT_FRAME:AddMessage("    y = " .. string.format("%.2f", sy * 100) .. ",")
    DEFAULT_CHAT_FRAME:AddMessage("    radius = " .. string.format("%.4f", radius) .. ",")
    DEFAULT_CHAT_FRAME:AddMessage("    buttonText = " .. AR:LuaQuote(base.buttonText or ("Search " .. (base.name or entry.title))) .. ",")
    DEFAULT_CHAT_FRAME:AddMessage("    tooltipHelp = " .. AR:LuaQuote(base.tooltipHelp or "") .. ",")
    if base.resultTitle then DEFAULT_CHAT_FRAME:AddMessage("    resultTitle = " .. AR:LuaQuote(base.resultTitle) .. ",") end
    if base.resultBody then DEFAULT_CHAT_FRAME:AddMessage("    resultBody = " .. AR:LuaQuote(base.resultBody) .. ",") end
    if base.toastTitle then DEFAULT_CHAT_FRAME:AddMessage("    toastTitle = " .. AR:LuaQuote(base.toastTitle) .. ",") end
    if base.toastBody then DEFAULT_CHAT_FRAME:AddMessage("    toastBody = " .. AR:LuaQuote(base.toastBody) .. ",") end
    DEFAULT_CHAT_FRAME:AddMessage("  },")
  end
end

function AR:DumpSelectedHumanSearchLocation()
  local slot = AR.humanSearchRecorderSlot or AR.humanQ1RecorderSlot or 1
  local entry = AR:GetHumanSearchRecorderEntry(slot)
  if not entry then return end
  DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics Dev:|r selected search location dump:")
  AR:DumpHumanSearchEntry(entry, slot)
end

function AR:DumpHumanQ1SearchLocations()
  local i
  DEFAULT_CHAT_FRAME:AddMessage("AR_HUMAN_Q1_SEARCH_SPOTS = {")
  DEFAULT_CHAT_FRAME:AddMessage("  -- NOTE: Ship interiors are still 2D map coordinates in Vanilla.")
  DEFAULT_CHAT_FRAME:AddMessage("  -- Do not stack spots above/below each other at the same X/Y.")
  DEFAULT_CHAT_FRAME:AddMessage("  -- Strongbox unlocks also require the Buccaneer's Strongbox tooltip and the cargo key.")
  local entries = AR:GetHumanSearchRecorderEntries()
  for i = 1, table.getn(entries) do
    if entries[i].kind == "q1" then AR:DumpHumanSearchEntry(entries[i], i) end
  end
  DEFAULT_CHAT_FRAME:AddMessage("}")

  DEFAULT_CHAT_FRAME:AddMessage("AR_HUMAN_LOCAL_SEARCH_SPOTS = {")
  for i = 1, table.getn(entries) do
    if entries[i].kind == "local" then AR:DumpHumanSearchEntry(entries[i], i) end
  end
  DEFAULT_CHAT_FRAME:AddMessage("}")
end

function AR:CreateHumanQ1RecorderFrame()
  if AR.frames.humanQ1Recorder then return end
  AR.humanSearchRecorderSlot = AR.humanSearchRecorderSlot or AR.humanQ1RecorderSlot or 1
  AR.humanQ1RecorderSlot = AR.humanSearchRecorderSlot

  local f = CreateFrame("Frame", "AshenRelicsHumanQ1Recorder", UIParent)
  f:SetWidth(520)
  f:SetHeight(545)
  f:SetPoint("CENTER", UIParent, "CENTER", 360, 40)
  f:SetFrameStrata("DIALOG")
  f:SetBackdrop({
    bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
    tile=1, tileSize=32, edgeSize=32,
    insets={left=8,right=8,top=8,bottom=8}
  })
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:Hide()

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", f, "TOP", 0, -18)
  title:SetText("Search Location Recorder")

  f.slotButtons = {}
  f.lines = {}
  local entries = AR:GetHumanSearchRecorderEntries()
  local i
  for i = 1, table.getn(entries) do
    local col = math.mod(i - 1, 5)
    local row = math.floor((i - 1) / 5)
    local b = AR:MakeSmallButton(f, entries[i].label or tostring(i), 24 + (col * 58), -50 - (row * 30), 52, 24, function() AR:SelectHumanQ1RecorderSlot(this.slotIndex) end)
    b.slotIndex = i
    f.slotButtons[i] = b

    local line = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -118 - ((i - 1) * 34))
    line:SetWidth(280)
    line:SetHeight(32)
    line:SetJustifyH("LEFT")
    line:SetJustifyV("TOP")
    f.lines[i] = line
  end

  local warning = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  warning:SetPoint("TOPLEFT", f, "TOPLEFT", 318, -50)
  warning:SetWidth(175)
  warning:SetHeight(54)
  warning:SetJustifyH("LEFT")
  warning:SetJustifyV("TOP")
  warning:SetText("Pick any search point.\nRadius changes live.\nShift = fine step.")

  local clueText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  clueText:SetPoint("TOPLEFT", f, "TOPLEFT", 318, -108)
  clueText:SetWidth(176)
  clueText:SetHeight(272)
  clueText:SetJustifyH("LEFT")
  clueText:SetJustifyV("TOP")
  f.clueText = clueText

  local debugText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  debugText:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -392)
  debugText:SetWidth(470)
  debugText:SetHeight(86)
  debugText:SetJustifyH("LEFT")
  debugText:SetJustifyV("TOP")
  f.debugText = debugText

  AR:MakeSmallButton(f, "Record Current Location", 24, -488, 146, 24, function() AR:RecordHumanQ1Location() end)
  AR:MakeSmallButton(f, "Radius -", 176, -488, 68, 24, function()
    local step = 0.0005
    if IsShiftKeyDown and IsShiftKeyDown() then step = 0.0001 end
    AR:AdjustHumanSearchRadius(-step)
  end)
  AR:MakeSmallButton(f, "Radius +", 250, -488, 68, 24, function()
    local step = 0.0005
    if IsShiftKeyDown and IsShiftKeyDown() then step = 0.0001 end
    AR:AdjustHumanSearchRadius(step)
  end)
  AR:MakeSmallButton(f, "Dump Selected", 324, -488, 104, 24, function() AR:DumpSelectedHumanSearchLocation() end)
  AR:MakeSmallButton(f, "Dump All", 434, -488, 70, 24, function() AR:DumpHumanQ1SearchLocations() end)
  AR:MakeSmallButton(f, "Clear", 24, -516, 70, 22, function() AR:ClearHumanQ1RecordedLocation() end)
  AR:MakeSmallButton(f, "Close", 424, -516, 70, 22, function() AR.frames.humanQ1Recorder:Hide() end)

  f.elapsed = 0
  f:SetScript("OnUpdate", function()
    this.elapsed = (this.elapsed or 0) + (arg1 or 0)
    if this.elapsed >= 0.25 then
      this.elapsed = 0
      AR:UpdateHumanQ1RecorderDebug()
    end
  end)

  AR.frames.humanQ1Recorder = f
  AR:UpdateHumanQ1RecorderText()
  AR:UpdateHumanSearchRecorderClue()
  AR:UpdateHumanQ1RecorderDebug()
end

function AR:ToggleHumanQ1Recorder()
  AR:CreateHumanQ1RecorderFrame()
  if AR.frames.humanQ1Recorder:IsShown() then
    AR.frames.humanQ1Recorder:Hide()
  else
    AR.frames.humanQ1Recorder:Show()
    AR:UpdateHumanQ1RecorderText()
    AR:UpdateHumanSearchRecorderClue()
    AR:UpdateHumanQ1RecorderDebug()
  end
end

function AR:GetStoryReturnBeat(index)
  if not index then return nil end
  return AR.storyReturnBeats and AR.storyReturnBeats[index]
end

function AR:UpdateStoryBeatRecorderText()
  local f = AR.frames.storyBeatRecorder
  if not f or not f.lines then return end
  local db = AR:GetStoryBeatPointDB()
  local i
  for i = 1, table.getn(AR.storyReturnBeats or {}) do
    local beat = AR.storyReturnBeats[i]
    local saved = beat and db[beat.id]
    local point = saved or AR:GetStoryReturnPoint(beat)
    local label = (beat and beat.label) or ("Beat " .. i)
    if point and point.x and point.y then
      local sx = AR:NormalizeMapCoord(point.x) or 0
      local sy = AR:NormalizeMapCoord(point.y) or 0
      local source = "default"
      if saved then source = "recorded" end
      f.lines[i]:SetText(i .. " = " .. label .. "\n" .. source .. "  " .. (point.zone or "") .. "  " .. string.format("%.2f", sx * 100) .. ", " .. string.format("%.2f", sy * 100))
    else
      f.lines[i]:SetText(i .. " = " .. label .. "\nNot recorded")
    end
    if f.slotButtons and f.slotButtons[i] then
      if AR.storyBeatRecorderSlot == i then
        f.slotButtons[i].text:SetTextColor(1, 0.82, 0)
      else
        f.slotButtons[i].text:SetTextColor(0.9, 0.9, 0.9)
      end
    end
  end
end

function AR:UpdateStoryBeatRecorderDebug()
  local f = AR.frames.storyBeatRecorder
  if not f or not f.debugText then return end
  local beat = AR:GetStoryReturnBeat(AR.storyBeatRecorderSlot or 1)
  if not beat then
    f.debugText:SetText("No return beat selected.")
    return
  end

  local zone = AR:GetCurrentZoneName()
  local px, py = AR:GetPlayerMapPositionSafe()
  local point = AR:GetStoryReturnPoint(beat)
  local lines = {}
  if px and py then
    table.insert(lines, "Current: " .. zone .. "  " .. string.format("%.2f", px * 100) .. ", " .. string.format("%.2f", py * 100))
  else
    table.insert(lines, "Current: coordinates unavailable")
  end

  local returnRadius = AR:GetStoryReturnRadius(beat, point)
  local inside, distance = AR:IsPlayerInsideStoryPoint(point, returnRadius)
  local distanceText = "n/a"
  if distance then distanceText = string.format("%.4f", distance) end
  local ready = "not ready"
  if AR:IsStoryBeatObjectiveReady(beat) then ready = "READY" end
  local fired = "not fired"
  if AshenRelicsDB.flavor and AshenRelicsDB.flavor["story_return_" .. beat.id] then fired = "already fired" end
  local state = "outside"
  if inside then state = "INSIDE" end

  table.insert(lines, beat.label or beat.id)
  table.insert(lines, "Point: " .. state .. "  d=" .. distanceText .. "  r=" .. string.format("%.4f", returnRadius))
  table.insert(lines, "Trigger: " .. ready .. "  " .. fired)
  f.debugText:SetText(table.concat(lines, "\n"))
end

function AR:SelectStoryBeatRecorderSlot(index)
  AR.storyBeatRecorderSlot = index
  AR:UpdateStoryBeatRecorderText()
  AR:UpdateStoryBeatRecorderDebug()
end

function AR:RecordStoryBeatLocation()
  local slot = AR.storyBeatRecorderSlot or 1
  local beat = AR:GetStoryReturnBeat(slot)
  if not beat then return end
  local x, y = AR:GetPlayerMapPositionSafe()
  if not x or not y then
    DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics Dev:|r could not read player map coordinates.")
    return
  end

  local db = AR:GetStoryBeatPointDB()
  db[beat.id] = {
    label=beat.label or beat.id,
    zone=AR:GetCurrentZoneName(),
    x=x,
    y=y,
    radius=beat.radius or 0.004,
  }
  AR.storyReturnInside = {}
  AR:UpdateStoryBeatRecorderText()
  AR:UpdateStoryBeatRecorderDebug()
  DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics Dev:|r recorded " .. (beat.label or beat.id) .. " at " .. string.format("%.2f", x * 100) .. ", " .. string.format("%.2f", y * 100) .. ".")
end

function AR:ClearStoryBeatLocation()
  local slot = AR.storyBeatRecorderSlot or 1
  local beat = AR:GetStoryReturnBeat(slot)
  if not beat then return end
  local db = AR:GetStoryBeatPointDB()
  db[beat.id] = nil
  AR.storyReturnInside = {}
  AR:UpdateStoryBeatRecorderText()
  AR:UpdateStoryBeatRecorderDebug()
  DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics Dev:|r cleared " .. (beat.label or beat.id) .. ".")
end

function AR:TestStoryBeatLocation()
  local slot = AR.storyBeatRecorderSlot or 1
  local beat = AR:GetStoryReturnBeat(slot)
  if not beat then return end
  local point = AR:GetStoryReturnPoint(beat)
  local inside = AR:IsPlayerInsideStoryPoint(point, AR:GetStoryReturnRadius(beat, point))
  local ready = AR:IsStoryBeatObjectiveReady(beat)
  local msg = "|cffb43a2aAshen Relics Dev:|r " .. (beat.label or beat.id) .. " would "
  if inside and ready then
    msg = msg .. "fire on crossing."
  elseif not inside then
    msg = msg .. "not fire: outside point."
  else
    msg = msg .. "not fire: quest/objective not ready."
  end
  DEFAULT_CHAT_FRAME:AddMessage(msg)
end

function AR:ClearStoryBeatFired(beat)
  if not beat then return end
  AR:EnsureFlavorDB()
  AshenRelicsDB.flavor["story_return_" .. beat.id] = nil
  if AR.storyReturnInside then AR.storyReturnInside[beat.id] = nil end
end

function AR:StageStoryBeatForTest()
  local slot = AR.storyBeatRecorderSlot or 1
  local beat = AR:GetStoryReturnBeat(slot)
  if not beat or not beat.questIndex then return end

  local q = AR:GetQuestList("human")[beat.questIndex]
  if not q then return end
  if not AshenRelicsDB.completed then AshenRelicsDB.completed = {} end
  if not AshenRelicsDB.items then AshenRelicsDB.items = {} end

  AshenRelicsDB.completed[q.id] = nil
  AR:SetQuestAccepted("human", beat.questIndex, 1)

  if beat.readyType == "humanQ1" then
    AshenRelicsDB.items.cargo_key = 1
    AshenRelicsDB.items.manifest = AR:GetHumanQ1SearchRequired()
    local searchDB = AR:GetHumanQ1SearchDB()
    local i
    for i = 1, table.getn(AR.humanQ1SearchSpots) do
      searchDB[i] = AR:GetHumanQ1SpotRequired(i)
    end
  elseif beat.itemKey then
    local count = beat.itemCount or 1
    if (AshenRelicsDB.items[beat.itemKey] or 0) < count then
      AshenRelicsDB.items[beat.itemKey] = count
    end
  end

  AR:ClearStoryBeatFired(beat)
  AR.storyReturnInside = {}
  AR.activeCategory = 1
  AR.activeQuest = beat.questIndex
  AR.activeEvidenceQuest = nil

  if AR.frames and AR.frames.bag then AR:RefreshBag() end
  AR:RenderSidebar()
  AR:RenderQuestDetail()
  AR:UpdateQuestOverlays()
  AR:UpdateStoryBeatRecorderDebug()

  DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics Dev:|r staged " .. (beat.label or beat.id) .. " as ready. Cross the point again, or use Force /say.")
end

function AR:ResetStoryBeatFired()
  local slot = AR.storyBeatRecorderSlot or 1
  local beat = AR:GetStoryReturnBeat(slot)
  if not beat then return end
  AR:ClearStoryBeatFired(beat)
  AR:UpdateStoryBeatRecorderDebug()
  DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics Dev:|r reset fired flag for " .. (beat.label or beat.id) .. ".")
end

function AR:ForceStoryBeatSay()
  local slot = AR.storyBeatRecorderSlot or 1
  local beat = AR:GetStoryReturnBeat(slot)
  if not beat then return end
  local line = beat.saySolo
  if AR:HasNearbyPartyMember() and beat.sayParty then line = beat.sayParty end
  if not line or line == "" then return end

  if SendChatMessage then
    SendChatMessage(line, "SAY")
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cffffffff" .. line .. "|r")
  end
  DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics Dev:|r forced /say for " .. (beat.label or beat.id) .. " without setting its fired flag.")
end

function AR:DumpStoryBeatLocations()
  local db = AR:GetStoryBeatPointDB()
  local found = nil
  local i
  for i = 1, table.getn(AR.storyReturnBeats or {}) do
    local beat = AR.storyReturnBeats[i]
    if beat and db[beat.id] and db[beat.id].x and db[beat.id].y then found = 1 end
  end
  if not found then
    DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics Dev:|r no recorded story beat points to dump.")
    return
  end

  DEFAULT_CHAT_FRAME:AddMessage("AR_STORY_RETURN_POINTS = {")
  for i = 1, table.getn(AR.storyReturnBeats or {}) do
    local beat = AR.storyReturnBeats[i]
    local saved = beat and db[beat.id]
    if saved and saved.x and saved.y then
      local sx = AR:NormalizeMapCoord(saved.x) or 0
      local sy = AR:NormalizeMapCoord(saved.y) or 0
      DEFAULT_CHAT_FRAME:AddMessage("  " .. beat.id .. " = {")
      DEFAULT_CHAT_FRAME:AddMessage("    zone = " .. AR:LuaQuote(saved.zone or "") .. ",")
      DEFAULT_CHAT_FRAME:AddMessage("    x = " .. string.format("%.2f", sx * 100) .. ",")
      DEFAULT_CHAT_FRAME:AddMessage("    y = " .. string.format("%.2f", sy * 100) .. ",")
      DEFAULT_CHAT_FRAME:AddMessage("    radius = " .. string.format("%.4f", AR:GetStoryReturnRadius(beat, saved)) .. ",")
      DEFAULT_CHAT_FRAME:AddMessage("  },")
    end
  end
  DEFAULT_CHAT_FRAME:AddMessage("}")
end

function AR:CreateStoryBeatRecorderFrame()
  if AR.frames.storyBeatRecorder then return end
  AR.storyBeatRecorderSlot = AR.storyBeatRecorderSlot or 1

  local f = CreateFrame("Frame", "AshenRelicsStoryBeatRecorder", UIParent)
  f:SetWidth(470)
  f:SetHeight(520)
  f:SetPoint("CENTER", UIParent, "CENTER", 350, 8)
  f:SetFrameStrata("DIALOG")
  f:SetBackdrop({
    bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
    tile=1, tileSize=32, edgeSize=32,
    insets={left=8,right=8,top=8,bottom=8}
  })
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:Hide()

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", f, "TOP", 0, -18)
  title:SetText("Story Beat Return Recorder")

  f.slotButtons = {}
  f.lines = {}
  local i
  for i = 1, table.getn(AR.storyReturnBeats or {}) do
    local col = math.mod(i - 1, 4)
    local row = math.floor((i - 1) / 4)
    local b = AR:MakeSmallButton(f, tostring(i), 24 + (col * 42), -48 - (row * 30), 32, 24, function() AR:SelectStoryBeatRecorderSlot(this.slotIndex) end)
    b.slotIndex = i
    f.slotButtons[i] = b

    local line = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -116 - ((i - 1) * 34))
    line:SetWidth(405)
    line:SetHeight(31)
    line:SetJustifyH("LEFT")
    line:SetJustifyV("TOP")
    f.lines[i] = line
  end

  local debugText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  debugText:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -394)
  debugText:SetWidth(420)
  debugText:SetHeight(58)
  debugText:SetJustifyH("LEFT")
  debugText:SetJustifyV("TOP")
  f.debugText = debugText

  AR:MakeSmallButton(f, "Record Current Location", 24, -462, 146, 24, function() AR:RecordStoryBeatLocation() end)
  AR:MakeSmallButton(f, "Stage Ready", 176, -462, 86, 24, function() AR:StageStoryBeatForTest() end)
  AR:MakeSmallButton(f, "Test Point", 268, -462, 82, 24, function() AR:TestStoryBeatLocation() end)
  AR:MakeSmallButton(f, "Dump Points", 356, -462, 86, 24, function() AR:DumpStoryBeatLocations() end)
  AR:MakeSmallButton(f, "Force /say", 24, -490, 86, 22, function() AR:ForceStoryBeatSay() end)
  AR:MakeSmallButton(f, "Reset Fired", 116, -490, 86, 22, function() AR:ResetStoryBeatFired() end)
  AR:MakeSmallButton(f, "Clear Point", 208, -490, 82, 22, function() AR:ClearStoryBeatLocation() end)
  AR:MakeSmallButton(f, "Close", 374, -490, 70, 22, function() AR.frames.storyBeatRecorder:Hide() end)

  f.elapsed = 0
  f:SetScript("OnUpdate", function()
    this.elapsed = (this.elapsed or 0) + (arg1 or 0)
    if this.elapsed >= 0.25 then
      this.elapsed = 0
      AR:UpdateStoryBeatRecorderDebug()
    end
  end)

  AR.frames.storyBeatRecorder = f
  AR:UpdateStoryBeatRecorderText()
  AR:UpdateStoryBeatRecorderDebug()
end

function AR:ToggleStoryBeatRecorder()
  AR:CreateStoryBeatRecorderFrame()
  if AR.frames.storyBeatRecorder:IsShown() then
    AR.frames.storyBeatRecorder:Hide()
  else
    AR.frames.storyBeatRecorder:Show()
    AR:UpdateStoryBeatRecorderText()
    AR:UpdateStoryBeatRecorderDebug()
  end
end

function AR:SnapshotDevDialogueDB()
  return {
    completed=AshenRelicsDB.completed,
    accepted=AshenRelicsDB.accepted,
    items=AshenRelicsDB.items,
    flags=AshenRelicsDB.flags,
  }
end

function AR:RestoreDevDialogueDB(saved)
  if not saved then return end
  AshenRelicsDB.completed = saved.completed
  AshenRelicsDB.accepted = saved.accepted
  AshenRelicsDB.items = saved.items
  AshenRelicsDB.flags = saved.flags
end

function AR:DevSetQuestComplete(index)
  local q = AR:GetQuestList("human")[index]
  if not q then return end
  AshenRelicsDB.completed[q.id] = 1
  AshenRelicsDB.accepted[q.id] = 1
end

function AR:DevSetQuestAccepted(index)
  local q = AR:GetQuestList("human")[index]
  if not q then return end
  AshenRelicsDB.accepted[q.id] = 1
end

function AR:ApplyDevDialogueScenario(scenario)
  AshenRelicsDB.completed = {}
  AshenRelicsDB.accepted = {}
  AshenRelicsDB.items = {}
  AshenRelicsDB.flags = {}

  AR:DevSetQuestAccepted(1)

  local i
  if scenario.completed then
    for i = 1, table.getn(scenario.completed) do
      AR:DevSetQuestComplete(scenario.completed[i])
    end
  end
  if scenario.accepted then
    for i = 1, table.getn(scenario.accepted) do
      AR:DevSetQuestAccepted(scenario.accepted[i])
    end
  end
  if scenario.items then
    local key, count
    for key, count in pairs(scenario.items) do
      AshenRelicsDB.items[key] = count
    end
  end
  if scenario.localSearches then
    AshenRelicsDB.flags.humanLocalSearches = {}
    local key, value
    for key, value in pairs(scenario.localSearches) do
      AshenRelicsDB.flags.humanLocalSearches[key] = value
    end
  end
  if scenario.flags then
    local key, value
    for key, value in pairs(scenario.flags) do
      AshenRelicsDB.flags[key] = value
    end
  end
  if scenario.q1Searches then
    AshenRelicsDB.flags.humanQ1StrongboxUnlocks = {}
    for i = 1, table.getn(AR.humanQ1SearchSpots) do
      AshenRelicsDB.flags.humanQ1StrongboxUnlocks[i] = AR:GetHumanQ1SpotRequired(i)
    end
  end
end

function AR:GetDevDialogueEntry(index)
  local scenario = AR.devDialogueScenarios and AR.devDialogueScenarios[index]
  if not scenario then return nil end

  local saved = AR:SnapshotDevDialogueDB()
  AR:ApplyDevDialogueScenario(scenario)
  local state = AR:GetNPCDialogueState(scenario.npc)
  AR:RestoreDevDialogueDB(saved)

  if not state then
    return {
      label=scenario.label or "Dialogue",
      kind=scenario.kind or "",
      npc=scenario.npc or "",
      button="",
      questIndex=scenario.questIndex or "",
      body="[No dialogue returned for this simulated state.]",
    }
  end

  local editKey = AR:GetDialogueEditKey(scenario.npc, state)
  state = AR:ApplyDialogueCopyEdit(editKey, state)

  return {
    label=scenario.label or state.title or "Dialogue",
    kind=scenario.kind or "",
    npc=scenario.npc or state.title or "",
    title=state.title or "",
    subtitle=state.subtitle or "",
    button=state.button or "",
    questIndex=state.questIndex or "",
    body=state.body or "",
    _editKey=editKey,
  }
end

function AR:EstimateDevDialogueHeight(text, width)
  local chars = math.floor((width or 420) / 6)
  if chars < 30 then chars = 30 end
  local lines = 1
  text = text or ""
  local startPos = 1
  while 1 do
    local nextBreak = string.find(text, "\n", startPos, true)
    local paragraph
    if nextBreak then
      paragraph = string.sub(text, startPos, nextBreak - 1)
    else
      paragraph = string.sub(text, startPos)
    end
    local len = string.len(paragraph or "")
    local needed = math.floor(len / chars) + 1
    if needed < 1 then needed = 1 end
    lines = lines + needed
    if not nextBreak then break end
    startPos = nextBreak + 1
  end
  local h = (lines * 14) + 24
  if h < 290 then h = 290 end
  return h
end

function AR:RenderDevDialogue()
  local f = AR.frames.devDialogue
  if not f then return end
  local total = table.getn(AR.devDialogueScenarios or {})
  if total < 1 then return end
  if not AR.devDialogueIndex or AR.devDialogueIndex < 1 then AR.devDialogueIndex = 1 end
  if AR.devDialogueIndex > total then AR.devDialogueIndex = total end

  local entry = AR:GetDevDialogueEntry(AR.devDialogueIndex)
  if not entry then return end
  f.currentEntry = entry
  f.currentQuestIndex = entry.questIndex

  f.heading:SetText(AR.devDialogueIndex .. "/" .. total .. "  " .. (entry.label or "Dialogue"))
  f.meta:SetText("NPC: " .. (entry.npc or "") .. "    Type: " .. (entry.kind or "") .. "    Quest: " .. tostring(entry.questIndex or "") .. "\nButton: " .. (entry.button or ""))
  f.bodyText:SetText((entry.title or "") .. "\n" .. (entry.subtitle or "") .. "\n\n" .. (entry.body or ""))
  f.bodyScroll:SetVerticalScroll(0)
  local h = AR:EstimateDevDialogueHeight((entry.body or "") .. (entry.title or "") .. (entry.subtitle or ""), 420)
  f.bodyChild:SetHeight(h)
end

function AR:StepDevDialogue(delta)
  local total = table.getn(AR.devDialogueScenarios or {})
  if total < 1 then return end
  AR.devDialogueIndex = (AR.devDialogueIndex or 1) + delta
  if AR.devDialogueIndex < 1 then AR.devDialogueIndex = total end
  if AR.devDialogueIndex > total then AR.devDialogueIndex = 1 end
  AR:RenderDevDialogue()
end

function AR:CreateDevDialogueFrame()
  if AR.frames.devDialogue then return end
  AR.devDialogueIndex = AR.devDialogueIndex or 1

  local f = CreateFrame("Frame", "AshenRelicsDevDialogueFrame", UIParent)
  f:SetWidth(560)
  f:SetHeight(470)
  f:SetPoint("CENTER", UIParent, "CENTER", 280, 20)
  f:SetFrameStrata("DIALOG")
  f:SetBackdrop({
    bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
    tile=1, tileSize=32, edgeSize=32,
    insets={left=8,right=8,top=8,bottom=8}
  })
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:Hide()

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", f, "TOP", 0, -18)
  title:SetText("Ashen Relics Dialogue Browser")

  f.heading = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.heading:SetPoint("TOPLEFT", f, "TOPLEFT", 32, -48)
  f.heading:SetWidth(496)
  f.heading:SetHeight(22)
  f.heading:SetJustifyH("LEFT")

  f.meta = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.meta:SetPoint("TOPLEFT", f, "TOPLEFT", 32, -76)
  f.meta:SetWidth(496)
  f.meta:SetHeight(36)
  f.meta:SetJustifyH("LEFT")
  f.meta:SetJustifyV("TOP")

  f.bodyScroll = CreateFrame("ScrollFrame", nil, f)
  f.bodyScroll:SetPoint("TOPLEFT", f, "TOPLEFT", 32, -122)
  f.bodyScroll:SetWidth(496)
  f.bodyScroll:SetHeight(286)
  f.bodyScroll:EnableMouseWheel(true)

  f.bodyChild = CreateFrame("Frame", nil, f.bodyScroll)
  f.bodyChild:SetWidth(470)
  f.bodyChild:SetHeight(286)
  f.bodyScroll:SetScrollChild(f.bodyChild)

  f.bodyText = f.bodyChild:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.bodyText:SetPoint("TOPLEFT", f.bodyChild, "TOPLEFT", 0, 0)
  f.bodyText:SetWidth(470)
  f.bodyText:SetJustifyH("LEFT")
  f.bodyText:SetJustifyV("TOP")

  f.bodyScroll:SetScript("OnMouseWheel", function()
    local child = AR.frames.devDialogue and AR.frames.devDialogue.bodyChild
    if not child then return end
    local maxScroll = child:GetHeight() - this:GetHeight()
    if maxScroll < 0 then maxScroll = 0 end
    local cur = this:GetVerticalScroll()
    if arg1 > 0 then cur = cur - 28 else cur = cur + 28 end
    if cur < 0 then cur = 0 end
    if cur > maxScroll then cur = maxScroll end
    this:SetVerticalScroll(cur)
  end)

  AR:MakeSmallButton(f, "Prev", 32, -426, 58, 24, function() AR:StepDevDialogue(-1) end)
  AR:MakeSmallButton(f, "Next", 96, -426, 58, 24, function() AR:StepDevDialogue(1) end)
  AR:MakeSmallButton(f, "Edit NPC", 160, -426, 76, 24, function() AR:OpenDialogueCopyEditor(AR.frames.devDialogue.currentEntry) end)
  AR:MakeSmallButton(f, "Edit Quest", 242, -426, 82, 24, function()
    local qi = AR.frames.devDialogue.currentQuestIndex or 1
    if qi == "" then qi = 1 end
    AR:OpenQuestCopyEditor("human", qi)
  end)
  AR:MakeSmallButton(f, "Dump", 330, -426, 58, 24, function() AR:ShowCopyEditsDumpWindow() end)
  AR:MakeSmallButton(f, "Refresh", 394, -426, 70, 24, function() AR:RenderDevDialogue() end)
  AR:MakeSmallButton(f, "Close", 470, -426, 58, 24, function() AR.frames.devDialogue:Hide() end)

  AR.frames.devDialogue = f
end

function AR:ToggleDevDialogue()
  AR:CreateDevDialogueFrame()
  if AR.frames.devDialogue:IsShown() then
    AR.frames.devDialogue:Hide()
  else
    AR.frames.devDialogue:Show()
    AR:RenderDevDialogue()
  end
end


function AR:ResetAllQuestsFromOptions()
  AR:CancelIntroNarration()

  AshenRelicsDB.completed = {}
  AshenRelicsDB.accepted = {}
  AshenRelicsDB.items = {}
  AshenRelicsDB.flavor = {}
  AshenRelicsDB.flags = {}
  AshenRelicsDB.evidenceLog = {}
  AshenRelicsDB.relicWhispers = {}
  AR.storyReturnInside = {}
  AR.humanQ1SearchGrace = nil

  if AR.frames.humanQ1SearchButton then AR.frames.humanQ1SearchButton:Hide() end
  if AR.frames.humanQ1SearchResult then AR.frames.humanQ1SearchResult:Hide() end

  AR.activeCategory = 1
  AR.activeQuest = 1
  AR.activeEvidenceQuest = nil

  AR:RenderSidebar()
  AR:RenderQuestDetail()
  AR:UpdateCategoryCounts()
  AR:RefreshBag()

  DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics:|r quests, relic items, and progression reset.")
end


function AR:CreateOptionsFrame()
  if AR.frames.options then return end
  AR.selectedLayoutIndex = 1
  AR.selectedLayoutElement = "page"

  local f = CreateFrame("Frame", "AshenRelicsOptionsFrame", UIParent)
  f:SetWidth(230)
  f:SetHeight(315)
  f:SetPoint("CENTER", UIParent, "CENTER", 395, 0)
  f:SetFrameStrata("DIALOG")
  f:SetBackdrop({
    bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
    tile=1, tileSize=32, edgeSize=32,
    insets={left=8,right=8,top=8,bottom=8}
  })
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:Hide()

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOP", f, "TOP", 0, -16)
  title:SetText("Ashen Relics Options")

  f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.text:SetPoint("TOP", f, "TOP", 0, -42)
  f.text:SetWidth(190)
  f.text:SetJustifyH("CENTER")

  AR:MakeSmallButton(f, "<", 25, -105, 42, 22, function() AR:CycleLayoutElement(-1) end)
  AR:MakeSmallButton(f, "Next", 75, -105, 80, 22, function() AR:CycleLayoutElement(1) end)
  AR:MakeSmallButton(f, ">", 165, -105, 42, 22, function() AR:CycleLayoutElement(1) end)

  AR:MakeSmallButton(f, "Up", 85, -135, 60, 22, function() AR:NudgeLayout(0, 1) end)
  AR:MakeSmallButton(f, "Left", 25, -163, 60, 22, function() AR:NudgeLayout(-1, 0) end)
  AR:MakeSmallButton(f, "Right", 145, -163, 60, 22, function() AR:NudgeLayout(1, 0) end)
  AR:MakeSmallButton(f, "Down", 85, -191, 60, 22, function() AR:NudgeLayout(0, -1) end)

  AR:MakeSmallButton(f, "W-", 25, -222, 42, 22, function() AR:ResizeLayout(-2, 0) end)
  AR:MakeSmallButton(f, "W+", 70, -222, 42, 22, function() AR:ResizeLayout(2, 0) end)
  AR:MakeSmallButton(f, "H-", 118, -222, 42, 22, function() AR:ResizeLayout(0, -2) end)
  AR:MakeSmallButton(f, "H+", 163, -222, 42, 22, function() AR:ResizeLayout(0, 2) end)

  AR:MakeSmallButton(f, "Scale-", 25, -250, 70, 22, function() AR:ScaleLayout(-0.05) end)
  AR:MakeSmallButton(f, "Scale+", 105, -250, 70, 22, function() AR:ScaleLayout(0.05) end)
  AR:MakeSmallButton(f, "Reset", 180, -250, 45, 22, function() AR:ResetLayout() end)
  AR:MakeSmallButton(f, "Dump", 180, -222, 45, 22, function() AR:ShowDumpWindow() end)
  AR:MakeSmallButton(f, "Flame", 25, -280, 55, 24, function() AR:SelectLayoutElement("headerFlame") end)
  AR:MakeSmallButton(f, "Reset Quests", 85, -280, 120, 24, function() AR:ResetAllQuestsFromOptions() end)

  AR.frames.options = f
  AR:UpdateOptionsText()
end

function AR:ToggleOptions()
  AR:CreateOptionsFrame()
  if AR.frames.options:IsShown() then
    AR.frames.options:Hide()
  else
    AR.frames.options:Show()
    AR:UpdateOptionsText()
  end
end



AR.fonts = {
  title = "Fonts\\MORPHEUS.TTF",
  header = "Fonts\\MORPHEUS.TTF",
  body = "Fonts\\FRIZQT__.TTF",
  small = "Fonts\\FRIZQT__.TTF",
}

function AR:ApplyFont(fs, fontPath, size, flags)
  if fs and fs.SetFont then
    fs:SetFont(fontPath, size, flags or "")
  end
end

function AR:ApplyThemedFonts()
  local f = AR.frames.main
  if not f then return end
  AR:ApplyFont(f.titleText, AR.fonts.title, 24, "")
  AR:ApplyFont(f.subtitleText, AR.fonts.body, 12, "")
  AR:ApplyFont(f.objectiveText, AR.fonts.body, 11, "")
  if f.objectiveLines then
    local i
    for i = 1, table.getn(f.objectiveLines) do
      AR:ApplyFont(f.objectiveLines[i], AR.fonts.body, 10, "")
    end
  end
  if f.objectiveChecks then
    local ci
    for ci = 1, table.getn(f.objectiveChecks) do
      if f.objectiveChecks[ci].tick then AR:ApplyFont(f.objectiveChecks[ci].tick, AR.fonts.body, 10, "") end
    end
  end
  AR:ApplyFont(f.descriptionText, AR.fonts.body, 10, "")
  AR:ApplyFont(f.targetNameText, AR.fonts.header, 13, "")
  AR:ApplyFont(f.targetLocationText, AR.fonts.body, 10, "")
  AR:ApplyFont(f.rewardNameText, AR.fonts.header, 13, "")
  AR:ApplyFont(f.rewardDetailText, AR.fonts.body, 10, "")
end

function AR:SerializeLayout()
  local out = "AR.defaultLayout = {\\n"
  local i
  for i = 1, table.getn(AR.layoutOrder) do
    local name = AR.layoutOrder[i]
    local d = AR:GetLayout(name)
    out = out .. "  " .. name .. "={x=" .. d.x .. ",y=" .. d.y .. ",w=" .. d.w .. ",h=" .. d.h .. ",scale=" .. string.format("%.2f", d.scale or 1) .. "},\\n"
  end
  out = out .. "}"
  return out
end

function AR:ShowDumpWindow()
  local dump = AR:SerializeLayout()
  DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics layout dump ready.|r Copy it from the popup.")

  if not AR.frames.dump then
    local f = CreateFrame("Frame", "AshenRelicsDumpFrame", UIParent)
    f:SetWidth(520)
    f:SetHeight(360)
    f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetBackdrop({
      bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
      tile=1, tileSize=32, edgeSize=32,
      insets={left=8,right=8,top=8,bottom=8}
    })
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() this:StartMoving() end)
    f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -18)
    title:SetText("Ashen Relics Layout Dump")

    local close = CreateFrame("Button", nil, f)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -16)
    close:SetWidth(24)
    close:SetHeight(24)
    close:SetNormalTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Up")
    close:SetPushedTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Down")
    close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight")
    close:SetScript("OnClick", function() AR.frames.dump:Hide() end)

    local eb = CreateFrame("EditBox", nil, f)
    eb:SetPoint("TOPLEFT", f, "TOPLEFT", 28, -52)
    eb:SetWidth(464)
    eb:SetHeight(270)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetTextColor(1, 0.82, 0.35)
    eb:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    f.editBox = eb

    AR.frames.dump = f
  end

  AR.frames.dump.editBox:SetText(dump)
  AR.frames.dump.editBox:HighlightText()
  AR.frames.dump.editBox:SetFocus()
  AR.frames.dump:Show()
end


function AR:SafeGetCVar(name)
  if not GetCVar then return nil end
  local ok, value = pcall(function() return GetCVar(name) end)
  if ok then return value end
  return nil
end

function AR:SafeSetCVar(name, value)
  if not SetCVar then return nil end
  local ok = pcall(function() SetCVar(name, tostring(value)) end)
  if ok then return 1 end
  return nil
end

function AR:SuppressGameMusicForIntro()
  if AR.introGameMusicSuppressed then return 1 end
  local names = { "Sound_EnableMusic", "EnableMusic" }
  local saved = {}
  local changed = nil
  local i
  for i = 1, table.getn(names) do
    local oldValue = AR:SafeGetCVar(names[i])
    if oldValue ~= nil then
      table.insert(saved, { name=names[i], value=oldValue })
      if tostring(oldValue) ~= "0" then
        if AR:SafeSetCVar(names[i], 0) then changed = 1 end
      end
    end
  end
  if table.getn(saved) > 0 then
    AR.introSavedMusicEnableCVars = saved
    AR.introGameMusicSuppressed = changed or 1
    return 1
  end
  return nil
end

function AR:RestoreGameMusicAfterIntro()
  local saved = AR.introSavedMusicEnableCVars
  AR.introSavedMusicEnableCVars = nil
  AR.introGameMusicSuppressed = nil
  if not saved then return nil end

  local i
  for i = 1, table.getn(saved) do
    if saved[i] and saved[i].name then
      AR:SafeSetCVar(saved[i].name, saved[i].value)
    end
  end
  return 1
end

function AR:RestartGameMusic()
  local names = { "Sound_EnableMusic", "EnableMusic" }
  local i
  for i = 1, table.getn(names) do
    local oldValue = AR:SafeGetCVar(names[i])
    if oldValue and tostring(oldValue) ~= "0" then
      if AR:SafeSetCVar(names[i], 0) then
        AR:SafeSetCVar(names[i], oldValue)
        return 1
      end
    end
  end
  return nil
end

function AR:GetMusicVolumeCVar()
  local names = { "Sound_MusicVolume", "MusicVolume" }
  local i
  for i = 1, table.getn(names) do
    local value = AR:SafeGetCVar(names[i])
    if value and tonumber(value) then
      return names[i], tonumber(value)
    end
  end
  return nil, nil
end

function AR:GetMusicEnableCVar()
  local names = { "Sound_EnableMusic", "EnableMusic" }
  local i
  for i = 1, table.getn(names) do
    local value = AR:SafeGetCVar(names[i])
    if value ~= nil then
      return names[i], value
    end
  end
  return nil, nil
end

function AR:SetMusicEnabledForIntro(enabled)
  local cvar = AR:GetMusicEnableCVar()
  if not cvar then return nil end
  if enabled then
    return AR:SafeSetCVar(cvar, 1)
  end
  return AR:SafeSetCVar(cvar, 0)
end

function AR:ClampVolume(value)
  value = tonumber(value) or 0
  if value < 0 then value = 0 end
  if value > 1 then value = 1 end
  return value
end

function AR:GetSoundEffectVolumeCVar()
  local names = { "Sound_SFXVolume", "Sound_EffectsVolume", "SoundVolume" }
  local i
  for i = 1, table.getn(names) do
    local value = AR:SafeGetCVar(names[i])
    if value and tonumber(value) then
      return names[i], tonumber(value)
    end
  end
  return nil, nil
end

function AR:GetSoundEffectEnableCVar()
  local names = { "Sound_EnableSFX", "EnableSFX", "Sound_EnableSound", "EnableSound", "Sound_EnableAllSound" }
  local i
  for i = 1, table.getn(names) do
    local value = AR:SafeGetCVar(names[i])
    if value ~= nil then
      return names[i], value
    end
  end
  return nil, nil
end

function AR:StopMusicVolumeFade()
  AR.musicVolumeFade = nil
  if AR.frames and AR.frames.musicVolumeFade then
    AR.frames.musicVolumeFade:Hide()
  end
end

function AR:UpdateMusicVolumeFade(elapsed)
  if not AR.musicVolumeFade then
    if this then this:Hide() end
    return
  end

  local fade = AR.musicVolumeFade
  fade.elapsed = fade.elapsed + (elapsed or 0)
  local pct = 1
  if fade.duration and fade.duration > 0 then
    pct = fade.elapsed / fade.duration
    if pct > 1 then pct = 1 end
  end

  local value = fade.from + ((fade.to - fade.from) * pct)
  AR:SafeSetCVar(fade.cvar, value)

  if pct >= 1 then
    local stopIntroMusic = fade.stopIntroMusic
    local restoreCVar = fade.restoreCVar
    local restoreValue = fade.restoreValue

    AR.musicVolumeFade = nil
    if this then this:Hide() end

    if stopIntroMusic then
      if StopMusic then pcall(function() StopMusic() end) end
      AR.musicWasFaded = nil
      AR.savedMusicVolumeCVar = nil
      AR.savedMusicVolume = nil
      AR.introUsingMusicChannel = nil
      AR.introAudioFading = nil
      if fade.fadeInGameMusic and restoreCVar and restoreValue then
        AR:RestoreGameMusicAfterIntro()
        AR:SafeSetCVar(restoreCVar, 0)
        AR:RestartGameMusic()
        AR:StartMusicVolumeFade(restoreCVar, 0, restoreValue, AR.introGameMusicFadeInSeconds or fade.duration or 0)
      else
        if restoreCVar and restoreValue then AR:SafeSetCVar(restoreCVar, restoreValue) end
        AR:RestoreGameMusicAfterIntro()
        AR:RestartGameMusic()
      end
    end
  end
end

function AR:StartMusicVolumeFade(cvar, fromValue, toValue, seconds, stopIntroMusic, restoreCVar, restoreValue, fadeInGameMusic)
  AR:StopMusicVolumeFade()

  if not seconds or seconds <= 0 then
    AR:SafeSetCVar(cvar, toValue)
    if stopIntroMusic then
      if StopMusic then pcall(function() StopMusic() end) end
      AR.introUsingMusicChannel = nil
      AR.introAudioFading = nil
      if fadeInGameMusic and restoreCVar and restoreValue then
        AR:RestoreGameMusicAfterIntro()
        AR:SafeSetCVar(restoreCVar, 0)
        AR:RestartGameMusic()
        AR:StartMusicVolumeFade(restoreCVar, 0, restoreValue, AR.introGameMusicFadeInSeconds or 0)
      else
        if restoreCVar and restoreValue then AR:SafeSetCVar(restoreCVar, restoreValue) end
        AR:RestoreGameMusicAfterIntro()
        AR:RestartGameMusic()
      end
    end
    return
  end

  AR.musicVolumeFade = {
    cvar=cvar,
    from=fromValue,
    to=toValue,
    elapsed=0,
    duration=seconds,
    stopIntroMusic=stopIntroMusic,
    restoreCVar=restoreCVar,
    restoreValue=restoreValue,
    fadeInGameMusic=fadeInGameMusic
  }

  if not AR.frames.musicVolumeFade then
    local f = CreateFrame("Frame", nil, UIParent)
    f:Hide()
    f:SetScript("OnUpdate", function() AR:UpdateMusicVolumeFade(arg1) end)
    AR.frames.musicVolumeFade = f
  end
  AR.frames.musicVolumeFade:Show()
end

function AR:StopSoundEffectVolumeFade()
  AR.soundEffectVolumeFade = nil
  if AR.frames and AR.frames.soundEffectVolumeFade then
    AR.frames.soundEffectVolumeFade:Hide()
  end
end

function AR:StopSoundEffectHold(restore)
  local hold = AR.soundEffectHold
  AR.soundEffectHold = nil
  if AR.frames and AR.frames.soundEffectHold then
    AR.frames.soundEffectHold:Hide()
  end
  if restore and hold and hold.cvar and hold.restoreValue then
    AR:SafeSetCVar(hold.cvar, hold.restoreValue)
  end
end

function AR:StopSoundEffectEnableHold(restore)
  local hold = AR.soundEffectEnableHold
  AR.soundEffectEnableHold = nil
  if AR.frames and AR.frames.soundEffectEnableHold then
    AR.frames.soundEffectEnableHold:Hide()
  end
  if restore and hold and hold.cvar and hold.restoreValue then
    AR:SafeSetCVar(hold.cvar, hold.restoreValue)
  end
end

function AR:RestoreSoundEffectSettings()
  AR:StopSoundEffectVolumeFade()
  AR:StopSoundEffectHold(1)
  AR:StopSoundEffectEnableHold(1)
  if AR.savedSoundEffectVolumeCVar and AR.savedSoundEffectVolume then
    AR:SafeSetCVar(AR.savedSoundEffectVolumeCVar, AR.savedSoundEffectVolume)
  end
  AR.savedSoundEffectVolumeCVar = nil
  AR.savedSoundEffectVolume = nil
end

function AR:UpdateSoundEffectEnableHold(elapsed)
  if not AR.soundEffectEnableHold then
    if this then this:Hide() end
    return
  end

  local hold = AR.soundEffectEnableHold
  hold.elapsed = hold.elapsed + (elapsed or 0)
  if hold.cvar then AR:SafeSetCVar(hold.cvar, 0) end

  if hold.elapsed >= (hold.duration or 0) then
    if hold.cvar and hold.restoreValue then AR:SafeSetCVar(hold.cvar, hold.restoreValue) end
    AR.soundEffectEnableHold = nil
    if this then this:Hide() end
  end
end

function AR:StartSoundEffectEnableHold(seconds)
  if not seconds or seconds <= 0 then seconds = 2 end
  if seconds > 2 then seconds = 2 end
  local cvar, oldValue = AR:GetSoundEffectEnableCVar()
  if not cvar then return nil end
  if not AR:SafeSetCVar(cvar, 0) then return nil end

  AR:StopSoundEffectEnableHold(nil)
  AR.soundEffectEnableHold = {
    cvar=cvar,
    restoreValue=oldValue or 1,
    elapsed=0,
    duration=seconds,
  }

  if not AR.frames.soundEffectEnableHold then
    local f = CreateFrame("Frame", nil, UIParent)
    f:Hide()
    f:SetScript("OnUpdate", function() AR:UpdateSoundEffectEnableHold(arg1) end)
    AR.frames.soundEffectEnableHold = f
  end
  AR.frames.soundEffectEnableHold:Show()
  return 1
end

function AR:UpdateSoundEffectHold(elapsed)
  if not AR.soundEffectHold then
    if this then this:Hide() end
    return
  end

  local hold = AR.soundEffectHold
  hold.elapsed = hold.elapsed + (elapsed or 0)
  if hold.cvar then AR:SafeSetCVar(hold.cvar, 0) end

  if hold.elapsed >= (hold.duration or 0) then
    if hold.cvar and hold.restoreValue then AR:SafeSetCVar(hold.cvar, hold.restoreValue) end
    AR.soundEffectHold = nil
    if this then this:Hide() end
  end
end

function AR:StartSoundEffectHold(cvar, restoreValue, seconds)
  if not cvar or not restoreValue or not seconds or seconds <= 0 then return nil end
  AR:StopSoundEffectHold(nil)
  AR.soundEffectHold = { cvar=cvar, restoreValue=restoreValue, elapsed=0, duration=seconds }
  AR:SafeSetCVar(cvar, 0)
  if not AR.frames.soundEffectHold then
    local f = CreateFrame("Frame", nil, UIParent)
    f:Hide()
    f:SetScript("OnUpdate", function() AR:UpdateSoundEffectHold(arg1) end)
    AR.frames.soundEffectHold = f
  end
  AR.frames.soundEffectHold:Show()
  return 1
end

function AR:FlushSoundEffectChannel()
  local cvar, oldValue = AR:GetSoundEffectEnableCVar()
  if cvar and AR:SafeSetCVar(cvar, 0) then
    AR:SafeSetCVar(cvar, oldValue or 1)
  end
end

function AR:UpdateSoundEffectVolumeFade(elapsed)
  if not AR.soundEffectVolumeFade then
    if this then this:Hide() end
    return
  end

  local fade = AR.soundEffectVolumeFade
  fade.elapsed = fade.elapsed + (elapsed or 0)
  local pct = 1
  if fade.duration and fade.duration > 0 then
    pct = fade.elapsed / fade.duration
    if pct > 1 then pct = 1 end
  end

  local value = fade.from + ((fade.to - fade.from) * pct)
  AR:SafeSetCVar(fade.cvar, value)

  if pct >= 1 then
    local flushSFX = fade.flushSFX

    AR.soundEffectVolumeFade = nil
    if this then this:Hide() end
    AR:StopIntroSoundFiles()
    if flushSFX then AR:FlushSoundEffectChannel() end
    if fade.holdSeconds and fade.holdSeconds > 0 and fade.restoreValue then
      AR.savedSoundEffectVolumeCVar = nil
      AR.savedSoundEffectVolume = nil
      AR:StartSoundEffectHold(fade.cvar, fade.restoreValue, fade.holdSeconds)
    else
      AR:RestoreSoundEffectSettings()
    end
    AR.introAudioFading = nil
  end
end

function AR:StartSoundEffectVolumeFade(cvar, fromValue, toValue, seconds, flushSFX, holdSeconds, restoreValue)
  AR:StopSoundEffectVolumeFade()

  if not seconds or seconds <= 0 then
    AR:SafeSetCVar(cvar, toValue)
    AR:StopIntroSoundFiles()
    if flushSFX then AR:FlushSoundEffectChannel() end
    if holdSeconds and holdSeconds > 0 and restoreValue then
      AR.savedSoundEffectVolumeCVar = nil
      AR.savedSoundEffectVolume = nil
      AR:StartSoundEffectHold(cvar, restoreValue, holdSeconds)
    else
      AR:RestoreSoundEffectSettings()
    end
    AR.introAudioFading = nil
    return
  end

  AR.soundEffectVolumeFade = {
    cvar=cvar,
    from=fromValue,
    to=toValue,
    elapsed=0,
    duration=seconds,
    flushSFX=flushSFX,
    holdSeconds=holdSeconds,
    restoreValue=restoreValue
  }

  if not AR.frames.soundEffectVolumeFade then
    local f = CreateFrame("Frame", nil, UIParent)
    f:Hide()
    f:SetScript("OnUpdate", function() AR:UpdateSoundEffectVolumeFade(arg1) end)
    AR.frames.soundEffectVolumeFade = f
  end
  AR.frames.soundEffectVolumeFade:Show()
end

function AR:DuckGameMusic()
  AR:RestoreSoundSettings()

  local cvar, oldValue = AR:GetMusicVolumeCVar()
  if cvar and oldValue then
    local target = AR.introDuckedGameMusicVolume or 0.08
    if oldValue < target then target = oldValue end
    AR.musicWasFaded = 1
    AR.savedMusicVolumeCVar = cvar
    AR.savedMusicVolume = oldValue
    AR:StartMusicVolumeFade(cvar, oldValue, target, AR.introMusicFadeSeconds or 0)
    return 1
  end

  -- If this client does not expose a safe music-volume CVar, at least stop
  -- the current zone music so the custom WAVs are not buried underneath it.
  if StopMusic then
    pcall(function() StopMusic() end)
    AR:RestartGameMusic()
  end
  return nil
end

function AR:RestoreSoundSettings()
  AR:StopMusicVolumeFade()
  AR:RestoreGameMusicAfterIntro()
  if AR.musicWasFaded and AR.savedMusicVolumeCVar and AR.savedMusicVolume then
    AR:SafeSetCVar(AR.savedMusicVolumeCVar, AR.savedMusicVolume)
  end
  AR.musicWasFaded = nil
  AR.savedMusicVolumeCVar = nil
  AR.savedMusicVolume = nil
end

function AR:PlayIntroSoundFile(path)
  if not PlaySoundFile or not path then return nil end
  local ok, a, b = pcall(function() return PlaySoundFile(path) end)
  if not ok then return nil end

  -- Modern clients may return success, handle.  Vanilla 1.12 usually returns
  -- nothing, so the file can still play even when no handle is available.
  local handle = nil
  if type(b) == "number" then
    handle = b
  elseif type(a) == "number" then
    handle = a
  end

  if handle then
    if not AR.introSoundHandles then AR.introSoundHandles = {} end
    table.insert(AR.introSoundHandles, handle)
  end
  return 1
end

function AR:IsIntroPlaybackActive()
  if AR.introNarration then return 1 end
  if AR.introMusicState then return 1 end
  if AR.introSoundHandles then return 1 end
  if AR.introUsingMusicChannel then return 1 end
  if AR.introAudioFading then return 1 end
  return nil
end

function AR:GetIntroControlledMusicPath()
  if AR.introNarrationPath and AR.introNarrationPath ~= "" then
    return AR.introNarrationPath
  end
  if AR.introMusicPath and AR.introMusicPath ~= "" then
    return AR.introMusicPath
  end
  return nil
end

function AR:GetIntroMusicTargetVolume(originalVolume)
  local target = AR:ClampVolume(originalVolume or 0.4)
  local requested = tonumber(AR.introMusicChannelVolume)
  if requested and requested > target then target = requested end
  return AR:ClampVolume(target)
end

function AR:EnsureIntroMusicDriver()
  if AR.frames.introMusicDriver then return end
  local f = CreateFrame("Frame", nil, UIParent)
  f:Hide()
  f:SetScript("OnUpdate", function() AR:UpdateIntroMusicPlayback(arg1) end)
  AR.frames.introMusicDriver = f
end

function AR:FinishIntroMusicPlayback(state)
  state = state or AR.introMusicState
  AR.introMusicState = nil
  AR.introUsingMusicChannel = nil
  AR.introAudioFading = nil
  if AR.frames and AR.frames.introMusicDriver then AR.frames.introMusicDriver:Hide() end

  if state and state.cvar and state.originalVolume then
    AR:SafeSetCVar(state.cvar, state.originalVolume)
  end
  if state and state.sfxCvar and state.originalSfxVolume then
    AR:SafeSetCVar(state.sfxCvar, state.originalSfxVolume)
  end
  if state and state.originalEnabled ~= nil then
    AR:SetMusicEnabledForIntro(tostring(state.originalEnabled) ~= "0")
  end
end

function AR:StartIntroMusicPlayback()
  local path = AR:GetIntroControlledMusicPath()
  if not path or not PlayMusic then return nil end

  AR:StopIntroMusicPlayback(1)
  AR:EnsureIntroMusicDriver()

  local cvar, originalVolume = AR:GetMusicVolumeCVar()
  local enableCVar, originalEnabled = AR:GetMusicEnableCVar()
  local sfxCvar, originalSfxVolume = AR:GetSoundEffectVolumeCVar()
  if not originalVolume then originalVolume = 0.4 end
  originalVolume = AR:ClampVolume(originalVolume)
  if originalSfxVolume then originalSfxVolume = AR:ClampVolume(originalSfxVolume) end

  local targetVolume = AR:GetIntroMusicTargetVolume(originalVolume)
  local state = {
    mode="playing",
    path=path,
    cvar=cvar,
    sfxCvar=sfxCvar,
    originalVolume=originalVolume,
    originalSfxVolume=originalSfxVolume,
    originalEnabled=originalEnabled,
    targetVolume=targetVolume,
    elapsed=0,
    duration=0,
  }

  AR.introMusicState = state
  AR.introUsingMusicChannel = 1
  AR:SetMusicEnabledForIntro(1)

  -- Start the custom intro immediately when Play Now is clicked. The previous
  -- version faded the game channel to zero, waited, then started the WAV,
  -- which made the button feel delayed.
  if StopMusic then pcall(function() StopMusic() end) end
  if cvar then AR:SafeSetCVar(cvar, targetVolume) end
  if sfxCvar and originalSfxVolume then AR:SafeSetCVar(sfxCvar, originalSfxVolume) end
  local ok = pcall(function() PlayMusic(path) end)
  if not ok then
    AR:FinishIntroMusicPlayback(state)
    return nil
  end

  AR.frames.introMusicDriver:Show()
  return 1
end

function AR:StopIntroMusicPlayback(immediate)
  local state = AR.introMusicState
  if not state then return nil end

  if immediate then
    if StopMusic then pcall(function() StopMusic() end) end
    AR:FinishIntroMusicPlayback(state)
    if state.originalEnabled == nil or tostring(state.originalEnabled) ~= "0" then
      AR:RestartGameMusic()
    end
    return 1
  end

  AR:EnsureIntroMusicDriver()
  if state.mode == "game_fade_out" or state.mode == "start_delay" then
    state.mode = "game_fade_in"
    state.elapsed = 0
    state.duration = AR.introGameMusicFadeInSeconds or AR.introStopFadeSeconds or 1.25
    state.fromVolume = state.cvar and AR:ClampVolume(AR:SafeGetCVar(state.cvar) or 0) or 0
    state.fromSfxVolume = state.sfxCvar and AR:ClampVolume(AR:SafeGetCVar(state.sfxCvar) or 0) or 0
    state.toVolume = state.originalVolume or 0
    state.toSfxVolume = state.originalSfxVolume
    AR.frames.introMusicDriver:Show()
    return 1
  end

  if state.mode == "custom_fade_out" or state.mode == "game_fade_in" then
    AR.frames.introMusicDriver:Show()
    return 1
  end

  state.mode = "custom_fade_out"
  state.elapsed = 0
  state.duration = AR.introStopFadeSeconds or 1.25
  if state.cvar then
    state.fromVolume = AR:ClampVolume(AR:SafeGetCVar(state.cvar) or state.targetVolume or 0)
  else
    state.fromVolume = state.targetVolume or state.originalVolume or 0
  end
  state.fromSfxVolume = state.sfxCvar and AR:ClampVolume(AR:SafeGetCVar(state.sfxCvar) or 0) or nil
  state.toVolume = 0
  state.toSfxVolume = nil
  AR.frames.introMusicDriver:Show()
  return 1
end

function AR:UpdateIntroMusicPlayback(elapsed)
  local state = AR.introMusicState
  if not state then
    if this then this:Hide() end
    return
  end

  elapsed = tonumber(elapsed) or 0
  state.elapsed = (state.elapsed or 0) + elapsed

  if state.mode == "playing" then return end

  if state.mode == "start_delay" then
    if state.elapsed >= (state.duration or 0) then
      if StopMusic then pcall(function() StopMusic() end) end
      local ok = pcall(function() PlayMusic(state.path) end)
      if not ok then
        AR:FinishIntroMusicPlayback(state)
        return
      end
      state.mode = "custom_fade_in"
      state.elapsed = 0
      state.duration = AR.introStartFadeSeconds or 1.6
      state.fromVolume = 0
      state.toVolume = state.targetVolume or state.originalVolume or 0.4
      state.fromSfxVolume = nil
      state.toSfxVolume = nil
      if state.cvar then AR:SafeSetCVar(state.cvar, 0) end
    end
    return
  end

  local duration = tonumber(state.duration) or 0
  if duration <= 0 then duration = 0.01 end
  local pct = state.elapsed / duration
  if pct > 1 then pct = 1 end

  local fromValue = AR:ClampVolume(state.fromVolume or 0)
  local toValue = AR:ClampVolume(state.toVolume or 0)
  local value = fromValue + ((toValue - fromValue) * pct)
  if state.cvar then AR:SafeSetCVar(state.cvar, value) end
  if state.sfxCvar and state.fromSfxVolume ~= nil and state.toSfxVolume ~= nil then
    local fromSfx = AR:ClampVolume(state.fromSfxVolume or 0)
    local toSfx = AR:ClampVolume(state.toSfxVolume or 0)
    local sfxValue = fromSfx + ((toSfx - fromSfx) * pct)
    AR:SafeSetCVar(state.sfxCvar, sfxValue)
  end

  if pct < 1 then return end

  if state.mode == "game_fade_out" then
    state.mode = "start_delay"
    state.elapsed = 0
    state.duration = AR.introStartDelaySeconds or 1.0
    if state.cvar then AR:SafeSetCVar(state.cvar, 0) end
    if state.sfxCvar then AR:SafeSetCVar(state.sfxCvar, 0) end
    return
  end

  if state.mode == "custom_fade_in" then
    state.mode = "playing"
    state.elapsed = 0
    if state.cvar then AR:SafeSetCVar(state.cvar, state.targetVolume or state.originalVolume or 0.4) end
    return
  end

  if state.mode == "custom_fade_out" then
    if StopMusic then pcall(function() StopMusic() end) end
    if state.cvar then AR:SafeSetCVar(state.cvar, 0) end
    if state.originalEnabled == nil or tostring(state.originalEnabled) ~= "0" then
      AR:SetMusicEnabledForIntro(1)
      AR:RestartGameMusic()
      state.mode = "game_fade_in"
      state.elapsed = 0
      state.duration = AR.introGameMusicFadeInSeconds or 1.5
      state.fromVolume = 0
      state.fromSfxVolume = state.sfxCvar and 0 or nil
      state.toVolume = state.originalVolume or 0.4
      state.toSfxVolume = state.originalSfxVolume
      return
    end
    AR:FinishIntroMusicPlayback(state)
    return
  end

  if state.mode == "game_fade_in" then
    AR:FinishIntroMusicPlayback(state)
  end
end

function AR:BoolText(value)
  if value and value ~= 0 then return "yes" end
  return "no"
end

function AR:IsIntroNarrationEnabled()
  if AR.introNarrationEnabled and AR.introNarrationEnabled ~= 0 then return 1 end
  return nil
end

function AR:IsIntroMusicEnabled()
  if AR.introMusicEnabled and AR.introMusicEnabled ~= 0 then return 1 end
  return nil
end

function AR:PrintSoundDebug(text)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics Sound:|r " .. (text or ""))
  end
end

function AR:PrintIntroAudioDebug(prefix)
  local label = prefix or "Play Now"
  local musicEnabledText = AR:BoolText(AR:IsIntroMusicEnabled())
  if not AR:IsIntroMusicEnabled() and (not AR.introMusicPath or AR.introMusicPath == "") then
    musicEnabledText = "no (included in mixed intro WAV)"
  end
  AR:PrintSoundDebug(label)
  AR:PrintSoundDebug("Narration path: " .. (AR.introNarrationPath or ""))
  AR:PrintSoundDebug("Music path: " .. (AR.introMusicPath or ""))
  AR:PrintSoundDebug("Narration enabled: " .. AR:BoolText(AR:IsIntroNarrationEnabled()))
  AR:PrintSoundDebug("Music enabled: " .. musicEnabledText)
  AR:PrintSoundDebug("PlayMusic available: " .. AR:BoolText(PlayMusic))
  AR:PrintSoundDebug("PlaySoundFile available: " .. AR:BoolText(PlaySoundFile))
end

function AR:PlayIntroAudioFiles(debugLabel, duckMusic)
  AR:PrintIntroAudioDebug(debugLabel)
  AR:RestoreSoundEffectSettings()
  AR:StopIntroSoundFiles()
  AR.introUsingMusicChannel = nil

  if duckMusic then AR:DuckGameMusic() end

  local played = nil
  if AR:IsIntroNarrationEnabled() then
    if AR:PlayIntroSoundFile(AR.introNarrationPath) then
      played = 1
      AR:PrintSoundDebug("Narration PlaySoundFile attempted.")
    else
      AR:PrintSoundDebug("Narration PlaySoundFile failed or is unavailable.")
    end
  end
  if AR:IsIntroMusicEnabled() then
    if AR:PlayIntroSoundFile(AR.introMusicPath) then
      played = 1
      AR:PrintSoundDebug("Music PlaySoundFile attempted.")
    else
      AR:PrintSoundDebug("Music PlaySoundFile failed or is unavailable.")
    end
  end
  return played
end

function AR:SoundTest()
  AR:RestoreSoundSettings()
  AR:PlayIntroAudioFiles("/ar soundtest", nil)
end

function AR:PlayIntroMusicChannel(path)
  if not PlayMusic or not path then return nil end

  local cvar, oldValue = AR:GetMusicVolumeCVar()
  local playValue = nil
  if cvar and oldValue then
    playValue = oldValue
    local requestedValue = AR.introMusicChannelVolume
    if requestedValue and requestedValue > playValue then playValue = requestedValue end
    AR.savedMusicVolumeCVar = cvar
    AR.savedMusicVolume = oldValue
    AR.musicWasFaded = 1
    AR:SafeSetCVar(cvar, 0)
  end

  if StopMusic then pcall(function() StopMusic() end) end
  local ok = pcall(function() PlayMusic(path) end)
  if not ok then
    if cvar and oldValue then AR:SafeSetCVar(cvar, oldValue) end
    AR.savedMusicVolumeCVar = nil
    AR.savedMusicVolume = nil
    AR.musicWasFaded = nil
    return nil
  end

  AR.introUsingMusicChannel = 1
  -- PlayMusic uses the music channel, but the normal zone-music scheduler can
  -- still wake up on some 1.12 clients. Suppress that scheduler until Stop/end.
  AR:SuppressGameMusicForIntro()
  if cvar and playValue then
    AR:StartMusicVolumeFade(cvar, 0, playValue, AR.introStartFadeSeconds or 0)
  end
  return 1
end

function AR:PlayUISoundFile(path, fallbackName)
  if PlaySoundFile and path then
    local ok = pcall(function() PlaySoundFile(path) end)
    if ok then return 1 end
  end
  if PlaySound and fallbackName then
    pcall(function() PlaySound(fallbackName) end)
    return 1
  end
  return nil
end

function AR:PlayNativeQuestCompleteSound()
  if PlaySound then
    -- Native WoW quest-complete fanfare used for Ashen Relics quest accepts.
    local ok = pcall(function() PlaySound("QUESTCOMPLETED") end)
    if ok then return 1 end
    ok = pcall(function() PlaySound("igQuestListComplete") end)
    if ok then return 1 end
  end
  return nil
end

function AR:PlayQuestAcceptedSound()
  if AR:PlayNativeQuestCompleteSound() then return end
  AR:PlayUISoundFile(nil, "igQuestListComplete")
end

function AR:PlayQuestCompleteSound()
  AR:PlayUISoundFile(AR.questCompleteSoundPath, "igQuestComplete")
end

function AR:PlaySearchSound()
  AR:PlayUISoundFile(AR.searchSoundPath, AR.searchSoundFallback)
end

function AR:PlayQuestPageTurnSound()
  AR:PlayUISoundFile(AR.pageTurnSoundPath, "igQuestLogOpen")
end


function AR:EnsureRelicWhisperDB()
  if not AshenRelicsDB.relicWhispers then AshenRelicsDB.relicWhispers = {} end
  if not AshenRelicsDB.relicWhispers.spoken then AshenRelicsDB.relicWhispers.spoken = {} end
  if not AshenRelicsDB.relicWhispers.foundAt then AshenRelicsDB.relicWhispers.foundAt = {} end
  if AshenRelicsDB.relicWhispers.firstReactionShown == nil then AshenRelicsDB.relicWhispers.firstReactionShown = 0 end
  if AshenRelicsDB.relicWhispers.enabled == nil then AshenRelicsDB.relicWhispers.enabled = AR.relicWhisperEnabledDefault or 1 end
end

function AR:GetRelicWhisperNow()
  if time then return time() end
  if GetTime then return GetTime() end
  return 0
end

function AR:GetRelicWhisperRequiredCount(data)
  if data and data.requiredCount then return data.requiredCount end
  return 1
end

function AR:IsRelicWhisperItemFound(data)
  if not data or not data.key then return nil end
  return AR:GetItemCount(data.key) >= AR:GetRelicWhisperRequiredCount(data)
end

function AR:IsRelicWhisperBlocked()
  if UnitAffectingCombat and UnitAffectingCombat("player") then return 1 end
  if AR.IsIntroPlaybackActive and AR:IsIntroPlaybackActive() then return 1 end
  if AR.frames and AR.frames.dialogue and AR.frames.dialogue:IsShown() then return 1 end
  if AR.frames and AR.frames.loot and AR.frames.loot:IsShown() then return 1 end
  return nil
end

function AR:SyncRelicWhisperFoundTimes()
  AR:EnsureRelicWhisperDB()
  local db = AshenRelicsDB.relicWhispers
  local now = AR:GetRelicWhisperNow()
  local i, data
  for i = 1, table.getn(AR.relicWhispers or {}) do
    data = AR.relicWhispers[i]
    if data and data.key and not db.spoken[data.key] and AR:IsRelicWhisperItemFound(data) and not db.foundAt[data.key] then
      db.foundAt[data.key] = now
    end
  end
end

function AR:GetNextRelicWhisper()
  AR:EnsureRelicWhisperDB()
  if AshenRelicsDB.relicWhispers.enabled == 0 then return nil end
  AR:SyncRelicWhisperFoundTimes()
  local db = AshenRelicsDB.relicWhispers
  local i, data
  for i = 1, table.getn(AR.relicWhispers or {}) do
    data = AR.relicWhispers[i]
    if data and data.key and not db.spoken[data.key] and AR:IsRelicWhisperItemFound(data) then
      return data
    end
  end
  return nil
end

function AR:GetNextDueRelicWhisper()
  AR:EnsureRelicWhisperDB()
  if AshenRelicsDB.relicWhispers.enabled == 0 then return nil end
  AR:SyncRelicWhisperFoundTimes()

  local db = AshenRelicsDB.relicWhispers
  local now = AR:GetRelicWhisperNow()
  local delay = AR.relicWhisperDelaySeconds or 30
  local i, data, foundAt
  for i = 1, table.getn(AR.relicWhispers or {}) do
    data = AR.relicWhispers[i]
    if data and data.key and not db.spoken[data.key] and AR:IsRelicWhisperItemFound(data) then
      foundAt = db.foundAt[data.key]
      if foundAt and (now - foundAt) >= delay then
        return data
      end
    end
  end
  return nil
end

function AR:ResetRelicWhisperTimer()
  AR:EnsureRelicWhisperDB()
  AR:SyncRelicWhisperFoundTimes()
end

function AR:PlayRelicWhisper(data)
  if not data or not data.key then return end
  AR:EnsureRelicWhisperDB()
  if AshenRelicsDB.relicWhispers.spoken[data.key] then return end
  AshenRelicsDB.relicWhispers.spoken[data.key] = 1

  if AshenRelicsDB.relicWhispers.firstReactionShown == 0 then
    AshenRelicsDB.relicWhispers.firstReactionShown = 1
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd78aOh my dog, is this item speaking to me? Am I hearing things?|r")
  end

  DEFAULT_CHAT_FRAME:AddMessage("|cff8f6bffCaelyn Vale whispers through the " .. (data.itemName or "relic") .. ":|r |cffb9a7ff\"" .. (data.line or "") .. "\"|r")
  if data.sound and data.sound ~= "" then
    AR:PlayUISoundFile(data.sound, nil)
  end
end

function AR:UpdateRelicWhispers(elapsed)
  AR:EnsureRelicWhisperDB()
  if AshenRelicsDB.relicWhispers.enabled == 0 then return end

  -- Found time is recorded as soon as the item/count is present. The whisper
  -- fires 30 seconds after that specific relic is found, not on a random global timer.
  AR:SyncRelicWhisperFoundTimes()
  if AR:IsRelicWhisperBlocked() then return end

  local nextData = AR:GetNextDueRelicWhisper()
  if nextData then
    AR:PlayRelicWhisper(nextData)
  end
end

function AR:CreateRelicWhisperTicker()
  if AR.frames.relicWhisperTicker then return end
  local f = CreateFrame("Frame")
  f.elapsed = 0
  f:SetScript("OnUpdate", function()
    this.elapsed = (this.elapsed or 0) + (arg1 or 0)
    if this.elapsed >= 1.0 then
      local elapsed = this.elapsed
      this.elapsed = 0
      AR:UpdateRelicWhispers(elapsed)
    end
  end)
  AR.frames.relicWhisperTicker = f
end

function AR:ToggleRelicWhispers()
  AR:EnsureRelicWhisperDB()
  if AshenRelicsDB.relicWhispers.enabled == 0 then
    AshenRelicsDB.relicWhispers.enabled = 1
    AR:ResetRelicWhisperTimer()
    DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics:|r Caelyn relic whispers enabled.")
  else
    AshenRelicsDB.relicWhispers.enabled = 0
    DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics:|r Caelyn relic whispers disabled.")
  end
end

function AR:DebugPlayNextRelicWhisper()
  local data = AR:GetNextRelicWhisper()
  if not data then
    DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics:|r no unspoken found relic whispers are queued.")
    return
  end
  AR:PlayRelicWhisper(data)
  AR:ResetRelicWhisperTimer()
end

function AR:FixHumanQ1ManifestStuck()
  if not AR:IsHumanQ1Active() then
    DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics:|r The Prepared Road is not active.")
    return
  end
  if AR:GetItemCount("cargo_key") < 1 then
    DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics:|r you still need the Buccaneer's Cargo Key first.")
    return
  end

  local required = AR:GetHumanQ1SearchRequired()
  local count = AR:GetHumanQ1SearchCount()
  if count >= required then
    DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics:|r manifest progress is already complete.")
    return
  end

  local searches = AR:GetHumanQ1SearchDB()
  local i
  for i = 1, table.getn(AR.humanQ1SearchSpots or {}) do
    if not AR:IsHumanQ1SpotSearched(i) then
      searches[i] = AR:GetHumanQ1SpotRequired(i)
      break
    end
  end
  if not AshenRelicsDB.items then AshenRelicsDB.items = {} end
  AshenRelicsDB.items.manifest = AR:GetHumanQ1SearchCount()
  if AshenRelicsDB.items.manifest > required then AshenRelicsDB.items.manifest = required end

  AR:ShowEvidenceToast("Moldy Shipping Manifest recovered. " .. AshenRelicsDB.items.manifest .. "/" .. required, "Recovered from the old trade vessel records.")
  AR:RenderQuestDetail()
  AR:UpdateQuestOverlays()
  if AR.frames and AR.frames.bag then AR:RefreshBag() end
  DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics:|r repaired The Prepared Road manifest progress.")
end

function AR:PlayQuestLogOpenSound()
  AR:PlayUISoundFile(AR.pageTurnSoundPath, "igQuestLogOpen")
end

function AR:PlayFireplaceLoopSound()
  if PlaySoundFile and AR.fireplaceLoopSoundPath then
    pcall(function() PlaySoundFile(AR.fireplaceLoopSoundPath) end)
  end
end

function AR:StartFireplaceAmbience()
  AR.fireplaceAmbienceActive = 1
  AR.fireplaceAmbienceElapsed = 0
  AR:PlayFireplaceLoopSound()
end

function AR:StopFireplaceAmbience()
  AR.fireplaceAmbienceActive = nil
  AR.fireplaceAmbienceElapsed = 0
end

function AR:UpdateFireplaceAmbience(elapsed)
  if not AR.fireplaceAmbienceActive then return end
  if not AR.frames.main or not AR.frames.main:IsShown() then return end
  AR.fireplaceAmbienceElapsed = (AR.fireplaceAmbienceElapsed or 0) + (elapsed or 0)
  local loopSeconds = AR.fireplaceLoopSeconds or 4.85
  if AR.fireplaceAmbienceElapsed >= loopSeconds then
    AR.fireplaceAmbienceElapsed = 0
    AR:PlayFireplaceLoopSound()
  end
end

function AR:KneelThenStand()
  if DoEmote then
    pcall(function() DoEmote("KNEEL") end)
  end

  if not AR.frames.kneelStandTicker then
    local f = CreateFrame("Frame", nil, UIParent)
    f:Hide()
    f:SetScript("OnUpdate", function()
      this.elapsed = (this.elapsed or 0) + (arg1 or 0)
      if this.elapsed >= (this.delay or 1.2) then
        this:Hide()
        this.elapsed = 0
        if DoEmote then
          pcall(function() DoEmote("STAND") end)
        end
      end
    end)
    AR.frames.kneelStandTicker = f
  end

  local f = AR.frames.kneelStandTicker
  f.elapsed = 0
  f.delay = 1.2
  f:Show()
end

function AR:StopIntroSoundFiles(fadeSeconds)
  if StopSound and AR.introSoundHandles then
    local i
    for i = 1, table.getn(AR.introSoundHandles) do
      local handle = AR.introSoundHandles[i]
      if handle then
        local stopped = nil
        if fadeSeconds and fadeSeconds > 0 then
          local ok = pcall(function() StopSound(handle, fadeSeconds) end)
          if ok then stopped = 1 end
        end
        if not stopped then
          pcall(function() StopSound(handle) end)
        end
      end
    end
  end
  AR.introSoundHandles = nil
end

function AR:HardStopIntroAudio()
  AR:RestoreSoundEffectSettings()
  AR:StopIntroSoundFiles()
  if AR.introMusicState then
    AR:StopIntroMusicPlayback(1)
  else
    if StopMusic and AR.introUsingMusicChannel then
      pcall(function() StopMusic() end)
    end
    AR.introUsingMusicChannel = nil
    AR:RestoreGameMusicAfterIntro()
    AR:RestoreSoundSettings()
    AR:RestartGameMusic()
  end
  AR.introAudioFading = nil
end

function AR:RestoreIntroButtons()
  if AR.frames and AR.frames.main then
    if AR.frames.main.playButton then AR.frames.main.playButton:Show() end
    if AR.frames.main.showTextButton then AR.frames.main.showTextButton:Show() end
    if AR.frames.main.stopButton then AR.frames.main.stopButton:Hide() end
  end
end

function AR:FadeOutIntroMusicChannel(seconds)
  local cvar, currentValue = AR:GetMusicVolumeCVar()
  local restoreCVar = AR.savedMusicVolumeCVar or cvar
  local restoreValue = AR.savedMusicVolume or currentValue

  if cvar and currentValue then
    AR:StartMusicVolumeFade(cvar, currentValue, 0, seconds or 0, 1, restoreCVar, restoreValue, 1)
  else
    if StopMusic then pcall(function() StopMusic() end) end
    AR:RestoreGameMusicAfterIntro()
    AR:RestartGameMusic()
    AR.introUsingMusicChannel = nil
    AR.introAudioFading = nil
    AR:RestoreSoundSettings()
  end
end

function AR:FadeOutIntroNarration()
  if AR.introAudioFading then return end
  if not AR.introNarration and not AR.introSoundHandles and not AR.introUsingMusicChannel then
    AR:RestoreIntroButtons()
    return
  end

  local remainingSeconds = 0
  if AR.introNarration and AR.introNarration.duration and AR.introNarration.elapsed then
    remainingSeconds = (AR.introNarration.duration - AR.introNarration.elapsed) + 1
    if remainingSeconds < 0 then remainingSeconds = 0 end
    if remainingSeconds > (AR.introNarrationSeconds or 132.21) then remainingSeconds = (AR.introNarrationSeconds or 132.21) end
  end

  AR.introAudioFading = 1
  AR.introNarration = nil
  if AR.frames and AR.frames.introTicker then AR.frames.introTicker:Hide() end
  AR:RestoreIntroButtons()

  local seconds = AR.introStopFadeSeconds or 1.25

  if AR.introMusicState then
    AR:StopIntroMusicPlayback(nil)
    return
  end

  if AR.introUsingMusicChannel then
    if StopSound and AR.introSoundHandles then AR:StopIntroSoundFiles(seconds) end
    AR:FadeOutIntroMusicChannel(seconds)
    return
  end

  -- The zone music was only ducked, not stopped, so restoring the music volume
  -- here lets it keep playing while the custom WAVs fade away.
  AR:RestoreSoundSettings()

  local hasSoundHandles = StopSound and AR.introSoundHandles

  local cvar, oldValue = AR:GetSoundEffectVolumeCVar()
  if cvar and oldValue then
    AR:PrintSoundDebug("Stop clicked: fading " .. cvar .. " to stop Introlude mixed WAV.")
    AR.savedSoundEffectVolumeCVar = cvar
    AR.savedSoundEffectVolume = oldValue
    local needsMuteHold = not hasSoundHandles
    local holdSeconds = nil
    if needsMuteHold then holdSeconds = remainingSeconds end
    AR:StartSoundEffectVolumeFade(cvar, oldValue, 0, seconds, needsMuteHold, holdSeconds, oldValue)
  else
    AR:PrintSoundDebug("Stop clicked: no sound-volume CVar found; trying sound-enable flush.")
    AR:StopIntroSoundFiles(seconds)
    if not AR:StartSoundEffectEnableHold(remainingSeconds) then
      AR:FlushSoundEffectChannel()
    end
    AR.introAudioFading = nil
  end
end

function AR:CancelIntroNarration()
  AR.introNarration = nil
  if AR.frames and AR.frames.introTicker then AR.frames.introTicker:Hide() end
  AR:HardStopIntroAudio()

  AR:RestoreIntroButtons()
end

function AR:StopIntroNarration()
  if AR:IsIntroPlaybackActive() then
    AR:FadeOutIntroNarration()
  else
    AR.introNarration = nil
    if AR.frames and AR.frames.introTicker then AR.frames.introTicker:Hide() end
    AR:RestoreIntroButtons()
  end
  if AR.frames and AR.frames.main then
    if AR.frames.main.stopButton then AR.frames.main.stopButton:Hide() end
  end

  local cat = AR.categories and AR.categories[AR.activeCategory]
  if cat and AR.frames and AR.frames.main then
    local list = AR:GetQuestList(cat.key)
    local q = list[AR.activeQuest]
    if q and q.isInterlude then
      if AR.frames.main.playButton then AR.frames.main.playButton:Show() end
      if AR.frames.main.showTextButton then AR.frames.main.showTextButton:Show() end
    end
  end
end

function AR:UpdateIntroNarration(elapsed)
  if not AR.introNarration then
    if this then this:Hide() end
    return
  end

  local n = AR.introNarration
  n.elapsed = n.elapsed + (elapsed or 0)

  local wanted = math.floor(n.elapsed * n.cps)
  if wanted == n.lastCount then return end
  n.lastCount = wanted

  local totalLen = string.len(n.text or "")
  if wanted > totalLen then wanted = totalLen end

  -- Do not reset the scroll to the top while the narration is unfolding.
  AR:UpdateDescriptionScroll(string.sub(n.text, 1, wanted), 1)

  -- Follow the narration only after the revealed text is no longer fully visible.
  -- Until then, keep the scroll at the top so the words unfold naturally.
  local f = AR.frames.main
  if f and f.descriptionScroll and f.descriptionChild then
    local visibleH = f.descriptionScroll:GetHeight() or 1
    local contentH = f.descriptionChild:GetHeight() or visibleH
    local maxScroll = contentH - visibleH
    if maxScroll < 0 then maxScroll = 0 end

    if maxScroll <= 0 then
      f.descriptionScroll:SetVerticalScroll(0)
    else
      -- Scroll just enough to keep the newest revealed line visible near the bottom,
      -- not immediately to the bottom before the page is filled.
      local bottomPad = 18
      local follow = maxScroll + bottomPad
      if follow > maxScroll then follow = maxScroll end
      f.descriptionScroll:SetVerticalScroll(follow)
    end
  end

  if wanted >= totalLen or n.elapsed >= n.duration then
    local cat = AR.categories[AR.activeCategory]
    if cat then AR:CompleteQuest(cat.key, AR.activeQuest) end
    AR:StopIntroNarration()
  end
end

function AR:PlayIntroNarration()
  local cat = AR.categories[AR.activeCategory]
  if not cat then return end
  local list = AR:GetQuestList(cat.key)
  local q = list[AR.activeQuest]
  if not q or not q.isInterlude then return end

  if AR:IsIntroPlaybackActive() then AR:HardStopIntroAudio() end
  AR.introAudioFading = nil
  AR:UpdateDescriptionScroll("")

  local text = q.description or ""
  local duration = AR.introNarrationSeconds or 180
  local cps = AR.introCharsPerSecond or 14
  local len = string.len(text)
  if len > 0 and duration > 0 then
    cps = len / duration
  end

  AR.introNarration = {
    text=text,
    elapsed=0,
    duration=duration,
    cps=cps,
    lastCount=-1
  }

  AR:PrintIntroAudioDebug("Play Now clicked")
  if not AR:StartIntroMusicPlayback() then
    AR:PlayIntroAudioFiles("Play Now clicked", 1)
  end

  if AR.frames.main then
    if AR.frames.main.playButton then AR.frames.main.playButton:Hide() end
    if AR.frames.main.showTextButton then AR.frames.main.showTextButton:Hide() end
    if AR.frames.main.stopButton then AR.frames.main.stopButton:Show() end
  end

  if not AR.frames.introTicker then
    local ticker = CreateFrame("Frame", nil, UIParent)
    ticker:Hide()
    ticker:SetScript("OnUpdate", function() AR:UpdateIntroNarration(arg1) end)
    AR.frames.introTicker = ticker
  end
  AR.frames.introTicker:Show()
end

function AR:ShowIntroText()
  local cat = AR.categories[AR.activeCategory]
  if not cat then return end
  local list = AR:GetQuestList(cat.key)
  local q = list[AR.activeQuest]
  if not q or not q.isInterlude then return end
  AR:FadeOutIntroNarration()
  AR:UpdateDescriptionScroll(q.description or "")
  AR:CompleteQuest(cat.key, AR.activeQuest)
  if AR.frames.main and AR.frames.main.descriptionScroll then
    AR.frames.main.descriptionScroll:SetVerticalScroll(0)
  end
end

function AR:SetInterludeMode(enabled)
  local f = AR.frames.main
  if not f or not f.pageBuilt then return end

  if enabled then
    if f.page then f.page:Hide() end
    f.objectiveText:Hide()
    local i
    for i = 1, 3 do
      if f.objectiveLines[i] then f.objectiveLines[i]:Hide() end
      if f.objectiveChecks[i] then f.objectiveChecks[i]:Hide() end
    end
    f.targetIconHolder:Hide()
    f.targetIcon2Holder:Hide()
    f.targetNameText:Hide()
    f.targetLocationText:Hide()
    f.rewardIconHolder:Hide()
    f.rewardTextHolder:Hide()
    f.stamp:Show()

    local itd = AR:GetLayout("interludeText")
    f.descriptionScroll:ClearAllPoints()
    f.descriptionScroll:SetPoint("TOPLEFT", f.content, "TOPLEFT", itd.x, itd.y)
    f.descriptionScroll:SetWidth(itd.w)
    f.descriptionScroll:SetHeight(itd.h)
    f.descriptionChild:SetWidth(itd.w)
    f.descriptionText:SetWidth(itd.w)

    local ib = AR:GetLayout("interludeButtons")
    local playingIntro = AR:IsIntroPlaybackActive()
    if f.playButton then
      f.playButton:ClearAllPoints()
      f.playButton:SetPoint("TOPLEFT", f.content, "TOPLEFT", ib.x, ib.y)
      if playingIntro then f.playButton:Hide() else f.playButton:Show() end
    end
    if f.showTextButton then
      f.showTextButton:ClearAllPoints()
      f.showTextButton:SetPoint("LEFT", f.playButton, "RIGHT", 10, 0)
      if playingIntro then f.showTextButton:Hide() else f.showTextButton:Show() end
    end
    if f.stopButton then
      f.stopButton:ClearAllPoints()
      f.stopButton:SetPoint("LEFT", f.showTextButton, "RIGHT", 10, 0)
      if playingIntro then f.stopButton:Show() else f.stopButton:Hide() end
    end
  else
    if AR:IsIntroPlaybackActive() then AR:FadeOutIntroNarration() end
    if f.page then f.page:Show() end
    if f.playButton then f.playButton:Hide() end
    if f.showTextButton then f.showTextButton:Hide() end
    if f.stopButton then f.stopButton:Hide() end
    f.objectiveText:Show()
    local i
    for i = 1, 3 do
      if f.objectiveLines[i] then f.objectiveLines[i]:Show() end
    end
    f.targetIconHolder:Show()
    f.targetNameText:Show()
    f.targetLocationText:Show()
    f.rewardIconHolder:Show()
    f.rewardTextHolder:Show()
    f.stamp:Show()

    f.descriptionScroll:ClearAllPoints()
    f.descriptionScroll:SetPoint("TOPLEFT", f.content, "TOPLEFT", 58, -246)
    f.descriptionScroll:SetWidth(315)
    f.descriptionScroll:SetHeight(96)
    f.descriptionChild:SetWidth(315)
    f.descriptionText:SetWidth(315)
  end
end

function AR:BuildQuestPage()
  local f = AR.frames.main
  if not f or f.pageBuilt then return end

  -- Page template art. This is only the TGA artwork.
  f.page = CreateFrame("Frame", nil, f)
  f.page:SetPoint("TOPLEFT", f, "TOPLEFT", 292, -80)
  f.page:SetWidth(430)
  f.page:SetHeight(574)
  f.page:SetFrameLevel(f:GetFrameLevel() + 4)
  AddTileGrid(f.page, AR.assets.pageTemplateHuman, 430, 574, "ARTWORK")

  -- Dynamic content is a separate sibling frame above the page template.
  -- This avoids Vanilla frame-level weirdness where child tile frames cover text/icon textures.
  f.content = CreateFrame("Frame", nil, f)
  f.content:SetPoint("TOPLEFT", f, "TOPLEFT", 292, -80)
  f.content:SetWidth(430)
  f.content:SetHeight(574)
  f.content:SetFrameLevel(f:GetFrameLevel() + 80)
  f.content:EnableMouse(false)

  f.titleText = MakeFont(f.content, "GameFontNormalLarge", 52, -46, 335, 34, {r=0.30,g=0.02,b=0.015})
  f.titleText:SetJustifyH("LEFT")
  f.subtitleText = MakeFont(f.content, "GameFontHighlightSmall", 58, -80, 320, 26, {r=0.12,g=0.09,b=0.06})
  f.subtitleText:SetJustifyH("LEFT")

  f.objectiveText = MakeFont(f.content, "GameFontNormalSmall", 58, -126, 320, 36, {r=0.08,g=0.055,b=0.035})
  f.objectiveLines = {}
  f.objectiveChecks = {}
  local i
  for i = 1, 3 do
    local check = CreateFrame("Frame", nil, f.content)
    check:SetWidth(11)
    check:SetHeight(11)
    check:SetFrameLevel(f.content:GetFrameLevel() + 18)

    local box = check:CreateTexture(nil, "BACKGROUND")
    box:SetAllPoints(check)
    box:SetTexture(0.025, 0.020, 0.015, 0.78)

    local border = check:CreateTexture(nil, "BORDER")
    border:SetPoint("TOPLEFT", check, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", check, "BOTTOMRIGHT", 1, -1)
    border:SetTexture(0.62, 0.42, 0.18, 0.85)

    local tick = check:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    tick:SetPoint("CENTER", check, "CENTER", 0, -1)
    tick:SetTextColor(0.20, 0.85, 0.22)
    tick:SetText("X")
    tick:Hide()
    check.tick = tick

    local line = MakeFont(f.content, "GameFontNormalSmall", 84, -164 - ((i-1)*18), 285, 16, {r=0.08,g=0.055,b=0.035})
    f.objectiveLines[i] = line
    f.objectiveChecks[i] = check
  end

  f.descriptionScroll = CreateFrame("ScrollFrame", nil, f.content)
  f.descriptionScroll:SetPoint("TOPLEFT", f.content, "TOPLEFT", 58, -246)
  f.descriptionScroll:SetWidth(315)
  f.descriptionScroll:SetHeight(96)
  f.descriptionScroll:EnableMouseWheel(true)
  f.descriptionScroll:SetFrameLevel(f.content:GetFrameLevel() + 10)

  f.descriptionChild = CreateFrame("Frame", nil, f.descriptionScroll)
  f.descriptionChild:SetWidth(315)
  f.descriptionChild:SetHeight(96)
  f.descriptionScroll:SetScrollChild(f.descriptionChild)

  f.descriptionText = f.descriptionChild:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.descriptionText:SetPoint("TOPLEFT", f.descriptionChild, "TOPLEFT", 0, 0)
  f.descriptionText:SetWidth(315)
  f.descriptionText:SetJustifyH("LEFT")
  f.descriptionText:SetJustifyV("TOP")
  f.descriptionText:SetTextColor(0.08, 0.055, 0.035)

  f.descriptionScroll:SetScript("OnMouseWheel", function()
    local frame = this
    local child = AR.frames.main.descriptionChild
    if not child then return end
    local maxScroll = child:GetHeight() - frame:GetHeight()
    if maxScroll < 0 then maxScroll = 0 end
    local cur = frame:GetVerticalScroll()
    if arg1 > 0 then
      cur = cur - 24
    else
      cur = cur + 24
    end
    frame:SetVerticalScroll(Clamp(cur, 0, maxScroll))
  end)

  -- Stamp overlay, above parchment but below main text.
  f.stamp = f.content:CreateTexture(nil, "BACKGROUND")
  f.stamp:SetPoint("TOPLEFT", f.content, "TOPLEFT", 278, -330)
  f.stamp:SetWidth(112)
  f.stamp:SetHeight(112)
  f.stamp:SetTexture(AR.icons.stamp)
  f.stamp:SetAlpha(0.55)
  f.stamp:SetBlendMode("BLEND")

  -- Target icon layered exactly inside the existing template target frame.
  -- Use child frames so Vanilla respects frame levels above the tiled page art.
  f.targetIconHolder = CreateFrame("Frame", nil, f.content)
  f.targetIconHolder:SetPoint("TOPLEFT", f.content, "TOPLEFT", 60, -363)
  f.targetIconHolder:SetWidth(58)
  f.targetIconHolder:SetHeight(58)
  f.targetIconHolder:SetFrameLevel(f.content:GetFrameLevel() + 20)
  f.targetIcon = f.targetIconHolder:CreateTexture(nil, "OVERLAY")
  f.targetIcon:SetAllPoints(f.targetIconHolder)
  f.targetIcon:SetBlendMode("BLEND")
  f.targetIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  f.targetIcon2Holder = CreateFrame("Frame", nil, f.content)
  f.targetIcon2Holder:SetPoint("TOPLEFT", f.content, "TOPLEFT", 96, -393)
  f.targetIcon2Holder:SetWidth(34)
  f.targetIcon2Holder:SetHeight(34)
  f.targetIcon2Holder:SetFrameLevel(f.content:GetFrameLevel() + 21)
  f.targetIcon2 = f.targetIcon2Holder:CreateTexture(nil, "OVERLAY")
  f.targetIcon2:SetAllPoints(f.targetIcon2Holder)
  f.targetIcon2:SetBlendMode("BLEND")
  f.targetIcon2:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.targetIcon2Holder:Hide()

  f.targetNameText = MakeFont(f.content, "GameFontNormal", 136, -360, 240, 22, {r=0.06,g=0.04,b=0.025})
  f.targetLocationText = MakeFont(f.content, "GameFontNormalSmall", 136, -384, 235, 42, {r=0.08,g=0.055,b=0.035})

  -- Reward icon layered exactly inside the existing template reward icon slot.
  f.rewardIconHolder = CreateFrame("Frame", nil, f.content)
  f.rewardIconHolder:SetPoint("TOPLEFT", f.content, "TOPLEFT", 68, -492)
  f.rewardIconHolder:SetWidth(45)
  f.rewardIconHolder:SetHeight(45)
  f.rewardIconHolder:SetFrameLevel(f.content:GetFrameLevel() + 20)
  f.rewardIcon = f.rewardIconHolder:CreateTexture(nil, "OVERLAY")
  f.rewardIcon:SetAllPoints(f.rewardIconHolder)
  f.rewardIcon:SetBlendMode("BLEND")
  f.rewardIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

  f.rewardTextHolder = CreateFrame("Frame", nil, f.content)
  f.rewardTextHolder:SetPoint("TOPLEFT", f.content, "TOPLEFT", 126, -484)
  f.rewardTextHolder:SetWidth(260)
  f.rewardTextHolder:SetHeight(58)
  f.rewardTextHolder:SetFrameLevel(f.content:GetFrameLevel() + 22)
  f.rewardNameText = MakeFont(f.rewardTextHolder, "GameFontNormal", 0, 0, 250, 22, {r=0.86,g=0.63,b=0.20})
  f.rewardDetailText = MakeFont(f.rewardTextHolder, "GameFontNormalSmall", 0, -24, 250, 22, {r=0.84,g=0.62,b=0.24})

  f.playButton = CreateFrame("Button", nil, f.content)
  f.playButton:SetPoint("TOPLEFT", f.content, "TOPLEFT", 58, -480)
  f.playButton:SetWidth(110)
  f.playButton:SetHeight(24)
  f.playButton:SetNormalTexture("Interface\Buttons\UI-Panel-Button-Up")
  f.playButton:SetPushedTexture("Interface\Buttons\UI-Panel-Button-Down")
  f.playButton:SetHighlightTexture("Interface\Buttons\UI-Panel-Button-Highlight")
  f.playButton:SetFrameLevel(f.content:GetFrameLevel() + 22)
  local playText = f.playButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  playText:SetPoint("CENTER", f.playButton, "CENTER", 0, 0)
  playText:SetText("Play Now")
  f.playButton:SetScript("OnClick", function() AR:PlayIntroNarration() end)
  f.playButton:Hide()

  f.showTextButton = CreateFrame("Button", nil, f.content)
  f.showTextButton:SetPoint("LEFT", f.playButton, "RIGHT", 10, 0)
  f.showTextButton:SetWidth(100)
  f.showTextButton:SetHeight(24)
  f.showTextButton:SetNormalTexture("Interface\Buttons\UI-Panel-Button-Up")
  f.showTextButton:SetPushedTexture("Interface\Buttons\UI-Panel-Button-Down")
  f.showTextButton:SetHighlightTexture("Interface\Buttons\UI-Panel-Button-Highlight")
  f.showTextButton:SetFrameLevel(f.content:GetFrameLevel() + 22)
  local showText = f.showTextButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  showText:SetPoint("CENTER", f.showTextButton, "CENTER", 0, 0)
  showText:SetText("Show Text")
  f.showTextButton:SetScript("OnClick", function() AR:ShowIntroText() end)
  f.showTextButton:Hide()

  f.stopButton = CreateFrame("Button", nil, f.content)
  f.stopButton:SetPoint("LEFT", f.showTextButton, "RIGHT", 10, 0)
  f.stopButton:SetWidth(80)
  f.stopButton:SetHeight(24)
  f.stopButton:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
  f.stopButton:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
  f.stopButton:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
  f.stopButton:SetFrameLevel(f.content:GetFrameLevel() + 22)
  local stopText = f.stopButton:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  stopText:SetPoint("CENTER", f.stopButton, "CENTER", 0, 0)
  stopText:SetText("Stop")
  f.stopButton:SetScript("OnClick", function() AR:FadeOutIntroNarration() end)
  f.stopButton:Hide()

  -- Texture smoke test square. Hidden by default; /ar textures shows it.
  f.textureTest = f.content:CreateTexture(nil, "OVERLAY")
  f.textureTest:SetPoint("TOPRIGHT", f.content, "TOPRIGHT", -10, -10)
  f.textureTest:SetWidth(32)
  f.textureTest:SetHeight(32)
  f.textureTest:SetTexture(AR.icons.manifest)
  f.textureTest:Hide()

  f.pageBuilt = 1
  AR:ApplyThemedFonts()
  AR:ApplyLayout()
end

local function AREstimateTextHeight(text, charsPerLine, lineHeight)
  if not text then return 96 end
  local lines = 1
  local i
  local len = string.len(text)
  local wrapped = math.floor(len / charsPerLine) + 1

  for i = 1, len do
    if string.sub(text, i, i) == "\n" then
      lines = lines + 1
    end
  end

  if wrapped > lines then lines = wrapped end
  return (lines * lineHeight) + 18
end

function AR:UpdateDescriptionScroll(text, keepScroll)
  local f = AR.frames.main
  if not f or not f.descriptionText then return end
  if not keepScroll then f.descriptionScroll:SetVerticalScroll(0) end
  f.descriptionText:SetText(text or "")

  -- Vanilla 1.12 does not reliably expose FontString:GetStringHeight().
  -- Estimate height so long quest copy can still scroll without throwing errors.
  local width = f.descriptionScroll:GetWidth() or 315
  local chars = math.floor(width / 6)
  if chars < 30 then chars = 30 end

  -- Interlude text uses a large cinematic area. Estimate conservatively so it
  -- does not start scrolling until the revealed words truly pass the bottom.
  local lineHeight = 15
  local h = AREstimateTextHeight(text or "", chars, lineHeight)
  local visibleH = f.descriptionScroll:GetHeight() or 96
  if h < visibleH then h = visibleH end
  f.descriptionChild:SetHeight(h)
end

function AR:RenderQuestDetail()
  local f = AR.frames.main
  if not f then return end
  AR:BuildQuestPage()

  local cat = AR.categories[AR.activeCategory]
  local list = AR:GetQuestList(cat.key)
  local q = list[AR.activeQuest]

  if not q then
    f.titleText:SetText(cat.title)
    f.subtitleText:SetText("This relic chain is waiting to be written.")
    f.objectiveText:SetText("No quests are loaded for this relic chain yet.")
    local i
    for i = 1, 3 do
      f.objectiveLines[i]:SetText("")
      if f.objectiveChecks and f.objectiveChecks[i] then f.objectiveChecks[i]:Hide() end
    end
    AR:UpdateDescriptionScroll("Future Ashen Relics content will use this same quest-page system.")
    f.targetIcon:SetTexture("")
    f.targetIcon2Holder:Hide()
    f.targetNameText:SetText("Unknown")
    f.targetLocationText:SetText("")
    f.rewardIcon:SetTexture(AR.icons.rep)
    f.rewardNameText:SetText("No reward")
    f.rewardDetailText:SetText("")
    AR:SetInterludeMode(nil)
    return
  end

  if AR.activeEvidenceQuest then
    local evidenceQuest = list[AR.activeEvidenceQuest]
    local evidence = AR:GetEvidenceLog(cat.key, AR.activeEvidenceQuest)
    if evidenceQuest and evidence then
      AR:SetInterludeMode(nil)
      f.titleText:SetText(evidence.questTitle or evidenceQuest.title or "")
      f.subtitleText:SetText(evidence.title or "Evidence Recovered")
      f.objectiveText:SetText("Completion Dialogue")

      local ei
      for ei = 1, 3 do
        f.objectiveLines[ei]:SetText("")
        if f.objectiveChecks and f.objectiveChecks[ei] then
          f.objectiveChecks[ei]:Hide()
          if f.objectiveChecks[ei].tick then f.objectiveChecks[ei].tick:Hide() end
        end
      end

      AR:UpdateDescriptionScroll(evidence.body or "")
      if evidenceQuest.targetIcon then f.targetIcon:SetTexture(evidenceQuest.targetIcon) else f.targetIcon:SetTexture(AR.icons.manifest) end
      f.targetIcon2Holder:Hide()
      f.targetNameText:SetText("Evidence Recovered")
      f.targetLocationText:SetText(evidence.subtitle or evidenceQuest.targetLocation or "")
      if evidenceQuest.rewardIcon then f.rewardIcon:SetTexture(evidenceQuest.rewardIcon) else f.rewardIcon:SetTexture(AR.icons.rep) end
      f.rewardNameText:SetText(evidence.questTitle or evidenceQuest.title or "")
      f.rewardDetailText:SetText("Recovered completion record")
      AR:ApplyThemedFonts()
      f.rewardNameText:SetTextColor(0.86, 0.63, 0.20)
      f.rewardDetailText:SetTextColor(0.84, 0.62, 0.24)
      return
    end
    AR.activeEvidenceQuest = nil
  end

  local completed = AR:IsQuestComplete(cat.key, AR.activeQuest)
  local objectiveText = q.objectiveText or ""
  local objectives = q.objectives
  local targetName = q.targetName or ""
  local targetLocation = q.targetLocation or ""

  if cat.key == "human" and AR.activeQuest == 5 and not completed then
    local livingStage = AR:GetLivingMeasureStage()
    if livingStage == "question_goblin" then
      objectiveText = "Question the suspicious goblin near Ratchet salvage."
      objectives = {
        { text="Question Suspicious Goblin", required=1, flagKey="livingMeasureGoblinRevealed" },
      }
      targetName = "Suspicious Goblin"
      targetLocation = "Near the Ratchet salvage, The Barrens"
    elseif livingStage == "skimmer_hold" then
      objectiveText = "Search the hold on the goblin's skimmer for the Cracked Survey Lens."
      objectives = {
        { text="Cracked Survey Lens", required=1, itemKey="lens" },
      }
      targetName = "Goblin Skimmer Hold"
      targetLocation = "Small skimmer behind the suspicious goblin, Ratchet"
    elseif livingStage == "search_salvage" then
      objectiveText = "Search salvage around Ratchet for signs of the Cracked Survey Lens."
      targetName = "Cracked Survey Lens"
      targetLocation = "Ratchet salvage piles"
    end
  end

  f.titleText:SetText(q.title or "")
  f.subtitleText:SetText(q.subtitle or "")
  f.objectiveText:SetText(objectiveText)

  if q.isInterlude then
    AR:SetInterludeMode(1)
    if not AR:IsIntroPlaybackActive() then
      AR:UpdateDescriptionScroll("")
    end
    local ii
    for ii = 1, 3 do
      f.objectiveLines[ii]:SetText("")
      if f.objectiveChecks and f.objectiveChecks[ii] then
        f.objectiveChecks[ii]:Hide()
        if f.objectiveChecks[ii].tick then f.objectiveChecks[ii].tick:Hide() end
      end
    end
    f.targetIcon:SetTexture("")
    f.targetIcon2Holder:Hide()
    f.targetNameText:SetText("")
    f.targetLocationText:SetText("")
    f.rewardIcon:SetTexture("")
    f.rewardNameText:SetText("")
    f.rewardDetailText:SetText("")
    AR:ApplyThemedFonts()
    return
  else
    AR:SetInterludeMode(nil)
  end

  local i
  for i = 1, 3 do
    f.objectiveLines[i]:SetText("")
    if f.objectiveChecks and f.objectiveChecks[i] then
      f.objectiveChecks[i]:Hide()
      if f.objectiveChecks[i].tick then f.objectiveChecks[i].tick:Hide() end
    end
  end
  if objectives then
    for i = 1, table.getn(objectives) do
      if i <= 3 then
        local obj = objectives[i]
        local current = AR:GetObjectiveProgress(obj)
        local req = obj.required or 1
        if completed and current < req then current = req end
        if f.objectiveChecks and f.objectiveChecks[i] then
          f.objectiveChecks[i]:Show()
          if current >= req and f.objectiveChecks[i].tick then f.objectiveChecks[i].tick:Show() end
        end
        f.objectiveLines[i]:SetText(obj.text .. ": " .. current .. "/" .. req)
      end
    end
  end

  AR:UpdateDescriptionScroll(q.description or "")

  if q.targetIcon then f.targetIcon:SetTexture(q.targetIcon) else f.targetIcon:SetTexture("") end
  if q.targetIcon2 then
    f.targetIcon2:SetTexture(q.targetIcon2)
    f.targetIcon2Holder:Show()
  else
    f.targetIcon2Holder:Hide()
  end

  f.targetNameText:SetText(targetName)
  f.targetLocationText:SetText(targetLocation)

  if q.rewardIcon then f.rewardIcon:SetTexture(q.rewardIcon) else f.rewardIcon:SetTexture(AR.icons.rep) end
  f.rewardNameText:SetText(q.rewardName or "")
  local detail = q.rewardDetail or ""
  if (not detail or detail == "") and q.rewardRep then detail = q.rewardRep .. " Banner Reputation" end
  f.rewardDetailText:SetText(detail)
  AR:ApplyThemedFonts()
  if q.rewardType == "artifact" then
    f.rewardNameText:SetTextColor(1.0, 0.48, 0.08)
    f.rewardDetailText:SetTextColor(0.95, 0.68, 0.22)
  else
    f.rewardNameText:SetTextColor(0.86, 0.63, 0.20)
    f.rewardDetailText:SetTextColor(0.84, 0.62, 0.24)
  end
end

function AR:CreateMinimapButton()
  if AR.frames.minimapButton then return end

  local b = CreateFrame("Button", "AshenRelicsMinimapButton", Minimap)
  b:SetWidth(32)
  b:SetHeight(32)
  b:SetFrameStrata("MEDIUM")
  b:SetPoint("TOPLEFT", Minimap, "TOPLEFT", 4, -4)
  b:SetMovable(true)
  b:EnableMouse(true)

  local border = b:CreateTexture(nil, "OVERLAY")
  border:SetWidth(54)
  border:SetHeight(54)
  border:SetPoint("TOPLEFT", b, "TOPLEFT", -11, 11)
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  local icon = b:CreateTexture(nil, "BACKGROUND")
  icon:SetWidth(20)
  icon:SetHeight(20)
  icon:SetPoint("CENTER", b, "CENTER", 0, 0)
  icon:SetTexture(AR.icons.rep)
  icon:SetTexCoord(0.12, 0.88, 0.12, 0.88)

  b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  b:SetScript("OnClick", function()
    AR:ToggleMain()
  end)
  b:SetScript("OnEnter", function()
    GameTooltip:SetOwner(this, "ANCHOR_LEFT")
    GameTooltip:SetText("Ashen Relics", 1, 0.82, 0)
    GameTooltip:AddLine("Click to open the quest log.", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)

  AR.frames.minimapButton = b
end

function AR:GetCurrentZoneName()
  local zone = nil
  if GetRealZoneText then zone = GetRealZoneText() end
  if (not zone or zone == "") and GetZoneText then zone = GetZoneText() end
  return zone or ""
end

function AR:GetPlayerMapPositionSafe()
  if not GetPlayerMapPosition then return nil, nil end
  if SetMapToCurrentZone and not (WorldMapFrame and WorldMapFrame:IsShown()) then
    pcall(function() SetMapToCurrentZone() end)
  end
  local ok, x, y = pcall(function() return GetPlayerMapPosition("player") end)
  if not ok or not x or not y then return nil, nil end
  if x <= 0 and y <= 0 then return nil, nil end
  return x, y
end

function AR:NormalizeMapCoord(value)
  local n = tonumber(value)
  if not n then return nil end
  if n > 1 then n = n / 100 end
  return n
end

function AR:GetSpotMapCoords(spot)
  if not spot then return nil, nil end
  return AR:NormalizeMapCoord(spot.x), AR:NormalizeMapCoord(spot.y)
end

function AR:GetSpotDistanceFromPlayer(spot, px, py)
  if not spot or not px or not py then return nil end
  local sx, sy = AR:GetSpotMapCoords(spot)
  if not sx or not sy then return nil end
  local dx = px - sx
  local dy = py - sy
  return math.sqrt((dx * dx) + (dy * dy))
end

function AR:GetUiNow()
  if GetTime then return GetTime() end
  if time then return time() end
  return 0
end

function AR:SetHumanQ1SearchGrace(index)
  AR.humanQ1SearchGrace = { index=index, expires=AR:GetUiNow() + 0.80 }
end

function AR:IsHumanQ1SearchGrace(index)
  local grace = AR.humanQ1SearchGrace
  if not grace or grace.index ~= index then return nil end
  if AR:GetUiNow() > (grace.expires or 0) then return nil end
  return 1
end

function AR:IsTooltipShowingText(text)
  if not text or not GameTooltip or not GameTooltip:IsShown() then return nil end
  local i
  for i = 1, 4 do
    local line = getglobal and getglobal("GameTooltipTextLeft" .. i)
    if line and line.GetText then
      local value = line:GetText()
      if value and string.find(value, text, 1, true) then return 1 end
    end
  end
  return nil
end

function AR:GetHumanQ1SearchDB()
  if not AshenRelicsDB.flags then AshenRelicsDB.flags = {} end
  if not AshenRelicsDB.flags.humanQ1StrongboxUnlocks then AshenRelicsDB.flags.humanQ1StrongboxUnlocks = {} end
  return AshenRelicsDB.flags.humanQ1StrongboxUnlocks
end

function AR:GetHumanQ1SpotProgress(index)
  local searches = AR:GetHumanQ1SearchDB()
  if searches and searches[index] then return searches[index] end
  return 0
end

function AR:GetHumanQ1SpotRequired(index)
  local spot = AR.humanQ1SearchSpots and AR.humanQ1SearchSpots[index]
  if spot and spot.required then return spot.required end
  return 1
end

function AR:IsHumanQ1SpotSearched(index)
  if AR:GetHumanQ1SpotProgress(index) >= AR:GetHumanQ1SpotRequired(index) then return 1 end
  return nil
end

function AR:RepairHumanQ1SearchProgress()
  if AR:IsQuestComplete("human", 3) then return end
  local searches = AR:GetHumanQ1SearchDB()
  local manifestCount = AR:GetItemCount("manifest")
  local searchCount = 0
  local i
  for i = 1, table.getn(AR.humanQ1SearchSpots) do
    searchCount = searchCount + (searches[i] or 0)
  end
  if manifestCount >= searchCount then return end

  for i = table.getn(AR.humanQ1SearchSpots), 1, -1 do
    while searches[i] and searches[i] > 0 and searchCount > manifestCount do
      searches[i] = searches[i] - 1
      searchCount = searchCount - 1
      if searches[i] <= 0 then searches[i] = nil end
    end
  end
end

function AR:IsHumanQ1Active()
  if not AR:IsQuestAccepted("human", 3) then return nil end
  if AR:IsQuestComplete("human", 3) then return nil end
  return 1
end

function AR:GetHumanQ1SearchCount()
  local count = 0
  local i
  for i = 1, table.getn(AR.humanQ1SearchSpots) do
    local progress = AR:GetHumanQ1SpotProgress(i)
    local required = AR:GetHumanQ1SpotRequired(i)
    if progress > required then progress = required end
    count = count + progress
  end
  return count
end

function AR:GetHumanQ1SearchRequired()
  local total = 0
  local i
  for i = 1, table.getn(AR.humanQ1SearchSpots) do
    total = total + AR:GetHumanQ1SpotRequired(i)
  end
  return total
end

function AR:IsHumanQ1ReadyToComplete()
  AR:RepairHumanQ1SearchProgress()
  if AR:GetItemCount("cargo_key") < 1 then return nil end
  if AR:GetHumanQ1SearchCount() < AR:GetHumanQ1SearchRequired() then return nil end
  return 1
end

function AR:GetHumanQ1ProgressText()
  local keyCount = AR:GetItemCount("cargo_key")
  if keyCount > 1 then keyCount = 1 end
  local manifests = AR:GetHumanQ1SearchCount()
  local required = AR:GetHumanQ1SearchRequired()
  if manifests > required then manifests = required end
  return "Cargo key: " .. keyCount .. "/1  Manifests: " .. manifests .. "/" .. required
end

function AR:MergeSearchSpotWithSaved(base, saved)
  if not base then return saved end
  if not saved or not saved.x or not saved.y then return base end
  local merged = {}
  local k, v
  for k, v in pairs(base) do merged[k] = v end
  merged.name = base.name or saved.name
  merged.zone = saved.zone or base.zone
  merged.x = saved.x or base.x
  merged.y = saved.y or base.y
  local savedRadius = tonumber(saved.radius)
  local baseRadius = tonumber(base.radius)
  if saved.radiusTuned or (savedRadius and baseRadius and savedRadius < baseRadius) then
    merged.radius = savedRadius or baseRadius
  else
    merged.radius = baseRadius or savedRadius
  end
  return merged
end

function AR:GetRuntimeHumanQ1SearchSpot(index)
  local base = AR.humanQ1SearchSpots and AR.humanQ1SearchSpots[index]
  if not base then return nil end
  local db = AshenRelicsDB.dev and AshenRelicsDB.dev.humanQ1SearchSpots
  local saved = db and db[index]
  return AR:MergeSearchSpotWithSaved(base, saved)
end

function AR:GetRuntimeHumanLocalSearchSpot(key)
  local base = AR.humanLocalSearchSpots and AR.humanLocalSearchSpots[key]
  if not base then return nil end
  local db = AshenRelicsDB.dev and AshenRelicsDB.dev.humanLocalSearchSpots
  local saved = db and db[key]
  return AR:MergeSearchSpotWithSaved(base, saved)
end

function AR:GetNearbyHumanQ1SearchSpot()
  if not AR:IsHumanQ1Active() then return nil end
  AR:RepairHumanQ1SearchProgress()
  local zone = AR:GetCurrentZoneName()
  local x, y = AR:GetPlayerMapPositionSafe()
  if not x or not y then return nil end

  local bestSpot = nil
  local bestIndex = nil
  local bestDistance = nil
  local i
  for i = 1, table.getn(AR.humanQ1SearchSpots) do
    local spot = AR:GetRuntimeHumanQ1SearchSpot(i)
    if spot and not AR:IsHumanQ1SpotSearched(i) and zone == spot.zone then
      local distance = AR:GetSpotDistanceFromPlayer(spot, x, y)
      if distance and distance <= (spot.radius or 0.0018) then
        local allowed = 1
        if spot.requiredItemKey and AR:GetItemCount(spot.requiredItemKey) < 1 then allowed = nil end
        -- Do not require the strongbox tooltip to still be visible. On some 1.12 clients
        -- the tooltip drops when the cursor moves from the object to this custom button,
        -- which could make the third manifest appear clickable but never loot.
        if allowed then
          if not bestDistance or distance < bestDistance then
            bestDistance = distance
            bestSpot = spot
            bestIndex = i
          end
        end
      end
    end
  end
  -- If the third manifest is the only one left, allow a slightly wider lower-hold fallback.
  -- This protects against ship-interior coordinate drift in Vanilla, where the lower deck can
  -- report nearly the same 2D map position as nearby planks. The first two boxes remain tighter
  -- so the button is less likely to appear while targeting through the ship wall.
  if not bestIndex and AR:GetHumanQ1SearchCount() >= 2 and AR:GetItemCount("cargo_key") >= 1 then
    for i = 1, table.getn(AR.humanQ1SearchSpots) do
      local spot = AR:GetRuntimeHumanQ1SearchSpot(i)
      if spot and not AR:IsHumanQ1SpotSearched(i) and zone == spot.zone then
        local distance = AR:GetSpotDistanceFromPlayer(spot, x, y)
        if distance and distance <= (AR.humanQ1ThirdManifestFallbackRadius or 0.0065) then
          bestIndex = i
          bestSpot = spot
          break
        end
      end
    end
  end

  if bestIndex then AR:SetHumanQ1SearchGrace(bestIndex) end
  return bestIndex, bestSpot
end

function AR:GetGraceHumanQ1SearchSpot()
  local grace = AR.humanQ1SearchGrace
  if not grace or not grace.index or AR:GetUiNow() > (grace.expires or 0) then return nil end
  local index = grace.index
  local spot = AR:GetRuntimeHumanQ1SearchSpot(index)
  if not spot or not AR:IsHumanQ1Active() or AR:IsHumanQ1SpotSearched(index) then return nil end

  local zone = AR:GetCurrentZoneName()
  local x, y = AR:GetPlayerMapPositionSafe()
  if not x or not y or zone ~= spot.zone then return nil end
  local distance = AR:GetSpotDistanceFromPlayer(spot, x, y)
  if distance and distance <= (spot.radius or 0.0018) then return index, spot end
  return nil
end

function AR:GetHumanLocalSearchDB()
  if not AshenRelicsDB.flags then AshenRelicsDB.flags = {} end
  if not AshenRelicsDB.flags.humanLocalSearches then AshenRelicsDB.flags.humanLocalSearches = {} end
  return AshenRelicsDB.flags.humanLocalSearches
end

function AR:IsHumanLocalSearchComplete(key)
  local db = AR:GetHumanLocalSearchDB()
  if key == "living_measure_dockside_salvage" and db and db.living_measure_bootybay_salvage then return 1 end
  if db and db[key] then return 1 end
  return nil
end

function AR:GetFlag(key)
  if not key or not AshenRelicsDB.flags then return nil end
  return AshenRelicsDB.flags[key]
end

function AR:SetFlag(key, value)
  if not key then return end
  if not AshenRelicsDB.flags then AshenRelicsDB.flags = {} end
  AshenRelicsDB.flags[key] = value or 1
end

function AR:GetLivingMeasureSalvageSearchCount()
  local db = AR:GetHumanLocalSearchDB()
  local count = 0
  if db.living_measure_cache then count = count + 1 end
  if db.living_measure_dockside_salvage or db.living_measure_bootybay_salvage then count = count + 1 end
  return count
end

function AR:IsLivingMeasureSalvageComplete()
  if AR:GetLivingMeasureSalvageSearchCount() >= 2 then return 1 end
  return nil
end

function AR:IsLivingMeasureGoblinReady()
  if not AR:IsQuestAccepted("human", 5) then return nil end
  if AR:IsQuestComplete("human", 5) then return nil end
  if AR:GetItemCount("lens") >= 1 then return nil end
  if AR:GetFlag("livingMeasureGoblinRevealed") then return nil end
  return AR:IsLivingMeasureSalvageComplete()
end

function AR:GetLivingMeasureGoblinStage()
  local stage = AR:GetFlag("livingMeasureGoblinStage") or 1
  if stage < 1 then stage = 1 end
  if stage > 3 then stage = 3 end
  return stage
end

function AR:GetLivingMeasureStage()
  if not AR:IsQuestAccepted("human", 5) or AR:IsQuestComplete("human", 5) then return nil end
  if AR:GetItemCount("lens") >= 1 then return "return_lens" end
  if AR:GetFlag("livingMeasureGoblinRevealed") then return "skimmer_hold" end
  if AR:IsLivingMeasureSalvageComplete() then return "question_goblin" end
  return "search_salvage"
end

function AR:IsHumanLocalSearchUnlocked(key, spot)
  if not spot then return nil end
  if spot.requiresFlag and not AR:GetFlag(spot.requiresFlag) then return nil end
  if spot.blocksFlag and AR:GetFlag(spot.blocksFlag) then return nil end
  return 1
end

function AR:GetNearbyHumanLocalSearchSpot()
  local zone = AR:GetCurrentZoneName()
  local x, y = AR:GetPlayerMapPositionSafe()
  if not x or not y then return nil end

  local key, spot
  for key, spot in pairs(AR.humanLocalSearchSpots) do
    spot = AR:GetRuntimeHumanLocalSearchSpot(key)
    if spot and spot.questIndex and AR:IsQuestAccepted("human", spot.questIndex) and not AR:IsQuestComplete("human", spot.questIndex) then
      if AR:IsHumanLocalSearchUnlocked(key, spot) and not AR:IsHumanLocalSearchComplete(key) and (not spot.itemKey or AR:GetItemCount(spot.itemKey) < 1) and zone == spot.zone then
        local distance = AR:GetSpotDistanceFromPlayer(spot, x, y)
        if distance and distance <= (spot.radius or 0.006) then
          return key, spot
        end
      end
    end
  end
  return nil
end

function AR:GetNearbyHumanSearchSpot()
  local index, spot = AR:GetNearbyHumanQ1SearchSpot()
  if index and spot then return "q1", index, spot end

  index, spot = AR:GetGraceHumanQ1SearchSpot()
  if index and spot then return "q1", index, spot end

  local key, localSpot = AR:GetNearbyHumanLocalSearchSpot()
  if key and localSpot then return "local", key, localSpot end

  return nil
end

function AR:CreateHumanQ1SearchResultFrame()
  if AR.frames.humanQ1SearchResult then return end

  local f = CreateFrame("Frame", "AshenRelicsHumanQ1SearchResult", UIParent)
  f:SetWidth(360)
  f:SetHeight(214)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 18)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetBackdrop({
    bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
    tile=1, tileSize=32, edgeSize=32,
    insets={left=8,right=8,top=8,bottom=8}
  })
  f:EnableMouse(true)
  f:Hide()

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.title:SetPoint("TOP", f, "TOP", 0, -24)
  f.title:SetWidth(310)
  f.title:SetJustifyH("CENTER")

  f.body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.body:SetPoint("TOPLEFT", f, "TOPLEFT", 34, -58)
  f.body:SetWidth(292)
  f.body:SetHeight(100)
  f.body:SetJustifyH("LEFT")
  f.body:SetJustifyV("TOP")

  local close = CreateFrame("Button", nil, f)
  close:SetPoint("BOTTOM", f, "BOTTOM", 0, 24)
  close:SetWidth(120)
  close:SetHeight(26)
  close:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
  close:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
  close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
  local text = close:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  text:SetPoint("CENTER", close, "CENTER", 0, 1)
  text:SetText("Okay")
  close:SetScript("OnClick", function() AR.frames.humanQ1SearchResult:Hide() end)

  AR.frames.humanQ1SearchResult = f
end

function AR:ShowHumanQ1SearchResult(title, body)
  AR:CreateHumanQ1SearchResultFrame()
  local f = AR.frames.humanQ1SearchResult
  f.title:SetText(title or "Record found.")
  f.body:SetText(body or "")
  f:Show()
end

function AR:GetHumanQ1SpotStageText(spot, index, field, fallback)
  if not spot then return fallback end
  local list = spot[field]
  if list and list[index] then return list[index] end
  return fallback
end

function AR:GetHumanQ1ManifestResult(index, field, fallback)
  local entry = AR.humanQ1ManifestResults and AR.humanQ1ManifestResults[index]
  if entry and entry[field] then return entry[field] end
  return fallback
end

function AR:SearchHumanQ1Spot(index)
  local spot = AR.humanQ1SearchSpots[index]
  if not spot or not AR:IsHumanQ1Active() then return end
  if AR:IsHumanQ1SpotSearched(index) then return end
  if spot.requiredItemKey and AR:GetItemCount(spot.requiredItemKey) < 1 then
    AR:ShowEvidenceToast("Buccaneer's Cargo Key required.", "Search Southsea sailors for the key before unlocking these strongboxes.")
    return
  end
  -- The player already earned the custom button by being at the strongbox.
  -- Allow the click through grace even if the game tooltip vanished before the click lands.
  local nearbyIndex = AR:GetNearbyHumanQ1SearchSpot()
  if nearbyIndex ~= index and not AR:IsHumanQ1SearchGrace(index) then return end

  AR:PlaySearchSound()
  AR:KneelThenStand()

  local searches = AR:GetHumanQ1SearchDB()
  local current = searches[index] or 0
  local nextProgress = current + 1
  local required = AR:GetHumanQ1SpotRequired(index)
  if nextProgress > required then nextProgress = required end
  searches[index] = nextProgress
  if spot.itemKey and current < nextProgress then
    if not AshenRelicsDB.items then AshenRelicsDB.items = {} end
    if (AshenRelicsDB.items[spot.itemKey] or 0) < AR:GetHumanQ1SearchRequired() then
      AshenRelicsDB.items[spot.itemKey] = (AshenRelicsDB.items[spot.itemKey] or 0) + 1
    end
    -- Keep manifest item count synced to strongbox progress so a missed/failed
    -- item increment cannot leave the third manifest stuck as searched-but-unlootable.
    if spot.itemKey == "manifest" then
      local searchedTotal = AR:GetHumanQ1SearchCount()
      if (AshenRelicsDB.items.manifest or 0) < searchedTotal then
        AshenRelicsDB.items.manifest = searchedTotal
      end
    end
  end
  if spot.consumeItemKey and AshenRelicsDB.items and AshenRelicsDB.items[spot.consumeItemKey] then
    AshenRelicsDB.items[spot.consumeItemKey] = AshenRelicsDB.items[spot.consumeItemKey] - 1
    if AshenRelicsDB.items[spot.consumeItemKey] <= 0 then AshenRelicsDB.items[spot.consumeItemKey] = nil end
  end

  local manifestStage = AR:GetHumanQ1SearchCount()
  local resultTitle = AR:GetHumanQ1ManifestResult(manifestStage, "title", spot.resultTitle)
  local resultBody = AR:GetHumanQ1ManifestResult(manifestStage, "body", spot.resultBody)
  AR:ShowHumanQ1SearchResult(resultTitle, resultBody)
  AR:ShowEvidenceToast("Moldy Shipping Manifest recovered. " .. manifestStage .. "/" .. AR:GetHumanQ1SearchRequired(), "Quest item recovered.")
  if manifestStage == 1 then
    AR:SpeakMutter(
      "q2_manifest_first_thought",
      '"First manifest. Emberfall was cargo before it was mystery."',
      '"First manifest. Emberfall was cargo before it was mystery."'
    )
  elseif manifestStage == 2 then
    AR:SpeakMutter(
      "q2_manifest_second_thought",
      '"Same route marks. Different copy. Someone wanted this shipment remembered by coin, not people."',
      '"Same route marks. Different copy. Someone wanted this shipment remembered by coin, not people."'
    )
  elseif manifestStage >= AR:GetHumanQ1SearchRequired() then
    AR:SpeakMutter(
      "q2_manifest_final_thought",
      '"That should be enough for Gazlowe. If Emberfall passed through Ratchet, these papers prove it."',
      '"That should be enough for Gazlowe. If Emberfall passed through Ratchet, these papers prove it."'
    )
  end
  if AR.frames.humanQ1SearchButton then AR.frames.humanQ1SearchButton:Hide() end
  if AR.frames and AR.frames.bag then AR:RefreshBag() end
  AR:RenderQuestDetail()
  AR:UpdateQuestOverlays()
end

function AR:SearchHumanLocalSpot(key)
  local spot = AR.humanLocalSearchSpots and AR.humanLocalSearchSpots[key]
  if not key or not spot then return end
  if not spot.questIndex or not AR:IsQuestAccepted("human", spot.questIndex) or AR:IsQuestComplete("human", spot.questIndex) then return end
  if AR:IsHumanLocalSearchComplete(key) then return end
  if not AR:IsHumanLocalSearchUnlocked(key, spot) then return end

  local nearbyType, nearbyKey = AR:GetNearbyHumanSearchSpot()
  if nearbyType ~= "local" or nearbyKey ~= key then return end

  AR:PlaySearchSound()

  local db = AR:GetHumanLocalSearchDB()
  db[key] = 1

  if spot.itemKey and not spot.noAutoAward then
    if not AshenRelicsDB.items then AshenRelicsDB.items = {} end
    if (AshenRelicsDB.items[spot.itemKey] or 0) < 1 then
      AshenRelicsDB.items[spot.itemKey] = 1
    end
  end

  local resultTitle = spot.resultTitle
  local resultBody = spot.resultBody
  if spot.searchGroup == "living_measure_salvage" and AR:IsLivingMeasureSalvageComplete() then
    resultTitle = "The salvage is clean."
    resultBody = "Nothing. No lens, no calibration marks, no Emberfall etching.\n\nBut the suspicious goblin nearby keeps pretending not to watch the salvage. He is doing a poor job of it."
    AR:SpeakMutter(
      "q4_salvage_clean_goblin_thought",
      '"Nothing in the piles. But that goblin keeps looking at what is not here."',
      '"Nothing in the piles. But that goblin keeps looking at what is not here."'
    )
  elseif spot.searchGroup == "living_measure_salvage" then
    AR:SpeakMutter(
      "q4_first_salvage_empty_thought",
      '"No lens. Just stripped parts. Someone knew what was worth taking."',
      '"No lens. Just stripped parts. Someone knew what was worth taking."'
    )
  elseif key == "living_measure_skimmer_hold" then
    AR:SpeakMutter(
      "q4_skimmer_lens_found_thought",
      '"Cracked glass, careful marks. Sputtervalve needs to see this before I decide what it means."',
      '"Cracked glass, careful marks. Sputtervalve needs to see this before we decide what it means."'
    )
  end

  AR:ShowHumanQ1SearchResult(resultTitle, resultBody)
  if spot.searchGroup == "living_measure_salvage" and AR:IsLivingMeasureSalvageComplete() then
    AR:ShowEvidenceToast("Someone is watching.", "The salvage is clean of lenses, but a suspicious goblin nearby keeps looking at the piles like he knows what is missing.")
  end
  if spot.toastTitle or spot.toastBody then
    AR:ShowEvidenceToast(spot.toastTitle or "Evidence recovered.", spot.toastBody or "")
  end

  if AR.frames.humanQ1SearchButton then AR.frames.humanQ1SearchButton:Hide() end
  if AR.frames and AR.frames.bag then AR:RefreshBag() end
  AR:RenderQuestDetail()
  AR:UpdateQuestOverlays()
end

function AR:CreateHumanQ1SearchButton()
  if AR.frames.humanQ1SearchButton then return end

  local b = CreateFrame("Button", "AshenRelicsHumanQ1SearchButton", UIParent)
  b:SetWidth(190)
  b:SetHeight(30)
  b:SetPoint("CENTER", UIParent, "CENTER", 0, -205)
  b:SetFrameStrata("FULLSCREEN_DIALOG")
  b:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
  b:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
  b:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
  b:Hide()

  local text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  text:SetPoint("CENTER", b, "CENTER", 0, 1)
  b.text = text

  b:SetScript("OnClick", function()
    if this.searchType == "local" and this.spotKey then
      AR:SearchHumanLocalSpot(this.spotKey)
    elseif this.spotIndex then
      AR:SearchHumanQ1Spot(this.spotIndex)
    end
  end)
  b:SetScript("OnEnter", function()
    if not this.spotName or not GameTooltip then return end
    GameTooltip:SetOwner(this, "ANCHOR_TOP")
    GameTooltip:SetText(this.spotName, 1, 0.82, 0)
    GameTooltip:AddLine(this.tooltipHelp or "Search this old harbor record cache.", 0.9, 0.9, 0.9)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)

  AR.frames.humanQ1SearchButton = b
end

function AR:PositionHumanSearchButtonAtCursor(button)
  if not button then return end
  if not GetCursorPosition or not UIParent then
    button:ClearAllPoints()
    button:SetPoint("CENTER", UIParent, "CENTER", 0, -205)
    return
  end

  local x, y = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale() or 1
  if scale <= 0 then scale = 1 end
  x = x / scale
  y = y / scale

  local parentW = UIParent:GetWidth() or 800
  local parentH = UIParent:GetHeight() or 600
  local w = button:GetWidth() or 190
  local h = button:GetHeight() or 30
  local left = x + 14
  local top = y - 8

  if left + w > parentW then left = x - w - 14 end
  if left < 4 then left = 4 end
  if top > parentH - 4 then top = parentH - 4 end
  if top < h + 4 then top = h + 4 end

  button:ClearAllPoints()
  button:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
end

function AR:PositionHumanSearchButtonDefault(button)
  if not button then return end
  button:ClearAllPoints()
  button:SetPoint("CENTER", UIParent, "CENTER", 0, -205)
end

function AR:UpdateHumanQ1SearchButton()
  AR:CreateHumanQ1SearchButton()
  local b = AR.frames.humanQ1SearchButton
  if not b then return end

  local searchType, index, spot = AR:GetNearbyHumanSearchSpot()
  if not searchType or not index or not spot then
    b.pinnedSearchType = nil
    b.pinnedSearchIndex = nil
    b:Hide()
    return
  end

  b.searchType = searchType
  b.spotIndex = index
  b.spotKey = nil
  b.spotName = spot.name
  if searchType == "local" then
    b.spotKey = index
    b.spotIndex = nil
    b.tooltipHelp = spot.tooltipHelp
    b.text:SetText(spot.buttonText or "Search")
  else
    local nextProgress = AR:GetHumanQ1SpotProgress(index) + 1
    b.tooltipHelp = AR:GetHumanQ1SpotStageText(spot, nextProgress, "tooltipHelps", spot.tooltipHelp)
    b.text:SetText(AR:GetHumanQ1SpotStageText(spot, nextProgress, "buttonTexts", spot.buttonText or "Search"))
    AR:SpeakMutter(
      "story_hover_q2_strongbox",
      '"There. Locked, but not forgotten."',
      '"There. Locked, but not forgotten."'
    )
  end
  local needsPosition = nil
  if not b:IsShown() then needsPosition = 1 end
  if b.pinnedSearchType ~= searchType or b.pinnedSearchIndex ~= index then needsPosition = 1 end
  if needsPosition then
    if searchType == "q1" then
      AR:PositionHumanSearchButtonAtCursor(b)
    else
      AR:PositionHumanSearchButtonDefault(b)
    end
    b.pinnedSearchType = searchType
    b.pinnedSearchIndex = index
  end
  b:Show()
end

function AR:CreateHumanQ1SearchTicker()
  if AR.frames.humanQ1SearchTicker then return end
  local f = CreateFrame("Frame", nil, UIParent)
  f.elapsed = 0
  f:SetScript("OnUpdate", function()
    this.elapsed = (this.elapsed or 0) + (arg1 or 0)
    if this.elapsed >= 0.20 then
      this.elapsed = 0
      AR:UpdateHumanQ1SearchButton()
    end
  end)
  AR.frames.humanQ1SearchTicker = f
end

function AR:FormatObjectiveProgress(label, key, required)
  local current = AR:GetItemCount(key)
  if current > required then current = required end
  return label .. ": " .. current .. "/" .. required
end

function AR:AddQuestOverlayMarker(list, kind, poi, title, questTitle, progress, progress2)
  if not list or not kind or not poi then return end
  table.insert(list, {
    kind=kind,
    poi=poi,
    title=title,
    questTitle=questTitle,
    progress=progress,
    progress2=progress2,
  })
end

function AR:GetMinimapQuestMarkers()
  local markers = {}
  local poi = AR.minimapPOIs or {}

  if AR:IsQuestAccepted("human", 2) and not AR:IsQuestComplete("human", 2) then
    AR:AddQuestOverlayMarker(markers, "turnin", poi.gazlowe, "Turn in: The First Trail", "Human Relics", "Speak with Gazlowe")
  end
  if AR:IsQuestComplete("human", 2) and not AR:IsQuestAccepted("human", 3) then
    AR:AddQuestOverlayMarker(markers, "accept", poi.gazlowe, "Quest available: The Prepared Road", "Human Relics", "Speak with Gazlowe")
  end

  if AR:IsQuestAccepted("human", 3) and not AR:IsQuestComplete("human", 3) then
    if AR:IsHumanQ1ReadyToComplete() then
      AR:AddQuestOverlayMarker(markers, "turnin", poi.gazlowe, "Turn in: The Prepared Road", "Human Relics", AR:GetHumanQ1ProgressText())
    end
  end
  if AR:IsQuestComplete("human", 3) and not AR:IsQuestAccepted("human", 4) then
    AR:AddQuestOverlayMarker(markers, "accept", poi.gazlowe, "Quest available: Cargo Under Seal", "Human Relics", "Speak with Gazlowe")
  end

  if AR:IsQuestAccepted("human", 4) and not AR:IsQuestComplete("human", 4) then
    if AR:GetItemCount("cargo_tag") >= 4 then
      AR:AddQuestOverlayMarker(markers, "turnin", poi.gazlowe, "Turn in: Cargo Under Seal", "Human Relics", AR:FormatObjectiveProgress("Salt-Stained Cargo Tag", "cargo_tag", 4))
    end
  end
  if AR:IsQuestComplete("human", 4) and not AR:IsQuestAccepted("human", 5) then
    AR:AddQuestOverlayMarker(markers, "accept", poi.sputtervalve, "Quest available: The Surveyor's Glass", "Human Relics", "Speak with Sputtervalve")
  end

  if AR:IsQuestAccepted("human", 5) and not AR:IsQuestComplete("human", 5) then
    if AR:GetItemCount("lens") >= 1 then
      AR:AddQuestOverlayMarker(markers, "turnin", poi.sputtervalve, "Turn in: The Surveyor's Glass", "Human Relics", AR:FormatObjectiveProgress("Cracked Survey Lens", "lens", 1))
    end
  end
  if AR:IsQuestComplete("human", 5) and not AR:IsQuestAccepted("human", 6) then
    AR:AddQuestOverlayMarker(markers, "accept", poi.sputtervalve, "Quest available: Where the Paper Sleeps", "Human Relics", "Speak with Sputtervalve")
  end

  if AR:IsQuestAccepted("human", 6) and not AR:IsQuestComplete("human", 6) then
    AR:AddQuestOverlayMarker(markers, "turnin", poi.dizzywig, "Turn in: Where the Paper Sleeps", "Human Relics", "Speak with Dizzywig")
  end
  if AR:IsQuestComplete("human", 6) and not AR:IsQuestAccepted("human", 7) then
    AR:AddQuestOverlayMarker(markers, "accept", poi.dizzywig, "Quest available: Paid Past the Road", "Human Relics", "Speak with Dizzywig")
  end

  if AR:IsQuestAccepted("human", 7) and not AR:IsQuestComplete("human", 7) then
    if AR:GetItemCount("continuation_ledger") >= 1 then
      AR:AddQuestOverlayMarker(markers, "turnin", poi.dizzywig, "Turn in: Paid Past the Road", "Human Relics", AR:FormatObjectiveProgress("Blackwater Payment Ledger", "continuation_ledger", 1))
    end
  end
  if AR:IsQuestComplete("human", 7) and not AR:IsQuestAccepted("human", 8) then
    AR:AddQuestOverlayMarker(markers, "accept", poi.gazlowe, "Quest available: The Broker's Cut", "Human Relics", "Speak with Gazlowe")
  end

  if AR:IsQuestAccepted("human", 8) and not AR:IsQuestComplete("human", 8) then
    if AR:GetItemCount("broker_cut_ledger") >= 1 then
      AR:AddQuestOverlayMarker(markers, "turnin", poi.gazlowe, "Turn in: The Broker's Cut", "Human Relics", AR:FormatObjectiveProgress("Broker's Cut Ledger", "broker_cut_ledger", 1))
    end
  end
  if AR:IsQuestComplete("human", 8) and not AR:IsQuestAccepted("human", 9) then
    AR:AddQuestOverlayMarker(markers, "accept", poi.revilgaz, "Quest available: The Guarantor's Mark", "Human Relics", "Speak with Revilgaz")
  end

  if AR:IsQuestAccepted("human", 9) and not AR:IsQuestComplete("human", 9) then
    if AR:GetItemCount("vale_mark") >= 1 then
      AR:AddQuestOverlayMarker(markers, "turnin", poi.revilgaz, "Turn in: The Guarantor's Mark", "Human Relics", AR:FormatObjectiveProgress("Unmarked Guarantor Seal", "vale_mark", 1))
    end
  end
  if AR:IsQuestComplete("human", 9) and not AR:IsQuestAccepted("human", 10) then
    AR:AddQuestOverlayMarker(markers, "accept", poi.gazlowe, "Quest available: The Contract They Burned", "Human Relics", "Speak with Gazlowe")
  end

  if AR:IsQuestAccepted("human", 10) and not AR:IsQuestComplete("human", 10) then
    if AR:GetItemCount("contract") >= 1 then
      AR:AddQuestOverlayMarker(markers, "turnin", poi.gazlowe, "Turn in: The Contract They Burned", "Human Relics", AR:FormatObjectiveProgress("Burned Contract Scrap", "contract", 1))
    end
  end
  if AR:IsQuestComplete("human", 10) and not AR:IsQuestAccepted("human", 11) then
    AR:AddQuestOverlayMarker(markers, "accept", poi.gazlowe, "Quest available: The Coin Without a King", "Human Relics", "Speak with Gazlowe")
  end

  if AR:IsQuestAccepted("human", 11) and not AR:IsQuestComplete("human", 11) then
    if AR:GetItemCount("coin") >= 1 then
      AR:AddQuestOverlayMarker(markers, "turnin", poi.gazlowe, "Turn in: The Coin Without a King", "Human Relics", AR:FormatObjectiveProgress("The Coin Without a King", "coin", 1))
    end
  end

  return markers
end

function AR:ShowQuestMarkerTooltip(frame)
  if not frame or not frame.marker or not GameTooltip then return end
  local marker = frame.marker
  GameTooltip:SetOwner(frame, frame.tooltipAnchor or "ANCHOR_LEFT")
  GameTooltip:SetText(marker.title or "Ashen Relics objective", 1, 0.08, 0.08)
  if marker.questTitle then GameTooltip:AddLine(marker.questTitle, 1, 0.82, 0.35) end
  if marker.progress then GameTooltip:AddLine(marker.progress, 0.95, 0.95, 0.95) end
  if marker.progress2 then GameTooltip:AddLine(marker.progress2, 0.95, 0.95, 0.95) end
  if marker.poi and marker.poi.label then GameTooltip:AddLine(marker.poi.label, 0.75, 0.75, 0.75) end
  GameTooltip:Show()
end

function AR:AttachQuestMarkerTooltip(frame, anchor)
  if not frame then return end
  frame.tooltipAnchor = anchor or "ANCHOR_LEFT"
  frame:EnableMouse(true)
  frame:SetScript("OnEnter", function() AR:ShowQuestMarkerTooltip(this) end)
  frame:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
end

function AR:CreateQuestIconMarker(parent, size, anchor)
  local b = CreateFrame("Frame", nil, parent)
  b:SetWidth(size)
  b:SetHeight(size)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
  b.text:SetTextColor(1, 0.03, 0.03)
  if b.text.SetFont then b.text:SetFont("Fonts\\MORPHEUS.TTF", size, "OUTLINE") end
  AR:AttachQuestMarkerTooltip(b, anchor)
  b:Hide()
  return b
end

function AR:CreateQuestAreaMarker(parent, size, anchor)
  local b = CreateFrame("Frame", nil, parent)
  b:SetWidth(size)
  b:SetHeight(size)
  b.circle = b:CreateTexture(nil, "ARTWORK")
  b.circle:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
  b.circle:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
  b.circle:SetTexture(AR.questOverlayTextures.areaCircle)
  AR:AttachQuestMarkerTooltip(b, anchor)
  b:Hide()
  return b
end

function AR:CreateMinimapQuestOverlay()
  if AR.frames.minimapQuestOverlay then return end
  if not Minimap then return end

  local f = CreateFrame("Frame", "AshenRelicsMinimapQuestOverlay", Minimap)
  f:SetAllPoints(Minimap)
  f:SetFrameStrata("MEDIUM")
  f.elapsed = 0
  f.icons = {}
  f.areas = {}

  local i
  for i = 1, 6 do
    f.icons[i] = AR:CreateQuestIconMarker(f, 24, "ANCHOR_LEFT")
    if f.icons[i].SetFrameLevel then f.icons[i]:SetFrameLevel(f:GetFrameLevel() + 3) end
  end

  f:SetScript("OnUpdate", function()
    this.elapsed = (this.elapsed or 0) + (arg1 or 0)
    if this.elapsed >= 0.25 then
      this.elapsed = 0
      AR:UpdateMinimapQuestOverlay()
    end
  end)

  AR.frames.minimapQuestOverlay = f
end

function AR:PositionMinimapQuestElement(element, poi, markerIndex, isArea)
  if not element or not poi then return nil end
  local zone = AR:GetCurrentZoneName()
  if zone ~= poi.zone then element:Hide(); return nil end

  local px, py = AR:GetPlayerMapPositionSafe()
  if not px or not py then element:Hide(); return nil end

  local scale = 900
  local dx = (poi.x - px) * scale
  local dy = (poi.y - py) * scale
  local size = element:GetWidth() or 24
  local maxDist = 66 - (size / 2)
  if maxDist < 0 then maxDist = 0 end
  local dist = math.sqrt((dx * dx) + (dy * dy))
  if dist > maxDist then
    element:Hide()
    return nil
  end

  if markerIndex and not isArea then
    dx = dx + ((markerIndex - 1) * 7)
    dy = dy - ((markerIndex - 1) * 5)
  end

  element:ClearAllPoints()
  element:SetPoint("CENTER", Minimap, "CENTER", dx, -dy)
  element:Show()
  return 1
end

function AR:UpdateMinimapQuestOverlay()
  AR:CreateMinimapQuestOverlay()
  local f = AR.frames.minimapQuestOverlay
  if not f then return end

  local i
  for i = 1, table.getn(f.icons) do f.icons[i]:Hide() end
  for i = 1, table.getn(f.areas) do f.areas[i]:Hide() end

  local markers = AR:GetMinimapQuestMarkers()
  local iconIndex = 1
  local areaIndex = 1
  for i = 1, table.getn(markers) do
    local marker = markers[i]
    if marker.kind == "area" then
      local area = f.areas[areaIndex]
      if area then
        local size = 34
        area:SetWidth(size)
        area:SetHeight(size)
        area.marker = marker
        AR:PositionMinimapQuestElement(area, marker.poi, areaIndex, 1)
        areaIndex = areaIndex + 1
      end
    else
      local icon = f.icons[iconIndex]
      if icon then
        if marker.kind == "accept" then icon.text:SetText("!") else icon.text:SetText("?") end
        icon.marker = marker
        AR:PositionMinimapQuestElement(icon, marker.poi, iconIndex, nil)
        iconIndex = iconIndex + 1
      end
    end
  end
end

function AR:UpdateQuestOverlays()
  AR:UpdateMinimapQuestOverlay()
  AR:UpdateWorldMapQuestOverlay()
end

function AR:GetWorldMapMarkerParent()
  if WorldMapButton then return WorldMapButton end
  if WorldMapFrame then return WorldMapFrame end
  return nil
end

function AR:GetWorldMapFileName()
  if not GetMapInfo then return nil end
  local ok, mapName = pcall(function() return GetMapInfo() end)
  if ok then return mapName end
  return nil
end

function AR:IsPOIOnWorldMap(poi)
  if not poi then return nil end
  local mapName = AR:GetWorldMapFileName()
  if mapName and mapName ~= "" then
    return poi.map and mapName == poi.map
  end
  return AR:GetCurrentZoneName() == poi.zone
end

function AR:CreateWorldMapQuestOverlay()
  if AR.frames.worldMapQuestOverlay then return end
  local parent = AR:GetWorldMapMarkerParent()
  if not parent then return end

  local f = CreateFrame("Frame", "AshenRelicsWorldMapQuestOverlay", parent)
  f:SetAllPoints(parent)
  if f.SetFrameLevel and parent.GetFrameLevel then f:SetFrameLevel(parent:GetFrameLevel() + 20) end
  f.icons = {}
  f.areas = {}

  local i
  for i = 1, 8 do
    f.icons[i] = AR:CreateQuestIconMarker(f, 28, "ANCHOR_CURSOR")
    if f.icons[i].SetFrameLevel then f.icons[i]:SetFrameLevel(f:GetFrameLevel() + 3) end
  end
  AR.frames.worldMapQuestOverlay = f
end

function AR:PositionWorldMapQuestElement(element, poi)
  if not element or not poi then return nil end
  local parent = AR:GetWorldMapMarkerParent()
  if not parent then element:Hide(); return nil end
  if not AR:IsPOIOnWorldMap(poi) then element:Hide(); return nil end

  local w = parent:GetWidth() or 1002
  local h = parent:GetHeight() or 668
  if w <= 1 then w = 1002 end
  if h <= 1 then h = 668 end

  element:ClearAllPoints()
  element:SetPoint("CENTER", parent, "TOPLEFT", poi.x * w, -poi.y * h)
  element:Show()
  return 1
end

function AR:UpdateWorldMapQuestOverlay()
  if WorldMapFrame and not WorldMapFrame:IsShown() then
    if AR.frames.worldMapQuestOverlay then AR.frames.worldMapQuestOverlay:Hide() end
    return
  end

  AR:CreateWorldMapQuestOverlay()
  local f = AR.frames.worldMapQuestOverlay
  if not f then return end
  f:Show()

  local i
  for i = 1, table.getn(f.icons) do f.icons[i]:Hide() end
  for i = 1, table.getn(f.areas) do f.areas[i]:Hide() end

  local markers = AR:GetMinimapQuestMarkers()
  local iconIndex = 1
  local areaIndex = 1
  for i = 1, table.getn(markers) do
    local marker = markers[i]
    if marker.kind == "area" then
      local area = f.areas[areaIndex]
      if area then
        local size = 56
        if marker.poi and marker.poi.radius then size = 40 + (marker.poi.radius * 450) end
        area:SetWidth(size)
        area:SetHeight(size)
        area.marker = marker
        AR:PositionWorldMapQuestElement(area, marker.poi)
        areaIndex = areaIndex + 1
      end
    else
      local icon = f.icons[iconIndex]
      if icon then
        if marker.kind == "accept" then icon.text:SetText("!") else icon.text:SetText("?") end
        icon.marker = marker
        AR:PositionWorldMapQuestElement(icon, marker.poi)
        iconIndex = iconIndex + 1
      end
    end
  end
end

function AR:GetHeaderFlameTexture(index)
  index = index or 1
  if index < 1 then index = 1 end
  if index > (AR.headerFlameFrameCount or 24) then index = 1 end
  return AR.flameBase .. "flame_" .. string.format("%02d", index)
end

function AR:GetHeaderFlameNextIndex(index)
  local nextIndex = (index or 1) + 1
  if nextIndex > (AR.headerFlameFrameCount or 24) then nextIndex = 1 end
  return nextIndex
end

function AR:PrimeHeaderFlameTextures(flame)
  if not flame then return end
  local index = flame.frameIndex or 1
  local nextIndex = AR:GetHeaderFlameNextIndex(index)
  local alpha = AR.headerFlameAlpha or 0.64
  if flame.tex then
    flame.tex:SetTexture(AR:GetHeaderFlameTexture(index))
    flame.tex:SetAlpha(alpha)
  end
  if flame.nextTex then
    flame.nextTex:SetTexture(AR:GetHeaderFlameTexture(nextIndex))
    flame.nextTex:SetAlpha(0)
  end
end

function AR:ApplyHeaderFlameLayout()
  local f = AR.frames.main
  if not f or not f.headerFlame then return end
  local d = AR:GetLayout("headerFlame")
  f.headerFlame:ClearAllPoints()
  f.headerFlame:SetPoint("TOPLEFT", f, "TOPLEFT", d.x, d.y)
  f.headerFlame:SetWidth(d.w)
  f.headerFlame:SetHeight(d.h)
end

function AR:CreateHeaderFlameOverlay(parent)
  if not parent or parent.headerFlame then return end

  local flame = CreateFrame("Frame", nil, parent)
  flame:SetWidth(72)
  flame:SetHeight(72)
  flame:SetFrameLevel(parent:GetFrameLevel() + 6)
  flame.frameIndex = 1
  flame.elapsed = 0

  local tex = flame:CreateTexture(nil, "OVERLAY")
  tex:SetAllPoints(flame)
  tex:SetTexture(AR:GetHeaderFlameTexture(1))
  tex:SetBlendMode("ADD")
  tex:SetAlpha(AR.headerFlameAlpha or 0.64)
  flame.tex = tex

  local nextTex = flame:CreateTexture(nil, "OVERLAY")
  nextTex:SetAllPoints(flame)
  nextTex:SetTexture(AR:GetHeaderFlameTexture(2))
  nextTex:SetBlendMode("ADD")
  nextTex:SetAlpha(0)
  flame.nextTex = nextTex

  flame:SetScript("OnUpdate", function()
    this.elapsed = (this.elapsed or 0) + (arg1 or 0)
    local frameDuration = AR.headerFlameFrameDuration or 0.12

    while this.elapsed >= frameDuration do
      this.elapsed = this.elapsed - frameDuration
      this.frameIndex = (this.frameIndex or 1) + 1
      if this.frameIndex > (AR.headerFlameFrameCount or 24) then this.frameIndex = 1 end
      AR:PrimeHeaderFlameTextures(this)
    end

    local blend = this.elapsed / frameDuration
    if blend < 0 then blend = 0 end
    if blend > 1 then blend = 1 end
    local alpha = AR.headerFlameAlpha or 0.64
    if this.tex then this.tex:SetAlpha(alpha * (1 - blend)) end
    if this.nextTex then this.nextTex:SetAlpha(alpha * blend) end
  end)

  parent.headerFlame = flame
  AR:PrimeHeaderFlameTextures(flame)
  AR:ApplyHeaderFlameLayout()
end

function AR:CreateMainFrame()
  if AR.frames.main then return end

  local f = CreateFrame("Frame", "AshenRelicsFrame", UIParent)
  f:SetWidth(760)
  f:SetHeight(666)
  f:SetPoint("CENTER", UIParent, "CENTER", -80, 0)
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:SetScript("OnShow", function()
    if this.headerFlame then
      this.headerFlame.frameIndex = 1
      this.headerFlame.elapsed = 0
      AR:PrimeHeaderFlameTextures(this.headerFlame)
      this.headerFlame:Show()
    end
    AR:PlayQuestLogOpenSound()
    AR:StartFireplaceAmbience()
  end)
  f:SetScript("OnHide", function()
    if this.headerFlame then this.headerFlame:Hide() end
    AR:StopFireplaceAmbience()
    AR:FadeOutIntroNarration()
  end)
  f:SetScript("OnUpdate", function() AR:UpdateFireplaceAmbience(arg1) end)
  f:Hide()
  table.insert(UISpecialFrames, "AshenRelicsFrame")
  AddTileGrid(f, AR.assets.main, 760, 666, "BACKGROUND")
  AR.frames.main = f
  AR:CreateHeaderFlameOverlay(f)

  local close = CreateFrame("Button", nil, f)
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, -18)
  close:SetWidth(28)
  close:SetHeight(28)
  close:SetFrameLevel(f:GetFrameLevel() + 8)
  local ct = close:CreateTexture(nil, "ARTWORK")
  ct:SetAllPoints(close)
  ct:SetTexture(AR.assets.close)
  close:SetScript("OnClick", function() AR:FadeOutIntroNarration(); f:Hide() end)

  local opt = CreateFrame("Button", nil, f)
  opt:SetPoint("TOPRIGHT", f, "TOPRIGHT", -96, -20)
  opt:SetWidth(70)
  opt:SetHeight(22)
  opt:SetFrameLevel(f:GetFrameLevel() + 8)
  opt:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
  opt:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
  opt:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
  local optText = opt:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  optText:SetPoint("CENTER", opt, "CENTER", 0, 0)
  optText:SetText("Options")
  opt:SetScript("OnClick", function() AR:ToggleOptions() end)

  local bag = CreateFrame("Button", nil, f)
  bag:SetPoint("TOPRIGHT", f, "TOPRIGHT", -58, -18)
  bag:SetWidth(28)
  bag:SetHeight(28)
  bag:SetFrameLevel(f:GetFrameLevel() + 8)
  local bt = bag:CreateTexture(nil, "ARTWORK")
  bt:SetAllPoints(bag)
  bt:SetTexture(AR.assets.arrowRight)
  bag:SetScript("OnClick", function() AR:ToggleBag() end)

  f.sidebar = CreateFrame("Frame", nil, f)
  f.sidebar:SetPoint("TOPLEFT", f, "TOPLEFT", 36, -108)
  f.sidebar:SetWidth(285)
  f.sidebar:SetHeight(470)
  f.sidebar:SetFrameLevel(f:GetFrameLevel() + 4)

  AR:BuildQuestPage()
  AR:UpdateCategoryCounts()
  AR:RenderSidebar()
  AR:RenderQuestDetail()
end

function AR:GetReliquaryItems()
  local list = {}
  if not AshenRelicsDB.items then return list end
  local key, count
  for key, count in pairs(AshenRelicsDB.items) do
    local def = AR.itemDefs[key]
    if def and count and count > 0 then
      table.insert(list, { key=key, name=def.name, texture=def.texture, count=count, kind=def.kind })
    end
  end
  return list
end

function AR:RefreshBag()
  local f = AR.frames.bag
  if not f or not f.slots then return end
  local items = AR:GetReliquaryItems()
  if f.searchText and f.searchText ~= "" then
    local filtered = {}
    local si
    for si = 1, table.getn(items) do
      if string.find(string.lower(items[si].name), string.lower(f.searchText), 1, true) then
        table.insert(filtered, items[si])
      end
    end
    items = filtered
  end
  local i
  for i = 1, table.getn(f.slots) do
    local s = f.slots[i]
    if s.icon then s.icon:SetTexture("") end
    if s.countText then s.countText:SetText("") end
    s.item = nil

    local item = items[i]
    if item then
      if s.icon then s.icon:SetTexture(item.texture) end
      if s.countText and item.count and item.count > 1 then s.countText:SetText(item.count) end
      s.item = item
    end
  end

  if f.countText then f.countText:SetText(table.getn(items) .. "/12") end
end

function AR:CreateBagFrame()
  if AR.frames.bag then return end

  local f = CreateFrame("Frame", "BannerReliquaryFrame", UIParent)
  f:SetWidth(342)
  f:SetHeight(480)
  if AR.frames.main then
    f:SetPoint("LEFT", AR.frames.main, "RIGHT", -8, 0)
  else
    f:SetPoint("CENTER", UIParent, "CENTER", 330, 35)
  end
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:Hide()
  AddTileGrid(f, AR.assets.bag, 342, 480, "BACKGROUND")
  AR.frames.bag = f

  local close = CreateFrame("Button", nil, f)
  close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -13, -10)
  close:SetWidth(24)
  close:SetHeight(24)
  close:SetFrameLevel(f:GetFrameLevel() + 8)
  local ct = close:CreateTexture(nil, "ARTWORK")
  ct:SetAllPoints(close)
  ct:SetTexture(AR.assets.close)
  close:SetScript("OnClick", function() f:Hide() end)

  local search = CreateFrame("EditBox", nil, f)
  search:SetPoint("TOPLEFT", f, "TOPLEFT", 88, -54)
  search:SetWidth(190)
  search:SetHeight(20)
  search:SetAutoFocus(false)
  search:SetFontObject(ChatFontNormal)
  search:SetTextColor(1, 0.82, 0.35)
  search:SetTextInsets(4, 4, 0, 0)
  search:SetScript("OnTextChanged", function()
    f.searchText = this:GetText()
    AR:RefreshBag()
  end)
  search:SetScript("OnEscapePressed", function()
    this:ClearFocus()
  end)
  f.searchBox = search
  f.searchText = ""

  local slotSize, gap, startX, startY = 55, 8, 40, -120
  local i
  f.slots = {}
  for i = 1, 16 do
    local col = math.mod(i - 1, 4)
    local row = math.floor((i - 1) / 4)
    local s = CreateFrame("Button", nil, f)
    s:SetPoint("TOPLEFT", f, "TOPLEFT", startX + col * (slotSize + gap), startY - row * (slotSize + gap))
    s:SetWidth(slotSize)
    s:SetHeight(slotSize)
    s:SetFrameLevel(f:GetFrameLevel() + 5)

    local bg = s:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(s)
    bg:SetTexture(0.01, 0.01, 0.01, 0.45)

    local icon = s:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", s, "TOPLEFT", 5, -5)
    icon:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -5, 5)
    s.icon = icon

    local countText = s:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    countText:SetPoint("BOTTOMRIGHT", s, "BOTTOMRIGHT", -6, 4)
    s.countText = countText

    s:SetScript("OnEnter", function()
      if this.item then
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
        GameTooltip:SetText(this.item.name, 1, 0.82, 0)
        GameTooltip:AddLine(this.item.kind or "Ashen Relics item", 0.7, 0.7, 0.7)
        GameTooltip:Show()
      end
    end)
    s:SetScript("OnLeave", function() GameTooltip:Hide() end)

    table.insert(f.slots, s)
  end

  local count = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  count:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 34, 30)
  count:SetText("0/12")
  f.countText = count

  AR:RefreshBag()
end

function AR:ToggleMain()
  AR:CreateMainFrame()
  if AR.frames.main:IsShown() then
    AR.frames.main:Hide()
  else
    AR.frames.main:Show()
  end
end


AR.npcDialogs = {
  ["Gazlowe"] = {
    title = "Gazlowe",
    subtitle = "Ratchet",
    questIndex = 2,
  },
  ["Sputtervalve"] = {
    title = "Sputtervalve",
    subtitle = "Ratchet",
    questIndex = 5,
  },
  ["Suspicious Goblin"] = {
    title = "Suspicious Goblin",
    subtitle = "Ratchet",
    questIndex = 5,
  },
  ["Wharfmaster Dizzywig"] = {
    title = "Wharfmaster Dizzywig",
    subtitle = "Ratchet",
    questIndex = 6,
  },
  ["Dizzywig"] = {
    title = "Wharfmaster Dizzywig",
    subtitle = "Ratchet",
    questIndex = 6,
  },
  ["Baron Revilgaz"] = {
    title = "Baron Revilgaz",
    subtitle = "Booty Bay",
    questIndex = 9,
  },
  ["Revilgaz"] = {
    title = "Baron Revilgaz",
    subtitle = "Booty Bay",
    questIndex = 9,
  },
}

function AR:GetGazloweState()
  if not AR:IsQuestUnlocked("human", 2) then return nil end

  if AR:IsQuestAccepted("human", 2) and not AR:IsQuestComplete("human", 2) then
    return "intro_handoff_done"
  end
  if AR:IsQuestComplete("human", 2) and not AR:IsQuestAccepted("human", 3) then
    return "q1_available"
  end

  if AR:IsQuestAccepted("human", 3) and not AR:IsQuestComplete("human", 3) then
    if AR:IsHumanQ1ReadyToComplete() then return "q1_done" end
    return "q1_search"
  end
  if AR:IsQuestComplete("human", 3) and not AR:IsQuestAccepted("human", 4) then return "cargo_available" end

  if AR:IsQuestAccepted("human", 4) and not AR:IsQuestComplete("human", 4) then
    if AR:GetItemCount("cargo_tag") >= 4 then return "cargo_done" end
    return "cargo_hunting"
  end

  if AR:IsQuestComplete("human", 7) and not AR:IsQuestAccepted("human", 8) then return "broker_available" end
  if AR:IsQuestAccepted("human", 8) and not AR:IsQuestComplete("human", 8) then
    if AR:GetItemCount("broker_cut_ledger") >= 1 then return "broker_done" end
    return "broker_hunting"
  end

  if AR:IsQuestComplete("human", 9) and not AR:IsQuestAccepted("human", 10) then return "contract_available" end
  if AR:IsQuestAccepted("human", 10) and not AR:IsQuestComplete("human", 10) then
    if AR:GetItemCount("contract") >= 1 then return "contract_done" end
    return "contract_hunting"
  end

  if AR:IsQuestComplete("human", 10) and not AR:IsQuestAccepted("human", 11) then return "coin_available" end
  if AR:IsQuestAccepted("human", 11) and not AR:IsQuestComplete("human", 11) then
    if AR:GetItemCount("coin") >= 1 then return "coin_done" end
    return "coin_search"
  end
  return nil
end

function AR:GetNPCDialogueState(name)
  if name == "Gazlowe" then
    local state = AR:GetGazloweState()
    if state == "intro_handoff_done" then
      return {
        title="Gazlowe",
        subtitle="Ratchet",
        body=[[The ledger points to Ratchet? Hah. Makes sense.

A lot of shady business gets done here, but good coin moves just as fast if you know how to move it.

Emberfall's an interesting stamp. I haven't heard of it before, but I know one thing: if Emberfall passed through here at any point, somebody knows something about it.

Ratchet is a city of history. Old papers turn into coin quicker than rum and ale.]],
        button="Complete: The First Trail",
        questIndex=2,
        complete=1,
        reopenAfterComplete=1,
      }
    elseif state == "q1_available" then
      return {
        title="Gazlowe",
        subtitle="Ratchet",
        body=[[I'd say your best bet is old shipping records. Generally, they're a mess: half-truths, fake weights, missing crates, anything to increase profit and decrease cost.

But if Emberfall passed through here, those Southsea sailors likely had something to do with it. They've got an old trade vessel south of here. I've been on it a time or two. Plenty of old-looking records. I even saw lockboxes down in the bowels of the ship, toward the back.

They guard that area with their lives, which tells me there's probably something worth finding there. You'll need a key, though. One of them is bound to have one.]],
        button="Accept: The Prepared Road",
        questIndex=3,
        acceptQuest=3,
      }
    elseif state == "q1_search" then
      return {
        title="Gazlowe",
        subtitle="Ratchet",
        body=[[Those Southsea sailors have been stripping old cargo for years. If Emberfall passed through Ratchet, something from it likely ended up in their hands.

Start with the old trade vessel south of here. The good records will not be sitting on deck in the sun. Check the lower hold, toward the back, where they keep the lockboxes and the things worth guarding.

Find a Buccaneer's Cargo Key from one of the sailors, then use it on the strongboxes aboard that vessel.]],
        button="Find the Key",
        questIndex=3,
        complete=nil,
      }
    elseif state == "q1_done" then
      return {
        title="Gazlowe",
        subtitle="Ratchet",
        body="So the ledger was right.\n\nThe Emberfall Expedition passed through Ratchet. Not as legend, not as song, not as some half-remembered Banner tale. As cargo, passage, and paperwork.\n\nBut this was not random packing. Whoever packed this knew the road better than the people walking it.\n\nWe know Emberfall left through Ratchet. Now we find out what followed them onto that road.",
        button="Complete: The Prepared Road",
        questIndex=3,
        complete=1,
      }
    elseif state == "cargo_available" then
      return {
        title="Gazlowe",
        subtitle="Ratchet",
        body="Those manifests prove Emberfall moved through Ratchet, but they do not tell us what rode with it.\n\nSee these crate numbers? Seal marks, handling codes, copied descriptions. The real cargo detail was probably on tags, stamped slats, and whatever pirates tore loose when the crates broke open.\n\nSouthsea has been picking at this coast for years. Most of them cannot read half of what they steal, but they keep marked cargo if they think it proves ownership.\n\nBring me anything stamped with Emberfall's mark.",
        button="Accept: Cargo Under Seal",
        questIndex=4,
        acceptQuest=4,
      }
    elseif state == "cargo_hunting" then
      local c = AR:GetItemCount("cargo_tag")
      return {
        title="Gazlowe",
        subtitle="Ratchet",
        body="Still short.\n\nSearch the Southsea Brigands and Southsea Cannoneers along the Merchant Coast. Look for stamped crate tags, slats, anything carrying Emberfall's mark.\n\nRecovered cargo tags: " .. c .. "/4",
        button="I'll keep searching",
        questIndex=4,
        complete=nil,
      }
    elseif state == "cargo_done" then
      return {
        title="Gazlowe",
        subtitle="Ratchet",
        body="Ah. Cargo tags. Good.\n\nThe manifest told us Emberfall moved. These tell us what followed them onto the road.\n\nRope. Lantern oil. Survey stakes. Preserved food. Crate braces. Spare tools. Most of this belongs on a rough expedition.\n\nBut this line here...\n\nGazlowe taps one stained entry with a fingernail.\n\nCalibrated lens housing. Damaged brass meter. Reaction marks in the margin.\n\nThat does not belong with trail gear. Not unless someone expected to recognize something ordinary maps would miss.\n\nMaybe it is a bad copy. Maybe it is nothing.\n\nOr maybe Emberfall carried instruments that do not belong on a normal expedition. Sputtervalve knows machines well enough to tell us what kind.",
        button="Complete: Cargo Under Seal",
        questIndex=4,
        complete=1,
      }
    elseif state == "broker_available" then
      return {
        title="Gazlowe",
        subtitle="Ratchet",
        body="Now we are looking at money that wanted to hide.\n\nThat means brokers, pirates, false cargo claims, and captains who skimmed enough to remember the job.\n\nBaron Longshore has been a thorn in Ratchet's side for years. If one of those old Emberfall payments passed through Southsea hands, he is the sort who would keep proof. Not because he cared. Because proof can become blackmail.\n\nBring me his ledger scrap.",
        button="Accept: The Broker's Cut",
        questIndex=8,
        acceptQuest=8,
      }
    elseif state == "broker_hunting" then
      return {
        title="Gazlowe",
        subtitle="Ratchet",
        body="Baron Longshore is still breathing, or his proof is still in his pocket.\n\nFind him along the Merchant Coast. If Emberfall coin passed through Southsea hands, he kept a cut and a record.",
        button="Find Longshore",
        questIndex=8,
        complete=nil,
      }
    elseif state == "broker_done" then
      return {
        title="Gazlowe",
        subtitle="Ratchet",
        body="Hah. There it is.\n\nSouthsea took a cut. Goblins moved the coin. But the source is hidden behind marks, proxies, and sealed instructions.\n\nThat means whoever paid for Emberfall did not want their name remembered.\n\nAnd here... this symbol again. Same family of marks as the Blackwater ledger.\n\nNot a merchant seal. Not a pirate sign.\n\nA covered hand.",
        button="Complete: The Broker's Cut",
        questIndex=8,
        complete=1,
      }
    elseif state == "contract_available" then
      return {
        title="Gazlowe",
        subtitle="Ratchet",
        body="Cozzle.\n\nIf there's a goblin alive who would keep a burned contract because he thought it might be worth something later, it's that miserable little foreman.\n\nDon't expect him to know what he has. That's not the point. The point is he kept it.\n\nGo to Stranglethorn. Find Cozzle. Take whatever Emberfall paper he's been sitting on.",
        button="Accept: The Contract They Burned",
        questIndex=10,
        acceptQuest=10,
      }
    elseif state == "contract_hunting" then
      return {
        title="Gazlowe",
        subtitle="Ratchet",
        body="Cozzle still has the paper, or somebody else is already selling it.\n\nFind him in Stranglethorn and take the burned Emberfall contract scrap.",
        button="Find Cozzle",
        questIndex=10,
        complete=nil,
      }
    elseif state == "contract_done" then
      return {
        title="Gazlowe",
        subtitle="Ratchet",
        body="This is the part where old paper stops being boring.\n\nThe first half is contract language. Payment schedules. Risk assumption. Material support. Very dull. Very goblin.\n\nAnd the burned half?\n\nNot so dull. Obligation. Witness. Continuance. Words that reach farther than wages should reach.\n\nThis was not just hiring language. Someone wanted the promise itself recorded.",
        button="Complete: The Contract They Burned",
        questIndex=10,
        complete=1,
      }
    elseif state == "coin_available" then
      return {
        title="Gazlowe",
        subtitle="Ratchet",
        body="Funny thing about coin.\n\nSpend it, and it disappears. Save it, and it remembers who touched it.\n\nThis piece passed through pirate hands, broker hands, and goblin hands, always near Emberfall records that should have had nothing to do with one another.\n\nNo crown mark. No house seal. No trade stamp. Nothing that points home.\n\nThe first trail began in Ratchet. It should end there too.",
        button="Accept: The Coin Without a King",
        questIndex=11,
        acceptQuest=11,
      }
    elseif state == "coin_search" then
      return {
        title="Gazlowe",
        subtitle="Ratchet",
        body="The coin will not be in a vault. Whoever hid it was not hiding treasure.\n\nLook near the first Ratchet records. Look where someone would leave proof for whoever was patient enough to follow the paper trail.",
        button="Search the final cache",
        questIndex=11,
        complete=nil,
      }
    elseif state == "coin_done" then
      return {
        title="Gazlowe",
        subtitle="Ratchet",
        body="There it is.\n\nNo crown. No house. No trade mark.\n\nWhoever paid for Emberfall wanted the road walked, the records buried, and the hand behind it hidden.\n\nYou have a prepared road, hidden tools, buried payments, and a coin that points nowhere.\n\nThat is not an expedition.\n\nThat is a trap with paperwork.",
        button="Complete: The Coin Without a King",
        questIndex=11,
        complete=1,
      }
    end
  end

  if name == "Suspicious Goblin" then
    if not AR:IsQuestAccepted("human", 5) or AR:IsQuestComplete("human", 5) then return nil end
    if AR:GetItemCount("lens") >= 1 then return nil end
    if AR:GetFlag("livingMeasureGoblinRevealed") then
      return {
        title="Suspicious Goblin",
        subtitle="Ratchet",
        body="I told you what I know.\n\nSmall skimmer behind me. Forward hold. Under the rope coil. If the glass is still there, it is only because nobody has offered enough for it yet.\n\nAnd if anyone asks, you did not hear that from me.",
        button="Search the skimmer hold",
        questIndex=5,
        complete=nil,
      }
    end
    if not AR:IsLivingMeasureSalvageComplete() then return nil end

    local stage = AR:GetLivingMeasureGoblinStage()
    if stage == 1 then
      return {
        title="Suspicious Goblin",
        subtitle="Ratchet",
        body="Watching? Me?\n\nNo, no. I am standing here professionally near unrelated salvage. Very common Ratchet behavior. People stand near salvage all the time. Sometimes the salvage appreciates the company.\n\nYou look like someone who has been digging through junk and finding disappointment. Very sad. Very normal. Nothing to do with me.",
        button="Ask about the lens",
        questIndex=5,
        advanceFlag="livingMeasureGoblinStage",
        advanceValue=2,
      }
    elseif stage == 2 then
      return {
        title="Suspicious Goblin",
        subtitle="Ratchet",
        body="Lens is a very specific word.\n\nLots of things are shiny. Bottle bottoms. Spyglass scraps. Pretty rocks with no resale value. Pirates bring scrap, dock hands sell scrap, I buy scrap, everybody goes home poorer but busier.\n\nDid a cracked piece with little marks come through here? Maybe. Did I know it was important? Absolutely not. Importance costs extra.",
        button="Press him",
        questIndex=5,
        advanceFlag="livingMeasureGoblinStage",
        advanceValue=3,
      }
    else
      return {
        title="Suspicious Goblin",
        subtitle="Ratchet",
        body="Fine. Fine.\n\nA Southsea hand brought in a cracked lens with marks around the rim. Too clean for bottle glass, too strange for a spyglass, and too annoying to price honestly.\n\nI kept it off the table because another buyer had already asked about calibrated scrap. Quiet buyer. Clean coin. Bad sign.\n\nIt is in the small skimmer behind me, forward hold, wrapped under the rope coil. Search there, take it, and let us both forget how helpful I was.",
        button="Search the skimmer hold",
        questIndex=5,
        setFlag="livingMeasureGoblinRevealed",
        flagValue=1,
      }
    end
  end

  if name == "Sputtervalve" then
    if AR:IsQuestComplete("human", 4) and not AR:IsQuestAccepted("human", 5) then
      return {
        title="Sputtervalve",
        subtitle="Ratchet",
        body="Interesting. Cargo tags.\n\nCalibrated lens housing... reaction marks in the handling notes.\n\nThat is not typical expedition packing. Not for mapping ruins. Not for hauling camp gear. Not for any normal survey job I have ever seen.\n\nIf that cargo broke open, most pirates would throw away the housing and keep the shiny bits. A lens, though? That might survive. Someone might think it is spyglass glass. Someone else might sell it as engineering scrap. A dock scavenger might not know what it is at all.\n\nStart with salvage around Ratchet. Check the piles near the docks, then any other salvage the scavengers have been picking through. Strange machine parts move fast when goblins think they can sell them twice.\n\nBring me the lens, or anything still carrying those calibration marks. Then I can tell you what that instrument was meant to recognize.",
        button="Accept: The Surveyor's Glass",
        questIndex=5,
        acceptQuest=5,
      }
    end

    if AR:IsQuestComplete("human", 5) and not AR:IsQuestAccepted("human", 6) then
      return {
        title="Sputtervalve",
        subtitle="Ratchet",
        body="This does not end with the lens.\n\nAn instrument like this needs records. Calibration notes. Repairs. Handling fees. Someone had to keep paying for the work after Emberfall left Ratchet.\n\nWharfmaster Dizzywig knows where old dock paper goes when everyone else pretends it is gone.\n\nTake this lead to him. Ask for continuation records, and watch his face when you say Sputtervalve sent you.",
        button="Accept: Where the Paper Sleeps",
        questIndex=6,
        acceptQuest=6,
      }
    end

    if AR:IsQuestAccepted("human", 6) and not AR:IsQuestComplete("human", 6) then
      return {
        title="Sputtervalve",
        subtitle="Ratchet",
        body="Dizzywig first.\n\nTell him the lens was not a survey part, and tell him I said to look for continuation records. He will complain. That means he knows where they are.",
        button="Speak with Dizzywig",
        questIndex=6,
        complete=nil,
      }
    end

    if not AR:IsQuestAccepted("human", 5) then
      return nil
    end
    if AR:IsQuestComplete("human", 5) then return nil end

    if AR:GetItemCount("lens") < 1 then
      local stage = AR:GetLivingMeasureStage()
      if stage == "question_goblin" then
        return {
          title="Sputtervalve",
          subtitle="Ratchet",
          body="Both salvage spots came up empty? Then the useful piece already walked away.\n\nRatchet salvage does not move itself. If someone nearby is watching you search, start there. Bad liars point at the truth by standing too close to it.",
          button="Question the goblin",
          questIndex=5,
          complete=nil,
        }
      elseif stage == "skimmer_hold" then
        return {
          title="Sputtervalve",
          subtitle="Ratchet",
          body="A skimmer hold behind the goblin?\n\nThat sounds exactly like where a nervous buyer would hide a thing he has not priced yet. Search it before he remembers another place to stash the lens.",
          button="Search the skimmer hold",
          questIndex=5,
          complete=nil,
        }
      end
      return {
        title="Sputtervalve",
        subtitle="Ratchet",
        body="Find me the lens, or anything still carrying those calibration marks.\n\nStart with salvage around Ratchet. Check the dock piles and any other salvage the scavengers have been picking through. Strange machine parts move fast when goblins think they can sell them twice.",
        button="Find the Lens",
        questIndex=5,
        complete=nil,
      }
    else
      return {
        title="Sputtervalve",
        subtitle="Ratchet",
        body="Well, that's ugly.\n\nThis lens was not made to measure land. It was made to recognize marks too fine for ordinary eyes. Survey scratches. Alignment cuts. Tiny signs a traveler would walk past without knowing they were being guided.\n\nWhoever packed this did not only want Emberfall moved.\n\nThey wanted Emberfall to follow something already prepared.\n\nAnd instruments like this are not packed once and forgotten. They need calibration notes. Replacement parts. Reports. Renewals. Somebody had to keep this work recorded after the road began.\n\nIf there were continuation payments, Dizzywig would know where that paper sleeps. Wharfmasters remember money longer than people remember names.",
        button="Complete: The Surveyor's Glass",
        questIndex=5,
        complete=1,
        reopenAfterComplete=1,
      }
    end
  end

  if name == "Wharfmaster Dizzywig" or name == "Dizzywig" then
    if AR:IsQuestAccepted("human", 6) and not AR:IsQuestComplete("human", 6) then
      return {
        title="Wharfmaster Dizzywig",
        subtitle="Ratchet",
        body="Sputtervalve sent you?\n\nOf course he did. That goblin only remembers paperwork when it makes my day worse.\n\nContinuation records, sealed renewals, quiet handling fees... yes, I know the kind of paper you mean. I did not say I had it. I said I know the kind.\n\nIf Emberfall kept getting paid after departure, then somebody was still watching the road from behind the records.",
        button="Complete: Where the Paper Sleeps",
        questIndex=6,
        complete=1,
        reopenAfterComplete=1,
      }
    end

    if AR:IsQuestComplete("human", 6) and not AR:IsQuestAccepted("human", 7) then
      return {
        title="Wharfmaster Dizzywig",
        subtitle="Ratchet",
        body="Sputtervalve sent you about continuation records? Then the machine bothered him more than he wanted to admit.\n\nOld payments, sealed renewals, quiet handling fees... you ask dangerous questions with a very calm face.\n\nA single payment buys passage. Continued payments mean someone still cared where the road was going.\n\nThere is an old Blackwater ledger in the harbor records. I never said you could look at it. I also never said where I keep it.",
        button="Accept: Paid Past the Road",
        questIndex=7,
        acceptQuest=7,
      }
    end

    if not AR:IsQuestAccepted("human", 7) then
      return nil
    end
    if AR:IsQuestComplete("human", 7) then return nil end

    if AR:GetItemCount("continuation_ledger") < 1 then
      return {
        title="Wharfmaster Dizzywig",
        subtitle="Ratchet",
        body="You did not hear this from me, because I did not say it.\n\nOld renewal records sit near the docks. If Emberfall kept getting paid after departure, that paper will show it.",
        button="Search the records",
        questIndex=7,
        complete=nil,
      }
    else
      return {
        title="Wharfmaster Dizzywig",
        subtitle="Ratchet",
        body="There it is.\n\nPayment after departure. Payment after cargo release. Payment after the first reports should have come back.\n\nThat was no ordinary expedition account. Someone kept the coin moving because Emberfall still needed to continue.\n\nAnd look at how carefully the entries avoid a name. Every hand is listed except the one that mattered.\n\nThe gold is not the strange part. The strange part is how much they knew before they spent it.",
        button="Complete: Paid Past the Road",
        questIndex=7,
        complete=1,
      }
    end
  end

  if name == "Baron Revilgaz" or name == "Revilgaz" then
    if AR:IsQuestComplete("human", 8) and not AR:IsQuestAccepted("human", 9) then
      return {
        title="Baron Revilgaz",
        subtitle="Booty Bay",
        body="Ratchet sent you here? Then Ratchet is either brave, stupid, or trying to make this my problem.\n\nOld money leaves cleaner tracks than pirate money. Better ink, better seals, better lies.\n\nDo not mistake legal cover for innocence. People sign things every day without reading the teeth inside them.\n\nSearch the old Blackwater exchange records. If someone gave Emberfall a clean face, the paper will still smell expensive.",
        button="Accept: The Guarantor's Mark",
        questIndex=9,
        acceptQuest=9,
      }
    end

    if not AR:IsQuestAccepted("human", 9) then
      return nil
    end
    if AR:IsQuestComplete("human", 9) then return nil end

    if AR:GetItemCount("vale_mark") < 1 then
      return {
        title="Baron Revilgaz",
        subtitle="Booty Bay",
        body="Some ships carry cargo. Some carry consequences. The smart captain knows which one is heavier.\n\nSearch the exchange records. If someone important covered Emberfall, you will find the mark.",
        button="Search the records",
        questIndex=9,
        complete=nil,
      }
    else
      return {
        title="Baron Revilgaz",
        subtitle="Booty Bay",
        body="There. A guarantor seal, scraped nearly clean. No name left for the record, but enough authority to open doors.\n\nThat is how these arrangements survive. One hand holds the coin. Another signs the paper. A third tells the poor fools walking the road that everything is proper.\n\nThis does not name the hand behind Emberfall. It proves that hand had help making the expedition look honest.",
        button="Complete: The Guarantor's Mark",
        questIndex=9,
        complete=1,
      }
    end
  end

  return nil
end

function AR:IsNPCDialogueEligible(name)
  if not name then return nil end
  if AR:GetNPCDialogueState(name) then return 1 end
  return nil
end

function AR:OpenNPCDialogue(name, force)
  if not name or not AR.npcDialogs[name] then return nil end
  local state = AR:GetNPCDialogueState(name)
  if not state and not force then return nil end
  if not state then state = { title=name, subtitle="", body="There is no active Ashen Relics business with this NPC.", button="Close", questIndex=1 } end
  local dialogueEditKey = AR:GetDialogueEditKey(name, state)
  state = AR:ApplyDialogueCopyEdit(dialogueEditKey, state)

  AR:CreateDialogueFrame()

  if GossipFrame and GossipFrame:IsShown() then GossipFrame:Hide() end
  if QuestFrame and QuestFrame:IsShown() then QuestFrame:Hide() end

  local f = AR.frames.dialogue
  f.title:SetText(state.title or name)
  f.subtitle:SetText(state.subtitle or "")
  f.body:SetText(state.body or "")
  if f.acceptText then f.acceptText:SetText(state.button or "Continue") end

  f.accept:SetScript("OnClick", function()
    if state.advanceFlag then
      AR:SetFlag(state.advanceFlag, state.advanceValue or 1)
      AR:OpenNPCDialogue(name, 1)
      return
    end

    if state.setFlag then
      AR:SetFlag(state.setFlag, state.flagValue or 1)
      if AR.frames.main then AR.frames.main:Show() end
      AR:RenderSidebar()
      AR:RenderQuestDetail()
      AR:UpdateQuestOverlays()
      f:Hide()
      return
    end

    if state.acceptQuest then
      local wasAcceptedBeforeClick = AR:IsQuestAccepted("human", state.acceptQuest)
      AR:AcceptQuest("human", state.acceptQuest, 1)
      if not wasAcceptedBeforeClick then AR:PlayQuestAcceptedSound() end
      if AR.frames.main then AR.frames.main:Show() end
    end

    if state.complete then
      AR.activeCategory = 1
      AR.activeQuest = state.questIndex or 2
      AR.activeEvidenceQuest = nil
      AR:SaveEvidenceLog("human", AR.activeQuest, state)
      if state.acceptNext then
        AR:CompleteQuest("human", AR.activeQuest, 1)
        local wasNextAcceptedBeforeClick = AR:IsQuestAccepted("human", state.acceptNext)
        AR:AcceptQuest("human", state.acceptNext, 1)
        if not wasNextAcceptedBeforeClick then AR:PlayQuestAcceptedSound() end
      else
        AR:CompleteQuest("human", AR.activeQuest)
      end
      AR:RenderSidebar()
      AR:RenderQuestDetail()
      if AR.frames.main then AR.frames.main:Show() end
      if state.reopenAfterComplete then
        AR:OpenNPCDialogue(name, 1)
        return
      end
    end
    f:Hide()
  end)

  f:Show()
  return 1
end

function AR:TryOpenTargetDialogue()
  local name = nil
  if UnitName then name = UnitName("target") end
  if name and AR:OpenNPCDialogue(name, 1) then return 1 end
  DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics:|r target an Ashen Relics NPC and use /ar talk.")
  return nil
end

function AR:TryGossipDialogue()
  local name = nil
  if UnitName then
    name = UnitName("target")
    if (not name or name == "") then name = UnitName("npc") end
  end
  if name and AR:OpenNPCDialogue(name, nil) then return 1 end
  return nil
end

function AR:InstallNPCDialogueHooks()
  if AR.gossipHooksInstalled then return end
  AR.gossipHooksInstalled = 1

  if GossipFrame then
    local oldGossipShow = GossipFrame:GetScript("OnShow")
    GossipFrame:SetScript("OnShow", function()
      if oldGossipShow then oldGossipShow() end
      AR:TryGossipDialogue()
    end)
  end

  if QuestFrame then
    local oldQuestShow = QuestFrame:GetScript("OnShow")
    QuestFrame:SetScript("OnShow", function()
      if oldQuestShow then oldQuestShow() end
      AR:TryGossipDialogue()
    end)
  end
end

function AR:InstallWorldMapOverlayHooks()
  if AR.worldMapHooksInstalled then return end
  AR.worldMapHooksInstalled = 1
end

function AR:CreateDialogueFrame()
  if AR.frames.dialogue then return end

  local f = CreateFrame("Frame", "AshenRelicsDialogueFrame", UIParent)
  f:SetWidth(560)
  f:SetHeight(403)
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:Hide()
  table.insert(UISpecialFrames, "AshenRelicsDialogueFrame")

  f.art = CreateFrame("Frame", nil, f)
  f.art:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  f.art:SetWidth(560)
  f.art:SetHeight(403)
  f.art:SetFrameLevel(f:GetFrameLevel() + 1)
  AddTileGrid(f.art, AR.assets.dialogue, 560, 403, "ARTWORK")

  f.content = CreateFrame("Frame", nil, f)
  f.content:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
  f.content:SetWidth(560)
  f.content:SetHeight(403)
  f.content:SetFrameLevel(f:GetFrameLevel() + 6)

  f.title = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  f.title:SetPoint("TOP", f.content, "TOP", 0, -30)
  f.title:SetTextColor(0.86, 0.23, 0.16)

  f.subtitle = f.content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.subtitle:SetPoint("TOP", f.title, "BOTTOM", 0, -4)
  f.subtitle:SetTextColor(0.48, 0.24, 0.12)

  f.body = f.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.body:SetPoint("TOPLEFT", f.content, "TOPLEFT", 66, -96)
  f.body:SetWidth(428)
  f.body:SetHeight(205)
  f.body:SetJustifyH("LEFT")
  f.body:SetJustifyV("TOP")
  f.body:SetTextColor(0.17, 0.10, 0.055)

  f.accept = CreateFrame("Button", nil, f.content)
  f.accept:SetPoint("BOTTOMLEFT", f.content, "BOTTOMLEFT", 88, 34)
  f.accept:SetWidth(154)
  f.accept:SetHeight(26)
  f.accept:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
  f.accept:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
  f.accept:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
  local acceptText = f.accept:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  acceptText:SetPoint("CENTER", f.accept, "CENTER", 0, 2)
  acceptText:SetText("Accept Lead")
  f.acceptText = acceptText

  f.close = CreateFrame("Button", nil, f.content)
  f.close:SetPoint("BOTTOMRIGHT", f.content, "BOTTOMRIGHT", -88, 34)
  f.close:SetWidth(154)
  f.close:SetHeight(26)
  f.close:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
  f.close:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
  f.close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
  local closeText = f.close:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  closeText:SetPoint("CENTER", f.close, "CENTER", 0, 2)
  closeText:SetText("Close")
  f.close:SetScript("OnClick", function() AR.frames.dialogue:Hide() end)

  AR.frames.dialogue = f
end

function AR:CheckLocationFlavor()
  AR:CheckStoryAreaBeats()
  AR:CheckStoryReturnBeats()
end





function AR:HasCoinTrailLead()
  return nil
end

function AR:SetCoinTrailLead()
  return nil
end

function AR:GetCoinTrailStage()
  return nil
end

function AR:IsOnCoinTrailQuest()
  return nil
end

function AR:IsRevilgazReturnReady()
  return nil
end



function AR:HasNameValeAsked()
  return nil
end

function AR:SetNameValeAsked()
  return nil
end

function AR:HasNameValePressed()
  return nil
end

function AR:SetNameValePressed()
  return nil
end

function AR:GetNameValeStage()
  return nil
end

function AR:IsOnNameValeQuest()
  return nil
end


function AR:HasBrokerLensReviewed()
  return nil
end

function AR:SetBrokerLensReviewed()
  return nil
end

function AR:GetBrokerMemoryStage()
  if not AR:IsQuestAccepted("human", 5) then return nil end
  if AR:IsQuestComplete("human", 5) then return nil end
  local stage = AR:GetLivingMeasureStage()
  if stage == "question_goblin" then return "question_goblin" end
  if stage == "skimmer_hold" then return "skimmer_hold" end
  if AR:GetItemCount("lens") < 1 then return "need_lens" end
  return "return_lens"
end


function AR:IsOnBrokerMemoryQuest()
  local questIndex = 5 -- Human: The Surveyor's Glass
  if not AR:IsQuestAccepted("human", questIndex) then return nil end
  if AR:IsQuestComplete("human", questIndex) then return nil end
  return 1
end

function AR:IsSputtervalveReturnReady()
  if not AR:IsQuestAccepted("human", 5) then return nil end
  if AR:IsQuestComplete("human", 5) then return nil end
  if AR:GetItemCount("lens") >= 1 then return 1 end
  return nil
end

function AR:GetBrokerMemoryProgressText()
  local stage = AR:GetLivingMeasureStage()
  if stage == "question_goblin" then return "Question Suspicious Goblin" end
  if stage == "skimmer_hold" then return "Search Skimmer Hold" end
  local lens = AR:GetItemCount("lens")
  if lens > 1 then lens = 1 end
  return "Cracked Survey Lens: " .. lens .. "/1"
end


function AR:IsOnManifestQuest()
  local questIndex = 4 -- Human: Cargo Under Seal
  if not AR:IsQuestAccepted("human", questIndex) then return nil end
  if AR:IsQuestComplete("human", questIndex) then return nil end
  if AR:GetItemCount("cargo_tag") >= 4 then return nil end
  return 1
end

function AR:IsHumanQ1KeyNeeded()
  if not AR:IsHumanQ1Active() then return nil end
  if AR:GetItemCount("cargo_key") >= 1 then return nil end
  return 1
end

function AR:IsHumanQ1KeyMob(mobName)
  if not mobName or not AR.humanQ1KeyMobs then return nil end
  local i
  for i = 1, table.getn(AR.humanQ1KeyMobs) do
    if string.find(mobName, AR.humanQ1KeyMobs[i], 1, true) then return 1 end
  end
  return nil
end

function AR:CanRollMobLoot(tableKey)
  if tableKey == "q1_sailor_key" then
    return AR:IsHumanQ1KeyNeeded()
  end
  if tableKey == "southsea_ratchet" or tableKey == "southsea" then
    return AR:IsOnManifestQuest()
  end
  if tableKey == "longshore" then
    if not AR:IsQuestAccepted("human", 8) then return nil end
    if AR:IsQuestComplete("human", 8) then return nil end
    if AR:GetItemCount("broker_cut_ledger") >= 1 then return nil end
    return 1
  end
  if tableKey == "cozzle" then
    if not AR:IsQuestAccepted("human", 10) then return nil end
    if AR:IsQuestComplete("human", 10) then return nil end
    if AR:GetItemCount("contract") >= 1 then return nil end
    return 1
  end
  return 1
end

function AR:QueueMobSearch(mobName, tableKey)
  if not mobName or not tableKey then return end
  if not AR.pendingMobSearches then AR.pendingMobSearches = {} end

  local now = nil
  if time then now = time() end
  local pending = AR.pendingMobSearches[mobName]
  if pending and pending.tableKey == tableKey and pending.time and now and pending.time == now then
    return
  end
  if not pending then
    pending = { count=0, tableKey=tableKey }
    AR.pendingMobSearches[mobName] = pending
  end
  pending.count = (pending.count or 0) + 1
  pending.tableKey = tableKey
  pending.time = now
end

function AR:ConsumeMobSearch(mobName)
  if not mobName or not AR.pendingMobSearches then return nil end
  local pending = AR.pendingMobSearches[mobName]
  if not pending or not pending.count or pending.count <= 0 then return nil end

  pending.count = pending.count - 1
  if pending.count <= 0 then AR.pendingMobSearches[mobName] = nil end
  return pending.tableKey
end

function AR:TrySearchTargetCorpse()
  if not UnitName or not UnitIsDead then return nil end
  if UnitExists and not UnitExists("target") then return nil end
  if not UnitIsDead("target") then return nil end

  local mobName = UnitName("target")
  if not mobName then return nil end
  local tableKey = AR:ConsumeMobSearch(mobName)
  if not tableKey then return nil end
  if not AR:CanRollMobLoot(tableKey) then return nil end

  AR:SearchMobForEvidence(mobName)
  AR:RollLoot(tableKey, mobName)
  return 1
end

function AR:SearchMobForEvidence(mobName)
  -- Intentionally quiet: the physical click is the search feedback.
end

function AR:NoEvidenceFound(mobName)
  if mobName and AR:IsHumanQ1KeyMob(mobName) and AR:IsHumanQ1Active() then
    return
  end
  if mobName and (string.find(mobName, "Venture Co.", 1, true) or string.find(mobName, "Privateer", 1, true) or string.find(mobName, "Freebooter", 1, true) or string.find(mobName, "Bloodsail", 1, true)) then
    -- Later quests intentionally stay quiet on no-drop so they do not copy the manifest quest cadence.
    return
  end

  AR:SpeakMutter(
    "southsea_nodrop_once",
    '"Nothing. Just rope, rust, and stink."',
    '"Nothing on this one. Just rope, rust, and stink."'
  )
end

function AR:HandleMobDeathMessage(msg)
  if not msg then return end
  local mobName, tableKey
  if AR:IsHumanQ1KeyNeeded() then
    local i
    for i = 1, table.getn(AR.humanQ1KeyMobs) do
      mobName = AR.humanQ1KeyMobs[i]
      if mobName and string.find(msg, mobName, 1, true) then
        AR:QueueMobSearch(mobName, "q1_sailor_key")
        return
      end
    end
  end
  for mobName, tableKey in pairs(AR.mobLootTables) do
    if string.find(msg, mobName, 1, true) then
      if AR:CanRollMobLoot(tableKey) then
        AR:QueueMobSearch(mobName, tableKey)
      end
      return
    end
  end
end

function AR:CreateLootFrame()
  if AR.frames.loot then return end

  local f = CreateFrame("Frame", "AshenRelicsLootFrame", UIParent)
  f:SetWidth(300)
  f:SetHeight(250)
  f:SetPoint("CENTER", UIParent, "CENTER", 210, -80)
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  f:SetBackdrop({
    bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
    tile=1, tileSize=32, edgeSize=32,
    insets={left=8,right=8,top=8,bottom=8}
  })
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function() this:StartMoving() end)
  f:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
  f:Hide()

  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  f.title:SetPoint("TOP", f, "TOP", 0, -18)
  f.title:SetText("Ashen Relics Loot")

  f.source = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  f.source:SetPoint("TOP", f.title, "BOTTOM", 0, -6)
  f.source:SetWidth(250)
  f.source:SetJustifyH("CENTER")
  f.source:SetTextColor(0.85, 0.72, 0.48)

  f.rows = {}
  local i
  for i = 1, 4 do
    local row = CreateFrame("Button", nil, f)
    row:SetPoint("TOPLEFT", f, "TOPLEFT", 30, -68 - ((i-1)*38))
    row:SetWidth(240)
    row:SetHeight(34)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.icon:SetWidth(30)
    row.icon:SetHeight(30)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("LEFT", row, "LEFT", 40, 0)
    row.text:SetWidth(150)
    row.text:SetJustifyH("LEFT")

    row.take = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.take:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.take:SetText("Take")

    row:SetNormalTexture("Interface\\Buttons\\UI-Listbox-Highlight")
    row:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight")
    row:SetScript("OnClick", function()
      if this.itemKey then
        AR:AddItem(this.itemKey, 1)
        this:Hide()
      end
    end)

    f.rows[i] = row
  end

  f.close = CreateFrame("Button", nil, f)
  f.close:SetPoint("BOTTOM", f, "BOTTOM", 0, 16)
  f.close:SetWidth(90)
  f.close:SetHeight(24)
  f.close:SetNormalTexture("Interface\\Buttons\\UI-Panel-Button-Up")
  f.close:SetPushedTexture("Interface\\Buttons\\UI-Panel-Button-Down")
  f.close:SetHighlightTexture("Interface\\Buttons\\UI-Panel-Button-Highlight")
  local closeText = f.close:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  closeText:SetPoint("CENTER", f.close, "CENTER", 0, 0)
  closeText:SetText("Close")
  f.close:SetScript("OnClick", function() AR.frames.loot:Hide() end)

  AR.frames.loot = f
end

function AR:ShowLootWindow(title, drops, sourceName)
  AR:CreateLootFrame()
  local f = AR.frames.loot
  f.title:SetText(title or "Ashen Relics Loot")
  if f.source then
    if sourceName then
      f.source:SetText("Recovered from " .. sourceName)
    else
      f.source:SetText("")
    end
  end

  local i
  for i = 1, 4 do
    f.rows[i]:Hide()
    f.rows[i].itemKey = nil
  end

  if not drops or table.getn(drops) == 0 then
    f.title:SetText((title or "Ashen Relics Loot") .. " - Empty")
  else
    for i = 1, table.getn(drops) do
      if i <= 4 then
        local key = drops[i]
        local def = AR.itemDefs[key]
        if def then
          local row = f.rows[i]
          row.itemKey = key
          row.icon:SetTexture(def.texture)
          row.text:SetText(def.name)
          row:Show()
        end
      end
    end
  end
  f:Show()
end

function AR:RollLoot(tableKey, sourceName)
  local lt = AR.lootTables[tableKey]
  if not lt then
    DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics:|r unknown loot table.")
    return
  end

  local drops = {}
  local i
  for i = 1, table.getn(lt.drops) do
    local d = lt.drops[i]
    local chance = d.chance
    if not d.exactChance then
      if chance < 10 then chance = 10 end
      if chance > 20 then chance = 20 end
    end
    if math.random(100) <= chance then
      table.insert(drops, d.key)
    end
  end

  if table.getn(drops) > 0 then
    AR:ShowLootWindow("Recovered Evidence", drops, sourceName)
  else
    if sourceName then
      AR:NoEvidenceFound(sourceName)
    else
      AR:ShowLootWindow(lt.title, drops)
    end
  end
end

function AR:ToggleBag()
  AR:CreateBagFrame()
  if AR.frames.bag:IsShown() then
    AR.frames.bag:Hide()
  else
    if AR.frames.main then
      AR.frames.bag:ClearAllPoints()
      AR.frames.bag:SetPoint("LEFT", AR.frames.main, "RIGHT", -8, 0)
    end
    AR.frames.bag:Show()
  end
end



function AR:DebugRows()
  DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics row texture paths:|r")
  DEFAULT_CHAT_FRAME:AddMessage("Normal: " .. AR.rowTextures.normal)
  DEFAULT_CHAT_FRAME:AddMessage("Selected: " .. AR.rowTextures.selected)
  if AR.frames.main and AR.frames.main.sidebar and AR.frames.main.sidebar.rows then
    local i
    for i = 1, table.getn(AR.frames.main.sidebar.rows) do
      local r = AR.frames.main.sidebar.rows[i]
      if r and r.bg and r.questIndex then
        r.bg:SetDrawLayer("ARTWORK")
        r.bg:SetTexture(AR.rowTextures.selected)
        r.bg:SetAlpha(1.0)
      end
    end
    DEFAULT_CHAT_FRAME:AddMessage("Forced all quest row textures to selected for testing.")
  end
end

function AR:DebugTextures()
  DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics texture paths:|r")
  DEFAULT_CHAT_FRAME:AddMessage("Page tile: " .. AR.pageBase .. "arpage_r01_c01.tga")
  DEFAULT_CHAT_FRAME:AddMessage("Icon: " .. AR.iconBase .. "manifest.tga")
  DEFAULT_CHAT_FRAME:AddMessage("Dialogue tile: " .. AR.dialogueBase .. "AshenQuestDialogue_256\\ashen_dialogue_r01_c01.tga")
  if AR.frames.main then
    if AR.frames.main.textureTest then
      if AR.frames.main.textureTest:IsShown() then
        AR.frames.main.textureTest:Hide()
        DEFAULT_CHAT_FRAME:AddMessage("Texture test hidden.")
      else
        AR.frames.main.textureTest:Show()
        DEFAULT_CHAT_FRAME:AddMessage("Texture test shown at top-right of quest page.")
      end
    end
    if AR.frames.main.targetIcon then AR.frames.main.targetIcon:SetTexture(AR.icons.manifest) end
    if AR.frames.main.rewardIcon then AR.frames.main.rewardIcon:SetTexture(AR.icons.rep) end
  end
end

function AR:CompleteSelected()
  local cat = AR.categories[AR.activeCategory]
  if not cat then return end
  AR:CompleteQuest(cat.key, AR.activeQuest)
end

function AR:GoToNextQuest()
  local cat = AR.categories[AR.activeCategory]
  if not cat then return end
  local list = AR:GetQuestList(cat.key)
  local nextQuest = (AR.activeQuest or 1) + 1
  local q = list[nextQuest]
  if not q then
    DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics:|r there is no next quest in this relic chain.")
    return
  end

  if not AR:IsQuestUnlocked(cat.key, nextQuest) then
    if AR:IsQuestAvailable(cat.key, nextQuest) then
      AR:SetQuestAccepted(cat.key, nextQuest, 1)
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics:|r the next quest is still locked. Complete the current step first.")
      return
    end
  elseif not AR:IsQuestAccepted(cat.key, nextQuest) and AR:IsQuestAvailable(cat.key, nextQuest) then
    AR:SetQuestAccepted(cat.key, nextQuest, 1)
  end

  AR.activeEvidenceQuest = nil
  AR.activeQuest = nextQuest
  AR:RenderSidebar()
  AR:RenderQuestDetail()
  AR:UpdateCategoryCounts()
  AR:UpdateQuestOverlays()
  DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics:|r selected next quest: " .. (q.title or "Unknown") .. ".")
end

function AR:ResetProgress()
  AR:ResetAllQuestsFromOptions()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("GOSSIP_SHOW")
loader:RegisterEvent("QUEST_GREETING")
loader:RegisterEvent("QUEST_DETAIL")
loader:RegisterEvent("CHAT_MSG_COMBAT_HOSTILE_DEATH")
loader:RegisterEvent("PLAYER_ENTERING_WORLD")
loader:RegisterEvent("ZONE_CHANGED")
loader:RegisterEvent("ZONE_CHANGED_INDOORS")
loader:RegisterEvent("ZONE_CHANGED_NEW_AREA")
loader:RegisterEvent("PLAYER_TARGET_CHANGED")
loader:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
loader:RegisterEvent("WORLD_MAP_UPDATE")
loader:RegisterEvent("PLAYER_LOGOUT")
loader:SetScript("OnEvent", function()
  if event == "PLAYER_LOGOUT" then
    AR:CancelIntroNarration()
    AR:RestoreSoundSettings()
    return
  end

  if event == "CHAT_MSG_COMBAT_HOSTILE_DEATH" then
    AR:HandleMobDeathMessage(arg1)
    return
  end

  if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA" then
    AR:CheckLocationFlavor()
    AR:CheckGazloweReturnProximity()
    AR:UpdateQuestOverlays()
    return
  end

  if event == "PLAYER_TARGET_CHANGED" then
    AR:CheckTargetVicinity()
    return
  end

  if event == "UPDATE_MOUSEOVER_UNIT" then
    AR:CheckMouseoverVicinity()
    return
  end

  if event == "WORLD_MAP_UPDATE" then
    AR:UpdateWorldMapQuestOverlay()
    return
  end

  if event == "GOSSIP_SHOW" or event == "QUEST_GREETING" or event == "QUEST_DETAIL" then
    AR:TryGossipDialogue()
    return
  end

  if arg1 == "AshenRelics" then
    if not AshenRelicsDB.completed then AshenRelicsDB.completed = {} end
    if not AshenRelicsDB.accepted then AshenRelicsDB.accepted = {} end
    if not AshenRelicsDB.items then AshenRelicsDB.items = {} end
    if not AshenRelicsDB.flags then AshenRelicsDB.flags = {} end
    if not AshenRelicsDB.dev then AshenRelicsDB.dev = {} end
    if not AshenRelicsDB.evidenceLog then AshenRelicsDB.evidenceLog = {} end
    AR:EnsureCopyEditDB()
    AR:ApplyAllQuestCopyEdits()
    AR:EnsureRelicWhisperDB()
    if (AshenRelicsDB.accepted["human_00"] or AshenRelicsDB.completed["human_00"]) and not AshenRelicsDB.completed["human_intro_to_gazlowe"] then
      AshenRelicsDB.accepted["human_intro_to_gazlowe"] = 1
      AshenRelicsDB.completed["human_intro_to_gazlowe"] = 1
      AshenRelicsDB.flags.gazlowe_intro_handoff_complete = 1
    end
    AR:SetQuestAccepted("human", 1, 1)
    if AR:IsQuestComplete("human", 1) then AR:SetQuestAccepted("human", 2, 1) end
    local qi
    for qi = 1, table.getn(AR:GetQuestList("human")) do
      if AR:IsQuestComplete("human", qi) then AR:SetQuestAccepted("human", qi, 1) end
    end
    if not AshenRelicsDB.layoutVersion or AshenRelicsDB.layoutVersion < 41 then
      AshenRelicsDB.layoutVersion = 41
      if not AshenRelicsDB.layout then AshenRelicsDB.layout = {} end
      AshenRelicsDB.layout.interludeText = {x=28,y=-92,w=388,h=470,scale=1}
      AshenRelicsDB.layout.interludeButtons = {x=58,y=-548,w=210,h=24,scale=1}
    end
    math.randomseed(time())
    AR:CreateMinimapButton()
    AR:CreateMinimapQuestOverlay()
    AR:CreateProximityTicker()
    AR:CreateHumanQ1SearchTicker()
    AR:CreateRelicWhisperTicker()
    AR:InstallNPCDialogueHooks()
    AR:CheckLocationFlavor()
    AR:CheckGazloweReturnProximity()
    AR:UpdateQuestOverlays()
    DEFAULT_CHAT_FRAME:AddMessage("|cffb43a2aAshen Relics v0.7.5-whisper-30s|r loaded. Use /ar.")
  end
end)

SLASH_ASHENRELICS1 = "/ar"
SLASH_ASHENRELICS2 = "/ashenrelics"
SlashCmdList["ASHENRELICS"] = function(msg)
  local _, _, cmd, rest = string.find(msg or "", "^%s*(%S*)%s*(.*)$")
  cmd = string.lower(cmd or "")
  rest = rest or ""
  if cmd == "talk" then
    AR:TryOpenTargetDialogue()
  elseif cmd == "loot" then
    AR:RollLoot(rest)
  elseif cmd == "additem" then
    AR:AddItem(rest, 1)
  elseif cmd == "rows" then
    AR:DebugRows()
  elseif cmd == "dump" then
    AR:ShowDumpWindow()
  elseif cmd == "dialogue" or cmd == "dialog" or cmd == "dialogs" then
    AR:ToggleDevDialogue()
  elseif cmd == "copydump" or cmd == "copyedits" or cmd == "dumpcopy" then
    AR:ShowCopyEditsDumpWindow()
  elseif cmd == "editquest" then
    local qi = tonumber(rest) or AR.activeQuest or 1
    AR:OpenQuestCopyEditor("human", qi)
  elseif cmd == "beat" or cmd == "beats" then
    AR:ToggleStoryBeatRecorder()
  elseif cmd == "dev" or cmd == "record" then
    AR:ToggleHumanQ1Recorder()
  elseif cmd == "soundtest" then
    AR:SoundTest()
  elseif cmd == "whispers" then
    AR:ToggleRelicWhispers()
  elseif cmd == "whispertest" then
    AR:DebugPlayNextRelicWhisper()
  elseif cmd == "fixmanifest" or cmd == "manifestfix" then
    AR:FixHumanQ1ManifestStuck()
  elseif cmd == "options" then
    AR:ToggleOptions()
  elseif cmd == "textures" then
    AR:DebugTextures()
  elseif cmd == "complete" then
    AR:CompleteSelected()
  elseif cmd == "next" then
    AR:GoToNextQuest()
  elseif cmd == "reset" then
    AR:ResetProgress()
  else
    AR:ToggleMain()
  end
end

SLASH_BANNERRELIQUARY1 = "/reliquary"
SLASH_BANNERRELIQUARY2 = "/br"
SlashCmdList["BANNERRELIQUARY"] = function(msg) AR:ToggleBag() end

_G["AshenRelics"] = AR


SLASH_ASHENRELICSDEV1 = "/dev"
SlashCmdList["ASHENRELICSDEV"] = function(msg)
  local _, _, cmd, rest = string.find(msg or "", "^%s*(%S*)%s*(.*)$")
  cmd = string.lower(cmd or "")
  rest = rest or ""
  if cmd == "dialogue" or cmd == "dialog" or cmd == "dialogs" or cmd == "" then
    AR:ToggleDevDialogue()
  elseif cmd == "dump" or cmd == "copydump" or cmd == "copyedits" then
    AR:ShowCopyEditsDumpWindow()
  elseif cmd == "editquest" then
    AR:OpenQuestCopyEditor("human", tonumber(rest) or AR.activeQuest or 1)
  else
    AR:ToggleHumanQ1Recorder()
  end
end
