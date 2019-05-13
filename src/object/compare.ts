export function shallowCompare(a:any, b:any)
{
    if(a == b)
        return true;

    for(const k of a)
        if(b[k] != a[k])
            return false;
    
    for(const k of b)
        if(b[k] != a[k])
            return false;

    return false;
}