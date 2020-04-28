nnoremap <silent> <LocalLeader>r :call <SID>VimPipe()<CR>

function Exit_cb(vimpipe_buffer, start, exit_status)
	let l:curr_buff = bufnr("%")
	if win_gotoid(bufwinid(a:vimpipe_buffer))
		silent! execute ":1d _"
		" Display exit statys
		silent call append(0, ["# Exit status: " . a:exit_status, ""])
		" Display execution time
		let l:duration = printf("%.2f", reltimefloat(reltime(a:start)))
		silent call append(0, "# Pipe command took: " . l:duration . "s")
		" Add the how-to-close shortcut.
		let l:leader = exists("g:maplocalleader") ? g:maplocalleader : "\\"
		silent call append(0, "# Use " . l:leader . "p to close this buffer.")
	endif
	call win_gotoid(bufwinid(l:curr_buff))
endfunction

function! s:VimPipe() " {
	" Save local settings.
	let saved_unnamed_register = @@
	let switchbuf_before = &switchbuf
	set switchbuf=useopen

	" Lookup the parent buffer.
	if exists("b:vimpipe_parent")
		let l:parent_buffer = b:vimpipe_parent
	else
		let l:parent_buffer = bufnr( "%" )
	endif

	" Create a new output buffer, if necessary.
	if ! exists("b:vimpipe_parent")
		let bufname = bufname( "%" ) . " [VimPipe]"
		let vimpipe_buffer = bufnr( bufname )

		if vimpipe_buffer == -1
			let vimpipe_buffer = bufnr( bufname, 1 )

			" Close-the-window mapping.
			execute "nnoremap \<buffer> \<silent> \<LocalLeader>p :bw " . vimpipe_buffer . "\<CR>"

			" Split & open.
			silent execute "sbuffer " . vimpipe_buffer

			" Set some defaults.
			call setbufvar(vimpipe_buffer, "&swapfile", 0)
			call setbufvar(vimpipe_buffer, "&buftype", "nofile")
			call setbufvar(vimpipe_buffer, "&bufhidden", "wipe")
			call setbufvar(vimpipe_buffer, "vimpipe_parent", l:parent_buffer)

			call setbufvar(vimpipe_buffer, "&filetype", getbufvar(l:parent_buffer, 'vimpipe_filetype'))

			" Close-the-window mapping.
			nnoremap <buffer> <silent> <LocalLeader>p :bw<CR>
		else
			silent execute "sbuffer" vimpipe_buffer
		endif

		let l:parent_was_active = 1
	endif

	" Display a "Running" message.
	silent! execute ":1,2d _"
	silent call append(0, ["# Running... ",""])
	redraw

	" Clear the buffer.
 	execute ":2,$d _"

	" Lookup the vimpipe command, either from here or a parent.
	if exists("b:vimpipe_command")
		let l:vimpipe_command = b:vimpipe_command
	else
		let l:vimpipe_command = getbufvar( b:vimpipe_parent, 'vimpipe_command' )
	endif

	" Call the pipe command, or give a hint about setting it up.
	if empty(l:vimpipe_command)
		silent call append(0, ["", "# See :help vim-pipe for setup advice."])
	else
		let start = reltime()
		let Cb = {es -> "call Exit_cb(" . vimpipe_buffer . ", " . string(start) . ", " . es . ")"}
		let pipe_options = {
					\ "in_io": "buffer",
					\ "in_buf": l:parent_buffer,
					\ "out_io": "buffer",
					\ "out_buf": vimpipe_buffer,
					\ "err_io": "out",
					\ "exit_cb": {job, exit_status -> execute(Cb(exit_status))}
					\ }
		let l:vimpipe_job = job_start(l:vimpipe_command, l:pipe_options)
	endif

	" Go back to the last window.
	if exists("l:parent_was_active")
		execute "normal! \<C-W>\<C-P>"
	endif

	" Restore local settings.
	let &switchbuf = switchbuf_before
	let @@ = saved_unnamed_register
endfunction " }

" vim: set foldmarker={,} foldlevel=1 foldmethod=marker:
