import * as _ from 'lodash'



//////////////////
/// Index Pool ///
//////////////////

export class Pool {

    public size      : number
    public free      : number[]
    public nextIndex : number
    public onResized : (oldSize:number, newSize:number) => void

	get dirtySize () { return this.nextIndex }
    
	constructor (required=0) { 
		this.size      = this._computeSquareSize(required)
		this.free      = []
        this.nextIndex = required
        this.onResized = _.noop
    }

	_computeSquareSize (required:number) {
        let size = 0
        if (required != 0) { 
			size = 1
			while (true) {
				if (size < required) {
                    size <<= 1
                } else break
            }
        }
        return size
    }

	reserve () {
		let n = this.free.shift()
		if (n != undefined) { return n }
		if (this.nextIndex == this.size) { this.grow() }
		n = this.nextIndex
		this.nextIndex += 1
        return n
    }

	dispose (n:number) {
		this.free.push(n)
    }

	resize (newSize:number) { 
        this.size = newSize
    }

	growTo (required:number) { 
		let newSize = this._computeSquareSize(required)
		let oldSize = this.size
		if (newSize > oldSize) { 
			this.size = newSize
            this.onResized(oldSize, newSize)
        }
    }
            
	grow () {
		let oldSize = this.size
		let newSize = (oldSize == 0) ? 1 : oldSize << 1
		this.size   = newSize
		this.onResized(oldSize, newSize)
    }

	reserveFromBeginning (required:number) {
		this.nextIndex = Math.max(this.nextIndex, required)
        this.growTo(required)
    }

}