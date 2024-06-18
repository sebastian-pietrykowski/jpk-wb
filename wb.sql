-- utw�rz baz� danych jpk_wb
	if not exists (select 1 from master..sysdatabases d where d.[name] = 'jpk_wb')
	BEGIN
		EXEC sp_sqlexec N'create database jpk_wb'
	END

	USE jpk_wb
	GO

-- je�eli nie istnieje utw�rz procedur� remove_table
	IF NOT EXISTS 
		( SELECT 1 FROM sysobjects o
			WHERE (o.[name] = 'remove_table')
			AND		(OBJECTPROPERTY(o.[ID], N'IsProcedure') = 1)
		)
	BEGIN
		EXEC sp_sqlExec N'CREATE PROCEDURE dbo.remove_table AS select 2'
	END
	GO

-- zmodyfikuj procedur� remove_table - niech usuwa tabel�
	ALTER PROCEDURE dbo.remove_table (@tab_name nvarchar(100))
	AS
		IF EXISTS 
		( SELECT 1 FROM sysobjects o
			WHERE (o.[name] = @tab_name)
			AND		(OBJECTPROPERTY(o.[ID], N'IsUserTable') = 1)
		)
		BEGIN
			DECLARE @sql nvarchar(1000)
			SET @sql = 'DROP TABLE ' + @tab_name
			EXEC sp_sqlexec @sql
		END
	GO

-- utw�rz tabele tymczasowe
	-- utw�rz tabel� tmp_wb_na
		EXEC dbo.remove_table @tab_name = 'tmp_wb_na'
		GO
		CREATE TABLE dbo.tmp_wb_na
		(	id_dokumentu			NVARCHAR(15)	NOT NULL
		,	kod_formularza			NVARCHAR(10)	NOT NULL
		,	kod_systemowy			NVARCHAR(15)	NOT NULL	
		,	wersja_schemy			NVARCHAR(5)		NOT NULL
		,	wariant_formularza		NVARCHAR(5)		NOT NULL
		,	cel_zlozenia			NVARCHAR(5)		NOT NULL
		,	data_wytworzenia_jpk	NCHAR(19)		NOT NULL -- RRRR-MM-DDTHH:MM:SS, np. 2024-04-03T12:12:33
		,	data_od					NCHAR(10)		NOT NULL -- RRRR-MM-DD
		,	data_do					NCHAR(10)		NOT NULL -- RRRR-MM-DD
		,	domyslny_kod_waluty		NCHAR(3)		NOT NULL -- 3 litery (ISO 4217)
		,	kod_urzedu				NCHAR(4)		NOT NULL -- 4 cyfry
		)
		GO

	-- utw�rz tabel� tmp_wb_pod
		EXEC dbo.remove_table @tab_name = 'tmp_wb_pod'
		GO
		CREATE TABLE dbo.tmp_wb_pod
		(	id_podmiotu			NVARCHAR(15)	NOT NULL
		,	nip					NCHAR(10)		NOT NULL -- 10 cyfr
		,	pelna_nazwa			NVARCHAR(255)	NOT NULL	
		,	regon				NCHAR(9)		NOT NULL -- 9 cyfr
		,	kod_kraju			NVARCHAR(50)	NOT NULL
		,	wojewodztwo			NVARCHAR(50)	NOT NULL
		,	powiat				NVARCHAR(50)	NOT NULL
		,	gmina				NVARCHAR(50)	NOT NULL
		,	ulica				NVARCHAR(100)	NOT NULL
		,	nr_domu				NVARCHAR(10)	NOT NULL
		,	nr_lokalu			NVARCHAR(5)		NOT NULL
		,	miejscowosc			NVARCHAR(100)	NOT NULL
		,	kod_pocztowy		NVARCHAR(10)	NOT NULL
		,	poczta				NVARCHAR(100)	NOT NULL
		)
		GO

	-- utw�rz tabel� tmp_wb_poz
		EXEC dbo.remove_table @tab_name = 'tmp_wb_poz'
		GO
		CREATE TABLE dbo.tmp_wb_poz
		(	id_dokumentu		NVARCHAR(15)	NOT NULL
		,	id_podmiotu			NVARCHAR(15)	NOT NULL
		,	numer_rachunku		NCHAR(26)		NOT NULL -- IBAN (26 cyfr)
		,	saldo_poczatkowe	NVARCHAR(20)	NOT NULL
		,	saldo_koncowe		NVARCHAR(20)	NOT NULL
		,	liczba_wierszy		NVARCHAR(10)	NOT NULL
		,	suma_obciazen		NVARCHAR(20)	NOT NULL
		,	suma_uznan			NVARCHAR(20)	NOT NULL
		)
		GO

	-- utw�rz tabel� tmp_wb_wiersz
		EXEC dbo.remove_table @tab_name = 'tmp_wb_wiersz'
		GO
		CREATE TABLE dbo.tmp_wb_wiersz
		(	id_dokumentu			NVARCHAR(15)	NOT NULL
		,	numer_wiersza			NVARCHAR(15)	NOT NULL
		,	data_operacji			NCHAR(10)		NOT NULL -- RRRR-MM-DD
		,	nazwa_podmiotu			NVARCHAR(255)	NOT NULL
		,	opis_operacji			NVARCHAR(255)	NOT NULL
		,	kwota_operacji			NVARCHAR(20)	NOT NULL
		,	saldo_operacji			NVARCHAR(20)	NOT NULL
		)
		GO

-- utw�rz logi z b��dami
	-- ELOG_N - nag��wki
		IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'WB_ELOG_N'
			AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1)  
		)
		BEGIN
			CREATE TABLE dbo.WB_ELOG_N
			(	id_elog_n		INT NOT NULL IDENTITY CONSTRAINT PK_ELOG_N PRIMARY KEY
			,	opis_n			NVARCHAR(100) NOT NULL
			,	dt				DATETIME NOT NULL DEFAULT GETDATE()
			,	u_name			NVARCHAR(40) NOT NULL DEFAULT USER_NAME()
			,	h_name			NVARCHAR(100) NOT NULL DEFAULT HOST_NAME()
			) 
		END
		GO

	-- ELOG_D - szczeg�y
		IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'WB_ELOG_D'
			AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1)  
		)
		BEGIN
			CREATE TABLE dbo.WB_ELOG_D
			(	id_elog_n		INT NOT NULL 
					CONSTRAINT FK_ELOG_N__ELOG_P FOREIGN KEY
					REFERENCES WB_ELOG_N(id_elog_n)
			,	opis_d			NVARCHAR(100) NOT NULL
			) 
		END
		GO
