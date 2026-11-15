(* XmlForge4D - shared compiler configuration.
  Included at the very top of every unit:  {$I XmlForge4D.inc}
  Targets: Delphi 2009+ (tested design target: Delphi 12) and Free Pascal 3.0+ (design target: 3.2.x). *)

{$IFDEF FPC}
  {$MODE DELPHIUNICODE}      // string = UnicodeString, Delphi-compatible syntax
  {$MODESWITCH ADVANCEDRECORDS}
  {$DEFINE XF_FPC}
{$ELSE}
  {$DEFINE XF_DELPHI}
  {$IFDEF CONDITIONALEXPRESSIONS}
    {$IF CompilerVersion < 20.0}
      {$MESSAGE FATAL 'XmlForge4D requires Delphi 2009 or newer (Unicode strings)'}
    {$IFEND}
  {$ELSE}
    {$MESSAGE FATAL 'XmlForge4D requires Delphi 2009 or newer (Unicode strings)'}
  {$ENDIF}
{$ENDIF}

{$POINTERMATH ON}
{$IFOPT Q+}{$Q-}{$ENDIF}
