// Generated by ReScript, PLEASE EDIT WITH CARE


var UIProxy = {};

function isBlockEntity(v) {
  return (v => ["content", "page"].every(k => Object.prototype.hasOwnProperty.call(v, k)))(v);
}

function classify(v) {
  if (isBlockEntity(v)) {
    return {
            TAG: /* BlockEntity */0,
            _0: v
          };
  } else {
    return {
            TAG: /* PageEntity */1,
            _0: v
          };
  }
}

var BlockOrPageEntity = {
  classify: classify
};

var EditorProxy = {};

function classify$1(v) {
  if (((v) => typeof v === "string")(v)) {
    return {
            TAG: /* String */0,
            _0: v
          };
  } else {
    return {
            TAG: /* Bool */1,
            _0: v
          };
  }
}

var StringOrBool = {
  classify: classify$1
};

var AppProxy = {};

var LSUserPlugin = {};

export {
  UIProxy ,
  BlockOrPageEntity ,
  EditorProxy ,
  StringOrBool ,
  AppProxy ,
  LSUserPlugin ,
}
/* No side effect */
