export function assert (ok:boolean, f:()=>any) {
    if (!ok) { f() }
}