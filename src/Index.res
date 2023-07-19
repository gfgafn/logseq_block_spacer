@module external logseqLibs: 'a = "@logseq/libs"

let _ = logseqLibs

type ls_plugin_user
@val external logseq: ls_plugin_user = "logseq"
@send external ready: (ls_plugin_user, ~callback: 'a => unit=?) => promise<'b> = "ready"

type ui_proxy
@get external ui: ls_plugin_user => ui_proxy = "UI"
@send external showMsg: (ui_proxy, ~content: string) => unit = "showMsg"

let main = () => {
  let content = "Hello World from Logseq"
  logseq->ui->showMsg(~content)->ignore
}

try {
  logseq->ready(~callback=main)->ignore
} catch {
| Js.Exn.Error(err) => Js.Console.error(err)
}
