; song format
; -----------
; bpm number
; track1 {
;   instrument string
;   notes (list
;     {
;       note number
;       time number
;       duration number
;     }
;     ...
;   )
; }
; track2 ...
; track3 ...
; track4 ...


extensions [
  table ;dicts
  sound
]

globals [
  screen ; "main" - main screen; "editor" - note editor
  cursortime ; \/
  cursornote ; cursor place for "editor"
  song ; see above
  editing ;which track is being edited
  selectMode?
  selectNote
  selectTime ;the note and time that the beginning of the selection is
  clipboard ;copying and pasting
  ; Clipboard format:
  ; -----------------
  ; (list
  ;   {
  ;     dNote number - distance from cursor in notes
  ;     dTime number - distance from cursor in time
  ;     duration number
  ;   }
  ;   ...
  ; )
  playhead ; location of playhead (measured in beats)
  playheadOffset ; measured in beats as well
  playheadCanBeDragged? ; if the song is playing, the playhead cannot be dragged
  playheadBeingDragged? ; whether or not the playhead is being dragged
  ;stop? ; activates when the stop button is pressed
  clicked? ; clicked? = mouse-down? except for the first time it is checked
  filename ; name of the song file
]

to startup ; run every time netlogo starts
  setup
  mainScreen
end
to setup
  ca
  set screen "main"
  set cursortime 0
  set cursornote 60 ; middle C
  set editing "track1"
  set selectMode? false
  set playhead 0
  set playheadOffset 0
  set playheadBeingDragged? false
  set playheadCanBeDragged? true
  set clicked? false
  set stop? false
  set song table:make
  set filename ""
  set clipboard (list table:make)
  table:put (item 0 clipboard) "dNote" 0
  table:put (item 0 clipboard) "dTime" 0
  table:put (item 0 clipboard) "duration" 0
  table:put song "bpm" 120
  foreach ["track1" "track2" "track3" "track4"] [ trackname ->
    table:put song trackName table:make
    table:put (table:get song trackName) "volume" 64
    table:put (table:get song trackName) "instrument" "TRUMPET"
    table:put (table:get song trackname) "notes" []
  ]
  table:put song "drums" table:make
  table:put (table:get song "drums") "volume" 64
  table:put (table:get song "drums") "instrument" "drums"
  table:put (table:get song "drums") "notes" []

  setVariables ; just in case I save the file with odd defaults
end

to drawDividers [startingxcor startingycor]
  ; draw measure dividers
  ; one measure = 4 patches
  set heading 180
  setxy startingxcor startingycor
  pd fd startingycor pu
  setxy xcor + 4 startingycor
  while [xcor <= 59.5 and xcor > startingxcor] [
    pd fd startingycor pu
    setxy xcor + 4 startingycor
  ]
end

to activatePlayer
  if screen = "main" [
    if playheadCanBeDragged? [
      let playheadArmyXcor -1
      let oldPlayheadOffset playheadOffset
      ask one-of turtles with [shape = "playheadarmy"] [
        set playheadArmyXcor xcor
      ]
      ask turtles with [shape = "playhead"] [
        ifelse mouse-down? [
          if
          not playheadBeingDragged? and
          mouse-xcor >= xcor - 0.5 and mouse-xcor <= xcor + 0.5 and
          mouse-ycor >= ycor - 0.5 and mouse-ycor <= ycor + 0.5
          [
            set playheadBeingDragged? true
          ]
        ] [
          set playheadBeingDragged? false
        ]
        if playheadBeingDragged? and (round mouse-xcor) != xcor and (round mouse-xcor) >= 10.5 [
          set xcor (round (mouse-xcor - 0.5)) + 0.5
          set playhead xcor - 10.5 + playheadOffset
          if xcor = 59.5 or xcor = -0.5 [
            set xcor xcor - 1
            set playheadOffset playheadOffset + 1
            wait 0.01
          ]
          if xcor = 10.5 and playheadOffset != 0 [
            set xcor xcor + 1
            set playheadOffset playheadOffset - 1
            wait 0.01
          ]
          ifelse playheadArmyXcor = xcor [
            set playheadArmyXcor -1
          ] [
            set playheadArmyXcor xcor
          ]
        ]
        if playheadBeingDragged? and (round mouse-xcor) < 10.5 and playheadOffset != 0[
          set xcor 11.5
          set playheadArmyXcor 11.5
          set playheadOffset playheadOffset - 1
          wait 0.01
        ]
      ]

      if playheadArmyXcor != -1 [
        ask turtles with [shape = "playheadarmy"] [ ;not only are shape names not case sensitive, they are stored ALWAYS LOWERCASE
          set xcor playheadArmyXcor
        ]
      ]
      if playheadOffset != oldPlayheadOffset [
        mainScreen
      ]
    ]
  ]
end

to mainScreen
  set screen "main"
  cd
  cp
  ct ; all turtles are remade---slower but less code
  cro 1 [
    ; draw dividers for tracks
    setxy 0 55
    set heading 90
    set color white
    repeat 5 [
      pd fd 60 pu
      setxy 0 ycor - 11
    ]
    setxy 10.5 59
    set heading 180
    pd fd 60 pu

    set color gray
    drawDividers (10.5 + (4 - (playheadOffset mod 4))) 55

    die
  ]
  cro 1 [
    setxy (10.5 + playhead - playheadOffset) 55.5
    set shape "playhead"
    set size 1
    set color orange
  ]
  let i 55
  repeat 55 [
    cro 1 [
      setxy (10.5 + playhead - playheadOffset) (55.5 - i)
      set shape "playheadArmy"
      set size 1
      set color orange
    ]
    set i i - 1
  ]
  foreach [1 2 3 4] [ track ->
    showMainScreenNotes (table:get (table:get song (word "track" track)) "notes") track
  ]
  foreach (table:get (table:get song "drums") "notes") [ note ->
    ask patches with [
      pycor = round ((11 * (table:get note "note") / 46)) and
      pxcor >= 11 + (ceiling (((table:get note "time") / 4) - playheadOffset)) and
      pxcor < 11 + (ceiling ((((table:get note "time") + (table:get note "duration")) / 4) - playheadOffset)) and
      pxcor >= 11
    ] [
      set pcolor blue
    ]
  ]
end

