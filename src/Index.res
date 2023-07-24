@@config(no_export)

let _ = LogseqSDK.logseqLibs

module UI = LogseqSDK.UIProxy
module Plugin = LogseqSDK.LSUserPlugin

let {logseq} = module(LogseqSDK)

let main: unit => promise<unit> = async () => {
  let content = "Hello World from Logseq"
  logseq->LogseqSDK.ui->UI.showMsg(~content, ~status=#success, ())->ignore
}

try {
  logseq->Plugin.ready(~callback=() => main()->ignore)->ignore
} catch {
| Js.Exn.Error(err) => Js.Console.error(err)
}
