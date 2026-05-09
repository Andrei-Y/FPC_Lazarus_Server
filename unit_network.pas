unit Unit_Network;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fphttpserver, fpjson, jsonparser, Sockets, BaseUnix;

type
  { Основной класс сетевого модуля }
  TForumNetwork = class
  private
    FServer: TFPHTTPServer;

    // Главный диспетчер: распределяет, кто пришел (браузер или админка)
    // Имена методов теперь на латинице (HandleRequest вместо ОбработкаЗапроса)
    procedure HandleRequest(Sender: TObject; var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse);

    // 1. Секция для обычных пользователей (Обычный Веб)
    procedure HandlePublicWeb(var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse);

    // 2. Секция для управления (Админ-API для Lazarus-клиента)
    procedure HandleAdminAPI(var ARequest: TFPHTTPConnectionRequest;
      var AResponse: TFPHTTPConnectionResponse);
  public
    constructor Create(APort: Word);
    destructor Destroy; override;
    procedure Start;
    procedure Stop; // Метод для корректной остановки сервера
  end;

implementation

{ TForumNetwork }

constructor TForumNetwork.Create(APort: Word);
begin
  FServer := TFPHTTPServer.Create(nil);
  FServer.Port := APort;
  // Назначаем обработчик события при получении запроса
  FServer.OnRequest := @HandleRequest;
    FServer.Threaded := True; // Чтобы не вешать GUI
      FServer.Active := False;
end;

procedure TForumNetwork.HandleRequest(Sender: TObject; var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
begin
  // Используем универсальный метод GetCustomHeader
  if ARequest.GetCustomHeader('X-Custom-Client') = 'Lazarus-Astro-Admin' then
    HandleAdminAPI(ARequest, AResponse)
  else
    HandlePublicWeb(ARequest, AResponse);
end;


{ --- ПУБЛИЧНАЯ ЧАСТЬ: Для тех, кто зашел через обычный браузер --- }

procedure TForumNetwork.HandlePublicWeb(var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
var
  Path: string;
begin
  AResponse.ContentType := 'text/html; charset=utf-8';
  Path := ARequest.PathInfo; // Путь после адреса сервера

  // 1. Если просят корень или индекс - отдаем главную
  if (Path = '/') or (Path = '/index.html') then
  begin

      // Запрещаем кэш на корню
  AResponse.SetCustomHeader('Cache-Control', 'no-store, no-cache, must-revalidate');
  AResponse.ContentType := 'text/html; charset=utf-8';

    AResponse.Content := '<html><body style="font-family:sans-serif; background:#eee; padding:50px;">' +
                         '<h1 style="color:#2c3e50;">🚀 Космическая Система Знаний</h1>' +
                         '<p>Сервер в эфире. Эстафета хвостов готова к передаче.</p>' +
                         '<hr><a href="/admin">Войти в админку</a> | <a href="/forum">Просмотр форума</a>' +
                         '</body></html>';
  end

  // 2. Заглушка для будущего форума
  else if Path = '/forum' then
  begin
    AResponse.Content := '<html><body><h1>Раздел Форума</h1><p>Здесь будет стриминг дерева...</p></body></html>';
  end

  // 3. Заглушка для админки
  else if Path = '/admin' then
  begin
    AResponse.Content := '<html><body><h1>Панель управления</h1><p>Доступ только для админа.</p></body></html>';
  end

  // 4. Всё остальное — честная 404
    else
  begin
    AResponse.Code := 404;
    // Добавь вывод того, что РЕАЛЬНО пришло в PathInfo
    AResponse.Content := '<html><body><h1>Ошибка 404</h1>' +
                         '<p>Вы искали: <b>' + ARequest.PathInfo + '</b></p>' +
                         '<p>Полный URL: <b>' + ARequest.URL + '</b></p></body></html>';
  end;
end;

//procedure TForumNetwork.HandlePublicWeb(var ARequest: TFPHTTPConnectionRequest;
//  var AResponse: TFPHTTPConnectionResponse);
//begin
//  AResponse.ContentType := 'text/html; charset=utf-8';
//
//  if ARequest.PathInfo = '/' then
//    AResponse.Content := '<html><body><h1>Космическая Система Знаний</h1>' +
//                         '<p>Сервер работает. Используйте клиентское приложение для визуализации.</p></body></html>'
//  else
//  begin
//    AResponse.Code := 404;
//    AResponse.Content := '<html><body>Ошибка 404: Объект не найден.</body></html>';
//  end;
//end;

{ --- АДМИН-API: Для твоего клиентского приложения на ноутбуке --- }
procedure TForumNetwork.HandleAdminAPI(var ARequest: TFPHTTPConnectionRequest;
  var AResponse: TFPHTTPConnectionResponse);
begin
  AResponse.ContentType := 'application/json; charset=utf-8';

  // Пример маршрута: запрос очереди на модерацию
  if ARequest.PathInfo = '/admin/get_audit_list' then
  begin
    AResponse.Content := '{"nodes": [], "status": "нарушений не обнаружено"}';
  end
  // Пример маршрута: запрос данных всей системы
  else if ARequest.PathInfo = '/admin/get_system' then
  begin
    AResponse.Content := '{"root_id": 1, "nodes_count": 0, "info": "система пуста"}';
  end
  else
  begin
    AResponse.Code := 400;
    AResponse.Content := '{"error": "неизвестная команда"}';
  end;
end;

procedure TForumNetwork.Start;
begin
  FServer.Active := True;
end;
//
//procedure TForumNetwork.Stop;
//begin
//    if Assigned(FServer) then
//    begin
//      FServer.Active := False;
//      // В Linux принудительное уничтожение объекта лучше всего освобождает порт
//      FreeAndNil(FServer);
//    end;
//end;

procedure TForumNetwork.Stop;
var
  S: LongInt;
  Addr: TInetSockAddr;
begin
  if not Assigned(FServer) then Exit;

  // 1. Ставим флаг выключения
  FServer.Active := False;

  // 2. Делаем "пустой звонок", чтобы разбудить блокирующий Accept
  S := fpSocket(AF_INET, SOCK_STREAM, 0);
  if S <> -1 then
  begin
    Addr.sin_family := AF_INET;
    Addr.sin_port := htons(FServer.Port);
    Addr.sin_addr.s_addr := htonl($7F000001); // 127.0.0.1 (localhost)

    // Пытаемся подключиться. Сервер проснется, увидит Active=False и выйдет
    fpConnect(S, @Addr, sizeof(Addr));

    // Закрываем наше временное соединение
    fpshutdown(S, 2);
    CloseSocket(S);
  end;

  // 3. Теперь можно спокойно удалять объект
  FreeAndNil(FServer);
end;



destructor TForumNetwork.Destroy;
begin
  Stop; // Вызываем наш стоп
  inherited Destroy;
end;


end.

