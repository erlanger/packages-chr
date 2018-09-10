/*  Part of CHR (Constraint Handling Rules)

    Author:        Tom Schrijvers
    E-mail:        Tom.Schrijvers@cs.kuleuven.be
    WWW:           http://www.swi-prolog.org
    Copyright (c)  2004-2015, K.U. Leuven
    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions
    are met:

    1. Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.

    2. Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in
       the documentation and/or other materials provided with the
       distribution.

    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
    "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
    LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
    FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
    COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
    INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
    BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
    LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
*/

:- module(chr,
	  [ chr_compile_step1/2		% +CHRFile, -PlFile
	  , chr_compile_step2/2		% +CHRFile, -PlFile
	  , chr_compile_step3/2		% +CHRFile, -PlFile
	  , chr_compile_step4/2		% +CHRFile, -PlFile
	  , chr_compile/3
	  ]).
%% SWI begin
% vsc:
:- expects_dialect(swi).

:- if(current_prolog_flag(dialect, yap)).

:- prolog_load_context(directory,D), add_to_path(D).

:- else.

:- use_module(library(listing)). % portray_clause/2

:- endif.

%% SWI end
:- include(chr_op).

		 /*******************************
		 *    FILE-TO-FILE COMPILER	*
		 *******************************/

%	chr_compile(+CHRFile, -PlFile)
%
%	Compile a CHR specification into a Prolog file

chr_compile_step1(From, To) :-
	use_module(chr(chr_translate_bootstrap)),
	chr_compile(From, To, informational).
chr_compile_step2(From, To) :-
	use_module(chr(chr_translate_bootstrap1)),
	chr_compile(From, To, informational).
chr_compile_step3(From, To) :-
	use_module(chr(chr_translate_bootstrap2)),
	chr_compile(From, To, informational).
chr_compile_step4(From, To) :-
	use_module(chr(chr_translate)),
	chr_compile(From, To, informational).

chr_compile(From, To, MsgLevel) :-
	print_message(MsgLevel, chr(start(From))),
	read_chr_file_to_terms(From,Declarations),
	% read_file_to_terms(From, Declarations,
	%		   [ module(chr)	% get operators from here
	%		   ]),
	print_message(silent, chr(translate(From))),
	chr_translate(Declarations, Declarations1),
	insert_declarations(Declarations1, NewDeclarations),
	print_message(silent, chr(write(To))),
	writefile(To, From, NewDeclarations),
	print_message(MsgLevel, chr(end(From, To))).


%% SWI begin
specific_declarations([ (:- use_module(chr(chr_runtime))),
			(:- style_check(-discontiguous)),
			(:- style_check(-singleton)),
			(:- style_check(-no_effect))
		      | Tail
		      ], Tail).
%% SWI end

%% SICStus begin
%% specific_declarations([(:- use_module('chr_runtime')),
%%                     (:-use_module(chr_hashtable_store)),
%%		       (:- use_module('hpattvars')),
%%		       (:- use_module('b_globval')),
%%		       (:- use_module('hprolog')),  % needed ?
%%		       (:- set_prolog_flag(discontiguous_warnings,off)),
%%		       (:- set_prolog_flag(single_var_warnings,off))|Tail], Tail).
%% SICStus end



insert_declarations(Clauses0, Clauses) :-
	specific_declarations(Decls,Tail),
	(Clauses0 = [(:- module(M,E))|FileBody] ->
	    Clauses = [ (:- module(M,E))|Decls],
	    Tail = FileBody
	;
	    Clauses = Decls,
	    Tail = Clauses0
	).

%	writefile(+File, +From, +Desclarations)
%
%	Write translated CHR declarations to a File.

writefile(File, From, Declarations) :-
	open(File, write, Out),
	writeheader(From, Out),
	writecontent(Declarations, Out),
	close(Out).

writecontent([], _).
writecontent([D|Ds], Out) :-
	portray_clause(Out, D),		% SWI-Prolog
	writecontent(Ds, Out).


writeheader(File, Out) :-
	format(Out, '/*  Generated by CHR bootstrap compiler~n', []),
	format(Out, '    From: ~w~n', [File]),
	format_date(Out),
	format(Out, '    DO NOT EDIT.  EDIT THE CHR FILE INSTEAD~n', []),
	format(Out, '*/~n~n', []).

%% SWI begin
format_date(Out) :-
	get_time(Now),
	format_time(string(Date), '%+', Now),
	format(Out, '    Date: ~s~n~n', [Date]).
%% SWI end

%% SICStus begin
%% :- use_module(library(system), [datime/1]).
%% format_date(Out) :-
%%	datime(datime(Year,Month,Day,Hour,Min,Sec)),
%%	format(Out, '    Date: ~d-~d-~d ~d:~d:~d~n~n', [Day,Month,Year,Hour,Min,Sec]).
%% SICStus end



		 /*******************************
		 *	       MESSAGES		*
		 *******************************/


:- multifile
	prolog:message/3.

prolog:message(chr(start(File))) -->
	{ file_base_name(File, Base)
	},
	[ 'Translating CHR file ~w'-[Base] ].
prolog:message(chr(end(_From, To))) -->
	{ file_base_name(To, Base)
	},
	[ 'Written translation to ~w'-[Base] ].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
read_chr_file_to_terms(Spec, Terms) :-
	absolute_file_name(Spec, Path, [ access(read) ]),
	open(Path, read, Fd, []),
	read_chr_stream_to_terms(Fd, Terms),
	close(Fd).

read_chr_stream_to_terms(Fd, Terms) :-
	chr_local_only_read_term(Fd, C0, [ module(chr) ]),
	read_chr_stream_to_terms(C0, Fd, Terms).

read_chr_stream_to_terms(end_of_file, _, []) :- !.
read_chr_stream_to_terms(C, Fd, [C|T]) :-
	( ground(C),
	  C = (:- op(Priority,Type,Name)) ->
		op(Priority,Type,Name)
	;
		true
	),
	chr_local_only_read_term(Fd, C2, [module(chr)]),
	read_chr_stream_to_terms(C2, Fd, T).




%% SWI begin
chr_local_only_read_term(A,B,C) :- read_term(A,B,C).
%% SWI end

%% SICStus begin
%% chr_local_only_read_term(A,B,_) :- read_term(A,B,[]).
%% SICStus end