-- utw�rz tabele docelowe
	-- utw�rz tabel� PODMIOT do przechowywania podmiot�w
		IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'WB_PODMIOT'
			AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1)  
		)
		BEGIN
			CREATE TABLE dbo.WB_PODMIOT
			(	id_podmiotu			INT NOT NULL IDENTITY CONSTRAINT PK_WB_PODMIOT PRIMARY KEY
			,	nip					NCHAR(10)		NOT NULL -- 10 cyfr
			,	pelna_nazwa			NVARCHAR(255)	NOT NULL	
			,	regon				NCHAR(9)		NOT NULL -- 9 cyfr
			,	kod_kraju			NVARCHAR(50)	NOT NULL
			,	wojewodztwo			NVARCHAR(50)	NOT NULL
			,	powiat				NVARCHAR(50)	NOT NULL
			,	gmina				NVARCHAR(50)	NOT NULL
			,	ulica				NVARCHAR(100)	NOT NULL
			,	nr_domu				NVARCHAR(10)	NOT NULL
			,	nr_lokalu			NVARCHAR(5)		NOT NULL
			,	miejscowosc			NVARCHAR(100)	NOT NULL
			,	kod_pocztowy		NVARCHAR(10)	NOT NULL
			,	poczta				NVARCHAR(100)	NOT NULL
			)
		END
		GO

	-- utw�rz tabel� NAGLOWEK do przechowywania nag��wk�w wyci�gu bankowego
		IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'WB_NAGLOWEK'
			AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1)  
		)
		BEGIN
			CREATE TABLE dbo.WB_NAGLOWEK
			(	id_dokumentu			INT	NOT NULL IDENTITY CONSTRAINT PK_WB_NAGLOWEK PRIMARY KEY
			,	kod_formularza			NVARCHAR(10)	NOT NULL
			,	kod_systemowy			NVARCHAR(15)	NOT NULL	
			,	wersja_schemy			NVARCHAR(5)		NOT NULL
			,	wariant_formularza		TINYINT			NOT NULL
			,	cel_zlozenia			TINYINT			NOT NULL
			,	data_wytworzenia_jpk	DATETIME		NOT NULL -- RRRR-MM-DDTHH:MM:SS, np. 2024-04-03T12:12:33
			,	data_od					DATE			NOT NULL -- RRRR-MM-DD
			,	data_do					DATE			NOT NULL -- RRRR-MM-DD
			,	domyslny_kod_waluty		NCHAR(3)		NOT NULL -- 3 litery (ISO 4217)
			,	kod_urzedu				NCHAR(4)		NOT NULL -- 4 cyfry
			)
		END
		GO

	-- utw�rz tabel� POZYCJA do przechowywania szczeg��w wyci�gu bankowego
		IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'WB_POZYCJA'
			AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1)  
		)
		BEGIN
			CREATE TABLE dbo.WB_POZYCJA
			(	id_dokumentu		INT NOT NULL
										CONSTRAINT PK_WB_POZYCJA PRIMARY KEY
										CONSTRAINT FK_WB_POZYCJA_NAGLOWEK FOREIGN KEY
										REFERENCES WB_NAGLOWEK(id_dokumentu)
			,	id_podmiotu			INT NOT NULL CONSTRAINT FK_WB_POZYCJA__PODMIOT
										FOREIGN KEY REFERENCES WB_PODMIOT(id_podmiotu)
			,	numer_rachunku		NCHAR(26)		NOT NULL -- IBAN (26 cyfr)
			,	saldo_poczatkowe	MONEY			NOT NULL
			,	saldo_koncowe		MONEY			NOT NULL
			,	liczba_wierszy		INT				NOT NULL
			,	suma_obciazen		MONEY			NOT NULL
			,	suma_uznan			MONEY			NOT NULL
			)
		END
		GO

	-- utw�rz tabel� WIERSZ do przechowywania wiersz�w wyci�gu bankowego
		IF NOT EXISTS ( SELECT 1  FROM sysobjects  o WHERE o.[name] = 'WB_WIERSZ'
			AND (OBJECTPROPERTY(o.[ID], 'IsUserTable') = 1)  
		)
		BEGIN
			CREATE TABLE dbo.WB_WIERSZ
			(	id_dokumentu			INT NOT NULL CONSTRAINT FK_WB_WIERSZ__NAGLOWEK
											FOREIGN KEY REFERENCES WB_NAGLOWEK(id_dokumentu)
			,	numer_wiersza			INT				NOT NULL
			,	CONSTRAINT PK_WB_WIERSZ PRIMARY KEY(id_dokumentu, numer_wiersza)
			,	data_operacji			DATE			NOT NULL -- RRRR-MM-DD
			,	nazwa_podmiotu			NVARCHAR(255)	NOT NULL
			,	opis_operacji			NVARCHAR(255)	NOT NULL
			,	kwota_operacji			MONEY			NOT NULL
			,	saldo_operacji			MONEY			NOT NULL
			)
		END
		GO

-- utw�rz procedur� kt�ra tw�rzy pust� procedur� o zadanej nazwie
	IF NOT EXISTS 
	(	SELECT 1 
			FROM sysobjects o 
			WHERE	(o.name = 'create_empty_proc')
			AND		(OBJECTPROPERTY(o.[ID], N'IsProcedure') = 1)
	)
	BEGIN
		DECLARE @sql nvarchar(500)
		SET @sql = 'CREATE PROCEDURE dbo.create_empty_proc AS '
		EXEC sp_sqlexec @sql
	END

	GO

	ALTER PROCEDURE dbo.create_empty_proc (@proc_name nvarchar(100))
	AS
		IF NOT EXISTS 
		(	SELECT 1 
			FROM sysobjects o 
			WHERE	(o.name = @proc_name)
			AND		(OBJECTPROPERTY(o.[ID], N'IsProcedure') = 1)
		)
		BEGIN
			DECLARE @sql nvarchar(500)
			SET @sql = 'CREATE PROCEDURE dbo.' + @proc_name + N' AS '
			EXEC sp_sqlexec @sql
		END
	GO

-- utw�rz procedur� kt�ra tw�rzy pust� funkcj� o zadanej nazwie
	EXEC dbo.create_empty_proc @proc_name = 'create_empty_fun'
	GO

	ALTER PROCEDURE dbo.create_empty_fun (@fun_name nvarchar(100), @type nvarchar(100))
	AS
		IF NOT EXISTS 
		(	SELECT 1 
			FROM sysobjects o 
			WHERE	(o.name = @fun_name)
			AND		(OBJECTPROPERTY(o.[ID], N'IsScalarFunction') = 1)
		)
		BEGIN
			DECLARE @sql nvarchar(500)
			SET @sql = 'CREATE FUNCTION dbo.' + @fun_name + N' () returns money AS begin return 0 end '
			EXEC sp_sqlexec @sql
		END
	GO

-- Utw�rz funkcj� konwertuj�c� text na money
	EXEC dbo.create_empty_fun @fun_name = 'text_to_money', @type='money'
	GO

	ALTER FUNCTION dbo.text_to_money(@txt nvarchar(20) )
	/*
	SELECT dbo.text_to_money(N'123,456.89') -- 123456,89
	SELECT dbo.text_to_money(N'123.456,89') -- 123456,89
	SELECT dbo.text_to_money(N'123 456,89') -- 123456,89
	*/
	RETURNS MONEY
	AS
	BEGIN
		SET @txt = REPLACE(@txt, N' ', N'')

		IF @txt LIKE '%,%.%' 
			BEGIN
				SET @txt = REPLACE(@txt, N',', N'')
			END ELSE
		IF @txt LIKE '%.%,%'
			BEGIN
				SET @txt = REPLACE(@txt, N'.', N'')
			END
		SET @txt = REPLACE(@txt, N',', N'.')
		RETURN  CONVERT(money, @txt)
	END
	GO

