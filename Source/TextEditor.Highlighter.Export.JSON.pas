unit TextEditor.Highlighter.Export.JSON;

interface

uses
  System.Classes, System.JSON, TextEditor;

type
  TTextEditorHighlighterExportJSON = class(TObject)
  strict private
    FEditor: TCustomTextEditor;
    procedure ExportColorTheme(const AThemeObject: TJSONObject);
  public
    constructor Create(const AEditor: TCustomTextEditor); overload;
    procedure SaveThemeToFile(const AFileName: string);
  end;

implementation

uses
  System.SysUtils, System.TypInfo, Vcl.Graphics, TextEditor.JSON.Helper;

type
  TPropertyArray = array of PPropInfo;

constructor TTextEditorHighlighterExportJSON.Create(const AEditor: TCustomTextEditor);
begin
  inherited Create;

  FEditor := AEditor;
end;

procedure TTextEditorHighlighterExportJSON.SaveThemeToFile(const AFileName: string);
const
  THEME_FILE_FORMAT = '{ "Theme": { "Colors": {}, "Fonts": {}, "FontSizes": {}, "Styles": [] } }';
var
  LJSONObject: TJSONObject;
  LStringList: TStringList;
begin
  LJSONObject := TJSONObject.ParseJSONValue(THEME_FILE_FORMAT) as TJSONObject;
  try
    ExportColorTheme(LJSONObject.ValueObject['Theme']);

    LStringList := TStringList.Create;
    try
      LStringList.Text := LJSONObject.Format(2);
      LStringList.SaveToFile(AFileName);
    finally
      LStringList.Free;
    end;
  finally
    LJSONObject.Free;
  end;
end;

function IntegerAsString(const ATypeInfo: PTypeInfo; const AValue: Integer): string;
var
  LIntToIdent: TIntToIdent;
  LIdent: string;
begin
  LIntToIdent := FindIntToIdent(ATypeInfo);

  Result := if Assigned(LIntToIdent) and LIntToIdent(AValue, LIdent) then LIdent else '$' + IntToHex(AValue, SizeOf(Integer) * 2);
end;

function SetAsString(const ATypeInfo: PTypeInfo; const AValue: Integer): string;
var
  LBaseType: PTypeInfo;
begin
  Result := '';

  LBaseType := GetTypeData(ATypeInfo)^.CompType^;

  for var LIndex := 0 to SizeOf(TIntegerSet) * 8 - 1 do
  if LIndex in TIntegerSet(AValue) then
  begin
    if not Result.IsEmpty then
      Result := Result + ';';

    Result := Result + Copy(GetEnumName(LBaseType, LIndex), 3);
  end;
end;

procedure TTextEditorHighlighterExportJSON.ExportColorTheme(const AThemeObject: TJSONObject);
var
  LPropertyArray: TPropertyArray;
  LPropertyCount: Integer;

  procedure GetPropertyArray(const APTypeInfo: PTypeInfo);
  begin
    LPropertyCount := GetPropList(APTypeInfo, tkProperties, nil);
    SetLength(LPropertyArray, LPropertyCount);
    GetPropList(APTypeInfo, tkProperties, PPropList(LPropertyArray));
  end;

  procedure ClearPropertyArray;
  begin
    SetLength(LPropertyArray, 0);
  end;

var
  LJSONObject, LJSONObject2: TJSONObject;
  LPPropInfo: PPropInfo;
  LObject: TObject;
  LJSONArray: TJSONArray;
  LStyle: string;
begin
  { Colors }
  LJSONObject := AThemeObject.ValueObject['Colors'];

  GetPropertyArray(FEditor.Colors.ClassInfo);
  try
    for var LIndex := 0 to LPropertyCount - 1 do
    begin
      LPPropInfo := LPropertyArray[LIndex];
      LJSONObject.ValueString[string(LPPropInfo.Name)] := IntegerAsString(LPPropInfo^.PropType^, GetOrdProp(FEditor.Colors, LPPropInfo));
    end;
  finally
    ClearPropertyArray;
  end;
  { Fonts and font sizes }
  LJSONObject := AThemeObject.ValueObject['Fonts'];
  LJSONObject2 := AThemeObject.ValueObject['FontSizes'];

  GetPropertyArray(FEditor.Fonts.ClassInfo);
  try
    for var LIndex := 0 to LPropertyCount - 1 do
    begin
      LPPropInfo := LPropertyArray[LIndex];

      LObject := GetObjectProp(FEditor.Fonts, LPPropInfo);

      LJSONObject.ValueString[string(LPPropInfo.Name)] := TFont(LObject).Name;
      LJSONObject2.ValueString[string(LPPropInfo.Name)] := TFont(LObject).Size.ToString;
    end;
  finally
    ClearPropertyArray;
  end;
  { Styles }
  LJSONArray := AThemeObject.ValueArray['Styles'];

  GetPropertyArray(FEditor.FontStyles.ClassInfo);
  try
    for var LIndex := 0 to LPropertyCount - 1 do
    begin
      LPPropInfo := LPropertyArray[LIndex];

      LStyle := SetAsString(LPPropInfo^.PropType^, GetOrdProp(FEditor.FontStyles, LPPropInfo));

      if not LStyle.IsEmpty then
      begin
        LJSONObject := LJSONArray.AddObject;
        LJSONObject.ValueString['Name'] := string(LPPropInfo.Name);
        LJSONObject.ValueString['Style'] := LStyle;
      end;
    end;
  finally
    ClearPropertyArray;
  end;
end;

end.
