let s:Promise = vital#lamp#import('Async.Promise')
let s:id = 0

"
" asyncomplete#sources#lamp#get_source_options
"
function! asyncomplete#sources#lamp#get_source_options(opt)
  let l:defaults = {
        \   'name': 'lamp',
        \   'completor': function('asyncomplete#sources#lamp#completor'),
        \   'whitelist': ['*']
        \ }
  return extend(l:defaults, a:opt)
endfunction

"
" asyncomplete#sources#lamp#completor
"
function! asyncomplete#sources#lamp#completor(opt, ctx)
  " check servers.
  let l:servers = s:get_servers()
  if empty(l:servers)
    return
  endif

  let l:before_line = lamp#view#cursor#get_before_line()
  let l:before_char = lamp#view#cursor#get_before_char_skip_white()

  let l:should_request = v:false
  let l:should_request = l:should_request || index(s:get_chars(l:servers), l:before_char) >= 0
  let l:should_request = l:should_request || strlen(matchstr(l:before_line, s:get_keyword_pattern() . '$')) == 1
  if !l:should_request
    return
  endif

  let l:promises = map(l:servers, { _, s ->
        \   s.request('textDocument/completion', {
        \     'textDocument': lamp#protocol#document#identifier(bufnr('%')),
        \     'position': lamp#protocol#position#get(),
        \     'context': {
        \       'triggerKind': 2,
        \       'triggerCharacter': l:before_char
        \     }
        \   }).then({ response ->
        \     { 'server_name': s.name, 'response': response }
        \   }).catch(lamp#rescue({}))
        \ })

  call s:Promise.all(l:promises).then({ responses ->
        \   s:on_responses(a:opt, a:ctx, responses)
        \ })
endfunction

"
" on_responses
"
function! s:on_responses(opt, ctx, responses) abort
  let l:candidates = []
  for l:response in a:responses
    if empty(l:response)
      continue
    endif
    let l:candidates += s:to_candidates(l:response)
  endfor

  call asyncomplete#complete(
        \   a:opt.name,
        \   a:ctx,
        \   a:ctx.col - strlen(matchstr(a:ctx.typed, s:get_keyword_pattern() . '$')),
        \   l:candidates
        \ )
endfunction

"
" to_candidates
"
function! s:to_candidates(response) abort
  let l:candidates = []
  for l:item in (type(a:response.response) == type([]) ? a:response.response : get(a:response.response, 'items', []))
    if get(l:item, 'insertTextFormat', 1) == 2 && has_key(l:item, 'insertText')
      let l:word = l:item.label
      let l:is_expandable = l:item.label !=# l:item.insertText
    elseif has_key(l:item, 'textEdit')
      let l:word = l:item.label
      let l:is_expandable = l:item.label !=# l:item.textEdit.newText
    else
      let l:word = get(l:item, 'insertText', l:item.label)
      let l:is_expandable = v:false
    endif

    call add(l:candidates, {
          \   'word': word,
          \   'abbr': l:word . (l:is_expandable ? '~' : ''),
          \   'kind': 'Snippet',
          \   'user_data': json_encode({
          \     'lamp': {
          \       'id': s:id,
          \       'server_name': a:response.server_name,
          \       'completion_item': l:item
          \     }
          \   })
          \ })

    let s:id += 1
  endfor
  return l:candidates
endfunction

"
" get_servers
"
function! s:get_servers() abort
  let l:servers = lamp#server#registry#find_by_filetype(&filetype)
  let l:servers = filter(l:servers, { k, v -> v.supports('capabilities.completionProvider') })
  return l:servers
endfunction

"
" get_trigger_chars
"
function! s:get_chars(servers) abort
  let l:chars = []
  for l:server in a:servers
    let l:chars += l:server.capability.get_completion_trigger_characters()
  endfor
  return l:chars
endfunction

"
" get_keyword_pattern
"
function! s:get_keyword_pattern() abort
  let l:keywords = split(&iskeyword, ',')
  let l:keywords = filter(l:keywords, { _, k -> match(k, '\d\+-\d\+') == -1 })
  let l:keywords = filter(l:keywords, { _, k -> k !=# '@' })
  let l:pattern = '\%(' . join(map(l:keywords, { _, v -> '\V' . escape(v, '\') . '\m' }), '\|') . '\|\w\|\d\)'
  return l:pattern
endfunction

