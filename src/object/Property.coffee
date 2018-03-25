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


export setObjectProperty = (a, name, value, configurable=true) ->
  Object.defineProperty(a, name , {value:value, configurable: configurable})
  a

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
      fset = (idxs) -> (v) -> @[ref][idxs[0]] = v; @.onChanged?()
    else
      fget = (idxs) -> ()  -> @[ref][idx] for idx from idxs
      fset = (idxs) -> (v) ->
        for idx from idxs
          @[ref][idx] = v[idx]
          @.onChanged?()
    cls.getter name, fget idxs
    cls.setter name, fset idxs

export swizzleFieldsXYZW = (cls, ref) -> swizzleFields cls, ref, ['x', 'y', 'z', 'w']
export swizzleFieldsRGBA = (cls, ref) -> swizzleFields cls, ref, ['r', 'g', 'b', 'a']
export swizzleFieldsSTPQ = (cls, ref) -> swizzleFields cls, ref, ['s', 't', 'p', 'q']

export addIndexFields = (cls, ref, num) ->
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

embedMixin = (self, mx, fredirect) =>
  proto = Object.getPrototypeOf mx
  forNonSelfField self, mx   , (key) => fredirect key, mx
  forNonSelfField self, proto, (key) => fredirect key, mx
  mx

embedIfMixin = (self,key) =>
  val = self[key]
  if val?.__isMixin__
    self[key] = embedMixin self, val, (subredirect self, key)

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
    embedMx.forEach (mx) => embedMixin @, mx, redirectSimple

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
