assert = (ok) ->
  if not ok then throw "Assertion failed"

# FIXME: move from define* to define*2
# It is better to set things oncei n prototype then per object(!)
### OBSOLETE START ###
export defineProperty = (obj, prop, a) -> Object.defineProperty obj, prop, a
export defineGetter   = (obj, prop, f) -> defineProperty obj, prop, {get: f, configurable: yes}
export defineSetter   = (obj, prop, f) -> defineProperty obj, prop, {set: f, configurable: yes}
### OBSOLETE END ###

export defineDynamicProperty = (obj, prop, a) -> Object.defineProperty obj, prop, a
export defineDynamicGetter   = (obj, prop, f) -> defineProperty obj, prop, {get: f, configurable: yes}
export defineDynamicSetter   = (obj, prop, f) -> defineProperty obj, prop, {set: f, configurable: yes}

export defineProperty2       = (cls, prop, a) -> Object.defineProperty cls.prototype, prop, a
export defineGetter2         = (cls, prop, f) -> defineProperty2 cls, prop, {get: f, configurable: yes}
export defineSetter2         = (cls, prop, f) -> defineProperty2 cls, prop, {set: f, configurable: yes}

# FIXME: Remove these, its just bad design to add methods to global objects
Function::property = (prop, desc) -> defineProperty2 @, prop, desc
Function::getter   = (prop, f)    -> defineGetter2   @, prop, f
Function::setter   = (prop, f)    -> defineSetter2   @, prop, f


# OLD! Use `defineValue` instead
export setObjectProperty = (a, name, value, configurable=true) ->
  Object.defineProperty(a, name , {value:value, configurable: configurable})
  a

export defineValue = (obj, name, value, configurable=true) ->
  Object.defineProperty obj, name, {value, configurable}
  obj

export consAlias = (a) -> (args...) -> new a args...


export swizzleFields = (cls, ref, fields) ->
  fieldsAssoc   = []
  fieldsAssoNew = []
  for els in [1..fields.length]
    for n,i in fields
      if els == 1 then fieldsAssoc.push [n,[i]]
      else for [an, ai],ii in fieldsAssoc
        fieldsAssoNew.push [an+n, ai.concat [i]]
    fieldsAssoc   = fieldsAssoc.concat fieldsAssoNew
    fieldsAssoNew = []

  for [name,idxs] from fieldsAssoc
    if idxs.length == 1
      fget = (idxs) -> ()  -> @[ref][idxs[0]]
      fset = (idxs) -> (v) -> @[ref][idxs[0]] = v; @onChanged?()
    else
      fget = (idxs) -> ()  -> @[ref][idx] for idx from idxs
      fset = (idxs) -> (v) ->
        for idx from idxs
          @[ref][idx] = v[idx]
          @onChanged?()
    cls.getter name, fget idxs
    cls.setter name, fset idxs

export swizzleFieldsXYZW = (cls, ref='array') -> swizzleFields cls, ref, ['x', 'y', 'z', 'w']
export swizzleFieldsXYZ  = (cls, ref='array') -> swizzleFields cls, ref, ['x', 'y', 'z']
export swizzleFieldsXY   = (cls, ref='array') -> swizzleFields cls, ref, ['x', 'y']
export swizzleFieldsRGBA = (cls, ref='array') -> swizzleFields cls, ref, ['r', 'g', 'b', 'a']
export swizzleFieldsRGB  = (cls, ref='array') -> swizzleFields cls, ref, ['r', 'g', 'b']
export swizzleFieldsSTPQ = (cls, ref='array') -> swizzleFields cls, ref, ['s', 't', 'p', 'q']
export swizzleFieldsSTP  = (cls, ref='array') -> swizzleFields cls, ref, ['s', 't', 'p']

export addIndexFields = (cls, ref, num) ->
  if ref == undefined then ref = 'array'
  if num == undefined then num = cls.size
  fget = (i) -> ()  -> @[ref][i]
  fset = (i) -> (v) -> @[ref][i] = v; @[ref].onChanged?()
  for i in [0..num-1]
    cls.getter i, fget i
    cls.setter i, fset i

