#!/usr/bin/env coffee

{log,error,inspect} = require 'util'
Potter = require 'potter'
deck = require 'deck'

fitness = require './fitness'

name = "automata1"

model = new Potter size: [ 1e3, 1e3, 1e3 ]

center = [ 200, 200, 200 ]



###

  TODO
  
  - data stream
  - physical simulation step
  - WebGL viewer

###


# in the future, we should try to increase the neighborhood size
nMatrix = [
  [0,+1,+1] # 0
  [+1,+1,+1] # 1

  [-1,0,+1] # 2
  [0,0,+1] # 3
  [+1,0,+1] # 4

  [-1,0,+1] # 5
  [0,-1,+1] # 6
  [+1,-1,+1] # 7

  [-1,+1,0] # 8
  [0,+1,0] # 9
  [+1,+1,0] # 10

  [-1,0,0] # 11
  [+1,0,0] # 12

  [-1,0,0] # 13
  [0,-1,0] # 14
  [+1,-1,0] # 15

  [-1,+1,-1] # 16
  [0,+1,-1] # 17
  [+1,+1,-1] # 18

  [-1,0,-1] # 19
  [0,0,-1]  # 20
  [+1,0,-1] # 21

  [-1,-1,-1] # 22
  [0,-1,-1] # 23
  [+1,-1,-1] # 24
]

# pick up a not-so-random number in [-1, 0, 1]
# you can unbalance the randomness using the first parameter
# eg: randNorm(-0.5) means more chances to pick -1
# randNorm(1.0) means no chance to pick -1, and lot of chance to pick 1
randNorm = (t=0.0,r=1e3) -> (Number) deck.pick '-1': r - r * t, '0': r, '1': r + r * t

getNeighborsFull = (p) ->
  [x,y,z] = p

  # mutable part
  neighbors = {}
  for n in nMatrix
    pos = [x+n[0],y+n[1],z+n[2]]
    neighbors.push [ pos, model.get pos ] 
  # this give us an array of [0 .. 24]
  neighbors

getNeighbors = (p) ->
  [x,y,z] = p

  # mutable part
  neighbors = []
  neighbors.push model.get([x+n[0],y+n[1],z+n[2]]) for n in nMatrix

  # this give us an array of [0 .. 24] materials
  neighbors

read = (p) ->
  model.get(p).values

# simple helper function
write = (p,values=[]) ->
  material = model.material values: values 
  model.use material
  log "writing mat: #{material.values} at #{p}"
  model.dot p, yes # yes to overwrite, no to skip

