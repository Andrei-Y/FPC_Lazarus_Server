program project1;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads, // КРИТИЧНО для Jetson Nano и работы Unit_Worker
  {$ENDIF}
  Interfaces, // связующее звено для GUI
  Forms,
  UMainForm,    // Твоя главная форма с логом
  Unit_Main,    // Дирижёр
  Unit_DB,      // База данных
  Unit_Network, // Сеть
  Unit_Worker, Unit_Renderer;  // Фоновые задачи

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  Application.Initialize;

  // Создаем главную форму.
  // В её событии OnCreate, как мы писали выше, запустится наш Дирижёр (FServer.Start)
  Application.CreateForm(TForm1, Form1);

  Application.Run;
end.

