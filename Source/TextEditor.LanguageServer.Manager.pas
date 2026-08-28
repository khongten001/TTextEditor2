unit TextEditor.LanguageServer.Manager;

interface

uses
  System.Classes, System.Generics.Collections, System.SysUtils, TextEditor, TextEditor.LanguageServer;

type
  TTextEditorLanguageServerRootPathKind = (rpDocumentFolder, rpFixedFolder, rpMarkerFile);
  TTextEditorLanguageServerSettingsFallback = (sfNone, sfDelphiLsp);

  TTextEditorLanguageServerDefinition = class(TCollectionItem)
  strict private
    FCommandLine: string;
    FConfiguration: string;
    FEnabled: Boolean;
    FExtensions: string;
    FInitializationOptions: string;
    FLanguageId: string;
    FName: string;
    FRootPath: string;
    FRootPathKind: TTextEditorLanguageServerRootPathKind;
    FSettingsFallback: TTextEditorLanguageServerSettingsFallback;
  protected
    function GetDisplayName: string; override;
  public
    constructor Create(ACollection: TCollection); override;
    function MatchesFileName(const AFileName: string): Boolean;
    procedure Assign(ASource: TPersistent); override;
  published
    property CommandLine: string read FCommandLine write FCommandLine;
    property Configuration: string read FConfiguration write FConfiguration;
    property Enabled: Boolean read FEnabled write FEnabled default True;
    property Extensions: string read FExtensions write FExtensions;
    property InitializationOptions: string read FInitializationOptions write FInitializationOptions;
    property LanguageId: string read FLanguageId write FLanguageId;
    property Name: string read FName write FName;
    property RootPath: string read FRootPath write FRootPath;
    property RootPathKind: TTextEditorLanguageServerRootPathKind read FRootPathKind write FRootPathKind default rpDocumentFolder;
    property SettingsFallback: TTextEditorLanguageServerSettingsFallback read FSettingsFallback write FSettingsFallback default sfNone;
  end;

  TTextEditorLanguageServerDefinitions = class(TOwnedCollection)
  strict private
    function GetItem(const AIndex: Integer): TTextEditorLanguageServerDefinition;
    procedure SetItem(const AIndex: Integer; const AValue: TTextEditorLanguageServerDefinition);
  public
    function Add: TTextEditorLanguageServerDefinition;
    function FindByName(const AName: string): TTextEditorLanguageServerDefinition;
    property Items[const AIndex: Integer]: TTextEditorLanguageServerDefinition read GetItem write SetItem; default;
  end;

  TTextEditorLanguageServers = class(TComponent)
  strict private type
    TAttachment = record
      Instance: TTextEditorLanguageServer;
      DefinitionId: Integer;
      DefinitionName: string;
    end;
  strict private
    FAttachments: TDictionary<TCustomTextEditor, TAttachment>;
    FCompletionTriggerEnabled: Boolean;
    FHoverDelay: Integer;
    FHoverEnabled: Boolean;
    FLogTraffic: Boolean;
    FOnGotoLocation: TTextEditorLanguageServerLocationEvent;
    FOnLog: TTextEditorLanguageServerLogEvent;
    FServers: TTextEditorLanguageServerDefinitions;
    FSignatureHelpEnabled: Boolean;
    FSyncTimeout: Integer;
    function BuildConfiguration(const ADefinition: TTextEditorLanguageServerDefinition; const AMarkerFileName: string): string;
    function CreateDelphiLspFallbackSettings(const ADefinition: TTextEditorLanguageServerDefinition; const AFileName: string): string;
    function ResolveConfiguration(const ADefinition: TTextEditorLanguageServerDefinition; const AFileName: string; out ARootPath: string): string;
    function ResolveRootPath(const ADefinition: TTextEditorLanguageServerDefinition; const AFileName: string; out AMarkerFileName: string): string;
    procedure InstanceGotoLocation(const ASender: TObject; const ALocation: TTextEditorLanguageServerLocation);
    procedure InstanceLog(const ASender: TObject; const AMessage: string);
    procedure SetServers(const AValue: TTextEditorLanguageServerDefinitions);
  protected
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function Attach(const AEditor: TCustomTextEditor; const AFileName: string): TTextEditorLanguageServer;
    function DefinitionForFileName(const AFileName: string): TTextEditorLanguageServerDefinition;
    function InstanceForEditor(const AEditor: TCustomTextEditor): TTextEditorLanguageServer;
    procedure Detach(const AEditor: TCustomTextEditor);
    procedure DetectInstalledServers;
    procedure StopAll;
  published
    property CompletionTriggerEnabled: Boolean read FCompletionTriggerEnabled write FCompletionTriggerEnabled default True;
    property HoverDelay: Integer read FHoverDelay write FHoverDelay default 600;
    property HoverEnabled: Boolean read FHoverEnabled write FHoverEnabled default True;
    property LogTraffic: Boolean read FLogTraffic write FLogTraffic default False;
    property OnGotoLocation: TTextEditorLanguageServerLocationEvent read FOnGotoLocation write FOnGotoLocation;
    property OnLog: TTextEditorLanguageServerLogEvent read FOnLog write FOnLog;
    property Servers: TTextEditorLanguageServerDefinitions read FServers write SetServers;
    property SignatureHelpEnabled: Boolean read FSignatureHelpEnabled write FSignatureHelpEnabled default True;
    property SyncTimeout: Integer read FSyncTimeout write FSyncTimeout default 1000;
  end;

