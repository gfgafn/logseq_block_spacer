%%raw(`
    import "@logseq/libs"

    logseq.ready(() => {
        logseq.UI.showMsg('Hello World from Logseq').catch(console.error)
    })
`)
