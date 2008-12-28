" Changed
"
" Description:
"   Displays signs on changed lines.
" Last Change: 2008-12-28
" Maintainer: Shuhei Kubota <kubota.shuhei+vim@gmail.com>
" Requirements:
"   * diff
"   * +signs (appears in :version)
" Installation:
"   Just source this file. (Put this file into the plugin directory.)
" Usage:
"   [Settings]
"
"   1. Changing sings
"       To change signs, re-define signs after sourcing this script.
"       example (changing text):
"           sign define SIGN_CHANGED_DELETED_VIM text=D texthl=ChangedDefaultHl
"           sign define SIGN_CHANGED_ADDED_VIM   text=A texthl=ChangedDefaultHl
"           sign define SIGN_CHANGED_VIM         text=M texthl=ChangedDefaultHl
"
"   2. (optional) Setting a directory where temporary files are saved
"       This script uses diff command. And it saves changed buffer into a
"       temporary file.
"       The default directory is a first path in the RUNTIMEPATH option.
"       (do :set rtp?  =>  /home/shu/.vim,...  or  d:\vimfiles,...)
"
"       Or set g:Changed_tempDir, for example /tmp. (let g:Changed_tempDir='/tmp')
"
"   [Usual]
"
"   Edit a buffer and wait seconds. Then signs appear on changed lines.
"

au! BufWritePost * call <SID>Changed_execute()
au! CursorHold   * call <SID>Changed_execute()
au! CursorHoldI  * call <SID>Changed_execute()
" heavy
"au! InsertLeave * call <SID>Changed_execute()
" too heavy
"au! CursorMoved * call <SID>Changed_execute()

if !exists('g:Changed_tempDir')
    let g:Changed_tempDir = substitute(split(&runtimepath, ',')[0], '\', '/', 'g')
endif

if !exists('g:Changed_definedSigns')
    let g:Changed_definedSigns = 1
    highlight ChangedDefaultHl cterm=bold ctermbg=yellow ctermfg=black gui=bold guibg=yellow guifg=black
    sign define SIGN_CHANGED_DELETED_VIM text=- texthl=ChangedDefaultHl
    sign define SIGN_CHANGED_ADDED_VIM 	 text=+ texthl=ChangedDefaultHl
    sign define SIGN_CHANGED_VIM 		 text=* texthl=ChangedDefaultHl
endif

function! s:Changed_execute()
    if exists('b:Changed__tick') && b:Changed__tick == b:changedtick | return | endif

    if exists('b:Changed__lineNums')
        " clear all signs
        for c in b:Changed__lineNums
            execute 'sign unplace ' . c[0] . ' buffer=' . bufnr('%')
        endfor
        unlet b:Changed__lineNums
    endif

    if ! &modified | return | endif

    " get paths
    let originalPath = substitute(expand('%:p'), '\', '/', 'g')
    let changedPath = g:Changed_tempDir . '/changed_' . substitute(expand('%:p:t'), '\', '/', 'g')

    " both files are not saved -> don't diff
    if ! filereadable(originalPath) | return | endif

    " get diff text
    execute 'write! ' . changedPath
    let diffText = system('diff -u ' . shellescape(originalPath) . ' ' . shellescape(changedPath))
    let diffLines = split(diffText, '\n')

    " clear all temp files
    call system('rm ' . changedPath)
    call system('del ' . substitute(changedPath, '/', '\', 'g'))

    " list lines and their signs
    let pos = 1 " changed line number
    let changedLineNums = [] " collection of pos
    let minusLevel = 0
    for line in diffLines
        if line[0] == '@'
            " reset pos
            let regexp = '@@\s*-\d\+\(,\d\+\)\?\s\++\(\d\+\),\d\+\s\+@@'
            let pos = eval(substitute(line, regexp, '\2', ''))
            let minusLevel = 0
        elseif line[0] == '-' && line !~ '^---'
            call add(changedLineNums, [pos, '-'])
            let minusLevel += 1
        elseif line[0] == '+' && line !~ '^+++'
            if minusLevel > 0
                call add(changedLineNums, [pos, '*'])
            else
                call add(changedLineNums, [pos, '+'])
            endif
            let pos += 1
            let minusLevel -= 1
        else
            let pos += 1
            let minusLevel = 0
        endif
    endfor

    " place signs
    let lastLineNum = line('$')
    for c in changedLineNums
        let lineNum = c[0]
        if lastLineNum < lineNum
            let lineNum = lastLineNum
        endif
        if c[1] == '-' 
            execute 'sign place ' . c[0] . ' line=' . lineNum . ' name=SIGN_CHANGED_DELETED_VIM buffer=' . bufnr('%')
        elseif c[1] == '+'
            execute 'sign place ' . c[0] . ' line=' . lineNum . ' name=SIGN_CHANGED_ADDED_VIM buffer=' . bufnr('%')
        else
            execute 'sign place ' . c[0] . ' line=' . lineNum . ' name=SIGN_CHANGED_VIM buffer=' . bufnr('%')
        endif
    endfor

    " memorize the signs list for clearing saved signs
    let b:Changed__lineNums = changedLineNums
    let b:Changed__tick = b:changedtick
endfunction