export addIndexFieldsStd = (cls, ref) -> addIndexFields cls, ref, 16







export merge = (a,b) ->
  out = {}
  for k,v of a
    out[k] = v
  for k,v of b
    out[k] = v
  out

export mergeMut = (a,b) ->
  for k,v of b
    a[k] = v




############################
### Object configuration ###
############################

forNonSelfField = (self, obj, f) =>
  for k in Object.getOwnPropertyNames obj
    if self[k] == undefined then f k

embedMixin_old = (self, mx, fredirect) =>
  proto = Object.getPrototypeOf mx
  forNonSelfField self, mx   , (key) => fredirect key, mx
  forNonSelfField self, proto, (key) => fredirect key, mx
  mx

embedIfMixin = (self,key) =>
  val = self[key]
  if val?.__isMixin__
    delete val.__isMixin__
    self[key] = embedMixin_old self, val, (subredirect self, key)
    val.__isMixin__ = true

subredirect = (self,mk) => (k) =>
  defineGetter self, k,     -> @[mk][k]
  defineSetter self, k, (v) -> @[mk][k]=v

export class Composable
  cons: ->
  init: ->
  constructor: (args...) ->

    redirectGetter = (k,a,ak) => defineGetter @, k,    ->a[ak]
    redirectSetter = (k,a,ak) => defineSetter @, k, (v)->a[ak]=v
    redirect       = (k,a,ak) => redirectSetter(k,a,ak); redirectSetter(k,a,ak)
    redirectSimple = (k,a)    => redirect(k,a,k)

    discoverEmbedMixins = (f) =>
      @__mixins__ = []
      f()
      mxs = @__mixins__
      delete @__mixins__
      set = new Set mxs
      set.delete @[key] for key in Object.keys @
      set

    embedMx = discoverEmbedMixins => @cons args...
    embedMx.forEach (mx) => embedMixin_old @, mx, redirectSimple

    # Handle all keys after initialization
    for key in Object.keys @
      embedIfMixin @, key
      if (key.startsWith '_') && not(key.startsWith '__')
        redirectGetter key.slice(1), @, key

    @init args...


  configure: (cfg) ->
    if cfg? then for key in Object.keys @
      if      key.startsWith '__' then nkey = key.slice 2
      else if key.startsWith '_'  then nkey = key.slice 1
      else    nkey = key
      cfgVal = cfg[nkey]
      if cfgVal?
        embedIfMixin @, key
        @[key] = cfgVal

  mixin: (cls, args...) ->
    if (cls.prototype.cons == undefined) || (cls.prototype.init == undefined)
      cls.call @, args...
    else
      mx = new cls args...
      @__mixins__.push mx
      mx.__isMixin__ = true
      mx

  mixins: (clss, args...) -> @mixin cls, args... for cls in clss


export fieldMixin = (cls) =>
  fieldName = '_' + cls.name.charAt(0).toLowerCase() + cls.name.slice(1)
  (args...) -> @[fieldName] = @mixin cls, args...



# Extending the config with additional config
export extend = (obj, cfg) =>
  nobj = Object.assign {}, obj
  for k,v of cfg
    nobj[k] = v
  nobj

# class C1 extends Composable
#   cons: (cfg) -> 
#     @_foo = 1
#     @configure cfg

# t1 = new C1
# t1._foo = 7
# t1._bar = 9

# t2 = new C1
# t2._foo = 8
# t2._bar = 10


# console.log t1
# console.log t2

# throw "end"

