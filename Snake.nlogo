breed [clients client]
globals [score currhsn highscore highscorename worldmap colors colornames]
patches-own [ttl]

clients-own [
  user-id
  turn ;is it their turn
  went ;how many times they've gone
  turnqueue
  turned
  ownscore
  died
  boosting
]

;runs once at beginning
to startup
  hubnet-reset
  set highscore 0
end

to clear-wents
  ask clients [
    set went 0
    hubnet-send user-id "went" went
  ]
end

to loadmap
  ifelse file-exists? filename [
    file-open filename
    set worldmap file-read
    file-close
  ] [
    show "File does not exist!"
    set worldmap []
    let add []
    repeat world-width [
      set add lput 0 add
    ]
    repeat world-height [
      set worldmap lput add worldmap
    ]
  ]
end

to drawmap
  ask patches [
    ifelse pycor - min-pycor >= length worldmap or pxcor -  min-pxcor >= length (item (pycor - min-pycor) worldmap) [
      set pcolor black
    ] [
      ifelse item (pxcor - min-pxcor) (item (pycor - min-pycor) worldmap) = 1 [
        set pcolor brown
      ] [
        set pcolor black
      ]
    ]
  ]
end

to client-setup [colorname]
  hubnet-send user-id "turn" turn
  hubnet-send user-id "went" went
  hubnet-send user-id "color" colorname
  hubnet-send user-id "score" ownscore
end
to broadcast-setup
  hubnet-broadcast "You were killed by" ""
  hubnet-broadcast "Current Highest Scorer" ""
  hubnet-broadcast "Current Highest Score" score
  ifelse count clients with [turn] > 1 [
    hubnet-broadcast "Whose turn is it?" ""
  ] [
    let goer ""
    ask clients with [turn] [set goer user-id]
    hubnet-broadcast "Whose turn is it?" goer
  ]
end

to setup-turn
  cp
  cd
  loadmap
  drawmap
  ask clients [
    hubnet-reset-perspective user-id
    set turn false
  ]
  ask min-one-of clients [went] [
    set turn true
  ]
  ask clients [
    client-setup "red"
  ]

  ask clients with [turn] [
    setxy 0 0
    set hidden? true
    set pcolor red
    set ttl 1
    set turned false
    set turnqueue []
    set heading 0
    set color red
    set died false
    set ownscore 1
    set boosting false
  ]
  ask n-of food-per-snake patches with [pcolor = black] [set pcolor green]
  set score 1
  broadcast-setup
end

to setup-comp
  cp
  cd
  loadmap
  drawmap
  ; hopefully that's enough
  set colors [15 25 45 75 85 95 105 115 125 135 9.9]
  set colornames ["red" "orange" "yellow" "turquoise" "cyan" "sky" "blue" "violet" "magenta" "pink" "white"]
  ask clients [
    set boosting false

    hubnet-reset-perspective user-id
    set turn true
    set ownscore 1

    let colorindex random length colors
    set color item colorindex colors
    client-setup item colorindex colornames
    set colornames remove-item colorindex colornames
    set colors remove-item colorindex colors
    setxy random world-width + min-pxcor random world-width + min-pycor

    ; this is really slow but idk a better way
    while [pcolor != black] [setxy random world-width + min-pxcor random world-width + min-pycor]

    set pcolor color
    set ttl 1
    ask n-of food-per-snake patches with [pcolor = black] [set pcolor green]
    set died false
    set turnqueue []
    set heading 0
    let myid user-id
    if not comp-worldview [
      hubnet-send-follow user-id one-of clients with [user-id = myid] comp-viewradius
    ]
    hubnet-send user-id "You were killed by" ""
  ]
  set score 1
  broadcast-setup
end

