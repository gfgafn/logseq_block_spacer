@@config(no_export)

let _ = LogseqSDK.logseqLibs

module App = LogseqSDK.AppProxy
module Editor = LogseqSDK.EditorProxy
module UI = LogseqSDK.UIProxy
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

let handleChildrenBlocks = async (childrens: array<LogseqSDK.block_entity>): unit => {
  // Js.log2("childrens of current block: ", childrens)
  let insertContent = ""

  switch childrens {
  | [] => Js.log("no children in current block/page")
  | [oneChildren] => {
      if !(oneChildren.content == "") {
        "There only one children and it is not empty, insert a block after this block"->Js.log

        editor
        ->Editor.insertBlock(
          ~srcBlock=oneChildren.uuid,
          ~content=insertContent,
          ~opts={before: true},
          (),
        )
        ->ignore
      }

      Js.log2("There only one children in current block/page: ", oneChildren)
    }
  | manyChildrens => {
      // Js.log2("many childrens in current block/page: ", manyChildrens)

      let (firstChildren, secondChildren) = (
        manyChildrens->Js.Array2.unsafe_get(0),
        manyChildrens->Js.Array2.unsafe_get(1),
      )

      let (firstBlockIsEmpty, secondBlockIsEmpty) = (
        firstChildren.content == "",
        secondChildren.content == "",
      )

      switch (firstBlockIsEmpty, secondBlockIsEmpty) {
      | (true, _) => "first children is empty, keep it, do nothing"->Js.log
      | (false, _) if !(await firstChildren->hasBuiltInProperty) => {
          "first children is not empty and has no built-in property,\
           insert a block before this block"->Js.Console.info

          editor
          ->Editor.insertBlock(
            ~srcBlock=firstChildren.uuid,
            ~content=insertContent,
            ~opts={before: true},
            (),
          )
          ->ignore
        }
      | (false, false) /* and firstChildren->hasBuiltInProperty */ => {
          "first children has built-in property and second children are not empty, \
          insert a block after first children block"->Js.Console.info

          editor
          ->Editor.insertBlock(
            ~srcBlock=firstChildren.uuid,
            ~content=insertContent,
            ~opts={sibling: true},
            (),
          )
          ->ignore
        }
      | (false, true) /* and firstChildren->hasBuiltInProperty */ =>
        "first children has built-in property, second children is empty, keep it,\
         do nothing"->Js.Console.info
      }
    }
  }
}

let getTodayJournalPageEntity = async (): option<LogseqSDK.page_entity> => {
  let userConfig = await logseqApp->App.getUserConfig

  // Js.log2("userConfig: ", userConfig)

  if !userConfig.enabledJournals {
    // Js.log("enabledJournals is false")
    None
  } else {
    // Js.log("enabledJournals is true")

    let currentGraphUrl = {
      let currentGraph = (await logseqApp->App.getCurrentGraph)->Js.Null.toOption
      switch currentGraph {
      | Some(currentGraph) => currentGraph.url
      | None =>
        logseq
        ->LogseqSDK.ui
        ->UI.showMsg(
          ~content="Can't get current graph, please open a graph first",
          ~status=#error,
          (),
        )
        ->ignore

        GraphURL("")
      }
    }
    // Js.log2("current graph url: ", currentGraphUrl)

    let allPages =
      (await editor
      ->Editor.getAllPages(~repo=currentGraphUrl, ()))
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

let getTodayJournalPageEntityMemo: unit => promise<option<LogseqSDK.page_entity>> = (
  () => {
    let cache: ref<option<LogseqSDK.page_entity>> = ref(None)
    let todayJournalDay: ref<option<float>> = ref(None)

    logseqApp
    ->App.onTodayJournalCreated(_ => {
      todayJournalDay := None
    })
    ->ignore

    async () => {
      if cache.contents->Belt.Option.isSome && todayJournalDay.contents->Belt.Option.isSome {
        cache.contents
      } else {
        let todayJournalPageEntity = await getTodayJournalPageEntity()

        cache := todayJournalPageEntity
        todayJournalDay := Some(Js.Date.make()->date2JournalDay)

        todayJournalPageEntity
      }
    }
  }
)()

let handleJournalPage = async (): unit => {
  // "Home/Journal page"->Js.log

  let todayJournalPageEntity = await getTodayJournalPageEntityMemo()
  // Js.log2("today journal page: ", todayJournalPageEntity)

  let todayJournalPageUuid =
    todayJournalPageEntity->Belt.Option.mapWithDefaultU(LogseqSDK.BlockUUID(""), (. page) =>
      page.uuid
    )

  let childrenBlocks = await editor->Editor.getPageBlocksTree(todayJournalPageUuid)

  childrenBlocks->handleChildrenBlocks->ignore
}

let handleNamedPage = async (): unit => {
  let blockEntity = (await editor->Editor.getCurrentPage)->Js.Null.toOption->Belt.Option.getExn

  switch blockEntity->BlockOrPageEntity.classify {
  | BlockEntity(blockEntity) => {
      let block =
        (await editor
        ->Editor.getBlock(blockEntity.uuid, ~opts={includeChildren: true}))
        ->Js.Null.toOption
        ->Belt.Option.getExn
      // Js.log2("block entity, blocks of this block: ", blocks)

      await block.children->Belt.Option.mapWithDefaultU([], (. c) => c)->handleChildrenBlocks
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