#
# foo = () ->
#
# class C1 extends Composable
#   cons: (cfg) ->
#     @_c1_id  = 0
#     @c1_p1   = 'c1_p1'
#     @_c1_p2  = 'c1_p2'
#     @__c1_p3 = 'c1_p3'
#     @configure cfg
#   c1_foo: () -> "foo"
#
# # console.log  C1.prototype.__proto__.constructor.name
# # console.log foo.prototype.__proto__.constructor.name
#
# class C2 extends Composable
#   cons: (id,cfg) ->
#     @_c2_id  = id
#     @c2_p1   = 'c2_p1'
#     @_c2_p2  = 'c2_p2'
#     @__c2_p3 = 'c2_p3'
#     @configure cfg
#   c2_foo: () -> "foo"
#
# class C3 extends Composable
#   cons: (id,cfg) ->
#     @_c3_id  = id
#     @c3_p1   = 'c3_p1'
#     @_c3_p2  = 'c3_p2'
#     @__c3_p3 = 'c3_p3'
#     @configure cfg
#   c3_foo: () -> "foo"
#
# class CX1 extends Composable
#   cons: (cfg) ->
#     @c1 = @mixin C1, 1, cfg
#     @c2 = @mixin C2, 2, cfg
#     @c3 = @mixin C3, 3, cfg
#     @configure cfg
#   bar: () -> "bar"
#
#
# c1_mixin = (cfg) -> @_c1 = @mixin C1, cfg
#
# class CX2 extends Composable
#   cons: (cfg) ->
#     @mixin c1_mixin, cfg
#     @configure cfg
#   c1_foo: () -> 'overriden by CX2'
#   bar: () -> "bar"
#
#
# c1 = new C1
#   c1_id: 'overriden!'
# cx2 = new CX2
#   c1: c1
#
# console.log cx2
# console.log cx2.c1_id
#
#
#
# throw "end"

#
#
#
# foo = () ->
#
# class C1 extends Composable
#   cons: (id,cfg) ->
#     @_c1_id  = id
#     @c1_p1   = 'c1_p1'
#     @_c1_p2  = 'c1_p2'
#     @__c1_p3 = 'c1_p3'
#     @configure cfg
#   c1_foo: () -> "foo"
#
# # console.log  C1.prototype.__proto__.constructor.name
# # console.log foo.prototype.__proto__.constructor.name
#
# class C2 extends Composable
#   cons: (id,cfg) ->
#     @_c2_id  = id
#     @c2_p1   = 'c2_p1'
#     @_c2_p2  = 'c2_p2'
#     @__c2_p3 = 'c2_p3'
#     @configure cfg
#   c2_foo: () -> "foo"
#
# class C3 extends Composable
#   cons: (id,cfg) ->
#     @_c3_id  = id
#     @c3_p1   = 'c3_p1'
#     @_c3_p2  = 'c3_p2'
#     @__c3_p3 = 'c3_p3'
#     @configure cfg
#   c3_foo: () -> "foo"
#
# class CX1 extends Composable
#   cons: (cfg) ->
#     @c1 = @mixin C1, 1, cfg
#     @c2 = @mixin C2, 2, cfg
#     @c3 = @mixin C3, 3, cfg
#     @configure cfg
#   bar: () -> "bar"
#
#
# c1_mixin = (cfg) -> @_c1 = @mixin C1, 1, cfg
#
# class CX2 extends Composable
#   cons: (cfg) ->
#     @mixin c1_mixin, cfg
#     @configure cfg
#   c1_foo: () -> 'overriden by CX2'
#   bar: () -> "bar"
#
#
# cx1 = new CX1
# console.log '>>>'
# cx2 = new CX2
#   c1_p1: 1
# console.log cx1
# console.log cx2
# console.log cx2.c1_p1
# console.log cx2.c1_foo()
#
#
#
# throw "end"


cloneObjectArray = (array) -> 
  newArray = []
  for obj in array
    newObj = Object.assign {}, obj
    newArray.push newObj
  newArray

arrayLast = (array) -> 
  array[array.length - 1]


###############################################################################
### NEW NEW NEW NEW NEW NEW NEW NEW NEW NEW NEW NEW NEW NEW NEW NEW NEW NEW ###
###############################################################################


#############################
### Fast Function builder ###
#############################

# The 'fastFunction' allows build highly-optimized functions, especially when
# some parts contain string-based lookups. 
#
# WARNING!
# Use only when necessary. Wrong usage can lead to performance bottlenecks. 
# Every usage can invalidate the browser cache and runs JavaScript compiler.
# Safe usages include generating getters / setters while metaprogramming, 
# for example during class generation. 

