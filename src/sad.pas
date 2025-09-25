{$mode objfpc}
unit sad;

{$scopedenums on}

interface

uses SysUtils, StrUtils, Types;

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

	TDocument = record
		title	: String;
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
	result := '';
	if Length(src) < 1 then exit;

	result := src[0];
	src := Copy(src, 1, Length(src)-1);

	for str in src do
		result := MergeStringArray + joinStr + str;
end;

function ParseHeaderLine(
	var ctx: TParseContext;
	line: TStringDynArray
): TParseStatus;
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
		{ ParseSwitchArgs(line, offset (var UInt32)): TStringDynArray }
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
	parseCtx	: TParseContext;
	parseRes	: TParseStatus;
begin
	parseCtx := Default(TParseContext);
	parseCtx.inHeader := True;

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
end;

end.
