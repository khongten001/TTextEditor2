unit TextEditor.LanguageServer;

{ Language Server Protocol client for TTextEditor built on the LSP-Pascal-Library (https://github.com/rickard67/LSP-Pascal-Library). }

interface

uses
  System.Classes, System.Generics.Collections, System.JSON, System.SysUtils, System.UITypes, Vcl.ExtCtrls, TextEditor, TextEditor.Marks,
  TextEditor.Types, XLSPClient, XLSPTypes;

type
  TTextEditorLanguageServerDiagnostic = record
    BeginPosition: TTextEditorTextPosition;
    EndPosition: TTextEditorTextPosition;
    &Message: string;
    Severity: Integer;
    Source: string;
  end;

  TTextEditorLanguageServerLocation = record
    FileName: string;
    TextPosition: TTextEditorTextPosition;
  end;

  TTextEditorLanguageServerDiagnosticsEvent = procedure(const ASender: TObject;
    const ADiagnostics: TArray<TTextEditorLanguageServerDiagnostic>) of object;
  TTextEditorLanguageServerLocationEvent = procedure(const ASender: TObject;
    const ALocation: TTextEditorLanguageServerLocation) of object;
  TTextEditorLanguageServerLogEvent = procedure(const ASender: TObject; const AMessage: string) of object;

  TTextEditorLanguageServer = class(TComponent)
  strict private
    FChangeTimer: TTimer;
    FClient: TLSPClient;
    FConfiguration: string;
    FDiagnostics: TArray<TTextEditorLanguageServerDiagnostic>;
    FDiagnosticMarkImageIndex: Integer;
    FDocumentOpen: Boolean;
    FDocumentVersion: Integer;
    FEditor: TCustomTextEditor;
    FFileName: string;
    FInitializationOptions: string;
    FLanguageId: string;
    FLogTraffic: Boolean;
    FOnDiagnostics: TTextEditorLanguageServerDiagnosticsEvent;
    FOnGotoLocation: TTextEditorLanguageServerLocationEvent;
    FOnLog: TTextEditorLanguageServerLogEvent;
    FPreviousOnChange: TNotifyEvent;
    FPreviousOnCustomTokenAttribute: TTextEditorCustomTokenAttributeEvent;
    FRootPath: string;
    FServerCommandLine: string;
    FServerDirectory: string;
    FServerRunning: Boolean;
    FSyncTimeout: Integer;
    function DocumentUri: string;
    function GetActive: Boolean;
    function GetInitialized: Boolean;
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
    procedure EditorChange(ASender: TObject);
    procedure EditorCustomTokenAttribute(const ASender: TObject; const AText: string; const ALine: Integer; const AChar: Integer;
      var AForegroundColor: TColor; var ABackgroundColor: TColor; var AStyles: TFontStyles; var AUnderline: TTextEditorUnderline;
      var AUnderlineColor: TColor);
    procedure HookEditor;
    procedure Log(const AMessage: string);
    procedure SendDidChange;
    procedure SetEditor(const AValue: TCustomTextEditor);
    procedure UnhookEditor;
  protected
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    class function FileNameToUri(const AFileName: string): string;
    function Completion(const AItems: TTextEditorCompletionProposalItems): Boolean;
    function DiagnosticAt(const ATextPosition: TTextEditorTextPosition; out ADiagnostic: TTextEditorLanguageServerDiagnostic): Boolean;
    function Hover(const ATextPosition: TTextEditorTextPosition): string;
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
    property Configuration: string read FConfiguration write FConfiguration;
    property DiagnosticMarkImageIndex: Integer read FDiagnosticMarkImageIndex write FDiagnosticMarkImageIndex default -1;
    property Editor: TCustomTextEditor read FEditor write SetEditor;
    property InitializationOptions: string read FInitializationOptions write FInitializationOptions;
    property LogTraffic: Boolean read FLogTraffic write FLogTraffic default False;
    property OnDiagnostics: TTextEditorLanguageServerDiagnosticsEvent read FOnDiagnostics write FOnDiagnostics;
    property OnGotoLocation: TTextEditorLanguageServerLocationEvent read FOnGotoLocation write FOnGotoLocation;
    property OnLog: TTextEditorLanguageServerLogEvent read FOnLog write FOnLog;
    property RootPath: string read FRootPath write FRootPath;
    property ServerCommandLine: string read FServerCommandLine write FServerCommandLine;
    property ServerDirectory: string read FServerDirectory write FServerDirectory;
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
  System.Math, XLSPFunctions;

const
  CHANGE_DEBOUNCE_MS = 300;

constructor TTextEditorLanguageServer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FDiagnosticMarkImageIndex := -1;
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
end;

{ The owner's child controls are already gone when owned components are destroyed, so event handlers must not run anymore. }
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

  if (AOperation = opRemove) and (AComponent = FEditor) then
  begin
    UnhookEditor;
    FEditor := nil;
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

procedure TTextEditorLanguageServer.HookEditor;
begin
  if not Assigned(FEditor) then
    Exit;

  FEditor.FreeNotification(Self);

  FPreviousOnChange := FEditor.OnChange;
  FEditor.OnChange := EditorChange;

  FPreviousOnCustomTokenAttribute := FEditor.OnCustomTokenAttribute;
  FEditor.OnCustomTokenAttribute := EditorCustomTokenAttribute;
end;

procedure TTextEditorLanguageServer.UnhookEditor;
begin
  if not Assigned(FEditor) then
    Exit;

  FEditor.OnChange := FPreviousOnChange;
  FEditor.OnCustomTokenAttribute := FPreviousOnCustomTokenAttribute;
  FPreviousOnChange := nil;
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

  FServerRunning := False;
  FChangeTimer.Enabled := False;

  if FDocumentOpen then
    CloseDocument;

  Log('Stopping server');

  FClient.CloseServer;
end;

{ CreateProcess gets the command line verbatim, so an executable path containing spaces must be quoted. The executable is
  found by testing successively longer space-delimited prefixes against the file system. }
function TTextEditorLanguageServer.QuotedCommandLine(const ACommandLine: string): string;
var
  LIndex: Integer;
  LCandidate: string;
begin
  Result := ACommandLine.Trim;

  if Result.IsEmpty or Result.StartsWith('"') or (Result.IndexOf(' ') < 0) then
    Exit;

  LIndex := 0;

  while LIndex >= 0 do
  begin
    LIndex := Result.IndexOf(' ', LIndex + 1);

    LCandidate := if LIndex < 0 then Result else Result.Substring(0, LIndex);

    if FileExists(LCandidate) then
      Exit('"' + LCandidate + '"' + Result.Substring(LCandidate.Length));
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
  AValue.capabilities.AddHoverSupport(False, True, True);
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

(* ASettingsJson is the complete params object of workspace/didChangeConfiguration, i.e. {"settings": {...}}. DelphiLSP's
   exported .delphilsp.json file has exactly that shape and can be sent verbatim. *)
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

{ The client reports every raw server message through OnLogMessage as lspMsgLog, next to real window/logMessage
  notifications; the raw JSON is only useful when debugging a server. }
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
  FChangeTimer.Enabled := False;

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

procedure TTextEditorLanguageServer.EditorChange(ASender: TObject);
begin
  if Assigned(FPreviousOnChange) then
    FPreviousOnChange(ASender);

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
    FDiagnostics[LIndex].Message := ADiagnostics[LIndex].&message;
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

function TTextEditorLanguageServer.Completion(const AItems: TTextEditorCompletionProposalItems): Boolean;
var
  LParams: TLSPCompletionParams;
  LList: TLSPCompletionList;
begin
  Result := False;

  if not FDocumentOpen or not Initialized or not FClient.IsRequestSupported(lspCompletion) then
    Exit;

  if FChangeTimer.Enabled then
  begin
    FChangeTimer.Enabled := False;
    SendDidChange;
  end;

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
    for var LItem in LList.items do
    begin
      var LProposalItem: TTextEditorCompletionProposalItem;
      LProposalItem.Keyword := if LItem.insertText.IsEmpty then LItem.&label else LItem.insertText;
      LProposalItem.Description := LItem.detail;
      LProposalItem.SnippetIndex := -1;

      AItems.Add(LProposalItem);
    end;

    Result := Length(LList.items) > 0;
  finally
    LList.Free;
  end;
end;

function TTextEditorLanguageServer.Hover(const ATextPosition: TTextEditorTextPosition): string;
var
  LParams: TLSPHoverParams;
  LHover: TLSPHoverResult;
  LText: string;
begin
  Result := '';

  if not FDocumentOpen or not Initialized or not FClient.IsRequestSupported(lspHover) then
    Exit;

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
    LText := LHover.contents.value;

    if LText.IsEmpty then
      LText := LHover.contentsMarked.value;

    if LText.IsEmpty then
      for var LMarked in LHover.contentsMarkedArray do
        LText := LText + LMarked.value + sLineBreak;

    Result := LText.Replace('```', '').Trim;
  finally
    LHover.Free;
  end;
end;

procedure TTextEditorLanguageServer.GotoDefinition;
var
  LParams: TLSPTextDocumentPositionParams;
begin
  if not FDocumentOpen or not Initialized or not FClient.IsRequestSupported(lspGotoDefinition) then
    Exit;

  LParams := TLSPTextDocumentPositionParams.Create;
  try
    LParams.textDocument.uri := DocumentUri;
    LParams.position := PositionToLSP(FEditor.TextPosition);

    FClient.SendRequest(lspGotoDefinition, LParams,
      procedure(AJson: TJSONObject)
      var
        LResult: TLSPGotoResult;
        LLocation: TTextEditorLanguageServerLocation;
        LUri: string;
        LRange: TLSPRange;
      begin
        if not Assigned(AJson.Values['result']) or AJson.Values['result'].Null then
          Exit;

        LResult := JsonGotoResultToObject(AJson.Values['result']);
        try
          if Length(LResult.locations) > 0 then
          begin
            LUri := LResult.locations[0].uri;
            LRange := LResult.locations[0].range;
          end
          else
          if Length(LResult.locationLinks) > 0 then
          begin
            LUri := LResult.locationLinks[0].targetUri;
            LRange := LResult.locationLinks[0].targetSelectionRange;
          end
          else
          begin
            LUri := LResult.location.uri;
            LRange := LResult.location.range;
          end;

          if LUri.IsEmpty then
            Exit;

          LLocation.FileName := UriToFilePath(LUri);
          LLocation.TextPosition := PositionToEditor(LRange.start);

          if SameText(LLocation.FileName, FFileName) and Assigned(FEditor) then
            FEditor.TextPosition := LLocation.TextPosition;

          if Assigned(FOnGotoLocation) then
            FOnGotoLocation(Self, LLocation);
        finally
          LResult.Free;
        end;
      end);
  finally
    LParams.Free;
  end;
end;

end.
