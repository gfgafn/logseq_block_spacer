@@config(no_export)

let _ = LogseqSDK.logseqLibs

module App = LogseqSDK.AppProxy
module Editor = LogseqSDK.EditorProxy
module Plugin = LogseqSDK.LSUserPlugin
module BlockOrPageEntity = LogseqSDK.BlockOrPageEntity

let {logseq} = module(LogseqSDK)
let editor = logseq->LogseqSDK.editor
let logseqApp = logseq->LogseqSDK.app

/** `Js.Date.t` => `float` of journal day like `20230102` */
let date2JournalDay: Js.Date.t => float = %raw(` 
  function (date) {
    const year = date.getFullYear().toString();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');

    const dateString = year + month + day;

    return Number(dateString);
  }
`)

let hasBuiltInProperty = async (block: LogseqSDK.block_entity): bool => {
  let properties: Js.Dict.t<'a> =
    (await logseq
    ->LogseqSDK.editor
    ->Editor.getBlockProperties(block.uuid))
    ->Js.Null.toOption
    ->Belt.Option.mapWithDefaultU(Js.Dict.empty(), (. p) => p)

  // Js.log2("properties: ", properties)

  // https://docs.logseq.com/#/page/built-in%20properties
  let includeBuiltInEditableProperty: Js.Dict.t<'a> => bool = %raw(`  
    function (blockProperty) {
      return ["icon", "title", "tags", "template", "template-including-parent",
        "alias", "filters", "public", "exclude-from-graph-view"]
        .some(k => Object.prototype.hasOwnProperty.call(blockProperty, k))
    }
  `)

  properties->includeBuiltInEditableProperty
}

let handleChildrenBlocks = async (childrenBlocks: array<LogseqSDK.block_entity>): unit => {
  // Js.log2("childrenBlocks of current block/page: ", childrenBlocks)
  let insertContent = ""

  switch childrenBlocks->Belt.Array.get(0) {
  | None => Js.log("no children in current block/page")
  | Some(firstBlock) =>
    if firstBlock.content == "" {
      Js.log("first block is empty, do nothing")
    } else {
      Js.log2("first block is not empty: ", firstBlock)

      if !(await firstBlock->hasBuiltInProperty) {
        Js.log("first block has no built-in property, insert a block before first block")

        editor
        ->Editor.insertBlock(
          ~srcBlock=firstBlock.uuid,
          ~content=insertContent,
          ~opts={before: true},
          (),
        )
        ->ignore
      } else {
        Js.log("first block has built-in property")

        switch childrenBlocks->Belt.Array.get(1) {
        | None => {
            Js.log("there is not a second block, insert a block after first block")

            editor
            ->Editor.insertBlock(
              ~srcBlock=firstBlock.uuid,
              ~content=insertContent,
              ~opts={sibling: true},
              (),
            )
            ->ignore
          }
        | Some(secondBlock) =>
          if secondBlock.content == "" {
            Js.log("second block is empty, do nothing")
          } else {
            Js.log("second block is not empty, insert a block after first block")

            editor
            ->Editor.insertBlock(
              ~srcBlock=firstBlock.uuid,
              ~content=insertContent,
              ~opts={sibling: true},
              (),
            )
            ->ignore

            // don't use the following commented code, because first has built-in property,
            // the inserted block will not insert before second block, but insert as a child of second block
            // // editor
            // // ->Editor.insertBlock(
            // //   ~srcBlock=secondBlock.uuid,
            // //   ~content=insertContent,
            // //   ~opts={before: true},
            // //   (),
            // // )
            // // ->ignore
          }
        }
      }
    }
  }
}

let getTodayJournalPageEntity = async (graphUrl: LogseqSDK.graph_url): option<
  LogseqSDK.page_entity,
> => {
  let userConfig = await logseqApp->App.getUserConfig

  // Js.log2("userConfig: ", userConfig)

  if !userConfig.enabledJournals {
    // Js.log("enabledJournals is false")
    None
  } else {
    // Js.log("enabledJournals is true")

    let allPages =
      (await editor
      ->Editor.getAllPages(~repo=graphUrl, ()))
      ->Js.Null.toOption
      ->Belt.Option.mapWithDefaultU([], (. page) => page)

    let journalPages = allPages->Js.Array2.filter(page => page.isJournal)
    // Js.log2("journal pages: ", journalPages)

    let todayJournalDay = Js.Date.make()->date2JournalDay

    let todayJournalPageEntity =
      journalPages->Js.Array2.find(journalPage =>
        journalPage.journalDay->Belt.Option.getExn == todayJournalDay
      )

    // Js.log2("todayJournalPageEntity: ", todayJournalPageEntity)

    todayJournalPageEntity
  }
}

let getCachedTodayPageUuidMemo: LogseqSDK.graph_url => promise<option<LogseqSDK.block_uuid>> = {
  // FIXME: open a graph then unlink it, the uuid may be regenerated, make the cache invalid
  let cache: ref<Js.Dict.t<option<LogseqSDK.block_uuid>>> = ref(Js.Dict.empty())
  let todayJournalDay: ref<option<float>> = ref(None)

  logseqApp
  ->App.onTodayJournalCreated(_ => {
    todayJournalDay := None
    cache := Js.Dict.empty()
  })
  ->ignore

  async (graphUrl: LogseqSDK.graph_url) => {
    let userConfig = await logseqApp->App.getUserConfig
    let LogseqSDK.GraphURL(graphUrlStr: string) = graphUrl

    if (
      userConfig.enabledJournals &&
      todayJournalDay.contents->Belt.Option.isSome &&
      cache.contents->Js.Dict.get(graphUrlStr)->Belt.Option.isSome
    ) {
      cache.contents->Js.Dict.get(graphUrlStr)->Belt.Option.getExn
    } else {
      todayJournalDay := Some(Js.Date.make()->date2JournalDay)

      let todayJournalPageEntityUuid =
        (await getTodayJournalPageEntity(graphUrl))->Belt.Option.mapU((. page) => page.uuid)

      cache.contents->Js.Dict.set(graphUrlStr, todayJournalPageEntityUuid)

      todayJournalPageEntityUuid
    }
  }
}

let handleJournalPage = async (): unit => {
  // "Home/Journal page"->Js.log

  let currentGraphUrl =
    (await logseqApp
    ->App.getCurrentGraph)
    ->Js.Null.toOption
    ->Belt.Option.mapU((. graph) => graph.url)

  switch currentGraphUrl {
  | None => "current graph is none"->Js.log
  | Some(currentGraphUrl) => {
      let todayJournalPageUuid = await getCachedTodayPageUuidMemo(currentGraphUrl)

      switch todayJournalPageUuid {
      | None => "today journal page uuid is none"->Js.log
      | Some(todayJournalPageUuid) => {
          let childrenBlocks = await editor->Editor.getPageBlocksTree(todayJournalPageUuid)

          childrenBlocks->handleChildrenBlocks->ignore
        }
      }
    }
  }
}

let handleNamedPage = async (): unit => {
  let entity = (await editor->Editor.getCurrentPage)->Js.Null.toOption->Belt.Option.getExn

  switch entity->BlockOrPageEntity.classify {
  | BlockEntity(blockEntity) => {
      let currentBlock =
        (await editor
        ->Editor.getBlock(blockEntity.uuid, ~opts={includeChildren: true}))
        ->Js.Null.toOption
        ->Belt.Option.getExn
      // Js.log2("block entity, blocks of this block: ", currentBlock)

      await currentBlock.children->Belt.Option.mapWithDefaultU([], (. c) => c)->handleChildrenBlocks
    }
  | PageEntity(pageEntity) => {
      // Js.log2("page entity, pageEntity: ", pageEntity)

      let blocksTree = await editor->Editor.getPageBlocksTree(pageEntity.uuid)
      // Js.log2("tree of this page: ", blocksTree)

      await blocksTree->handleChildrenBlocks
    }
  }
}

let main = async (_baseInfo: Plugin.base_info): unit => {
  logseqApp
  ->App.onRouteChanged(obj => {
    // Js.log2("\nOnRouteChanged callback argument: ", obj)

    let (_path, template) = (obj["path"], obj["template"])
    switch template {
    | "/" => handleJournalPage()->ignore
    | "/page/:name" => handleNamedPage()->ignore
    | _ => ignore()
    }
  })
  ->ignore

  handleJournalPage()->ignore
}

try {
  logseq
  ->Plugin.ready(~callback=baseInfo => {
    open Js.Promise2

    main(baseInfo)
    ->then(_ => {
      `The plugin "${baseInfo.title}" which id is "${baseInfo.id}" has load`->Js.Console.info

      resolve()
    })
    ->catch(err => {
      `Can't load the plugin ${baseInfo.title} which id is "${baseInfo.id}"`->Js.Console.error2(err)

      resolve()
    })
    ->ignore
  })
  ->ignore
} catch {
| Js.Exn.Error(err) => Js.Console.error(err)
}