# kernel code executed on each point
kernel = (position, state) ->


  ###############################################
  ## PRIVATE STUFF NOT EXPOSED IN THE RULES
  ## BUT IN THE METHODS 

  # create some contextual objects, used by kernel
  n = getNeighbors position
  [x,y,z] = position

  ## HOOK POINT
  rules = []

  # always keep the signal between -1.0 and +1.0
  safe = (v) -> 
    if v < -1.0
      v = -1.0
    else if v > 1.0
      v = 1.0
    v

  fsafe = (func) -> safe func

  # get material stored in a voxel
  point = (x,y,z) -> model.get [x,y,z]

  fidx = (array, i) -> 
    len = array.length
    return -1 if len is 0

    # convert the [-1.0, +1.0] signal to [0.0, 1.0]
    i = (i + 1.0) * 0.5
    
    # convert from [0.0, 1.0] to an array index
    index = Math.round i*(len - 1)

  fget = (array, i) ->
    len = array.length
    return 0.0 if len is 0

    # convert the [-1.0, +1.0] signal to [0.0, 1.0]
    i = (i + 1.0) * 0.5
    log "A: #{i}"
    
    # convert from [0.0, 1.0] to an array index
    index = Math.round i*(len - 1)
    log "B: #{index}"

    array[index]

  fset = (array, i, v) ->
    len = array.length
    return v if len is 0

    # convert the [-1.0, +1.0] signal to [0.0, 1.0]
    i = (i + 1.0) * 0.5
    
    # convert from [0.0, 1.0] to an array index
    index = Math.round i*(len - 1)

    array[index] = v
    v

  # END OF PRIVATE FUNCTIONS
  ################################################




  ##################################################
  # SAFE FUZZY LOGIC FUNCTIONS EXPOSED IN THE RULES
  returnNow = no
  saveCPUWhenPositive = (p) -> 
    p = safe p
    if p > 0.0
      returnNow = yes
    p

  skipRule = no

  # random number between -1 and 1
  rand = -> 1.0 - Math.random() * 2.0

  # set a value in the current voxel/cell
  setvalue = (i,v) ->
    i = safe i
    v = safe v
    fset state.values, i, v

  # set a value in the current voxel/cell
  getvalue = (i) ->
    i = safe i
    log "safe i: #{i}"
    fget state.values, i

  # check if two values are equals 'within an acceptant value)
  equal = (a,b,e) -> 
    a = safe a
    b = safe b
    e = Math.abs safe(e)
    if ((b - e) <= a <= (b + e)) then 1.0 else 0.0

  # check if two values are equals
  equal = (a,b) -> if (safe(a) is safe(b)) then 1.0 else 0.0

  # decrement the safe
  dec = (v) -> if !v? then 0 else safe(v)-0.01

  # increment the safe of something small
  inc = (v) -> if !v? then 0 else safe(v)+0.01

  sub = (a,b) -> safe(a) - safe(b)
  add = (a,b) -> safe(a) + safe(b)

  # filter
  filter = (s,f=1.0) -> safe(s) * safe(f)

  # random filtering
  weak = (s) -> safe(s) * rand()

  # random number using a probability of being neg or positive
  prandunit = (p) ->
    if (safe(p) > 0.0) then Math.random() else (1.0 - Math.random())

  # probability of transmitting a signal (all or nothing)
  relay = (p,v) ->
    p = safe p
    v = safe v
    if rand() > 0.0 then v else 0.0

  # remove a rule
  remove = (i) ->
    i = safe i
    rules.splice fidx(i,rules), 1
    i

  # using float indexes (-1 to +1)
  neighborvalue = (n,i) ->
    n = safe n
    i = safe i
    values = fget neighbors, n
    fget values, i

  # END OF FUZZY LOGIC FUNCTIONS
  ########################################################


  # TODO use a system of symbols rather than float numbers
  # eg a, b, c, d
  # with different amounts (1, 8..)
  # and corresponding mutators:
  # a_value(), b_value(), a_relay(), c_relay()..

  rules.push -> 
    # when > 0, this function will terminate
    # saveCPUWhenPositive(rand())

  rules.push ->

    log "state value0: #{state.values[0]} value: #{getvalue(0.8)}"
    #setvalue(1, add(getvalue(1),0.01))

  # </MUTABLE>

  #log "executing #{rules.length} rules"
  for rule in rules

    returnNow = no
    skipRule = no

    effect = rule()

    # high-level conditions 
    if returnNow
      log "return now"
      return
    if skipRule
      continue

  state


log "step 1: contamination"
for x in     [ 0 ... 2 ]
  for y in   [ 0 ... 2 ]
    for z in [ 0 ... 2 ]
      write [x, y, z], [ 
        0 # 0 for dead/invisible, 1 for alive/visible -> -(1.0,-0.7)
        0 # iteration number -> (-0.7,-0.3)
        0 # cell type (-0.2,0.2)
        0 # foo  -> (0.3,0.7)
        0 # bar -> (0.8,1.0)
      ] 
log "writing seed"
write [1, 1, 1], [ 1, 0, 0, 0, 0 ]

log " - #{model.count} cells\n"

log "step 2: proliferation"
for step in [1..1]
  log "   - timestep #{step} (#{model.count} cells)"
  model.map kernel

  # TODO
  # add here a simulation step (for updating coordinates)
  # and push cells if necessary

  # then send the streamed updates to the viewer (using socket.io?)


log " - #{model.count} cells\n"

model2 = new Potter size: [ 1e3, 1e3, 1e3 ]
for x in     [ 0 ... 5 ]
  for y in   [ 0 ... 5 ]
    for z in [ 0 ... 5 ]
      mat = model2.material values: [ 
        Math.round Math.random() # 0 for dead/invisible, 1 for alive/visible -> -(1.0,-0.7)
        0 # iteration number -> (-0.7,-0.3)
        0 # cell type (-0.2,0.2)
        0 # foo  -> (0.3,0.7)
        0 # bar -> (0.8,1.0)
      ]
      model2.use mat
      if Math.random() > 0.5 and x > 2
        model2.dot [x, y, z], yes

log "comparing models"
fitness.compare model, model2
# TODO


# note: this wil constrain models to have the less state.value[0] possible
log "step 3: remove dead cells"
model.filter (p, state) -> state.values[0] # if true we keep, else we don't keep

log " - #{model.count} cells\n"

#log "step 4: export"
#model.save "exports/#{name}.stl", -> log "file saved"

