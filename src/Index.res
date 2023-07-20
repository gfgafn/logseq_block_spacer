let _ = LogseqBindings.logseqLibs

/** Binding of global namespace `logseq` */
@val
external logseq: LogseqBindings.LSPluginUser.t = "logseq"

module LSPluginUser = LogseqBindings.LSPluginUser
module UIProxy = LogseqBindings.UIProxy

let main = () => {
  let content = "logseq.UI.showMsg('something', undefined) don't work)"

  // don't work
  logseq->LSPluginUser.ui->UIProxy.showMsg(~content, ())->ignore

  // work and behavior like "success"
  let _ = %raw(`logseq.UI.showMsg("logseq.UI.showMsg('something') work")`)

  // work and behavior like "info"
  let _ = %raw(`logseq.UI.showMsg("logseq.UI.showMsg('something', 'any string') work", "any string")`)
}

try {
  logseq->LSPluginUser.ready(~callback=main)->ignore
} catch {
| Js.Exn.Error(err) => Js.Console.error(err)
}
