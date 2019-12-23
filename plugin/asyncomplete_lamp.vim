if exists('g:loaded_asyncomplete_lamp')
  finish
endif
let g:loaded_asyncomplete_lamp = v:true

augroup asyncomplete_lamp
  autocmd!
  autocmd User asyncomplete_setup call asyncomplete#register_source(
        \   asyncomplete#sources#lamp#get_source_options({})
        \ )
augroup END

