import * as Reflect      from 'basegl/object/Reflect'
import * as Property     from 'basegl/object/Property'
import * as Image        from 'basegl/display/Image'

import {Color}           from 'basegl/display/Color'
import {Vector}          from "basegl/math/Vector"
import {DisplayObject}   from "basegl/display/DisplayObject"
import {IdxPool}         from 'basegl/lib/container/Pool'
import {Composable}      from 'basegl/object/Property'



export variables =
  time        : "time"
  zoom        : "zoom"
  world_mouse : "world_mouse"

  bbox           : "bbox"
  uv             : "uv"
  world          : "world"
  local          : "local"
  mouse          : "mouse"
  pointerEvents  : "pointerEvents "
  symbolID       : "symbolID"
  symbolFamilyID : "symbolFamilyID"



attribSizeByType = new Map \
  [ ['bool'  , 1]
  , ['int'   , 1]
  , ['float' , 1]
  , ['vec2'  , 2]
  , ['vec3'  , 3]
  , ['vec4'  , 4]
  ]

attribBufferByType = new Map \
  [ ['float' , Float32Array]
  , ['vec2'  , Float32Array]
  , ['vec3'  , Float32Array]
  , ['vec4'  , Float32Array]
  ]


attribTypeByJSType = new Map \
  [ [ Number              , 'float' ]
  , [ Image.DataTexture   , 'sampler2D']
  , [ Image.CanvasTexture , 'sampler2D']
  , [ Color               , 'vec4']
  ]

inferAttribType = (a) ->
  type = attribTypeByJSType.get (Reflect.typeOf a)
  if not type? then throw {msg: "Cannot infer type of attribute", attr: a}
  type



##############
### Symbol ###
##############

export DRAW_BUFFER =
  NORMAL : 0
  ID     : 1

export class TypedValue
  constructor: (@type, @value=undefined) ->

export typedValue = Property.consAlias TypedValue
export int   = (args...) -> typedValue 'int'   , args...
export float = (args...) -> typedValue 'float' , args...


export class Symbol
  constructor: (@shape) ->
    @bbox              = new Vector [512,512]
    @_instances        = new Set
    @_localVariables   = new Map
    @_globalVariables  = new Map

    @_initShader()
    @_initVariables()
    @_initMaterial()
    @_recomputeShader()
    @_initDefaultVariables()

  ### Initialization ###

  _initShader: () ->
    @shader            = @shape.toShader()
    @shader.attributes = @_localVariables
    @shader.uniforms   = @_globalVariables

  _initVariables: () ->
    mkVariableProxy = (fdef) => new Proxy {},
      set: (target, name, val) =>
        tval = val
        if not (tval instanceof TypedValue)
          tval = new TypedValue (inferAttribType val), val
        fdef.call @, name, tval
        true
    @variables       = mkVariableProxy @defineVariable
    @globalVariables = mkVariableProxy @defineGlobalVariable

  _initMaterial: () ->
    @material = new THREE.RawShaderMaterial
      blending:    THREE.NormalBlending
      transparent: true
      extensions:
        derivatives:      true
        fragDepth:        false
        drawBuffers:      false
        shaderTextureLOD: false

  _initDefaultVariables: () ->
    # FIXME (when WebGL > 2.0)
    # We need to pass symbolID and symbolFamilyID as floats
    # until we hit WebGL 2.0 with "flat" attribute support.
    # For more information, see https://github.com/mrdoob/three.js/issues/9965
    @variables.bbox           = typedValue 'vec2'
    @variables.xform1         = typedValue 'vec4'
    @variables.xform2         = typedValue 'vec4'
    @variables.xform3         = typedValue 'vec4'
    @variables.xform4         = typedValue 'vec4'
    @variables.symbolID       = 0
    @variables.symbolFamilyID = 0
    @variables.pointerEvents  = 1
    @variables.zIndex         = 0

    @globalVariables.zoom        = 1
    @globalVariables.displayMode = int 0
    @globalVariables.drawBuffer  = int DRAW_BUFFER.NORMAL
    @globalVariables.time        = 0


  ### Variables ###

  setVariable: (name, v) ->
    @_localVariables.set name, v

  setGlobalVariable: (name, v) ->
    @_globalVariables.set name, v
    @material.uniforms[name] = v

  defineVariable: (name, def) ->
    cvar = @_localVariables.get name
    @setVariable name, def
    if not (cvar? && cvar.type == def.type) then @_recomputeShader()

  defineGlobalVariable: (name, def) ->
    cvar = @_globalVariables.get name
    @setGlobalVariable name, def
    if not (cvar? && cvar.type == def.type) then @_recomputeShader()

  _recomputeShader: () ->
    # FIXME (when resolved https://github.com/mrdoob/three.js/issues/13019)
    # It would be better to re-generate shader only when material is about to update
    # not every time a variable is added.
    s = @shader.compute()
    @material.vertexShader   = s.vertex
    @material.fragmentShader = s.fragment
    @material.needsUpdate    = true

  lookupShape: (id) -> @shader.idmap.get id

  registerInstance: (instance) ->
    @_instances.add instance

  @getter 'instances', -> [@_instances...]

  addToScene: (scene) -> scene.addSymbol @




class DOMSymbol
  constructor: (@domElement) ->

  addToScene: (scene) -> scene.addDOMSymbol @

  newInstance: () ->
    new DOMSymbolInstance @domElement.cloneNode(true)


