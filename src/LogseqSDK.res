/*** Binding of [Logseq SDK libraries](https://github.com/logseq/logseq/tree/ac1b53544466dedd80b4c9c54479ced63983e022/libs) */

@module external logseqLibs: 'a = "@logseq/libs"

/** 
 * Abstract type of `logseq` global namespace
 * It's isloated in plugin runtime, it is not the same as `logseq` in browser console.
 */
type logseq

/** Binding of global namespace `logseq` */
@val
@scope("window")
external logseq: logseq = "logseq"

/** Binding of `interface IUIProxy{...}` */
module UIProxy = {
  type t
  @unboxed type ui_message_key = UIMsgKey(string)
  type partial_ui_msg_options = {
    key?: ui_message_key,
    timeout?: float,
  }

  @send
  external showMsg: (
    t,
    ~content: string,
    // https://github.com/logseq/logseq/blob/ac1b53544466dedd80b4c9c54479ced63983e022/src/main/frontend/ui.cljs#L219-L229
    ~status: [#success | #warning | #error | #info]=?,
    ~opts: partial_ui_msg_options=?,
    unit,
  ) => promise<ui_message_key> = "showMsg"
  @send external closeMsg: (t, ui_message_key) => unit = "closeMsg"
}

@unboxed type entity_id = EntityID(float)
@unboxed type block_uuid = BlockUUID(string)

type block_entity = {
  id: entity_id,
  uuid: block_uuid,
  content: string,
  page: {"id": float},
}

type page_entity = {
  id: entity_id,
  uuid: block_uuid,
  name: string,
  originalName: string,
  \"journal?": bool,
  journalDay?: bool,
}

module BlockOrPageEntity: {
  type t
  type case = BlockEntity(block_entity) | PageEntity(page_entity)

  let classify: t => case
} = {
  type t
  type case = BlockEntity(block_entity) | PageEntity(page_entity)

  let isBlockEntity: t => bool = v =>
    %raw(`v => ["content", "page"].every(k => Object.prototype.hasOwnProperty.call(v, k))`)(v)

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

  @sned
  external exitEditingMode: (t, ~selectBlock: bool=?, unit) => promise<unit> = "exitEditingMode"
  @send external getCurrentBlock: (t, unit) => promise<Js.Null.t<block_entity>> = "getCurrentBlock"
  @send
  external getSelectedBlocks: (t, unit) => promise<Js.Null.t<array<block_entity>>> =
    "getSelectedBlocks"
  @send
  external getCurrentPage: (t, unit) => promise<Js.Null.t<BlockOrPageEntity.t>> = "getCurrentPage"
  @send
  external getCurrentPageBlocksTree: (t, unit) => promise<array<block_entity>> =
    "getCurrentPageBlocksTree"
  @send external newBlockUUID: (t, unit) => promise<string> = "newBlockUUID"
  @send
  external insertBlock: (
    t,
    ~srcBlock: BlockOrPageEntity.t=?,
    ~content: string=?,
    ~opts: insertBlockOpts=?,
    unit,
  ) => promise<Js.Null.t<block_entity>> = "insertBlock"
  @send
  external getAllPages: (t, ~repo: string=?, unit) => promise<Js.Null.t<array<page_entity>>> =
    "getAllPages"
  @send external getBlockProperty: (t, block_uuid, string) => promise<'a> = "getBlockProperty"
  @send external getBlockProperties: (t, block_uuid) => promise<'a> = "getBlockProperties"
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

type app_user_config = {perferrredDateFormat: string}

/** Binding of `interface IAppProxy{...}` */
module AppProxy = {
  type t

  @send external getUserConfig: (t, unit) => promise<app_user_config> = "getUserConfigs"
  @send external queryElementById: (t, string) => promise<StringOrBool.t> = "queryElementById"
  // TODO: return type is `DOMRectReadOnly`
  @send
  external queryElementRect: (t, string) => promise<{"x": float, "y": float}> = "queryElementRect"
  @send
  external onRouteChanged: (t, {"path": string, "template": string} => unit) => unit =
    "onRouteChanged"
  @send
  external onSidebarVisibleChanged: (t, {"visible": bool} => unit) => unit =
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
  @send external toggleMainUI: (t, unit) => unit = "toggleMainUI"
  @send external beforeunload: (t, unit => promise<unit>) => unit = "beforeunload"
}

@get external ui: logseq => UIProxy.t = "UI"
@get external editor: logseq => EditorProxy.t = "Editor"
@get external app: logseq => AppProxy.t = "App"
