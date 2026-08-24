unit TTextEditorDemo.Frame.TextEditor;

{ Define TEXTEDITOR_LSP to enable the language server panel.
  Requires the LSP-Pascal-Library sources (https://github.com/rickard67/LSP-Pascal-Library) on the search path. }

{$DEFINE TEXTEDITOR_LSP}

interface

uses
  Winapi.Windows, System.Classes, System.SysUtils, Vcl.Controls, Vcl.ExtCtrls, Vcl.Forms, Vcl.StdCtrls, TextEditor,
  TextEditor.MacroRecorder, TextEditor.Types
{$IFDEF TEXTEDITOR_LSP}
  , TextEditor.LanguageServer
{$ENDIF};

type
  TFrameTextEditor = class(TFrame)
    ButtonServerStart: TButton;
    ButtonServerStop: TButton;
    ButtonSettingsFile: TButton;
    EditServerCommandLine: TEdit;
    EditSettingsFile: TEdit;
    LabelServerCommandLine: TLabel;
    LabelSettingsFile: TLabel;
    LabelTestRun: TLabel;
    MemoServerLog: TMemo;
    PanelLanguageServer: TPanel;
    PanelTests: TPanel;
    TextEditor: TTextEditor;
    procedure ButtonServerStartClick(Sender: TObject);
    procedure ButtonServerStopClick(Sender: TObject);
    procedure ButtonSettingsFileClick(Sender: TObject);
    procedure TextEditorCreateHighlighterStream(const ASender: TObject; const AName: string; var AStream: TStream);
  private
    FClipboardDirty: Boolean;
    FFileName: string;
    FTestMacroRecorder: TCustomEditorMacroRecorder;
{$IFDEF TEXTEDITOR_LSP}
    FHintWindow: THintWindow;
    FHoverPosition: TTextEditorTextPosition;
    FHoverTimer: TTimer;
    FHoverWord: string;
    FLanguageServer: TTextEditorLanguageServer;
    function FindDelphiLSPConfiguration(const AFileName: string): string;
    function LanguageIdFromFileName(const AFileName: string): string;
    procedure HideHoverHint;
    procedure HoverTimerTimer(ASender: TObject);
    procedure LanguageServerGotoLocation(const ASender: TObject; const ALocation: TTextEditorLanguageServerLocation);
    procedure LanguageServerLog(const ASender: TObject; const AMessage: string);
    procedure TextEditorCompletionProposalExecute(const ASender: TObject; var AParams: TCompletionProposalParams);
    procedure TextEditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure TextEditorMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
{$ENDIF}
    function RunCaretNavigationSeed(ASeed: Integer): string;
    function RunClipboardRoundTripSeed(ASeed: Integer): string;
    function RunMacroSeed(ASeed: Integer): string;
    function RunPastEndOfFileSeed(ASeed: Integer): string;
    function RunSaveLoadSeed(ASeed: Integer): string;
    function RunSelectionInvariantsSeed(ASeed: Integer): string;
    function RunUndoRedoSeed(ASeed: Integer): string;
    function TestCommandNames(const ASeed, ASkip, ACount: Integer): string;
    procedure ExecuteTestCommand(const ACommand: Integer; const AViaCommandProcessor: Boolean = False);
    procedure LoadTestDocument;
    procedure PrepareTestClipboard;
    procedure RunTestLoop(const ASeeds: Integer; const ARun: TFunc<Integer, string>);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure OpenDocument(const AFileName: string);
    procedure RunCaretNavigationTest;
    procedure RunClipboardRoundTripTest;
    procedure RunHighlighterSweepTest;
    procedure RunMacroTest(const ARecorder: TCustomEditorMacroRecorder);
    procedure RunPastEndOfFileTest;
    procedure RunSaveLoadTest;
    procedure RunSelectionInvariantsTest;
    procedure RunUndoRedoTest;
{$IFDEF TEXTEDITOR_LSP}
    property LanguageServer: TTextEditorLanguageServer read FLanguageServer;
{$ENDIF}
  end;

implementation

{$R *.dfm}

uses
  System.IOUtils, System.Math, Vcl.Clipbrd, Vcl.Dialogs, TextEditor.KeyCommands;


procedure TFrameTextEditor.ButtonServerStartClick(Sender: TObject);
begin
{$IFDEF TEXTEDITOR_LSP}
  if FFileName.IsEmpty then
  begin
    MemoServerLog.Lines.Add('Open a file first so the server gets a document and a root folder.');
    Exit;
  end;

  FLanguageServer.ServerCommandLine := EditServerCommandLine.Text;
  FLanguageServer.RootPath := ExtractFileDir(FFileName);
  FLanguageServer.ServerDirectory := FLanguageServer.RootPath;
  FLanguageServer.Configuration := '';

  var LConfigurationFileName := Trim(EditSettingsFile.Text);

  if LConfigurationFileName.IsEmpty then
    LConfigurationFileName := FindDelphiLSPConfiguration(FFileName);

  if FileExists(LConfigurationFileName) then
  begin
    MemoServerLog.Lines.Add('Using ' + LConfigurationFileName);
    FLanguageServer.Configuration := '{"settings":{"settingsFile":"' +
      TTextEditorLanguageServer.FileNameToUri(LConfigurationFileName) + '"}}';
  end
  else
    MemoServerLog.Lines.Add('No settings file - a DelphiLSP server will only offer keywords.');

  FLanguageServer.OpenDocument(FFileName, LanguageIdFromFileName(FFileName));
  FLanguageServer.Start;

  ButtonServerStart.Enabled := False;
  ButtonServerStop.Enabled := True;
{$ENDIF}
end;

{$IFDEF TEXTEDITOR_LSP}

constructor TFrameTextEditor.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FLanguageServer := TTextEditorLanguageServer.Create(Self);
  FLanguageServer.Editor := TextEditor;
  FLanguageServer.OnGotoLocation := LanguageServerGotoLocation;
  FLanguageServer.OnLog := LanguageServerLog;

  FHoverTimer := TTimer.Create(Self);
  FHoverTimer.Enabled := False;
  FHoverTimer.Interval := 600;
  FHoverTimer.OnTimer := HoverTimerTimer;

  TextEditor.OnCompletionProposalExecute := TextEditorCompletionProposalExecute;
  TextEditor.OnKeyDown := TextEditorKeyDown;
  TextEditor.OnMouseMove := TextEditorMouseMove;
end;

destructor TFrameTextEditor.Destroy;
begin
  FLanguageServer.Stop;

  inherited Destroy;
end;

function TFrameTextEditor.LanguageIdFromFileName(const AFileName: string): string;
var
  LExtension: string;
begin
  LExtension := ExtractFileExt(AFileName).ToLower;

  if (LExtension = '.pas') or (LExtension = '.pp') or (LExtension = '.dpr') or (LExtension = '.lpr') or (LExtension = '.inc') then
    Exit('pascal');

  if (LExtension = '.c') or (LExtension = '.h') then
    Exit('c');

  if (LExtension = '.cpp') or (LExtension = '.cc') or (LExtension = '.cxx') or (LExtension = '.hpp') then
    Exit('cpp');

  if (LExtension = '.js') or (LExtension = '.mjs') then
    Exit('javascript');

  if LExtension = '.ts' then
    Exit('typescript');

  if LExtension = '.py' then
    Exit('python');

  if LExtension = '.rs' then
    Exit('rust');

  if LExtension = '.go' then
    Exit('go');

  if LExtension = '.cs' then
    Exit('csharp');

  if LExtension = '.java' then
    Exit('java');

  if LExtension = '.json' then
    Exit('json');

  if LExtension = '.md' then
    Exit('markdown');

  Result := 'plaintext';
end;

procedure TFrameTextEditor.OpenDocument(const AFileName: string);
begin
  FFileName := AFileName;

  if Trim(EditSettingsFile.Text).IsEmpty then
    EditSettingsFile.Text := FindDelphiLSPConfiguration(AFileName);

  FLanguageServer.OpenDocument(AFileName, LanguageIdFromFileName(AFileName));
end;

procedure TFrameTextEditor.ButtonSettingsFileClick(Sender: TObject);
var
  LOpenDialog: TOpenDialog;
begin
  LOpenDialog := TOpenDialog.Create(Self);
  try
    LOpenDialog.Filter := 'DelphiLSP settings (*.delphilsp.json)|*.delphilsp.json|All files (*.*)|*.*';

    if not FFileName.IsEmpty then
      LOpenDialog.InitialDir := ExtractFileDir(FFileName);

    if LOpenDialog.Execute then
      EditSettingsFile.Text := LOpenDialog.FileName;
  finally
    LOpenDialog.Free;
  end;
end;

{ DelphiLSP learns the compiler options from a <Project>.delphilsp.json (exported by RAD Studio or written by hand) that the
  client points to through workspace/didChangeConfiguration. Without it the server only offers keywords. The file is searched
  from the document's folder upwards since units usually sit below the project. }
function TFrameTextEditor.FindDelphiLSPConfiguration(const AFileName: string): string;
var
  LDirectory, LParentDirectory: string;
  LFiles: TArray<string>;
begin
  LDirectory := ExtractFileDir(AFileName);

  while not LDirectory.IsEmpty do
  begin
    LFiles := TDirectory.GetFiles(LDirectory, '*.delphilsp.json');

    if Length(LFiles) > 0 then
      Exit(LFiles[0]);

    LParentDirectory := ExtractFileDir(LDirectory);

    if LParentDirectory = LDirectory then
      Break;

    LDirectory := LParentDirectory;
  end;

  Result := '';
end;

procedure TFrameTextEditor.ButtonServerStopClick(Sender: TObject);
begin
  FLanguageServer.Stop;

  ButtonServerStart.Enabled := True;
  ButtonServerStop.Enabled := False;
end;

procedure TFrameTextEditor.LanguageServerLog(const ASender: TObject; const AMessage: string);
begin
  MemoServerLog.Lines.Add(AMessage);

  if AMessage.StartsWith('Server exited') then
  begin
    ButtonServerStart.Enabled := True;
    ButtonServerStop.Enabled := False;
  end;
end;

procedure TFrameTextEditor.LanguageServerGotoLocation(const ASender: TObject; const ALocation: TTextEditorLanguageServerLocation);
begin
  if not SameText(ALocation.FileName, FFileName) then
    MemoServerLog.Lines.Add(Format('Definition is in %s (%d:%d) - open it to navigate.', [ALocation.FileName,
      ALocation.TextPosition.Line + 1, ALocation.TextPosition.Char]));
end;

procedure TFrameTextEditor.TextEditorCompletionProposalExecute(const ASender: TObject; var AParams: TCompletionProposalParams);
begin
  if FLanguageServer.Completion(AParams.Items) then
  begin
    AParams.Options.ParseItemsFromText := False;
    AParams.Options.AddHighlighterKeywords := False;
    AParams.Options.AddSnippets := False;
    AParams.Options.ShowDescription := True;
  end;
end;

procedure TFrameTextEditor.TextEditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  HideHoverHint;

  if (Key = VK_F12) and (ssCtrl in Shift) then
  begin
    Key := 0;
    FLanguageServer.GotoDefinition;
  end;
end;

procedure TFrameTextEditor.HideHoverHint;
begin
  if Assigned(FHintWindow) then
    FHintWindow.ReleaseHandle;
end;

procedure TFrameTextEditor.TextEditorMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
var
  LTextPosition: TTextEditorTextPosition;
  LWord: string;
begin
  if not FLanguageServer.Initialized then
    Exit;

  if not TextEditor.GetTextPositionOfMouse(LTextPosition) then
  begin
    HideHoverHint;
    Exit;
  end;

  LWord := TextEditor.WordAtTextPosition(LTextPosition);

  if (LTextPosition.Line = FHoverPosition.Line) and (LWord = FHoverWord) and not LWord.IsEmpty then
    Exit;

  FHoverPosition := LTextPosition;
  FHoverWord := LWord;

  HideHoverHint;

  FHoverTimer.Enabled := False;
  FHoverTimer.Enabled := not LWord.IsEmpty;
end;

procedure TFrameTextEditor.HoverTimerTimer(ASender: TObject);
var
  LText: string;
  LDiagnostic: TTextEditorLanguageServerDiagnostic;
  LRect: TRect;
  LPoint: TPoint;
begin
  FHoverTimer.Enabled := False;

  if FLanguageServer.DiagnosticAt(FHoverPosition, LDiagnostic) then
    LText := LDiagnostic.Message
  else
    LText := FLanguageServer.Hover(FHoverPosition);

  if LText.IsEmpty then
    Exit;

  if not Assigned(FHintWindow) then
  begin
    FHintWindow := THintWindow.Create(Self);
    FHintWindow.Font.Name := TextEditor.Fonts.Text.Name;
  end;

  LRect := FHintWindow.CalcHintRect(600, LText, nil);
  LPoint := Mouse.CursorPos;

  OffsetRect(LRect, LPoint.X, LPoint.Y + 20);
  FHintWindow.ActivateHint(LRect, LText);
end;

{$ELSE}

constructor TFrameTextEditor.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  PanelLanguageServer.Visible := False;
end;

destructor TFrameTextEditor.Destroy;
begin
  inherited Destroy;
end;

procedure TFrameTextEditor.OpenDocument(const AFileName: string);
begin
  FFileName := AFileName;
end;

procedure TFrameTextEditor.ButtonServerStopClick(Sender: TObject);
begin
end;

procedure TFrameTextEditor.ButtonSettingsFileClick(Sender: TObject);
begin
end;

{$ENDIF}


procedure TFrameTextEditor.TextEditorCreateHighlighterStream(const ASender: TObject; const AName: string; var AStream: TStream);
begin
  if not AName.IsEmpty then
    AStream := TFileStream.Create(ExtractFilePath(ParamStr(0)) + '..\..\Highlighters\' + AName + '.json', fmOpenRead);
end;

{ Tests }

const
  cTestCommands: array [0..70] of Integer = (
    TKeyCommands.Char, TKeyCommands.Text, TKeyCommands.Char, TKeyCommands.Text, TKeyCommands.Char, TKeyCommands.Tab, TKeyCommands.ShiftTab,
    TKeyCommands.InsertLine, TKeyCommands.LineBreak, TKeyCommands.DeleteChar, TKeyCommands.Backspace, TKeyCommands.DeleteLine,
    TKeyCommands.DeleteWord, TKeyCommands.Left, TKeyCommands.Right, TKeyCommands.Up, TKeyCommands.Down, TKeyCommands.PageUp,
    TKeyCommands.PageDown, TKeyCommands.SelectionLeft, TKeyCommands.SelectionRight, TKeyCommands.SelectionUp, TKeyCommands.SelectionDown,
    TKeyCommands.LineBegin, TKeyCommands.LineEnd, TKeyCommands.WordLeft, TKeyCommands.WordRight, TKeyCommands.SelectionLineBegin,
    TKeyCommands.SelectionLineEnd, TKeyCommands.SelectionWordLeft, TKeyCommands.SelectionWordRight, TKeyCommands.PageUp,
    TKeyCommands.PageDown, TKeyCommands.SelectionPageUp, TKeyCommands.SelectionPageDown, TKeyCommands.LineComment,
    TKeyCommands.BlockComment, TKeyCommands.BlockIndent, TKeyCommands.BlockUnindent, TKeyCommands.Copy, TKeyCommands.Cut,
    TKeyCommands.Paste, TKeyCommands.MoveLinesUp, TKeyCommands.MoveLinesDown, TKeyCommands.DeleteBeginningOfLine,
    TKeyCommands.DeleteEndOfLine, TKeyCommands.DeleteWhitespaceBackward, TKeyCommands.DeleteWhitespaceForward,
    TKeyCommands.DeleteWordBackward, TKeyCommands.DeleteWordForward, TKeyCommands.EditorTop, TKeyCommands.EditorBottom,
    TKeyCommands.SelectionEditorTop, TKeyCommands.SelectionEditorBottom, TKeyCommands.PageTop, TKeyCommands.PageBottom,
    TKeyCommands.SelectionPageTop, TKeyCommands.SelectionPageBottom, TKeyCommands.SelectAll, TKeyCommands.SelectionWord,
    TKeyCommands.UpperCase, TKeyCommands.LowerCase, TKeyCommands.AlternatingCase, TKeyCommands.SentenceCase, TKeyCommands.TitleCase,
    TKeyCommands.UpperCaseBlock, TKeyCommands.LowerCaseBlock, TKeyCommands.AlternatingCaseBlock, TKeyCommands.KeywordsUpperCase,
    TKeyCommands.KeywordsLowerCase, TKeyCommands.KeywordsTitleCase);

  cTestDocumentText = 'a1'#13#10'b2'#13#10'c3'#13#10'd4'#13#10'e5'#13#10;
  cTestDocumentState = 'a1,b2,c3,d4,e5,';

type
  TTestClipboard = class(TPersistent)
  private
    FOpenRefCount: Integer;
    procedure HardClose;
    procedure HardOpen;
  end;

procedure TTestClipboard.HardClose;
begin
  CloseClipboard;

  TTestClipboard(Clipboard).FOpenRefCount:=0;
end;

procedure TTestClipboard.HardOpen;
begin
  while not OpenClipboard(Application.Handle) do
    Sleep(1);

  TTestClipboard(Clipboard).FOpenRefCount := 1;
end;

procedure TFrameTextEditor.LoadTestDocument;
begin
  TextEditor.Clear;

  var LStringStream := TStringStream.Create(cTestDocumentText);
  try
    TextEditor.LoadFromStream(LStringStream);
  finally
    LStringStream.Free;
  end;
end;

procedure TFrameTextEditor.PrepareTestClipboard;
begin
  if not FClipboardDirty then
    Exit;

  TTestClipboard(Clipboard).HardOpen;
  try
    Clipboard.AsText := 'b';
  finally
    TTestClipboard(Clipboard).HardClose;
  end;

  FClipboardDirty := False;
end;

procedure TFrameTextEditor.ExecuteTestCommand(const ACommand: Integer; const AViaCommandProcessor: Boolean = False);

  { CommandProcessor is the full input path - it notifies hooked command handlers (the macro recorder records through
    them), ExecuteCommand bypasses them }
  procedure Execute(const ACommand: Integer; const AChar: Char);
  begin
    if AViaCommandProcessor then
      TextEditor.CommandProcessor(ACommand, AChar, nil)
    else
      TextEditor.ExecuteCommand(ACommand, AChar, nil);
  end;

begin
  case ACommand of
    TKeyCommands.Cut, TKeyCommands.Copy, TKeyCommands.Paste:
      begin
         TTestClipboard(Clipboard).HardOpen;
         try
            Execute(ACommand, 'a');
         finally
            TTestClipboard(Clipboard).HardClose;
         end;

         if ACommand <> TKeyCommands.Paste then
           FClipboardDirty := True;
      end;
    TKeyCommands.Text:
      for var LIndex := 1 to Random(10) + 1 do
        Execute(TKeyCommands.Char, 'c');
  else
    Execute(ACommand, 'a');
  end;
end;

function TFrameTextEditor.TestCommandNames(const ASeed, ASkip, ACount: Integer): string;
var
  LIdent: string;
begin
  Result := '';

  RandSeed := ASeed;

  for var LIndex := 1 to ASkip + ACount do
  begin
    EditorCommandToIdent(cTestCommands[Random(Length(cTestCommands))], LIdent);

    if LIndex <= ASkip then
      Continue;

    Result := Result + ', ' + LIdent;
  end;
end;

procedure TFrameTextEditor.RunTestLoop(const ASeeds: Integer; const ARun: TFunc<Integer, string>);
var
  LRun: string;
begin
  PanelTests.Visible := True;
  FClipboardDirty := True;

  for var LIndex := 0 to ASeeds do
  begin
    if LIndex and 127 = 0 then
    begin
      LabelTestRun.Caption := LIndex.ToString;
      Application.ProcessMessages;
    end;

    LRun := ARun(LIndex);

    if not LRun.IsEmpty then
    begin
      LabelTestRun.Caption := LIndex.ToString + ': ' + LRun;
      Clipboard.AsText := LRun;
      Exit;
    end;
  end;

  ShowMessage('Done.');
  PanelTests.Visible := False;
end;

function TFrameTextEditor.RunUndoRedoSeed(ASeed: Integer): string;
const
  cActionsCount = 4;
  cSkipCount = 0;
var
  LCommand: TTextEditorCommand;
begin
  LoadTestDocument;
  PrepareTestClipboard;

  RandSeed := ASeed;

  for var LIndexAction := 1 to cSkipCount + cActionsCount do
  begin
    LCommand := cTestCommands[Random(Length(cTestCommands))];

    if LIndexAction <= cSkipCount then
      Continue;

    ExecuteTestCommand(LCommand);
  end;

  var LFinalState := TextEditor.Lines.CommaText;

  for var LIndex := 1 to cActionsCount do
     TextEditor.ExecuteCommand(TKeyCommands.Undo, #0, nil);

  if TextEditor.Lines.CommaText <> cTestDocumentState then
    Exit('Failed for RandSeed = ' + ASeed.ToString + TestCommandNames(ASeed, cSkipCount, cActionsCount));

  for var LIndex := 1 to cActionsCount do
    TextEditor.ExecuteCommand(TKeyCommands.Redo, #0, nil);

  if (TextEditor.Lines.CommaText <> LFinalState) and (TextEditor.Lines.CommaText <> '""') then
    Exit('Failed Redo for RandSeed = ' + ASeed.ToString + TestCommandNames(ASeed, cSkipCount, cActionsCount));

  Result := '';

  for var LIndex := 1 to cActionsCount do
    TextEditor.ExecuteCommand(TKeyCommands.Undo, #0, nil);
end;

procedure TFrameTextEditor.RunUndoRedoTest;
begin
  RunTestLoop(10000, RunUndoRedoSeed);
end;

function TFrameTextEditor.RunCaretNavigationSeed(ASeed: Integer): string;
const
  cBookmarkCount = 4;
var
  LPositions: array [0 .. cBookmarkCount - 1] of TTextEditorTextPosition;
  LPosition, LEditPosition: TTextEditorTextPosition;
begin
  Result := '';

  LoadTestDocument;

  RandSeed := ASeed;

  { Caret bookmarks return in last-in-first-out order }
  for var LIndex := 0 to cBookmarkCount - 1 do
  begin
    LPosition.Char := Random(3) + 1;
    LPosition.Line := Random(TextEditor.Lines.Count);
    TextEditor.TextPosition := LPosition;
    LPositions[LIndex] := TextEditor.TextPosition;

    TextEditor.AddCaretBookmark;
  end;

  for var LIndex := cBookmarkCount - 1 downto 0 do
  begin
    TextEditor.ExecuteCommand(TKeyCommands.ReturnToCaretBookmark, #0, nil);

    LPosition := TextEditor.TextPosition;

    if (LPosition.Line <> LPositions[LIndex].Line) or (LPosition.Char <> LPositions[LIndex].Char) then
      Exit('Caret bookmark ' + LIndex.ToString + ' returned to a wrong position for RandSeed = ' + ASeed.ToString);
  end;

  if TextEditor.CaretBookmarks.Count <> 0 then
    Exit('Caret bookmark list is not empty for RandSeed = ' + ASeed.ToString);

  { Swap toggles between the caret and the topmost caret bookmark }
  TextEditor.TextPosition := LPositions[0];
  TextEditor.AddCaretBookmark;
  TextEditor.TextPosition := LPositions[1];
  TextEditor.ExecuteCommand(TKeyCommands.SwapCaretBookmark, #0, nil);

  LPosition := TextEditor.TextPosition;

  if (LPosition.Line <> LPositions[0].Line) or (LPosition.Char <> LPositions[0].Char) then
    Exit('Swap did not move the caret to the bookmark for RandSeed = ' + ASeed.ToString);

  TextEditor.ExecuteCommand(TKeyCommands.SwapCaretBookmark, #0, nil);

  LPosition := TextEditor.TextPosition;

  if (LPosition.Line <> LPositions[1].Line) or (LPosition.Char <> LPositions[1].Char) then
    Exit('Swap did not move the caret back for RandSeed = ' + ASeed.ToString);

  TextEditor.ExecuteCommand(TKeyCommands.ReturnToCaretBookmark, #0, nil);

  { Go to last edit position finds the edit after the caret moved away }
  LPosition.Char := Random(3) + 1;
  LPosition.Line := Random(TextEditor.Lines.Count);
  TextEditor.TextPosition := LPosition;
  TextEditor.ExecuteCommand(TKeyCommands.Char, 'x', nil);
  LEditPosition := TextEditor.TextPosition;

  LPosition.Char := 1;
  LPosition.Line := (LEditPosition.Line + 1) mod TextEditor.Lines.Count;
  TextEditor.TextPosition := LPosition;

  TextEditor.ExecuteCommand(TKeyCommands.GoToLastEditPosition, #0, nil);

  if TextEditor.TextPosition.Line <> LEditPosition.Line then
    Exit('Go to last edit position landed on line ' + TextEditor.TextPosition.Line.ToString + ' instead of ' +
      LEditPosition.Line.ToString + ' for RandSeed = ' + ASeed.ToString);
end;

procedure TFrameTextEditor.RunCaretNavigationTest;
begin
  RunTestLoop(10000, RunCaretNavigationSeed);
end;

function TFrameTextEditor.RunPastEndOfFileSeed(ASeed: Integer): string;
const
  cActionsCount = 6;
var
  LPosition: TTextEditorTextPosition;
  LTargetLine: Integer;
begin
  Result := '';

  LoadTestDocument;
  PrepareTestClipboard;

  RandSeed := ASeed;

  TextEditor.Scroll.Options := TextEditor.Scroll.Options + [soPastEndOfFileMarker];

  if Odd(ASeed) then
    TextEditor.Scroll.Options := TextEditor.Scroll.Options + [soPastEndOfLine]
  else
    TextEditor.Scroll.Options := TextEditor.Scroll.Options - [soPastEndOfLine];

  try
    { Typing on a virtual line past the end of file materializes the missing lines }
    LTargetLine := TextEditor.Lines.Count + Random(5);
    LPosition.Char := Random(6) + 1;
    LPosition.Line := LTargetLine;
    TextEditor.TextPosition := LPosition;

    TextEditor.ExecuteCommand(TKeyCommands.Char, 'w', nil);

    if TextEditor.Lines.Count <= LTargetLine then
      Exit('Typing on a virtual line did not materialize the lines for RandSeed = ' + ASeed.ToString);

    if not TextEditor.Lines[LTargetLine].Contains('w') then
      Exit('Typed character not found on the target line for RandSeed = ' + ASeed.ToString);

    { Random commands with the caret dropped on virtual positions must keep the position valid }
    for var LIndex := 1 to cActionsCount do
    begin
      LPosition.Char := Random(6) + 1;
      LPosition.Line := TextEditor.Lines.Count + Random(3);
      TextEditor.TextPosition := LPosition;

      ExecuteTestCommand(cTestCommands[Random(Length(cTestCommands))]);

      LPosition := TextEditor.TextPosition;

      if (LPosition.Line < 0) or (LPosition.Char < 1) then
        Exit('Invalid caret position after command ' + LIndex.ToString + ' for RandSeed = ' + ASeed.ToString);
    end;
  except
    on E: Exception do
      Exit(E.ClassName + ': ' + E.Message + ' for RandSeed = ' + ASeed.ToString);
  end;
end;

procedure TFrameTextEditor.RunPastEndOfFileTest;
var
  LOptions: TTextEditorScrollOptions;
begin
  LOptions := TextEditor.Scroll.Options;
  try
    RunTestLoop(10000, RunPastEndOfFileSeed);
  finally
    TextEditor.Scroll.Options := LOptions;
  end;
end;

function TFrameTextEditor.RunSelectionInvariantsSeed(ASeed: Integer): string;
const
  cActionsCount = 6;

  function CheckPosition(const AName: string; const APosition: TTextEditorTextPosition): string;
  begin
    Result := '';

    { An empty document still has the caret on line 0 }
    var LMaxLine := Max(TextEditor.Lines.Count - 1, 0);

    if (APosition.Line < 0) or (APosition.Line > LMaxLine) then
      Result := AName + '.Line = ' + APosition.Line.ToString + ' out of [0, ' + LMaxLine.ToString + ']'
    else
    if APosition.Char < 1 then
      Result := AName + '.Char = ' + APosition.Char.ToString + ' < 1';
  end;

var
  LError: string;
begin
  Result := '';

  LoadTestDocument;
  PrepareTestClipboard;

  RandSeed := ASeed;

  for var LIndex := 1 to cActionsCount do
  begin
    ExecuteTestCommand(cTestCommands[Random(Length(cTestCommands))]);

    LError := CheckPosition('TextPosition', TextEditor.TextPosition);

    if LError.IsEmpty and TextEditor.SelectionAvailable then
    begin
      LError := CheckPosition('SelectionStart', TextEditor.SelectionStartPosition);

      if LError.IsEmpty then
        LError := CheckPosition('SelectionEnd', TextEditor.SelectionEndPosition);
    end;

    if not LError.IsEmpty then
      Exit('Failed for RandSeed = ' + ASeed.ToString + ' after command ' + LIndex.ToString + ' (' + LError + ')' +
        TestCommandNames(ASeed, 0, cActionsCount));
  end;
end;

procedure TFrameTextEditor.RunSelectionInvariantsTest;
begin
  RunTestLoop(10000, RunSelectionInvariantsSeed);
end;

function TFrameTextEditor.RunSaveLoadSeed(ASeed: Integer): string;
const
  cActionsCount = 10;
var
  LText: string;
begin
  Result := '';

  LoadTestDocument;
  PrepareTestClipboard;

  RandSeed := ASeed;

  for var LIndex := 1 to cActionsCount do
    ExecuteTestCommand(cTestCommands[Random(Length(cTestCommands))]);

  LText := TextEditor.Text;

  var LStream := TMemoryStream.Create;
  try
    TextEditor.SaveToStream(LStream);
    LStream.Position := 0;
    TextEditor.Clear;
    TextEditor.LoadFromStream(LStream);
  finally
    LStream.Free;
  end;

  if TextEditor.Text <> LText then
    Result := 'Failed for RandSeed = ' + ASeed.ToString + TestCommandNames(ASeed, 0, cActionsCount);
end;

procedure TFrameTextEditor.RunSaveLoadTest;
begin
  RunTestLoop(10000, RunSaveLoadSeed);
end;

function TFrameTextEditor.RunClipboardRoundTripSeed(ASeed: Integer): string;
var
  LPosition: TTextEditorTextPosition;
  LSelectedText: string;
  LOriginalText: string;
begin
  Result := '';

  LoadTestDocument;

  RandSeed := ASeed;

  LOriginalText := TextEditor.Text;

  LPosition.Char := Random(5) + 1;
  LPosition.Line := Random(TextEditor.Lines.Count);
  TextEditor.TextPosition := LPosition;
  TextEditor.SelectionStartPosition := LPosition;
  LPosition.Char := Random(5) + 1;
  LPosition.Line := Random(TextEditor.Lines.Count);
  TextEditor.SelectionEndPosition := LPosition;

  LSelectedText := TextEditor.SelectedText;

  if LSelectedText.IsEmpty then
    Exit;

  FClipboardDirty := True;

  TTestClipboard(Clipboard).HardOpen;
  try
    TextEditor.ExecuteCommand(TKeyCommands.Copy, #0, nil);

    if Clipboard.AsText <> LSelectedText then
      Exit('Failed Copy for RandSeed = ' + ASeed.ToString + ', clipboard [' + Clipboard.AsText + '] selected [' + LSelectedText + ']');

    TextEditor.ExecuteCommand(TKeyCommands.Cut, #0, nil);
    TextEditor.ExecuteCommand(TKeyCommands.Paste, #0, nil);
  finally
    TTestClipboard(Clipboard).HardClose;
  end;

  if TextEditor.Text <> LOriginalText then
    Exit('Failed Cut+Paste for RandSeed = ' + ASeed.ToString);

  TextEditor.ExecuteCommand(TKeyCommands.Undo, #0, nil);
  TextEditor.ExecuteCommand(TKeyCommands.Undo, #0, nil);

  if TextEditor.Text <> LOriginalText then
    Exit('Failed Undo after Cut+Paste for RandSeed = ' + ASeed.ToString);
end;

procedure TFrameTextEditor.RunClipboardRoundTripTest;
begin
  RunTestLoop(2000, RunClipboardRoundTripSeed);
end;

function TFrameTextEditor.RunMacroSeed(ASeed: Integer): string;
const
  cActionsCount = 4;
var
  LFinalText: string;
  LFinalPosition: TTextEditorTextPosition;

  procedure Playback;
  begin
    LoadTestDocument;

    FClipboardDirty := True;
    PrepareTestClipboard;

    TTestClipboard(Clipboard).HardOpen;
    try
      FTestMacroRecorder.PlaybackMacro(TextEditor);
    finally
      TTestClipboard(Clipboard).HardClose;
    end;
  end;

begin
  Result := '';

  LoadTestDocument;

  FClipboardDirty := True;
  PrepareTestClipboard;

  RandSeed := ASeed;

  FTestMacroRecorder.RecordMacro(TextEditor);
  try
    for var LIndex := 1 to cActionsCount do
      ExecuteTestCommand(cTestCommands[Random(Length(cTestCommands))], True);
  finally
    FTestMacroRecorder.Stop;
  end;

  LFinalText := TextEditor.Text;
  LFinalPosition := TextEditor.TextPosition;

  Playback;

  if TextEditor.Text <> LFinalText then
    Exit('Failed playback for RandSeed = ' + ASeed.ToString + TestCommandNames(ASeed, 0, cActionsCount));

  if (TextEditor.TextPosition.Line <> LFinalPosition.Line) or (TextEditor.TextPosition.Char <> LFinalPosition.Char) then
    Exit('Failed playback caret for RandSeed = ' + ASeed.ToString + TestCommandNames(ASeed, 0, cActionsCount));

  { The macro must survive its own stream format }
  var LStream := TMemoryStream.Create;
  try
    FTestMacroRecorder.SaveToStream(LStream);
    LStream.Position := 0;
    FTestMacroRecorder.LoadFromStream(LStream);
  finally
    LStream.Free;
  end;

  Playback;

  if TextEditor.Text <> LFinalText then
    Exit('Failed playback after macro save/load for RandSeed = ' + ASeed.ToString + TestCommandNames(ASeed, 0, cActionsCount));
end;

procedure TFrameTextEditor.RunMacroTest(const ARecorder: TCustomEditorMacroRecorder);
begin
  FTestMacroRecorder := ARecorder;

  FTestMacroRecorder.Stop;

  RunTestLoop(2000, RunMacroSeed);
end;

procedure TFrameTextEditor.RunHighlighterSweepTest;
var
  LHighlighters, LThemes: TArray<string>;
  LCurrentFile: string;
begin
  PanelTests.Visible := True;

  LHighlighters := TDirectory.GetFiles(ExtractFilePath(ParamStr(0)) + '..\..\Highlighters', '*.json');
  LThemes := TDirectory.GetFiles(ExtractFilePath(ParamStr(0)) + '..\..\Themes', '*.json');

  try
    for var LIndex := 0 to High(LHighlighters) do
    begin
      LabelTestRun.Caption := Format('%d / %d: %s', [LIndex + 1, Length(LHighlighters), TPath.GetFileName(LHighlighters[LIndex])]);
      Application.ProcessMessages;

      LCurrentFile := LHighlighters[LIndex];
      TextEditor.Highlighter.LoadFromFile(LCurrentFile);
      TextEditor.Lines.Text := TextEditor.Highlighter.Sample;

      for var LTheme in LThemes do
      begin
        LCurrentFile := LTheme;
        TextEditor.Highlighter.Colors.LoadFromFile(LTheme);
        TextEditor.Repaint;
      end;
    end;
  except
    on E: Exception do
    begin
      var LError := 'Failed loading ' + LCurrentFile + ': ' + E.ClassName + ' ' + E.Message;
      LabelTestRun.Caption := LError;
      Clipboard.AsText := LError;
      Exit;
    end;
  end;

  ShowMessage('Done.');
  PanelTests.Visible := False;
end;

end.
