////////////////////
/// Default tags ///
////////////////////

export enum Tag {
    info,
    warning,
    error
}

///////////
/// Log ///
///////////

export class Log {
    public tags: Set<Tag>
    public scope: string
    public time: number
    constructor(tags: Tag[] = [], scope: string = '') {
        this.tags = new Set(tags)
        this.scope = scope
        this.time = Date.now()
    }
    hasTag(tag: Tag) {
        return this.tags.has(tag)
    }
}

export class Message extends Log {
    public msgs: string[]
    constructor(tags: Tag[], scope: string, msgs: string[]) {
        super(tags, scope)
        this.msgs = msgs
    }
}

export class GroupStart extends Log {
    public msg: string
    constructor(tags: Tag[], scope: string, msg: string) {
        super(tags, scope)
        this.msg = msg
    }
}

export class GroupEnd extends Log {}

//////////////
/// Stream ///
//////////////

interface Stream {
    addLog: (log: Log) => void
}

//////////////
/// Logger ///
//////////////

export class Logger {
    public scope: string
    private streams: Set<Stream>
    constructor(scope: string = '') {
        this.scope = scope
        this.streams = new Set()
    }

    attachStream(stream: Stream) {
        this.streams.add(stream)
    }

    addLog(log: Log) {
        this.streams.forEach(stream => {
            stream.addLog(log)
        })
    }

    groupWith_<T>(tags: Tag[], msg: string, f: () => T): T {
        this.addLog(new GroupStart(tags, this.scope, msg))
        let out = f()
        this.addLog(new GroupEnd())
        return out
    }

    async asyncGroupWith_<T>(tags: Tag[], msg: string, f: () => T): Promise<T> {
        this.addLog(new GroupStart(tags, this.scope, msg))
        let out = await f()
        this.addLog(new GroupEnd())
        return out
    }

    groupWith<T>(tags: Tag[]) {
        return (msg: string, f: () => T) => {
            if (f.constructor.name == 'AsyncFunction') {
                return this.asyncGroupWith_(tags, msg, f)
            } else {
                return this.groupWith_(tags, msg, f)
            }
        }
    }

    group<T>(msg: string, f: () => T) {
        return this.groupWith([])(msg, f)
    }

    log(tags: Tag[]) {
        return (...msgs: string[]) => {
            this.addLog(new Message(tags, this.scope, msgs))
        }
    }

    info(...msgs: string[]) {
        this.log([Tag.info])(...msgs)
    }
    warning(...msgs: string[]) {
        this.log([Tag.warning])(...msgs)
    }
    error(...msgs: string[]) {
        this.log([Tag.error])(...msgs)
    }

    scoped(scope: string) {
        let childScope = this.scope == '' ? scope : this.scope + '.' + scope
        let child = new Logger(childScope)
        child.streams = this.streams
        return child
    }

    // To be removed in release scripts
    ifEnabled<T>(f: () => T): T {
        return f()
    }
}

///////////////
/// Streams ///
///////////////

export class StreamBase {
    private formatter: (msg: Log) => Log
    constructor() {
        this.formatter = a => a
    }

    setFormatter(f: (msg: Log) => Log) {
        this.formatter = f
    }

    getFormatter() {
        return this.formatter
    }

    format(msg: Log) {
        return this.formatter(msg)
    }
}

export class Console extends StreamBase {
    addLog(log: Log) {
        let flog = this.format(log)
        if (flog instanceof GroupStart) {
            console.group(flog.msg)
        } else if (flog instanceof GroupEnd) {
            console.groupEnd()
        } else if (flog instanceof Message) {
            let print = console.log
            if (flog.hasTag(Tag.error)) {
                print = console.error
            } else if (flog.hasTag(Tag.warning)) {
                print = console.warn
            }
            print(...flog.msgs)
        }
    }
}

function scopedFormatter(log: Log) {
    if (log instanceof GroupStart) {
        let scope = log.scope == '' ? '' : `[${log.scope}] `
        log.msg = scope + log.msg
    } else if (log instanceof Message) {
        let scope = log.scope == '' ? '' : `[${log.scope}]`
        log.msgs = [scope].concat(log.msgs)
    }
    return log
}

// ///////////////////////////
// /// Stream Transformers ///
// ///////////////////////////

// export class StreamTransformer {
//     public stream
//     constructor(stream){
//         this.stream = stream;
//     }

// //   addLog: (log) =>
// //     @stream.addLog log

// //   setFormatter: (f) => @stream.setFormatter f
// //   getFormatter:     => @stream.getFormatter()
// //   format:       (l) => @stream.format(l)
// }

// // export class Buffered extends StreamTransformer
// //   constructor: (args...) ->
// //     super(args...)
// //     @_buffer = []

// //   addLog: (log) ->
// //     @_buffer.push log
// //     if log.hasTag tags.error then @flush()

// //   flush: () =>
// //     @_buffer.forEach (log) => @stream.addLog log
// //     @_buffer = []

////////////////
/// Defaults ///
////////////////

export let defaultLogger = new Logger()
let stream = new Console()
stream.setFormatter(scopedFormatter)
defaultLogger.attachStream(stream)

export let log = defaultLogger.log
export let group = defaultLogger.groupWith([])
export let info = log([Tag.info])
export let warning = log([Tag.warning])
export let error = log([Tag.error])

export let logger = defaultLogger
