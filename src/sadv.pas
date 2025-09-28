{$mode objfpc}
program sadv;

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
(*    documentation    and/or other materials provided with the distribution. *)
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

{$H+}

uses SysUtils, Types, StrUtils, sad, uANSIUtils;

procedure ListDocSections(constref doc: TDocument);
	procedure PrintIndent(const amount: Integer);
	var
		i: Integer;
	begin
		for i := 0 to amount - 1 do
			write('  ');
	end;

	procedure PrintSections(const section: PSection; const level: Integer);
	var
		child: PSection;
	begin
		for child in section^.children do
		begin
			PrintIndent(level);
			writeln(':', child^.name);
			PrintSections(child, level + 1);
		end;
	end;
begin
	writeln(':root');
	PrintSections(doc.root, 1);
end;

procedure PrintSection(const section: PSection; const printLines: Boolean);
	procedure _PrintSection(
		const section: PSection;
		const printLines: Boolean;
		lineno: UInt32;
		const depth: UInt32
	);
	var
		block: TTextBlock;
		style: TStyle;
		a: String;
		child: PSection;
	begin
		for block in section^.blocks do
		begin
			for style in block.styles do
			begin
				if style.kind = TStyleKind.Head then
					Write(STYLE_BOLD)
				else
					for a in style.args do
						Write(NameToEscape(a));
			end;

			for a in block.content do
			begin
				if a = sLineBreak then
				begin
					Inc(lineno);
					WriteLn;
					Write(Format('%.3d ', [lineno]));
					continue;
				end;

				Write(a, ' ');
			end;

			Write(STYLE_RESET);
		end;

		for child in section^.children do
			_PrintSection(child, printLines, lineno, depth + 1);
	end;
begin
	Write('001 ');
	_PrintSection(section, printLines, 1, 1);
end;

const
	VERSION = '1.5.0';
var
	i: Integer;
	path, requiredSection, cparam: String;
	printMeta, printLines, listSections: Boolean;
	parseRes: TParseResult;
begin
	if (ParamCount() = 0) then
	begin
		writeln('SAD Command Line Viewer ; ', VERSION, ' by Marie Eckert');
		writeln('Usage: sadv [file] <parameters> <:section>');
		writeln;
		writeln('Parameters: ');
		writeln('-pm, --meta      Print Meta-Information');
		writeln('-l,  --lines     Print Line-Numbers');
		writeln('     --sections  List all sections');
		writeln;
		halt;
	end;

	path := ParamStr(1);

	if not FileExists(path) then
	begin
		writeln('Input File not found: ', path);
		halt;
	end;

	requiredSection := '.';
	printMeta := False;
	printLines := False;
	listSections := False;
	for i := 2 to ParamCount() do
	begin
		cparam := ParamStr(i);
		if cparam[1] = ':' then
		begin
			requiredSection := Copy(cparam, 2, Length(cparam));
			break;
		end;

		if (cparam = '-pm') or (cparam = '--meta') then
			printMeta := True
		else if (cparam = '-l') or (cparam = '--lines') then
			printLines := True
		else if (cparam = '--sections') then
			listSections := True;
	end;

	parseRes := ParseFile(path);
	if parseRes.status <> TParseStatus.Ok then
	begin
		WriteLn('error: ', MakeResultString(parseRes, path));
		Halt(1);
	end;

	if listSections then
	begin
		ListDocSections(parseRes.document);
		Halt;
	end;

	if printMeta then
		for i := 0 to parseRes.document.meta.Count do
			writeln('meta-data: ',
				parseRes.document.meta.Keys[i], ': ', parseRes.document.meta.Data[i]
			);

	writeln(STYLE_BOLD, STYLE_UNDERLINE, parseRes.document.title, #27'[0m');

	PrintSection(
		FindSectionByPath(parseRes.document, requiredSection),
		printLines
	);

end.
