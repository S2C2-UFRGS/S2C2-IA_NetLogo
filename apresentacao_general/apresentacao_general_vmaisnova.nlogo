extensions [gis matrix]

breed [tanks tank]
breed [ARPs ARP]
breed [enemies enemy]

globals
[
  p-valids   ; Valid Patches for moving not wall)
  Start      ; Starting patch
  Final-Cost ; The final cost of the path given by A*
  Goal
  begun

  path
  last-positions
  stopping

  estradas-dataset
  agua-dataset
  relevo-dataset
  rel_trans-dataset

  spotted
]

tanks-own[
  velocity
  vehicle-position
]


patches-own
[
  father     ; Previous patch in this partial path
  Cost-path  ; Stores the cost of the path to the current patch
  visited?   ; has the path been visited previously? That is,
             ; at least one path has been calculated going through this patch
  active?    ; is the patch active? That is, we have reached it, but
             ; we must consider it because its children have not been explored
]



to setup-map
  clear-all
  reset-ticks


  gis:load-coordinate-system "./data/gis_map/estradas.prj"

  set estradas-dataset gis:load-dataset "./data/gis_map/estradas.shp"
  set agua-dataset gis:load-dataset "./data/gis_map/corpos_dagua.shp"
  set relevo-dataset gis:load-dataset "./data/gis_map/relevos.shp"
  set rel_trans-dataset gis:load-dataset "./data/gis_map/rel_trans.shp"
  gis:set-world-envelope gis:envelope-of estradas-dataset


  gis:set-drawing-color black
  gis:draw estradas-dataset 10

  gis:set-drawing-color cyan
  gis:draw agua-dataset 1

  gis:set-drawing-color brown
  gis:draw relevo-dataset 1

  gis:set-drawing-color grey
  gis:draw rel_trans-dataset 1

  import-drawing "./data/cenario.png"

  ask patches[
    set pcolor green
  ]
  ask patches gis:intersecting agua-dataset
  [ set pcolor cyan ]

  ask patches gis:intersecting relevo-dataset
  [ set pcolor brown]

  ask patches gis:intersecting rel_trans-dataset
  [ set pcolor grey]



  ; Initial values of patches for A*
  ask patches
  [
    set father nobody
    set Cost-path 0
    set visited? false
    set active? false
  ]
  set p-valids patches with [pcolor = green or pcolor = grey]


  set path (list 0 0)
  set last-positions (list (list 0 0 0) (list 0 0 0))

  set spotted 0
  set stopping 0

  ;; create ARP
  create-ARPs 1
  [
    set color blue
    set shape "calunga_arp"
    set size 6
    setxy 60 50
    set heading 90
  ]


  ;; create allies
  let ally-y 60
  let veh-position 0
  repeat 2
  [
    let ally-x 30
    create-tanks 3
    [
      set color blue
      set size 6
      set shape "calunga_tank_ally"
      setxy ally-x ally-y
      set velocity 1
      set vehicle-position veh-position

      set veh-position veh-position + 1
      set ally-x ally-x + 5
    ]

    set ally-y ally-y - 50
  ]



  ;; create enemies
  let enemy-x 110
  create-enemies 2 [
    set color red
    set size 6
    set shape "calunga_tank_enemy"
    setxy enemy-x 70
    set heading 180

    set enemy-x enemy-x + 5
  ]

  create-turtles 1[
    set shape "dot"
    set color red
    set label-color black
    set label "Campo de Instru????o de Buti??"
    setxy 32 34
  ]

  create-turtles 1[
  set shape "dot"
  set color red
  set hidden? false
  set label-color black
  set label "Cap??o Alto"
  setxy 70 40
  ]


end