-- Utw�rz procedur� konwertuj�c� text na date
	EXEC dbo.create_empty_fun @fun_name='text_to_date', @type='date'
	GO

	ALTER FUNCTION dbo.text_to_date(@txt nvarchar(10) )
	-- SELECT dbo.text_to_date(N'2022-03-31') -- 2022-03-31
	RETURNS DATE
	AS
		BEGIN
			SET @txt = REPLACE(@txt, N'-', N'.')
			-- yyyy.mm.dd
			RETURN CONVERT(date, @txt, 102)
		END
	GO

-- Utw�rz procedur� konwertuj�c� text na datetime
	EXEC dbo.create_empty_fun @fun_name='text_to_datetime', @type='DATETIME'
	GO

	ALTER FUNCTION dbo.text_to_datetime(@txt nvarchar(30) )
	-- SELECT dbo.text_to_datetime(N'2022-03-31T00:00:00') -- 2022-03-31 00:00:00.000
	RETURNS DATETIME
	AS
		BEGIN
			-- yyyy-mm-ddThh:mi:ss.mmm
			RETURN CONVERT(datetime, REPLACE(@txt, 'T', ' '), 120)
		END
	GO

-- Utw�rz procedur� sprawdzaj�c� poprawno�� podmiotu na wyci�gu bankowego
	EXEC dbo.create_empty_proc @proc_name = 'tmp_wb_pod_check'
	GO

	ALTER PROCEDURE dbo.tmp_wb_pod_check(@error int = 0 output)
	AS
		DECLARE @count int, @elog_n nvarchar(100), @id_en int
		SET @error = 0
		SET @elog_n = 'B��d w procedurze: tmp_wb_pod_check / '

		-- Sprawd� czy jest dok�adnie 1 podmiot
			SELECT @count = COUNT(*) FROM tmp_wb_pod
			SELECT @count
			IF @count <> 1
			BEGIN
				SET @elog_n = @elog_n + 'Nie ma dok�adnie 1 podmiotu'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d) VALUES (@id_en, 'Nie 1 wiersz w tmp_wb_pod')
				
				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END
		
		-- Sprawd� czy id podmiot�w unikalne
			DECLARE @all_ids_count_pod int, @unique_ids_count_pod int
			SELECT @all_ids_count_pod = COUNT(t.id_podmiotu) FROM tmp_wb_pod t
			SELECT @unique_ids_count_pod = COUNT(DISTINCT t.id_podmiotu) FROM tmp_wb_pod t
			
			IF @all_ids_count_pod <> @unique_ids_count_pod
			BEGIN
				SET @elog_n = @elog_n + 'Id podmiotu nie s� unikalne / '
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)
				
				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d) VALUES (@id_en, 'Powtarza si� to samo id podmiotu')
				
				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy poprawny nip
			IF EXISTS (SELECT 1 FROM dbo.tmp_wb_pod t WHERE t.nip NOT LIKE REPLICATE('[0-9]', 10))
			BEGIN
				SET @elog_n = @elog_n + 'Niepoprawny nip'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, t.nip
						FROM tmp_wb_pod t WHERE t.nip NOT LIKE REPLICATE('[0-9]', 10)

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy pelna_nazwa nie jest pusta
			IF EXISTS (SELECT 1 FROM dbo.tmp_wb_pod t WHERE t.pelna_nazwa NOT LIKE '%_%')
			BEGIN
				SET @elog_n = @elog_n + 'Pusta pelna_nazwa'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, t.pelna_nazwa
						FROM tmp_wb_pod t WHERE t.pelna_nazwa NOT LIKE '%_%'

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy poprawny regon
			IF EXISTS (SELECT 1 FROM dbo.tmp_wb_pod t WHERE t.regon NOT LIKE REPLICATE('[0-9]', 9))
			BEGIN
				SET @elog_n = @elog_n + 'Niepoprawny regon'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, t.regon
						FROM tmp_wb_pod t WHERE t.nip NOT LIKE REPLICATE('[0-9]', 9)

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy kod_kraju nie jest pusty
			IF EXISTS (SELECT 1 FROM dbo.tmp_wb_pod t WHERE t.kod_kraju NOT LIKE '%_%')
			BEGIN
				SET @elog_n = @elog_n + 'Pusty kod_kraju'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, t.kod_kraju
						FROM tmp_wb_pod t WHERE t.kod_kraju NOT LIKE '%_%'

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy wojewodztwo nie jest puste
			IF EXISTS (SELECT 1 FROM dbo.tmp_wb_pod t WHERE t.wojewodztwo NOT LIKE '%_%')
			BEGIN
				SET @elog_n = @elog_n + 'Puste wojewodztwo'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, t.wojewodztwo
						FROM tmp_wb_pod t WHERE t.wojewodztwo NOT LIKE '%_%'

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy powiat nie jest pusty
			IF EXISTS (SELECT 1 FROM dbo.tmp_wb_pod t WHERE t.powiat NOT LIKE '%_%')
			BEGIN
				SET @elog_n = @elog_n + 'Pusty powiat'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, t.powiat
						FROM tmp_wb_pod t WHERE t.powiat NOT LIKE '%_%'

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy gmina nie jest pusta
			IF EXISTS (SELECT 1 FROM dbo.tmp_wb_pod t WHERE t.gmina NOT LIKE '%_%')
			BEGIN
				SET @elog_n = @elog_n + 'Pusta gmina'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, t.gmina
						FROM tmp_wb_pod t WHERE t.gmina NOT LIKE '%_%'

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy ulica nie jest pusta
			IF EXISTS (SELECT 1 FROM dbo.tmp_wb_pod t WHERE t.ulica NOT LIKE '%_%')
			BEGIN
				SET @elog_n = @elog_n + 'Pusta ulica'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, t.ulica
						FROM tmp_wb_pod t WHERE t.ulica NOT LIKE '%_%'

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy nr_domu nie jest pusty
			IF EXISTS (SELECT 1 FROM dbo.tmp_wb_pod t WHERE t.nr_domu NOT LIKE '%_%')
			BEGIN
				SET @elog_n = @elog_n + 'Pusty numer domu'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, t.nr_domu
						FROM tmp_wb_pod t WHERE t.nr_domu NOT LIKE '%_%'

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy miejscowosc nie jest pusta
			IF EXISTS (SELECT 1 FROM dbo.tmp_wb_pod t WHERE t.miejscowosc NOT LIKE '%_%')
			BEGIN
				SET @elog_n = @elog_n + 'Pusta miejscowo��'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, t.miejscowosc
						FROM tmp_wb_pod t WHERE t.miejscowosc NOT LIKE '%_%'

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy poprawny kod_pocztowy
			IF EXISTS (SELECT 1 FROM dbo.tmp_wb_pod t
				WHERE t.kod_pocztowy NOT LIKE REPLICATE('[0-9]', 2) + '-' + REPLICATE('[0-9]', 3))
			BEGIN
				SET @elog_n = @elog_n + 'Niepoprawny kod pocztowy'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, t.kod_pocztowy
						FROM tmp_wb_pod t
						WHERE t.kod_pocztowy NOT LIKE REPLICATE('[0-9]', 2) + '-' + REPLICATE('[0-9]', 3)

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy poczta nie jest pusta
			IF EXISTS (SELECT 1 FROM dbo.tmp_wb_pod t WHERE t.poczta NOT LIKE '%_%')
			BEGIN
				SET @elog_n = @elog_n + 'Pusta poczta'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, t.poczta
						FROM tmp_wb_pod t WHERE t.poczta NOT LIKE '%_%'

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END
	GO

