// Generated by ReScript, PLEASE EDIT WITH CARE

import * as Js_exn from "rescript/lib/es6/js_exn.js";
import * as Libs from "@logseq/libs";
import * as Caml_js_exceptions from "rescript/lib/es6/caml_js_exceptions.js";

function main(param) {
  logseq.UI.showMsg("Hello World from Logseq");
}

try {
  logseq.ready(main);
}
catch (raw_err){
  var err = Caml_js_exceptions.internalToOCamlException(raw_err);
  if (err.RE_EXN_ID === Js_exn.$$Error) {
    console.error(err._1);
  } else {
    throw err;
  }
}

export {
  
}
/*  Not a pure module */