; Here come a bunch of functions that wouldn't exist were there no drum track
to showMainScreenNotes [notes track]
  foreach notes [ note ->
    ask patches with [
      pycor = round ((11 * (table:get note "note") / 128) + (11 * (5 - track))) and
      pxcor >= 11 + (ceiling (((table:get note "time") / 4) - playheadOffset)) and
      pxcor < 11 + (ceiling ((((table:get note "time") + (table:get note "duration")) / 4) - playheadOffset)) and
      pxcor >= 11
    ] [
      set pcolor blue
    ]
  ]
end

to setPatchesAlternatingGrays
  ask patches [
    set plabel ""
    ifelse (floor (pycor / 2)) mod 2 = 0 [
      set pcolor [20 20 20]
    ] [
      set pcolor [80 80 80]
    ]
  ]
end

to drawEditorPlayhead [timeoffset]
  if playhead >= (timeoffset * 4) and playhead < ((timeoffset * 4) + 12) [
    setxy (5.5 + (playhead * 4)) 60
    set color orange
    pd fd 60 pu
  ]
end

to drawAllTheNotes [trackName noteoffset timeoffset minNote maxNote minTime maxTime]
  let notes table:get (table:get song trackName) "notes"
  foreach notes [note ->
    let notenumber table:get note "note"
    let notetime table:get note "time"
    let noteduration table:get note "duration"
    if
      notetime < (timeoffset * 16) + 48 and
      notetime >= (timeoffset * 16) and
      notenumber < noteoffset + 30 and
      notenumber >= noteoffset
    [
      let colorToSet blue
      if
        selectMode? and
        notenumber >= minNote and
        notenumber <= maxNote and
        maxTime >= notetime and
        minTime < notetime + noteduration
      [
        set colorToSet green
      ]
      ask patches with [
        floor (pycor / 2) = notenumber - noteoffset and
        pxcor - 6 >= notetime - (timeoffset * 16) and
        pxcor - 6 < notetime - (timeoffset * 16) + (table:get note "duration")
      ] [
        set pcolor colorToSet
      ]
    ]
  ]
end

to drawSelectModeBox [noteoffset timeoffset minNote maxNote minTime maxTime]
  ; this next part is gonna be really expensive but idk let's see
  if selectMode? [
    ask patches [
      let patchNote floor (pycor / 2) + noteoffset
      let patchTime pxcor - 6 + (timeoffset * 16)
      if pcolor != blue and pcolor != green [
        if patchNote >= minNote and patchNote <= maxNote and patchTime <= maxTime and patchTime >= minTime [
          set pcolor [130 130 130]
        ]
      ]
    ]
  ]
end

to drawCursor [noteoffset timeoffset]
  ask patches with [
    floor (pycor / 2) = cursornote - noteoffset and
    pxcor - 6 = cursortime - (timeoffset * 16)
  ] [
    ifelse pcolor = blue [
      set pcolor green
    ] [
      set pcolor white
    ]
  ]
end

to drawMeasureNumbers [timeoffset]
  ask patch 6 59 [ set plabel timeoffset + 1 ]
  ask patch 22 59 [ set plabel timeoffset + 2 ]
  ask patch 38 59 [ set plabel timeoffset + 3 ]
  ask patch 54 59 [ set plabel timeoffset + 4 ]
end

to drumScreen
  set screen "editor"
  set editing "drums"
  ;cp
  ct
  cd
  if cursornote > 46 [set cursornote 46]

  let noteoffset (floor (cursornote / 30)) * 30
  let timeoffset (floor ((floor (cursortime / 16)) / 3)) * 3

  setPatchesAlternatingGrays

  ask patches with [pxcor = 5 and pycor mod 2 = 0] [
    if (pycor / 2) + noteoffset < 47 [
      set plabel (pycor / 2) + 35 + noteoffset
    ]
  ]

  cro 1 [
    set heading 90
    set color white
    setxy 0 1.5
    repeat 47 - noteoffset [
      pd fd 60 pu
      setxy 0 ycor + 2
    ]

    set heading 180
    drawDividers 5.5 60

    drawEditorPlayhead timeoffset

    die
  ]

  ; so that it doesn't have to be recalculated for every patch
  let maxNote max list selectNote cursornote
  let minNote min list selectNote cursornote
  let maxTime max list selectTime cursortime
  let minTime min list selectTime cursortime

  drawAllTheNotes "drums" noteoffset timeoffset minNote maxNote minTime maxTime

  drawSelectModeBox noteoffset timeoffset minNote maxNote minTime maxTime

  drawCursor noteoffset timeoffset

  drawMeasureNumbers timeoffset
end

to editorScreen
  ; It shouldn't be like this but I'm too lazy to change a bunch of stuff
  if editing = "drums" [
    drumScreen
    stop
  ]
  set screen "editor"
  ;cp
  ct
  cd

  let noteoffset (floor (cursornote / 30)) * 30
  ; timeoffset is measured in measures
  let timeoffset (floor ((floor (cursortime / 16)) / 3)) * 3

  setPatchesAlternatingGrays

  cro 1 [
    set heading 90
    set color white
    setxy 0 1.5
    pd fd 60 pu
    setxy 0 3.5
    while [ycor <= 59.5 and ycor > 1.5] [
      pd fd 60 pu
      setxy 0 ycor + 2
    ]

    set heading 180
    drawDividers 5.5 60

    drawEditorPlayhead timeoffset

    die
  ]

  ; note, offset, how many of that note there is below the limit
  let offsets [
    ["C" 12 9]
    ["G" 19 9]
  ]
  if Show_More_Notes [
    set offsets [
      ["C" 12 9]
      ["D" 14 9]
      ["E" 16 9]
      ["F" 17 9]
      ["G" 19 9]
      ["A" 21 8]
      ["B" 23 8]
    ]
  ]
  ; fuck yeah anonymous functions
  foreach offsets [ nameoffset ->
    let note 0
    while [note <= (item 2 nameoffset)] [
      ask patches with [
        pxcor = 5 and
        pycor / 2 = ((12 * note) + (item 1 nameoffset)) - noteoffset
      ] [
        set plabel word (item 0 nameoffset) note
      ]
      set note note + 1
    ]
  ]

  ; so that it doesn't have to be recalculated for every patch
  let maxNote max list selectNote cursornote
  let minNote min list selectNote cursornote
  let maxTime max list selectTime cursortime
  let minTime min list selectTime cursortime

  drawAllTheNotes editing noteoffset timeoffset minNote maxNote minTime maxTime

  drawSelectModeBox noteoffset timeoffset minNote maxNote minTime maxTime

  drawCursor noteoffset timeoffset

  drawMeasureNumbers timeoffset