to go
  let going true
  ask patches with [ttl > 0] [
    set ttl ttl - 1
    if ttl = 0 [set pcolor black]
  ]
  ask clients with [turn] [
    if label-players [
      set plabel ""
    ]
    set going gomain
    if boosting [
      let mycolor color
      ask min-one-of patches with [pcolor = mycolor] [ttl] [
        set pcolor green
        set ttl 0
      ]
      ask patches with [ttl > 0 and pcolor = mycolor] [
        set ttl ttl - 1
        if ttl = 0 [set pcolor black]
      ]
      set ownscore ownscore - 1
      updatescore
      set going gomain
    ]
    if label-players [
      set plabel-color green
      set plabel user-id
    ]
  ]
  if not going [
    if score > highscore [
      set highscore score
      hubnet-broadcast "highscore" highscore
      ask clients with [turn and died] [set highscorename user-id]
      hubnet-broadcast "highscorename" highscorename
    ]
    ask clients with [turn and died] [
      set turn false
      set died false
      set went went + 1
    ]
    ; if there's only one player this is skipped
    ifelse count clients with [turn] > 1 [
      ask max-one-of clients with [turn] [ownscore] [
        set score ownscore
        set currhsn user-id
        hubnet-broadcast "Current Highest Scorer" currhsn
        hubnet-broadcast "Current Highest Score" score
      ]
    ] [
      ask min-one-of clients [went] [
        set turn true ;won't do anything with comp enabled
      ]
    ]
    if count clients with [turn] <= 1 [stop]
  ]
  wait 1 / speed
end

to updatescore
  if ownscore > score [
    set score ownscore
    set currhsn user-id
  ]
  if ownscore < score [
    ask max-one-of clients [ownscore] [
      set score ownscore
      set currhsn user-id
    ]
  ]
  if ownscore < 2 [
    set boosting false
  ]
  hubnet-broadcast "Current Highest Scorer" currhsn
  hubnet-broadcast "Current Highest Score" score
  hubnet-send user-id "score" ownscore
end

to-report gomain
  fd 1
  set turned false
  ifelse pcolor != black and pcolor != green [
    set died true
    let killer ""
    ask clients with [color = pcolor] [set killer user-id]
    hubnet-send user-id "You were killed by" killer
    report false
  ] [
    if pcolor = green [
      set ownscore ownscore + 1
      updatescore
      if count patches with [pcolor = green] <= count clients * food-per-snake [
        ask one-of patches with [pcolor = black] [
          set pcolor green
        ]
      ]
    ]
    set ttl ownscore
    set pcolor color
  ]
  if (length turnqueue) != 0 [
    set heading first turnqueue
      set turnqueue remove-item 0 turnqueue
  ]
  report true
end

to listen-clients
  while [hubnet-message-waiting?]
  [
    hubnet-fetch-message
    ifelse hubnet-enter-message?
    [create-new-student]
    [
      ifelse hubnet-exit-message?
      [remove-student]
      [
        execute-command hubnet-message-tag
      ]
    ]
  ]
end

to create-new-student
  create-clients 1 [
    set user-id hubnet-message-source
    set turn false
    set went 0
    set turnqueue []
    set turned false
    set ownscore 1
    set died false
    set hidden? true
    set boosting false
    hubnet-send user-id "highscorename" highscorename
    hubnet-send user-id "highscore" highscore
    client-setup "none"
    broadcast-setup
  ]
end
to remove-student
  ask clients with [user-id = hubnet-message-source] [die]
