import { expect } from 'chai'
import 'mocha'
import {mixed} from "basegl/lib/composable-mixins"

class C1 { 
    private _priv_field = "c1_priv_field"
    c1_field1 : string
    c1_func1(){return this._priv_field} 
    get c1_priv_field()  {return this._priv_field}
    set c1_priv_field(v) {this._priv_field = v}
    constructor(cfg:any){
        this.c1_field1 = `c${cfg.id}_field1`
    }
}
const c1 = {c1:C1}


class C2 { 
    private _priv_field = "c2_priv_field"
    c2_field1 : string
    c2_func1(){return this._priv_field} 
    get c2_priv_field()  {return this._priv_field}
    set c2_priv_field(v) {this._priv_field = v}
    constructor(cfg:any){
        this.c2_field1 = `c${cfg.id}_field1`
    }
}
const c2 = {c2:C2}


class C3 extends mixed (c1,c2) {
    private _priv_field = "c3_priv_field"
    c3_field1 : string 
    c3_func1(){return this._priv_field} 
    get c3_priv_field()  {return this._priv_field}
    set c3_priv_field(v) {this._priv_field = v}
    constructor(cfg:any){
        super(cfg)
        this.c3_field1 = `c${cfg.id}_field1`
    }
}
const c3 = {c3:C3}


class C4 extends mixed (c3) {
    private _priv_field = "c4_priv_field"
    c4_field1 : string
    c4_func1(){return this._priv_field} 
    get c4_priv_field()  {return this._priv_field}
    set c4_priv_field(v) {this._priv_field = v}
    constructor(cfg:any){
        super(cfg)
        this.c4_field1 = `c${cfg.id}_field1`
    }
}


const tgt = new C4(
    { id:4
    , c3: 
        { id: 3
        , c1: {id: 1}
        , c2: {id: 2}
        }
})


describe('Mixins', () => {
    it('mixin instances', () => {
        expect(tgt.c1.constructor).to.equal(C1)
        expect(tgt.c2.constructor).to.equal(C2)
        expect(tgt.c3.constructor).to.equal(C3)
    })
    it('fields', () => {
        expect(tgt.c1_field1).to.equal("c1_field1")
        expect(tgt.c2_field1).to.equal("c2_field1")
        expect(tgt.c3_field1).to.equal("c3_field1")
        expect(tgt.c4_field1).to.equal("c4_field1")
    })
    it('bound functions', () => {
        expect(tgt.c1_func1()).to.equal("c1_priv_field")
        expect(tgt.c2_func1()).to.equal("c2_priv_field")
        expect(tgt.c3_func1()).to.equal("c3_priv_field")
        expect(tgt.c4_func1()).to.equal("c4_priv_field")
    })
    it('getters', () => {
        expect(tgt.c1_priv_field).to.equal("c1_priv_field")
        expect(tgt.c2_priv_field).to.equal("c2_priv_field")
        expect(tgt.c3_priv_field).to.equal("c3_priv_field")
        expect(tgt.c4_priv_field).to.equal("c4_priv_field")
    })
    it('setters', () => {
        const v1 = tgt.c1_priv_field
        const v2 = tgt.c2_priv_field
        const v3 = tgt.c3_priv_field
        const v4 = tgt.c4_priv_field
        tgt.c1_priv_field = 'test1'
        tgt.c2_priv_field = 'test2'
        tgt.c3_priv_field = 'test3'
        tgt.c4_priv_field = 'test4'
        expect(tgt.c1_priv_field).to.equal("test1")
        expect(tgt.c2_priv_field).to.equal("test2")
        expect(tgt.c3_priv_field).to.equal("test3")
        expect(tgt.c4_priv_field).to.equal("test4")
        tgt.c1_priv_field = v1
        tgt.c2_priv_field = v2
        tgt.c3_priv_field = v3
        tgt.c4_priv_field = v4
    })
    it('should be able to change fields', () => {
        const val = tgt.c1_field1
        tgt.c1_field1 = "test"
        expect(tgt.c1_field1).to.equal("test")
        tgt.c1_field1 = val
    })
    
})
