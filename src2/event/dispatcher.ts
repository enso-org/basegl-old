/////////////
/// Types ///
/////////////

type Listener = (...args:any[]) => any



///////////////////////
/// EventDispatcher ///
///////////////////////

export class EventDispatcher {
    private _listeners : Set<Listener>
    
    constructor() {
        this._listeners = new Set
    }
  
    addEventListener (f:Listener) {
        this._listeners.add(f)
    }
  
    removeEventListener (f:Listener) { 
        this._listeners.delete(f)
    }
  
    dispatch (...args:any[]) { 
        this._listeners.forEach ((f) => f (...args))
    }
}



/////////////////////////////////
/// SingleShotEventDispatcher ///
/////////////////////////////////

export class SingleShotEventDispatcher {
    private _dispatcher : EventDispatcher
    private _args       : any[] | null

    get dispatcher () { return this._dispatcher }
    get args       () { return this._args       }

    constructor() {
        this._dispatcher = new EventDispatcher
        this._args       = null
    }

    addEventListener (f:Listener) {
        this.dispatcher.addEventListener(f)
        if (this.args != null) { f(...this.args) }
    }

    removeEventListener (f:Listener) {
        this.dispatcher.removeEventListener(f) 
    }

    dispatch (...args:any[]) {
        this._args = args
        this.dispatcher.dispatch(...args)
    }
}