object FrameSyncEditors: TFrameSyncEditors
  Left = 0
  Top = 0
  Width = 1148
  Height = 860
  Align = alClient
  TabOrder = 0
  object PanelOptions: TPanel
    Left = 0
    Top = 0
    Width = 1148
    Height = 33
    Align = alTop
    BevelOuter = bvNone
    ShowCaption = False
    TabOrder = 0
    object LabelOffset: TLabel
      Left = 440
      Top = 9
      Width = 3
      Height = 15
    end
    object CheckBoxSyncVertical: TCheckBox
      Left = 8
      Top = 8
      Width = 200
      Height = 17
      Caption = 'Synchronize vertical scrolling'
      TabOrder = 0
      OnClick = CheckBoxSyncClick
    end
    object CheckBoxSyncHorizontal: TCheckBox
      Left = 216
      Top = 8
      Width = 210
      Height = 17
      Caption = 'Synchronize horizontal scrolling'
      TabOrder = 1
      OnClick = CheckBoxSyncClick
    end
  end
  object GridPanel: TGridPanel
    Left = 0
    Top = 33
    Width = 1148
    Height = 827
    Align = alClient
    BevelOuter = bvNone
    Caption = 'GridPanel'
    ColumnCollection = <
      item
        Value = 50.000000000000000000
      end
      item
        Value = 50.000000000000000000
      end>
    ControlCollection = <
      item
        Column = 0
        Control = EditorLeft
        Row = 0
      end
      item
        Column = 1
        Control = EditorRight
        Row = 0
      end>
    RowCollection = <
      item
        Value = 100.000000000000000000
      end>
    ShowCaption = False
    TabOrder = 1
    object EditorLeft: TTextEditor
      Left = 0
      Top = 0
      Width = 574
      Height = 827
      Align = alClient
      Border.Color = 9471874
      Border.ColoredEdges = [ebLeft, ebTop, ebRight, ebBottom]
      LeftMargin.Width = 57
      OnScroll = EditorScroll
      PartialLoad.Rows = 100
      TabOrder = 0
    end
    object EditorRight: TTextEditor
      Left = 574
      Top = 0
      Width = 574
      Height = 827
      Align = alClient
      Border.Color = 9471874
      Border.ColoredEdges = [ebLeft, ebTop, ebRight, ebBottom]
      LeftMargin.Width = 57
      OnScroll = EditorScroll
      PartialLoad.Rows = 100
      TabOrder = 1
    end
  end
end
