let _ = LogseqSDK.logseqLibs

module UI = LogseqSDK.UIProxy

let main: unit => promise<unit> = async () => {
  // NOTE: must get `logseq` after `logseq.ready` or `logseq` will be `undefined`
  let {logseq} = module(LogseqSDK)

  let content = "Hello World from Logseq"
  logseq->LogseqSDK.ui->UI.showMsg(~content, ~status=#success, ())->ignore
}

try {
  LogseqSDK.logseq->LogseqSDK.ready(~callback=() => main()->ignore)->ignore
} catch {
| Js.Exn.Error(err) => Js.Console.error(err)
}