to-report Total-expected-cost [#Goal]
  report Cost-path + Heuristic #Goal
end

to-report Heuristic [#Goal]
  report distance #Goal
end

; A* algorithm. Inputs:
;   - #Start     : starting point of the search.
;   - #Goal      : the goal to reach.
;   - #valid-map : set of agents (patches) valid to visit.
; Returns:
;   - If there is a path : list of the agents of the path.
;   - Otherwise          : false

to-report A* [#Start #Goal #valid-map]
  ; clear all the information in the agents
  ask #valid-map with [visited?]
  [
    set father nobody
    set Cost-path 0
    set visited? false
    set active? false
  ]
  ; Active the staring point to begin the searching loop
  ask #Start
  [
    set father self
    set visited? true
    set active? true
  ]
  ; exists? indicates if in some instant of the search there are no options to
  ; continue. In this case, there is no path connecting #Start and #Goal
  let exists? true
  ; The searching loop is executed while we don't reach the #Goal and we think
  ; a path exists
  while [not [visited?] of #Goal and exists?]
  [
    ; We only work on the valid pacthes that are active
    let options #valid-map with [active?]
    ; If any
    ifelse any? options
    [
      ; Take one of the active patches with minimal expected cost
      ask min-one-of options [Total-expected-cost #Goal]
      [
        ; Store its real cost (to reach it) to compute the real cost
        ; of its children
        let Cost-path-father Cost-path
        ; and deactivate it, because its children will be computed right now
        set active? false
        ; Compute its valid neighbors
        let valid-neighbors neighbors with [member? self #valid-map]
        ask valid-neighbors
        [
          ; There are 2 types of valid neighbors:
          ;   - Those that have never been visited (therefore, the
          ;       path we are building is the best for them right now)
          ;   - Those that have been visited previously (therefore we
          ;       must check if the path we are building is better or not,
          ;       by comparing its expected length with the one stored in
          ;       the patch)
          ; One trick to work with both type uniformly is to give for the
          ; first case an upper bound big enough to be sure that the new path
          ; will always be smaller.
          let t ifelse-value visited? [ Total-expected-cost #Goal] [2 ^ 20]
          ; If this temporal cost is worse than the new one, we substitute the
          ; information in the patch to store the new one (with the neighbors
          ; of the first case, it will be always the case)
          if t > (Cost-path-father + distance myself + Heuristic #Goal)
          [
            ; The current patch becomes the father of its neighbor in the new path
            set father myself
            set visited? true
            set active? true
            ; and store the real cost in the neighbor from the real cost of its father
            set Cost-path Cost-path-father + distance father
            set Final-Cost precision Cost-path 3
          ]
        ]
      ]
    ]
    ; If there are no more options, there is no path between #Start and #Goal
    [
      set exists? false
    ]
  ]
  ; After the searching loop, if there exists a path
  ifelse exists?
  [
    ; We extract the list of patches in the path, form #Start to #Goal
    ; by jumping back from #Goal to #Start by using the fathers of every patch
    let current #Goal
    set Final-Cost (precision [Cost-path] of #Goal 3)
    let rep (list current)
    While [current != #Start]
    [
      set current [father] of current
      set rep fput current rep
    ]
    report rep
  ]
  [
    ; Otherwise, there is no path, and we return False
    report false
  ]
end

to go
  tick

  create-A*

  move-ARP

  move-enemy

  move-tanks

end

to create-A*
  if ticks mod 20 = 0 and spotted = 1 [
    ;; ask scout tanks
    ask tanks with [vehicle-position mod 3 = 2]
    [
      let closest-enemy min-one-of enemies [distance myself]

      ifelse distance closest-enemy < 5
      [ set stopping 1 ]
      [
        ;; if it is in the upper or lower formation
        ifelse vehicle-position < 3
        [
          set path replace-item 0 path (A* patch-here closest-enemy p-valids)
        ]
        [
          set path replace-item 1 path (A* patch-here closest-enemy p-valids)
        ]
      ]

    ]

  ]
end


to move-tanks
  if path != (list 0 0) and path != false and ticks mod 20 != 0
  [
    get-last-positions

    ask tanks
    [

      ;; set velocity according to the ground
      ifelse color-patchhere who = green[ set velocity 0.2 ][set velocity 0.08]

      ;; select right platoon
      ifelse vehicle-position < 3
      [
        if (item 0 path) != []
        [ move-A* 0 ]
      ]
      [
        if (item 1 path) != []
        [ move-A* 1 ]
      ]
    ]
  ]
end

to move-enemy
  ask enemies
  [
    if stopping = 0
    [ fd 0.05 ]
  ]
end

to move-ARP
  ask ARPs
  [
    let closest-enemy min-one-of enemies [distance myself]

    if distance closest-enemy < ARP-vision
    [
      set spotted 1
      face closest-enemy
    ]

    if distance closest-enemy > 5
    [ fd 0.5 ]

  ]

end

to move-A* [ index ]

  ifelse vehicle-position mod 3 = 2
  [
    ;; the leader will follow the A* path

    face first (item index path)

    ifelse distance first (item index path) < velocity
    [
      fd distance first (item index path)
      set path replace-item index path (remove-item 0 (item index path))
    ]
    [ fd velocity ]
  ]
  [
    ;; the others will follow the leader steps
    let positions item (vehicle-position mod 3) (item index last-positions)
    let new-x item 0 positions
    let new-y item 1 positions

    facexy new-x new-y

    fd (distancexy new-x new-y - 5)

  ]


end

to get-last-positions
  ask tanks
  [
    let platoon-index 0
    if vehicle-position > 2
      [set platoon-index 1]

    ;; refreshing the positions list
    if vehicle-position mod 3 != 0
    [
      set last-positions replace-item platoon-index last-positions ( replace-item ((vehicle-position mod 3) - 1) (item platoon-index last-positions) (list xcor ycor) )
    ]
  ]

end

to-report color-patchhere [tank-who] ;report the patch that the agent is sitting at
  let col 0
  ask tank tank-who [
    ask patch-here[
      set col pcolor
    ]
  ]
  report col
end
@#$#@#$#@
GRAPHICS-WINDOW
197
17
2168
1014
-1
-1
13.0
1
10
1
1
1
0
0
0
1
0
150
0
75
0
0
1
ticks
30.0

BUTTON
65
120
155
153
NIL
setup-map\n
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
74
215
145
256
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

SLIDER
10
297
184
330
ARP-vision
ARP-vision
0
100
29.0
1
1
NIL
HORIZONTAL

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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

calunga_arp
false
0
Polygon -7500403 true true 240 270 240 225 225 150 180 90 150 75 150 300 240 300 240 270
Polygon -7500403 true true 60 270 60 225 75 150 120 90 150 75 150 300 60 300 60 270
Polygon -7500403 true true 90 165 90 165 90 165
Polygon -16777216 true false 210 180 210 195 150 225 150 210 210 180
Polygon -16777216 true false 90 180 90 195 150 225 150 210 90 180
Polygon -16777216 true false 141 105 141 149 149 148 149 126 156 125 160 124 162 118 161 111 157 106 153 105 150 105 146 105
Polygon -16777216 true false 146 111
Polygon -7500403 true true 156 115
Polygon -7500403 true true 147 111 147 121 153 121 156 117 155 111 151 110

calunga_tank_ally
false
0
Rectangle -7500403 true true 45 90 255 225
Line -16777216 false 45 225 255 90
Circle -16777216 true false 90 45 30
Circle -16777216 true false 135 45 30
Circle -16777216 true false 180 45 30
Line -16777216 false 90 120 210 120
Line -16777216 false 90 120 75 135
Line -16777216 false 75 135 75 165
Line -16777216 false 75 165 75 180
Line -16777216 false 75 180 90 195
Line -16777216 false 90 195 210 195
Line -16777216 false 225 165 225 180
Line -16777216 false 225 135 225 165
Line -16777216 false 210 120 225 135
Line -16777216 false 210 195 225 180

calunga_tank_enemy
false
0
Polygon -7500403 true true 150 45 45 150 150 255 255 150 150 45
Line -16777216 false 195 180 105 180
Line -16777216 false 105 120 195 120
Line -16777216 false 195 180 210 165
Line -16777216 false 210 135 210 165
Line -16777216 false 195 120 210 135
Line -16777216 false 90 135 90 165
Line -16777216 false 105 180 90 165
Line -16777216 false 105 120 90 135
Line -16777216 false 98 204 204 98
Circle -16777216 true false 93 13 24
Circle -16777216 true false 136 12 24
Circle -16777216 true false 174 12 24

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

exclamation
false
0
Circle -7500403 true true 103 198 95
Polygon -7500403 true true 135 180 165 180 210 30 180 0 120 0 90 30

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

tank
true
0
Rectangle -7500403 true true 144 0 159 105
Rectangle -6459832 true false 195 45 255 255
Rectangle -16777216 false false 195 45 255 255
Rectangle -6459832 true false 45 45 105 255
Rectangle -16777216 false false 45 45 105 255
Line -16777216 false 45 75 255 75
Line -16777216 false 45 105 255 105
Line -16777216 false 45 60 255 60
Line -16777216 false 45 240 255 240
Line -16777216 false 45 225 255 225
Line -16777216 false 45 195 255 195
Line -16777216 false 45 150 255 150
Polygon -7500403 true true 90 60 60 90 60 240 120 255 180 255 240 240 240 90 210 60
Rectangle -16777216 false false 135 105 165 120
Polygon -16777216 false false 135 120 105 135 101 181 120 225 149 234 180 225 199 182 195 135 165 120
Polygon -16777216 false false 240 90 210 60 211 246 240 240
Polygon -16777216 false false 60 90 90 60 89 246 60 240
Polygon -16777216 false false 89 247 116 254 183 255 211 246 211 237 89 236
Rectangle -16777216 false false 90 60 210 90
Rectangle -16777216 false false 143 0 158 105

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
NetLogo 6.2.2
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
