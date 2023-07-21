let _ = LogseqBindings.logseqLibs

module UI = LogseqBindings.UIProxy

let main: unit => promise<unit> = async () => {
  // NOTE: must get `logseq` after `logseq.ready` or `logseq` will be `undefined`
  let {logseq} = module(LogseqBindings)

  let content = "Hello World from Logseq"
  logseq->LogseqBindings.ui->UI.showMsg(~content, ~status=#success, ())->ignore
}

try {
  LogseqBindings.logseq->LogseqBindings.ready(~callback=() => main()->ignore)->ignore
} catch {
| Js.Exn.Error(err) => Js.Console.error(err)
}
