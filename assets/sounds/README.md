# Sounds (placeholders)

Placeholder sounds for every event we know of, so the game isn't silent at the demo. Replace any file freely: keep the file name and nothing else needs to change.

- **License:** every file is **CC0** (public domain) from [Freesound](https://freesound.org). Commercial use is fine and credit isn't required, but the sources are listed below anyway.
- **Format:** effects are mono 16-bit WAV (Godot's choice for short sounds), trimmed and levelled to about the same loudness. Music and ambience are the original Ogg Vorbis previews.
- **Buses:** play effects on `SFX` and music/ambience on `Music` (see CLAUDE.md).
- **Loops:** the music and background files are set to loop in their `.import` files.
- **Wired:** `SurgicalTool.drop_sound` plays when a tool lands after being let go (`ToolGrabber`, on the `SFX` bus). The base scene `tools/surgical_tool.tscn` sets it to a random pick of `gameplay/tool_drop_1–3.wav`; tools with an `items/<id>.wav` get that instead (see below). `ToolGrabber` also plays `tool_grab` on pick-up (silly items play their own sound), `tool_return_whoosh` and `surgeon_receive`. `levels/level.tscn` has a `Sounds` node with the request, right, wrong, hint, tray slide and level-complete players, called from `level.gd`, plus the operating-room background. UI sounds live in the `UiSounds` autoload (`ui/ui_sounds.tscn`), so a click survives a scene change: every button clicks, and the sheet, settings slider, toast, Pocket Guide tabs and cards have their own sounds. The main menu plays `music_menu`. Sounds not listed here aren't wired yet.

## Gameplay (`gameplay/`)

| File | When | Source |
|---|---|---|
| `tool_grab.wav` | A tool is picked up (`ToolGrabber.tool_grabbed`). | [Metal Click.WAV](https://freesound.org/people/scaevola/sounds/333260/) by scaevola |
| `tool_drop_1.wav` | A tool lands on the tray (pick one of the 3 at random). | [Dropping a Metal Spoon](https://freesound.org/people/eben-frostey/sounds/608680/) by eben-frostey |
| `tool_drop_2.wav` | Variation 2 of the above. | [dropping a fork_1-2.aif](https://freesound.org/people/acrober/sounds/86141/) by acrober |
| `tool_drop_3.wav` | Variation 3 of the above. | [Metal Knife Drop- Short.wav](https://freesound.org/people/akennedybrewer/sounds/389185/) by akennedybrewer |
| `tool_clink_1.wav` | Tools hit each other or the tray. Scale volume by impact speed, pick at random. | [Clink1.wav](https://freesound.org/people/BMacZero/sounds/96134/) by BMacZero |
| `tool_clink_2.wav` | Variation 2 of the above. | [Clink3.wav](https://freesound.org/people/BMacZero/sounds/96136/) by BMacZero |
| `tool_clink_3.wav` | Variation 3 of the above. | [Metal Tap](https://freesound.org/people/Alteration/sounds/191489/) by Alteration |
| `tray_hit.wav` | A harder hit on the tray itself. | [Silver Cheese Tray Hit 1.wav](https://freesound.org/people/potentjello/sounds/194137/) by potentjello |
| `tray_rummage.wav` | Soft clatter while the pile moves (`_jumble()`, dragging through the pile). | [Cutlery in A Drawer](https://freesound.org/people/dslrguide/sounds/321479/) by dslrguide |
| `tool_return_whoosh.wav` | A tool flies back to the tray (`return_to_tray`). | [Swish 4](https://freesound.org/people/ihitokage/sounds/395369/) by ihitokage |
| `handoff_correct.wav` | Right tool handed over. | [correct](https://freesound.org/people/ertfelda/sounds/243701/) by ertfelda |
| `handoff_wrong.wav` | Wrong tool handed over. | [Wrong Answer Buzzer](https://freesound.org/people/-Andreas/sounds/650842/) by -Andreas |
| `surgeon_receive.wav` | The tool lands in the surgeon's hand (`consume`). | [Slap.wav](https://freesound.org/people/MrDrPrFr/sounds/337148/) by MrDrPrFr |
| `surgeon_happy.wav` | Surgeon is pleased. | [mhm.mp3](https://freesound.org/people/gnimpl/sounds/339838/) by gnimpl |
| `surgeon_annoyed.wav` | Surgeon is annoyed (wrong tool, slow). | [male sigh.wav](https://freesound.org/people/Reitanna/sounds/215380/) by Reitanna |
| `throw_whoosh.wav` | Surgeon throws the wrong tool at the patient (IDEAS.md). | [Whoosh #1](https://freesound.org/people/Kinoton/sounds/427823/) by Kinoton |
| `throw_stab.wav` | ...and it lands in the patient. | [Knife Stab Melon.wav](https://freesound.org/people/jawbutch/sounds/344404/) by jawbutch |
| `request_new.wav` | A new request card appears. | [Pop-up/notification.wav](https://freesound.org/people/GabrielAraujo/sounds/242502/) by GabrielAraujo |
| `hint_sparkle.wav` | A hint glow starts. | [Item Sparkle](https://freesound.org/people/Mr._Fritz_/sounds/545238/) by Mr._Fritz_ |
| `tray_slide.wav` | The tray slides away / back between trays. | [Metal Slide 2](https://freesound.org/people/WasabiWielder/sounds/323369/) by WasabiWielder |
| `level_complete.wav` | Level complete. | [Congrats](https://freesound.org/people/Fupicat/sounds/607207/) by Fupicat |
| `new_best.wav` | New best time / rank up (leaderboard). | [Achievement Accomplish Jingle App UI](https://freesound.org/people/CogFireStudios/sounds/619840/) by CogFireStudios |

## Silly items (`items/`)

Played when the item lands after being dropped (its `drop_sound`), instead of the metal `gameplay/tool_drop_*.wav`. Not on grab. Each item sounds like its real material (no gag sounds). Each file is named after the tool `id`: the instrument build script (`dev/instruments/build_instruments.gd`) gives a tool `items/<id>.wav` as its `drop_sound` when that file exists. Metal lookalikes (`eyebrow_tweezers`, `dental_explorer`) use the default metal sound. Ids of items not built yet are guesses; rename the file if the id ends up different.

| File | Sound | Source |
|---|---|---|
| `rubber_duck.wav` | squeaky toy (Julia: squeak, not quack) | [Squeaky Toy #1](https://freesound.org/people/Breviceps/sounds/468443/) by Breviceps |
| `banana.wav` | soft thud | [soft-hit.wav](https://freesound.org/people/Krokulator/sounds/653910/) by Krokulator |
| `eyelash_curler.wav` | metal click | [Metallic_Click](https://freesound.org/people/BlondPanda/sounds/778444/) by BlondPanda |
| `spatula.wav` | wooden spoon on a counter | [hit - wooden spoon - dropped onto counter 07.wav](https://freesound.org/people/Anthousai/sounds/406287/) by Anthousai |
| `lipstick.wav` | plastic cap click | [click1.wav](https://freesound.org/people/florian_reinke/sounds/63531/) by florian_reinke |
| `wing_corkscrew.wav` | metal ching | [Metallic_Ching_Keys_2.mp3](https://freesound.org/people/michael_grinnell/sounds/464426/) by michael_grinnell |
| `nose_hair_trimmer.wav` | plastic hit | [Plastic Bottle Hit](https://freesound.org/people/WarcakeStudios/sounds/173598/) by WarcakeStudios |
| `butt_plug.wav` | metal hit | [Metal Hit](https://freesound.org/people/BenjaminNelan/sounds/410364/) by BenjaminNelan |
| `oscar_statuette.wav` | hollow plastic drop (the Oscar is a light plastic replica) | [hollow plastic box, dropped](https://freesound.org/people/Lemato/sounds/697092/) by Lemato |
| `crime_and_punishment.wav` | book drop | [Book Dropping 1.wav](https://freesound.org/people/LightDJ/sounds/267481/) by LightDJ |
| `sock.wav` | cloth rustle | [Fabric_Foley_1](https://freesound.org/people/Mediasaur/sounds/789038/) by Mediasaur |
| `dentures.wav` | teeth click | [Perc_Teeth_lo](https://freesound.org/people/LudwigMueller/sounds/548541/) by LudwigMueller |
| `cat_head.wav` | meow | [cat meow](https://freesound.org/people/tuberatanka/sounds/110011/) by tuberatanka |
| `falafel.wav` | crunch | [Crunch](https://freesound.org/people/steenish/sounds/528962/) by steenish |
| `coin_5_shekel.wav` | coin drop | [Real Coin Drop](https://freesound.org/people/Rocotilos/sounds/343462/) by Rocotilos |

## UI (`ui/`)

| File | When | Source |
|---|---|---|
| `ui_click.wav` | Any button. | [Videogame Menu BUTTON CLICK](https://freesound.org/people/Christopherderp/sounds/342200/) by Christopherderp |
| `ui_back.wav` | Back / close. | [Arcade UI Cancel](https://freesound.org/people/plasterbrain/sounds/464912/) by plasterbrain |
| `ui_tab.wav` | Pocket Guide tab switch. | [UISwitchTab1](https://freesound.org/people/NoisyRedFox/sounds/759827/) by NoisyRedFox |
| `ui_sheet.wav` | Bottom sheet slides up or down. | [swoosh_v2](https://freesound.org/people/migoreng1/sounds/786514/) by migoreng1 |
| `ui_pause.wav` | Pause. | [pause.mp3](https://freesound.org/people/crisstanza/sounds/167127/) by crisstanza |
| `ui_resume.wav` | Resume. | [unpause.mp3](https://freesound.org/people/crisstanza/sounds/167126/) by crisstanza |
| `ui_locked.wav` | Tapping a locked level. | [acess denied buzz](https://freesound.org/people/Jacco18/sounds/419023/) by Jacco18 |
| `ui_slider_tick.wav` | Sample while the Sound slider moves. | [Button Tick](https://freesound.org/people/NenadSimic/sounds/268108/) by NenadSimic |
| `ui_toast.wav` | "Coming soon" toast. | [Message Receive](https://freesound.org/people/Froey_/sounds/760369/) by Froey_ |
| `guide_card_open.wav` | Pocket Guide card opens the 3D view. | [flipCard.wav](https://freesound.org/people/Splashdust/sounds/84322/) by Splashdust |

## Music and ambience (`music/`)

| File | When | Source |
|---|---|---|
| `music_menu.ogg` | Main menu loop (18 s). | [BirdFish Happy Loop.mp3](https://freesound.org/people/pinkinblue/sounds/425971/) by pinkinblue |
| `music_level.ogg` | In-level loop (58 s). | [Upbeat loop](https://freesound.org/people/mistermender/sounds/512340/) by mistermender |
| `heart_monitor.wav` | Level background, on top of the room: ten regular heartbeats (10.7 s loop; the speed-up and flatline in the recording are cut out) | [Heart Monitor Beep](https://freesound.org/people/samfk360/sounds/148897/) by samfk360 |
| `ambience_or_room.wav` | Level background: a real operating room, machine hum (22 s loop from 72.5–94.5 s of the recording, which has no monitor alarms; the alarm melodies elsewhere in it are cut out) | [room tone operating room quiet machine hum and monitor beeps…](https://freesound.org/people/kyles/sounds/406512/) by kyles |

## Finding replacements

Freesound with the CC0 filter worked best: `https://freesound.org/search/?q=<words>&f=license:"Creative Commons 0"`. Kenney's CC0 audio packs (kenney.nl) and OpenGameArt are the other usual jam sources, but the venue network blocks both.
