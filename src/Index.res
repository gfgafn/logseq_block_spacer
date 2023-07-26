@@config(no_export)

let _ = LogseqSDK.logseqLibs

module UI = LogseqSDK.UIProxy
module Plugin = LogseqSDK.LSUserPlugin

let {logseq} = module(LogseqSDK)

let main = async (_baseInfo: Plugin.base_info): unit => {
  let content = "Hello World from Logseq"
  logseq->LogseqSDK.ui->UI.showMsg(~content, ~status=#success, ())->ignore
}

try {
  logseq->Plugin.ready(~callback=e => main(e)->ignore)->ignore
} catch {
| Js.Exn.Error(err) => Js.Console.error(err)
}
