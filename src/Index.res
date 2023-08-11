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

let handleChildrenBlocks = async (
  parentUuid: LogseqSDK.block_uuid,
  childrenBlocks: array<LogseqSDK.block_entity>,
): unit => {
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
        Js.log(
          "first block has no built-in property, insert a block to parent block with before option",
        )

        // HACK: insert a block to parent block with before option
        editor
        ->Editor.insertBlock(~srcBlock=parentUuid, ~content=insertContent, ~opts={before: true}, ())
        ->ignore

        // Don't use: if the first block is the first block of a page, the inserted block will be inserted as a child of the first block
        // // editor
        // // ->Editor.insertBlock(
        // //   ~srcBlock=firstBlock.uuid,
        // //   ~content=insertContent,
        // //   ~opts={before: true},
        // //   (),
        // // )
        // // ->ignore
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

let getTodayJournalPageEntity = async (
  graphUrl: LogseqSDK.graph_url,
  userConfig: LogseqSDK.app_user_config,
): option<LogseqSDK.page_entity> => {
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

let getCachedTodayPageUuid: LogseqSDK.graph_url => promise<option<LogseqSDK.block_uuid>> = {
  // FIXME: open a graph then unlink it, the uuid may be regenerated, make the cache invalid
  let cache: ref<Js.Dict.t<option<LogseqSDK.block_uuid>>> = ref(Js.Dict.empty())
  let todayJournalDay: ref<option<float>> = ref(None)

  // register callback by `onTodayJournalCreated` and `onGraphAfterIndexed`
  // before the `logseq.ready` callback was called will not work,
  // so register them in `getCachedTodayPageUuidMemo` and use this flag to make sure they are only registered once
  let hasAddedCallback = ref(false)

  async (graphUrl: LogseqSDK.graph_url) => {
    if !hasAddedCallback.contents {
      logseqApp
      ->App.onTodayJournalCreated(_ => {
        todayJournalDay := None
        cache := Js.Dict.empty()
      })
      ->ignore

      logseqApp
      ->App.onGraphAfterIndexed(callBackArg => {
        let LogseqSDK.GraphURL(graphUrlStr: string) = callBackArg["repo"]
        `graph ${graphUrlStr} indexed`->Js.log
        cache.contents->Js.Dict.set(graphUrlStr, None)
      })
      ->ignore

      hasAddedCallback := true
    }

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

      let todayJournalPageEntityUuid: option<_> =
        (await getTodayJournalPageEntity(graphUrl, userConfig))->Belt.Option.mapU((. page) =>
          page.uuid
        )

      cache.contents->Js.Dict.set(graphUrlStr, todayJournalPageEntityUuid)

      todayJournalPageEntityUuid
    }
  }
}

let handleJournalPage = async (): unit => {
  // "Home/Journal page"->Js.log

  let currentGraphUrl: option<_> =
    (await logseqApp
    ->App.getCurrentGraph)
    ->Js.Null.toOption
    ->Belt.Option.mapU((. graph) => graph.url)

  switch currentGraphUrl {
  | None => "current graph is none"->Js.log
  | Some(currentGraphUrl) => {
      let todayJournalPageUuid = await getCachedTodayPageUuid(currentGraphUrl)

      switch todayJournalPageUuid {
      | None => "today journal page uuid is none"->Js.log
      | Some(todayJournalPageUuid) => {
          let childrenBlocks =
            (await editor
            ->Editor.getPageBlocksTree(todayJournalPageUuid))
            ->Js.Null.toOption
            ->Belt.Option.mapWithDefaultU([], (. blocks) => blocks)

          handleChildrenBlocks(todayJournalPageUuid, childrenBlocks)->ignore
        }
      }
    }
  }
}

let handleNamedPageOrExistingBlock = async (blockOrPageEntity): unit => {
  switch blockOrPageEntity->BlockOrPageEntity.classify {
  | BlockEntity(blockEntity) => {
      let currentBlock =
        (await editor
        ->Editor.getBlock(blockEntity.uuid, ~opts={includeChildren: true}))
        ->Js.Null.toOption
        ->Belt.Option.getExn
      // Js.log2("block entity, blocks of this block: ", currentBlock)

      await handleChildrenBlocks(
        blockEntity.uuid,
        currentBlock.children->Belt.Option.mapWithDefaultU([], (. c) => c),
      )
    }
  | PageEntity(pageEntity) => {
      // Js.log2("page entity, pageEntity: ", pageEntity)

      let blocksTree =
        (await editor
        ->Editor.getPageBlocksTree(pageEntity.uuid))
        ->Js.Null.toOption
        ->Belt.Option.getExn
      // Js.log2("tree of this page: ", blocksTree)

      await handleChildrenBlocks(pageEntity.uuid, blocksTree)
    }
  }
}

let handleHomePage = () => {
  logseqApp
  ->App.getUserConfig
  ->Js.Promise2.then(userConfig => {
    if userConfig.enabledJournals {
      handleJournalPage()
    } else {
      editor
      ->Editor.getCurrentPage
      ->Js.Promise2.then(entity => {
        let blockOrPageEntity = entity->Js.Null.toOption->Belt.Option.getExn
        handleNamedPageOrExistingBlock(blockOrPageEntity)
      })
    }
  })
  ->ignore
}

let main = async (_baseInfo: Plugin.base_info): unit => {
  // `onRouteChanged` callback not only called when route in the same graph changed,
  //  but also called when switch to another graph
  logseqApp
  ->App.onRouteChanged(obj => {
    // Js.log2("\nOnRouteChanged callback argument: ", obj)

    let (_path, template) = (obj["path"], obj["template"])
    switch template {
    | "/" => handleHomePage()->ignore
    | "/page/:name" =>
      editor
      ->Editor.getCurrentPage
      ->Js.Promise2.then(entity => {
        let blockOrPageEntity = entity->Js.Null.toOption->Belt.Option.getExn
        handleNamedPageOrExistingBlock(blockOrPageEntity)
      })
      ->ignore
    | _ => ignore()
    }
  })
  ->ignore

  handleHomePage()->ignore
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
