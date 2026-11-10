# SoundNexus Pro – user manual, English text (same structure as content_hu.py)

META = dict(
    title='SoundNexus Pro',
    subtitle='Detailed user manual',
    version='Release 1.0 · November 2026',
    toc='Contents',
    fig='Figure',
    intro_video='SoundNexus Pro – user guide',
    outro_video='The complete, detailed description is in the PDF manual.',
)

SECTIONS = [
dict(id='intro', title='What is SoundNexus Pro?', shot='main', body='''
SoundNexus Pro is an editor and live control program for **Yamaha Genos 2, Genos, Tyros 5, Tyros 4 and PSR-SX** instruments. It manages your songs (lyrics, chords, score), voices, rhythm, layers (V1–V4), OTS and registrations in one place, and sets up the instrument for a song with a single click.
The program has two parts, and this is the most important rule:
- **PC / Mac – editor:** all design and editing happens here: songs, scores, buttons, colours, images, layout, templates, samples.
- **Tablet / phone – performance mode:** use only. The mobile plays the package received from the PC; nothing can be changed there – so nothing can get mis-set on stage.
The workflow is always: **design on the PC → send to the tablet / phone → perform on the mobile.**
> The program offers 20 languages, and on the PC you can preview how the interface will look on a tablet and on a phone.
''', video=['SoundNexus Pro is made for Yamaha Genos, Tyros and PSR-SX instruments.',
            'You edit on the PC or Mac, and you perform on the tablet or phone.',
            'Nothing can get mis-set on the mobile: it is for use only.']),

dict(id='install', title='Installation', shot=None, body='''
Download the program from the GitHub release (Releases → latest). No installer is needed and nothing is written to the system.
## Windows (editor)
- Download **SoundNexusPro-Windows.zip** and extract it to any folder (e.g. Documents).
- Start **SoundNexus Pro.exe**. Runs on Windows 10 and 11.
- If Windows SmartScreen warns you: “More info” → “Run anyway”.
## Mac (editor)
- Download **SoundNexusPro-macOS.zip**, extract it and drag the program into Applications.
- On first start: right-click the program → Open → Open. Runs on Intel and Apple Silicon; the 2015 MacBook Pro / Air is supported too.
## Android tablet and phone (performance mode)
- Copy **SoundNexusPro-Android.apk** to the device and open it.
- Allow installation from “unknown sources” if asked. Android 7.0 or newer is required.
## iPad and iPhone
- The program also builds for iOS, but installing it requires an Apple developer account. Once that is set up, the iOS version will be added to the release.
! Your settings (language, display mode) and the autosave are stored in your user folder, in the “SoundNexus Pro” subfolder. The program folder can be deleted or moved at any time.
''', video=['Windows: extract the ZIP and start SoundNexus Pro.exe.',
            'Mac: on first start, right-click → Open.',
            'Android: copy the APK file to the device and install it.']),

dict(id='settings', title='First start: language and display mode', shot='settings', body='''
The **gear** icon in the top right corner (or View → Language and display mode…) opens the settings window.
## Language
Choose from 20 languages: Hungarian, English, German, French, Spanish, Italian, Portuguese, Dutch, Polish, Czech, Slovak, Romanian, Croatian, Serbian, Slovenian, Russian, Ukrainian, Bulgarian, Greek and Turkish. The choice takes effect immediately and is remembered.
## Display mode
- **Automatic:** the editor (PC mode) on PC and Mac, the tablet layout on tablets, the phone layout on phones.
- **PC:** the full editor with menu bar and all editor windows.
- **Tablet:** a preview on the PC, exactly as it appears on a tablet: three columns side by side.
- **Phone:** a preview on the PC: the song in the middle, voices and rhythm slide in from the sides.
> In Tablet or Phone mode you can only look, not edit, even on the PC – just like on the mobile. The **“Back to PC mode”** button in the top bar returns to the editor.
''', video=['Use the gear icon to choose the language and the display mode.',
            'You can choose from 20 languages.',
            'In Tablet and Phone mode you preview the mobile interface on the PC.']),

dict(id='main', title='The main window', shot='main', body='''
The main window has five parts:
- **Menu bar (top):** File, Edit, View, Instrument, Tools, Help. On the right: the gear, the connection indicator (green = connected, yellow = test mode, red = not connected) and the Connect button.
- **Voices (left bar):** voice buttons in groups, in two columns. Pressing a button sends the voice to the instrument.
- **Song (centre):** the lyrics with chords, the score, or both. Page with the arrows or by swiping.
- **Rhythm (right bar):** Start / Stop, Intro, Main A–D, Fill In, Break, Ending, TAP tempo, tempo + / −.
- **Bottom control bar:** layers (V1–V4), One Touch Settings (OTS 1–4), registration banks, tempo, sync button.
The dividers can be dragged with the mouse to change the width of the bars.
## File menu
- New project (Ctrl+N), Open… (Ctrl+O), Save (Ctrl+S), Save as… (Ctrl+Shift+S).
- Send to tablet / phone…, Import lyrics (.txt)…, Exit.
The project file extension is **.snxproj** (old .alsproj files open too). The program also saves your work automatically, so nothing is lost after a power cut.
''', video=['Voices on the left, the song in the centre, rhythm on the right.',
            'At the bottom: layers (V1–V4), OTS and registration banks.',
            'Drag the dividers to change the width of the bars.']),

dict(id='connect', title='Connecting to the instrument', shot='connect', body='''
## PC / Mac
- Connect the instrument's **USB TO HOST** port to the computer with a USB cable (USB-B or USB-C) and switch the instrument on.
- Click **Connect** in the top right (or Instrument → Connect…).
- Choose the **MIDI output (to the instrument)** – for a Genos e.g. “Digital Keyboard-1” or “Genos-1” – and, if needed, the MIDI input.
- If the list is empty: check the cable and that the instrument is on, then click **Refresh**.
## Android / iPad / iPhone
- USB: a USB-C / OTG cable or adapter into the instrument's USB TO HOST port.
- Bluetooth: the **Bluetooth search** button also finds Bluetooth MIDI adapters (or instruments with Bluetooth MIDI).
## Test mode
With no instrument connected, the program runs in test mode: every button works, but no commands are sent out. The yellow indicator shows this.
! If a button says “Connect to the instrument first”, the MIDI connection has not been set up.
''', video=["Connect the instrument's USB TO HOST port to the computer.",
            "Connect button → choose the instrument's MIDI output.",
            'On mobile you can use a USB OTG cable or a Bluetooth MIDI adapter.']),

dict(id='voices', title='Voices: editing the left bar', shot='voices', body='''
Set up the left bar in **View → Voice panel editor…**.
- **Groups:** e.g. Piano, Organ, Strings, Guitar, Brass, Solo. New group, rename, delete; drag to reorder.
- **Voices:** for every button enter the name and the **Bank MSB / LSB / Program** numbers from the instrument's list (found in the instrument's Data List manual).
- **Columns:** one, two or three columns; the button look (colour, image, label, shape) can be set here too.
- **Default voice library:** ready-made starter groups if you want to begin from scratch.
## What to change where?
- A button gives the wrong voice → correct the MSB / LSB / Program numbers.
- The voice should go to another part (Right 1, Right 2, Left) → change the MIDI channel.
''', video=['In the Voice panel editor you create groups and buttons.',
            'Each button has a Bank MSB, LSB and Program number.',
            'Drag to change the order.']),

dict(id='rhythm', title='Rhythm: editing the right bar', shot='rhythm', body='''
In **View → Rhythm panel editor…** you decide which buttons appear on the right bar and in what order.
- Available items: Start / Stop, Intro A–C, Main A–D, Fill In, Break, Ending A–C, TAP tempo, Tempo + / −, Sync.
- **Add:** choose the new item in the “Add:” row. **Remove:** with the minus icon next to the item.
- **Order:** by dragging. **Columns:** the bar can have 1–3 columns.
You select the style itself **on the instrument**; SoundNexus Pro starts it, switches sections and sets the tempo from here.
''', video=['In the Rhythm panel editor you choose the buttons on the right.',
            'Start, Intro, Main A–D, Fill In, Break, Ending and tempo.',
            'Select the style on the instrument and control it from here.']),

dict(id='bottom', title='Bottom control bar: V1–V4, OTS, registration banks', shot='bottom', body='''
In **View → Bottom control bar editor…** you assemble the items of the bottom bar from left to right.
- **Layers (V1–V4):** four virtual layers on the instrument's Song channels, each with voice, keyboard zone, octave, volume and velocity curve.
- **One Touch Settings (OTS 1–4).**
- **Registration banks:** SoundNexus Pro's own registrations, 8 slots per bank.
- **Tempo, Sync button, Lock.**
## Storing and recalling a registration
- Click **Save** on the bar, then the slot number: the current setting is stored there.
- Later, click the number to recall it. An empty slot says: “is empty. To store: Save, then the number.”
''', video=['The bottom bar holds the V1–V4 layers, OTS and registration banks.',
            'To store: the Save button, then the slot number.',
            'Click the number to recall the setting.']),

dict(id='slot', title='Setting up a layer (V1–V4)', shot='slot', body='''
On the PC, clicking one of the V1–V4 buttons opens the layer settings:
- **On:** whether the layer sounds.
- **Voice (Bank MSB / LSB / Program)** and **MIDI channel** (the instrument's Song channels); try it immediately with **Send voice**.
- **Keyboard zone:** from which note to which note it sounds (e.g. only under the left hand).
- **Octave**, **Volume**.
- **Velocity curve:** e.g. “Only on strong hits” – the layer only sounds when you strike the key harder.
> Tip: strings under the piano on V1, brass sounding only on strong hits on V2 – so one hand controls two voices.
''', video=['Click a V1–V4 button to set up the layer.',
            'Voice, keyboard zone, octave, volume and velocity curve.',
            'For example: brass only on strong hits.']),

dict(id='song', title='Editing a song: lyrics, chords, score', shot='song', body='''
New song: **Edit → New song…**; existing song: **Edit → Edit song…** (Ctrl+E).
## Details
Title, artist, key, tempo, time signature, style name (selected on the instrument), start section, layers.
## Lyrics and chords
Write a chord in square brackets before the syllable, a section change in curly brackets, a comment with #:
- [G]Text [D]with chords
- {Main A} section – the instrument switches to Main A from here
- # comment – visible only to you
Lyrics can also be imported from a .txt file (UTF-8).
## Score
- **Import MIDI…:** the program reads the MIDI file, asks which track is the melody and creates a melody + chord score. The rhythmic grid (eighth / sixteenth) sets the precision of the score.
- **Take over tempo and time signature** copies the MIDI's tempo into the song.
- The full MIDI is attached to the song: on the tablet the **Play song** button plays it on the instrument.
## View
The song can be shown as text, as score, or both together.
## Sync (F5)
**Sync to the instrument** sends tempo, section and layers in one go.
> Automatic transcription from MP3/MP4 recordings (instrument separation, note recognition) arrives in the next phase, B.
''', video=['In the song editor you enter the title, tempo and key.',
            'Chord: [G], section change: {Main A}, comment: #.',
            'Importing a MIDI creates a melody + chord score.',
            'F5 sets up the instrument for the song in one go.']),

dict(id='theme', title='Theme, colours, background image', shot='theme', body='''
**View → Theme and colours…**
- **Ready-made themes:** Aurora, Neon, Ocean, Sunset, Lava, Emerald, Gold, Ice, Lavender, Midnight blue, Carbon, Crimson.
- **Background:** solid, gradient or **animated gradient** (cycle time and gradient direction adjustable; the colours can rotate too).
- **Background image:** upload your own image (max. 3 MB) – full image, fill or tile, blur, darken, transparency.
- **Accent colour, panel colour, panel transparency.**
**View → Font and text…:** font, font size, text colours.
**View → Bar styles:** each bar (voices, song, rhythm, bottom bar) can have its own background, border, corner rounding and spacing.
''', video=['Choose from twelve ready-made themes.',
            'Animated gradients and your own background image are possible.',
            'Each bar can have its own style.']),

dict(id='edit', title='Edit interface: buttons and bars', shot='edit', body='''
**View → Edit interface (buttons, bars)**.
- **Click any button** to change its look: image on the button (upload), label and its colour, button colour, size, shape (square, rounded, capsule, circle), image visibility (image only, without label, too).
- **The orange brush in the corner of each bar** styles the whole bar.
- **The dividers** can be dragged; **Reset sizes** restores them.
When you are done, switch it off with the same menu item and save the project.
! Editing is only possible in PC mode. The tablet and the phone receive exactly this look.
''', video=['In Edit interface mode the look of any button can be changed.',
            'Image, label, colour, size and shape.',
            'The orange brush styles a whole bar.']),

dict(id='sample', title='SoundNexus Sample Studio: trimming samples', shot='sample', body='''
**Tools → SoundNexus Sample Studio…** – trims silence and decay from WAV samples, **sample-accurately**. The remaining samples stay bit-identical: no resampling and no bit-depth change.
- **Open WAV:** one or more files (batch processing).
- **Onset threshold, Decay threshold, Noise floor:** how sensitive the trimming is.
- **Click-free ending:** a 5–20 ms fade at the end.
- **Start trimming**, then the result: how much was trimmed from the start and the end, “format unchanged ✓”.
- **Save:** the program asks where to save (overwrite or a new file).
! With slow-attack sounds (e.g. pad), listen to check that the start of the sound was not cut.
''', video=['Sample Studio trims silence and decay sample-accurately.',
            'The remaining samples are bit-identical to the original.',
            'When saving, it asks where the file should go.']),

dict(id='loop', title='SoundNexus Loop Studio: loop points', shot='loop', body='''
**Tools → SoundNexus Loop Studio…** – finds click-free loop points for sustained samples and writes them into the WAV file's **smpl** chunk (read by Yamaha Expansion Manager and most samplers).
- A sustained sound (strings, pad, organ, choir) works best.
- **Shortest loop**, **Root note (MIDI)**, **Crossfade** (equal-power; without it the samples stay untouched).
- **Find loop points** → result: loop start and end (samples and ms), seam match %, level difference.
- **The magnified seam** shows the loop end (left) and start (right): a smooth transition = no click.
''', video=['Loop Studio finds click-free loop points.',
            "The points are written into the WAV file's smpl chunk.",
            'Check the transition on the magnified seam.']),

dict(id='normalize', title='Style volume normalisation', shot=None, body='''
**Tools → Volume normalisation…** – evens out the loudness of styles (target: −18 LUFS).
- Enter the measured loudness of the style (LUFS) and the current CC7 values of the parts, separated by spaces.
- **Calculate** gives the new CC7 value for each part; any remaining difference goes into the style volume.
''', video=[]),

dict(id='send', title='Sending to a tablet / phone', shot='send', body='''
**File → Send to tablet / phone…** – creates a show package (.snxshow) from the project: songs, scores, MIDI files, images, buttons, theme, registrations.
## 1. Wi-Fi (recommended)
- The PC and the mobile must be on **the same Wi-Fi network**.
- On the PC: **Start sending**. A **6-digit code** appears.
- On the mobile: SoundNexus Pro → **Receive from PC**. The mobile finds the computer by itself; if not, enter the address shown on the PC.
- Enter the 6-digit code → **Download**. The PC shows how many devices have downloaded it.
! If the Windows firewall asks, allow “Private network” access.
## 2. As a file (USB cable, Bluetooth, AirDrop)
- **Save package (.snxshow)**, then copy it to the mobile (on Android to the Downloads folder, on iPhone/iPad to the Files app).
- On the mobile: Receive → **Open from file (.snxshow)**.
The transfer is protected by a checksum: the mobile rejects a damaged package.
''', video=['File → Send to tablet / phone.',
            'Wi-Fi: Start sending, on the mobile Receive from PC, then the 6-digit code.',
            'Or as a file: a .snxshow package via USB or AirDrop.']),

dict(id='tablet', title='Performance mode on a tablet', shot='tablet', body='''
On a tablet the interface has three columns: voices on the left, the song in the middle, rhythm on the right, and the control bar at the bottom. Every button works as on the PC, but **nothing can be edited**.
- **Paging:** swipe or use the arrows; previous / next song buttons.
- **Lock page (padlock):** the song does not page away on an accidental touch.
- **Play song:** plays the attached MIDI on the instrument.
- **Start scrolling:** the text scrolls with the tempo (internal clock).
- **Receive from PC:** load a new package. On start, the program opens the last received package.
''', video=['On a tablet: three columns – voices, song and rhythm.',
            'The padlock locks the page so it does not turn by accident.',
            'The Play song button plays the MIDI on the instrument.']),

dict(id='phone', title='Performance mode on a phone', shot='phone', body='''
On a phone the song fills the full width in the middle. **Voices slide in from the left, rhythm from the right**, or open them with the icon at the left and right end of the top bar. The bottom bar items scroll horizontally.
> Phone mode on the PC shows exactly this – check there before sending that the buttons fit and the text is readable.
''', video=['On a phone the song is in the middle; voices and rhythm slide in from the sides.',
            "Check it in advance in the PC's Phone mode."]),

dict(id='about', title='Keyboard shortcuts', shot='about', body='''
- **Ctrl+N** new project · **Ctrl+O** open · **Ctrl+S** save · **Ctrl+Shift+S** save as
- **Ctrl+E** edit song · **F5** sync to the instrument
- **← / →** page · **Space** Start / Stop
On a Mac use Cmd instead of Ctrl.
''', video=['Ctrl+S save, Ctrl+E edit song, F5 sync.',
            'Arrows: page, Space: Start / Stop.']),

dict(id='where', title='What to change where? – quick finder', shot=None, table=[
    ('I want another language', 'Gear → Language'),
    ('See how it will look on tablet / phone', 'Gear → Display mode: Tablet / Phone'),
    ('A button gives the wrong voice', 'View → Voice panel editor → MSB / LSB / Program'),
    ('I need a new voice group', 'View → Voice panel editor → New group'),
    ('Other buttons on the rhythm bar', 'View → Rhythm panel editor'),
    ('V1–V4, OTS, registrations on the bar', 'View → Bottom control bar editor'),
    ("A button's image, colour, label", 'View → Edit interface → click the button'),
    ("A whole bar's background, border", 'View → Bar styles, or the orange brush'),
    ('Background, colours, animated gradient', 'View → Theme and colours'),
    ('Font, font size', 'View → Font and text'),
    ("A song's lyrics, chords, tempo", 'Edit → Edit song (Ctrl+E)'),
    ('A score for the song', 'Edit song → Score → Import MIDI'),
    ('The instrument does not react', 'Instrument → Connect, choose the MIDI output'),
    ('Get the change onto the tablet', 'Save, then File → Send to tablet / phone'),
    ('Silence at the start / end of a WAV', 'Tools → SoundNexus Sample Studio'),
    ('Loop points into a WAV', 'Tools → SoundNexus Loop Studio'),
], body='''
Left column: what you want to achieve; right column: where to do it.
''', video=[]),

dict(id='trouble', title='Troubleshooting', shot=None, body='''
## No MIDI device found
- Switch the instrument on and plug the cable into the instrument's **USB TO HOST** port (not USB TO DEVICE).
- Click Refresh. Try another USB port or cable.
- On mobile: an OTG cable / adapter is needed; for Bluetooth use the Bluetooth search.
## The mobile does not find the PC
- Are both on the same Wi-Fi? (On guest networks devices often cannot see each other.)
- Is sending running on the PC? Did you allow “Private network” access in the firewall?
- Enter the address shown on the PC manually (e.g. 192.168.1.20).
## “Wrong code” or “Damaged transfer”
Check the 6-digit code; after a damaged transfer simply try again.
## The image cannot be uploaded
The image may be at most 3 MB – shrink it.
## The MIDI file cannot be read
Only standard MIDI (.mid) files can be imported, not Yamaha's own style files.
## The project cannot be opened
Only .snxproj (or old .alsproj) files open as projects; the package for the mobile is .snxshow.
''', video=[]),

dict(id='plans', title='Planned features', shot=None, body='''
These features arrive in upcoming releases:
- **Automatic transcription from MP3 / MP4 recordings** (phase B): the program separates the instruments and recognises the notes locally on the PC; before that, it asks which instruments and how many parts the recording has.
- **OTS recall via MIDI** based on each model's Data List.
- An extended **registration bank editor** and **protection** (activation code + binding to the instrument's Instrument Info code).
- **iPad / iPhone** install package (after the Apple developer account).
- The manual and video in 18 more languages.
''', video=[]),
]