-- Utw�rz procedur� sprawdzaj�c� poprawno�� nag��wka wyci�gu bankowego
	EXEC dbo.create_empty_proc @proc_name = 'tmp_wb_na_check'
	GO

	ALTER PROCEDURE dbo.tmp_wb_na_check(@error int = 0 output)
	AS
		IF NOT (@error = 0)
		BEGIN
			RAISERROR(N'B�edy', 16, 3)
			RETURN -1
		END

		DECLARE @count int, @elog_n nvarchar(100), @id_en int
		SET @error = 0
		SET @elog_n = 'B��d w procedurze: tmp_wb_na_check / '

		-- Sprawd� czy jest dok�adnie 1 nag��wek wyci�gu bankowego
			SELECT @count = COUNT(*) FROM tmp_wb_na
			IF @count <> 1
			BEGIN
				SET @elog_n = @elog_n + 'Nie ma dok�adnie 1 nag��wka'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d) VALUES (@id_en, 'Nie 1 wiersz w tmp_wb_na')
				
				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy id nag��wk�w unikalne
			DECLARE @all_ids_count_na int, @unique_ids_count_na int
			SELECT @all_ids_count_na = COUNT(t.id_dokumentu) FROM tmp_wb_na t
			SELECT @unique_ids_count_na = COUNT(DISTINCT t.id_dokumentu) FROM tmp_wb_na t
			IF @all_ids_count_na <> @unique_ids_count_na
			BEGIN
				SET @elog_n = @elog_n + 'Id dokumentu nie s� unikalne / '
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)
				
				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d) VALUES (@id_en, 'Powtarza si� to samo id dokumentu')
				
				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy kod_formularza prawid�owy
			IF EXISTS (SELECT 1 FROM tmp_wb_na t WHERE t.kod_formularza NOT LIKE 'JPK_WB')
			BEGIN
				SET @elog_n = @elog_n + 'Kod formularza nie wskazuje na wyci�g bankowy / '
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)
				
				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d) VALUES (@id_en, 'Kod formularza r�ny od JPK_WB')
				
				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy kod_systemowy poprawny
			IF EXISTS (SELECT 1 FROM tmp_wb_na t WHERE t.kod_systemowy NOT LIKE 'JPK\_WB \([0-9]%\)' ESCAPE '\')
				BEGIN
					SET @elog_n = @elog_n + 'Kod systemowy niepoprawny'
					INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)
				
					SET @id_en = SCOPE_IDENTITY()
					INSERT INTO WB_ELOG_D(id_elog_n, opis_d) VALUES (@id_en, 'Kod systemowy r�ny od ''JPK\_WB \([0-9]%\)'' ESCAPE \')
				
					RAISERROR(@elog_n, 16, 4)
					SET @error = 1
					RETURN -1
				END

		-- Sprawd� czy wersja_schemy poprawna
			IF EXISTS (SELECT 1 FROM tmp_wb_na t WHERE t.wersja_schemy NOT LIKE '%[0-9]%-%[0-9]%')
				BEGIN
					SET @elog_n = @elog_n + 'Wersja schemy niepoprawna / '
					INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)
				
					SET @id_en = SCOPE_IDENTITY()
					INSERT INTO WB_ELOG_D(id_elog_n, opis_d) VALUES (@id_en, 'Wersja schemy r�na od %[0-9]%-%[0-9]%')
				
					RAISERROR(@elog_n, 16, 4)
					SET @error = 1
					RETURN -1
				END

		-- Sprawd� czy wariant_formularza poprawny
			IF EXISTS (SELECT 1 FROM tmp_wb_na t WHERE ISNUMERIC(t.wariant_formularza) <> 1)
				BEGIN
					SET @elog_n = @elog_n + 'Wariant formularza niepoprawny / '
					INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)
				
					SET @id_en = SCOPE_IDENTITY()
					INSERT INTO WB_ELOG_D(id_elog_n, opis_d) VALUES (@id_en, 'Wariant formularza nie jest liczb�')
				
					RAISERROR(@elog_n, 16, 4)
					SET @error = 1
					RETURN -1
				END

		-- Sprawd� czy cel_zlozenia poprawny
			IF EXISTS (SELECT 1 FROM tmp_wb_na t WHERE t.wariant_formularza NOT LIKE '1')
				BEGIN
					SET @elog_n = @elog_n + 'Cel z�o�enia niepoprawny / '
					INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)
				
					SET @id_en = SCOPE_IDENTITY()
					INSERT INTO WB_ELOG_D(id_elog_n, opis_d) VALUES (@id_en, 'Cel z�o�enia jest r�ny od 1')
				
					RAISERROR(@elog_n, 16, 4)
					SET @error = 1
					RETURN -1
				END

		-- Sprawd� czy data_wytworzenia_jpk nie jest w przysz�o�ci
			DECLARE @datetime_now nchar(20)
			SET @datetime_now = CONVERT(nchar(20), GETDATE(), 126)

			IF EXISTS (SELECT 1 FROM tmp_wb_na t WHERE t.data_wytworzenia_jpk >= @datetime_now)
			BEGIN
				SET @elog_n = @elog_n + 'Data wytworzenia JPK jest w przysz�o�ci'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, t.data_wytworzenia_jpk
						FROM tmp_wb_na t WHERE t.data_wytworzenia_jpk >= @datetime_now

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy data_do nie jest w przysz�o�ci
			DECLARE @date_now nchar(10)
			SET @date_now = CONVERT(nchar(10), GETDATE(), 102)

			IF EXISTS (
				SELECT 1 FROM tmp_wb_na t
				WHERE CONVERT(nchar(10), REPLACE(t.data_do, '-', '.'), 102) >= @date_now
			)
			BEGIN
				SET @elog_n = @elog_n + 'data_do jest w przysz�o�ci'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, t.data_do
						FROM tmp_wb_na t WHERE CONVERT(nchar(10), t.data_do, 102) >= @date_now

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy data_od nie jest p�niejsza ni� data_do
			IF EXISTS (SELECT 1 FROM tmp_wb_na t WHERE t.data_od > t.data_do)
			BEGIN
				SET @elog_n = @elog_n + 'data_od jest p�niej ni� data_do'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, t.data_od + ' ' + t.data_do
						FROM tmp_wb_na t WHERE t.data_wytworzenia_jpk >= @datetime_now

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy domyslny_kod_waluty jest prawid�owy
			IF EXISTS (SELECT 1 FROM tmp_wb_na t WHERE t.domyslny_kod_waluty NOT LIKE 'PLN')
			BEGIN
				SET @elog_n = @elog_n + 'Domy�lny kod waluty r�ny od PLN'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, t.domyslny_kod_waluty
						FROM tmp_wb_na t WHERE t.domyslny_kod_waluty NOT LIKE 'PLN'

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy kod_urzedu jest prawidlowy
			IF EXISTS (SELECT 1 FROM tmp_wb_na t WHERE t.kod_urzedu NOT LIKE REPLICATE('[0-9]', 4))
			BEGIN
				SET @elog_n = @elog_n + 'Kod urz�du nie jest 4-cyfrowy'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, t.kod_urzedu
						FROM tmp_wb_na t WHERE t.kod_urzedu NOT LIKE REPLICATE('[0-9]', 4)

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END
	GO

	-- Utw�rz procedur� sprawdzaj�c� poprawno�� pozycji wyci�gu bankowego
	EXEC dbo.create_empty_proc @proc_name = 'tmp_wb_poz_check'
	GO

	ALTER PROCEDURE dbo.tmp_wb_poz_check(@error int = 0 output)
	AS
		IF NOT (@error = 0)
		BEGIN
			RAISERROR(N'B�edy', 16, 3)
			RETURN -1
		END

		DECLARE @count int, @elog_n nvarchar(100), @id_en int
		SET @error = 0
		SET @elog_n = 'B��d w procedurze: tmp_wb_poz_check / '

		-- Sprawd� czy jest dok�adnie 1 wiersz
			SELECT @count = COUNT(*) FROM tmp_wb_poz
			IF @count <> 1
			BEGIN
				SET @elog_n = @elog_n + 'Nie ma dok�adnie 1 id_dokumentu'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d) VALUES (@id_en, 'Nie 1 wiersz w tmp_wb_poz')
				
				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy id_dokumentu unikalne
			DECLARE @all_ids_count_poz_dok int, @unique_ids_count_poz_dok int
			SELECT @all_ids_count_poz_dok = COUNT(t.id_dokumentu) FROM tmp_wb_poz t
			SELECT @unique_ids_count_poz_dok = COUNT(DISTINCT t.id_dokumentu) FROM tmp_wb_poz t
			IF @all_ids_count_poz_dok <> @unique_ids_count_poz_dok
			BEGIN
				SET @elog_n = @elog_n + 'Id dokumentu nie s� unikalne / '
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)
				
				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d) VALUES (@id_en, 'Powtarza si� to samo id dokumentu')
				
				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy ka�de id_dokumentu z tmp_wb_pod istnieje w tmp_wb_na
			DECLARE @wrong_id_dokumentu_count int
			SELECT @wrong_id_dokumentu_count = COUNT(*)
				FROM tmp_wb_poz p
				WHERE NOT EXISTS
				( SELECT 1
					FROM tmp_wb_na n
					WHERE p.id_dokumentu = n.id_dokumentu
				)

			IF @wrong_id_dokumentu_count > 0
			BEGIN
				SET @elog_n = @elog_n + 'Pozycja bez nag��wka'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT @id_en, p.id_dokumentu
					FROM tmp_wb_poz p
					WHERE NOT EXISTS
					( SELECT 1
						FROM tmp_wb_na n
						WHERE p.id_dokumentu = n.id_dokumentu
					)

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy ka�de id_dokumentu z tmp_wb_na istnieje w tmp_wb_poz
			SELECT @wrong_id_dokumentu_count = COUNT(*)
				FROM tmp_wb_na n
				WHERE NOT EXISTS
				( SELECT 1
					FROM tmp_wb_poz p
					WHERE p.id_dokumentu = n.id_dokumentu
				)

			IF @wrong_id_dokumentu_count > 0
			BEGIN
				SET @elog_n = @elog_n + 'Nag��wek bez pozycji'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT @id_en, n.id_dokumentu
					FROM tmp_wb_na n
					WHERE EXISTS
					( SELECT 1
						FROM tmp_wb_poz p
						WHERE p.id_dokumentu <> n.id_dokumentu
					)

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy ka�de id_podmiotu z tmp_wb_poz istnieje w tmp_wb_pod
			DECLARE @wrong_id_podmiotu_count int
			SELECT @wrong_id_podmiotu_count = COUNT(*)
				FROM tmp_wb_poz poz
				WHERE EXISTS
				( SELECT 1
					FROM tmp_wb_pod pod
					WHERE pod.id_podmiotu <> poz.id_podmiotu
				)

			IF @wrong_id_podmiotu_count > 0
			BEGIN
				SET @elog_n = @elog_n + 'Pozycja bez podmiotu'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT @id_en, poz.id_podmiotu
					FROM tmp_wb_poz poz
					WHERE NOT EXISTS
					( SELECT 1
						FROM tmp_wb_pod pod
						WHERE pod.id_podmiotu = poz.id_podmiotu
					)

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy numer_rachunku poprawny
			IF EXISTS (SELECT 1 FROM tmp_wb_poz t WHERE t.numer_rachunku NOT LIKE REPLICATE('[0-9]', 26))
			BEGIN
				SET @elog_n = @elog_n + 'Numer rachunku nie jest 26-cyfrowy'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, t.numer_rachunku
						FROM tmp_wb_poz t WHERE t.numer_rachunku NOT LIKE REPLICATE('[0-9]', 26)

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy saldo_poczatkowe jest kwot�
			IF EXISTS (SELECT 1 FROM tmp_wb_poz t WHERE TRY_CONVERT(MONEY, t.saldo_poczatkowe) IS NULL)
			BEGIN
				SET @elog_n = @elog_n + 'Saldo pocz�tkowe nie jest kwot�'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, t.saldo_poczatkowe
						FROM tmp_wb_poz t WHERE TRY_CONVERT(MONEY, t.saldo_poczatkowe) IS NULL

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy saldo_koncowe jest kwot�
			IF EXISTS (SELECT 1 FROM tmp_wb_poz t WHERE TRY_CONVERT(MONEY, t.saldo_koncowe) IS NULL)
			BEGIN
				SET @elog_n = @elog_n + 'Saldo ko�cowe nie jest kwot�'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, t.saldo_koncowe
						FROM tmp_wb_poz t WHERE TRY_CONVERT(MONEY, t.saldo_koncowe) IS NULL

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy liczba wierszy jest liczb� ca�kowit� wi�ksz� od 0
			IF EXISTS (
				SELECT 1 FROM tmp_wb_poz t
				WHERE ISNUMERIC(t.liczba_wierszy) <> 1 OR CAST(t.liczba_wierszy AS INT) < 1
			)
			BEGIN
				SET @elog_n = @elog_n + 'Liczba wierszy nie jest liczb� ca�kowit� wi�ksz� od 0'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, t.saldo_koncowe
						FROM tmp_wb_poz t
						WHERE ISNUMERIC(t.liczba_wierszy) <> 1 OR CAST(t.liczba_wierszy AS INT) < 1

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy suma_obciazen jest kwot�
			IF EXISTS (SELECT 1 FROM tmp_wb_poz t WHERE TRY_CONVERT(MONEY, t.suma_obciazen) IS NULL)
			BEGIN
				SET @elog_n = @elog_n + 'Suma obci��e� nie jest kwot�'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, t.suma_obciazen
						FROM tmp_wb_poz t WHERE TRY_CONVERT(MONEY, t.suma_obciazen) IS NULL

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy suma_uznan jest kwot�
			IF EXISTS (SELECT 1 FROM tmp_wb_poz t WHERE TRY_CONVERT(MONEY, t.suma_uznan) IS NULL)
			BEGIN
				SET @elog_n = @elog_n + 'Suma uzna� nie jest kwot�'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, t.suma_obciazen
						FROM tmp_wb_poz t WHERE TRY_CONVERT(MONEY, t.suma_uznan) IS NULL

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy saldo_koncowe jest prawid�owe
			IF EXISTS (
				SELECT 1 FROM tmp_wb_poz t
				WHERE CAST(REPLACE(t.saldo_koncowe, ',', '.') as MONEY)
					<> CAST(REPLACE(t.saldo_poczatkowe, ',', '.') AS MONEY)
						- CAST(REPLACE(t.suma_obciazen, ',', '.') AS MONEY)
						+ CAST(REPLACE(t.suma_uznan, ',', '.') AS MONEY)
			)
			BEGIN
				SET @elog_n = @elog_n + 'Saldo ko�cowe nie jest prawid�owe'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, t.suma_obciazen
						FROM tmp_wb_poz t
						WHERE CAST(REPLACE(t.saldo_koncowe, ',', '.') as MONEY)
							<> CAST(REPLACE(t.saldo_poczatkowe, ',', '.') AS MONEY)
								- CAST(REPLACE(t.suma_obciazen, ',', '.') AS MONEY)
								+ CAST(REPLACE(t.suma_uznan, ',', '.') AS MONEY)
				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END
	GO

	-- Utw�rz procedur� sprawdzaj�c� poprawno�� wierszy wyci�gu bankowego
	EXEC dbo.create_empty_proc @proc_name = 'tmp_wb_wiersz_check'
	GO

	ALTER PROCEDURE dbo.tmp_wb_wiersz_check(@error int = 0 output)
	AS
		IF NOT (@error = 0)
		BEGIN
			RAISERROR(N'B�edy', 16, 3)
			RETURN -1
		END

		DECLARE @count int, @elog_n nvarchar(100), @id_en int
		SET @error = 0
		SET @elog_n = 'B��d w procedurze: tmp_wb_wiersz_check / '

		-- Sprawd� czy ka�de id_dokumentu z tmp_wb_wiersz istnieje w tmp_wb_na
			DECLARE @wrong_id_dokumentu_count int
			SELECT @wrong_id_dokumentu_count = COUNT(*)
				FROM tmp_wb_wiersz w
				WHERE NOT EXISTS
				( SELECT 1
					FROM tmp_wb_na n
					WHERE w.id_dokumentu = n.id_dokumentu
				)
			SELECT @wrong_id_dokumentu_count

			IF @wrong_id_dokumentu_count > 0
			BEGIN
				SET @elog_n = @elog_n + 'Wiersz bez nag��wka'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT @id_en, w.id_dokumentu
					FROM tmp_wb_wiersz w
					WHERE NOT EXISTS
					( SELECT 1
						FROM tmp_wb_na n
						WHERE w.id_dokumentu = n.id_dokumentu
					)

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy liczba_wierszy z tmp_wb_poz jest r�wna liczbie wierszy z tmp_wb_wiersz
			IF NOT EXISTS(
				SELECT 1 FROM tmp_wb_poz p
				JOIN(
					SELECT id_dokumentu, COUNT(*) AS liczba_wierszy
					FROM tmp_wb_wiersz
					GROUP BY id_dokumentu
				) w ON w.id_dokumentu = p.id_dokumentu
				WHERE p.liczba_wierszy = w.liczba_wierszy
			)
			BEGIN
				SET @elog_n = @elog_n + 'Liczba wierszy z poz nie zgadza si� z liczb� wierszy z wiersz'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT @id_en, p.id_dokumentu
					FROM tmp_wb_poz p
					JOIN(
						SELECT id_dokumentu, COUNT(*) AS liczba_wierszy
						FROM tmp_wb_wiersz
						GROUP BY id_dokumentu
					) w ON w.id_dokumentu = p.id_dokumentu
					WHERE p.liczba_wierszy <> w.liczba_wierszy

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy data operacji jest dat�
			IF EXISTS(SELECT 1 FROM tmp_wb_wiersz w WHERE ISDATE(w.data_operacji) <> 1)
			BEGIN
				SET @elog_n = @elog_n + 'Niepoprawny format daty'
					INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

					SET @id_en = SCOPE_IDENTITY()
					INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
						SELECT DISTINCT @id_en, w.data_operacji
							FROM tmp_wb_wiersz w WHERE ISDATE(w.data_operacji) <> 1

					RAISERROR(@elog_n, 16, 4)
					SET @error = 1
					RETURN -1
			END

		-- Sprawd� czy nazwa_podmiotu nie jest pusta
			IF EXISTS (SELECT 1 FROM dbo.tmp_wb_wiersz w WHERE w.nazwa_podmiotu NOT LIKE '%_%')
			BEGIN
				SET @elog_n = @elog_n + 'Pusta nazwa_podmiotu'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, w.nazwa_podmiotu
						FROM tmp_wb_wiersz w WHERE w.nazwa_podmiotu NOT LIKE '%_%'

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy opis_operacji nie jest pusty
			IF EXISTS (SELECT 1 FROM dbo.tmp_wb_wiersz w WHERE w.opis_operacji NOT LIKE '%_%')
			BEGIN
				SET @elog_n = @elog_n + 'Pusty opis_operacji'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, w.nazwa_podmiotu
						FROM tmp_wb_wiersz w WHERE w.opis_operacji NOT LIKE '%_%'

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy kwota_operacji jest kwot�
			IF EXISTS (SELECT 1 FROM tmp_wb_wiersz w WHERE TRY_CONVERT(MONEY, w.kwota_operacji) IS NULL)
			BEGIN
				SET @elog_n = @elog_n + 'Kwota operacji nie jest kwot�'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, w.kwota_operacji
						FROM tmp_wb_wiersz w WHERE TRY_CONVERT(MONEY, w.kwota_operacji) IS NULL

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy saldo_operacji jest kwot�
			IF EXISTS (SELECT 1 FROM tmp_wb_wiersz w WHERE TRY_CONVERT(MONEY, w.saldo_operacji) IS NULL)
			BEGIN
				SET @elog_n = @elog_n + 'Saldo operacji nie jest kwot�'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, w.saldo_operacji
						FROM tmp_wb_wiersz w WHERE TRY_CONVERT(MONEY, w.saldo_operacji) IS NULL

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy kwota_operacji odpowiada saldo_operacji
			IF EXISTS (
				SELECT 1 FROM tmp_wb_wiersz w
				WHERE CAST(w.kwota_operacji AS MONEY) <> ABS(CAST(w.saldo_operacji AS MONEY))
			)
			BEGIN
				SET @elog_n = @elog_n + 'Saldo operacji nie odpowiada kwocie'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, w.saldo_operacji + ' ' + w.kwota_operacji
						FROM tmp_wb_wiersz w
						WHERE CAST(w.kwota_operacji AS MONEY) <> ABS(CAST(w.saldo_operacji AS MONEY))

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END

		-- Sprawd� czy r�nica kwot z tmp_wb_poz odpowiada sumie kwot z tmp_wb_wiersz
			IF EXISTS (
				SELECT 1
				FROM(
					SELECT id_dokumentu,
						SUM(CAST(REPLACE(saldo_koncowe, ',', '.') AS MONEY)
							- CAST(REPLACE(saldo_poczatkowe, ',', '.') AS MONEY))
							AS roznica_operacji
					FROM tmp_wb_poz
					GROUP BY id_dokumentu
				) AS p
				JOIN (
					SELECT id_dokumentu,
						SUM(CAST(REPLACE(saldo_operacji, ',', '.') AS MONEY)) AS suma_operacji
					FROM tmp_wb_wiersz
					GROUP BY id_dokumentu
				) w ON w.id_dokumentu = p.id_dokumentu
				WHERE p.roznica_operacji <> w.suma_operacji
			)
			BEGIN
				SET @elog_n = @elog_n + 'R�nica kwot z tmp_wb_poz odpowiada sumie kwot z tmp_wb_wiersz'
				INSERT INTO WB_ELOG_N(opis_n) VALUES (@elog_n)

				SET @id_en = SCOPE_IDENTITY()
				INSERT INTO WB_ELOG_D(id_elog_n, opis_d)
					SELECT DISTINCT @id_en, p.roznica_operacji + ' ' + w.suma_operacji
					FROM(
						SELECT id_dokumentu,
							SUM(CAST(REPLACE(saldo_koncowe, ',', '.') AS MONEY)
								- CAST(REPLACE(saldo_poczatkowe, ',', '.') AS MONEY))
								AS roznica_operacji
						FROM tmp_wb_poz
						GROUP BY id_dokumentu
					) AS p
					JOIN (
						SELECT id_dokumentu,
							SUM(CAST(REPLACE(saldo_operacji, ',', '.') AS MONEY)) AS suma_operacji
						FROM tmp_wb_wiersz
						GROUP BY id_dokumentu
					) w ON w.id_dokumentu = p.id_dokumentu
					WHERE p.roznica_operacji <> w.suma_operacji

				RAISERROR(@elog_n, 16, 4)
				SET @error = 1
				RETURN -1
			END
	GO

	-- Utw�rz procedur� dodaj�c� dane z tabel tymczasowych do docelowych
	EXEC dbo.create_empty_proc @proc_name = 'wb_move_data'
	GO

	ALTER PROCEDURE dbo.wb_move_data(@error int = 0 output)
	AS
		IF NOT (@error = 0)
		BEGIN
			RAISERROR(N'B�edy', 16, 3)
			RETURN -1
		END

		-- Wyczy�� tabele docelowe
			DELETE FROM WB_WIERSZ
			DELETE FROM WB_POZYCJA
			DELETE FROM WB_NAGLOWEK
			DELETE FROM WB_PODMIOT
	
		-- Dodaj dane do tabeli docelowych
			SET XACT_ABORT ON
			BEGIN TRANSACTION [dodaj_do_docelowej]
				BEGIN TRY
					-- Dodaj nowe dane do tabeli WB_PODMIOT
						SET IDENTITY_INSERT WB_PODMIOT ON;
						INSERT INTO WB_PODMIOT(
							id_podmiotu, nip, pelna_nazwa,
							regon, kod_kraju, wojewodztwo,
							powiat, gmina, ulica,
							nr_domu, nr_lokalu, miejscowosc,
							kod_pocztowy, poczta
						)
						SELECT
							CAST(p.id_podmiotu as int), p.nip, p.pelna_nazwa,
							p.regon, p.kod_kraju, p.wojewodztwo,
							p.powiat, p.gmina, p.ulica,
							p.nr_domu, p.nr_lokalu, p.miejscowosc,
							p.kod_pocztowy, p.poczta
						FROM tmp_wb_pod p
						WHERE NOT EXISTS
						( SELECT *
							FROM WB_PODMIOT pW
							WHERE p.id_podmiotu = pW.id_podmiotu
						)
						SET IDENTITY_INSERT WB_PODMIOT OFF;
					
					-- Dodaj dane do tabeli WB_NAGLOWEK
						SET IDENTITY_INSERT WB_NAGLOWEK ON;
					
						INSERT INTO WB_NAGLOWEK
						(
							id_dokumentu, kod_formularza, kod_systemowy,
							wersja_schemy, wariant_formularza, cel_zlozenia,
							data_wytworzenia_jpk, data_od, data_do,
							domyslny_kod_waluty, kod_urzedu
						)
						SELECT
							CAST(n.id_dokumentu AS INT), N.kod_formularza, N.kod_systemowy,
							n.wersja_schemy, CAST(n.wariant_formularza AS tinyint), CAST(n.cel_zlozenia AS tinyint),
							dbo.text_to_datetime(n.data_wytworzenia_jpk), dbo.text_to_date(n.data_od), dbo.text_to_date(n.data_do),
							n.domyslny_kod_waluty,	n.kod_urzedu
						FROM tmp_wb_na n
						SET IDENTITY_INSERT WB_NAGLOWEK OFF;

					-- Dodaj dane do tabeli WB_POZYCJA
						INSERT INTO WB_POZYCJA
						(
							id_dokumentu, id_podmiotu, numer_rachunku,
							saldo_poczatkowe, saldo_koncowe, liczba_wierszy,
							suma_obciazen, suma_uznan	
						)
						SELECT
							CAST(poz.id_dokumentu AS int), CAST(poz.id_podmiotu AS int), poz.numer_rachunku,
							dbo.text_to_money(poz.saldo_poczatkowe), dbo.text_to_money(poz.saldo_koncowe), CAST(poz.liczba_wierszy AS int),
							dbo.text_to_money(poz.suma_obciazen), dbo.text_to_money(suma_uznan)
						FROM tmp_wb_poz poz
						JOIN WB_NAGLOWEK n ON (n.id_dokumentu = poz.id_dokumentu)
						JOIN WB_PODMIOT pod ON (pod.id_podmiotu = poz.id_podmiotu)

					-- Dodaj dane do tabeli WB_WIERSZ
						INSERT INTO WB_WIERSZ
						(
							id_dokumentu, numer_wiersza, 
							data_operacji, nazwa_podmiotu, opis_operacji,
							kwota_operacji,saldo_operacji	
						)
						SELECT
							CAST(w.id_dokumentu AS int), CAST(w.numer_wiersza AS int),
							dbo.text_to_date(w.data_operacji), w.nazwa_podmiotu, w.opis_operacji,
							dbo.text_to_money(w.kwota_operacji), dbo.text_to_money(w.saldo_operacji)
							FROM tmp_wb_wiersz w
							JOIN WB_NAGLOWEK n ON (n.id_dokumentu = w.id_dokumentu)

						COMMIT TRANSACTION [dodaj_do_docelowej]
				END TRY
				BEGIN CATCH
					ROLLBACK TRANSACTION [dodaj_do_docelowej]
					RAISERROR('Nie uda�o si� doda� do tabeli docelowej', 16, 4)
				END CATCH
	GO

	-- jak napis pusty a musi by� w XML NULL
	EXEC dbo.create_empty_fun @fun_name = 'SAFT_NULL', @type='nvarchar(250)'
	GO

	ALTER FUNCTION dbo.SAFT_NULL(@msg nvarchar(250) )
	RETURNS nvarchar(250)
	AS
	BEGIN
		IF @msg IS NULL OR RTRIM(@msg)=N''
			RETURN NULL
		RETURN @msg
	END
	GO

