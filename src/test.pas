{$mode fpc}
program test;

uses sad;

procedure PrintSection(section: PSection; const depth: UInt32);
var
	block: TTextBlock;
	style: TStyle;
	a: String;
	child: PSection;
begin
	if section^.parent <> Nil then
		WriteLn(StringOfChar('#', depth), ' ', section^.name);

	for block in section^.blocks do
	begin
		Write('[');
		for style in block.styles do
		begin
			Write(style.kind, '(');
			for a in style.args do
				Write(a, ', ');
			Write('), ');
		end;
		Write('] ');

		WriteLn(MergeStringArray(block.content, ' '));
	end;

	for child in section^.children do
		PrintSection(child, depth + 1);
end;

var
	res: TParseResult;
begin
	res := ParseFile('test.sad');
	if res.status <> TParseStatus.Ok then
	begin
		WriteLn(stderr, 'error: ', MakeResultString(res, 'test.sad'));
		Halt(1);
	end;

	Writeln('=== ', res.document.title, ' ===');
	PrintSection(res.document.root, 1);
end.