end

to dropNote
  if getIndexOfNote cursornote cursortime = -1 [
    let newnote table:make
    table:put newnote "note" cursornote
    table:put newnote "time" cursortime
    table:put newnote "duration" 1
    let editingTrack table:get song editing
    table:put editingTrack "notes" lput newnote (table:get editingTrack "notes")
  ]
end

to deleteNote
  ifelse selectMode? [
    let noteIndexes []
    iterateOverSelectedNotes [ noteIndex -> set noteIndexes lput noteIndex noteIndexes ]
    ; must be done backwards to avoid changing future indexes
    foreach (reverse noteIndexes) [ noteIndex ->
      table:put (table:get song editing) "notes" remove-item noteIndex (table:get (table:get song editing) "notes")
    ]
  ] [
    let noteIndex getIndexOfNote cursornote cursortime
    if noteIndex != -1 [
      table:put (table:get song editing) "notes" remove-item noteIndex (table:get (table:get song editing) "notes")
    ]
  ]
end

to copyNote
  ifelse selectMode? [
    set clipboard []
    iterateOverSelectedNotes [ noteIndex ->
      let selectedNote (item noteIndex (table:get (table:get song editing) "notes"))
      let clipboardNote table:make
      table:put clipboardNote "dNote" (table:get selectedNote "note") - cursornote
      table:put clipboardNote "dTime" (table:get selectedNote "time") - cursortime
      table:put clipboardNote "duration" (table:get selectedNote "duration")
      set clipboard lput clipboardNote clipboard
    ]
  ] [
    let noteIndex getIndexOfNote cursornote cursortime
    if noteIndex != -1 [
      let selectedNote (item noteIndex (table:get (table:get song editing) "notes"))
      set clipboard (list table:make)
      table:put (item 0 clipboard) "dNote" 0
      table:put (item 0 clipboard) "dTime" (table:get selectedNote "time") - cursortime
      table:put (item 0 clipboard) "duration" (table:get selectedNote "duration")
    ]
  ]
end

to pasteNote
  foreach clipboard [ copiedNote ->
    let newNoteNumber (cursornote + (table:get copiedNote "dNote"))
    let newNoteTime (cursornote + (table:get copiedNote "dTime"))
    if newNoteNumber <= 127 and newNoteNumber >= 0 and newNoteTime >= 0 [
      let newNote table:make
      table:put newNote "note" cursornote + (table:get copiedNote "dNote")
      table:put newNote "time" cursortime + (table:get copiedNote "dTime")
      table:put newNote "duration" (table:get copiedNote "duration")
      table:put (table:get song editing) "notes" lput newNote (table:get (table:get song editing) "notes")
    ]
  ]
end

to iterateOverSelectedNotes [callback]
  let maxNote max list selectNote cursornote
  let minNote min list selectNote cursornote
  let maxTime max list selectTime cursortime
  let minTime min list selectTime cursortime
  let i 0
  foreach table:get (table:get song editing) "notes" [trynote ->
    let note table:get trynote "note"
    let time table:get trynote "time"
    let duration table:get trynote "duration"
    if
      note >= minNote and
      note <= maxNote and
      maxTime >= time and
      minTime <= time + duration
    [
      (run callback i)
    ]
    set i i + 1
  ]
end

to changeNote [deltaNote deltaTime deltaDuration]
  ifelse selectMode? [
    iterateOverSelectedNotes [ noteIndex -> changeOneNote noteIndex deltaNote deltaTime deltaDuration ]
  ] [
    let noteIndex getIndexOfNote cursornote cursortime
    if noteIndex != -1 [
      changeOneNote noteIndex deltaNote deltaTime deltaDuration
    ]
  ]
  set cursornote cursornote + deltaNote
  set cursortime cursortime + deltaTime
  set selectNote selectNote + deltaNote
  set selectTime selectTime + deltaTime
end

to changeOneNote [noteIndex deltaNote deltaTime deltaDuration]
  let oldnote item noteIndex (table:get (table:get song editing) "notes")
  let oldNoteNumber table:get oldnote "note"
  let oldTime table:get oldnote "time"
  let oldDuration table:get oldnote "duration"
  if
    (deltaNote = 0 or (oldNoteNumber + deltaNote >= 0 and
                       oldNoteNumber + deltaNote <= 127)) and
    (deltaTime = 0 or oldTime + deltaTime >= 0) and
    oldDuration + deltaDuration > 0
  [
    let newnote table:make
    table:put newnote "note" oldNoteNumber + deltaNote
    table:put newnote "time" oldTime + deltaTime
    table:put newnote "duration" oldDuration + deltaDuration
    table:put (table:get song editing) "notes" (replace-item noteIndex (table:get (table:get song editing) "notes") newnote)
  ]
end


to-report getIndexOfNote [note time]
  let i 0
  foreach table:get (table:get song editing) "notes" [trynote ->
    if
      note = table:get trynote "note" and
      time >= table:get trynote "time" and
      time < table:get trynote "time" + table:get trynote "duration"
    [
      report i
    ]
    set i i + 1
  ]
  report -1
end

to test-instrument [instrument]
  sound:play-note-later 0 instrument 60 64 1
end

