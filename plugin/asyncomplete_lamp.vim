if exists('g:loaded_asyncomplete_lamp')
  finish
endif
let g:loaded_asyncomplete_lamp = v:true

augroup asyncomplete_lamp
  autocmd!
  autocmd User lamp#server#initialized call asyncomplete#sources#lamp#register()
  autocmd User lamp#server#exited call asyncomplete#sources#lamp#unregister()
augroup END

