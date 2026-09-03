unit TextEditor.JSON.Helper;

interface

uses
  System.Classes, System.JSON, System.SysUtils, System.UITypes, TextEditor.Consts;

type
  TTextEditorJSONObjectHelper = class helper for TJSONObject
  strict private
    function GetValueArray(const AName: string): TJSONArray;
    function GetValueBoolean(const AName: string): Boolean;
    function GetValueCharSet(const AName: string): TTextEditorCharSet;
    function GetValueColor(const AName: string): TColor;
    function GetValueObject(const AName: string): TJSONObject;
    function GetValueString(const AName: string): string;
    procedure SetValueString(const AName, AValue: string);
  public
    class function ParseFromStream(const AStream: TStream): TJSONObject; static;
    function Contains(const AName: string): Boolean;
    function ValueBooleanDef(const AName: string; const ADefault: Boolean): Boolean;
    function ValueIntegerDef(const AName: string; const ADefault: Integer): Integer;
    function ValueStringDef(const AName, ADefault: string): string;
    property ValueArray[const AName: string]: TJSONArray read GetValueArray;
    property ValueBoolean[const AName: string]: Boolean read GetValueBoolean;
    property ValueCharSet[const AName: string]: TTextEditorCharSet read GetValueCharSet;
    property ValueColor[const AName: string]: TColor read GetValueColor;
    property ValueObject[const AName: string]: TJSONObject read GetValueObject;
    property ValueString[const AName: string]: string read GetValueString write SetValueString;
  end;

  TTextEditorJSONArrayHelper = class helper for TJSONArray
  strict private
    function GetValueObject(const AIndex: Integer): TJSONObject;
    function GetValueString(const AIndex: Integer): string;
  public
    function AddObject: TJSONObject;
    property ValueObject[const AIndex: Integer]: TJSONObject read GetValueObject;
    property ValueString[const AIndex: Integer]: string read GetValueString;
  end;

implementation

uses
  System.Generics.Collections, Vcl.Graphics;

function JSONValueToString(const AValue: TJSONValue): string;
begin
  Result := if Assigned(AValue) and not (AValue is TJSONNull) then AValue.Value else '';
end;

{ TTextEditorJSONObjectHelper }

class function TTextEditorJSONObjectHelper.ParseFromStream(const AStream: TStream): TJSONObject;
var
  LBytes: TBytes;
  LEncoding: TEncoding;
  LPreambleLength: Integer;
begin
  SetLength(LBytes, AStream.Size - AStream.Position);
  AStream.ReadBuffer(LBytes, Length(LBytes));

  LEncoding := nil;
  LPreambleLength := TEncoding.GetBufferEncoding(LBytes, LEncoding, TEncoding.UTF8);

  if LEncoding <> TEncoding.UTF8 then
    LBytes := TEncoding.Convert(LEncoding, TEncoding.UTF8, LBytes, LPreambleLength, Length(LBytes) - LPreambleLength);

  Result := TJSONObject.ParseJSONValue(LBytes, 0, [TJSONParseOption.IsUTF8, TJSONParseOption.RaiseExc]) as TJSONObject;
end;

function TTextEditorJSONObjectHelper.Contains(const AName: string): Boolean;
begin
  Result := Assigned(Values[AName]);
end;

function TTextEditorJSONObjectHelper.GetValueArray(const AName: string): TJSONArray;
var
  LValue: TJSONValue;
begin
  LValue := Values[AName];

  if Assigned(LValue) then
    Exit(LValue as TJSONArray);

  Result := TJSONArray.Create;
  AddPair(AName, Result);
end;

function TTextEditorJSONObjectHelper.GetValueBoolean(const AName: string): Boolean;
var
  LValue: TJSONValue;
begin
  LValue := Values[AName];

  if LValue is TJSONBool then
    Result := TJSONBool(LValue).AsBoolean
  else
  if LValue is TJSONString then
    Result := StrToBoolDef(TJSONString(LValue).Value, False)
  else
    Result := False;
end;

function TTextEditorJSONObjectHelper.GetValueCharSet(const AName: string): TTextEditorCharSet;
begin
  Result := [];

  for var LChar in ValueString[AName] do
  if Ord(LChar) < 256 then
    Include(Result, AnsiChar(LChar));
end;

function TTextEditorJSONObjectHelper.GetValueColor(const AName: string): TColor;
var
  LValue: string;
begin
  LValue := ValueString[AName].Trim;

  Result := if LValue.IsEmpty then TColors.SysDefault else StringToColor(LValue);
end;

function TTextEditorJSONObjectHelper.GetValueObject(const AName: string): TJSONObject;
var
  LValue: TJSONValue;
begin
  LValue := Values[AName];

  if Assigned(LValue) then
    Exit(LValue as TJSONObject);

  Result := TJSONObject.Create;
  AddPair(AName, Result);
end;

function TTextEditorJSONObjectHelper.GetValueString(const AName: string): string;
begin
  Result := JSONValueToString(Values[AName]);
end;

procedure TTextEditorJSONObjectHelper.SetValueString(const AName, AValue: string);
begin
  RemovePair(AName).Free;
  AddPair(AName, AValue);
end;

function TTextEditorJSONObjectHelper.ValueBooleanDef(const AName: string; const ADefault: Boolean): Boolean;
begin
  Result := if Contains(AName) then ValueBoolean[AName] else ADefault;
end;

function TTextEditorJSONObjectHelper.ValueIntegerDef(const AName: string; const ADefault: Integer): Integer;
begin
  Result := StrToIntDef(ValueString[AName], ADefault);
end;

function TTextEditorJSONObjectHelper.ValueStringDef(const AName, ADefault: string): string;
begin
  Result := ValueString[AName];

  if Result.Trim.IsEmpty then
    Result := ADefault;
end;

{ TTextEditorJSONArrayHelper }

function TTextEditorJSONArrayHelper.AddObject: TJSONObject;
begin
  Result := TJSONObject.Create;
  AddElement(Result);
end;

function TTextEditorJSONArrayHelper.GetValueObject(const AIndex: Integer): TJSONObject;
begin
  Result := Items[AIndex] as TJSONObject;
end;

function TTextEditorJSONArrayHelper.GetValueString(const AIndex: Integer): string;
begin
  Result := JSONValueToString(Items[AIndex]);
end;

end.
