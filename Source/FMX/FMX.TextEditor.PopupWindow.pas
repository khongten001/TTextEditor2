unit FMX.TextEditor.PopupWindow;

interface

uses
  System.Classes, System.Types, System.UITypes, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Types;

type
  TTextEditorPopupWindow = class(TControl)
  protected
    FActiveControl: TControl;
    FBorderColor: TAlphaColor;
    FBorderWidth: Integer;
    procedure Show(const AOrigin: TPointF); reintroduce; virtual;
  public
    { FMX TControl.Show/Hide are empty change-notification methods, not actions like in the VCL - the popup
      reintroduces them to actually toggle visibility. }
    procedure Hide; reintroduce; virtual;
    procedure SetBounds(X, Y, AWidth, AHeight: Single); override;
    procedure SetOrigin(const AOrigin: TPointF); virtual;
    constructor Create(AOwner: TComponent); override;
    property ActiveControl: TControl read FActiveControl;
  end;

implementation

type
  TControlAccess = class(TControl);
  TFormAccess = class(TCommonCustomForm);

constructor TTextEditorPopupWindow.Create(AOwner: TComponent);
var
  LOwnerControl: TControl;
begin
  inherited Create(AOwner);

  Visible := False;
  FBorderColor := TAlphaColors.Gray;
  FBorderWidth := 0;

  LOwnerControl := AOwner as TControl;

  if Assigned(LOwnerControl.Parent) then
    Parent := LOwnerControl.Parent
  else
    Parent := LOwnerControl;
end;

procedure TTextEditorPopupWindow.SetOrigin(const AOrigin: TPointF);
var
  LPoint: TPointF;
begin
  LPoint := AOrigin;

  { The origin is given in owner (editor) local coordinates. Absolute coordinates are form client
    coordinates, so when the parent is the form itself no further conversion is needed. }
  if Owner is TControl then
  begin
    LPoint := (Owner as TControl).LocalToAbsolute(LPoint);

    if Parent is TControl then
      LPoint := (Parent as TControl).AbsoluteToLocal(LPoint);
  end;

  Position.X := LPoint.X;
  Position.Y := LPoint.Y;
end;

procedure TTextEditorPopupWindow.Hide;
begin
  Visible := False;
end;

procedure TTextEditorPopupWindow.SetBounds(X, Y, AWidth, AHeight: Single);
var
  LOldBounds, LUnionBounds: TRectF;
begin
  LOldBounds := BoundsRect;

  inherited SetBounds(X, Y, AWidth, AHeight);

  if Visible and (LOldBounds <> BoundsRect) then
  begin
    LUnionBounds := TRectF.Union(LOldBounds, BoundsRect);
    LUnionBounds.Inflate(2, 2);

    if Parent is TControl then
      TControlAccess(Parent).RepaintRect(LUnionBounds)
    else
    if Parent is TCommonCustomForm then
      TFormAccess(Parent).InvalidateRect(LUnionBounds);
  end;
end;

procedure TTextEditorPopupWindow.Show(const AOrigin: TPointF);
begin
  SetOrigin(AOrigin);

  Visible := True;

  BringToFront;
  Repaint;
end;

end.