varPat = /\$[a-zA-Z0-9_]+/gi;

export fastFunction = (dict, f) ->
  code1 = f.toString()
  code2 = code1.replace varPat, (dkey) -> 
    key = dkey.slice(1)
    val = dict[key]
    if val == undefined
      throw "Key '#{key}' not found while building the function"
    val
  new Function("return #{code2};")()



#########################
### generateAccessors ###
#########################

# The `generateAccessors` function analyses the provided class constructor and 
# for each field generates getters / setters according to the following rules:
#
#   - If the field was prefixed with double underscore, like `__foo`, then it is 
#     meant not to be seen from outside and pair of `_foo` getter / setter is 
#     generated.
#
#   - If the field was prefixed with single underscore, like `_foo`, then it is
#     considered a private field, but accessible from outside and only `foo` 
#     getter is generated.

generateAccessors = (base) ->
  proto     = base.prototype
  protoCons = proto.constructor
  if protoCons.generatedAccessors == undefined
    protoCons.generatedAccessors = new Set
  if not protoCons.generatedAccessors.has base.name
    protoCons.generatedAccessors.add base.name
    consStr = base.prototype.constructor.toString()
    fields  = getMatches consStr, accessorPattern
    fields  = new Set fields
    fields.forEach (field) =>
      if field.startsWith '__'
        name = field.slice(1)
        Object.defineProperty proto, name, 
          get: fastFunction {field},     -> @$field
          set: fastFunction {field}, (v) -> @$field = v
          configurable: true
      else if field.startsWith '_'
        name = field.slice(1)
        Object.defineProperty proto, name, 
          get: fastFunction {field}, -> @$field
          configurable: true

accessorPattern = /this *. *([a-zA-Z0-9_]+) *=/gm

getMatches = (string, regex) ->
  matches = []
  match
  while (match = regex.exec(string))
    matches.push(match[1]);
  matches

Function::generateAccessors = (args...) -> generateAccessors @, args...



#############
### mixin ###
#############

# Options:
#
#   - cfg.rename="foo" 
#     Renames the mixin variable
#
#   - cfg.exportMixin [default: true] [true / false / 'private']
#     Exports the mixin variable to variable scope 
#
#   - cfg.exportPrivate [default: false]
#     Exports private mixin fields
#
#   - cfg.allowFieldsOverlap [defaukt: false]
#     Allows mixin definition to override existing fields
#
#   - cfg.whitelist=['foo', 'bar'] [default: undefined]
#     List of fields to be exposed in host class. Defaults to all fields.
#
#   - cfg.blacklist=['foo', 'bar'] [default: undefined]
#     List of fields to be hidden in host class. Defaults to none.


class MixinRegistry
  constructor: (cfg={fields: new Map, constructorStack: []}) ->
    @fields           = cfg.fields
    @constructorStack = cfg.constructorStack

  initializer: (args...) ->
      if @_mixins_constructor_chain_depth_ == undefined
        @_mixins_constructor_chain_depth_ = 0
      else
        @_mixins_constructor_chain_depth_ += 1
      cons = @_mixins_.constructorStack[@_mixins_constructor_chain_depth_]
      if @_mixins == undefined
        @_mixins = {}
      for n,f of cons
        do (n,f) =>
          @_mixins[n] = new f args...
      if @_mixins_constructor_chain_depth_ == (@_mixins_.constructorStack.length - 1)
        delete @_mixins_constructor_chain_depth_

  clone: ->
    fields           = new Map @fields
    constructorStack = cloneObjectArray @constructorStack
    new MixinRegistry {fields, constructorStack}



