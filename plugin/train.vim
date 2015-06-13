if !exists("g:train_words")
    let g:train_words = 12
endif

function! s:get_date()
    return system('date +%s')
endfunction!

function! s:get_words_count()
    return g:train_words
endfunction!

function! s:move_next()
    let l:line = getline('.')
    let l:column = virtcol('.')

    if l:column + 1 <= len(l:line)
        execute "normal l"
    elseif line('$') > line('.')
        execute "normal j0"
    en
endfunction!

function! s:check_symbol(char)
    let l:lines_count = line('.') - 1
    let l:iterator = 1
    let l:char_count = virtcol('.')
    while l:iterator <= l:lines_count
        " 1 for "<space>", which will be converted to new line by vim textwidth
        let l:char_count = l:char_count + len(getline(l:iterator)) + 1
        let l:iterator = l:iterator+1
    endw

    let l:actual_char = b:text[l:char_count - 1]
    if a:char == l:actual_char
        return 1
    endif

    return 0
endfunction!

function! s:init_buffer()
    let b:errors_count = 0
    let b:started_date = 0
    let b:current_char_is_wrong = 0
    let b:matches = []
    let b:last_correct = [-1, -1]

    let b:text = s:get_text()

    execute "normal ggcG" . b:text
    execute "normal gg0"
endfunction!

function! s:cleanup_buffer()
    for l:match_id in b:matches
        call matchdelete(l:match_id)
    endfor
endfunction!

function! s:match_add(group)
    let l:match_id = matchaddpos(a:group, [[line('.'), virtcol('.')]])
    call add(b:matches, l:match_id)
endfunction!

function! s:train_tick(char)
    if b:started_date == 0
        let b:started_date = s:get_date()
    en

    let l:is_correct = s:check_symbol(a:char)

    if l:is_correct
        if b:current_char_is_wrong == 0
            call s:match_add("TrainCorrect")
        en

        let b:current_char_is_wrong = 0
        let b:last_correct = [line('.'), virtcol('.')]

        call s:move_next()
    else
        if b:current_char_is_wrong == 0
            let b:errors_count = b:errors_count + 1
        en

        let b:current_char_is_wrong = 1
        call s:match_add("TrainWrong")
    en

    return ""
endfunction!

function! s:generate_result()
    let b:finished_date = s:get_date()

    let l:time = b:finished_date - b:started_date
    let l:words = s:get_words_count()

    let l:speed = (str2float(l:words)/str2float(l:time))*60

    execute 'setlocal statusline=speed:\ ' . string(l:speed) .
                \ '\ errors:\ ' . string(b:errors_count)
endfunction!

function! s:get_text()
    let l:command = "echo $(cat ~/.vim/bundle/train/text) " .
                \ "| tr -cd '[[:alnum:]] ' " .
                \ "| sed 's/ /\\n/g' " .
                \ "| shuf -n " . s:get_words_count() . " - " .
                \ "| tr '\\n' ' ' " .
                \ "| xargs"

    let l:text = system(l:command)
    let l:text = tolower(l:text)

    return l:text
endfunction!

function! Train()
    enew!

    call s:setup()
    call s:init_buffer()
    call s:define_au()
endfunction!

command! Train call Train()

function! s:cursorholdi()
    if line('$') == b:last_correct[0] && virtcol('$')-1 == b:last_correct[1]
        call s:generate_result()
        call s:cleanup_buffer()
        call s:init_buffer()
    en
endfunction!

function! s:setup()
    highlight! TrainWrong ctermbg=red
    highlight! TrainNeutral ctermfg=black
    highlight! TrainCorrect ctermbg=green

    setlocal cmdheight=1
    setlocal laststatus=2
    setlocal statusline=speed:\ 0\ errors:\ 0
endfunction!

function! s:define_au()
    augroup TrainGame
        au!

        au InsertCharPre * let v:char = <sid>train_tick(v:char)
        au CursorHoldI * call <sid>cursorholdi()
    augroup end
endfunction!
