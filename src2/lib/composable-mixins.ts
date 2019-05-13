/////////////
/// Utils ///
/////////////

function lowerFirstChar(s: string): string {
    return s.charAt(0).toLowerCase() + s.slice(1)
}

const varPat = /\$[a-zA-Z0-9_]+/gi

export function fastFunction(
    dict: {[k: string]: string},
    f: (...args: any[]) => any
): () => any {
    const code1 = f.toString()
    const code2 = code1.replace(varPat, dkey => {
        const key = dkey.slice(1)
        const val = dict[key]
        if (val == undefined) {
            throw `Key '${key}' not found while building the function`
        }
        return val
    })
    return new Function(`return ${code2};`)()
}

const accessorPattern = /this *. *([a-zA-Z0-9_]+) *=/gm

function getMatches(string: string, regex: RegExp) {
    let matches = []
    let match
    while ((match = regex.exec(string))) {
        matches.push(match[1])
    }
    return matches
}

//////////////
/// Mixins ///
//////////////

export function mixed<T extends NamedConstructors[]>(
    ...mixinsArr: T
): new (cfg?: any) => UnionToIntersection<InstanceValues<T[number]>> {
    const mixins = merge(...mixinsArr)
    const cls = class Mixin {
        constructor(cfg: any = {}) {
            for (const key of Object.keys(mixins)) {
                const mcfg = cfg[key] || {}
                Object.assign(this, {[`_${key}`]: new mixins[key](mcfg)})
            }
        }
    } as any
    embedMixins(cls, mixins)
    return cls
}

// Use `T extends any` to force distribution, then map to the instance types
// within the distribution. This prevents everything just turning to `any`
type InstanceValues<T extends NamedConstructors> = T extends any
    ?
          | {[K in keyof T]: InstanceType<T[K]>}
          | {[K in keyof T]: PublicInstance<T[K]>}[keyof T]
    : never

type NamedConstructors = {[k: string]: new (...args: any[]) => any}

type PublicInstance<T extends new (...args: any[]) => any> = T extends (new (
    ...args: any[]
) => infer I)
    ? {[K in keyof I]: I[K]}
    : never

export type UnionToIntersection<U> = (U extends any
    ? (k: U) => void
    : never) extends ((k: infer I) => void)
    ? I
    : never

///////////////////////
/// Mixin embedding ///
///////////////////////

function embedMixins(base: any, mixins: {[k: string]: any}) {
    for (let mixinName in mixins) {
        const mixin = mixins[mixinName]
        embedMixin(base, mixinName, mixin)
    }
}

function embedMixin(base: any, mixinName: string, mixin: any) {
    const mixinProto = mixin.prototype
    const consStr = mixinProto.constructor.toString()
    const protoFields = getAllPropertyNames(mixinProto)
    const consFields = getMatches(consStr, accessorPattern)
    const fields = protoFields.concat(consFields).filter(checkMixinField)

    Object.defineProperty(base.prototype, mixinName, {
        get: fastFunction({mixinName}, function(this: any) {
            return this._$mixinName
        }),
        set: fastFunction({mixinName}, function(this: any, v: any) {
            this._$mixinName = v
        }),
        configurable: true
    })

    fields.forEach(field => embedMixinField(base, mixinName, mixin, field))
}

function embedMixinField(base: any, name: string, mixin: any, field: string) {
    let isFunc = false
    const desc = Object.getOwnPropertyDescriptor(mixin.prototype, field)
    if (desc != undefined) {
        const tgtProtoField = desc.value
        if (tgtProtoField && tgtProtoField.constructor == Function) {
            isFunc = true
        }
    }
    if (isFunc) {
        Object.defineProperty(base.prototype, field, {
            get: fastFunction({name, field}, function(this: any) {
                return this.$name.$field.bind(this.$name)
            }),
            configurable: true
        })
    } else {
        Object.defineProperty(base.prototype, field, {
            get: fastFunction({name, field}, function(this: any) {
                return this.$name.$field
            }),
            set: fastFunction({name, field}, function(this: any, v: any) {
                this.$name.$field = v
            }),
            configurable: true
        })
    }
}

/////////////
/// Utils ///
/////////////

function getAllPropertyNames(obj: any) {
    let props: string[] = []
    do {
        props = props.concat(Object.getOwnPropertyNames(obj))
    } while ((obj = Object.getPrototypeOf(obj)))
    return props
}

function checkMixinField(name: string) {
    const notMagic = !(name in {})
    const notPriv = !name.startsWith('_')
    return notMagic && notPriv
}

function merge(...objs: {[k: string]: any}[]): {[k: string]: any} {
    return Object.assign({}, ...objs)
}