embedMixin = (base, ext, cfg={}) ->
  baseProto = base.prototype
  extProto  = ext.prototype
  instName  = if cfg.rename then cfg.rename else lowerFirstChar ext.name

  isFirstMixinDefinition = not baseProto.hasOwnProperty('_mixins_')
  hasInheritedMixins     = not (baseProto._mixins_ == undefined)

  currentClassMixinsConstructors = {}
  if isFirstMixinDefinition
    if hasInheritedMixins
      baseProto._mixins_ = baseProto._mixins_.clone()
    else
      baseProto._mixins_ = new MixinRegistry
    baseProto._mixins_.constructorStack.push currentClassMixinsConstructors
  else
    currentClassMixinsConstructors = 
      arrayLast baseProto._mixins_.constructorStack

  if currentClassMixinsConstructors[instName] != undefined
    throw "Trying to override '#{instName}' mixin. Possible solution is to use 
          'rename' option in the mixin definition:\n" + 
          "    @mixin MyMixin, {rename: 'foo'}"
  currentClassMixinsConstructors[instName] = ext
  
  if cfg.exportMixin != false
    Object.defineProperty baseProto, "_#{instName}", 
      get: fastFunction {instName}, -> @_mixins.$instName
      configurable: true

    if cfg.exportMixin != 'private'
      Object.defineProperty baseProto, "#{instName}", 
        get: fastFunction {instName}, -> @_mixins.$instName
        configurable: true

  # Making getters / setters for mixins
  fields = Object.getOwnPropertyNames extProto  
  fields.forEach (field) =>
    if checkMixinField field, cfg
      fieldFree = Object.getOwnPropertyDescriptor(baseProto,field) == undefined
      if fieldFree
        if not cfg.allowFieldsOverlap
          oldInstName = baseProto._mixins_.fields.get field
          if oldInstName        
            throw "Trying to override '#{field}' field inherited from 
                  #{oldInstName} mixin while expanding '#{instName}' mixin. 
                  Possible solution is to use 'allowFieldsOverlap' option in the 
                  mixin definition:\n" +
                  "    @mixin MyMixin, {allowFieldsOverlap: true}"
        
        baseProto._mixins_.fields.set field, instName 

        # Check if the target field is a function. If so, bind 'this'.
        tgtProto          = currentClassMixinsConstructors[instName].prototype
        tgtProtoFieldDesc = Object.getOwnPropertyDescriptor tgtProto, field
        tgtProtoField     = tgtProtoFieldDesc.value
        if tgtProtoField?.constructor == Function
          Object.defineProperty baseProto, field, 
            get: fastFunction {instName, field},
                 -> @_mixins.$instName.$field.bind @_mixins.$instName
            configurable: true
        else
          Object.defineProperty baseProto, field, 
            get: fastFunction {instName, field},
                 -> @_mixins.$instName.$field
            set: fastFunction {instName, field}, 
                 (v) -> @_mixins.$instName.$field = v
            configurable: true
    
  # Mixin utils accessor
  Object.defineProperty baseProto, 'mixins', 
    get: -> {constructor: @_mixins_.initializer.bind @}
    configurable: true

  checkInit base

checkMixinField = (name, cfg) -> 
  notMagic       = not (name in ['constructor', 'mixins'])
  notPriv        = (not name.startsWith '_') || cfg.exportPrivate
  whitelisted    = (cfg.whitelist == undefined || (name in cfg.whitelist))
  notBlacklisted = (cfg.blacklist == undefined || not (name in cfg.blacklist))
  notMagic && notPriv && whitelisted && notBlacklisted

