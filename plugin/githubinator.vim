" ================================================================
" Name:         vim-githubinator: open highlighted text on Github
" Maintainer:   Danish Prakash
" HomePage:     https://github.com/prakashdanish/vim-githubinator
" License:      MIT
" ================================================================

" MIT License

" Copyright (c) 2018 Danish Prakash

" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:

" The above copyright notice and this permission notice shall be included in all
" copies or substantial portions of the Software.

" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
" SOFTWARE.

let s:githubinator_host_map = {}
if exists('g:githubinator_host_map')
    let s:githubinator_host_map = g:githubinator_host_map
endif
let s:githubinator_host_map['git@github.com:'] = 'https://github.com/'
let s:githubinator_host_map['git@gitlab.com:'] = 'https://gitlab.com/'
let s:githubinator_host_map['git@bitbucket.org:'] = 'https://bitbucket.org/'
let s:githubinator_host_map['https://\w*@bitbucket.org'] = 'https://bitbucket.org'

let s:githubinator_multiline_delim = {}
if exists('g:githubinator_multiline_delim') 
    let s:githubinator_multiline_delim = g:githubinator_multiline_delim
endif
let s:githubinator_multiline_delim['https://github.com/'] = '-L'
let s:githubinator_multiline_delim['https://gitlab.com/'] = '-'
let s:githubinator_multiline_delim['https://bitbucket.org/'] = ':'


function! s:parse_remote(url)
    for [k, v] in items(s:githubinator_host_map)
        if a:url =~# k
            let l:url = substitute(a:url, k, v, '')
            return l:url
        endif
    endfor
    return a:url
endfunction

function! s:multiline_delim(url)
    for [k, v] in items(s:githubinator_multiline_delim)
        if a:url =~# k
            return v
        endif
    endfor
    return '-L'
endfunction


" get remote URL 
function! s:generate_url(beg, end) range
    let l:file_name = expand("%")
    let l:branch = system("git branch 2> /dev/null | awk '{print $2}' | tr -d '\n'")
    if l:branch == ''
        echohl Error | echom 'Not a git repository' | echohl None
        return ''
    endif

    " get remote relative to the branch
    let l:remote = system(printf("git config --get branch.%s.remote | tr -d '\n'", l:branch))
    if l:remote == ''
        echohl Error | echom 'No remote branch' | echohl None
        return ''
    endif

    " get remote url
    let l:git_remote = system(printf("git config --get remote.%s.url | tr -d '\n'", l:remote))
    if l:git_remote == ''
        echohl Error | echom 'No remote address' | echohl None
        return ''
    endif

    " get the path relative to git repo
    let l:relative_path = system("git rev-parse --show-prefix | tr -d '\n'")
    " translate git protocal to https protocal
    " let l:git_remote = substitute(l:git_remote, '^git@github\.com:\(.*\)$', 'https://github.com/\1', '')
    let l:git_remote = <sid>parse_remote(l:git_remote)
    " remove .git
    let l:git_remote = substitute(l:git_remote, '.git$', '', '')
    if l:git_remote =~# 'https://bitbucket.org'
      let l:final_url = l:git_remote . '/src/' . l:branch . '/' . l:relative_path . l:file_name . '#lines-' . a:beg
    else
      let l:final_url = l:git_remote . '/blob/' . l:branch . '/' . l:relative_path . l:file_name . '#L' . a:beg
    endif
    if a:beg != a:end
        let delim = <sid>multiline_delim(l:final_url)
        let l:final_url .= delim . a:end
    endif

    return l:final_url
endfunction

function! GithubOpenURL(beg, end) range
    let l:final_url = s:generate_url(a:beg, a:end)
    if l:final_url == ''
    endif

    if executable('xdg-open')
        call system('xdg-open ' . l:final_url)
    elseif executable('open')
        call system('open ' . l:final_url)
    else
        echoerr 'githubinator: no `open` or equivalent command found. Try `ghc` to copy URL'
    endif
endfunction

function! GithubCopyURL(beg, end) range
    let l:final_url = s:generate_url(a:beg, a:end)

    if executable('pbcopy')
        call system("echo " . l:final_url . " | pbcopy")
    elseif executable('xsel')
        call system("echo " . l:final_url . " | xsel -b")
    else
        echoerr "githubinator: no `copy-to-clipboard` command found."
        return
    endif

    echom "URL copied: " . l:final_url
endfunction

command! -range -nargs=0 GHO call GithubOpenURL(<line1>, <line2>)
command! -range -nargs=0 GHC call GithubCopyURL(<line1>, <line2>)

xnoremap <silent> <Plug>(githubinator-open) :<C-U>call GithubOpenURL(getpos("'<")[1], getpos("'>")[1])<CR>
xnoremap <silent> <Plug>(githubinator-copy) :<C-U>call GithubCopyURL(getpos("'<")[1], getpos("'>")[1])<CR>
nnoremap <silent> <Plug>(githubinator-open) :<C-U>call GithubOpenURL(line('.'), line('.')+v:count1-1)<CR>
nnoremap <silent> <Plug>(githubinator-copy) :<C-U>call GithubCopyURL(line('.'), line('.')+v:count1-1)<CR>

if !hasmapto('<Plug>(githubinator-open)', 'v')
    xmap <silent> gho <Plug>(githubinator-open)
endif
if !hasmapto('<Plug>(githubinator-copy)', 'v')
    xmap <silent> ghc <Plug>(githubinator-copy)
endif
if !hasmapto('<Plug>(githubinator-open)', 'n')
    nmap <silent> gho <Plug>(githubinator-open)
endif
if !hasmapto('<Plug>(githubinator-copy)', 'n')
    nmap <silent> ghc <Plug>(githubinator-copy)
endif