class DOMSymbolInstance extends DisplayObject
  constructor: (@domElement) ->
    super()
    @obj = new THREE.CSS3DObject @domElement
    @obj.matrixAutoUpdate = false


  setOrigin: (args...) ->
    super.setOrigin args...
    @_updatePosition()

  onTransformed: () ->
    super.onTransformed()
    @_updatePosition()

  _updatePosition: () -> @obj.matrix.fromArray @xform

  dispose: ()->
    @obj.parent?.remove(@obj)


export symbol = (a) =>
  if a instanceof HTMLElement then new DOMSymbol a else new Symbol a



######################
### SymbolGeometry ###
######################

export class SymbolGeometry
  constructor: (@attributeMap=new Map, @maxElements=1000) ->
    @_symbolIDPool = new IdxPool 1

    @attributeTypeMap = new Map
    @buffers    = {}
    @attributes = {}

    @bufferGeometry = new THREE.PlaneBufferGeometry 0,0,1,1
    @geometry       = new THREE.InstancedBufferGeometry()

    @geometry.index               = @bufferGeometry.index
    @geometry.attributes.position = @bufferGeometry.attributes.position
    @geometry.attributes.v_uv     = @bufferGeometry.attributes.uv

    # what a hack :(
    @geometry.computeBoundingSphere()
    @geometry.boundingSphere.radius = 100000

    @attributeMap.forEach  (v,name) => @addAttribute v, name



  setBufferVal: (id, name, vals) =>
    if not (vals instanceof Array)
      if      typeof vals == 'number' then vals = [vals]
      else if vals instanceof Color   then vals = vals.toRGB().rgba
      else 
        throw {msg: "Wrong buffer value", vals}
    vname  = 'v_' + name
    size   = attribSizeByType.get(@attributeTypeMap.get(vname))
    start  = id * size
    buffer = @buffers[vname]
    if window.BASEGL_DEBUG
      console.debug "setBufferVal", id, name, vals      
      attrib = @attributes[vname]
      if vals.length != attrib.itemSize
        console.error "Asserion failed: Attribute '#{name}' size mismatch. 
          Expected #{attrib.itemSize}, got #{vals.length} (#{vals})."
    for v,i in vals
      buffer[start + i] = v
    @geometry.attributes[vname].needsUpdate = true

  addAttribute: (v, name) ->
    vname = 'v_' + name
    @attributeTypeMap.set vname, v.type
    size               = attribSizeByType.get v.type
    bufferCons         = attribBufferByType.get v.type
    buffer             = new bufferCons (@maxElements * size)
    if v.value then buffer.fill v.value
    attribute          = new THREE.InstancedBufferAttribute buffer, size
    @buffers[vname]    = buffer
    @attributes[vname] = attribute
    @attributes[vname].setDynamic true
    @geometry.addAttribute vname, attribute

  setSize: (id, vals) -> @setBufferVal id, "bbox", vals

  dispose: (id) ->
    @_symbolIDPool.dispose id
    @setSize id, [0,0]

  reserveID: () ->
    # FIXME: handle reshaping
    @_symbolIDPool.reserve()



######################
### SymbolInstance ###
######################

export class SymbolInstance extends DisplayObject
  constructor: (@id, @family) ->
    super()
    @bbox = @family.definition.bbox.clone()
    @bbox.onChanged = () => @family.geometry.setSize @id, @bbox.xy
    @bbox.onChanged()
    @variables = new Proxy {},
      set: (target, name, val) =>
        @setVariable name, val
        true

    @variables.symbolID       = [@id]
    @variables.symbolFamilyID = [@family.id]
    @_updatePosition()


  setOrigin: (args...) ->
    super.setOrigin args...
    @_updatePosition()

  onTransformed: () ->
    super.onTransformed()
    @_updatePosition()

  _updatePosition: () ->
    @variables.xform1 = [ @xform[0]  , @xform[1]  , @xform[2]  , @xform[3]  ]
    @variables.xform2 = [ @xform[4]  , @xform[5]  , @xform[6]  , @xform[7]  ]
    @variables.xform3 = [ @xform[8]  , @xform[9]  , @xform[10] , @xform[11] ]
    @variables.xform4 = [ @xform[12] , @xform[13] , @xform[14] , @xform[15] ]

  setVariable: (name, val) ->
    @family.geometry.setBufferVal @id, name, val

  dispose: ()->
    @family.geometry.dispose @id


  lookupShapeDef: (id) -> @family.definition.lookupShape id




####################
### SymbolFamily ###
####################

export class SymbolFamily
  constructor: (@id, @definition, @geometry=new SymbolGeometry) ->
    @_mesh = new THREE.Mesh @geometry.geometry, @definition.material
    @_symbolIDMap = new Map
  
  @getter 'zIndex',       -> @_mesh.renderOrder
  @setter 'zIndex', (idx) -> @_mesh.renderOrder = idx
  
  newInstance: () ->
    id   = @geometry.reserveID()
    inst = new SymbolInstance id, @
    @definition.registerInstance inst
    @_symbolIDMap.set id, inst
    inst

  lookupSymbol: (id) -> @_symbolIDMap.get id




#############
### Utils ###
#############

export group = (children) -> new DisplayObject children


# export class SymbolInstanceProxy extends DisplayObject
#   constructor: (@def) ->
