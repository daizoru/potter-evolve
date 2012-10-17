#!/usr/bin/env coffee

{log,error,inspect} = require 'util'
Potter = require 'potter'
deck = require 'deck'

NearestCells = require './neighbourhood'


# pick up a not-so-random number in [-1, 0, 1]
# you can unbalance the randomness using the first parameter
# eg: randNorm(-0.5) means more chances to pick -1
# randNorm(1.0) means no chance to pick -1, and lot of chance to pick 1
randNorm = (t=0.0,r=1e3) -> (Number) deck.pick '-1': r - r * t, '0': r, '1': r + r * t

exports.getNeighborsFull = getNeighborsFull = (model, p) ->
  [x,y,z] = p

  # mutable part
  neighbors = {}
  for n in NearestCells
    pos = [x+n[0],y+n[1],z+n[2]]
    neighbors.push [ pos, model.get pos ] 
  # this give us an array of [0 .. 24]
  neighbors

exports.getNeighbors = getNeighbors = (model, p) ->
  console.log "getNeighbors: model: #{model}, p: #{inspect p}"
  [x,y,z] = p

  # mutable part
  neighbors = []
  neighbors.push model.get([x+n[0],y+n[1],z+n[2]]) for n in NearestCells

  # this give us an array of [0 .. 24] materials
  neighbors

exports.read = read = (model, p) ->
  model.get(p).values

# simple helper function
exports.write = write = (model, p,values=[]) ->
  #console.log "model: #{inspect model}"
  material = model.material values: values 
  model.use material
  #log "writing mat: #{material.values} at #{p}"
  model.dot p, yes # yes to overwrite, no to skip

# kernel code executed on each point
exports.kernel = kernel = (model, position, state) ->


  ###############################################
  ## PRIVATE STUFF NOT EXPOSED IN THE RULES
  ## BUT IN THE METHODS 

  #console.log "kernel -> model: #{inspect model}"
  # create some contextual objects, used by kernel
  n = getNeighbors model, position
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
    #log "A: #{i}"
    
    # convert from [0.0, 1.0] to an array index
    index = Math.round i*(len - 1)
    #log "B: #{index}"

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
    #log "safe i: #{i}"
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
    0

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