to play
  set stop? false
  set playheadCanBeDragged? false
  set playheadBeingDragged? false
  let bunchedTogetherNotes []
  foreach ["track1" "track2" "track3" "track4" "drums"] [ track ->
    foreach (table:get (table:get song track) "notes") [ note ->
      ; kinda expensive but if we want the notes to play at the same time without using sound:play-note-later,
      ; we have to sort them by time (so we can stop it and stuff)
      if ((table:get note "time") / 4) >= playhead [
        let newNote table:make
        table:put newNote "note" (table:get note "note")
        table:put newNote "duration" (table:get note "duration")
        table:put newNote "time" (table:get note "time")
        table:put newNote "instrument" (table:get (table:get song track) "instrument")
        table:put newNote "volume" (table:get (table:get song track) "volume")
        set bunchedTogetherNotes lput newNote bunchedTogetherNotes
      ]
    ]
  ]
  set bunchedTogetherNotes sort-by [ [note1 note2] -> table:get note1 "time" < table:get note2 "time" ] bunchedTogetherNotes
  let noteIndex 0 ; have to use this instead of foreach because of a bug I found and submitted
                  ; #1809 on netlogo's github issues page.
  let oldTime (playhead * 4)
  while [noteIndex < length bunchedTogetherNotes] [
    let note (item noteIndex bunchedTogetherNotes)
    if stop? [
      set playheadCanBeDragged? true
      stop
    ]
    let time (table:get note "time")
    if time != oldTime [
      repeat (time - oldTime) [
        wait (1 / 4) * (60 / table:get song "bpm")
        set oldTime time
        if oldTime - (playhead * 4) >= 4 [
          set playhead playhead + 1
          ask turtles with [shape = "playhead" or shape = "playheadarmy"] [
            set xcor xcor + 1
          ]
          if playhead - playheadOffset >= 49 [
            set playheadOffset playheadOffset + 1
            mainScreen
          ]
        ]
      ]
    ]
    ifelse (table:get note "instrument") = "drums" [
      sound:play-drum (item (table:get note "note") sound:drums) (table:get note "volume")
    ] [
      sound:play-note
        (table:get note "instrument")
        (table:get note "note")
        (table:get note "volume")
        (table:get note "duration" / 4) * (60 / table:get song "bpm")
    ]
    set noteIndex noteIndex + 1
  ]
  ;due to the way netlogo works, the playhead will stop at the beginning of the last note instead of its end
  ;furthermore, like some other DAWs, if the playhead is placed in the middle of a note, that note will not play
  ask turtles with [shape = "stop"] [set shape "play"]
  set playheadCanBeDragged? true
end

to loadFile
  set filename user-file
  if filename = false [
    set filename ""
    stop
  ]
  file-open filename
  let loadingSong table:from-list file-read
  let loadedSong table:make
  table:put loadedSong "bpm" (table:get loadingSong "bpm")
  foreach ["track1" "track2" "track3" "track4" "drums"] [ track ->
    let oldTrack (table:get loadingSong track)
    let newTrack table:make
    table:put newTrack "instrument" (item 1 (item 0 oldTrack))
    table:put newTrack "volume" (item 1 (item 1 oldTrack))
    let newTrackNotes []
    foreach (item 1 (item 2 oldTrack)) [ note ->
      set newTrackNotes lput (table:from-list note) newTrackNotes
    ]
    table:put newTrack "notes" newTrackNotes
    table:put loadedSong track newTrack
  ]
  set song loadedSong
  setVariables
  file-close
  mainScreen
end
to saveFile
  if filename = "" [
    set filename user-new-file
    if filename = false [
      set filename ""
      stop
    ]
  ]
  if file-exists? filename [file-delete filename]
  file-open filename
  writeFile
  file-close
end
to saveNew
  set filename user-new-file
  if filename = false [
    set filename ""
    stop
  ]
  if file-exists? filename [file-delete filename]
  file-open filename
  writeFile
  file-close
end

to writeFile
  let songList []
  set songList lput (list "bpm" (table:get song "bpm")) songList
  foreach ["track1" "track2" "track3" "track4" "drums"] [ track ->
    let currTrack (table:get song track)
    let trackToList []
    set trackToList lput (list "instrument" (table:get currTrack "instrument")) trackToList
    set trackToList lput (list "volume" (table:get currTrack "volume")) trackToList
    let notesToList []
    foreach (table:get currTrack "notes") [ note ->
      set notesToList lput (table:to-list note) notesToList
    ]
    set trackToList lput (list "notes" notesToList) trackToList
    set songList lput (list track trackToList) songList
  ]
  file-write songList
end
to setVariables
  set Track1_volume (table:get (table:get song "track1") "volume")
  set Track2_volume (table:get (table:get song "track2") "volume")
  set Track3_volume (table:get (table:get song "track3") "volume")
  set Track4_volume (table:get (table:get song "track4") "volume")
  set Drums_volume (table:get (table:get song "drums") "volume")
  set Track1_instrument (table:get (table:get song "track1") "instrument")
  set Track2_instrument (table:get (table:get song "track2") "instrument")
  set Track3_instrument (table:get (table:get song "track3") "instrument")
  set Track4_instrument (table:get (table:get song "track4") "instrument")
  set Beats_Per_Minute (table:get song "bpm")
end
@#$#@#$#@
GRAPHICS-WINDOW
10
10
738
739
-1
-1
12.0
1
20
1
1
1
0
1
1
1
0
59
0
59
0
0
1
ticks
30.0

TEXTBOX
755
295
905
319
Editor Controls
20
0.0
0

BUTTON
822
326
885
359
⬆
if cursornote < 127 [\n  set cursornote cursornote + 1\n  editorScreen\n]
NIL
1
T
OBSERVER
NIL
K
NIL
NIL
1

BUTTON
750
367
813
400
⬅
if cursortime > 0 [\n  set cursortime cursortime - 1\n  editorScreen\n]
NIL
1
T
OBSERVER
NIL
H
NIL
NIL
1

BUTTON
824
406
887
439
⬇
if cursornote > 0 [\n  set cursornote cursornote - 1\n  editorScreen\n]
NIL
1
T
OBSERVER
NIL
J
NIL
NIL
1

BUTTON
894
369
957
402
➡
set cursortime cursortime + 1\neditorScreen
NIL
1
T
OBSERVER
NIL
L
NIL
NIL
1

BUTTON
754
447
971
481
Put note under cursor
dropNote\neditorScreen
NIL
1
T
OBSERVER
NIL
B
NIL
NIL
1

TEXTBOX
752
495
987
514
* doesn't add one if there is one already
12
0.0
1

BUTTON
865
521
974
555
Extend Note
changeNote 0 0 1\neditorScreen
NIL
1
T
OBSERVER
NIL
W
NIL
NIL
1

BUTTON
750
521
864
555
Shorten Note
changeNote 0 0 -1\neditorScreen
NIL
1
T
OBSERVER
NIL
E
NIL
NIL
1

BUTTON
826
562
908
596
Drag up
if cursornote < 127 [\n  changeNote 1 0 0\n  editorScreen\n]
NIL
1
T
OBSERVER
NIL
D
NIL
NIL
1

BUTTON
750
601
835
635
Drag left
if cursortime > 0 [\n  changeNote 0 -1 0\n  editorScreen\n]
NIL
1
T
OBSERVER
NIL
A
NIL
NIL
1

BUTTON
895
606
990
640
Drag right
changeNote 0 1 0\neditorScreen
NIL
1
T
OBSERVER
NIL
F
NIL
NIL
1

