import * as _ from 'lodash'
import {EventDispatcher} from 'basegl/event/dispatcher'
import {assert} from 'basegl/lib/runtime-check/assert'
import {mixed} from 'basegl/lib/composable-mixins'

/////////////
/// Types ///
/////////////

type TypedArray =
    | Int8Array
    | Uint8Array
    | Uint8ClampedArray
    | Int16Array
    | Uint16Array
    | Int32Array
    | Uint32Array
    | Float32Array
    | Float64Array

type TypedArrayCons = new (...args: any[]) => TypedArray

function patternArray(
    cls: TypedArrayCons,
    elements: Iterable<number>,
    tgtLen: number
): TypedArray {
    let pat = new cls(elements)
    let arr = new cls(tgtLen)
    let len = pat.length
    let buff = arr.buffer
    let view = new cls(pat.buffer, 0, Math.min(len, tgtLen))
    arr.set(view)
    while (true) {
        if (len >= tgtLen) {
            break
        }
        view = new cls(buff, 0, Math.min(len, tgtLen - len))
        arr.set(view, len)
        len <<= 1
    }
    return arr
}

//////////////
/// Buffer ///
//////////////

/**
 * Buffer is a wrapper over any array-like object and exposes element read /
 * write functions that can be overriden instead of inflexible index-based
 * interface.
 */

export class Buffer {
    public type: TypedArrayCons
    private default: Iterable<number> | undefined
    private _array: TypedArray

    get array() {
        return this._array
    }
    get length() {
        return this._array.length
    }

    constructor(type: TypedArrayCons, arg: any, cfg: any = {}) {
        this.type = type
        this.default = cfg.default
        this._array = this._newArray(arg)
    }

    _newArray(arg: any) {
        if (this.default && arg.constructor == Number) {
            return patternArray(this.type, this.default, arg)
        } else {
            return new this.type(arg)
        }
    }

    /// Read / Write ///

    read(ix: number) {
        return this.array[ix]
    }

    write(ix: number, v: number) {
        assert(this.array.length > ix, () => {
            throw `Index ${ix} is too big, array has ${
                this.array.length
            } elements`
        })
        this.array[ix] = v
    }

    readMultiple(ixs: number[]) {
        return ixs.map(ix => this.array[ix])
    }

    writeMultiple(ixs: number[], vals: number[]) {
        for (let i = 0; i < ixs.length; i++) {
            let ix = ixs[i]
            let val = vals[i]
            this.write(ix, val)
        }
    }

    /// Size Management ///

    resize(newLength: number) {
        let newArray = this._newArray(newLength)
        let arrayView =
            this.length <= newLength
                ? this.array
                : new this.type(this.array.buffer, 0, newLength)
        newArray.set(arrayView)
        this._array = newArray
    }

    /// Redirect ///

    set(array: ArrayLike<number>, offset?: number | undefined) {
        this.array.set(array, offset)
    }
}

////////////
/// View ///
////////////

/**
 * View is a wrapper over any buffer-like object allowing to view the array with
 * a defined elements shift.
 */

export class View {
    private _buffer: Buffer
    private _offset: number
    private _length: number

    get buffer() {
        return this._buffer
    }
    get offset() {
        return this._offset
    }
    get length() {
        return this._length
    }

    constructor(buffer: Buffer, offset = 0, length = 0) {
        this._buffer = buffer
        this._offset = offset
        this._length = length
    }

    read(ix: number) {
        return this.buffer.read(ix + this.offset)
    }

    write(ix: number, val: number) {
        this.buffer.write(ix + this.offset, val)
    }

    readMultiple(ixs: number[]) {
        return this.buffer.readMultiple(ixs.map(ix => ix + this.offset))
    }

    writeMultiple(ixs: number[], vals: number[]) {
        this.buffer.writeMultiple(ixs.map(ix => ix + this.offset), vals)
    }
}

////////////////
/// Bindable ///
////////////////

/**
 * Bindable is a wrapper over any buffer-like object allowing to subscribe to
 * changes by monkey-patching its methods.
 */

export class Bindable {
    public onResized: (oldSize: number, newSize: number) => void
    public onChanged: (ix: number) => void
    public onChangedMultiple: (ixs: number[]) => void
    public onChangedRange: (offset: number, length: number) => void
    private _buffer: Buffer

    get buffer() {
        return this._buffer
    }
    get length() {
        return this.buffer.length
    }
    get array() {
        return this.buffer.array
    }

    constructor(buffer: Buffer) {
        this._buffer = buffer
        this.onResized = _.noop
        this.onChanged = _.noop
        this.onChangedMultiple = ixs => {
            for (let ix of ixs) {
                this.onChanged(ix)
            }
        }
        this.onChangedRange = (offset, length) => {
            for (let ix of _.range(offset, offset + length)) {
                this.onChanged(ix)
            }
        }
    }

    read(ix: number) {
        return this.buffer.read(ix)
    }

    readMultiple(ixs: number[]) {
        return this.buffer.readMultiple(ixs)
    }

    write(ix: number, val: number) {
        this.buffer.write(ix, val)
        this.onChanged(ix)
    }

    writeMultiple(ixs: number[], vals: number[]) {
        this.buffer.writeMultiple(ixs, vals)
        this.onChangedMultiple(ixs)
    }

    set(buffer: ArrayLike<number>, offset = 0) {
        this.buffer.set(buffer, offset)
        this.onChangedRange(offset, buffer.length)
    }

    resize(newLength: number) {
        let oldLength = this.length
        if (oldLength != newLength) {
            this.buffer.resize(newLength)
            this.onResized(oldLength, newLength)
        }
    }
}

//////////////////
/// Observable ///
//////////////////

/**
 * Observable is a wrapper over any buffer-like object allowing to subscribe to
 * changes.
 */

export class Observable {
    private _buffer: Buffer
    private _onChanged: EventDispatcher

    get buffer() {
        return this._buffer
    }
    get onChanged() {
        return this._onChanged
    }
    get length() {
        return this.buffer.length
    }
    get array() {
        return this.buffer.array
    }

    constructor(buffer: Buffer) {
        this._buffer = buffer
        this._onChanged = new EventDispatcher()
    }

    /// Read / Write ///

    read(ix: number) {
        return this.buffer.read(ix)
    }

    readMultiple(ixs: number[]) {
        return this.buffer.readMultiple(ixs)
    }

    write(ix: number, val: number) {
        this.buffer.write(ix, val)
        this.__onChanged(ix)
    }

    writeMultiple(ixs: number[], vals: number[]) {
        this.buffer.writeMultiple(ixs, vals)
        this.__onChangedMultiple(ixs)
    }

    set(buffer: ArrayLike<number>, offset = 0) {
        this.buffer.set(buffer, offset)
        this.__onChangedRange(offset, buffer.length)
    }

    /// Size Management ///

    resize(newLength: number) {
        let oldLength = this.length
        if (oldLength != newLength) {
            this.buffer.resize(newLength)
            this.__onResized(oldLength, newLength)
        }
    }

    /// Events ///

    __onResized(oldSize: number, newSize: number) {
        _.noop(oldSize)
        _.noop(newSize)
    }

    __onChanged(ix: number) {
        this.onChanged.dispatch(ix)
    }

    __onChangedMultiple(ixs: number[]) {
        for (let ix of ixs) {
            this.__onChanged(ix)
        }
    }

    __onChangedRange(offset: number, length: number) {
        for (let ix of _.range(offset, offset + length)) {
            this.__onChanged(ix)
        }
    }
}
