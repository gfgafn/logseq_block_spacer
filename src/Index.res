let _ = LogseqBindings.logseqLibs

/** Binding of global namespace `logseq` */
@val
external logseq: LogseqBindings.LSPluginUser.t = "logseq"

module LSPluginUser = LogseqBindings.LSPluginUser
module UIProxy = LogseqBindings.UIProxy

let main = () => {
  let content = "Hello World from Logseq"
  logseq->LSPluginUser.ui->UIProxy.showMsg(~content)->ignore
}

try {
  logseq->LSPluginUser.ready(~callback=main)->ignore
} catch {
| Js.Exn.Error(err) => Js.Console.error(err)
}
