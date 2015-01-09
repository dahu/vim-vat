" Vim global plugin for storing files in an sqlite3 DB
" Maintainer:	Barry Arthur <barry.arthur@gmail.com>
" Version:	0.1
" Description:	Keep your files in an Sqlite Database
" Last Change:	2015-01-09
" License:	Vim License (see :help license)
" Location:	plugin/vat.vim
" Website:	https://github.com/dahu/vat
"
" See vat.txt for help.  This can be accessed by doing:
"
" :helptags ~/.vim/doc
" :help vat

" Vimscript Setup: {{{1
" Allow use of line continuation.
let s:save_cpo = &cpo
set cpo&vim

"if exists("g:loaded_vat")
"      \ || v:version < 700
"      \ || &compatible
"  let &cpo = s:save_cpo
"  finish
"endif
"let g:loaded_vat = 1

" DB Class : {{{1

function! DB(dbname)
  let db = {}
  let db.name = a:dbname

  func db.has_schema() dict
    return self.exec('.schema') != ''
  endfunc

  func db.new_schema() dict
    return self.exec('CREATE TABLE data(filename text primary key, content blob);')
  endfunc

  func db.exec(sql) dict
    let sql = 'sqlite3 ' . self.name . " '" . a:sql . "'"
    return system(sql)
  endfunc

  func db.escape(value)
    return substitute(substitute(a:value, '"', '""', 'g'), "'", "'\"'\"'", 'g')
  endfunc

  func db.exists(filename)
    return self.exec(printf('select count(*) from data where filename = "%s"', self.escape(a:filename)))
  endfunc

  func db.update(filename, content)
    return self.exec(printf('update data set content = "%s" where filename = "%s"', self.escape(a:content), self.escape(a:filename)))
  endfunc

  func db.insert(filename, content)
    return self.exec(printf('insert into data values("%s", "%s")', self.escape(a:filename), self.escape(a:content)))
  endfunc

  func db.select_content(filename)
    return self.exec(printf('select content from data where filename = "%s"', self.escape(a:filename)))
  endfunc

  func db.ls()
    return self.exec('select filename from data')
  endfunc

  if ! db.has_schema()
    call db.new_schema()
  endif
  return db
endfunction

" Public Interface : {{{1

function! DBWrite(filename)
  let [dbname, filename] = matchlist(a:filename, '\(.*\.vat\)://\(.*\)')[1:2]
  let db = DB(dbname)
  let content = join(getline(1, '$'), "\n")
  if db.exists(filename)
    call db.update(filename, content)
  else
    call db.insert(filename, content)
  end
  set nomodified
endfunction

function! DBRead(filename)
  let [dbname, filename] = matchlist(a:filename, '\(.*\.vat\)://\(.*\)')[1:2]
  let db = DB(dbname)
  let content = ''
  if db.exists(filename)
    let content =  db.select_content(filename)
  end
  % delete
  call append(1, split(content, "\n", 1))
  1 delete
  setlocal noswapfile
  setlocal nomodified
  exe 'file ' . db.name . '://' . filename
  filetype detect
endfunction

function! s:db_filename_completion(arg_lead, cmd_line, cursor_pos)
  let dbname = matchstr(a:cmd_line, '^\s*\w\+\s\+\zs.*\.vat\ze://')
  if dbname == ""
    return map(glob('*.vat', 1, 1), 'v:val . "://"')
  else
    let arg_lead = substitute(a:arg_lead, '^' . dbname . '://', '', '')
    return map(filter(split(DBls(dbname), "\n"), 'v:val =~# "' . arg_lead . '"'), 'dbname . "://" . v:val')
  endif
endfunction

function! DBls(filename)
  let [dbname, filename] = matchlist(a:filename, '\(.*\.vat\)\%(://\(.*\)\)\?')[1:2]
  let db = DB(dbname)
  return db.ls()
endfunction

augroup DBWriter
  au!
  au BufWriteCmd,FileWriteCmd *.vat://* call DBWrite(expand('<amatch>'))
  au BufReadCmd               *.vat://* call DBRead(expand('<amatch>'))
  au BufRead                  *.vat     call DBRead(expand('<amatch>') . "://")
augroup END

" Commands: {{{1

command! -nargs=1 -bar -complete=customlist,<SID>db_filename_completion DBRead call DBRead(<q-args>)

" Teardown: {{{1
" reset &cpo back to users setting
let &cpo = s:save_cpo

" Template From: https://github.com/dahu/Area-41/
" vim: set sw=2 sts=2 et fdm=marker:
