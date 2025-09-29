{$mode objfpc}
unit sad;

(* Copyright (c) 2025, Marie Eckert                                           *)
(*                                                                            *)
(* Redistribution and use in source and binary forms, with or without         *)
(* modification, are permitted provided that the following conditions are met:*)
(*                                                                            *)
(* 1. Redistributions of source code must retain the above copyright notice,  *)
(* this list of conditions and the following disclaimer.                      *)
(*                                                                            *)
(* 2. Redistributions in binary form must reproduce the above copyright       *)
(*    notice, this list of conditions and the following disclaimer in the     *)
(*    documentation   and/or other materials provided with the distribution.  *)
(*                                                                            *)
(* 3. Neither the name of the copyright holder nor the names of its           *)
(*    contributors may be used to endorse or promote products derived from    *)
(*    this software without specific prior written permission.                *)
(*                                                                            *)
(* THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS        *)
(* "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED  *)
(* TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR *)
(* PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR          *)
(* CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,      *)
(* EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,        *)
(* PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;*)
(* OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,   *)
(* WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR    *)
(* OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF     *)
(* ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.                                 *)

{$scopedenums on}
{$H+}

interface

uses fgl, SysUtils, StrUtils, Types;

type
	TStyleKind = (Head, Custom);

	TStyle = record
		kind	: TStyleKind;
		args	: TStringDynArray;
	end;
	TStyleDynArray = array of TStyle;

	TTextBlock = record
		styles	: TStyleDynArray;
		content	: TStringDynArray;
	end;
	TTextBlockDynArray = array of TTextBlock;
	PTextBlock = ^TTextBlock;

	PSection = ^TSection;
	PSectionDynArray = array of PSection;

	TSection = record
		name		: String;
		blocks		: TTextBlockDynArray;
		children	: PSectionDynArray;
		parent		: PSection;
	end;

	TMetaMap = specialize TFPGMap<String, String>;

	TDocument = record
		title	: String;
		meta	: TMetaMap;
		root	: PSection;
	end;

	TParseStatus = (Ok, InvalidState, SyntaxError, SectionError);

	TParseContext = record
		lineno		: UInt32;
		inHeader	: Boolean;
		lastMessage	: String;

		document		: TDocument;
		currentSection	: PSection;
		sectionDepth	: UInt32;
	end;

	TParseResult = record
		lineno	: UInt32;
		status	: TParseStatus;
		message	: String;

		{ only valid if status = TParseStatus.Ok }
		document	: TDocument;
	end;

function MergeStringArray(
	src: TStringDynArray;
	const joinStr: String
): String;

function FindSectionByPath(
	const document: TDocument;
	const path: String
): PSection;

function ParseSwitchArgs(
	constref line: TStringDynArray;
	var offset: Int64
): TStringDynArray;

function ParseLine(var ctx: TParseContext; line: String): TParseStatus;
function ParseOpenFile(var fl: TextFile): TParseResult;
function ParseFile(const path: String): TParseResult;

function MakeResultString(
	constref res: TParseResult;
	const path: String
): String;

const
	SAD_VERSION = '2.1.0';
	SECTION_START_MARKER = '$$SECTION_START$$';
	SECTION_END_MARKER = '$$SECTION_END$$';

implementation

function MergeStringArray(
	src: TStringDynArray;
	const joinStr: String
): String;
var
	str: String;
begin
	result := '';
	if Length(src) < 1 then exit;

	result := src[0];
	src := Copy(src, 1, Length(src)-1);

	for str in src do
		result := MergeStringArray + joinStr + str;
end;

function FindSectionByPath(
	const document: TDocument;
	const path: String
): PSection;
var
	pathSplit: TStringDynArray;
	elem: String;
	sec, currSec: PSection;
begin
	pathSplit := SplitString(path, ':');

	currSec := document.root;
	for elem in pathSplit do
	begin
		for sec in currSec^.children do
		begin
			if sec^.name = elem then
			begin
				currSec := sec;
				break;
			end;
		end;
	end;

	exit(currSec);
end;

function ParseSwitchArgs(
	constref line: TStringDynArray;
	var offset: Int64
): TStringDynArray;
var
	ix, cpyOffset: UInt32;
begin
	SetLength(result, 0);

	for ix := offset + 1 to Length(line) - 1 do
	begin
		SetLength(result, Length(result) + 1);

		if line[ix][High(line[ix])] = '}' then
			cpyOffset := 1
		else
			cpyOffset := 0;

		result[High(result)] := Copy(line[ix], 1, Length(line[ix]) - cpyOffset);

		Inc(offset);

		if cpyOffset = 1 then
			break;
	end;

	Inc(offset);
end;

function ParseHeaderLine(
	var ctx: TParseContext;
	line: TStringDynArray
): TParseStatus;
var
	tmp: TStringDynArray;
	offset: Int64;
begin
	result := TParseStatus.Ok;

	if not ctx.inHeader then
	begin
		ctx.lastMessage := 'ParseHeaderLine called but ctx.InHeader = False!';
		exit(TParseStatus.InvalidState);
	end;

	if Length(line) = 0 then
		exit;

	//
	//	format of a SAD header is simple:
	//	[whitespace]<HEADER SWITCH> [VALUE][whitespace]<linebreak>
	//
	//	so: only one header switch by line with no restrictions on leading
	//		and trailing whitespace. whitespace should already be taken care
	//		of by the caller.
	//
	//	header switches are:
	//	{$title} <Title>
	//	{$meta <Tag> <Value>
	//
	//	the document header is stopped and the actual document body is started
	//	using the {$start} switch.
	//

	case line[0] of
	'{$meta': begin
		offset := 0;
		tmp := ParseSwitchArgs(line, offset);

		ctx.document.meta.add(
			MergeStringArray(tmp, ' '),
			MergeStringArray(Copy(line, offset, Length(line) - offset), ' ')
		);
	end;
	'{$title}': ctx.document.title := MergeStringArray(
		Copy(line, 1, Length(line) - 1),
		' '
	);
	'{$start}': ctx.inHeader := False;
	end;
end;

function ParseBodyLine(
	var ctx: TParseContext;
	line: TStringDynArray
): TParseStatus;

	procedure AppendBlockWord(section: PSection; wrd: String);
	var
		blockIx: UInt32;
	begin
		if Length(section^.blocks) = 0 then
			SetLength(section^.blocks, 1);

		blockIx := High(section^.blocks);
		SetLength(
			section^.blocks[blockIx].content,
			Length(
				section^.blocks[blockIx].content
			) + 1
		);

		section^.blocks[blockIx].content[
			High(
				section^.blocks[blockIx].content
			)
		] := wrd;
	end;

	function NewBlock(section: PSection): UInt32;
	begin
		SetLength(section^.blocks, Length(section^.blocks) + 1);
		exit(High(section^.blocks));
	end;

	procedure ApplyStyle(section: PSection; args: TStringDynArray);
	var
		block: PTextBlock;
		cpyOffs: UInt32;
	begin
		if (Length(section^.blocks) = 0) then
			NewBlock(section)
		else if
			(Length(section^.blocks[High(section^.blocks)].content) > 0) then
		begin
			NewBlock(section);
			section^.blocks[High(section^.blocks)].styles :=
				section^.blocks[High(section^.blocks) - 1].styles;
		end;

		block := @section^.blocks[High(section^.blocks)];

		cpyOffs := 1;

		SetLength(block^.styles, Length(block^.styles) + 1);
		case args[0] of
		'head', 'sub-head':
			block^.styles[High(block^.styles)].kind := TStyleKind.Head;
		else begin
			block^.styles[High(block^.styles)].kind := TStyleKind.Custom;
			cpyOffs := 0;
		end;
		end;

		if Length(args) < 1 + cpyOffs then
			exit;

		block^.styles[High(block^.styles)].args :=
			Copy(args, cpyOffs, Length(args) - cpyOffs);
	end;

	procedure PopStyle(section: PSection);
	begin
		NewBlock(section);
		if (Length(section^.blocks) = 1) then
			exit;

		section^.blocks[High(section^.blocks)].styles := Copy(
			section^.blocks[High(section^.blocks) - 1].styles,
			0,
			Length(section^.blocks[High(section^.blocks) - 1].styles) - 1
		);
	end;

var
	ix, skip, tmp: Int64;
	args: TStringDynArray;
begin
	result := TParseStatus.Ok;

	if ctx.inHeader then
	begin
		ctx.lastMessage := 'ParseBodyLine called but ctx.InHeader = True!';
		exit(TParseStatus.InvalidState);
	end;

	skip := 0;

	for ix := 0 to Length(line) - 1 do
	begin
		if skip > 0 then
		begin
			Dec(skip);
			continue;
		end;

		if not StartsStr('{$', line[ix]) then
		begin
			AppendBlockWord(ctx.currentSection, line[ix]);
			continue;
		end;

		case line[ix] of
		'{$begin-section}', '{$section}': begin
			if ix > 0 then
			begin
				ctx.lastMessage :=
					'section switch must appear on its own line!';
				exit(TParseStatus.SyntaxError);
			end;

			if Length(line) < 2 then
			begin
				ctx.lastMessage := 'section is missing a name!';
				exit(TParseStatus.SyntaxError);
			end;

{$ifdef InsertSectionMarkers}
			AppendBlockWord(ctx.currentSection, SECTION_START_MARKER);
{$endif}

			tmp := Length(ctx.currentSection^.children);
			SetLength(ctx.currentSection^.children, tmp + 1);
			ctx.currentSection^.children[tmp] := New(PSection);
			ctx.currentSection^.children[tmp]^.parent := ctx.currentSection;
			ctx.currentSection := ctx.currentSection^.children[tmp];
			ctx.currentSection^.name := MergeStringArray(
				Copy(line, 1, Length(line) - 1),
				' '
			);
			Inc(ctx.sectionDepth);
			exit;
		end;
		'{$end-section}', '{$end}': begin
			if ctx.currentSection = ctx.document.root then
			begin
				ctx.lastMessage := 'cannot end the root section!';
				exit(TParseStatus.SectionError);
			end;

			if ctx.currentSection^.parent = Nil then
			begin
				ctx.lastMessage := 'current section has a Nil parent!';
				exit(TParseStatus.InvalidState);
			end;

{$ifdef InsertSectionMarkers}
			AppendBlockWord(ctx.currentSection, SECTION_END_MARKER);
{$endif}

			ctx.currentSection := ctx.currentSection^.parent;
			Dec(ctx.sectionDepth);
			exit;
		end;
		'{$head}', '{$sub-head}': begin
			tmp := NewBlock(ctx.currentSection);
			SetLength(ctx.currentSection^.blocks[tmp].styles, 1);
			ctx.currentSection^.blocks[tmp].styles[0].kind := TStyleKind.Head;
			ctx.currentSection^.blocks[tmp].styles[0].args :=
				[IntToStr(ctx.sectionDepth)];
			ctx.currentSection^.blocks[tmp].content :=
				Copy(line, 1, Length(line) - 1);
			SetLength(
				ctx.currentSection^.blocks[tmp].content,
				Length(ctx.currentSection^.blocks[tmp].content) + 1
			);
			ctx.currentSection^.blocks[tmp].content[
				High(ctx.currentSection^.blocks[tmp].content)
			] := sLineBreak;

			NewBlock(ctx.currentSection);
			exit;
		end;
		'{$style': begin
			tmp := ix;
			args := ParseSwitchArgs(line, tmp);
			skip := Length(args);

			ApplyStyle(ctx.currentSection, args);
		end;
		'{$reset}': begin
			PopStyle(ctx.currentSection);
		end;
		'{$reset-all}': begin
			NewBlock(ctx.currentSection);
		end;
		else begin
{$ifdef OnlyStandardSwitches}
			ctx.lastMessage := 'invalid switch: ' + line[ix];
			exit(TParseStatus.SyntaxError);
{$else}
			AppendBlockWord(ctx.currentSection, line[ix]);
{$endif}
		end;
		end;
	end;

	AppendBlockWord(ctx.currentSection, sLineBreak);
end;

function ParseLine(var ctx: TParseContext; line: String): TParseStatus;
var
	split: TStringDynArray;
begin
	result := TParseStatus.Ok;

	Inc(ctx.lineno);
	if (Length(line) = 0) or (Trim(line) = '') then
		split := []
	else
		split := SplitString(Trim(line), ' ');

	if ctx.inHeader then
		result := ParseHeaderLine(ctx, split)
	else
		result := ParseBodyLine(ctx, split);
end;

function ParseOpenFile(var fl: TextFile): TParseResult;
var
	s			: String;
	parseCtx	: TParseContext;
	parseRes	: TParseStatus;
begin
	parseCtx := Default(TParseContext);
	parseCtx.inHeader := True;
	parseCtx.document.meta := TMetaMap.Create;
	parseCtx.document.root := New(PSection);
	parseCtx.currentSection := parseCtx.document.root;

	while not eof(fl) do
	begin
		ReadLn(fl, s);
		parseRes := ParseLine(parseCtx, s);
		if parseRes <> TParseStatus.Ok then
			break;
	end;

	result.lineno := parseCtx.lineno;
	result.status := parseRes;
	result.message := parseCtx.lastMessage;
	result.document := parseCtx.document;
end;

function ParseFile(const path: String): TParseResult;

{$ifdef HaveDebug}
	function MakeIndent(const level: UInt32): String;
	begin
		exit(StringOfChar(' ', level * 4));
	end;

	procedure PrintSection(const section: PSection; const level: UInt32);
	var
		indent: String;
		child: PSection;
		block: TTextBlock;
		style: TStyle;
		tmp: String;
	begin
		indent := MakeIndent(level);
		WriteLn(indent, 'address    : ', Format('$%p', [section]));
		WriteLn(indent, 'name       : ', section^.name);
		WriteLn(indent, 'parent     : ', Format('$%p', [section^.parent]));
		WriteLn(indent, 'block count: ', Length(section^.blocks));
		for block in section^.blocks do
		begin
			indent := MakeIndent(level + 1);
			WriteLn(indent, 'word count : ', Length(block.content));
			WriteLn(indent, 'style count: ', Length(block.styles));
			WriteLn(indent, 'styles     : ');
			for style in block.styles do
			begin
				indent := MakeIndent(level + 2);
				WriteLn(indent, 'kind     : ', style.kind);
				WriteLn(indent, 'arg count: ', Length(style.args));
				WriteLn(indent, 'args     : ');
				for tmp in style.args do
				begin
					indent := MakeIndent(level + 3);
					WriteLn(indent, tmp);
				end;
			end;
		end;
		indent := MakeIndent(level);
		WriteLn(indent, 'child count: ', Length(section^.children));
		WriteLn(indent, 'children   : ');
		for child in section^.children do
			PrintSection(child, level + 1);
	end;
{$endif}

var
	inFile		: TextFile;
begin
	Assign(inFile, path);
	ReSet(inFile);

	result := ParseOpenFile(inFile);

	Close(inFile);

{$ifdef HaveDebug}
	WriteLn('debug: doc title: ', result.document.title);
	WriteLn('debug: doc meta:');
	for ix := 0 to result.document.meta.Count - 1 do
		Writeln('    ', result.document.meta.Keys[ix], ' = ', result.document.meta.Data[ix]);

	WriteLn('debug: sections:');
	PrintSection(result.document.root, 1);
{$endif}
end;

function MakeResultString(
	constref res: TParseResult;
	const path: String
): String;
var
	errStr: String;
begin
	if res.status = TParseStatus.Ok then
		exit(path + ': parsed successfully');
	WriteStr(errStr, res.status);
	exit(
		path + ':' + IntToStr(res.lineno) + ': ' + errStr + ': ' + res.message
	);
end;

end.