-- prawda/falsz w zaleznosci czy 0
	EXEC dbo.create_empty_fun @fun_name='SAFT_TRUE_FALSE', @type='nvarchar(6)'
	GO

	ALTER FUNCTION dbo.SAFT_TRUE_FALSE(@msg nvarchar(20) )
	RETURNS nvarchar(6)
	AS
	BEGIN
		IF (@msg IS NULL)
			RETURN N'false'
		RETURN N'true'
	END
	GO

-- format daty dopuszczalny w plikach JPK
	EXEC dbo.create_empty_fun @fun_name = 'SAFT_DATE', @type='nchar(10)'
	GO

	ALTER FUNCTION dbo.SAFT_DATE(@d date )
	RETURNS nchar(10)
	AS
	BEGIN
		RETURN REPLACE(CONVERT(nchar(10), @d, 102), '.', '-')
	END
	GO

-- format daty z czasem dopuszczalny w plikach JPK
	EXEC dbo.create_empty_fun @fun_name = 'SAFT_DATETIME', @type='nchar(10)'
	GO

	ALTER FUNCTION dbo.SAFT_DATETIME(@d datetime )
	RETURNS nchar(10)
	AS
	BEGIN
		RETURN CONVERT(nchar(10), @d, 120)
	END
	GO

-- format kwotowy dopuszczalny w XML
	EXEC dbo.create_empty_fun @fun_name = 'SAFT_GET_AMT', @type='nvarchar(20)'
	GO

	ALTER FUNCTION dbo.SAFT_GET_AMT(@amt money )
	RETURNS nvarchar(20)
	AS
	BEGIN
		IF @amt IS NULL
			RETURN N''
		RETURN RTRIM(LTRIM(STR(@amt,18,2)))
	END
	GO

