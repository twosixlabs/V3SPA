This is the Lobster editor view.

    Editor = Backbone.View.extend
        id:        'editor'
        className: 'dialog'

        initialize: () ->
          lobsterChecker = new LobsterJSON

          editor = ace.edit(@$el[0].id)
          editor.setTheme("ace/theme/chaos");
          editor.getSession().setMode("ace/mode/lobster");
          editor.setKeyboardHandler("vim");
          editor.setBehavioursEnabled(true);
          editor.setSelectionStyle('line');
          editor.setHighlightActiveLine(true);
          editor.setShowInvisibles(false);
          editor.setDisplayIndentGuides(false);
          editor.renderer.setHScrollBarAlwaysVisible(false);
          editor.setAnimatedScroll(false);
          editor.renderer.setShowGutter(true);
          editor.renderer.setShowPrintMargin(false);
          editor.getSession().setUseSoftTabs(true);
          editor.setHighlightSelectedWord(true);

  Check to see whether or not the Lobster code provided is parseable.

          editor.on "change", (e)=>
            text = editor.getValue()
            try
              decoded = lobsterChecker.decode text
            catch error
              editor.getSession().setAnnotations([{
                row: error.line - 1,
                column: error.column,
                type: 'warning',
                text: "Syntax Error: #{error.message}"
              }])
              return

            editor.getSession().clearAnnotations()
            try
              parsed = lobsterChecker.translate decoded
            catch error
              console.log error
              return
            @data = parsed
