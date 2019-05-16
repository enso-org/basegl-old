import {EventDispatcher} from 'basegl/event/dispatcher'

export class HierarchicalObject {
    private _onChildAdded: EventDispatcher
    private _onChildRemoved: EventDispatcher
    private _children: Set<HierarchicalObject>
    private _parent: HierarchicalObject | null

    constructor() {
        this._onChildAdded = new EventDispatcher()
        this._onChildRemoved = new EventDispatcher()
        this._children = new Set<HierarchicalObject>()
        this._parent = null
    }

    public get parent(): HierarchicalObject | null {
        return this._parent
    }

    public set parent(parent: HierarchicalObject | null) {
        this._redirect(parent)
    }

    public get onChildAdded(): EventDispatcher {
        return this._onChildAdded
    }

    public get onChildRemoved(): EventDispatcher {
        return this._onChildRemoved
    }

    public add(child: HierarchicalObject): void {
        this._redirect(child)
    }

    public removeChild(child: HierarchicalObject): void {
        this._redirect(child)
    }

    private _redirect(newParent: HierarchicalObject | null): void {
        if (this._parent) {
            this._parent._children.delete(this)
            this._parent.onChildRemoved.dispatch(this)
        }

        this._parent = newParent

        if (newParent) {
            newParent._children.add(this)
            newParent._onChildAdded.dispatch(this)
        }
    }

    public forEach(f: (child: HierarchicalObject) => void): void {
        this._children.forEach(f)
    }

    public dispose(): void {
        for (let child of this._children) {
            child.dispose()
        }

        this._children.clear()

        if (this._parent) {
            this._parent.removeChild(this)
        }
    }

    public parentChain(list: HierarchicalObject[]): HierarchicalObject[] {
        if (this._parent) {
            this._parent.parentChain(list)
        }
        list.push(this)

        return list
    }
}