implementation

uses
  System.Hash, System.IOUtils;

{ TTextEditorLanguageServerDefinition }

constructor TTextEditorLanguageServerDefinition.Create(ACollection: TCollection);
begin
  inherited Create(ACollection);

  FEnabled := True;
  FRootPathKind := rpDocumentFolder;
end;

function TTextEditorLanguageServerDefinition.GetDisplayName: string;
begin
  Result := if FName.IsEmpty then inherited GetDisplayName else FName;
end;

function TTextEditorLanguageServerDefinition.MatchesFileName(const AFileName: string): Boolean;
var
  LExtension, LCandidate: string;
begin
  LExtension := ExtractFileExt(AFileName).ToLower;

  if LExtension.IsEmpty then
    Exit(False);

  for LCandidate in FExtensions.ToLower.Split([';']) do
  if LCandidate.Trim = LExtension then
    Exit(True);

  Result := False;
end;

procedure TTextEditorLanguageServerDefinition.Assign(ASource: TPersistent);
begin
  if ASource is TTextEditorLanguageServerDefinition then
  with ASource as TTextEditorLanguageServerDefinition do
  begin
    Self.FCommandLine := CommandLine;
    Self.FConfiguration := Configuration;
    Self.FEnabled := Enabled;
    Self.FExtensions := Extensions;
    Self.FInitializationOptions := InitializationOptions;
    Self.FLanguageId := LanguageId;
    Self.FName := Name;
    Self.FRootPath := RootPath;
    Self.FRootPathKind := RootPathKind;
    Self.FSettingsFallback := SettingsFallback;
  end
  else
    inherited Assign(ASource);
end;

{ TTextEditorLanguageServerDefinitions }

function TTextEditorLanguageServerDefinitions.GetItem(const AIndex: Integer): TTextEditorLanguageServerDefinition;
begin
  Result := inherited GetItem(AIndex) as TTextEditorLanguageServerDefinition;
end;

procedure TTextEditorLanguageServerDefinitions.SetItem(const AIndex: Integer; const AValue: TTextEditorLanguageServerDefinition);
begin
  inherited SetItem(AIndex, AValue);
end;

function TTextEditorLanguageServerDefinitions.Add: TTextEditorLanguageServerDefinition;
begin
  Result := inherited Add as TTextEditorLanguageServerDefinition;
end;

function TTextEditorLanguageServerDefinitions.FindByName(const AName: string): TTextEditorLanguageServerDefinition;
begin
  for var LIndex := 0 to Count - 1 do
  if SameText(Items[LIndex].Name, AName) then
    Exit(Items[LIndex]);

  Result := nil;
end;

{ TTextEditorLanguageServers }

constructor TTextEditorLanguageServers.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FServers := TTextEditorLanguageServerDefinitions.Create(Self, TTextEditorLanguageServerDefinition);
  FAttachments := TDictionary<TCustomTextEditor, TAttachment>.Create;

  FCompletionTriggerEnabled := True;
  FHoverDelay := 600;
  FHoverEnabled := True;
  FSignatureHelpEnabled := True;
  FSyncTimeout := 1000;
end;

destructor TTextEditorLanguageServers.Destroy;
begin
  StopAll;

  FAttachments.Free;
  FServers.Free;

  inherited Destroy;
end;

procedure TTextEditorLanguageServers.SetServers(const AValue: TTextEditorLanguageServerDefinitions);
begin
  FServers.Assign(AValue);