checkInitPattern = /this *. *mixins *\. *constructor *\(/gm
checkInit = (base) ->
  consStr = base.prototype.constructor.toString()
  match   = consStr.match checkInitPattern
  if not match
    throw "Please initialize mixins with 'mixins.constructor' inside of 
          '#{base.name}' class constructor"


mixin = (base, ext, cfg) -> 
  embedMixin base, ext, cfg
  generateAccessors base

initMixinName = 'initMixins'

lowerFirstChar = (string) ->
    string.charAt(0).toLowerCase() + string.slice(1)

Function::mixin = (ext, cfg) -> mixin @, ext, cfg



# class B1
#   constructor: ->
#     console.log "B1"
#   fb1: -> 1

# class B2
#   constructor: (a) ->
#     console.log "B2"
#     console.log "!!", a
#   fb2: -> 2

# class B3
#   constructor: ->
#     console.log "B3"  
#   fb3: -> 3

# class C1
#   @mixin B1
#   constructor: ->
#     console.log ">> C1"
#     console.log @mixins
#     @mixins.constructor()
#     console.log "<< C1"

# class C2 extends C1
#   @mixin B2
#   @mixin B3
#   constructor: ->
#     console.log ">> C2"
#     super()
#     console.log "--"
#     @mixins.constructor
#       test: 1
#     console.log "<< C2"

# class C3 extends C1

# c2 = new C2
# c2_2 = new C2
# # c3 = new C3 

# console.log c2
# console.log c2_2

# window.c2 = c2
# # console.log c3

# throw "!!!"

### BENCH: ###

# class Base
#   @generateAccessors()
#   constructor: ->
#     @_field1 = 7

#   fn1: -> @_field1 += 1


# class C1
#   @mixin Base
#   constructor: ->
#     @mixins.constructor()

# console.log "^^^"
# console.log ""

# class C2
#   constructor: ->
#     @_base = new Base
    
#   @getter 'field1', -> @_base.field1 
#   @getter 'fn1',    -> @_base.fn1.bind @_base 


# window.C1 = C1
# window.c1 = new C1
# console.log c1
# console.log c1.field1
# c1.fn1()
# console.log c1.field1

# console.log "---"

# window.c2 = new C2
# console.log c2
# console.log c2.field1
# c2.fn1()
# console.log c2.field1



# t1 = performance.now()
# s  = 0
# for i in [1..10000000] by 1 
#   s += c1.field1
#   # c1.fn1()
# t2 = performance.now()
# console.log "C1", (t2-t1)

# t1 = performance.now()
# s  = 0
# for i in [1..10000000] by 1 
#   s += c2.field1
#   # c2.fn1()
# t2 = performance.now()
# console.log "C2", (t2-t1)



#######################
### Field swizzling ###
#######################

export swizzleFields2 = (cls, fields) ->
  fieldsAssoc   = []
  fieldsAssoNew = []
  for els in [1..fields.length]
    for n,i in fields
      if els == 1 then fieldsAssoc.push [n,[i]]
      else for [an, ai],ii in fieldsAssoc
        fieldsAssoNew.push [an+n, ai.concat [i]]
    fieldsAssoc   = fieldsAssoc.concat fieldsAssoNew
    fieldsAssoNew = []

  fieldsAssoc.forEach ([name,ixs]) ->
    if ixs.length == 1
      ix = ixs[0]
      fget =     -> @read  ix
      fset = (v) -> @write ix, v
    else
      fget =     -> @readMultiple  ixs
      fset = (v) -> @writeMultiple ixs, v
    cls.getter name, fget
    cls.setter name, fset

export swizzleFieldsXYZW2 = (cls) -> swizzleFields2 cls, ['x', 'y', 'z', 'w']
export swizzleFieldsXYZ2  = (cls) -> swizzleFields2 cls, ['x', 'y', 'z']
export swizzleFieldsXY2   = (cls) -> swizzleFields2 cls, ['x', 'y']
export swizzleFieldsRGBA2 = (cls) -> swizzleFields2 cls, ['r', 'g', 'b', 'a']
export swizzleFieldsRGB2  = (cls) -> swizzleFields2 cls, ['r', 'g', 'b']
export swizzleFieldsSTPQ2 = (cls) -> swizzleFields2 cls, ['s', 't', 'p', 'q']
export swizzleFieldsSTP2  = (cls) -> swizzleFields2 cls, ['s', 't', 'p']



######################
### Field indexing ###
######################

export addIndexFields2 = (cls, num) ->
  if num == undefined then num = cls.size
  assert num?
  for i in [0..num-1]
    do (i) =>
      Object.defineProperty cls.prototype, i, 
        get: fastFunction({i},     -> @read $i)
        set: fastFunction({i}, (v) -> @write $i, v)
        configurable: false