-- Utw�rz procedur� generuj�c� raport xml
	EXEC dbo.create_empty_proc @proc_name = 'generuj_raport'
	GO

	ALTER PROCEDURE dbo.generuj_raport
	(
		@xml	xml = null out,
		@curr_code nchar(3) = N'PLN'
	)
	AS
		SET @xml = '';
		;WITH XMLNAMESPACES
		(
			N'http://jpk.mf.gov.pl/wzor/2016/03/09/03092/' AS tns,
			N'http://crd.gov.pl/xml/schematy/dziedzinowe/mf/2016/01/25/eD/DefinicjeTypy/' AS etd
		)
		SELECT @xml = (
			SELECT
			(
				SELECT
					n.kod_formularza AS [tns:KodFormularza],
					n.kod_systemowy AS [tns:WariantFormularza],
					n.cel_zlozenia AS [tns:CelZlozenia],
					dbo.SAFT_DATETIME(n.data_wytworzenia_jpk) AS [tns:DataWytworzeniaJPK],
					dbo.SAFT_DATE(n.data_od) AS [tns:DataOd],
					dbo.SAFT_DATE(n.data_do) AS [tns:DataDo],
					n.domyslny_kod_waluty AS [tns:DomyslnyKodWaluty],
					n.kod_urzedu AS [tns:KodUrzedu]
				FOR XML PATH('tns:Naglowek'), TYPE
			),
			(
				SELECT
				(
					SELECT
						pod.nip AS [etd:NIP],
						pod.pelna_nazwa AS [etd:PelnaNazwa],
						pod.regon AS [etd:REGON]
					FOR XML PATH('tns:IdentyfikatorPodmiotu'), TYPE
				),
				(
					SELECT
						pod.kod_kraju AS [etd:KodKraju],
						pod.wojewodztwo AS [etd:Wojewodztwo],
						pod.powiat AS [etd:Powiat],
						pod.gmina AS [etd:Gmina],
						pod.ulica AS [etd:Ulica],
						pod.nr_domu AS [etd:NrDomu],
						pod.nr_lokalu AS [etd:NrLokalu],
						pod.miejscowosc AS [etd:Miejscowosc],
						pod.kod_pocztowy AS [etd:KodPocztowy],
						pod.powiat AS [etd:Poczta]
					FOR XML PATH('tns:AdresPodmiotu'), TYPE
				) 
				FOR XML PATH('tns:Podmiot1'),  TYPE
			),
			poz.numer_rachunku AS [tns:NumerRachunku]	
			,
			(
				SELECT
					dbo.SAFT_GET_AMT(poz.saldo_poczatkowe) as [tns:SaldoPoczatkowe],
					dbo.SAFT_GET_AMT(poz.saldo_koncowe) as [tns:SaldoKoncowe]
				FOR XML PATH('tns:Salda'), TYPE
			),
			(
				SELECT
					w.numer_wiersza AS [tns:NumerWiersza],
					dbo.SAFT_DATE(w.data_operacji) AS [tns:DataOperacji],
					w.nazwa_podmiotu AS [tns:NazwaPodmiotu],
					w.opis_operacji AS [tns:OpisOperacji],
					dbo.SAFT_GET_AMT(w.kwota_operacji) AS [tns:KwotaOperacji],
					dbo.SAFT_GET_AMT(w.saldo_operacji) AS [tns:SaldoOperacji]
				FROM WB_WIERSZ w
				JOIN WB_NAGLOWEK ON (w.id_dokumentu = n.id_dokumentu)
				FOR XML PATH('tns:WyciagWiersz'), TYPE
			),
			(
				SELECT
					poz.liczba_wierszy AS [tns:LiczbaWierszy],
					dbo.SAFT_GET_AMT(poz.suma_obciazen) AS [tns:SumaObciazen],
					dbo.SAFT_GET_AMT(poz.suma_uznan) AS [tns:SumaUznan]
				FOR XML PATH('tns:WyciagCtrl'), TYPE
			)
			FOR XML PATH('tns:JPK'), TYPE
		)
		FROM WB_POZYCJA poz
		JOIN WB_NAGLOWEK n ON (n.id_dokumentu = poz.id_dokumentu)
		JOIN WB_PODMIOT pod ON (pod.id_podmiotu = poz.id_podmiotu)

		SELECT @xml
	GO

EXEC dbo.generuj_raport

			