BUTTON
820
645
920
679
Drag down
if cursornote > 0 [\n  changeNote -1 0 0\n  editorScreen\n]
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

CHOOSER
11
744
152
789
Track1_instrument
Track1_instrument
"ACOUSTIC GRAND PIANO" "BRIGHT ACOUSTIC PIANO" "ELECTRIC GRAND PIANO" "HONKY-TONK PIANO" "ELECTRIC PIANO 1" "ELECTRIC PIANO 2" "HARPSICHORD" "CLAVI" "CELESTA" "GLOCKENSPIEL" "MUSIC BOX" "VIBRAPHONE" "MARIMBA" "XYLOPHONE" "TUBULAR BELLS" "DULCIMER" "DRAWBAR ORGAN" "PERCUSSIVE ORGAN" "ROCK ORGAN" "CHURCH ORGAN" "REED ORGAN" "ACCORDION" "HARMONICA" "TANGO ACCORDION" "NYLON STRING GUITAR" "STEEL ACOUSTIC GUITAR" "JAZZ ELECTRIC GUITAR" "CLEAN ELECTRIC GUITAR" "MUTED ELECTRIC GUITAR" "OVERDRIVEN GUITAR" "DISTORTION GUITAR" "GUITAR HARMONICS" "ACOUSTIC BASS" "FINGERED ELECTRIC BASS" "PICKED ELECTRIC BASS" "FRETLESS BASS" "SLAP BASS 1" "SLAP BASS 2" "SYNTH BASS 1" "SYNTH BASS 2" "VIOLIN" "VIOLA" "CELLO" "CONTRABASS" "TREMOLO STRINGS" "PIZZICATO STRINGS" "ORCHESTRAL HARP" "TIMPANI" "STRING ENSEMBLE 1" "STRING ENSEMBLE 2" "SYNTH STRINGS 1" "SYNTH STRINGS 2" "CHOIR AAHS" "VOICE OOHS" "SYNTH VOICE" "ORCHESTRA HIT" "TRUMPET" "TROMBONE" "TUBA" "MUTED TRUMPET" "FRENCH HORN" "BRASS SECTION" "SYNTH BRASS 1" "SYNTH BRASS 2" "SOPRANO SAX" "ALTO SAX" "TENOR SAX" "BARITONE SAX" "OBOE" "ENGLISH HORN" "BASSOON" "CLARINET" "PICCOLO" "FLUTE" "RECORDER" "PAN FLUTE" "BLOWN BOTTLE" "SHAKUHACHI" "WHISTLE" "OCARINA" "SQUARE WAVE" "SAWTOOTH WAVE" "CALLIOPE" "CHIFF" "CHARANG" "VOICE" "FIFTHS" "BASS AND LEAD" "NEW AGE" "WARM" "POLYSYNTH" "CHOIR" "BOWED" "METAL" "HALO" "SWEEP" "RAIN" "SOUNDTRACK" "CRYSTAL" "ATMOSPHERE" "BRIGHTNESS" "GOBLINS" "ECHOES" "SCI-FI" "SITAR" "BANJO" "SHAMISEN" "KOTO" "KALIMBA" "BAG PIPE" "FIDDLE" "SHANAI" "TINKLE BELL" "AGOGO" "STEEL DRUMS" "WOODBLOCK" "TAIKO DRUM" "MELODIC TOM" "SYNTH DRUM" "REVERSE CYMBAL" "GUITAR FRET NOISE" "BREATH NOISE" "SEASHORE" "BIRD TWEET" "TELEPHONE RING" "HELICOPTER" "APPLAUSE" "GUNSHOT"
56

BUTTON
12
793
141
826
Test Insturment
sound:play-note-later 0 Track1_instrument 60 64 1
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
163
745
304
790
Track2_instrument
Track2_instrument
"ACOUSTIC GRAND PIANO" "BRIGHT ACOUSTIC PIANO" "ELECTRIC GRAND PIANO" "HONKY-TONK PIANO" "ELECTRIC PIANO 1" "ELECTRIC PIANO 2" "HARPSICHORD" "CLAVI" "CELESTA" "GLOCKENSPIEL" "MUSIC BOX" "VIBRAPHONE" "MARIMBA" "XYLOPHONE" "TUBULAR BELLS" "DULCIMER" "DRAWBAR ORGAN" "PERCUSSIVE ORGAN" "ROCK ORGAN" "CHURCH ORGAN" "REED ORGAN" "ACCORDION" "HARMONICA" "TANGO ACCORDION" "NYLON STRING GUITAR" "STEEL ACOUSTIC GUITAR" "JAZZ ELECTRIC GUITAR" "CLEAN ELECTRIC GUITAR" "MUTED ELECTRIC GUITAR" "OVERDRIVEN GUITAR" "DISTORTION GUITAR" "GUITAR HARMONICS" "ACOUSTIC BASS" "FINGERED ELECTRIC BASS" "PICKED ELECTRIC BASS" "FRETLESS BASS" "SLAP BASS 1" "SLAP BASS 2" "SYNTH BASS 1" "SYNTH BASS 2" "VIOLIN" "VIOLA" "CELLO" "CONTRABASS" "TREMOLO STRINGS" "PIZZICATO STRINGS" "ORCHESTRAL HARP" "TIMPANI" "STRING ENSEMBLE 1" "STRING ENSEMBLE 2" "SYNTH STRINGS 1" "SYNTH STRINGS 2" "CHOIR AAHS" "VOICE OOHS" "SYNTH VOICE" "ORCHESTRA HIT" "TRUMPET" "TROMBONE" "TUBA" "MUTED TRUMPET" "FRENCH HORN" "BRASS SECTION" "SYNTH BRASS 1" "SYNTH BRASS 2" "SOPRANO SAX" "ALTO SAX" "TENOR SAX" "BARITONE SAX" "OBOE" "ENGLISH HORN" "BASSOON" "CLARINET" "PICCOLO" "FLUTE" "RECORDER" "PAN FLUTE" "BLOWN BOTTLE" "SHAKUHACHI" "WHISTLE" "OCARINA" "SQUARE WAVE" "SAWTOOTH WAVE" "CALLIOPE" "CHIFF" "CHARANG" "VOICE" "FIFTHS" "BASS AND LEAD" "NEW AGE" "WARM" "POLYSYNTH" "CHOIR" "BOWED" "METAL" "HALO" "SWEEP" "RAIN" "SOUNDTRACK" "CRYSTAL" "ATMOSPHERE" "BRIGHTNESS" "GOBLINS" "ECHOES" "SCI-FI" "SITAR" "BANJO" "SHAMISEN" "KOTO" "KALIMBA" "BAG PIPE" "FIDDLE" "SHANAI" "TINKLE BELL" "AGOGO" "STEEL DRUMS" "WOODBLOCK" "TAIKO DRUM" "MELODIC TOM" "SYNTH DRUM" "REVERSE CYMBAL" "GUITAR FRET NOISE" "BREATH NOISE" "SEASHORE" "BIRD TWEET" "TELEPHONE RING" "HELICOPTER" "APPLAUSE" "GUNSHOT"
56

