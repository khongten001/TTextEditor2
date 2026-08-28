unit TextEditor.LanguageServer;

{ Language Server Protocol client for TTextEditor built on the LSP-Pascal-Library (https://github.com/rickard67/LSP-Pascal-Library). }

interface

uses
  Winapi.Windows, System.Classes, System.Generics.Collections, System.JSON, System.SysUtils, System.Types, System.UITypes, Vcl.Controls,
  Vcl.ExtCtrls, TextEditor, TextEditor.CompletionProposal.PopupWindow, TextEditor.Hover.PopupWindow, TextEditor.Marks, TextEditor.Types,
  XLSPClient, XLSPTypes;

type
  TTextEditorLanguageServerDiagnostic = record
    BeginPosition: TTextEditorTextPosition;
    EndPosition: TTextEditorTextPosition;
    &Message: string;
    Severity: Integer;
    Source: string;
  end;

  TTextEditorLanguageServerHoverPart = record
    Code: Boolean;
    Text: string;
  end;

  TTextEditorLanguageServerLocation = record
    FileName: string;
    TextPosition: TTextEditorTextPosition;
  end;

  TTextEditorLanguageServerSignature = record
    Parameters: TArray<string>;
    Text: string;
  end;

  TTextEditorLanguageServerSignatureHelp = record
    ActiveParameter: Integer;
    ActiveSignature: Integer;
    Signatures: TArray<TTextEditorLanguageServerSignature>;
  end;

  TTextEditorLanguageServerDiagnosticsEvent = procedure(const ASender: TObject; const ADiagnostics: TArray<TTextEditorLanguageServerDiagnostic>) of object;
  TTextEditorLanguageServerLocationEvent = procedure(const ASender: TObject; const ALocation: TTextEditorLanguageServerLocation) of object;
  TTextEditorLanguageServerLogEvent = procedure(const ASender: TObject; const AMessage: string) of object;

  TTextEditorLanguageServer = class(TComponent)
  strict private
    FChangeTimer: TTimer;
    FClient: TLSPClient;
    FCompletionItems: TArray<TLSPCompletionItem>;
    FCompletionItemsOffset: Integer;
    FCompletionItemsResolved: TArray<Boolean>;
    FCompletionTriggerEnabled: Boolean;
    FCompletionTriggerTimer: TTimer;
    FConfiguration: string;
    FDiagnostics: TArray<TTextEditorLanguageServerDiagnostic>;
    FDiagnosticMarkImageIndex: Integer;
    FDocumentOpen: Boolean;
    FDocumentVersion: Integer;
    FEditor: TCustomTextEditor;
    FFileName: string;
    FHoverCloseTimer: TTimer;
    FHoverCursorPoint: TPoint;
    FHoverDelay: Integer;
    FHoverEnabled: Boolean;
    FHoverKeepRect: TRect;
    FHoverLocation: TTextEditorLanguageServerLocation;
    FHoverLocationValid: Boolean;
    FHoverPopup: TTextEditorHoverPopupWindow;
    FHoverPosition: TTextEditorTextPosition;
    FHoverTimer: TTimer;
    FHoverWord: string;
    FInitializationOptions: string;
    FLanguageId: string;
    FLogTraffic: Boolean;
    FOnDiagnostics: TTextEditorLanguageServerDiagnosticsEvent;
    FOnGotoLocation: TTextEditorLanguageServerLocationEvent;
    FOnLog: TTextEditorLanguageServerLogEvent;
    FPreviousOnCompletionProposalExecute: TOnCompletionProposalExecute;
    FPreviousOnCustomTokenAttribute: TTextEditorCustomTokenAttributeEvent;
    FResolveTimer: TTimer;
    FRootPath: string;
    FServerCommandLine: string;
    FServerDirectory: string;
    FServerRunning: Boolean;
    FSignatureHelpActive: Boolean;
    FSignatureHelpEnabled: Boolean;
    FSignatureHelpPopup: TTextEditorHoverPopupWindow;
    FSignatureHelpTimer: TTimer;
    FSyncTimeout: Integer;
    function CompletionItemKindText(const AKind: Integer; const ADetail: string): string;
    function DecodeRawJsonString(const AText: string): string;
    function DocumentUri: string;
    function ExtractGotoLocation(const AGotoResult: TLSPGotoResult; out ALocation: TTextEditorLanguageServerLocation): Boolean;
    function GetActive: Boolean;
    function GetInitialized: Boolean;
    function HoverKeepZone: TRect;
    function IsCompletionTriggerCharacter(const AChar: Char): Boolean;
    function IsSignatureHelpTriggerCharacter(const AChar: Char): Boolean;
    function ParseHoverParts(const AText: string; const ACode: Boolean): TArray<TTextEditorLanguageServerHoverPart>;
    function PositionToLSP(const ATextPosition: TTextEditorTextPosition): TLSPPosition;
    function PositionToEditor(const APosition: TLSPPosition): TTextEditorTextPosition;
    function QuotedCommandLine(const ACommandLine: string): string;
    procedure ApplyDiagnostics;
    procedure ChangeTimerTimer(ASender: TObject);
    procedure ClientError(ASender: TObject; const AId, AErrorCode: Integer; const AErrorMessage: string; ARetriggerRequest: Boolean);
    procedure ClientExit(ASender: TObject; AExitCode: Integer; const ARestartServer: Boolean);
    procedure ClientInitialize(ASender: TObject; var AValue: TLSPInitializeParams);
    procedure ClientInitialized(ASender: TObject; var AValue: TLSPInitializeResult);
    procedure ClientLogMessage(ASender: TObject; const AType: TLSPMessageType; const AMessage: string);
    procedure ClientPublishDiagnostics(ASender: TObject; const AUri: string; const AVersion: Cardinal; const ADiagnostics: TArray<TLSPDiagnostic>);
    procedure CompletionSelectedItemChange(ASender: TObject);
    procedure CompletionTriggerTimerTimer(ASender: TObject);
    procedure EditorCompletionProposalExecute(const ASender: TObject; var AParams: TCompletionProposalParams);
    procedure EditorCustomTokenAttribute(const ASender: TObject; const AText: string; const ALine: Integer; const AChar: Integer;
      var AForegroundColor: TColor; var ABackgroundColor: TColor; var AStyles: TFontStyles; var AUnderline: TTextEditorUnderline;
      var AUnderlineColor: TColor);
    procedure EditorDocumentChanged(ASender: TObject);
    procedure EditorKeyDown(ASender: TObject; var AKey: Word; AShift: TShiftState);
    procedure EditorKeyPress(const ASender: TObject; var AKey: Char);
    procedure EditorMouseCursor(const ASender: TObject; const ALineCharPos: TTextEditorTextPosition; var ACursor: TCursor);
    procedure EditorMouseDown(ASender: TObject; AButton: TMouseButton; AShift: TShiftState; AX, AY: Integer);
    procedure HideHover;
    procedure HideSignatureHelp;
    procedure HookEditor;
    procedure HoverCloseTimerTimer(ASender: TObject);
    procedure HoverLinkClick(ASender: TObject);
    procedure HoverTimerTimer(ASender: TObject);
    procedure Log(const AMessage: string);
    procedure ResolveTimerTimer(ASender: TObject);
    procedure SendDidChange;
    procedure SetEditor(const AValue: TCustomTextEditor);
    procedure SetHoverDelay(const AValue: Integer);
    procedure ShowHoverPopup;
    procedure SignatureHelpTimerTimer(ASender: TObject);
    procedure SyncDocument;
    procedure UnhookEditor;
    procedure UpdateSignatureHelp;
  protected
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    class function FileNameToUri(const AFileName: string): string;
    function Completion(const AItems: TTextEditorCompletionProposalItems): Boolean;
    function DiagnosticAt(const ATextPosition: TTextEditorTextPosition; out ADiagnostic: TTextEditorLanguageServerDiagnostic): Boolean;
    function FindDefinition(const ATextPosition: TTextEditorTextPosition; out ALocation: TTextEditorLanguageServerLocation): Boolean;
    function Hover(const ATextPosition: TTextEditorTextPosition): string;
    function HoverParts(const ATextPosition: TTextEditorTextPosition): TArray<TTextEditorLanguageServerHoverPart>;
    function SignatureHelp(const ATextPosition: TTextEditorTextPosition;
      out AHelp: TTextEditorLanguageServerSignatureHelp): Boolean;
    procedure CloseDocument;
    procedure GotoDefinition;
    procedure OpenDocument(const AFileName: string; const ALanguageId: string);
    procedure SendConfiguration(const ASettingsJson: string);
    procedure Start;
    procedure Stop;
    property Active: Boolean read GetActive;
    property Diagnostics: TArray<TTextEditorLanguageServerDiagnostic> read FDiagnostics;
    property Initialized: Boolean read GetInitialized;
  published
    property CompletionTriggerEnabled: Boolean read FCompletionTriggerEnabled write FCompletionTriggerEnabled default True;
    property Configuration: string read FConfiguration write FConfiguration;
    property DiagnosticMarkImageIndex: Integer read FDiagnosticMarkImageIndex write FDiagnosticMarkImageIndex default -1;
    property Editor: TCustomTextEditor read FEditor write SetEditor;
    property HoverDelay: Integer read FHoverDelay write SetHoverDelay default 600;
    property HoverEnabled: Boolean read FHoverEnabled write FHoverEnabled default True;
    property InitializationOptions: string read FInitializationOptions write FInitializationOptions;
    property LogTraffic: Boolean read FLogTraffic write FLogTraffic default False;
    property OnDiagnostics: TTextEditorLanguageServerDiagnosticsEvent read FOnDiagnostics write FOnDiagnostics;
    property OnGotoLocation: TTextEditorLanguageServerLocationEvent read FOnGotoLocation write FOnGotoLocation;
    property OnLog: TTextEditorLanguageServerLogEvent read FOnLog write FOnLog;
    property RootPath: string read FRootPath write FRootPath;
    property ServerCommandLine: string read FServerCommandLine write FServerCommandLine;
    property ServerDirectory: string read FServerDirectory write FServerDirectory;
    property SignatureHelpEnabled: Boolean read FSignatureHelpEnabled write FSignatureHelpEnabled default True;
    property SyncTimeout: Integer read FSyncTimeout write FSyncTimeout default 1000;
  end;

const
  LANGUAGE_SERVER_DIAGNOSTIC_MARK_INDEX = 1000;
  LANGUAGE_SERVER_SEVERITY_ERROR = 1;
  LANGUAGE_SERVER_SEVERITY_WARNING = 2;
  LANGUAGE_SERVER_SEVERITY_INFORMATION = 3;
  LANGUAGE_SERVER_SEVERITY_HINT = 4;

implementation

uses
  System.Generics.Defaults, System.Math, TextEditor.CompletionProposal, TextEditor.PaintHelper, XLSPFunctions;

const
  CHANGE_DEBOUNCE_MS = 300;
  HOVER_CLOSE_POLL_MS = 100;
  MAX_COMPLETION_DESCRIPTION_LENGTH = 100;
  RESOLVE_DELAY_MS = 150;
  SIGNATURE_HELP_DELAY_MS = 50;

constructor TTextEditorLanguageServer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FCompletionTriggerEnabled := True;
  FDiagnosticMarkImageIndex := -1;
  FHoverDelay := 600;
  FHoverEnabled := True;
  FSignatureHelpEnabled := True;
  FSyncTimeout := 1000;

  FClient := TLSPClient.Create(Self);
  FClient.OnError := ClientError;
  FClient.OnExit := ClientExit;
  FClient.OnInitialize := ClientInitialize;
  FClient.OnInitialized := ClientInitialized;
  FClient.OnLogMessage := ClientLogMessage;
  FClient.OnShowMessage := ClientLogMessage;
  FClient.OnPublishDiagnostics := ClientPublishDiagnostics;

  FChangeTimer := TTimer.Create(Self);
  FChangeTimer.Enabled := False;
  FChangeTimer.Interval := CHANGE_DEBOUNCE_MS;
  FChangeTimer.OnTimer := ChangeTimerTimer;

  FHoverTimer := TTimer.Create(Self);
  FHoverTimer.Enabled := False;
  FHoverTimer.Interval := FHoverDelay;
  FHoverTimer.OnTimer := HoverTimerTimer;

  FHoverCloseTimer := TTimer.Create(Self);
  FHoverCloseTimer.Enabled := False;
  FHoverCloseTimer.Interval := HOVER_CLOSE_POLL_MS;
  FHoverCloseTimer.OnTimer := HoverCloseTimerTimer;

  FSignatureHelpTimer := TTimer.Create(Self);
  FSignatureHelpTimer.Enabled := False;
  FSignatureHelpTimer.Interval := SIGNATURE_HELP_DELAY_MS;
  FSignatureHelpTimer.OnTimer := SignatureHelpTimerTimer;

  FCompletionTriggerTimer := TTimer.Create(Self);
  FCompletionTriggerTimer.Enabled := False;
  FCompletionTriggerTimer.OnTimer := CompletionTriggerTimerTimer;

  FResolveTimer := TTimer.Create(Self);
  FResolveTimer.Enabled := False;
  FResolveTimer.Interval := RESOLVE_DELAY_MS;
  FResolveTimer.OnTimer := ResolveTimerTimer;
end;

destructor TTextEditorLanguageServer.Destroy;
begin
  FOnDiagnostics := nil;
  FOnGotoLocation := nil;
  FOnLog := nil;

  Stop;
  UnhookEditor;

  inherited Destroy;
end;

class function TTextEditorLanguageServer.FileNameToUri(const AFileName: string): string;
begin
  Result := FilePathToUri(AFileName);
end;

function TTextEditorLanguageServer.DecodeRawJsonString(const AText: string): string;
var
  LValue: TJSONValue;
begin
  Result := AText;

  if not AText.StartsWith('"') then
    Exit;

  LValue := TJSONObject.ParseJSONValue(AText);
  try
    if LValue is TJSONString then
      Result := TJSONString(LValue).Value;
  finally
    LValue.Free;
  end;
end;

function TTextEditorLanguageServer.DocumentUri: string;
begin
  Result := FilePathToUri(FFileName);
end;

function TTextEditorLanguageServer.GetActive: Boolean;
begin
  Result := FServerRunning;
end;

function TTextEditorLanguageServer.GetInitialized: Boolean;
begin
  Result := Active and FClient.Initialized;
end;

function TTextEditorLanguageServer.PositionToLSP(const ATextPosition: TTextEditorTextPosition): TLSPPosition;
begin
  Result.line := Max(0, ATextPosition.Line);
  Result.character := Max(0, ATextPosition.Char - 1);
end;

function TTextEditorLanguageServer.PositionToEditor(const APosition: TLSPPosition): TTextEditorTextPosition;
begin
  Result.Line := APosition.line;
  Result.Char := APosition.character + 1;
end;

procedure TTextEditorLanguageServer.Log(const AMessage: string);
begin
  if Assigned(FOnLog) then
    FOnLog(Self, AMessage);
end;

procedure TTextEditorLanguageServer.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited Notification(AComponent, AOperation);

  if AOperation = opRemove then
  begin
    if AComponent = FHoverPopup then
      FHoverPopup := nil;

    if AComponent = FSignatureHelpPopup then
      FSignatureHelpPopup := nil;

    if AComponent = FEditor then
    begin
      UnhookEditor;
      FEditor := nil;
    end;
  end;
end;

procedure TTextEditorLanguageServer.SetEditor(const AValue: TCustomTextEditor);
begin
  if AValue = FEditor then
    Exit;

  UnhookEditor;
  FEditor := AValue;
  HookEditor;
end;

procedure TTextEditorLanguageServer.SetHoverDelay(const AValue: Integer);
begin
  FHoverDelay := AValue;
  FHoverTimer.Interval := Max(1, AValue);
end;

procedure TTextEditorLanguageServer.HookEditor;
begin
  if not Assigned(FEditor) then
    Exit;

  FEditor.FreeNotification(Self);
  FEditor.AddChangeNotification(EditorDocumentChanged);
  FEditor.AddKeyDownHandler(EditorKeyDown);
  FEditor.AddKeyPressHandler(EditorKeyPress);
  FEditor.AddMouseCursorHandler(EditorMouseCursor);
  FEditor.AddMouseDownHandler(EditorMouseDown);

  FPreviousOnCompletionProposalExecute := FEditor.OnCompletionProposalExecute;
  FEditor.OnCompletionProposalExecute := EditorCompletionProposalExecute;

  FPreviousOnCustomTokenAttribute := FEditor.OnCustomTokenAttribute;
  FEditor.OnCustomTokenAttribute := EditorCustomTokenAttribute;
end;

procedure TTextEditorLanguageServer.UnhookEditor;
begin
  if not Assigned(FEditor) then
    Exit;

  HideHover;
  HideSignatureHelp;

  FCompletionTriggerTimer.Enabled := False;

  if Assigned(FHoverPopup) then
  begin
    FHoverPopup.RemoveFreeNotification(Self);
    FreeAndNil(FHoverPopup);
  end;

  if Assigned(FSignatureHelpPopup) then
  begin
    FSignatureHelpPopup.RemoveFreeNotification(Self);
    FreeAndNil(FSignatureHelpPopup);
  end;

  if not (csDestroying in FEditor.ComponentState) then
  begin
    FEditor.RemoveChangeNotification(EditorDocumentChanged);
    FEditor.RemoveKeyDownHandler(EditorKeyDown);
    FEditor.RemoveKeyPressHandler(EditorKeyPress);
    FEditor.RemoveMouseCursorHandler(EditorMouseCursor);
    FEditor.RemoveMouseDownHandler(EditorMouseDown);

    FEditor.OnCompletionProposalExecute := FPreviousOnCompletionProposalExecute;
    FEditor.OnCustomTokenAttribute := FPreviousOnCustomTokenAttribute;
  end;

  FPreviousOnCompletionProposalExecute := nil;
  FPreviousOnCustomTokenAttribute := nil;
end;

procedure TTextEditorLanguageServer.Start;
var
  LCommandLine: string;
begin
  if Active then
    Exit;

  if FServerCommandLine.IsEmpty then
    raise Exception.Create('Language server command line is not set');

  LCommandLine := QuotedCommandLine(FServerCommandLine);

  Log('Starting ' + LCommandLine);

  FClient.RunServer(LCommandLine, FServerDirectory);
  FServerRunning := True;

  FClient.SendRequest(lspInitialize);
end;

procedure TTextEditorLanguageServer.Stop;
begin
  if not Active then
    Exit;

  HideHover;
  HideSignatureHelp;

  FServerRunning := False;
  FChangeTimer.Enabled := False;
  FCompletionTriggerTimer.Enabled := False;
  FResolveTimer.Enabled := False;

  if FDocumentOpen then
    CloseDocument;

  Log('Stopping server');

  FClient.CloseServer;
end;

function TTextEditorLanguageServer.QuotedCommandLine(const ACommandLine: string): string;

  function WithExecutable(const AExecutable, AArguments: string): string;
  begin
    if SameText(ExtractFileExt(AExecutable), '.cmd') or SameText(ExtractFileExt(AExecutable), '.bat') then
      Result := 'cmd.exe /c "' + AExecutable + '"' + AArguments
    else
    if AExecutable.Contains(' ') then
      Result := '"' + AExecutable + '"' + AArguments
    else
      Result := AExecutable + AArguments;
  end;

var
  LIndex: Integer;
  LCandidate: string;
begin
  Result := ACommandLine.Trim;

  if Result.IsEmpty then
    Exit;

  if Result.StartsWith('"') then
  begin
    LIndex := Result.IndexOf('"', 1);

    if LIndex > 1 then
      Result := WithExecutable(Result.Substring(1, LIndex - 1), Result.Substring(LIndex + 1));

    Exit;
  end;

  if Result.IndexOf(' ') < 0 then
    Exit(WithExecutable(Result, ''));

  LIndex := 0;

  while LIndex >= 0 do
  begin
    LIndex := Result.IndexOf(' ', LIndex + 1);

    LCandidate := if LIndex < 0 then Result else Result.Substring(0, LIndex);

    if FileExists(LCandidate) then
      Exit(WithExecutable(LCandidate, Result.Substring(LCandidate.Length)));
  end;
end;

procedure TTextEditorLanguageServer.ClientInitialize(ASender: TObject; var AValue: TLSPInitializeParams);
var
  LRootPath: string;
begin
  LRootPath := FRootPath;

  if LRootPath.IsEmpty and not FFileName.IsEmpty then
    LRootPath := ExtractFileDir(FFileName);

  if not LRootPath.IsEmpty then
  begin
    AValue.AddRoot(LRootPath);
    AValue.AddWorkspaceFolders([LRootPath]);
  end;

  if not FInitializationOptions.IsEmpty then
    AValue.initializationOptions := FInitializationOptions;

  AValue.capabilities.AddSynchronizationSupport(True, False, False, False);
  AValue.capabilities.AddPublishDiagnosticsSupport(True, False, False, False);
  AValue.capabilities.AddCompletionSupport(False, False, False, True, True, False, False, False, False, [], ['detail', 'documentation']);
  AValue.capabilities.AddHoverSupport(False, False, True);
  AValue.capabilities.AddSignatureHelpSupport(False, True, True, False, False);
  AValue.capabilities.AddDefinitionSupport(False);
end;

procedure TTextEditorLanguageServer.ClientInitialized(ASender: TObject; var AValue: TLSPInitializeResult);
begin
  Log('Server initialized');

  if not FConfiguration.IsEmpty then
    SendConfiguration(FConfiguration);

  if not FFileName.IsEmpty and not FDocumentOpen then
    OpenDocument(FFileName, FLanguageId);
end;

procedure TTextEditorLanguageServer.SendConfiguration(const ASettingsJson: string);
begin
  if not Initialized then
    Exit;

  FClient.SendNotification(lspDidChangeConfiguration, '', nil, ASettingsJson);
end;

procedure TTextEditorLanguageServer.ClientExit(ASender: TObject; AExitCode: Integer; const ARestartServer: Boolean);
begin
  FServerRunning := False;
  FDocumentOpen := False;
  FChangeTimer.Enabled := False;

  Log('Server exited with code ' + AExitCode.ToString);

  FDiagnostics := nil;
  ApplyDiagnostics;
end;

procedure TTextEditorLanguageServer.ClientError(ASender: TObject; const AId, AErrorCode: Integer; const AErrorMessage: string;
  ARetriggerRequest: Boolean);
begin
  Log(Format('Error %d (request %d): %s', [AErrorCode, AId, AErrorMessage]));
end;

procedure TTextEditorLanguageServer.ClientLogMessage(ASender: TObject; const AType: TLSPMessageType; const AMessage: string);
begin
  if not FLogTraffic and (AType = lspMsgLog) and AMessage.TrimLeft.StartsWith('{') then
    Exit;

  Log(AMessage);
end;

procedure TTextEditorLanguageServer.OpenDocument(const AFileName: string; const ALanguageId: string);
var
  LParams: TLSPDidOpenTextDocumentParams;
begin
  if FDocumentOpen then
    CloseDocument;

  FFileName := AFileName;
  FLanguageId := ALanguageId;
  FDocumentVersion := 1;

  if not Initialized or not Assigned(FEditor) then
    Exit;

  LParams := TLSPDidOpenTextDocumentParams.Create;
  try
    LParams.textDocument.uri := DocumentUri;
    LParams.textDocument.languageId := FLanguageId;
    LParams.textDocument.version := FDocumentVersion;
    LParams.textDocument.text := FEditor.Text;

    FClient.SendNotification(lspDidOpenTextDocument, '', LParams);
  finally
    LParams.Free;
  end;

  FDocumentOpen := True;
end;

procedure TTextEditorLanguageServer.CloseDocument;
var
  LParams: TLSPDidCloseTextDocumentParams;
begin
  HideHover;
  HideSignatureHelp;

  FChangeTimer.Enabled := False;
  FCompletionTriggerTimer.Enabled := False;
  FResolveTimer.Enabled := False;

  if FDocumentOpen and Initialized then
  begin
    LParams := TLSPDidCloseTextDocumentParams.Create;
    try
      LParams.textDocument.uri := DocumentUri;

      FClient.SendNotification(lspDidCloseTextDocument, '', LParams);
    finally
      LParams.Free;
    end;
  end;

  FDocumentOpen := False;
  FDiagnostics := nil;
  ApplyDiagnostics;
end;

procedure TTextEditorLanguageServer.EditorDocumentChanged(ASender: TObject);
begin
  HideHover;

  if FDocumentOpen then
  begin
    FChangeTimer.Enabled := False;
    FChangeTimer.Enabled := True;
  end;
end;

procedure TTextEditorLanguageServer.ChangeTimerTimer(ASender: TObject);
begin
  FChangeTimer.Enabled := False;

  SendDidChange;
end;

procedure TTextEditorLanguageServer.SyncDocument;
begin
  FChangeTimer.Enabled := False;

  SendDidChange;
end;

procedure TTextEditorLanguageServer.SendDidChange;
var
  LParams: TLSPDidChangeTextDocumentParams;
  LChange: TLSPBaseTextDocumentContentChangeEvent;
begin
  if not FDocumentOpen or not Initialized or not Assigned(FEditor) then
    Exit;

  Inc(FDocumentVersion);

  LChange := TLSPBaseTextDocumentContentChangeEvent.Create;
  LChange.text := FEditor.Text;

  LParams := TLSPDidChangeTextDocumentParams.Create;
  try
    LParams.textDocument.uri := DocumentUri;
    LParams.textDocument.version := FDocumentVersion;
    LParams.contentChanges := [LChange];

    FClient.SendNotification(lspDidChangeTextDocument, '', LParams);
  finally
    LParams.Free;
  end;
end;

procedure TTextEditorLanguageServer.ClientPublishDiagnostics(ASender: TObject; const AUri: string; const AVersion: Cardinal;
  const ADiagnostics: TArray<TLSPDiagnostic>);
var
  LIndex: Integer;
begin
  if not SameText(UriToFilePath(AUri), FFileName) then
    Exit;

  SetLength(FDiagnostics, Length(ADiagnostics));

  for LIndex := 0 to High(ADiagnostics) do
  begin
    FDiagnostics[LIndex].BeginPosition := PositionToEditor(ADiagnostics[LIndex].range.start);
    FDiagnostics[LIndex].EndPosition := PositionToEditor(ADiagnostics[LIndex].range.&end);
    FDiagnostics[LIndex].Message := DecodeRawJsonString(ADiagnostics[LIndex].&message);
    FDiagnostics[LIndex].Severity := ADiagnostics[LIndex].severity;
    FDiagnostics[LIndex].Source := ADiagnostics[LIndex].source;
  end;

  ApplyDiagnostics;

  if Assigned(FOnDiagnostics) then
    FOnDiagnostics(Self, FDiagnostics);
end;

procedure TTextEditorLanguageServer.ApplyDiagnostics;
var
  LIndex: Integer;
  LMark: TTextEditorMark;
  LLinesMarked: TDictionary<Integer, Boolean>;
begin
  if not Assigned(FEditor) then
    Exit;

  for LIndex := FEditor.Marks.Count - 1 downto 0 do
  begin
    LMark := FEditor.Marks[LIndex];

    if LMark.&Index >= LANGUAGE_SERVER_DIAGNOSTIC_MARK_INDEX then
      FEditor.DeleteMark(LMark);
  end;

  if FDiagnosticMarkImageIndex >= 0 then
  begin
    LLinesMarked := TDictionary<Integer, Boolean>.Create;
    try
      for LIndex := 0 to High(FDiagnostics) do
      if not LLinesMarked.ContainsKey(FDiagnostics[LIndex].BeginPosition.Line) then
      begin
        LLinesMarked.Add(FDiagnostics[LIndex].BeginPosition.Line, True);
        FEditor.SetMark(LANGUAGE_SERVER_DIAGNOSTIC_MARK_INDEX + LIndex, FDiagnostics[LIndex].BeginPosition, FDiagnosticMarkImageIndex);
      end;
    finally
      LLinesMarked.Free;
    end;
  end;

  FEditor.Invalidate;
end;

function TTextEditorLanguageServer.DiagnosticAt(const ATextPosition: TTextEditorTextPosition;
  out ADiagnostic: TTextEditorLanguageServerDiagnostic): Boolean;
var
  LIndex: Integer;
  LBeginPosition, LEndPosition: TTextEditorTextPosition;
begin
  for LIndex := 0 to High(FDiagnostics) do
  begin
    LBeginPosition := FDiagnostics[LIndex].BeginPosition;
    LEndPosition := FDiagnostics[LIndex].EndPosition;

    if (ATextPosition.Line < LBeginPosition.Line) or (ATextPosition.Line > LEndPosition.Line) then
      Continue;

    if (ATextPosition.Line = LBeginPosition.Line) and (ATextPosition.Char < LBeginPosition.Char) then
      Continue;

    if (ATextPosition.Line = LEndPosition.Line) and (ATextPosition.Char >= LEndPosition.Char) then
      Continue;

    ADiagnostic := FDiagnostics[LIndex];
    Exit(True);
  end;

  Result := False;
end;

procedure TTextEditorLanguageServer.EditorCustomTokenAttribute(const ASender: TObject; const AText: string; const ALine: Integer;
  const AChar: Integer; var AForegroundColor: TColor; var ABackgroundColor: TColor; var AStyles: TFontStyles;
  var AUnderline: TTextEditorUnderline; var AUnderlineColor: TColor);
var
  LIndex: Integer;
  LTokenBegin, LTokenEnd: TTextEditorTextPosition;
  LDiagnostic: TTextEditorLanguageServerDiagnostic;
begin
  if Assigned(FPreviousOnCustomTokenAttribute) then
    FPreviousOnCustomTokenAttribute(ASender, AText, ALine, AChar, AForegroundColor, ABackgroundColor, AStyles, AUnderline,
      AUnderlineColor);

  if Length(FDiagnostics) = 0 then
    Exit;

  LTokenBegin.Line := ALine;
  LTokenBegin.Char := AChar + 1;
  LTokenEnd := LTokenBegin;
  Inc(LTokenEnd.Char, Max(0, Length(AText) - 1));

  for LIndex := 0 to High(FDiagnostics) do
  begin
    LDiagnostic := FDiagnostics[LIndex];

    if LDiagnostic.BeginPosition.Line > LTokenBegin.Line then
      Continue;

    if LDiagnostic.EndPosition.Line < LTokenBegin.Line then
      Continue;

    if (LDiagnostic.BeginPosition.Line = LTokenBegin.Line) and (LDiagnostic.BeginPosition.Char > LTokenEnd.Char) then
      Continue;

    if (LDiagnostic.EndPosition.Line = LTokenBegin.Line) and (LDiagnostic.EndPosition.Char <= LTokenBegin.Char) then
      Continue;

    AUnderline := ulWaveLine;

    case LDiagnostic.Severity of
      LANGUAGE_SERVER_SEVERITY_ERROR:
        AUnderlineColor := TColors.Red;
      LANGUAGE_SERVER_SEVERITY_WARNING:
        AUnderlineColor := TColors.Orange;
    else
      AUnderlineColor := TColors.Dodgerblue;
    end;

    Exit;
  end;
end;

function TTextEditorLanguageServer.CompletionItemKindText(const AKind: Integer; const ADetail: string): string;

  function IsFunctionDetail: Boolean;
  var
    LRest: string;
    LIndex, LParenthesisCount: Integer;
  begin
    LRest := ADetail.TrimLeft;

    if LRest.StartsWith('(') then
    begin
      LParenthesisCount := 0;

      for LIndex := 1 to LRest.Length do
      begin
        if LRest[LIndex] = '(' then
          Inc(LParenthesisCount)
        else
        if LRest[LIndex] = ')' then
        begin
          Dec(LParenthesisCount);

          if LParenthesisCount = 0 then
          begin
            LRest := LRest.Substring(LIndex);
            Break;
          end;
        end;
      end;
    end;

    Result := LRest.TrimLeft.StartsWith(':');
  end;

var
  LPascal: Boolean;
begin
  LPascal := SameText(FLanguageId, 'pascal');

  // TODO: kind type, remove comments
  case AKind of
    2, 3: // method, function
      if LPascal then
        Result := if IsFunctionDetail then 'function' else 'procedure'
      else
        Result := if AKind = 2 then 'method' else 'function';
    4:
      Result := 'constructor';
    5: // field
      Result := if LPascal then 'var' else 'field';
    6: // variable
      Result := if LPascal then 'var' else 'variable';
    7: // class
      Result := if LPascal then 'type' else 'class';
    8: // interface
      Result := if LPascal then 'type' else 'interface';
    9: // module
      Result := if LPascal then 'unit' else 'module';
    10:
      Result := 'property';
    11:
      Result := 'unit';
    12: // value
      Result := if LPascal then 'const' else 'value';
    13: // enum
      Result := if LPascal then 'type' else 'enum';
    14:
      Result := 'keyword';
    15:
      Result := 'snippet';
    17:
      Result := 'file';
    19:
      Result := 'folder';
    20: // enum member
      Result := if LPascal then 'const' else 'enum member';
    21: // constant
      Result := 'const';
    22: // struct
      Result := if LPascal then 'type' else 'struct';
    23:
      Result := 'event';
    24:
      Result := 'operator';
    25: // type parameter
      Result := 'type';
  else
    Result := '';
  end;
end;

function TTextEditorLanguageServer.Completion(const AItems: TTextEditorCompletionProposalItems): Boolean;
var
  LParams: TLSPCompletionParams;
  LList: TLSPCompletionList;
begin
  Result := False;

  if not FDocumentOpen or not Initialized or not FClient.IsRequestSupported(lspCompletion) then
    Exit;

  SyncDocument;

  LList := nil;

  LParams := TLSPCompletionParams.Create;
  try
    LParams.textDocument.uri := DocumentUri;
    LParams.position := PositionToLSP(FEditor.TextPosition);

    if not FClient.SendSyncRequest(lspCompletion, LParams,
      procedure(AJson: TJSONObject)
      begin
        if Assigned(AJson.Values['result']) then
          LList := JsonCompletionResultToObject(AJson.Values['result']);
      end, FSyncTimeout) then
      Exit;
  finally
    LParams.Free;
  end;

  if not Assigned(LList) then
    Exit;

  try
    var LIndexes: TArray<Integer>;
    SetLength(LIndexes, Length(LList.items));

    for var LIndex := 0 to High(LIndexes) do
      LIndexes[LIndex] := LIndex;

    TArray.Sort<Integer>(LIndexes, TComparer<Integer>.Construct(
      function(const ALeft, ARight: Integer): Integer
      var
        LLeftKey, LRightKey: string;
      begin
        LLeftKey := if LList.items[ALeft].sortText.IsEmpty then LList.items[ALeft].&label else LList.items[ALeft].sortText;
        LRightKey := if LList.items[ARight].sortText.IsEmpty then LList.items[ARight].&label else LList.items[ARight].sortText;

        Result := CompareStr(LLeftKey, LRightKey);

        if Result = 0 then
          Result := ALeft - ARight;
      end));

    FCompletionItemsOffset := AItems.Count;
    FCompletionItems := nil;
    FCompletionItemsResolved := nil;
    SetLength(FCompletionItems, Length(LList.items));
    SetLength(FCompletionItemsResolved, Length(LList.items));

    var LItemCount := 0;

    for var LIndex in LIndexes do
    begin
      var LItem := LList.items[LIndex];
      var LProposalItem: TTextEditorCompletionProposalItem;
      LProposalItem.Keyword := LItem.insertText;

      if LProposalItem.Keyword.IsEmpty then
      begin
        LProposalItem.Keyword := LItem.&label.Trim;

        if LProposalItem.Keyword.EndsWith('?') then
          LProposalItem.Keyword := LProposalItem.Keyword.Substring(0, LProposalItem.Keyword.Length - 1);
      end;

      LProposalItem.Kind := CompletionItemKindText(LItem.kind, LItem.detail);
      LProposalItem.Description := LItem.detail.Replace(#13, '').Replace(#10, ' ');

      if Length(LProposalItem.Description) > MAX_COMPLETION_DESCRIPTION_LENGTH then
        LProposalItem.Description := Copy(LProposalItem.Description, 1, MAX_COMPLETION_DESCRIPTION_LENGTH - 3) + '...';
      LProposalItem.SnippetIndex := -1;

      FCompletionItems[LItemCount] := LItem;
      Inc(LItemCount);

      AItems.Add(LProposalItem);
    end;

    Result := Length(LList.items) > 0;
  finally
    LList.Free;
  end;
end;

function TTextEditorLanguageServer.ParseHoverParts(const AText: string; const ACode: Boolean): TArray<TTextEditorLanguageServerHoverPart>;
var
  LParts: TList<TTextEditorLanguageServerHoverPart>;
  LLines: TArray<string>;
  LLine, LTrimmedLine: string;
  LInCode: Boolean;
  LBracketIndex, LLinkEndIndex: Integer;

  function IsMarkdownRule(const ALine: string): Boolean;
  begin
    Result := False;

    if (ALine.Length < 3) or not CharInSet(ALine[1], ['-', '*', '_']) then
      Exit;

    for var LIndex := 2 to ALine.Length do
    if ALine[LIndex] <> ALine[1] then
      Exit;

    Result := True;
  end;

  function LastPartIsBlank: Boolean;
  begin
    Result := (LParts.Count = 0) or LParts.Last.Text.IsEmpty;
  end;

  procedure AddPart(const ACodePart: Boolean; const AText: string);
  var
    LPart: TTextEditorLanguageServerHoverPart;
  begin
    if (LParts.Count > 0) and not AText.IsEmpty and (LParts.Last.Code = ACodePart) and (LParts.Last.Text = AText) then
      Exit;

    LPart.Code := ACodePart;
    LPart.Text := AText;
    LParts.Add(LPart);
  end;

begin
  LParts := TList<TTextEditorLanguageServerHoverPart>.Create;
  try
    LInCode := ACode;
    LLines := AText.Replace(#13, '').Split([#10]);

    for LLine in LLines do
    begin
      LTrimmedLine := LLine.TrimRight;

      if LTrimmedLine.TrimLeft.StartsWith('```') then
      begin
        LInCode := not LInCode;
        Continue;
      end;

      if LInCode then
      begin
        if LTrimmedLine.IsEmpty and LastPartIsBlank then
          Continue;

        AddPart(True, LTrimmedLine);

        Continue;
      end;

      LBracketIndex := LTrimmedLine.IndexOf('[');

      while LBracketIndex >= 0 do
      begin
        LLinkEndIndex := LTrimmedLine.IndexOf(')', LBracketIndex);

        if (LLinkEndIndex > LBracketIndex) and (LTrimmedLine.IndexOf('](', LBracketIndex) > LBracketIndex) and
          (LTrimmedLine.IndexOf('](', LBracketIndex) < LLinkEndIndex) then
        begin
          var LLabelText := LTrimmedLine.Substring(LBracketIndex + 1, LTrimmedLine.IndexOf('](', LBracketIndex) - LBracketIndex - 1);
          LTrimmedLine := LTrimmedLine.Substring(0, LBracketIndex) + LLabelText + LTrimmedLine.Substring(LLinkEndIndex + 1);
        end
        else
          Break;

        LBracketIndex := LTrimmedLine.IndexOf('[');
      end;

      LTrimmedLine := LTrimmedLine.Replace('**', '').Replace('`', '').Trim;

      while LTrimmedLine.StartsWith('#') do
        LTrimmedLine := LTrimmedLine.Substring(1).TrimLeft;

      if IsMarkdownRule(LTrimmedLine) then
        LTrimmedLine := '';

      if LTrimmedLine.IsEmpty and LastPartIsBlank then
        Continue;

      AddPart(False, LTrimmedLine);
    end;

    while (LParts.Count > 0) and LParts.Last.Text.IsEmpty do
      LParts.Delete(LParts.Count - 1);

    Result := LParts.ToArray;
  finally
    LParts.Free;
  end;
end;

function TTextEditorLanguageServer.HoverParts(const ATextPosition: TTextEditorTextPosition): TArray<TTextEditorLanguageServerHoverPart>;
var
  LParams: TLSPHoverParams;
  LHover: TLSPHoverResult;
begin
  Result := nil;

  if not FDocumentOpen or not Initialized or not FClient.IsRequestSupported(lspHover) then
    Exit;

  if FChangeTimer.Enabled then
    SyncDocument;

  LHover := nil;

  LParams := TLSPHoverParams.Create;
  try
    LParams.textDocument.uri := DocumentUri;
    LParams.position := PositionToLSP(ATextPosition);

    if not FClient.SendSyncRequest(lspHover, LParams,
      procedure(AJson: TJSONObject)
      begin
        if Assigned(AJson.Values['result']) and not AJson.Values['result'].Null then
          LHover := JsonHoverResultToObject(AJson.Values['result']);
      end, FSyncTimeout) then
      Exit;
  finally
    LParams.Free;
  end;

  if not Assigned(LHover) then
    Exit;

  try
    if not LHover.contents.value.IsEmpty then
      Result := ParseHoverParts(LHover.contents.value, False)
    else
    if not LHover.contentsMarked.value.IsEmpty then
      Result := ParseHoverParts(LHover.contentsMarked.value, not LHover.contentsMarked.language.IsEmpty)
    else
    for var LMarked in LHover.contentsMarkedArray do
      Result := Result + ParseHoverParts(LMarked.value, not LMarked.language.IsEmpty);
  finally
    LHover.Free;
  end;
end;

function TTextEditorLanguageServer.Hover(const ATextPosition: TTextEditorTextPosition): string;
var
  LPart: TTextEditorLanguageServerHoverPart;
  LText: string;
begin
  LText := '';

  for LPart in HoverParts(ATextPosition) do
    LText := LText + LPart.Text + sLineBreak;

  Result := LText.TrimRight;
end;

function TTextEditorLanguageServer.ExtractGotoLocation(const AGotoResult: TLSPGotoResult;
  out ALocation: TTextEditorLanguageServerLocation): Boolean;
var
  LUri: string;
  LRange: TLSPRange;
begin
  if Length(AGotoResult.locations) > 0 then
  begin
    LUri := AGotoResult.locations[0].uri;
    LRange := AGotoResult.locations[0].range;
  end
  else
  if Length(AGotoResult.locationLinks) > 0 then
  begin
    LUri := AGotoResult.locationLinks[0].targetUri;
    LRange := AGotoResult.locationLinks[0].targetSelectionRange;
  end
  else
  begin
    LUri := AGotoResult.location.uri;
    LRange := AGotoResult.location.range;
  end;

  if LUri.IsEmpty then
    Exit(False);

  ALocation.FileName := UriToFilePath(LUri);
  ALocation.TextPosition := PositionToEditor(LRange.start);

  Result := True;
end;

function TTextEditorLanguageServer.FindDefinition(const ATextPosition: TTextEditorTextPosition;
  out ALocation: TTextEditorLanguageServerLocation): Boolean;
var
  LParams: TLSPTextDocumentPositionParams;
  LGotoResult: TLSPGotoResult;
begin
  Result := False;
  ALocation := Default(TTextEditorLanguageServerLocation);

  if not FDocumentOpen or not Initialized or not FClient.IsRequestSupported(lspGotoDefinition) then
    Exit;

  if FChangeTimer.Enabled then
    SyncDocument;

  LGotoResult := nil;

  LParams := TLSPTextDocumentPositionParams.Create;
  try
    LParams.textDocument.uri := DocumentUri;
    LParams.position := PositionToLSP(ATextPosition);

    if not FClient.SendSyncRequest(lspGotoDefinition, LParams,
      procedure(AJson: TJSONObject)
      begin
        if Assigned(AJson.Values['result']) and not AJson.Values['result'].Null then
          LGotoResult := JsonGotoResultToObject(AJson.Values['result']);
      end, FSyncTimeout) then
      Exit;
  finally
    LParams.Free;
  end;

  if not Assigned(LGotoResult) then
    Exit;

  try
    Result := ExtractGotoLocation(LGotoResult, ALocation);
  finally
    LGotoResult.Free;
  end;
end;

procedure TTextEditorLanguageServer.GotoDefinition;
var
  LParams: TLSPTextDocumentPositionParams;
begin
  if not FDocumentOpen or not Initialized or not FClient.IsRequestSupported(lspGotoDefinition) then
    Exit;

  if FChangeTimer.Enabled then
    SyncDocument;

  LParams := TLSPTextDocumentPositionParams.Create;
  try
    LParams.textDocument.uri := DocumentUri;
    LParams.position := PositionToLSP(FEditor.TextPosition);

    FClient.SendRequest(lspGotoDefinition, LParams,
      procedure(AJson: TJSONObject)
      var
        LResult: TLSPGotoResult;
        LLocation: TTextEditorLanguageServerLocation;
        LFound: Boolean;
      begin
        if not Assigned(AJson.Values['result']) or AJson.Values['result'].Null then
          Exit;

        LResult := JsonGotoResultToObject(AJson.Values['result']);
        try
          LFound := ExtractGotoLocation(LResult, LLocation);
        finally
          LResult.Free;
        end;

        if not LFound then
          Exit;

        TThread.Queue(nil,
          procedure
          begin
            if SameText(LLocation.FileName, FFileName) and Assigned(FEditor) then
              FEditor.GoToLineAndSetPosition(LLocation.TextPosition.Line, LLocation.TextPosition.Char);

            if Assigned(FOnGotoLocation) then
              FOnGotoLocation(Self, LLocation);
          end);
      end);
  finally
    LParams.Free;
  end;
end;

function TTextEditorLanguageServer.HoverKeepZone: TRect;
begin
  Result := FHoverKeepRect;

  if Assigned(FHoverPopup) and FHoverPopup.Visible then
    Result := TRect.Union(Result, FHoverPopup.BoundsRect);

  Result.Inflate(2, 2);
end;

procedure TTextEditorLanguageServer.EditorMouseCursor(const ASender: TObject; const ALineCharPos: TTextEditorTextPosition;
  var ACursor: TCursor);
var
  LCursorPoint: TPoint;
  LTextPosition: TTextEditorTextPosition;
  LWord: string;
begin
  if not FHoverEnabled or not Initialized or not Assigned(FEditor) then
    Exit;

  LCursorPoint := Mouse.CursorPos;

  if LCursorPoint = FHoverCursorPoint then
    Exit;

  FHoverCursorPoint := LCursorPoint;

  if Assigned(FHoverPopup) and FHoverPopup.Visible and PtInRect(HoverKeepZone, LCursorPoint) then
    Exit;

  if not FEditor.GetTextPositionOfMouse(LTextPosition) then
  begin
    HideHover;
    Exit;
  end;

  LWord := FEditor.WordAtTextPosition(LTextPosition);

  if (LTextPosition.Line = FHoverPosition.Line) and (LWord = FHoverWord) and not LWord.IsEmpty then
    Exit;

  HideHover;

  FHoverPosition := LTextPosition;
  FHoverWord := LWord;
  FHoverTimer.Enabled := not LWord.IsEmpty;
end;

procedure TTextEditorLanguageServer.EditorKeyDown(ASender: TObject; var AKey: Word; AShift: TShiftState);
begin
  HideHover;

  if FSignatureHelpActive then
  case AKey of
    VK_ESCAPE:
      begin
        HideSignatureHelp;
        AKey := 0;
      end;
    VK_BACK, VK_DELETE, VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN, VK_HOME, VK_END, VK_RETURN:
      begin
        FSignatureHelpTimer.Enabled := False;
        FSignatureHelpTimer.Enabled := True;
      end;
  end;
end;

procedure TTextEditorLanguageServer.EditorKeyPress(const ASender: TObject; var AKey: Char);
begin
  if not Initialized or not FDocumentOpen then
    Exit;

  if FSignatureHelpEnabled and (IsSignatureHelpTriggerCharacter(AKey) or (FSignatureHelpActive and (AKey = ')'))) then
  begin
    FSignatureHelpTimer.Enabled := False;
    FSignatureHelpTimer.Enabled := True;
  end;

  FCompletionTriggerTimer.Enabled := False;

  if FSignatureHelpEnabled and FClient.IsRequestSupported(lspSignatureHelp) and IsSignatureHelpTriggerCharacter(AKey) then
    Exit;

  if FCompletionTriggerEnabled and Assigned(FEditor) and FEditor.CompletionProposal.Active and
    IsCompletionTriggerCharacter(AKey) and FClient.IsRequestSupported(lspCompletion) then
  begin
    if not FEditor.CompletionProposal.Trigger.Active or (Pos(AKey, FEditor.CompletionProposal.Trigger.Chars) = 0) then
    begin
      FCompletionTriggerTimer.Interval := Max(1, FEditor.CompletionProposal.Trigger.Interval);
      FCompletionTriggerTimer.Enabled := True;
    end;
  end;
end;

procedure TTextEditorLanguageServer.EditorMouseDown(ASender: TObject; AButton: TMouseButton; AShift: TShiftState; AX, AY: Integer);
begin
  HideHover;
  HideSignatureHelp;
end;

procedure TTextEditorLanguageServer.HideHover;
begin
  FHoverTimer.Enabled := False;
  FHoverCloseTimer.Enabled := False;
  FHoverWord := '';

  if Assigned(FHoverPopup) then
    FHoverPopup.Hide;
end;

function TTextEditorLanguageServer.IsCompletionTriggerCharacter(const AChar: Char): Boolean;
var
  LProvider: TLSPCompletionOptions;
  LCharacter: string;
begin
  LProvider := if Assigned(FClient.ServerCapabilities) then FClient.ServerCapabilities.completionProvider else nil;

  if not Assigned(LProvider) or (Length(LProvider.triggerCharacters) = 0) then
    Exit(AChar = '.');

  for LCharacter in LProvider.triggerCharacters do
  if LCharacter = AChar then
    Exit(True);

  Result := False;
end;

function TTextEditorLanguageServer.IsSignatureHelpTriggerCharacter(const AChar: Char): Boolean;
var
  LProvider: TLSPSignatureHelpOptions;
  LCharacter: string;
begin
  LProvider := if Assigned(FClient.ServerCapabilities) then FClient.ServerCapabilities.signatureHelpProvider else nil;

  if not Assigned(LProvider) or (Length(LProvider.triggerCharacters) = 0) then
    Exit(CharInSet(AChar, ['(', ',']));

  for LCharacter in LProvider.triggerCharacters do
  if LCharacter = AChar then
    Exit(True);

  for LCharacter in LProvider.retriggerCharacters do
  if FSignatureHelpActive and (LCharacter = AChar) then
    Exit(True);

  Result := False;
end;

procedure TTextEditorLanguageServer.CompletionSelectedItemChange(ASender: TObject); //FI:O804 Method parameter is declared but never used
begin
  FResolveTimer.Enabled := False;
  FResolveTimer.Enabled := True;
end;

procedure TTextEditorLanguageServer.ResolveTimerTimer(ASender: TObject); //FI:O804 Method parameter is declared but never used
var
  LPopupWindow: TTextEditorCompletionProposalPopupWindow;
  LItemsIndex, LArrayIndex: Integer;
  LProposalItem: TTextEditorCompletionProposalItem;
  LParams: TLSPCompletionItemResolveParams;
  LResolvedItem: TLSPCompletionItem;
  LResolved: Boolean;
  LDescription, LLine: string;
begin
  FResolveTimer.Enabled := False;

  if not Initialized or not Assigned(FEditor) then
    Exit;

  LPopupWindow := FEditor.CompletionProposalPopupWindow;

  if not Assigned(LPopupWindow) or not LPopupWindow.Visible then
    Exit;

  LItemsIndex := LPopupWindow.SelectedItemIndex;
  LArrayIndex := LItemsIndex - FCompletionItemsOffset;

  if (LItemsIndex < 0) or (LItemsIndex >= LPopupWindow.Items.Count) or (LArrayIndex < 0) or
    (LArrayIndex >= Length(FCompletionItems)) then
    Exit;

  if FCompletionItemsResolved[LArrayIndex] then
    Exit;

  FCompletionItemsResolved[LArrayIndex] := True;

  if not LPopupWindow.Items[LItemsIndex].Description.IsEmpty then
    Exit;

  LResolved := False;

  LParams := TLSPCompletionItemResolveParams.Create;
  try
    LParams.completionItem := FCompletionItems[LArrayIndex];

    if not FClient.SendSyncRequest(lspCompletionItemResolve, LParams,
      procedure(AJson: TJSONObject)
      var
        LResult: TLSPCompetionItemResolveResult;
      begin
        if Assigned(AJson.Values['result']) and not AJson.Values['result'].Null then
        begin
          LResult := JsonCompletionItemResolveResultToObject(AJson.Values['result']);
          try
            LResolvedItem := LResult.completionItem;
            LResolved := True;
          finally
            LResult.Free;
          end;
        end;
      end, FSyncTimeout) then
      Exit;
  finally
    LParams.Free;
  end;

  if not LResolved then
    Exit;

  LDescription := LResolvedItem.detail.Replace(#13, '').Replace(#10, ' ');

  if LDescription.IsEmpty then
  for LLine in LResolvedItem.documentationMarkup.value.Replace(#13, '').Split([#10]) do
  begin
    if not LLine.Trim.IsEmpty then
    begin
      LDescription := LLine.Trim;
      Break;
    end;
  end;

  if LDescription.IsEmpty then
    Exit;

  if Length(LDescription) > MAX_COMPLETION_DESCRIPTION_LENGTH then
    LDescription := Copy(LDescription, 1, MAX_COMPLETION_DESCRIPTION_LENGTH - 3) + '...';

  LPopupWindow := FEditor.CompletionProposalPopupWindow;

  if not Assigned(LPopupWindow) or (LItemsIndex >= LPopupWindow.Items.Count) then
    Exit;

  LProposalItem := LPopupWindow.Items[LItemsIndex];
  LProposalItem.Description := LDescription;
  LPopupWindow.Items[LItemsIndex] := LProposalItem;
  LPopupWindow.Invalidate;
end;

procedure TTextEditorLanguageServer.CompletionTriggerTimerTimer(ASender: TObject);
begin
  FCompletionTriggerTimer.Enabled := False;

  if Initialized and FDocumentOpen and Assigned(FEditor) then
    FEditor.ShowCompletionProposal(True);
end;

procedure TTextEditorLanguageServer.EditorCompletionProposalExecute(const ASender: TObject; var AParams: TCompletionProposalParams);
begin
  if Assigned(FPreviousOnCompletionProposalExecute) then
    FPreviousOnCompletionProposalExecute(ASender, AParams);

  if Completion(AParams.Items) then
  begin
    AParams.Options.ParseItemsFromText := False;
    AParams.Options.AddHighlighterKeywords := False;
    AParams.Options.AddSnippets := False;
    AParams.Options.ShowDescription := True;
    AParams.Options.SortByKeyword := False; { the server's sortText ranking is already applied }

    if FClient.IsRequestSupported(lspCompletionItemResolve) and Assigned(FEditor) and
      Assigned(FEditor.CompletionProposalPopupWindow) then
    begin
      FEditor.CompletionProposalPopupWindow.OnSelectedItemChange := CompletionSelectedItemChange;
      CompletionSelectedItemChange(FEditor.CompletionProposalPopupWindow);
    end;
  end
  else
  if Initialized and FDocumentOpen then
  begin
    AParams.Options.ParseItemsFromText := False;
    AParams.Options.AddHighlighterKeywords := False;
    AParams.Options.AddSnippets := False;
  end;
end;

procedure TTextEditorLanguageServer.HideSignatureHelp;
begin
  FSignatureHelpTimer.Enabled := False;
  FSignatureHelpActive := False;

  if Assigned(FSignatureHelpPopup) then
    FSignatureHelpPopup.Hide;
end;

procedure TTextEditorLanguageServer.SignatureHelpTimerTimer(ASender: TObject);
begin
  FSignatureHelpTimer.Enabled := False;

  UpdateSignatureHelp;
end;

procedure TTextEditorLanguageServer.HoverTimerTimer(ASender: TObject);
begin
  FHoverTimer.Enabled := False;

  ShowHoverPopup;
end;

procedure TTextEditorLanguageServer.HoverCloseTimerTimer(ASender: TObject);
begin
  if not Assigned(FHoverPopup) or not FHoverPopup.Visible then
  begin
    FHoverCloseTimer.Enabled := False;
    Exit;
  end;

  if not PtInRect(HoverKeepZone, Mouse.CursorPos) then
    HideHover;
end;

procedure TTextEditorLanguageServer.HoverLinkClick(ASender: TObject);
var
  LLocation: TTextEditorLanguageServerLocation;
begin
  HideHover;

  if not FHoverLocationValid then
    Exit;

  LLocation := FHoverLocation;

  if SameText(LLocation.FileName, FFileName) and Assigned(FEditor) then
    FEditor.TextPosition := LLocation.TextPosition;

  if Assigned(FOnGotoLocation) then
    FOnGotoLocation(Self, LLocation);
end;

procedure TTextEditorLanguageServer.ShowHoverPopup;
var
  LDiagnostic: TTextEditorLanguageServerDiagnostic;
  LParts: TArray<TTextEditorLanguageServerHoverPart>;
  LPart: TTextEditorLanguageServerHoverPart;
  LTextPosition: TTextEditorTextPosition;
  LAnchorRect: TRect;
  LTopLeft, LBottomRight: TPoint;
begin
  if not Assigned(FEditor) or FHoverWord.IsEmpty then
    Exit;

  if not FEditor.GetTextPositionOfMouse(LTextPosition) or (LTextPosition.Line <> FHoverPosition.Line) or
    (FEditor.WordAtTextPosition(LTextPosition) <> FHoverWord) then
    Exit;

  FHoverLocationValid := False;

  if DiagnosticAt(FHoverPosition, LDiagnostic) then
    LParts := ParseHoverParts(LDiagnostic.Message, False)
  else
  begin
    LParts := HoverParts(FHoverPosition);
    FHoverLocationValid := FindDefinition(FHoverPosition, FHoverLocation);
  end;

  if (Length(LParts) = 0) and not FHoverLocationValid then
    Exit;

  if not Assigned(FHoverPopup) then
  begin
    FHoverPopup := TTextEditorHoverPopupWindow.Create(FEditor);
    FHoverPopup.FreeNotification(Self);
    FHoverPopup.OnLinkClick := HoverLinkClick;
  end;

  FHoverPopup.Clear;

  for LPart in LParts do
  if LPart.Code then
    FHoverPopup.AddLine(hlCode, LPart.Text)
  else
    FHoverPopup.AddLine(hlText, LPart.Text);

  if FHoverLocationValid then
    FHoverPopup.LinkText := Format('%s (%d)', [ExtractFileName(FHoverLocation.FileName), FHoverLocation.TextPosition.Line + 1]);

  LTopLeft := FEditor.ViewPositionToPixels(FEditor.TextToViewPosition(FEditor.WordStart(FHoverPosition)));
  LBottomRight := FEditor.ViewPositionToPixels(FEditor.TextToViewPosition(FEditor.WordEnd(FHoverPosition)));

  LAnchorRect.TopLeft := FEditor.ClientToScreen(LTopLeft);
  LAnchorRect.BottomRight := FEditor.ClientToScreen(Point(LBottomRight.X, LBottomRight.Y + FEditor.LineHeight));

  FHoverKeepRect := LAnchorRect;

  FHoverPopup.Execute(LAnchorRect);
  FHoverCloseTimer.Enabled := FHoverPopup.Visible;
end;

function TTextEditorLanguageServer.SignatureHelp(const ATextPosition: TTextEditorTextPosition; out AHelp: TTextEditorLanguageServerSignatureHelp): Boolean;
var
  LParams: TLSPSignatureHelpParams;
  LHelpResult: TLSPSignatureHelpResult;
  LIndex, LParameterIndex: Integer;
begin
  Result := False;
  AHelp := Default(TTextEditorLanguageServerSignatureHelp);

  if not FDocumentOpen or not Initialized or not FClient.IsRequestSupported(lspSignatureHelp) then
    Exit;

  SyncDocument;

  LHelpResult := nil;

  LParams := TLSPSignatureHelpParams.Create;
  try
    LParams.textDocument.uri := DocumentUri;
    LParams.position := PositionToLSP(ATextPosition);
    LParams.context.triggerKind := 1;
    LParams.context.isRetrigger := FSignatureHelpActive;

    if not FClient.SendSyncRequest(lspSignatureHelp, LParams,
      procedure(AJson: TJSONObject)
      begin
        if Assigned(AJson.Values['result']) and not AJson.Values['result'].Null then
          LHelpResult := JsonSignatureHelpResultToObject(AJson.Values['result']);
      end, FSyncTimeout) then
      Exit;
  finally
    LParams.Free;
  end;

  if not Assigned(LHelpResult) then
    Exit;

  try
    SetLength(AHelp.Signatures, Length(LHelpResult.signatures));

    for LIndex := 0 to High(LHelpResult.signatures) do
    begin
      AHelp.Signatures[LIndex].Text := LHelpResult.signatures[LIndex].&label;

      SetLength(AHelp.Signatures[LIndex].Parameters, Length(LHelpResult.signatures[LIndex].parameters));

      for LParameterIndex := 0 to High(LHelpResult.signatures[LIndex].parameters) do
        AHelp.Signatures[LIndex].Parameters[LParameterIndex] := LHelpResult.signatures[LIndex].parameters[LParameterIndex].&label;
    end;

    if Length(AHelp.Signatures) > 0 then
      AHelp.ActiveSignature := EnsureRange(Integer(LHelpResult.activeSignature), 0, High(AHelp.Signatures));

    AHelp.ActiveParameter := Integer(LHelpResult.activeParameter);

    Result := Length(AHelp.Signatures) > 0;
  finally
    LHelpResult.Free;
  end;
end;

procedure TTextEditorLanguageServer.UpdateSignatureHelp;
var
  LHelp: TTextEditorLanguageServerSignatureHelp;
  LSignature: TTextEditorLanguageServerSignature;
  LIndex, LSearchIndex, LFoundIndex: Integer;
  LHighlightBegin, LHighlightLength: Integer;
  LPoint: TPoint;
  LAnchorRect: TRect;
begin
  if not FSignatureHelpEnabled or not Assigned(FEditor) or not SignatureHelp(FEditor.TextPosition, LHelp) then
  begin
    HideSignatureHelp;
    Exit;
  end;

  if not Assigned(FSignatureHelpPopup) then
  begin
    FSignatureHelpPopup := TTextEditorHoverPopupWindow.Create(FEditor);
    FSignatureHelpPopup.FreeNotification(Self);
  end;

  FSignatureHelpPopup.Clear;

  for LSignature in LHelp.Signatures do
  begin
    LHighlightBegin := 0;
    LHighlightLength := 0;

    if (LHelp.ActiveParameter >= 0) and (LHelp.ActiveParameter < Length(LSignature.Parameters)) then
    begin
      LSearchIndex := 0;

      for LIndex := 0 to LHelp.ActiveParameter do
      begin
        LFoundIndex := LSignature.Text.IndexOf(LSignature.Parameters[LIndex], LSearchIndex);

        if LFoundIndex < 0 then
          Break;

        if LIndex = LHelp.ActiveParameter then
        begin
          LHighlightBegin := LFoundIndex + 1;
          LHighlightLength := LSignature.Parameters[LIndex].Length;
        end
        else
          LSearchIndex := LFoundIndex + LSignature.Parameters[LIndex].Length;
      end;
    end;

    FSignatureHelpPopup.AddLine(hlCode, LSignature.Text, LHighlightBegin, LHighlightLength);
  end;

  LPoint := FEditor.ClientToScreen(FEditor.ViewPositionToPixels(FEditor.ViewPosition));

  LAnchorRect.TopLeft := LPoint;
  LAnchorRect.BottomRight := Point(LPoint.X, LPoint.Y + FEditor.LineHeight);

  FSignatureHelpPopup.Execute(LAnchorRect, True);
  FSignatureHelpActive := FSignatureHelpPopup.Visible;
end;

end.
