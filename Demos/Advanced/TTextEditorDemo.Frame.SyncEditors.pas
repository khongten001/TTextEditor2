unit TTextEditorDemo.Frame.SyncEditors;

interface

uses
  System.Classes, System.SysUtils, Vcl.Controls, Vcl.ExtCtrls, Vcl.Forms, Vcl.StdCtrls, TextEditor;

type
  TFrameSyncEditors = class(TFrame)
    CheckBoxSyncHorizontal: TCheckBox;
    CheckBoxSyncVertical: TCheckBox;
    EditorLeft: TTextEditor;
    EditorRight: TTextEditor;
    GridPanel: TGridPanel;
    LabelOffset: TLabel;
    PanelOptions: TPanel;
    procedure CheckBoxSyncClick(Sender: TObject);
    procedure EditorScroll(const ASender: TObject; const AScrollBar: TScrollBarKind);
  private
    FHorizontalOffset: Integer;
    FSyncing: Boolean;
    FTopLineOffset: Integer;
    procedure UpdateOffsetLabel;
  public
    constructor Create(AOwner: TComponent); override;
  end;

implementation

{$R *.dfm}

constructor TFrameSyncEditors.Create(AOwner: TComponent);
var
  LBuilder: TStringBuilder;
begin
  inherited Create(AOwner);

  LBuilder := TStringBuilder.Create;
  try
    for var LIndex := 1 to 500 do
      LBuilder.AppendLine(Format('Line %4d  The quick brown fox jumps over the lazy dog. ' +
        'Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium.', [LIndex]));

    EditorLeft.Lines.Text := LBuilder.ToString;
    EditorRight.Lines.Text := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

procedure TFrameSyncEditors.CheckBoxSyncClick(Sender: TObject);
begin
  if Sender = CheckBoxSyncVertical then
    FTopLineOffset := EditorRight.TopLine - EditorLeft.TopLine
  else
    FHorizontalOffset := EditorRight.HorizontalScrollPosition - EditorLeft.HorizontalScrollPosition;

  UpdateOffsetLabel;
end;

procedure TFrameSyncEditors.EditorScroll(const ASender: TObject; const AScrollBar: TScrollBarKind);
var
  LOther: TTextEditor;
begin
  if FSyncing then
    Exit;

  FSyncing := True;
  try
    LOther := if ASender = EditorLeft then EditorRight else EditorLeft;

    if (AScrollBar = TScrollBarKind.sbVertical) and CheckBoxSyncVertical.Checked then
    begin
      if ASender = EditorLeft then
        EditorRight.TopLine := EditorLeft.TopLine + FTopLineOffset
      else
        EditorLeft.TopLine := EditorRight.TopLine - FTopLineOffset;

      LOther.Invalidate;
    end
    else
    if (AScrollBar = TScrollBarKind.sbHorizontal) and CheckBoxSyncHorizontal.Checked then
    begin
      if ASender = EditorLeft then
        EditorRight.HorizontalScrollPosition := EditorLeft.HorizontalScrollPosition + FHorizontalOffset
      else
        EditorLeft.HorizontalScrollPosition := EditorRight.HorizontalScrollPosition - FHorizontalOffset;

      LOther.Invalidate;
    end;
  finally
    FSyncing := False;
  end;
end;

procedure TFrameSyncEditors.UpdateOffsetLabel;
begin
  var LText := '';

  if CheckBoxSyncVertical.Checked then
    LText := Format('Line offset: %+d', [FTopLineOffset]);

  if CheckBoxSyncHorizontal.Checked then
  begin
    if LText <> '' then
      LText := LText + '   ';

    LText := LText + Format('Horizontal offset: %+d px', [FHorizontalOffset]);
  end;

  LabelOffset.Caption := LText;
end;

end.
