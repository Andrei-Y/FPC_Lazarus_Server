unit UMainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  Unit_Main; // Подключаем нашего Дирижёра

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
//    MemoLog: TMemo;
    MemoLog: TMemo; // Добавь TMemo на форму, чтобы видеть, что происходит
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FServer: TForumServer;
  public
    procedure Log(const AMsg: string); // Добавь CONST перед AMsg
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

procedure TForm1.FormCreate(Sender: TObject);
begin
  Log('Запуск сервера...');
  try
    // Создаем экземпляр Дирижёра
    FServer := TForumServer.Create('forum.db'); // Добавь имя файла
      FServer.OnLog := @Log; // Привязываем наш метод Log формы к серверу
    // Запускаем все системы (БД, Сеть, Воркер)
    FServer.Start;
    Log('Сервер запущен на порту 8080.');
    Log('Открой в браузере: http://localhost:8080');
  except
    on E: Exception do
      Log('ОШИБКА СТАРТА: ' + E.Message);
  end;
end;

procedure TForm1.Button1Click(Sender: TObject);
var
  ActualHeadID: Integer;
begin
  Log('--- ТЕСТ ГРАВИТАЦИИ ---');

  // Вызываем наш новый метод
  ActualHeadID := FServer.DB.CreateHead('Паспорт новой системы');

  if ActualHeadID > 0 then
  begin
    Log('Реальный ID Головы: ' + IntToStr(ActualHeadID));

    // Приземляем к полученному ID
    FServer.DB.LandingNode(ActualHeadID, 'Первая мысль');
    FServer.DB.LandingNode(ActualHeadID, 'Вторая мысль');

    Log('Запуск выдергивания от ID: ' + IntToStr(ActualHeadID));
    FServer.Worker.ExposeSystem(ActualHeadID);
  end
  else
    Log('Ошибка: Не удалось создать голову.');
end;




procedure TForm1.Log(const AMsg: string); // Добавь const и сюда!
begin
  MemoLog.Lines.Add(FormatDateTime('HH:nn:ss ', Now) + AMsg);
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  if Assigned(FServer) then
  begin
    FServer.Stop;
    FServer.Free;
  end;
end;

end.


