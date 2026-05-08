program project1;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, unit1
  { you can add units after this };

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
    // --- ЖЕСТКОЕ ПРИЗЕМЛЕНИЕ ---
  // Если сервер существует, гасим его активность
  // Вместо попыток дотянуться до FServer, просто рубим всё
  Halt(0);

  // Контрольный выстрел для Linux
  Halt(0);
end.