end;

function TTextEditorLanguageServers.DefinitionForFileName(const AFileName: string): TTextEditorLanguageServerDefinition;
begin
  for var LIndex := 0 to FServers.Count - 1 do
  if FServers[LIndex].Enabled and FServers[LIndex].MatchesFileName(AFileName) then
    Exit(FServers[LIndex]);

  Result := nil;
end;

function TTextEditorLanguageServers.InstanceForEditor(const AEditor: TCustomTextEditor): TTextEditorLanguageServer;
var
  LAttachment: TAttachment;
begin
  Result := if FAttachments.TryGetValue(AEditor, LAttachment) then LAttachment.Instance else nil;
end;

function TTextEditorLanguageServers.ResolveRootPath(const ADefinition: TTextEditorLanguageServerDefinition;
  const AFileName: string; out AMarkerFileName: string): string;
var
  LDirectory, LParentDirectory: string;
  LFiles: TArray<string>;
begin
  AMarkerFileName := '';
  Result := ExtractFileDir(AFileName);

  case ADefinition.RootPathKind of
    rpFixedFolder:
      if not ADefinition.RootPath.IsEmpty then
        Result := ADefinition.RootPath;
    rpMarkerFile:
      begin
        LDirectory := ExtractFileDir(AFileName);

        while not LDirectory.IsEmpty do
        begin
          LFiles := TDirectory.GetFiles(LDirectory, ADefinition.RootPath);

          if Length(LFiles) > 0 then
          begin
            AMarkerFileName := LFiles[0];
            Exit(LDirectory);
          end;

          LParentDirectory := ExtractFileDir(LDirectory);

          if LParentDirectory = LDirectory then
            Break;

          LDirectory := LParentDirectory;
        end;
      end;
  end;
end;

function TTextEditorLanguageServers.BuildConfiguration(const ADefinition: TTextEditorLanguageServerDefinition;
  const AMarkerFileName: string): string;
begin
  Result := ADefinition.Configuration;

  if Result.Contains('%MARKERFILEURI%') then
  begin
    if AMarkerFileName.IsEmpty then
      Exit('');

    Result := Result.Replace('%MARKERFILEURI%', TTextEditorLanguageServer.FileNameToUri(AMarkerFileName));
  end;
end;