end
to execute-command [command]
  ifelse command = "Toggle Boost" [
    ask clients with [turn and user-id = hubnet-message-source] [
      set boosting not boosting
      if ownscore < 2 [
        set boosting false
      ]
    ]
  ] [
    ask clients with [turn and user-id = hubnet-message-source] [
      let chheading heading
      if command = "up" and chheading != 180 [
        set chheading 0
      ]
      if command = "down" and chheading != 0 [
        set chheading 180
      ]
      if command = "left" and chheading != 90 [
        set chheading 270
      ]
      if command = "right" and chheading != 270 [
        set chheading 90
      ]
      ifelse not turned [
        ifelse (length turnqueue) = 0 [
          set heading chheading
        ] [
          set heading first turnqueue
          set turnqueue remove-item 0 turnqueue
        ]
        set turned true
      ] [
        set turnqueue lput chheading turnqueue
      ]
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
210
10
626
427
-1
-1
8.0
1
10
1
1
1
0
1
1
1
-25
25
-25
25
0
0
1
ticks
30.0

BUTTON
16
10
111
43
NIL
setup-turn
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
18
313
127
346
NIL
listen-clients
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
16
222
188
255
speed
speed
1
50
50.0
0.1
1
NIL
HORIZONTAL

BUTTON
17
361
80
394
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
582
520
652
565
NIL
highscore
17
1
11

MONITOR
583
467
685
512
NIL
highscorename
17
1
11

INPUTBOX
15
456
387
516
filename
NOPE (/home/victor/notes/CSHW/SNAKEWORLDMAP.txt)
1
0
String

BUTTON
16
412
104
445
NIL
loadmap
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
113
412
205
445
NIL
drawmap
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
17
57
122
90
NIL
setup-comp
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
434
520
575
565
Current Highest Score
score
17
1
11

BUTTON
14
184
116
217
NIL
clear-wents
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
18
102
175
135
comp-worldview
comp-worldview
1
1
-1000

SLIDER
15
145
187
178
comp-viewradius
comp-viewradius
3
10
8.0
1
1
NIL
HORIZONTAL

SLIDER
13
262
185
295
food-per-snake
food-per-snake
1
10
10.0
1
1
NIL
HORIZONTAL

MONITOR
429
467
575
512
Current Highest Socrer
currhsn
17
1
11

SWITCH
241
531
375
564
label-players
label-players
0
1
-1000

@#$#@#$#@
# Snake

This is a multiplayer game of snake that utilizes HubNet, a NetLogo feature that allows people to interact with NetLogo models.

## Features

  1. Multiplayer!
  2. A competitive and traditional game mode, with an extensive set of customizable presets.
    1. In the traditional game, players take turns playing snake to see who gets the high score.
    2. In the competitive game, players play at the same time in a free-for-all, fighting in a last man standing snake game.
  3. A better turning mechanism that buffers turns to prevent snakes running into themselves while turning twice before moving.
  4. The ability to load maps into the game.
  5. Players can boost themselves forward to help them kill an enemy or get out of a tricky situation, but at the cost of their score.

## Usage

  1. The HubNet monitor should automatically start. If it does not, type `hubnet-reset` in the console. Use the hubnet monitor to start the activity.
  2. Connect users to the model by having them open up their HubNet client applications (bundled with NetLogo) and connecting to the server (if the server doesn't show up in the list, they should enter the IP shown in the HubNet monitor)
  3. Press the `listen-clients` button, and never depress it. This ensures that the server receives all commands from clients and allows new clients to connect.
  4. If you want, put in the filename of a file that contains a worldmap (see example below). There's no need to press loadmap and drawmap; these functions will be called automatically every time you setup a new game.
  5. Press setup-turn or setup-comp depending on which game mode you want
  6. Press go. This button should automatically depress when the game ends.

### Notes:

  * In the competitive mode, switching off comp-worldview before setup will make each client see only a part of the view around their turtle. This can also _reduce lag_.
  * Clients that enter a room in the middle of a game will have to wait until the game ends to play.
  * The clear-wents button can be used when moving to turns mode from competitive mode to even out the field. Without it, every winner of a competitve mode game gets an extra turn.

## Example world map

The following is an example world map for a world of 33x33 spaces. Note that the default is actually 51x51 spaces. You can change the world size by editing the world. Don't worry about the list in your file being to small; any patches that are outside of your map are automatically turned to black.

    [
      [1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1]
      [1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1]
      [1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1]
    ]

## Credits and References

Created by Victor Veytsman.
Thanks to Mr. Brooks for his wonderful instruction and the developers of NetLogo for their great software and documentation.
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

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

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
BUTTON
83
10
146
43
up
NIL
NIL
1
T
OBSERVER
NIL
W

BUTTON
0
52
63
85
left
NIL
NIL
1
T
OBSERVER
NIL
A

BUTTON
161
53
224
86
right
NIL
NIL
1
T
OBSERVER
NIL
D

BUTTON
81
53
147
86
down
NIL
NIL
1
T
OBSERVER
NIL
S

MONITOR
86
97
143
146
turn
NIL
3
1

MONITOR
161
97
218
146
went
NIL
3
1

MONITOR
168
387
242
436
highscore
NIL
3
1

MONITOR
167
330
277
379
highscorename
NIL
3
1

VIEW
301
10
730
439
0
0
0
1
1
1
1
1
0
1
1
1
-25
25
-25
25

MONITOR
4
156
61
205
score
NIL
3
1

MONITOR
5
96
62
145
color
NIL
3
1

MONITOR
160
152
284
201
You were killed by
NIL
3
1

MONITOR
14
387
163
436
Current Highest Score
NIL
3
1

MONITOR
9
329
163
378
Current Highest Scorer
NIL
3
1

MONITOR
72
246
189
295
Whose turn is it?
NIL
3
1

BUTTON
162
10
275
43
Toggle Boost
NIL
NIL
1
T
OBSERVER
NIL
E

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
