export class Unique {
    private static _nextID : number = 0
    private _id : number

    static getID(): number {
        const id = this._nextID
        this._nextID += 1
        return id
    }

    constructor(){
        this._id = Unique.getID()
    }

    get id() {
        return this._id
    }
}
