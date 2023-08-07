/*** Binding of [Logseq SDK libraries](https://github.com/logseq/logseq/tree/ac1b53544466dedd80b4c9c54479ced63983e022/libs) */

@module external logseqLibs: 'a = "@logseq/libs"

/** 
 * Abstract type of `logseq` global namespace
 * It's isolated in plugin runtime, it is not the same as `logseq` in browser console.
 */
type logseq

/** Binding of global namespace `logseq` */
@val
@scope("window")
external logseq: logseq = "logseq"

@unboxed type graph_url = GraphURL(string)

/** Binding of `interface IUIProxy{...}` */
module UIProxy: {
  type t
  @unboxed type ui_message_key = UIMsgKey(string)
  type partial_ui_msg_options = {
    key?: ui_message_key,
    timeout?: float,
  }

  let showMsg: (
    t,
    ~content: string,
    ~status: [#success | #warning | #error | #info]=?,
    ~opts: partial_ui_msg_options=?,
    unit,
  ) => promise<ui_message_key>

  @send external closeMsg: (t, ui_message_key) => unit = "closeMsg"
} = {
  type t
  @unboxed type ui_message_key = UIMsgKey(string)
  type partial_ui_msg_options = {
    key?: ui_message_key,
    timeout?: float,
  }

  @send
  external showMsg_: (
    t,
    ~content: string,
    ~status: [#success | #warning | #error | #info]=?,
    ~opts: option<partial_ui_msg_options>=?,
    unit,
  ) => promise<ui_message_key> = "showMsg"

  let showMsg = (
    logseq: t,
    ~content: string,
    // https://github.com/logseq/logseq/blob/458ac81cb412cd309f45e8dd507f1e2d6c5ea1aa/src/main/logseq/sdk/ui.cljs#L15-L25
    ~status: [#success | #warning | #error | #info]=#success,
    ~opts: option<partial_ui_msg_options>=?,
    (),
  ) => showMsg_(logseq, ~content, ~status, ~opts, ())

  @send external closeMsg: (t, ui_message_key) => unit = "closeMsg"
}

@unboxed type entity_id = EntityID(float)
@unboxed type block_uuid = BlockUUID(string)

type rec block_entity = {
  id: entity_id,
  uuid: block_uuid,
  content: string,
  page: {"id": float},
  // TODO: children?: Array<BlockEntity | BlockUUIDTuple>;
  children?: array<block_entity>,
}

type page_entity = {
  id: entity_id,
  uuid: block_uuid,
  name: string,
  originalName: string,
  @as("journal?") isJournal: bool,
  journalDay?: float,
}

module BlockOrPageEntity: {
  type t
  type case = BlockEntity(block_entity) | PageEntity(page_entity)

  let classify: t => case
} = {
  type t
  type case = BlockEntity(block_entity) | PageEntity(page_entity)

  let isBlockEntity: t => bool = %raw(`v => ["content", "page"].every(k => Object.prototype.hasOwnProperty.call(v, k))`)

  let classify = (v: t): case => {
    if isBlockEntity(v) {
      BlockEntity((Obj.magic(v): block_entity))
    } else {
      PageEntity((Obj.magic(v): page_entity))
    }
  }
}

/** Binding of `interface IEditorProxy{...}` */
module EditorProxy = {
  type t
  type insertBlockOpts = {
    before?: bool,
    sibling?: bool,
    isPageBlock?: bool,
    focus?: bool,
    customUUID?: string,
    properties?: Js.Dict.t<string>,
  }
  type getBlockOpts = {includeChildren?: bool}

  @send
  external exitEditingMode: (t, ~selectBlock: bool=?, unit) => promise<unit> = "exitEditingMode"
  @send external getCurrentBlock: t => promise<Js.Null.t<block_entity>> = "getCurrentBlock"
  @send
  external getSelectedBlocks: t => promise<Js.Null.t<array<block_entity>>> = "getSelectedBlocks"
  @send
  external getCurrentPage: t => promise<Js.Null.t<BlockOrPageEntity.t>> = "getCurrentPage"
  @send
  external getCurrentPageBlocksTree: t => promise<array<block_entity>> = "getCurrentPageBlocksTree"
  @send
  external getPageBlocksTree: (t, block_uuid) => promise<array<block_entity>> = "getPageBlocksTree"
  @send external newBlockUUID: t => promise<string> = "newBlockUUID"
  @send
  external insertBlock: (
    t,
    ~srcBlock: block_uuid=?,
    ~content: string=?,
    ~opts: insertBlockOpts=?,
    unit,
  ) => promise<Js.Null.t<block_entity>> = "insertBlock"
  @send external removeBlock: (t, block_uuid) => promise<unit> = "removeBlock"
  @send
  external getBlock: (t, block_uuid, ~opts: getBlockOpts=?) => promise<Js.Null.t<block_entity>> =
    "getBlock"
  @send
  external getPage: (t, block_uuid, ~opts: getBlockOpts=?, unit) => promise<page_entity> = "getPage"
  @send
  external getAllPages: (t, ~repo: graph_url=?, unit) => promise<Js.Null.t<array<page_entity>>> =
    "getAllPages"
  @send
  external prependBlockInPage: (t, block_uuid, string, unit) => promise<Js.Null.t<block_entity>> =
    "prependBlockInPage"
  @send
  external appendBlockInPage: (t, block_uuid, string, unit) => promise<Js.Null.t<block_entity>> =
    "appendBlockInPage"
  @send
  external getPreviousSiblingBlock: (t, block_uuid) => promise<Js.Null.t<block_entity>> =
    "getPreviousSiblingBlock"
  @send
  external getNextSiblingBlock: (t, block_uuid) => promise<Js.Null.t<block_entity>> =
    "getNextSiblingBlock"
  @send external getBlockProperty: (t, block_uuid, string) => promise<'a> = "getBlockProperty"
  @send
  external getBlockProperties: (t, block_uuid) => promise<Js.Null.t<Js.Dict.t<'a>>> =
    "getBlockProperties"
}

module StringOrBool = {
  type t
  type case = String(string) | Bool(bool)

  let classify: t => case = v => {
    if %raw(`(v) => typeof v === "string"`)(v) {
      String((Obj.magic(v): string))
    } else {
      Bool((Obj.magic(v): bool))
    }
  }
}

type app_user_config = {
  preferredDateFormat: string,
  enabledJournals: bool,
}

type app_graph_info = {
  name: string,
  path: string,
  url: graph_url,
}

/** Binding of `interface IAppProxy{...}` */
module AppProxy = {
  type t
  type user_off_hook = (. unit) => unit
  // https://github.com/logseq/logseq/blob/master/src/main/frontend/state.cljs#L29
  type state = [#"sidebar/blocks"]

  @send external getUserConfig: t => promise<app_user_config> = "getUserConfigs"
  @send external getStateFromStore: (t, array<state>) => promise<'a> = "getStateFromStore"
  @send external getCurrentGraph: t => promise<Js.Null.t<app_graph_info>> = "getCurrentGraph"
  @send external queryElementById: (t, string) => promise<StringOrBool.t> = "queryElementById"
  // TODO: return type is `DOMRectReadOnly`
  @send
  external queryElementRect: (t, string) => promise<{"x": float, "y": float}> = "queryElementRect"
  @send
  external onCurrentGraphChanged: (t, {.} => unit) => user_off_hook = "onCurrentGraphChanged"
  @send
  external onGraphAfterIndexed: (t, {"repo": graph_url} => unit) => user_off_hook =
    "onGraphAfterIndexed"
  @send
  external onTodayJournalCreated: (t, {"title": string} => unit) => user_off_hook =
    "onTodayJournalCreated"
  @send
  external onRouteChanged: (t, {"path": string, "template": string} => unit) => user_off_hook =
    "onRouteChanged"
  @send
  external onSidebarVisibleChanged: (t, {"visible": bool} => unit) => user_off_hook =
    "onSidebarVisibleChanged"
}

/** Binding of `interface ILSPluginUser{...}`
 *  `UI`, `Editor`, `App` method was moved to top level for more clear usage.  
 */
module LSUserPlugin = {
  type t = logseq
  type base_info = {
    id: string,
    name: string,
    title: string,
    settings: {"disabled": bool},
  }

  @send external ready: (t, ~callback: base_info => unit=?) => promise<'b> = "ready"
  @get external isMainUIVisible: t => bool = "isMainUIVisible"
  @send external showMainUI: (t, ~opts: {"autoFocus": bool}=?, unit) => unit = "showMainUI"
  @send
  external hideMainUI: (t, ~opts: {"restoreEditingCursor": bool}=?, unit) => unit = "hideMainUI"
  @send external toggleMainUI: t => unit = "toggleMainUI"
  @send external beforeUnload: (t, unit => promise<unit>) => unit = "beforeunload"
}

@get external ui: logseq => UIProxy.t = "UI"
@get external editor: logseq => EditorProxy.t = "Editor"
@get external app: logseq => AppProxy.t = "App"
