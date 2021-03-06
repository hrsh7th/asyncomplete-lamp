let s:Promise = vital#lamp#import('Async.Promise')
let s:Position = vital#lamp#import('VS.LSP.Position')

let s:state = {
\   'is_inserted': v:false
\ }

augroup asyncomplete#sources#lamp
  autocm!
  autocmd InsertEnter * call s:on_insert_enter()
  autocmd InsertCharPre * call s:on_insert_char_pre()
augroup END

"
" s:on_insert_enter
"
function! s:on_insert_enter() abort
  let s:state.is_inserted = v:false
endfunction

"
" s:on_insert_char_pre
"
function! s:on_insert_char_pre() abort
  let s:state.is_inserted = v:true
endfunction


"
" asyncomplete#sources#lamp#register
"
function! asyncomplete#sources#lamp#register() abort
  let l:servers = s:get_servers()
  if empty(l:servers)
    return
  endif

  call asyncomplete#unregister_source(printf('lamp-%s', &filetype))
  let l:source = {}
  let l:source.name = printf('lamp-%s', &filetype)
  let l:source.completor = function('s:completor')
  let l:source.whitelist = [&filetype]
  let l:source.triggers = { '*': s:get_chars(l:servers) }
  call asyncomplete#register_source(l:source)
endfunction

"
" asyncomplete#sources#lamp#unregister
"
function! asyncomplete#sources#lamp#unregister() abort
  call asyncomplete#unregister_source(printf('lamp-%s', &filetype))
endfunction

"
" completor
"
function! s:completor(opt, ctx)
  " check servers.
  let l:servers = s:get_servers()
  if empty(l:servers)
    return
  endif

  let l:before_line = lamp#view#cursor#get_before_line()
  if s:state.is_inserted
    let l:is_trigger_line = strlen(matchstr(l:before_line, s:get_keyword_pattern() . '$')) == 1
  else
    let l:is_trigger_line = strlen(matchstr(l:before_line, s:get_keyword_pattern() . '$')) >= 1
  endif

  let l:before_char = lamp#view#cursor#get_before_char_skip_white()
  let l:is_trigger_char = index(s:get_chars(l:servers), l:before_char) >= 0

  let l:should_request = v:false
  let l:should_request = l:should_request || l:is_trigger_char
  let l:should_request = l:should_request || l:is_trigger_line
  if !l:should_request
    return
  endif

  let l:position = s:Position.cursor()
  let l:promises = map(l:servers, { _, server ->
        \   server.request('textDocument/completion', {
        \     'textDocument': lamp#protocol#document#identifier(bufnr('%')),
        \     'position': l:position,
        \     'context': {
        \       'triggerKind': 2,
        \       'triggerCharacter': l:before_char
        \     }
        \   }).then({ response ->
        \     {
        \       'server_name': server.name,
        \       'position': l:position,
        \       'response': response
        \     }
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
    let l:candidates += lamp#feature#completion#convert(l:response.server_name, l:response.position, l:response.response)
  endfor

  let l:before_line = lamp#view#cursor#get_before_line()
  call asyncomplete#complete(
        \   a:opt.name,
        \   a:ctx,
        \   strlen(substitute(l:before_line, s:get_keyword_pattern() . '$', '', 'g')) + 1,
        \   l:candidates,
        \ )
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
  let l:pattern = '\%(' . join(map(l:keywords, { _, v -> '\V' . escape(v, '\') . '\m' }), '\|') . '\|\w\)*'
  return l:pattern
endfunction

