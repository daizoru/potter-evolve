#!/usr/bin/env coffee

{log,error,inspect} = require 'util'
Potter = require 'potter'
deck = require 'deck'
fitness = require './fitness'
{kernel, write} = require './automata'

main = ->

  name = "automata1"
  model = new Potter size: [ 1e3, 1e3, 1e3 ]
  center = [ 200, 200, 200 ]


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


exports.cli = main()