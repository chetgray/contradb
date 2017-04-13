function set_if_unset (dict, key, value) {
    if (!(key in dict))
        dict[key] = value;
}

// take words, put them in strings, return a big, space separated string of them all. 
function words() {
    if (arguments.length <= 0) return "";
    else {
        var acc = arguments[0];
        var i;
        for (i=1; i<arguments.length; i++)
            acc += " " + arguments[i];
        return acc;
    }
}

// Patch to support current IE, source http://stackoverflow.com/questions/31720269/internet-explorer-11-object-doesnt-support-property-or-method-isinteger
isInteger = Number.isInteger || function(value) {
    return typeof value === "number" && 
           isFinite(value) && 
           Math.floor(value) === value;
};

// throw is a keyword and can't be in expressions, but function calls can be, so wrap throw.
function throw_up(str) {
    throw new Error(str)
}