BUTTON
164
794
293
827
Test Instrument
sound:play-note-later 0 Track2_instrument 60 64 1
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
11
833
134
866
Set Instrument
table:put (table:get song \"track1\") \"instrument\" Track1_instrument
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
164
831
287
864
Set Instrument
table:put (table:get song \"track2\") \"instrument\" Track2_instrument
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
321
831
444
864
Set Instrument
table:put (table:get song \"track3\") \"instrument\" Track3_instrument
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
481
829
604
862
Set Instrument
table:put (table:get song \"track4\") \"instrument\" Track4_instrument
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
321
743
462
788
Track3_instrument
Track3_instrument
"ACOUSTIC GRAND PIANO" "BRIGHT ACOUSTIC PIANO" "ELECTRIC GRAND PIANO" "HONKY-TONK PIANO" "ELECTRIC PIANO 1" "ELECTRIC PIANO 2" "HARPSICHORD" "CLAVI" "CELESTA" "GLOCKENSPIEL" "MUSIC BOX" "VIBRAPHONE" "MARIMBA" "XYLOPHONE" "TUBULAR BELLS" "DULCIMER" "DRAWBAR ORGAN" "PERCUSSIVE ORGAN" "ROCK ORGAN" "CHURCH ORGAN" "REED ORGAN" "ACCORDION" "HARMONICA" "TANGO ACCORDION" "NYLON STRING GUITAR" "STEEL ACOUSTIC GUITAR" "JAZZ ELECTRIC GUITAR" "CLEAN ELECTRIC GUITAR" "MUTED ELECTRIC GUITAR" "OVERDRIVEN GUITAR" "DISTORTION GUITAR" "GUITAR HARMONICS" "ACOUSTIC BASS" "FINGERED ELECTRIC BASS" "PICKED ELECTRIC BASS" "FRETLESS BASS" "SLAP BASS 1" "SLAP BASS 2" "SYNTH BASS 1" "SYNTH BASS 2" "VIOLIN" "VIOLA" "CELLO" "CONTRABASS" "TREMOLO STRINGS" "PIZZICATO STRINGS" "ORCHESTRAL HARP" "TIMPANI" "STRING ENSEMBLE 1" "STRING ENSEMBLE 2" "SYNTH STRINGS 1" "SYNTH STRINGS 2" "CHOIR AAHS" "VOICE OOHS" "SYNTH VOICE" "ORCHESTRA HIT" "TRUMPET" "TROMBONE" "TUBA" "MUTED TRUMPET" "FRENCH HORN" "BRASS SECTION" "SYNTH BRASS 1" "SYNTH BRASS 2" "SOPRANO SAX" "ALTO SAX" "TENOR SAX" "BARITONE SAX" "OBOE" "ENGLISH HORN" "BASSOON" "CLARINET" "PICCOLO" "FLUTE" "RECORDER" "PAN FLUTE" "BLOWN BOTTLE" "SHAKUHACHI" "WHISTLE" "OCARINA" "SQUARE WAVE" "SAWTOOTH WAVE" "CALLIOPE" "CHIFF" "CHARANG" "VOICE" "FIFTHS" "BASS AND LEAD" "NEW AGE" "WARM" "POLYSYNTH" "CHOIR" "BOWED" "METAL" "HALO" "SWEEP" "RAIN" "SOUNDTRACK" "CRYSTAL" "ATMOSPHERE" "BRIGHTNESS" "GOBLINS" "ECHOES" "SCI-FI" "SITAR" "BANJO" "SHAMISEN" "KOTO" "KALIMBA" "BAG PIPE" "FIDDLE" "SHANAI" "TINKLE BELL" "AGOGO" "STEEL DRUMS" "WOODBLOCK" "TAIKO DRUM" "MELODIC TOM" "SYNTH DRUM" "REVERSE CYMBAL" "GUITAR FRET NOISE" "BREATH NOISE" "SEASHORE" "BIRD TWEET" "TELEPHONE RING" "HELICOPTER" "APPLAUSE" "GUNSHOT"
56

BUTTON
320
792
449
825
Test Instrument
sound:play-note-later 0 Track3_instrument 60 64 1
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
481
743
622
788
Track4_instrument
Track4_instrument
"ACOUSTIC GRAND PIANO" "BRIGHT ACOUSTIC PIANO" "ELECTRIC GRAND PIANO" "HONKY-TONK PIANO" "ELECTRIC PIANO 1" "ELECTRIC PIANO 2" "HARPSICHORD" "CLAVI" "CELESTA" "GLOCKENSPIEL" "MUSIC BOX" "VIBRAPHONE" "MARIMBA" "XYLOPHONE" "TUBULAR BELLS" "DULCIMER" "DRAWBAR ORGAN" "PERCUSSIVE ORGAN" "ROCK ORGAN" "CHURCH ORGAN" "REED ORGAN" "ACCORDION" "HARMONICA" "TANGO ACCORDION" "NYLON STRING GUITAR" "STEEL ACOUSTIC GUITAR" "JAZZ ELECTRIC GUITAR" "CLEAN ELECTRIC GUITAR" "MUTED ELECTRIC GUITAR" "OVERDRIVEN GUITAR" "DISTORTION GUITAR" "GUITAR HARMONICS" "ACOUSTIC BASS" "FINGERED ELECTRIC BASS" "PICKED ELECTRIC BASS" "FRETLESS BASS" "SLAP BASS 1" "SLAP BASS 2" "SYNTH BASS 1" "SYNTH BASS 2" "VIOLIN" "VIOLA" "CELLO" "CONTRABASS" "TREMOLO STRINGS" "PIZZICATO STRINGS" "ORCHESTRAL HARP" "TIMPANI" "STRING ENSEMBLE 1" "STRING ENSEMBLE 2" "SYNTH STRINGS 1" "SYNTH STRINGS 2" "CHOIR AAHS" "VOICE OOHS" "SYNTH VOICE" "ORCHESTRA HIT" "TRUMPET" "TROMBONE" "TUBA" "MUTED TRUMPET" "FRENCH HORN" "BRASS SECTION" "SYNTH BRASS 1" "SYNTH BRASS 2" "SOPRANO SAX" "ALTO SAX" "TENOR SAX" "BARITONE SAX" "OBOE" "ENGLISH HORN" "BASSOON" "CLARINET" "PICCOLO" "FLUTE" "RECORDER" "PAN FLUTE" "BLOWN BOTTLE" "SHAKUHACHI" "WHISTLE" "OCARINA" "SQUARE WAVE" "SAWTOOTH WAVE" "CALLIOPE" "CHIFF" "CHARANG" "VOICE" "FIFTHS" "BASS AND LEAD" "NEW AGE" "WARM" "POLYSYNTH" "CHOIR" "BOWED" "METAL" "HALO" "SWEEP" "RAIN" "SOUNDTRACK" "CRYSTAL" "ATMOSPHERE" "BRIGHTNESS" "GOBLINS" "ECHOES" "SCI-FI" "SITAR" "BANJO" "SHAMISEN" "KOTO" "KALIMBA" "BAG PIPE" "FIDDLE" "SHANAI" "TINKLE BELL" "AGOGO" "STEEL DRUMS" "WOODBLOCK" "TAIKO DRUM" "MELODIC TOM" "SYNTH DRUM" "REVERSE CYMBAL" "GUITAR FRET NOISE" "BREATH NOISE" "SEASHORE" "BIRD TWEET" "TELEPHONE RING" "HELICOPTER" "APPLAUSE" "GUNSHOT"
56

BUTTON
480
791
609
824
Test Instrument
sound:play-note-later 0 Track4_instrument 60 64 1
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
751
19
856
52
Edit Track 1
set editing \"track1\"\neditorScreen
NIL
1
T
OBSERVER
NIL
1
NIL
NIL
1

BUTTON
751
63
856
96
Edit Track 2
set editing \"track2\"\neditorScreen
NIL
1
T
OBSERVER
NIL
2
NIL
NIL
1

BUTTON
751
103
856
136
Edit Track 3
set editing \"track3\"\neditorScreen
NIL
1
T
OBSERVER
NIL
3
NIL
NIL
1

BUTTON
751
145
856
178
Edit Track 4
set editing \"track4\"\neditorScreen
NIL
1
T
OBSERVER
NIL
4
NIL
NIL
1

SLIDER
865
20
1037
53
Track1_volume
Track1_volume
0
127
64.0
1
1
NIL
HORIZONTAL

BUTTON
1047
19
1150
52
Set Volume
table:put (table:get song \"track1\") \"volume\" Track1_volume
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
865
62
1037
95
Track2_volume
Track2_volume
1
127
64.0
1
1
NIL
HORIZONTAL

SLIDER
864
103
1036
136
Track3_volume
Track3_volume
1
127
64.0
1
1
NIL
HORIZONTAL

SLIDER
864
146
1036
179
Track4_volume
Track4_volume
1
127
64.0
1
1
NIL
HORIZONTAL

BUTTON
1048
58
1151
91
Set Volume
table:put (table:get song \"track2\") \"volume\" Track2_volume
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1047
104
1150
137
Set Volume
table:put (table:get song \"track3\") \"volume\" Track3_volume
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1047
146
1150
179
Set Volume
table:put (table:get song \"track4\") \"volume\" Track4_volume
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
897
284
1067
317
Show_More_Notes
Show_More_Notes
0
1
-1000

BUTTON
1073
286
1151
319
Redraw
editorScreen
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
997
328
1149
361
Toggle Select Mode
set selectMode? not selectMode?\nset selectNote cursornote\nset selectTime cursortime\neditorScreen
NIL
1
T
OBSERVER
NIL
V
NIL
NIL
1

MONITOR
1026
367
1118
412
Select Mode?
selectMode?
17
1
11

BUTTON
1016
446
1135
479
Delete Note(s)
deleteNote\neditorScreen
NIL
1
T
OBSERVER
NIL
X
NIL
NIL
1

BUTTON
1019
482
1132
515
Copy Note(s)
copyNote
NIL
1
T
OBSERVER
NIL
Y
NIL
NIL
1

BUTTON
1017
516
1134
549
Paste Note(s)
pasteNote\neditorScreen
NIL
1
T
OBSERVER
NIL
P
NIL
NIL
1

BUTTON
754
796
1057
829
Activate Mouse Controls (Main Screen Only)
activatePlayer
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
757
720
907
744
Main Controls
20
0.0
1

BUTTON
755
759
922
792
Go to the main screen
mainScreen
NIL
1
T
OBSERVER
NIL
M
NIL
NIL
1

BUTTON
754
837
817
870
Play
play
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
824
839
914
872
stop?
stop?
1
1
-1000

BUTTON
753
182
854
215
Edit Drums
set editing \"drums\"\ndrumScreen
NIL
1
T
OBSERVER
NIL
5
NIL
NIL
1

SLIDER
864
183
1036
216
Drums_volume
Drums_volume
0
127
64.0
1
1
NIL
HORIZONTAL

BUTTON
1045
185
1148
218
Set Volume
table:put (table:get song \"drums\") \"volume\" Drums_volume
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1085
754
1151
787
LOAD
loadFile
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1085
792
1151
825
SAVE
saveFile
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1075
830
1162
863
SAVE AS
saveNew
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
897
702
1205
747
File name
filename
17
1
11

SLIDER
773
236
945
269
Beats_Per_Minute
Beats_Per_Minute
20
360
120.0
1
1
NIL
HORIZONTAL

BUTTON
950
235
1033
268
Set BPM
table:put song \"bpm\" Beats_Per_Minute
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
1084
870
1147
903
NEW
startup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
# NetLogo Digital Audio Workstation

This program is a DAW/Music Sequencer written in NetLogo. 

## Features

1. 4 tracks that can each use different instruments supported by NetLogo.
2. A separate drum track.
3. A versatile system to manipulate notes on a large scale.

## [How to video](https://www.youtube.com/watch?v=XjbuvEDAq7c)

## How to

### About the Screens

When you first open the DAW, it will create an empty song and load the Main Screen. The Main Screen has six different sections, the last five of which are dedicated to visualizing the different tracks. The Screen also has an orange playhead that can be moved to start playing the music at different section. Finally, the Screen has grey vertical dividers that denote measures.

In order to start editing music, press one of the buttons on the top that says "Edit track ..." or "Edit drums." Pressing the button will put you into the Editor Screen, where you can manipulate notes. The Editor Screen has horizontal dividers so that each row corresponds to a single note. It also has vertical dividers, each dividing up beats (not measures, like the Main Screen). Note that while the vertical dividers denote beats, songs made in the DAW can have notes as short as 16th notes in them. At the top, the numbers denote the measures, starting from measure 1. On the left, if the track being edited is a note track, there are labels saying what the notes are. You can flip the switch titled "Show_More_Notes" to only show the Cs and Gs or to show all of the notes in the C major scale. Alternitavely, if the track being edited is the drum track, it will show a number corresponding to the numbers of the drums on the NetLogo Sound Extension's manual. The manual lists 47 drums but for some reason starts from the number 35. The DAW does so too, to make it easier to edit drums.

### Editing Music

Most of the work in making music in the DAW happens in the Editor Screen.

The cursor can be moved with the keys hjkl (a-la vim). The cursor is represented by white patches. It is one note tall and one 16th note wide.

Pressing the button "Put note under cursor" (b) will place a note under the cursor if there isn't one already. The note will be a 16th by default.

If the cursor is over a note, pressing "Extend note" (w) or "Shorten note" (e) will change the length of the note by one sixteenth

If the cursor is over a note, pressing the keys asdf will allow you to move that note along with the cursor.

If the cursor is over a note, pressing "Delete note" (x) will remove the note, and pressing "Copy note" (y) will copy it. Pressing "Paste note" (p) in an area without a note will paste the note back

### Visual mode

Sometimes musicians will want to edit a number of notes at a time, whether they want to move them or to copy them. For that, we have Select Mode. Press "Toggle Select Mode" (v) to turn it on or off.

In select mode, use the normal cursor moving keys to make a selected block. The selected area will be represented by a light gray. Any notes that the selected block touches will be selected in their entirety.

From there, using asdf will move the whole selection, pressing y will copy all of the notes, and so on.

### Playing Music

In order to play music, press "Go to the main screen" (m) to go to the main screen. From there, you should also turn on mouse controls by activating the button below the main screen button. You can click the playhead (the little orange square at the top) and drag it to the left and to the right to change where the playing starts. If you drag it past the right edge of the screen, it will scroll the main screen forwards. Similarly, if the main screen is scrolled past the beginning of the song, dragging the playhead behind the first measure will scroll the main screen back.

Finally, press the "Play" button to play the music. Because of the way NetLogo works, there is no stop button, but rather a "stop?" switch. Switch it on to stop the music. Make sure to switch it off before playing it again.

### Instruments and Volumes

To change the instruments of each track, or the volume of the track, move the sliders (on the right) or choose the instruments (under the screen) corresponding to the track whose properties you want to change. Make sure that you press "Set Volume" or "Set Instrument" to set the instruments before you play or save/load the music. You can also press "Test Instrument" to test any chosen instrument.

**NETLOGO NOTE**: While there are technically 47 supported drums and 127 supported sounds, in NetLogo, a lot of the instruments and drums produce the same sound.

### Saving and Loading

Pressing the "SAVE" button will save the song as a file to whatever file is indicated in the "filename" variable (which is shown above the buttons). If there is no filename there, the command will prompt you to make a new file. "SAVE AS" is the same as save but will prompt you to make a new file every time. "LOAD" will ask you for a file to load into the program.

## Drum names

```
35. Acoustic Bass Drum             59. Ride Cymbal 2
36. Bass Drum 1                    60. Hi Bongo
37. Side Stick                     61. Low Bongo
38. Acoustic Snare                 62. Mute Hi Conga
39. Hand Clap                      63. Open Hi Conga
40. Electric Snare                 64. Low Conga
41. Low Floor Tom                  65. Hi Timbale
42. Closed Hi Hat                  66. Low Timbale
43. Hi Floor Tom                   67. Hi Agogo
44. Pedal Hi Hat                   68. Low Agogo
45. Low Tom                        69. Cabasa
47. Open Hi Hat                    70. Maracas
47. Low Mid Tom                    71. Short Whistle
48. Hi Mid Tom                     72. Long Whistle
49. Crash Cymbal 1                 73. Short Guiro
50. Hi Tom                         74. Long Guiro
51. Ride Cymbal 1                  75. Claves
52. Chinese Cymbal                 76. Hi Wood Block
53. Ride Bell                      77. Low Wood Block
54. Tambourine                     78. Mute Cuica
55. Splash Cymbal                  79. Open Cuica
56. Cowbell                        80. Mute Triangle
57. Crash Cymbal 2                 81. Open Triangle
58. Vibraslap
```
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

play
false
0
Rectangle -7500403 true true 0 0 300 300
Polygon -1 true false 60 45 60 255 255 150

playhead
false
0
Rectangle -7500403 true true 0 0 300 300

playheadarmy
false
0
Line -7500403 true 150 0 150 330

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

stop
false
0
Rectangle -7500403 true true 0 0 300 300
Rectangle -1 true false 45 45 255 255

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

to-beginning
true
0
Polygon -1 true false 165 90 165 210 75 150
Rectangle -1 true false 45 90 75 210
Polygon -1 true false 255 90 255 210 165 150

tracksign
true
0
Polygon -1 true false 0 135 45 135 45 150 30 150 30 195 15 195 15 150 0 150 0 135
Polygon -1 true false 60 135 60 195 75 195 75 165 90 195 105 180 90 165 105 150 90 135
Polygon -16777216 true false 71 142 72 155 83 155 88 149 85 143
Polygon -1 true false 120 195 135 195 135 165 150 165 150 195 165 195 165 135 120 135
Polygon -16777216 true false 134 142 135 157 148 157 148 142
Polygon -1 true false 195 135 180 150 180 180 195 195 210 195 225 180 195 180 195 150 225 150 210 135
Polygon -1 true false 240 135 240 195 255 195 255 180 285 195 285 180 255 165 285 150 285 135 255 150 255 135

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
