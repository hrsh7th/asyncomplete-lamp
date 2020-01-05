if exists('g:loaded_asyncomplete_lamp')
  finish
endif
let g:loaded_asyncomplete_lamp = v:true

augroup asyncomplete_lamp
  autocmd!
  autocmd User lamp#text_document_did_open call asyncomplete#sources#lamp#attach()
augroup END

