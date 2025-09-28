{$mode objfpc}
unit sad;

{$scopedenums on}
{$H+}

interface

uses fgl, SysUtils, StrUtils, Types;

type
	TStyleKind = (Head, SubHead, Custom);

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

	PSection = ^TSection;
	PSectionDynArray = array of PSection;

	TSection = record
		name		: String;
		blocks		: TTextBlockDynArray;
		children	: PSectionDynArray;
	end;

	TMetaMap = specialize TFPGMap<String, String>;

	TDocument = record
		title	: String;
		meta	: TMetaMap;
		root	: PSection;
	end;

	TParseStatus = (Ok, InvalidState);

	TParseContext = record
		lineno		: UInt32;
		inHeader	: Boolean;
		lastMessage	: String;

		document		: TDocument;
		currentSection	: PSection;
	end;

	TParseResult = record
		lineno	: UInt32;
		status	: TParseStatus;
		message	: String;

		{ only valid if status = TParseStatus.Ok }
		document	: TDocument;
	end;

function ParseLine(var ctx: TParseContext; line: String): TParseStatus;
function ParseFile(const path: String): TParseResult;

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

function ParseSwitchArgs(
	constref line: TStringDynArray;
	var offset: UInt32
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
	str: String;
	offset: UInt32;
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
	'${start': ctx.inHeader := False;
	end;
end;

function ParseBodyLine(
	var ctx: TParseContext;
	line: TStringDynArray
): TParseStatus;
begin
	if ctx.inHeader then
	begin
		ctx.lastMessage := 'ParseBodyLine called but ctx.InHeader = True!';
		exit(TParseStatus.InvalidState);
	end;
end;

function ParseLine(var ctx: TParseContext; line: String): TParseStatus;
var
	split: TStringDynArray;
begin
	result := TParseStatus.Ok;

	Inc(ctx.lineno);
	if (Length(line) = 0) or (Trim(line) = '') then
		exit;

	split := SplitString(line, ' ');

	if ctx.inHeader then
		result := ParseHeaderLine(ctx, split)
	else
		result := ParseBodyLine(ctx, split);
end;

function ParseFile(const path: String): TParseResult;
var
	inFile		: TextFile;
	s			: String;
	ix			: UInt32;
	parseCtx	: TParseContext;
	parseRes	: TParseStatus;
begin
	parseCtx := Default(TParseContext);
	parseCtx.inHeader := True;
	parseCtx.document.meta := TMetaMap.Create;

	Assign(inFile, path);
	ReSet(inFile);

	while not eof(inFile) do
	begin
		ReadLn(inFile, s);
		parseRes := ParseLine(parseCtx, s);
		if parseRes <> TParseStatus.Ok then
			break;
	end;

	result.lineno := parseCtx.lineno;
	result.status := parseRes;
	result.message := parseCtx.lastMessage;
	result.document := parseCtx.document;

{$ifndef NoDebug}
	WriteLn('debug: doc title: ', result.document.title);
	WriteLn('debug: doc meta:');
	for ix := 0 to result.document.meta.Count - 1 do
		Writeln('    ', result.document.meta.Keys[ix], ' = ', result.document.meta.Data[ix]);
{$endif}
end;

end.
