unit Unit_DB;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, sqldb, DateUtils;

type
  TDatabaseModule = class
  private
    FConn: TSQLite3Connection;
    FTran: TSQLTransaction;
    FQuery: TSQLQuery;
  public
    constructor Create(ADBPath: string);
    destructor Destroy; override;

    // Получить физический ID из постоянного (Маппинг)
    function GetPhysicalID(APermanentID: Integer): Integer;

    // Добавление узла с автоматическим созданием маппинга
    function AddNode(AParentID: Integer; AContent: string; AX, AY: Double): Integer;

    // Получение данных для пульсации и рендера
    procedure GetSystemData(ARootID: Integer; AList: TList);

    procedure ExecuteMaintenance; // Для запуска VACUUM воркером
  end;

implementation

constructor TDatabaseModule.Create(ADBPath: string);
begin
    //FConn := TSQLite3Connection.Create(nil);
    //FTran := TSQLTransaction.Create(FConn);
    //FQuery := TSQLQuery.Create(nil);
    //FQuery.Database := FConn;
    //FQuery.Transaction := FTran;
    //
    //FConn.DatabaseName := ADBPath;
    //FConn.Open;
    //
    //// Включаем режим WAL и быструю синхронизацию
    //FConn.ExecuteDirect('PRAGMA journal_mode=WAL;');
    //FConn.ExecuteDirect('PRAGMA synchronous=NORMAL;');
    inherited Create; // Хороший тон для классов
  FConn := TSQLite3Connection.Create(nil);
  FTran := TSQLTransaction.Create(FConn);
  FQuery := TSQLQuery.Create(nil);

  FConn.Transaction := FTran;
  FQuery.Database := FConn;
  FQuery.Transaction := FTran;

  // Указываем полный путь к базе в папке с программой
  FConn.DatabaseName := ExtractFilePath(ParamStr(0)) + ADBPath;

  try
    FConn.Open;
    FTran.Active := True;

    // Создаем таблицы
    // 1. Nodes - Хранилище данных
    FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS nodes (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'content TEXT, ' +
      'coords_x REAL, coords_y REAL, ' +
      'chronology INTEGER, ' +
      'activity_index REAL DEFAULT 0);');

    // 2. ID_Map - Таблица переадресации (Маппинг)
    FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS id_map (' +
      'perm_id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'phys_id INTEGER);');

    // 3. Users - Карма и баллы
    FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS users (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'name TEXT, karma INTEGER DEFAULT 100);');

    // 4. Mod_Queue - Очередь для "Судьи"
    FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS mod_queue (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'node_id INTEGER, report TEXT, status INTEGER DEFAULT 0);');

      // 5. RenderCache - кэш отрисованных объектов (звезд, планет, систем)
  FConn.ExecuteDirect('CREATE TABLE IF NOT EXISTS render_cache (' +
    'perm_id INTEGER PRIMARY KEY, ' + // Вечный ID из маппинга
    'img_data BLOB, ' +               // Бинарные данные картинки (PNG/BMP)
    'last_update INTEGER);');         // Когда кэш был создан (хронология)


      FTran.Commit;
  except
    on E: Exception do raise Exception.Create('Ошибка БД: ' + E.Message);
  end;
end;

// 1. Тело функции GetPhysicalID
function TDatabaseModule.GetPhysicalID(APermanentID: Integer): Integer;
begin
  // Пока заглушка, завтра напишем логику маппинга
  Result := APermanentID;
end;

// 2. Тело функции AddNode
function TDatabaseModule.AddNode(AParentID: Integer; AContent: string; AX, AY: Double): Integer;
begin
  // Пока заглушка
  Result := 0;
end;

// 3. Тело процедуры GetSystemData
procedure TDatabaseModule.GetSystemData(ARootID: Integer; AList: TList);
begin
  // Пока пусто
end;

// 4. Тело процедуры ExecuteMaintenance
procedure TDatabaseModule.ExecuteMaintenance;
begin
  FConn.ExecuteDirect('VACUUM;');
end;

destructor TDatabaseModule.Destroy;
begin
  FQuery.Free;
  FTran.Free;
  FConn.Free;
  inherited Destroy;
end;

end.
