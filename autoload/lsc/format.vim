" https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#textDocument_formatting
" for the whole document
" and
" https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/#textDocument_rangeFormatting
" for ranges
"
"
"

function! s:FormattingOptions()
  " TODO Not sure what things like clangd do with this stuff when they read
  " their own configuration files, but it's a non-optional field in the
  " formatting request params. Work out what it does, and make it configurable
  " to users (probably per language, but maybe also globally; or both)
  return {
      \ 'tabSize': 8,
      \ 'insertSpaces': v:false,
      \ 'trimTrailingWhitespace': v:true,
      \ 'insertFinalNewline': v:true,
      \ 'trimFinalNewlines': v:true,
      \}
endfunction

function! s:ApplyEdit(textedit)
  " FIXME This is a hack. We probably don't want to use hack around workspace
  " edits here
  let l:workspace_edit = {'changes': {lsc#uri#documentUri(): a:textedit}}
  return lsc#edit#apply(l:workspace_edit)
endfunction

function! s:OnResult(textedit) abort
  "Response:

  "  result: TextEdit[] | null describing the modification to the document to be formatted.
  "  error: code and message set in case an exception happens during the range formatting request.
  "
  "  Since version 3.18.0

 "call lsc#message#error('onresult')
  if a:textedit == v:null | return | endif
  call lsc#message#log('got edits' . json_encode(a:textedit), 'Info')
  return s:ApplyEdit(a:textedit)
endfunction

function! s:OnSkip(bufnr, textedit) abort
  call lsc#message#error('formatting skipped for ')
endfunction

function! s:startDocFormattingRequest() abort
  let l:params = lsc#params#textDocument()
  let l:params['options'] = s:FormattingOptions()
  let l:server = lsc#server#forFileType(&filetype)[0]
  call lsc#message#log('sending message' . json_encode(l:params), 'Info')
  call l:server.request('textDocument/formatting', l:params,
      \ lsc#util#gateResult('FormatDoc',
      \     function('<SID>OnResult', []),
      \     function('<SID>OnSkip', [bufnr('%')])))
endfunction

function! s:startRangeFormattingRequest(range) abort
  let l:params = lsc#params#textDocument()
  let l:params['range'] = a:range
  let l:params['options'] = s:FormattingOptions()
  let l:server = lsc#server#forFileType(&filetype)[0]
  call l:server.request('textDocument/rangeFormatting', l:params,
      \ lsc#util#gateResult('FormatRange',
      \     function('<SID>OnResult', []),
      \     function('<SID>OnSkip', [bufnr('%')])))
endfunction

function! lsc#format#formatFile() abort
  return s:startDocFormattingRequest()
endfunction

function! lsc#format#formatRange() range abort
  let l:range = {
      \   'start': {'line': a:firstline - 1, 'character': 0},
      \   'end': {'line': a:lastline - 1, 'character': strlen(getline("."))}
      \}
  call lsc#message#log('formatting range' . json_encode(l:range), 'Info')

  return s:startRangeFormattingRequest(l:range)
endfunction