function TTextEditorLanguageServers.CreateDelphiLspFallbackSettings(const ADefinition: TTextEditorLanguageServerDefinition;
  const AFileName: string): string;

  function EscapedPath(const APath: string): string;
  begin
    Result := APath.Replace('\', '\\');
  end;

  function ServerFileName: string;
  var
    LCommandLine: string;
    LIndex: Integer;
  begin
    LCommandLine := ADefinition.CommandLine.Trim;

    if LCommandLine.StartsWith('"') then
    begin
      LIndex := LCommandLine.IndexOf('"', 1);
      Result := if LIndex > 1 then LCommandLine.Substring(1, LIndex - 1) else ''
    end
    else
      Result := LCommandLine.Split([' '])[0];
  end;

var
  LBinDirectory, LLibDirectory, LDirectory, LDocumentDirectory: string;
  LCompilerFileNames: TArray<string>;
  LProjectFileName, LSettingsFileName: string;
begin
  Result := '';

  LBinDirectory := ExtractFileDir(ServerFileName);
  LLibDirectory := ExtractFileDir(LBinDirectory) + '\lib\Win32\release';

  if not TDirectory.Exists(LLibDirectory) then
    Exit;

  LCompilerFileNames := TDirectory.GetFiles(LBinDirectory, 'dcc32*.dll');

  if Length(LCompilerFileNames) = 0 then
    Exit;

  LDocumentDirectory := ExtractFileDir(AFileName);
  LDirectory := TPath.Combine(TPath.GetTempPath, 'TTextEditor');
  LProjectFileName := TPath.Combine(LDirectory, 'Fallback.dproj');
  LSettingsFileName := TPath.Combine(LDirectory, 'Fallback.' +
    IntToHex(THashFNV1a32.GetHashValue(LDocumentDirectory.ToLower), 8) + '.delphilsp.json');

  try
    TDirectory.CreateDirectory(LDirectory);
    TFile.WriteAllText(LProjectFileName, '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003"/>',
      TEncoding.UTF8);
    TFile.WriteAllText(LSettingsFileName,
      '{"settings":{"project":"' + TTextEditorLanguageServer.FileNameToUri(LProjectFileName) +
      '","dllname":"' + ExtractFileName(LCompilerFileNames[High(LCompilerFileNames)]) +
      '","dccOptions":"-U\"' + EscapedPath(LDocumentDirectory) + '\";\"' + EscapedPath(LLibDirectory) + '\" ' +
      '-NSSystem;Xml;Data;Datasnap;Web;Soap;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell;Winapi;System.Win"}}',
      TEncoding.UTF8);
  except
    Exit('');
  end;

  Result := LSettingsFileName;
end;

function TTextEditorLanguageServers.ResolveConfiguration(const ADefinition: TTextEditorLanguageServerDefinition;
  const AFileName: string; out ARootPath: string): string;
var
  LMarkerFileName: string;
begin
  ARootPath := ResolveRootPath(ADefinition, AFileName, LMarkerFileName);

  if LMarkerFileName.IsEmpty and (ADefinition.SettingsFallback = sfDelphiLsp) and
    ADefinition.Configuration.Contains('%MARKERFILEURI%') then
  begin
    LMarkerFileName := CreateDelphiLspFallbackSettings(ADefinition, AFileName);

    if Assigned(FOnLog) then
      if LMarkerFileName.IsEmpty then
        FOnLog(Self, '[' + ADefinition.Name + '] No ' + ADefinition.RootPath +
          ' found for this file and no default settings could be generated - completions will be keywords only.')
      else
        FOnLog(Self, '[' + ADefinition.Name + '] No ' + ADefinition.RootPath +
          ' found for this file - using generated default settings (the file''s folder and the Studio library).');
  end;

  Result := BuildConfiguration(ADefinition, LMarkerFileName);
end;

function TTextEditorLanguageServers.Attach(const AEditor: TCustomTextEditor; const AFileName: string): TTextEditorLanguageServer;
var
  LDefinition: TTextEditorLanguageServerDefinition;
  LAttachment: TAttachment;
  LConfiguration, LRootPath: string;
begin
  LDefinition := DefinitionForFileName(AFileName);

  if not Assigned(LDefinition) then
  begin
    Detach(AEditor);
    Exit(nil);
  end;

  if FAttachments.TryGetValue(AEditor, LAttachment) and (LAttachment.DefinitionId = LDefinition.ID) then
  begin
    LConfiguration := ResolveConfiguration(LDefinition, AFileName, LRootPath);

    if LConfiguration <> LAttachment.Instance.Configuration then
    begin
      LAttachment.Instance.Configuration := LConfiguration;
      LAttachment.Instance.SendConfiguration(LConfiguration);
    end;

    LAttachment.Instance.OpenDocument(AFileName, LDefinition.LanguageId);
    Exit(LAttachment.Instance);
  end;

  Detach(AEditor);

  LConfiguration := ResolveConfiguration(LDefinition, AFileName, LRootPath);

  Result := TTextEditorLanguageServer.Create(Self);
  Result.Editor := AEditor;
  Result.ServerCommandLine := LDefinition.CommandLine;
  Result.RootPath := LRootPath;
  Result.ServerDirectory := LRootPath;
  Result.InitializationOptions := LDefinition.InitializationOptions;
  Result.Configuration := LConfiguration;
  Result.CompletionTriggerEnabled := FCompletionTriggerEnabled;
  Result.HoverDelay := FHoverDelay;
  Result.HoverEnabled := FHoverEnabled;
  Result.LogTraffic := FLogTraffic;
  Result.SignatureHelpEnabled := FSignatureHelpEnabled;
  Result.SyncTimeout := FSyncTimeout;
  Result.OnGotoLocation := InstanceGotoLocation;
  Result.OnLog := InstanceLog;

  LAttachment.Instance := Result;
  LAttachment.DefinitionId := LDefinition.ID;
  LAttachment.DefinitionName := LDefinition.Name;
  FAttachments.Add(AEditor, LAttachment);

  AEditor.FreeNotification(Self);

  Result.OpenDocument(AFileName, LDefinition.LanguageId);
  Result.Start;
end;

procedure TTextEditorLanguageServers.Detach(const AEditor: TCustomTextEditor);
var
  LAttachment: TAttachment;
begin
  if not FAttachments.TryGetValue(AEditor, LAttachment) then
    Exit;

  FAttachments.Remove(AEditor);
  LAttachment.Instance.Free;
end;

procedure TTextEditorLanguageServers.StopAll;
var
  LAttachment: TAttachment;
begin
  for LAttachment in FAttachments.Values do
    LAttachment.Instance.Free;

  FAttachments.Clear;
end;

procedure TTextEditorLanguageServers.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited Notification(AComponent, AOperation);

  if (AOperation = opRemove) and (AComponent is TCustomTextEditor) then
    Detach(TCustomTextEditor(AComponent));
end;

procedure TTextEditorLanguageServers.InstanceLog(const ASender: TObject; const AMessage: string);
var
  LAttachment: TAttachment;
begin
  if not Assigned(FOnLog) then
    Exit;

  for LAttachment in FAttachments.Values do
  if LAttachment.Instance = ASender then
  begin
    FOnLog(ASender, '[' + LAttachment.DefinitionName + '] ' + AMessage);
    Exit;
  end;

  FOnLog(ASender, AMessage);
end;

procedure TTextEditorLanguageServers.InstanceGotoLocation(const ASender: TObject;
  const ALocation: TTextEditorLanguageServerLocation);
begin
  if Assigned(FOnGotoLocation) then
    FOnGotoLocation(ASender, ALocation);
end;

procedure TTextEditorLanguageServers.DetectInstalledServers;

  function ProgramFilesDirectory: string;
  begin
    Result := GetEnvironmentVariable('ProgramW6432');

    if Result.IsEmpty then
      Result := GetEnvironmentVariable('ProgramFiles');
  end;

  function AddDefinition(const AName, ACommandLine, AExtensions, ALanguageId: string): TTextEditorLanguageServerDefinition;
  begin
    Result := FServers.FindByName(AName);

    if not Assigned(Result) then
    begin
      Result := FServers.Add;
      Result.Name := AName;
    end;

    Result.CommandLine := ACommandLine;
    Result.Extensions := AExtensions;
    Result.LanguageId := ALanguageId;
  end;

  function NodeCommandLine(const AScriptFileName: string): string;
  var
    LNodeFileName, LScriptFileName: string;
  begin
    Result := '';

    LNodeFileName := ProgramFilesDirectory + '\nodejs\node.exe';
    LScriptFileName := GetEnvironmentVariable('APPDATA') + '\npm\node_modules\' + AScriptFileName;

    if FileExists(LNodeFileName) and FileExists(LScriptFileName) then
      Result := '"' + LNodeFileName + '" "' + LScriptFileName + '" --stdio';
  end;

var
  LDirectory, LFileName, LCommandLine: string;
  LDefinition: TTextEditorLanguageServerDefinition;
begin
  LDirectory := GetEnvironmentVariable('ProgramFiles(x86)') + '\Embarcadero\Studio';
  LCommandLine := '';

  if TDirectory.Exists(LDirectory) then
  for var LStudioDirectory in TDirectory.GetDirectories(LDirectory) do
  begin
    LFileName := LStudioDirectory + '\bin\DelphiLSP.exe';

    if FileExists(LFileName) then
      LCommandLine := '"' + LFileName + '"';
  end;

  if not LCommandLine.IsEmpty then
  begin
    LDefinition := AddDefinition('DelphiLSP', LCommandLine, '.pas;.pp;.dpr;.lpr;.inc', 'pascal');
    LDefinition.RootPathKind := rpMarkerFile;
    LDefinition.RootPath := '*.delphilsp.json';
    LDefinition.Configuration := '{"settings":{"settingsFile":"%MARKERFILEURI%"}}';
    LDefinition.SettingsFallback := sfDelphiLsp;
  end;

  LFileName := ProgramFilesDirectory + '\LLVM\bin\clangd.exe';

  if FileExists(LFileName) then
  begin
    AddDefinition('clangd (C)', '"' + LFileName + '"', '.c;.h', 'c');
    AddDefinition('clangd (C++)', '"' + LFileName + '"', '.cpp;.cc;.cxx;.hpp', 'cpp');
  end;

  LCommandLine := NodeCommandLine('pyright\langserver.index.js');

  if not LCommandLine.IsEmpty then
    AddDefinition('Pyright', LCommandLine, '.py;.pyi', 'python');

  LCommandLine := NodeCommandLine('typescript-language-server\lib\cli.mjs');

  if not LCommandLine.IsEmpty then
  begin
    AddDefinition('TypeScript', LCommandLine, '.ts;.tsx', 'typescript');
    AddDefinition('JavaScript', LCommandLine, '.js;.jsx;.mjs', 'javascript');
  end;
end;

end.
