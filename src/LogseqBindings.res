/*** Binding of [Logseq SDK libraries](https://github.com/logseq/logseq/tree/ac1b53544466dedd80b4c9c54479ced63983e022/libs) */

@module external logseqLibs: 'a = "@logseq/libs"

module UIMsgOptions = {
  type key = string
  type timeout = float
}

/** Binding of `interface IUIProxy{...}` */
module UIProxy = {
  type t
  type ui_message_key = UIMsgOptions.key
  type partial_ui_msg_options = {
    key?: UIMsgOptions.key,
    timeout?: UIMsgOptions.timeout,
  }

  @send
  external showMsg: (
    t,
    ~content: string,
    // https://github.com/logseq/logseq/blob/ac1b53544466dedd80b4c9c54479ced63983e022/src/main/frontend/ui.cljs#L219-L229
    ~status: [
      | #success
      | #warning
      | #error
      | #info
    ]=?,
    ~opts: partial_ui_msg_options=?,
    unit,
  ) => promise<ui_message_key> = "showMsg"
}

/** Binding of `interface ILSPluginUser{...}` */
module LSPluginUser = {
  type t

  @send external ready: (t, ~callback: 'a => unit=?) => promise<'b> = "ready"
  @get external ui: t => UIProxy.t = "UI"
}
