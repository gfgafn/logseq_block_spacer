// Generated by ReScript, PLEASE EDIT WITH CARE

import * as Js_exn from "rescript/lib/es6/js_exn.js";
import * as Js_dict from "rescript/lib/es6/js_dict.js";
import * as Belt_Array from "rescript/lib/es6/belt_Array.js";
import * as Belt_Option from "rescript/lib/es6/belt_Option.js";
import * as Caml_option from "rescript/lib/es6/caml_option.js";
import * as Js_promise2 from "rescript/lib/es6/js_promise2.js";
import * as Libs from "@logseq/libs";
import * as Caml_js_exceptions from "rescript/lib/es6/caml_js_exceptions.js";
import * as LogseqSDK$LogseqBlockSpacer from "./LogseqSDK.bs.js";

var logseq = window.logseq;

var editor = logseq.Editor;

var logseqApp = logseq.App;

var date2JournalDay = (function (date) {
    const year = date.getFullYear().toString();
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');

    const dateString = year + month + day;

    return Number(dateString);
  });

async function hasBuiltInProperty(block) {
  var properties = Belt_Option.mapWithDefaultU(Caml_option.null_to_opt(await logseq.Editor.getBlockProperties(block.uuid)), {}, (function (p) {
          return p;
        }));
  var includeBuiltInEditableProperty = (function (blockProperty) {
      return ["icon", "title", "tags", "template", "template-including-parent",
        "alias", "filters", "public", "exclude-from-graph-view"]
        .some(k => Object.prototype.hasOwnProperty.call(blockProperty, k))
    });
  return includeBuiltInEditableProperty(properties);
}

async function handleChildrenBlocks(childrenBlocks) {
  var insertContent = "";
  var firstBlock = Belt_Array.get(childrenBlocks, 0);
  if (firstBlock !== undefined) {
    if (firstBlock.content === "") {
      console.log("first block is empty, do nothing");
      return ;
    }
    console.log("first block is not empty: ", firstBlock);
    if (await hasBuiltInProperty(firstBlock)) {
      console.log("first block has built-in property");
      var secondBlock = Belt_Array.get(childrenBlocks, 1);
      if (secondBlock !== undefined) {
        if (secondBlock.content === "") {
          console.log("second block is empty, do nothing");
        } else {
          console.log("second block is not empty, insert a block after first block");
          editor.insertBlock(firstBlock.uuid, insertContent, {
                sibling: true
              });
        }
      } else {
        console.log("there is not a second block, insert a block after first block");
        editor.insertBlock(firstBlock.uuid, insertContent, {
              sibling: true
            });
      }
      return ;
    }
    console.log("first block has no built-in property, insert a block before first block");
    editor.insertBlock(firstBlock.uuid, insertContent, {
          before: true
        });
    return ;
  }
  console.log("no children in current block/page");
}

async function getTodayJournalPageEntity(graphUrl) {
  var userConfig = await logseqApp.getUserConfigs();
  if (!userConfig.enabledJournals) {
    return ;
  }
  var allPages = Belt_Option.mapWithDefaultU(Caml_option.null_to_opt(await editor.getAllPages(graphUrl)), [], (function (page) {
          return page;
        }));
  var journalPages = allPages.filter(function (page) {
        return page["journal?"];
      });
  var todayJournalDay = date2JournalDay(new Date());
  return Caml_option.undefined_to_opt(journalPages.find(function (journalPage) {
                  return Belt_Option.getExn(journalPage.journalDay) === todayJournalDay;
                }));
}

var cache = {
  contents: {}
};

var todayJournalDay = {
  contents: undefined
};

logseqApp.onTodayJournalCreated(function (param) {
      todayJournalDay.contents = undefined;
      cache.contents = {};
    });

async function getCachedTodayPageUuidMemo(graphUrl) {
  var userConfig = await logseqApp.getUserConfigs();
  if (userConfig.enabledJournals && Belt_Option.isSome(todayJournalDay.contents) && Belt_Option.isSome(Js_dict.get(cache.contents, graphUrl))) {
    return Belt_Option.getExn(Js_dict.get(cache.contents, graphUrl));
  }
  todayJournalDay.contents = date2JournalDay(new Date());
  var todayJournalPageEntityUuid = Belt_Option.mapU(await getTodayJournalPageEntity(graphUrl), (function (page) {
          return page.uuid;
        }));
  cache.contents[graphUrl] = todayJournalPageEntityUuid;
  return todayJournalPageEntityUuid;
}

async function handleJournalPage(param) {
  var currentGraphUrl = Belt_Option.mapU(Caml_option.null_to_opt(await logseqApp.getCurrentGraph()), (function (graph) {
          return graph.url;
        }));
  if (currentGraphUrl !== undefined) {
    var todayJournalPageUuid = await getCachedTodayPageUuidMemo(currentGraphUrl);
    if (todayJournalPageUuid !== undefined) {
      var childrenBlocks = await editor.getPageBlocksTree(todayJournalPageUuid);
      handleChildrenBlocks(childrenBlocks);
      return ;
    }
    console.log("today journal page uuid is none");
    return ;
  }
  console.log("current graph is none");
}

async function handleNamedPage(param) {
  var entity = Belt_Option.getExn(Caml_option.null_to_opt(await editor.getCurrentPage()));
  var blockEntity = LogseqSDK$LogseqBlockSpacer.BlockOrPageEntity.classify(entity);
  if (blockEntity.TAG === /* BlockEntity */0) {
    var currentBlock = Belt_Option.getExn(Caml_option.null_to_opt(await editor.getBlock(blockEntity._0.uuid, {
                  includeChildren: true
                })));
    return await handleChildrenBlocks(Belt_Option.mapWithDefaultU(currentBlock.children, [], (function (c) {
                      return c;
                    })));
  }
  var blocksTree = await editor.getPageBlocksTree(blockEntity._0.uuid);
  return await handleChildrenBlocks(blocksTree);
}

async function main(_baseInfo) {
  logseqApp.onRouteChanged(function (obj) {
        var template = obj.template;
        switch (template) {
          case "/" :
              handleJournalPage(undefined);
              return ;
          case "/page/:name" :
              handleNamedPage(undefined);
              return ;
          default:
            return ;
        }
      });
  handleJournalPage(undefined);
}

try {
  logseq.ready(function (baseInfo) {
        Js_promise2.$$catch(Js_promise2.then(main(baseInfo), (function (param) {
                    console.info("The plugin \"" + baseInfo.title + "\" which id is \"" + baseInfo.id + "\" has load");
                    return Promise.resolve(undefined);
                  })), (function (err) {
                console.error("Can't load the plugin " + baseInfo.title + " which id is \"" + baseInfo.id + "\"", err);
                return Promise.resolve(undefined);
              }));
      });
}
catch (raw_err){
  var err = Caml_js_exceptions.internalToOCamlException(raw_err);
  if (err.RE_EXN_ID === Js_exn.$$Error) {
    console.error(err._1);
  } else {
    throw err;
  }
}

export {
  
}
/*  Not a pure module */
