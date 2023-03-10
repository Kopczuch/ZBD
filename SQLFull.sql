--Procedura wstawiajaca nowa gre do tabeli gry i nastepnie wstawiajaca id i nazwe gracza do odpowiedniej tabeli (albo gracze_gry albo graczezawodowi_gry)
CREATE PROCEDURE wstaw_gre (
@gracz VARCHAR(20),
@pro CHAR(1),
@rezultat VARCHAR(4),
@zabojstwa SMALLINT,
@smierci SMALLINT,
@asysty SMALLINT,
@creep_score SMALLINT,
@zdobyte_zloto INT,
@czas_gry TIME(0),
@zadane_obrazenia INT,
@strona VARCHAR(4),
@zabojstwa_druzyny SMALLINT = NULL,
@zgony_druzyny SMALLINT = NULL,
@bohater VARCHAR(20))
AS
BEGIN
    DECLARE @id INT;
    INSERT INTO gry (rezultat, zabojstwa, smierci, asysty, creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia, zabojstwa_druzyny, zgony_druzyny, strona, bohaterowie_nazwa)
    VALUES (@rezultat, @zabojstwa, @smierci, @asysty, @creep_score, @zdobyte_zloto, @czas_gry, @zabojstwa, @zabojstwa, @zgony_druzyny, @strona, @bohater);
    SET @id = SCOPE_IDENTITY();

	IF @pro = 'T'
	BEGIN
		INSERT INTO graczezawodowi_gry (gry_id_meczu, gracze_zawodowi_nick)
		VALUES (@id, @gracz);
	END;
	IF @pro = 'N'
	BEGIN
		INSERT INTO gracze_gry (gry_id_meczu, gracze_nick)
		VALUES (@id, @gracz);
	END;
END;
GO
--Przykladowe wywolania
--EXEC wstaw_gre 'Sloik', 'N', 'WIN', 69, 69, 69, 420, 1000, '00:21:37', 12345, 'BLUE';
--EXEC wstaw_gre 'Jankos', 'T', 'WIN', 69, 69, 69, 420, 1000, '00:21:37', 12345, 'BLUE';


CREATE PROCEDURE register(
@nick VARCHAR(20),
@haslo VARCHAR(100),
@dywizja VARCHAR(15),
@poziom SMALLINT,
@ulubiony_bohater VARCHAR(20))
AS
BEGIN
	INSERT INTO gracze(nick, dywizja, poziom, ulubiony_bohater) VALUES (@nick, @dywizja, @poziom, @ulubiony_bohater);
	INSERT INTO dane_logowania(nick, haslo, rola) VALUES (@nick, @haslo, 'User');
END;
GO

-------------------------------------------------------------------------------------------------------------------

-- Procedura znajdujaca komponenty danego przedmiotu (wszystkie)
CREATE PROCEDURE znajdz_komponenty (@id_przed INT)
AS
BEGIN
WITH ItemComponents AS (
SELECT k.id, p.id_przed, p.nazwa, 0 as [Level]
FROM przedmioty p
JOIN komponenty_przedmiotow k ON p.id_przed = k.id_komponentu
WHERE k.id_przed = @id_przed

UNION ALL

SELECT k.id, p.id_przed, p.nazwa, [Level] + 1
FROM przedmioty p
JOIN komponenty_przedmiotow k ON p.id_przed = k.id_komponentu
JOIN ItemComponents c ON k.id_przed = c.id_przed
)
SELECT id, id_przed, nazwa, [Level]
FROM ItemComponents;
END;
GO

--Przykladowe wywolanie
--EXEC znajdz_komponenty 3078;

-------------------------------------------------------------------------------------------------------------------

-- Procedura znajdujaca komponenty danego przedmiotu (tylko te z kt??rych dany przedmiot bezpo??rednio si?? sk??ada)
CREATE PROCEDURE znajdz_komponenty2(@id_przed INT)
AS
BEGIN
	SELECT id_przed, nazwa, ikona
	FROM przedmioty p
	WHERE id_przed IN (SELECT id_komponentu FROM komponenty_przedmiotow kp WHERE kp.id_przed = @id_przed) 
END;
GO
--Przykladowe wywolanie
--EXEC znajdz_komponenty2 3078;

-------------------------------------------------------------------------------------------------------------------

-- Procedura znajdujaca przedmioty zakupione w grze o podanym id
CREATE PROCEDURE znajdz_zakupione_przedmioty(@id_meczu INT)
AS
BEGIN
SELECT id_przed, nazwa, ikona
FROM przedmioty INNER JOIN gry_zakupioneprzedmioty ON id_zakupionego_przedmiotu = id_przed
WHERE id_meczu = @id_meczu;
END;
GO
--Przykladowe wywolanie
--EXEC znajdz_zakupione_przedmioty 123;

-------------------------------------------------------------------------------------------------------------------

--Procedura zwracajaca zawodnikow danej druzyny
CREATE PROCEDURE znajdz_graczy_druzyny(@p_team_id VARCHAR(6))
AS
BEGIN
SET NOCOUNT ON;
    SELECT nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny, ulubiony_bohater
    FROM gracze_zawodowi
    WHERE id_druzyny = @p_team_id
     ORDER BY
            CASE
                WHEN rola = 'Top Laner' THEN 1
                WHEN rola = 'Jungler'   THEN 2
                WHEN rola = 'Mid Laner' THEN 3
                WHEN rola = 'Bot Laner' THEN 4
                ELSE 5
            END;
END;
GO
-------------------------------------------------------------------------------------------------------------------

-- Funkcja obliczajaca procent wygranych gracza o podanym nicku

CREATE FUNCTION win_rate (@pNick VARCHAR(20), @pro CHAR(1))
RETURNS FLOAT AS
BEGIN
    DECLARE @vWinRate FLOAT;
    DECLARE @vWins FLOAT = 0;
    DECLARE @vLoses FLOAT = 0;
    DECLARE @vGames FLOAT = 0;
    DECLARE @vGame_rezultat VARCHAR(200);
    
	IF @pro = 'T'
	BEGIN
		SELECT @vWins = SUM(CASE WHEN rezultat = 'WIN' THEN 1 ELSE 0 END)
		FROM graczezawodowi_gry g
		INNER JOIN gry m ON g.gry_id_meczu = m.id_meczu
		WHERE gracze_zawodowi_nick = @pNick;
    
		SET @vLoses = (SELECT COUNT(*) 
					   FROM graczezawodowi_gry g 
					   INNER JOIN gry m ON g.gry_id_meczu = m.id_meczu 
					   WHERE gracze_zawodowi_nick = @pNick) - @vWins;
	END
	ELSE
	BEGIN
		SELECT @vWins = SUM(CASE WHEN rezultat = 'WIN' THEN 1 ELSE 0 END)
		FROM gracze_gry g
		INNER JOIN gry m ON g.gry_id_meczu = m.id_meczu
		WHERE gracze_nick = @pNick;
    
		SET @vLoses = (SELECT COUNT(*) 
					   FROM gracze_gry g 
					   INNER JOIN gry m ON g.gry_id_meczu = m.id_meczu 
					   WHERE gracze_nick = @pNick) - @vWins;
	END;

	SET @vGames = @vWins + @vLoses;
		
	IF @vGames > 0
	BEGIN
		SET @vWinRate = @vWins / @vGames * 100;
	END
	ELSE
	BEGIN
		SET @vWinRate = 0;
	END;
    
    RETURN @vWinRate;
END;
GO
-- Przykladowe wywolania:
--SELECT dbo.win_rate('Sloik', 'N')
--SELECT dbo.win_rate('Jankos', 'T')

-------------------------------------------------------------------------------------------------------------------

-- Funckja obliczajaca KDA dla gry o podanym ID

CREATE FUNCTION KDA (@id_meczu INT)
RETURNS FLOAT
AS
BEGIN
    DECLARE @vK INT;
    DECLARE @vD INT;
    DECLARE @vA INT;
	DECLARE @vKDA FLOAT;

    SELECT @vK = zabojstwa, @vD = smierci, @vA = asysty
    FROM Gry
    WHERE id_meczu = @id_meczu;

	IF @vD > 0
	BEGIN
		SET @vKda = ROUND(CAST((@vK + @vA) AS FLOAT) / CAST(@vD AS FLOAT),2)
	END
	ELSE
	BEGIN
		SET @vKda = (@vK + @vA)
	END;

    RETURN @vKda;
END;
GO
--Przykladowe wywolanie
--SELECT dbo.KDA(123)

-------------------------------------------------------------------------------------------------------------------

-- Funckja obliczajaca srednie KDA dla gracza o podanym nicku

CREATE FUNCTION srednie_KDA(@pNick VARCHAR(20), @pro CHAR(1))
RETURNS FLOAT AS
BEGIN
	DECLARE @vSrednieKDA FLOAT;

	IF @pro = 'T'
	BEGIN
		SELECT @vSrednieKDA = ROUND((CAST((SUM(zabojstwa) + SUM(asysty)) AS FLOAT)) / CAST(SUM(smierci) AS FLOAT),2)
		FROM gry WHERE id_meczu IN (SELECT gry_id_meczu FROM graczezawodowi_gry WHERE gracze_zawodowi_nick = @pNick);
	END
	ELSE
	BEGIN 
		SELECT @vSrednieKDA = ROUND((CAST((SUM(zabojstwa) + SUM(asysty)) AS FLOAT)) / CAST(SUM(smierci) AS FLOAT),2)
		FROM gry WHERE id_meczu IN (SELECT gry_id_meczu FROM gracze_gry WHERE gracze_nick = @pNick);
	END;

	RETURN @vSrednieKDA;
END;
GO
--Przykladowe wywolanie
--SELECT dbo.srednie_KDA('Jankos', 'T')
--SELECT dbo.srednie_KDA('Quavenox', 'N')

-------------------------------------------------------------------------------------------------------------------

-- Procedura zwracajaca 3 najczesciej rozgrywanych bohaterow danego gracza

CREATE PROCEDURE top3_rozgrywani_bohaterowie(@pNick VARCHAR(20), @pro CHAR(1))
AS
BEGIN
	IF @pro = 'T'
	BEGIN
		SELECT TOP 3 bohaterowie_nazwa
		FROM gry
		WHERE id_meczu IN (SELECT gry_id_meczu FROM graczezawodowi_gry WHERE gracze_zawodowi_nick = @pNick)
		GROUP BY bohaterowie_nazwa
		ORDER BY COUNT(*) DESC;
	END
	ELSE
	BEGIN
		SELECT TOP 3 bohaterowie_nazwa
		FROM gry
		WHERE id_meczu IN (SELECT gry_id_meczu FROM gracze_gry WHERE gracze_nick = @pNick)
		GROUP BY bohaterowie_nazwa
		ORDER BY COUNT(*) DESC;
	END;
END;
GO
--Przykladowe wywolanie
--EXEC top3_rozgrywani_bohaterowie 'Jankos', 'T'
--EXEC top3_rozgrywani_bohaterowie 'Quavenox', 'N'

-------------------------------------------------------------------------------------------------------------------

-- Procedura zwracajaca najczesciej rozgrywanego bohatera danego gracza

CREATE PROCEDURE top1_rozgrywani_bohaterowie(@pNick VARCHAR(20), @pro CHAR(1))
AS
BEGIN
	IF @pro = 'T'
	BEGIN
		SELECT TOP 1 bohaterowie_nazwa
		FROM gry
		WHERE id_meczu IN (SELECT gry_id_meczu FROM graczezawodowi_gry WHERE gracze_zawodowi_nick = @pNick)
		GROUP BY bohaterowie_nazwa
		ORDER BY COUNT(*) DESC;
	END
	ELSE
	BEGIN
		SELECT TOP 1 bohaterowie_nazwa
		FROM gry
		WHERE id_meczu IN (SELECT gry_id_meczu FROM gracze_gry WHERE gracze_nick = @pNick)
		GROUP BY bohaterowie_nazwa
		ORDER BY COUNT(*) DESC;
	END;
END;
GO
--Przykladowe wywolanie
--EXEC top1_rozgrywani_bohaterowie 'Jankos', 'T'
--EXEC top1_rozgrywani_bohaterowie 'Quavenox', 'N'

-------------------------------------------------------------------------------------------------------------------

--Procedura zwracjaca wszystkie turnieje w ktorych brala udzial druzynya o podanym id

CREATE PROCEDURE turnieje_druzyny(@pId VARCHAR(6))
AS
BEGIN
	SELECT *
	FROM turnieje
	WHERE id_druzyny = @pId;
END;
GO
--Przykladowe wywolanie
--EXEC turnieje_druzyny 'AST'

-------------------------------------------------------------------------------------------------------------------

--Procedura dodaj??ca przedmiot o podanej nazwie do danego meczu
CREATE PROCEDURE dodaj_przedmiot_do_gry (@pIdMeczu BIGINT, @pNazwaPrzedmiotu CHAR(100))
AS
BEGIN
DECLARE @idPrzed INT;
DECLARE @liczbaPrzed INT;

SELECT @idPrzed = id_przed
FROM przedmioty
WHERE nazwa = @pNazwaPrzedmiotu;

IF @idPrzed IS NOT NULL
BEGIN
	SELECT @liczbaPrzed = COUNT(*)
	FROM gry_zakupioneprzedmioty
	WHERE id_meczu = @pIdMeczu;
	IF @liczbaPrzed < 6
	BEGIN
		INSERT INTO gry_zakupioneprzedmioty(id_meczu, id_zakupionego_przedmiotu)
		VALUES (@pIdMeczu, @idPrzed);
	END;
END;
END;
GO
--Przykladowe wywolanie
--EXEC dodaj_przedmiot_do_gry 201, 'Z??odziej Esencji';

CREATE TABLE bohaterowie (
    nazwa       VARCHAR(20) NOT NULL,
    tytu??       VARCHAR(30) NOT NULL,
    krotki_opis VARCHAR(max) NOT NULL,
    atak        SMALLINT NOT NULL CHECK(atak BETWEEN 0 AND 10),
    obrona      SMALLINT NOT NULL CHECK(obrona BETWEEN 0 AND 10), 
    magia       SMALLINT NOT NULL CHECK(magia BETWEEN 0 AND 10),
    trudnosc    SMALLINT NOT NULL CHECK(trudnosc BETWEEN 0 AND 10),
    obraz       VARCHAR(max) NOT NULL,
	ikona		VARCHAR(max) NOT NULL,
    klasa       VARCHAR(20) NOT NULL CHECK(klasa IN ('Assassin', 'Fighter', 'Mage', 'Marksman', 'Support', 'Tank'))
);

CREATE INDEX bohaterowie__idx ON
    bohaterowie (
        nazwa
    ASC );

ALTER TABLE bohaterowie ADD CONSTRAINT bohaterowie_pk PRIMARY KEY ( nazwa );

CREATE TABLE dane_logowania (
    nick                        VARCHAR(20) NOT NULL,
    haslo                       VARCHAR(100) NOT NULL,
    rola 						VARCHAR(30) NOT NULL
);

ALTER TABLE dane_logowania ADD CONSTRAINT dane_logowania_pk PRIMARY KEY ( nick );

CREATE TABLE druzyny (
    id_druzyny         VARCHAR(6) NOT NULL,
    nazwa              VARCHAR(50) NOT NULL,
	opis			   VARCHAR(max) NOT NULL,
    liga             VARCHAR(20) NOT NULL CHECK (liga IN ('LCK', 'LPL', 'LCS', 'LEC', 'PCS', 'VCS', 'CBLOL', 'LJL', 'LLA')),
    logo               VARCHAR(max) NOT NULL,
    zdjecie_zawodnikow VARCHAR(max)
);

ALTER TABLE druzyny ADD CONSTRAINT druzyny_pk PRIMARY KEY ( id_druzyny );

CREATE TABLE gracze (
    nick             VARCHAR(20) NOT NULL,
    dywizja          VARCHAR(15) NOT NULL CHECK (dywizja IN ('Challenger','Grand Master','Master',
	'Diamond I','Diamond II','Diamond III','Diamond IV','Platinum I','Platinum II','Platinum III',
		'Platinum IV','Gold I','Gold II','Gold III','Gold IV','Silver I','Silver II','Silver III',
		'Silver IV','Bronze I','Bronze II','Bronze III','Bronze IV','Iron I','Iron II','Iron III',
		'Iron IV','Unranked')),
    poziom           SMALLINT NOT NULL CHECK(poziom > 0),
    ulubiony_bohater VARCHAR(20)
);

ALTER TABLE gracze ADD CONSTRAINT gracze_pk PRIMARY KEY ( nick );

CREATE TABLE gracze_gry (
    gracze_nick  VARCHAR(20) NOT NULL,
    gry_id_meczu BIGINT NOT NULL
);

ALTER TABLE gracze_gry ADD CONSTRAINT gracze_gry_pk PRIMARY KEY ( gracze_nick,
                                                                  gry_id_meczu );

CREATE TABLE gracze_zawodowi (
    nick             VARCHAR(20) NOT NULL,
    imie_i_nazwisko  VARCHAR(50) NOT NULL,
    kraj             VARCHAR(30) NOT NULL,
    rola             VARCHAR(9) NOT NULL CHECK (rola IN ('Top Laner', 'Support', 'Jungler', 'Mid Laner', 'Bot Laner')),
    rezydencja       VARCHAR(20) NOT NULL CHECK (rezydencja IN ('North America', 'EMEA', 'Europe', 'Turkey', 'CIS', 'Korea
', 'China', 'PCS', 'Brazil', 'Japan', 'Latin America', 'Oceania', 'Vietnam')),
    zdjecie          VARCHAR(max),
    data_urodzin     DATETIME2(0),
    id_druzyny       VARCHAR(6),
    ulubiony_bohater VARCHAR(20)
);

CREATE INDEX gracze_zawodowi__idx ON
    gracze_zawodowi (
        nick
    ASC );

ALTER TABLE gracze_zawodowi ADD CONSTRAINT gracze_zawodowi_pk PRIMARY KEY ( nick );

CREATE TABLE graczezawodowi_gry (
    gracze_zawodowi_nick VARCHAR(20) NOT NULL,
    gry_id_meczu         BIGINT NOT NULL
);

ALTER TABLE graczezawodowi_gry ADD CONSTRAINT graczezawodowi_gry_pk PRIMARY KEY ( gracze_zawodowi_nick,
                                                                                  gry_id_meczu );

CREATE TABLE gry (
    id_meczu          BIGINT NOT NULL IDENTITY,
    rezultat          VARCHAR(4) NOT NULL CHECK (rezultat IN ('WIN', 'LOSE')),
    zabojstwa         SMALLINT NOT NULL CHECK (zabojstwa >= 0),
    smierci           SMALLINT NOT NULL CHECK (smierci >= 0),
    asysty            SMALLINT NOT NULL CHECK (asysty >= 0),
    creep_score       SMALLINT NOT NULL CHECK (creep_score >= 0),
    zdobyte_zloto     INT NOT NULL CHECK (zdobyte_zloto >= 0),
    czas_gry          TIME(0) NOT NULL,
    zadane_obrazenia  INT NOT NULL CHECK (zadane_obrazenia >= 0),
    zabojstwa_druzyny SMALLINT CHECK (zabojstwa_druzyny >= 0),
    zgony_druzyny     SMALLINT CHECK (zgony_druzyny >= 0),
    strona            VARCHAR(4) NOT NULL CHECK (strona IN ('RED','BLUE')),
    bohaterowie_nazwa VARCHAR(20),
    PRIMARY KEY (id_meczu)
);
    
CREATE TABLE gry_zakupioneprzedmioty (
	id 						  BIGINT NOT NULL IDENTITY,
    id_meczu                  BIGINT NOT NULL,
    id_zakupionego_przedmiotu INT NOT NULL
	PRIMARY KEY(id)
);

CREATE TABLE komponenty_przedmiotow (
    id            BIGINT NOT NULL IDENTITY,
    id_przed      INT NOT NULL,
    id_komponentu INT NULL,
    PRIMARY KEY (id)
);

CREATE INDEX komponenty_przedmiotow__idx ON
    komponenty_przedmiotow (
        id_przed
    ASC,
        id_komponentu
    ASC );

CREATE TABLE kontry (
    bohater VARCHAR(20) NOT NULL,
    kontra  VARCHAR(20) NOT NULL
);

ALTER TABLE kontry ADD CONSTRAINT kontry_pk PRIMARY KEY ( bohater,
                                                          kontra );

CREATE TABLE przedmioty (
    id_przed          INT NOT NULL,
    nazwa             CHAR(100) NOT NULL,
    statystyki         VARCHAR(max) NOT NULL,
    ikona             VARCHAR(max) NOT NULL,
    cena              SMALLINT CHECK(cena >= 0),
    wartosc_sprzedazy SMALLINT CHECK (wartosc_sprzedazy >= 0)
);

CREATE INDEX przedmioty__idx ON
    przedmioty (
        id_przed
    ASC );

ALTER TABLE przedmioty ADD CONSTRAINT przedmioty_pk PRIMARY KEY ( id_przed );

CREATE TABLE turnieje (
    nazwa_turnieju     VARCHAR(70) NOT NULL,
    rodzaj             VARCHAR(8) NOT NULL CHECK (rodzaj IN ('ONLINE', 'OFFLINE')),
    data               DATETIME2(0) NOT NULL,
    zajete_miejsce     SMALLINT NOT NULL,
    ostatni_wynik      VARCHAR(10) NOT NULL,
    nagroda            DECIMAL(10, 5),
    id_druzyny VARCHAR(6) NOT NULL
);

ALTER TABLE turnieje ADD CONSTRAINT turnieje_pk PRIMARY KEY ( nazwa_turnieju,
                                                              id_druzyny );

ALTER TABLE gracze_zawodowi
    ADD CONSTRAINT bohaterowienazwapro_fk FOREIGN KEY ( ulubiony_bohater )
        REFERENCES bohaterowie ( nazwa )
        ON DELETE SET NULL;

ALTER TABLE gracze
    ADD CONSTRAINT bohaterowienazwareg_fk FOREIGN KEY ( ulubiony_bohater )
        REFERENCES bohaterowie ( nazwa )
		ON DELETE SET NULL;

ALTER TABLE dane_logowania
    ADD CONSTRAINT dane_logowania_gracze_fk FOREIGN KEY ( nick )
        REFERENCES gracze ( nick );

ALTER TABLE gracze_zawodowi
    ADD CONSTRAINT druzynyidpro_fk FOREIGN KEY ( id_druzyny )
        REFERENCES druzyny ( id_druzyny )
		ON DELETE SET NULL;

ALTER TABLE turnieje
    ADD CONSTRAINT druzynyidtur_fk FOREIGN KEY ( id_druzyny )
        REFERENCES druzyny ( id_druzyny )
		ON DELETE CASCADE;

ALTER TABLE gracze_gry
    ADD CONSTRAINT gracznick_fk FOREIGN KEY ( gracze_nick )
        REFERENCES gracze ( nick )
		ON DELETE CASCADE;

ALTER TABLE graczezawodowi_gry
    ADD CONSTRAINT graczzawodowynick_fk FOREIGN KEY ( gracze_zawodowi_nick )
        REFERENCES gracze_zawodowi ( nick )
		ON DELETE CASCADE;

ALTER TABLE gracze_gry
    ADD CONSTRAINT gragracz_fk FOREIGN KEY ( gry_id_meczu )
        REFERENCES gry ( id_meczu )
		ON DELETE CASCADE;

ALTER TABLE graczezawodowi_gry
    ADD CONSTRAINT gragraczzawodowy_fk FOREIGN KEY ( gry_id_meczu )
        REFERENCES gry ( id_meczu )
		ON DELETE CASCADE;

ALTER TABLE gry_zakupioneprzedmioty
    ADD CONSTRAINT graidmeczu_fk FOREIGN KEY ( id_meczu )
        REFERENCES gry ( id_meczu )
		ON DELETE CASCADE;

ALTER TABLE gry
    ADD CONSTRAINT gry_bohaterowie_fk FOREIGN KEY ( bohaterowie_nazwa )
        REFERENCES bohaterowie ( nazwa )
		ON DELETE SET NULL;

ALTER TABLE kontry
    ADD CONSTRAINT kontry_bohaterowie_fk FOREIGN KEY ( bohater )
        REFERENCES bohaterowie ( nazwa )
		ON DELETE CASCADE;

ALTER TABLE kontry
    ADD CONSTRAINT kontry_bohaterowie_fkv1 FOREIGN KEY ( kontra )
        REFERENCES bohaterowie ( nazwa )

ALTER TABLE komponenty_przedmiotow
    ADD CONSTRAINT przedmiotyid1_fk FOREIGN KEY ( id_przed )
        REFERENCES przedmioty ( id_przed )
		ON DELETE CASCADE;

ALTER TABLE komponenty_przedmiotow
    ADD CONSTRAINT przedmiotyid2_fk FOREIGN KEY ( id_komponentu )
        REFERENCES przedmioty ( id_przed );

ALTER TABLE gry_zakupioneprzedmioty
    ADD CONSTRAINT przedmiotid3_fk FOREIGN KEY ( id_zakupionego_przedmiotu )
        REFERENCES przedmioty ( id_przed )
		ON DELETE CASCADE;

INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Aatrox', 'Ostrze Darkin??w', 'Aatrox i jego pobratymcy, kiedy?? szanowani obro??cy Shurimy przed Pustk??, ostatecznie stali si?? jeszcze wi??kszym zagro??eniem dla Runeterry ni?? sama Pustka i zostali pokonani tylko dzi??ki przebieg??ym czarom ??miertelnik??w. Lecz po latach sp??dzonych w wi??zieniu Aatrox by?? pierwszym, kt??ry ponownie wydosta?? si?? na wolno????, spaczaj??c i przemieniaj??c wszystkich wystarczaj??co g??upich, by spr??bowa?? w??adania magiczn?? broni??, kt??ra zawiera??a jego esencj??. Teraz w??druje po Runeterze z ukradzion?? pow??ok?? skrzywion?? na brutalne podobie??stwo swej poprzedniej postaci i pragnie apokaliptycznej zemsty, kt??rej powinien by?? dokona?? ju?? dawno.', 8, 4, 3, 4, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Aatrox_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Aatrox.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Ahri', 'Lisica o Dziewi??ciu Ogonach', 'Ahri to Vastajanka naturalnie po????czona z magi?? kr??????c?? po Runeterze, kt??ra mo??e zmienia?? energi?? magiczn?? w kule czystej energii. Uwielbia bawi?? si?? swoimi ofiarami i manipulowa?? ich emocjami, aby p????niej po??re?? ich esencj?? ??yciow??. Pomimo drapie??nej natury Ahri odczuwa empati??, poniewa?? wraz z poch??anianymi duszami otrzymuje przeb??yski ich wspomnie??.', 3, 4, 8, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Ahri_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Ahri.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Akali', 'Skryta Zab??jczyni', 'Opu??ciwszy Zakon Kinkou i wyzbywszy si?? tytu??u Pi????ci Cienia, Akali dzia??a w pojedynk??, gotowa sta?? si?? ??mierciono??n?? broni??, kt??rej jej lud tak bardzo potrzebowa??. Cho?? nie wyrzek??a si?? wiedzy, kt??r?? przekaza?? jej mistrz Shen, poprzysi??g??a zabija?? wrog??w Ionii jednego po drugim. Akali uderza wprawdzie w niczym niezm??conej ciszy, ale jej przes??anie rozbrzmiewa z wielk?? moc??: b??j si?? zab??jczyni bez mistrza.', 5, 3, 8, 7, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Akali_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Akali.png', 'Assassin');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Akshan', 'Zbuntowany Stra??nik', 'Ledwie unosz??cy brew w obliczu niebezpiecze??stwa Akshan walczy ze z??em, wykorzystuj??c swoj?? osza??amiaj??c?? charyzm??, pragnienie dokonania s??usznej zemsty i rzucaj??cy si?? w oczy brak jakiejkolwiek koszuli. Wyr????nia si?? niesamowitymi umiej??tno??ciami prowadzenia walki z ukrycia ??? potrafi unika?? spojrze?? wrog??w, by wy??oni?? si?? przed nimi, gdy najmniej si?? tego spodziewaj??. Wraz ze swoim gorliwym poczuciem sprawiedliwo??ci oraz legendarn?? broni?? potrafi??c?? odwr??ci?? ??mier?? Akshan naprawia krzywdy wyrz??dzone przez zamieszkuj??cych Runeterr?? nikczemnik??w. Sam ??yje wed??ug w??asnego kodu moralnego, kt??ry brzmi: ???Nie b??d?? dupkiem???.', 0, 0, 0, 0, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Akshan_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Akshan.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Alistar', 'Minotaur', 'Jako pot????ny wojownik z przera??aj??c?? reputacj??, Alistar chce zem??ci?? si?? za wyt??pienie jego klanu przez noxia??skie imperium. Pomimo ??e zniewolono go i zmuszono do walk na arenie, jego niez??omna wola powstrzymywa??a go od stania si?? besti??. Teraz, wolny od ??a??cuch??w starych pan??w, walczy w imi?? uciskanych i ubogich. W??ciek??o???? jest jego broni?? tak samo jak rogi, kopyta i pi????ci.', 6, 9, 5, 7, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Alistar_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Alistar.png', 'Tank');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Amumu', 'Smutna Mumia', 'Legenda m??wi, ??e Amumu to samotna i melancholijna istota z antycznej Shurimy, przemierzaj??ca ??wiat w poszukiwaniu przyjaciela. Na wieczn?? samotno???? skaza??a go staro??ytna kl??twa, w wyniku kt??rej jego dotyk przynosi ??mier??, a jego sympatia ??? zgub??. Ci, kt??rzy twierdz??, ??e widzieli Amumu, opisuj?? go jako ??ywego trupa o niewielkiej posturze, ca??kowicie owini??tego od??a????cymi banda??ami. Nikt jednak nie wie, jaki naprawd?? jest Amumu. Prawda i fikcja przeplataj?? si?? ze sob?? w??r??d przekazywanych z pokolenia na pokolenie mit??w, baja?? i pie??ni zainspirowanych jego postaci??.', 2, 6, 8, 3, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Amumu_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Amumu.png', 'Tank');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Anivia', 'Kriofeniks', 'Anivia to dobrotliwy, skrzydlaty duch, kt??ry stawia czo??o nieko??cz??cym si?? cyklom ??ycia, ??mierci i odrodzenia, by chroni?? Freljord. P????bogini zrodzona z bezlitosnego lodu i wichr??w, posiada moce ??ywio????w, kt??re zatrzymaj?? ka??dego, kto zak????ci spok??j jej ojczyzny. Anivia strze??e i chroni plemiona z mro??nej p????nocy, kt??re czcz?? j?? jako symbol nadziei i znak wielkich zmian. Walczy ka??d?? cz??stk?? siebie, bo wie, ??e dzi??ki jej po??wi??ceniu jej pami???? przetrwa, a ona sama odrodzi si?? w nowym dniu.', 1, 4, 10, 10, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Anivia_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Anivia.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Annie', 'Dziecko Ciemno??ci', 'Niebezpieczna, lecz przedwcze??nie dojrza??a Annie, jest dzieckiem o nieprawdopodobnych zdolno??ciach zwi??zanych z piromani??. Nawet w cieniach g??r na p????noc od Noxusu jest magicznym ewenementem. Jej naturalne zami??owanie do ognia uzewn??trzni??o si?? wcze??nie pod postaci?? nieprzewidywalnych wybuch??w emocji. Z czasem jednak nauczy??a si?? kontrolowa?? te ???sztuczki???. Do jej ulubionych czynno??ci nale??y przyzywanie ukochanego misia, Tibbersa, jako ognistego obro??cy. Zagubiona w wiecznej, dzieci??cej niewinno??ci, Annie przemierza ciemne lasy, zawsze poszukuj??c kogo?? do zabawy.', 2, 3, 10, 6, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Annie_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Annie.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Aphelios', 'Bro?? Wiernych', 'Wychodz??c z broni?? w r??ce z cienia rzucanego przez ksi????yc, Aphelios zabija wrog??w swojej wiary w z??owrogiej ciszy ??? przemawia tylko poprzez niesamowit?? celno???? i strza??y z pistolet??w. Cho?? nap??dza go trucizna czyni??ca z niego niemow??, to kieruje nim jego siostra Alune. Z odleg??ego ??wi??tynnego sanktuarium wpycha arsena?? broni z kamienia ksi????ycowego w jego r??ce. Albowiem tak d??ugo, jak ksi????yc ??wieci nad jego g??ow??, Aphelios nigdy nie b??dzie sam.', 6, 2, 1, 10, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Aphelios_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Aphelios.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Ashe', 'Lodowa ??uczniczka', 'C??ra Lodu i wojmatka avarosa??skiego plemienia, Ashe w??ada najliczniejsz?? hord?? na ca??ej p????nocy. Stoicka, inteligentna i idealistyczna, lecz nie czuj??ca si?? pewnie w swej roli przyw??dczyni, czerpie z magii przodk??w, by w??ada?? ??ukiem Prawdziwego Lodu. Skoro jej ludzie wierz??, ??e to ona jest wcieleniem mitycznej bohaterki Avarosy, Ashe ma nadziej?? na wt??rne zjednoczenie Freljordu poprzez ponowne zaj??cie staro??ytnych ziem jej plemienia.', 7, 3, 2, 4, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Ashe_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Ashe.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Aurelion Sol', 'Architekt Gwiazd', 'Aurelion Sol niegdy?? ozdabia?? nieprzebran?? pustk?? kosmosu astralnymi cudami swojego autorstwa. Teraz musi wykorzystywa?? swoj?? straszliw?? moc, by us??ugiwa?? kosmicznemu imperium, kt??re podst??pem go zniewoli??o. Pragn??c powr??ci?? do czas??w, gdy tworzy?? gwiazdy, Aurelion Sol got??w jest zedrze?? je z nieba ??? byle tylko odzyska?? wolno????.', 2, 3, 8, 7, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/AurelionSol_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/AurelionSol.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Azir', 'Imperator Pustyni', 'Azir by?? ??miertelnym imperatorem Shurimy w dawnych czasach, dumnym m????czyzn??, kt??ry by?? o krok od zyskania nie??miertelno??ci. Jego arogancka duma doprowadzi??a do tego, ??e zdradzono i zamordowano go w chwili najwi??kszego triumfu. Jednak teraz, wiele tysi??cleci p????niej, odrodzi?? si?? jako Wyniesiona istota o bezgranicznej mocy. Jego pogrzebane w??r??d piask??w miasto raz jeszcze powsta??o, a Azir pragnie przywr??ci?? imperium Shurimy dawn?? chwa????.', 6, 3, 8, 9, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Azir_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Azir.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Bard', 'W??druj??cy Opiekun', 'Podr????nik spoza gwiazd, Bard, jest patronem szcz????liwych przypadk??w, walcz??cym, by zachowa?? r??wnowag??, dzi??ki kt??rej ??ycie mo??e przetrwa?? oboj??tno???? chaosu. Wielu mieszka??c??w Runeterry ??piewa piosenki, kt??re wychwalaj?? jego niecodzienny charakter, lecz wszyscy zgadzaj?? si??, ??e ten kosmiczny w????czykij ma poci??g do artefakt??w o wielkiej mocy. Bard zwykle jest otoczony przez rozradowany ch??r pomocnych meep??w i nie mo??na przyj???? jego czyn??w za z??e, poniewa?? on zawsze s??u??y wi??kszemu dobru... na sw??j w??asny, dziwny spos??b.', 4, 4, 5, 9, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Bard_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Bard.png', 'Support');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Bel''Veth', 'Cesarzowa Pustki', 'Bel''Veth, koszmarna cesarzowa zrodzona z czystej esencji poch??oni??tego w ca??o??ci miasta, zwiastuje koniec obecnej Runeterry??? i pocz??tek potwornej rzeczywisto??ci, kt??r?? tworzy wedle w??asnego uznania. Milenia przeinaczania historii, wiedzy i wspomnie?? ze ??wiata powy??ej ka???? jej nieustannie karmi?? swoj?? wiecznie rosn??c?? potrzeb?? poznawania nowych do??wiadcze?? i emocji, wi??c poch??ania wszystko, co stanie jej na drodze. Jeden ??wiat nie wystarczy jednak, aby zaspokoi?? jej ????dze, a wi??c Bel''Veth kieruje swoje wyg??odnia??e spojrzenie ku dawnym panom Pustki???', 4, 2, 7, 10, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Belveth_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Belveth.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Blitzcrank', 'Wielki Golem Parowy', 'Blitzcrank to ogromny, prawie niezniszczalny automat z Zaun, zbudowany w celu pozbywania si?? radioaktywnych odpad??w. Pewnego dnia stwierdzi??, ??e jego zadanie nadto go ogranicza, wi??c zmodyfikowa?? si??, by lepiej s??u??y?? delikatnym ludziom ze Slums??w. Blitzcrank bezinteresownie u??ywa swojej si??y i wytrzyma??o??ci w ramach pomagania innym. Wyci??ga pomocn?? pi?????? lub eksplozj?? energii do okie??znania wszystkich rzezimieszk??w.', 4, 8, 5, 4, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Blitzcrank_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Blitzcrank.png', 'Tank');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Brand', 'P??omie?? Zemsty', 'Kiedy?? cz??onek plemienia lodowego Freljordu, imieniem Kegan Rodhe, istota znana jako Brand jest lekcj?? na temat pokus wi??kszej mocy. Podczas poszukiwania jednej z legendarnych Run ??wiata, Kegan zdradzi?? swoich towarzyszy i zgarn???? j?? dla siebie ??? po chwili ju?? go nie by??o. Jego dusza si?? wypali??a, a cia??o sta??o si?? no??nikiem ??ywego ognia. Brand w??druje teraz po Valoranie, szukaj??c innych Run i poprzysi??g?? zemst?? za krzywdy, kt??rych nie m??g??by do??wiadczy?? nawet w ci??gu parunastu ??miertelnych ??y??.', 2, 2, 9, 4, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Brand_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Brand.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Braum', 'Serce Freljordu', 'Dzi??ki pot????nym bicepsom i jeszcze wi??kszemu sercu Braum jest ukochanym bohaterem Freljordu. Ca??y mi??d pitny na p????noc od Mro??nej Przystani jest wypijany za jego legendarn?? si????, o kt??rej m??wi si??, ??e jest zdolna do powalenia ca??ego d??bowego lasu w ci??gu jednej nocy i obr??cenia g??ry w proch. Dzier????c zakl??te drzwi skarbca jako tarcz??, Braum, prawdziwy przyjaciel dla tych w biedzie, w??druje po mro??nej p????nocy z w??satym u??miechem na twarzy tak du??ym jak jego mi????nie.', 3, 9, 4, 3, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Braum_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Braum.png', 'Support');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Caitlyn', 'Szeryf Piltover', 'Znana jako najlepsza rozjemczyni, Caitlyn jest r??wnie?? najlepsz?? szans?? Piltover na pozbycie si?? nieuchwytnych element??w kryminalnych z miasta. Cz??sto w parze z Vi, jest przystani?? spokoju w por??wnaniu z ??ywio??owym charakterem jej partnerki. Pomimo tego, ??e korzysta z jedynego w swoim rodzaju karabinu pulsarowego, najpot????niejsz?? broni?? Caitlyn jest jej ponadprzeci??tna inteligencja, kt??ra pozwala jej na zastawianie skomplikowanych pu??apek na przest??pc??w na tyle g??upich, by dzia??a?? w Mie??cie Post??pu.', 8, 2, 2, 6, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Caitlyn_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Caitlyn.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Camille', 'Stalowy Cie??', 'Wyposa??ona, aby dzia??a?? poza granicami prawa, Camille jest g????wn?? wywiadowczyni?? rodu Ferros oraz eleganck?? i elitarn?? agentk??, kt??ra upewnia si??, ??e maszyna Piltover oraz jej zau??skie podbrzusze dzia??aj?? prawid??owo. Zdolna do przystosowywania si?? oraz przyk??adania uwagi do szczeg??????w, uwa??a wszelkie przejawy zaniedbania za wstyd, kt??ry trzeba zmaza??. Camille posiada umys?? r??wnie ostry, co ostrza, kt??rych u??ywa, a ci??g??e ulepszanie cia??a za pomoc?? hextechowych wzmocnie?? sprawi??o, ??e wiele os??b si?? zastanawia, czy nie sta??a si?? bardziej maszyn?? ni?? kobiet??.', 8, 6, 3, 4, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Camille_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Camille.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Cassiopeia', 'W????owy U??cisk', 'Cassiopeia jest ??mierteln?? istot?? zdeterminowan??, by manipulowa?? innymi zgodnie z jej niegodziw?? wol??. Najm??odsza i najpi??kniejsza c??rka szlachetnej, noxia??skiej rodziny Du Couteau, odby??a wypraw?? w poszukiwaniu mocy g????boko do krypt pod Shurim??. Zosta??a tam ugryziona przez przera??aj??cego stra??nika grobowca, kt??rego jad zmieni?? j?? w ??mij?? drapie??nika. Przebieg??a i zwinna, Cassiopeia pe??za pod os??on?? nocy, by obraca?? przeciwnik??w w kamie?? swym zgubnym spojrzeniem.', 2, 3, 9, 10, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Cassiopeia_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Cassiopeia.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Cho''Gath', 'Postrach Pustki', 'Od momentu, w kt??rym Cho''Gath pierwszy raz wynurzy?? si?? na ostre ??wiat??o s??o??ca Runeterry, nap??dza go najczystszy i niezaspokojony g????d. Cho''Gath jest przyk??adowym wyrazem ????dzy Pustki do po??erania wszystkiego, co ??yje, a jego skomplikowana biologia szybko przetwarza materi?? na rozrost cia??a, zwi??kszaj??c mas?? i g??sto???? mi????ni lub czyni??c jego zewn??trzny pancerz twardym jak diament. Kiedy ro??ni??cie nie pasuje pomiotowi Pustki, wymiotuje nadmiar materia??u pod postaci?? ostrych jak brzytwa kolc??w, kt??re przebijaj?? ofiary, przygotowuj??c je na p????niejsz?? uczt??.', 3, 7, 7, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Chogath_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Chogath.png', 'Tank');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Corki', 'Dzielny Bombardier', 'Yordlowy pilot Corki najbardziej kocha dwie rzeczy: latanie i swoje ol??niewaj??ce w??sy... cho?? niekoniecznie w tej kolejno??ci. Po opuszczeniu Bandle City osiedli?? si?? w Piltover i zakocha?? si?? w niezwyk??ych maszynach, kt??re tam znalaz??. Po??wi??ci?? si?? rozwojowi swoich lataj??cych wynalazk??w, przewodz??c obronnym si??om powietrznym z??o??onym z zaprawionych weteran??w, znanych jako Wrzeszcz??ce W????e. Spokojny nawet pod ostrza??em, Corki patroluje niebo wok???? swojego przybranego domu i nigdy nie napotyka takiego problemu, kt??rego nie da??oby si?? rozwi??za?? za pomoc?? dobrego ognia zaporowego.', 8, 3, 6, 6, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Corki_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Corki.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Darius', 'R??ka Noxusu', 'Nie ma lepszego symbolu noxia??skiej si??y ni?? Darius, siej??cy strach w sercach ca??ego narodu i najbardziej zaprawiony w bojach dow??dca. Zaczyna?? skromnie, by w ko??cu zosta?? R??k?? Noxusu i za pomoc?? topora rozprawia?? si?? z wrogami imperium, kt??rzy czasami okazuj?? si?? by?? Noxianami. Wiedz??c, ??e Darius nigdy nie w??tpi w nieomylno???? swojej sprawy i nigdy nie waha si??, gdy jego top??r jest w g??rze, ci, kt??rzy przeciwstawiaj?? si?? liderowi Legionu Tryfaria??skiego, nie mog?? liczy?? na lito????.', 9, 5, 1, 2, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Darius_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Darius.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Diana', 'Pogarda Ksi????yca', 'Diana, wyposa??ona w zakrzywione, ksi????ycowe ostrze, jest wojowniczk?? Lunari ??? cz??onk??w wyznania, kt??re praktycznie ju?? nie istnieje na terenach otaczaj??cych G??r?? Targon. Odziana w l??ni??c?? zbroj?? w kolorze nocnego ??niegu, jest ??ywym uciele??nieniem mocy srebrnego ksi????yca. Przepe??niona esencj?? Aspektu spoza szczytu Targonu, Diana nie jest ju?? w pe??ni cz??owiekiem i stara si?? poj???? swoj?? moc i cel egzystencji na tym ??wiecie.', 7, 6, 8, 4, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Diana_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Diana.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Draven', 'Wielki Oprawca', 'W Noxusie wojownicy znani jako walecznicy mierz?? si?? ze sob?? na arenach, gdzie przelewa si?? krew, a si???? poddaje si?? pr??bie. Jednak??e ??aden z nich nie by?? tak s??awny jak Draven. By??y ??o??nierz doszed?? do wniosku, ??e t??um docenia jego smyka??k?? do dramatyczno??ci, jak i niedo??cigniony kunszt, z jakim w??ada wiruj??cymi toporami. Uzale??niony od pokazu bezczelnej perfekcji, Draven poprzysi??g?? pokona?? wszystkich, by to jego imi?? wiecznie powtarzano w ca??ym imperium.', 9, 3, 1, 8, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Draven_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Draven.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Dr Mundo', 'Szaleniec z Zaun', 'Doszcz??tnie oszala??y, tragicznie zab??jczy i przera??aj??co fioletowy Dr Mundo jest przyczyn??, dla kt??rej wielu mieszka??c??w Zaun nie opuszcza swoich dom??w w szczeg??lnie ciemne noce. Ten samozwa??czy lekarz by?? niegdy?? pacjentem nies??awnego o??rodka opieki dla ob????kanych. Po ???uleczeniu??? ca??ego personelu plac??wki Dr Mundo za??o??y?? w??asn?? przychodni?? w opustosza??ych salach szpitalnych, w kt??rych to na nim kiedy?? przeprowadzano okrutne terapie. Zacz???? w niej odtwarza?? wysoce nieetyczne zabiegi, kt??re prze??y?? na w??asnej sk??rze. Korzystaj??c z pe??nego dost??pu do lek??w i zerowego wykszta??cenia medycznego, z ka??dym podanym sobie zastrzykiem Mundo zmienia si?? w coraz okropniejsze monstrum i terroryzuje nieszcz??snych ???pacjent??w???, kt??rzy trafiaj?? zbyt blisko jego gabinetu.', 5, 7, 6, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/DrMundo_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/DrMundo.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Ekko', 'Ch??opiec, kt??ry ujarzmi?? czas', 'Ekko, geniusz wychowany na ulicach Zaun, manipuluje czasem, aby ka??da sytuacja potoczy??a si?? po jego my??li. Korzystaj??c ze swojego w??asnego wynalazku, Nap??du Zero, Ekko odkrywa niesko??czone mo??liwo??ci czasoprzestrzeni, aby stworzy?? idealny moment. Cho?? ceni sobie swoj?? wolno???? ponad wszystko, to nie zawaha si?? pom??c przyjacio??om, gdy s?? w potrzebie. Dla przybysz??w Ekko wydaje si?? dokonywa?? niemo??liwych rzeczy za pierwszym razem, przy ka??dej rzeczy, kt??r?? robi.', 5, 3, 7, 8, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Ekko_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Ekko.png', 'Assassin');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Elise', 'Kr??lowa Paj??k??w', 'Elise jest niebezpiecznym drapie??nikiem, kt??ry siedzib?? ma w zamkni??tym i mrocznym pa??acu, mieszcz??cym si?? g????boko w najstarszym mie??cie Noxusu. Kiedy?? by??a ??miertelniczk??, dam?? z pot????nego rodu, ale uk??szenie nikczemnego paj??czego p????boga zmieni??o j?? w co?? pi??knego, lecz ca??kowicie nieludzkiego ??? w paj??cze stworzenie, wabi??ce niespodziewaj??ce si?? ofiary w swoj?? sie??. Aby zachowa?? wieczn?? m??odo????, poluje na naiwnych i niewiernych ludzi, a tylko nieliczni s?? w stanie oprze?? si?? jej sztuce uwodzenia.', 6, 5, 7, 9, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Elise_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Elise.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Evelynn', 'U??cisk ??mierci', 'W mrocznych zak??tkach Runeterry demoniczna Evelynn poszukuje nast??pnej ofiary. Wabi j??, przyjmuj??c ludzk??, pon??tn?? posta?? kobiety, a gdy ta ulegnie jej wdzi??kom, pokazuje swoje prawdziwe ja. Nast??pnie poddaje j?? niewyobra??alnym m??kom, zaspokajaj??c si?? jej b??lem. Dla demonicznej Evelynn tego typu przygody to jedynie niewinne romanse. Natomiast dla reszty Runeterry to makabryczne opowie??ci o po????daniu, kt??re wymkn????o si?? spod kontroli, i przera??aj??ce przypomnienie o tym, do czego mog?? doprowadzi?? nieokie??znane ????dze.', 4, 2, 7, 10, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Evelynn_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Evelynn.png', 'Assassin');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Ezreal', 'Odkrywca z Powo??ania', 'Ezreal, pr????ny poszukiwacz przyg??d, nie??wiadomy swojego daru magicznego, przeszukuje dawno zaginione katakumby, zadziera ze staro??ytnymi kl??twami i z ??atwo??ci?? radzi sobie z na pierwszy rzut oka niemo??liwymi do pokonania przeszkodami. Jego odwaga i zuchwa??o???? nie znaj?? granic, a on sam woli wychodzi?? z nieciekawych sytuacji drog?? improwizacji, cz????ciowo polegaj??c na sprycie, ale g????wnie na mistycznej, shurima??skiej r??kawicy, kt??rej u??ywa, by wyzwala?? niszczycielskie, magiczne wybuchy. Jedno jest pewne ??? kiedy Ezreal jest w pobli??u, k??opoty nie pozostaj?? daleko w tyle. Nie wybiegaj?? te?? zbyt daleko w prz??d. W sumie to pewnie s?? wsz??dzie.', 7, 2, 6, 7, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Ezreal_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Ezreal.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Fiddlesticks', 'Prastary Strach', 'Co?? zbudzi??o si?? w Runeterze. Co?? prastarego. Okropnego. Ponadczasowa potworno????, znana jako Fiddlesticks, grasuje w??r??d ??miertelnik??w. Przyci??gaj?? j?? obszary pe??ne paranoi, gdzie ??eruje na przera??onych ofiarach. To dzier????ce kos?? szpetne, wygl??daj??ce jakby mia??o si?? rozpa???? stworzenie, zbiera owoc strachu i doprowadza do szale??stwa nieszcz????nik??w, kt??rym uda??o si?? przetrwa?? spotkanie z nim. Wystrzegajcie si?? krakania i szept??w kszta??tu <i>przypominaj??cego</i> ludzki... Fiddlesticks powr??ci??.', 2, 3, 9, 9, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Fiddlesticks_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Fiddlesticks.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Fiora', 'Mistrzyni Fechtunku', 'Fiora to fechmistrzyni, o kt??rej s??yszano w ca??ym Valoranie. Zas??yn????a zar??wno niez??omno??ci?? i ci??tym j??zykiem, jak i mistrzostwem w szermierce. B??d??c c??rk?? domu Laurent z Demacii, Fiora przej????a kontrol?? nad swoim rodem od ojca w obliczu skandalu, kt??ry niemal ich zniszczy??. Cho?? reputacja domu Laurent zosta??a zszargana, Fiora robi wszystko, co tylko mo??liwe, aby przywr??ci?? jego utracony honor i nale??yte miejsce w??r??d wielkich i wspania??ych rod??w Demacii.', 10, 4, 2, 3, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Fiora_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Fiora.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Fizz', 'Szachraj Sztorm??w', 'Fizz jest amfibiotycznym Yordlem, kt??ry ??yje po??r??d raf otaczaj??cych Bilgewater. Cz??sto wy??awia i zwraca dziesi??ciny wrzucane do morza przez przes??dnych kapitan??w, ale nawet najbardziej do??wiadczeni z ??eglarzy wiedz??, ??eby mu si?? nie sprzeciwia?? ??? wszak jest wiele opowie??ci o tych, kt??rzy nie docenili tej nieuchwytnej postaci. Cz??sto mylony z wcieleniem kapry??nego ducha oceanu, sprawia wra??enie, ??e potrafi dowodzi?? ogromn??, mi??so??ern?? besti?? z otch??ani, i czerpie przyjemno???? z wprowadzania w zak??opotanie tak samo sojusznik??w, jak i wrog??w.', 6, 4, 7, 6, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Fizz_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Fizz.png', 'Assassin');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Galio', 'Kolos', 'Kamienny kolos Galio strze??e l??ni??cego miasta zwanego Demacia. Zbudowany w celu obrony przed wrogimi magami, cz??sto stoi bez ruchu przez wiele dekad, dop??ki obecno???? pot????nej magii go nie o??ywi. Gdy to nast??pi, Galio wykorzystuje ten czas jak najlepiej, rozkoszuj??c si?? walk?? i ciesz??c, ??e mo??e broni?? krajan. Jednak??e jego sukcesy nie nios?? rado??ci, poniewa?? magia, kt??r?? zwalcza, jest powodem jego o??ywienia i po ka??dym zwyci??stwie ponownie zapada w sen.', 1, 10, 6, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Galio_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Galio.png', 'Tank');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Gangplank', 'Postrach Siedmiu M??rz', 'R??wnie nieprzewidywalny, co brutalny, zdetronizowany kr??l ??upie??c??w Gangplank wzbudza strach na ca??ym ??wiecie. Kiedy?? dowodzi?? miastem portowym Bilgewater, i cho?? jego panowanie si?? sko??czy??o, s?? tacy, kt??rzy twierdz??, ??e uczyni??o go to jeszcze bardziej niebezpiecznym. Gangplank raczej by utopi?? Bilgewater we krwi, ni?? odda?? je komu?? innemu. Teraz, uzbrojony w pistolet, kordelas i beczki prochu, jest zdeterminowany, by odebra?? to, co utraci??.', 7, 6, 4, 9, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Gangplank_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Gangplank.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Garen', 'Pot??ga Demacii', 'Dumny i szlachetny wojownik, Garen jest jednym z cz??onk??w Nieustraszonej Gwardii. Jego koledzy ceni?? go, a przeciwnicy szanuj?? ??? zw??aszcza, ??e jest potomkiem szanowanego rodu Obro??c??w Korony, kt??remu powierzono trzymanie pieczy nad Demaci?? i jej idea??ami. Odziany w zbroj?? odporn?? na magi??, Garen i jego pot????ny miecz s?? gotowi stawi?? czo??a magom i czarodziejom na polu bitwy w prawdziwym wirze prawej stali.', 7, 7, 1, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Garen_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Garen.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Gnar', 'Brakuj??ce Ogniwo', 'Gnar jest pierwotnym Yordlem, kt??rego dziecinne wyg??upy mog?? w mgnieniu oka przerodzi?? si?? w wybuch gniewu, zmieniaj??c go w ogromn?? besti?? zdeterminowan??, by niszczy??. Zamro??ony w Prawdziwym Lodzie przez tysi??clecia, to ciekawskie stworzenie wydosta??o si?? ze?? i teraz skacze po ??wiecie pe??nym zmian, kt??ry postrzega jako egzotyczny i niezwyk??y. Czerpi??c przyjemno???? z niebezpiecze??stwa, Gnar rzuca w przeciwnik??w czymkolwiek tylko mo??e ??? ko??cianym bumerangiem lub pobliskim budynkiem.', 6, 5, 5, 8, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Gnar_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Gnar.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Gragas', 'Karczemny Zabijaka', 'R??wnie weso??y, co okaza??y, Gragas jest ogromnym, bitnym piwowarem, kt??ry poszukuje perfekcyjnego kufla piwa. Jego pochodzenie jest nieznane, ale wiadomo, ??e teraz szuka rzadkich sk??adnik??w po nieskalanych pustkowiach Freljordu, pr??buj??c ka??dego przepisu po drodze. Cz??sto pijany i ekstremalnie impulsywny, przeszed?? do legendy za wszczynane przez siebie b??jki, kt??re cz??sto ko??cz?? si?? na ca??onocnych imprezach i rozleg??ych zniszczeniach mienia. Ka??de pojawienie si?? Gragasa z pewno??ci?? zwiastuje popijaw?? i zniszczenie ??? w tej kolejno??ci.', 4, 7, 6, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Gragas_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Gragas.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Graves', 'Banita', 'Malcolm Graves jest znanym najemnikiem, szulerem i z??odziejem, w dodatku jest poszukiwany w ka??dym mie??cie i imperium, jakie odwiedzi??. Pomimo ??e ma wybuchowy temperament, kieruje si?? z??odziejskim honorem, kt??ry cz??sto pokazuje za pomoc?? swojej dwulufowej strzelby zwanej Losem. Ostatnimi laty zakopa?? top??r wojenny z Twisted Fate''em i zn??w prosperuj?? w zam??cie kryminalnego podbrzusza Bilgewater.', 8, 5, 3, 3, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Graves_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Graves.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Gwen', 'Mglista Krawczyni', 'Gwen, niegdy?? lalka, a teraz przemienione i dzi??ki magii powo??ane do ??ycia dziewcz??, dzier??y te same narz??dzia, kt??re j?? stworzy??y. Z ka??dym krokiem niesie mi??o???? swojej tw??rczyni i niczego nie uznaje za oczywisto????. W??ada U??wi??con?? Mg???? ??? pradawn?? magi?? ochronn??, kt??r?? pob??ogos??awione zosta??y jej no??yce, ig??y i nici. Gwen nadal nie rozumie wi??kszo??ci praw, jakimi rz??dzi si?? ten okrutny ??wiat, a mimo to, nie utraciwszy pogody ducha, postanowi??a podj???? si?? walki w imi?? wci???? obecnego w nim dobra.', 7, 4, 5, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Gwen_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Gwen.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Hecarim', 'Cie?? Wojny', 'Hecarim jest upiornym po????czeniem cz??owieka i bestii, przekl??tym, by przez ca???? wieczno???? goni?? za duszami ??yj??cych. Kiedy B??ogos??awione Wyspy poch??on???? cie??, ten dumny rycerz, z ca???? swoj?? kawaleri?? i wierzchowcami, zosta?? rozniesiony przez niszcz??ce si??y Zrujnowania. Teraz, kiedy Czarna Mg??a rozpo??ciera si?? przez ca???? Runeterr??, przewodzi ich niszczycielskiej szar??y, karmi??c si?? rzezi?? i tratuj??c wrog??w swoimi opancerzonymi kopytami.', 8, 6, 4, 6, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Hecarim_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Hecarim.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Heimerdinger', 'Wielbiony Wynalazca', 'R??wnie genialny, co ekscentryczny yordlowy naukowiec, Profesor Cecil B. Heimerdinger jest jednym z najbystrzejszych i uznanych naukowc??w, jakich zna?? Piltover. Pogr????ony w pracy tak bardzo, ??e sta??a si?? jego obsesj??, d????y do znalezienia odpowiedzi na najbardziej nieprzeniknione pytania wszech??wiata. Cho?? jego teorie cz??sto wydaj?? si?? mgliste i tajemnicze, Heimerdinger stworzy?? jedne z najcudowniejszych, i zab??jczych, maszyn Piltover. Ci??gle grzebie przy swoich wynalazkach, by uczyni?? je jeszcze bardziej efektywnymi.', 2, 6, 8, 8, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Heimerdinger_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Heimerdinger.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Illaoi', 'Kap??anka Krakena', 'Pot????na budowa cia??a Illaoi jest przy??miona jedynie przez jej niez??omn?? wiar??. Jako prorok Wielkiego Krakena u??ywa wielkiego, z??otego pos????ka do wyrywania dusz wrog??w z ich cia??, tym samym zaburzaj??c ich postrzeganie rzeczywisto??ci. Wszyscy, kt??rzy odwa???? si?? przeciwstawi?? ???Zwiastunce Prawdy Nagakabourossy???, wkr??tce przekonaj?? si??, ??e??Illaoi??nigdy nie walczy w pojedynk?? ??? bogini z Wysp W????y walczy u jej boku.', 8, 6, 3, 4, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Illaoi_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Illaoi.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Irelia', 'Ta??cz??ca z Ostrzami', 'Ionia??ska ziemia zrodzi??a wielu bohater??w pod noxia??sk?? okupacj??, ale ??aden z nich nie by?? bardziej nadzwyczajny ni?? m??oda Irelia z Navori. Zosta??a wyszkolona w staro??ytnej sztuce ta??c??w swojej prowincji, a potem przystosowa??a j?? do potrzeb wojny ??? wykorzystuj??c dok??adnie wy??wiczone, pe??ne wdzi??ku ruchy, by unosi?? w powietrzu szereg ??mierciono??nych ostrzy. Gdy udowodni??a sw?? warto???? jako wojowniczka, postawiono j?? w roli przyw??dczyni ruchu oporu i wzoru do na??ladowania. Do dzi?? jest oddana ochronie ojczyzny.', 7, 4, 5, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Irelia_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Irelia.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Ivern', 'Zielony Ojciec', 'Ivern Krzewobrody, znany te?? jako Zielony Ojciec, to jedyny w swoim rodzaju p????cz??owiek, p????drzewo. W??druje przez lasy Runeterry, na ka??dym kroku staraj??c si?? piel??gnowa?? ??ycie. Dobrze zna sekrety natury i przyja??ni si?? ze wszystkimi lataj??cymi, biegaj??cymi i rosn??cymi w ziemi istotami. Ivern przemierza dzicz i dzieli si?? swoj?? niezwyk???? wiedz?? z ka??dym, kogo napotka, ubogaca las, a czasem nawet zdradza swoje sekrety wsz??dobylskim motylom.', 3, 5, 7, 7, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Ivern_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Ivern.png', 'Support');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Janna', 'Sza?? Burzy', 'Janna, uzbrojona w pot??g?? wichur Runeterry, jest tajemniczym duchem wiatru, kt??ry ochrania poszkodowanych z Zaun. Niekt??rzy ludzie uwa??aj??, ??e zosta??a zrodzona z b??aga?? ??eglarzy z Runeterry, kt??rzy modlili si?? o przyjazne wiatry, gdy p??ywali po zdradliwych wodach i mierzyli si?? z pot????nymi wichurami. Jej przychylno???? oraz ochrona zawita??y w ko??cu do Zaun, gdzie sta??a si?? ??r??d??em nadziei dla potrzebuj??cych. Nikt nie wie, gdzie lub kiedy si?? pojawi, ale na og???? przybywa na pomoc.', 3, 5, 7, 7, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Janna_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Janna.png', 'Support');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Jarvan IV', 'Wz??r dla Demacian', 'Ksi?????? Jarvan, potomek dynastii Promiennej Tarczy, jest nast??pc?? praw do tronu Demacii. Wychowany, by sta?? si?? przyk??adem cn??t swojego narodu, jest zmuszony do ??onglowania pomi??dzy oczekiwaniami jego rodzic??w, a jego wol?? do walki w pierwszej linii. Na polu walki inspiruje swoje oddzia??y zagrzewaj??c?? do boju odwag?? i determinacj??, pod niebiosa wynosz??c barwy swojego rodu. To tam ujawnia si?? jego prawdziwa si??a i zdolno??ci przyw??dcze.', 6, 8, 3, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/JarvanIV_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/JarvanIV.png', 'Tank');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Jax', 'Mistrz Broni', 'Niedo??cigniony we w??adaniu wyj??tkowymi broniami i w u??ywaniu ci??tego sarkazmu, Jax jest ostatnim znanym mistrzem broni z Icathii. Po tym jak jego ojczyzna w swojej aroganckiej dumie uwolni??a Pustk?? i zosta??a przez to zniszczona, Jax i jego pobratymcy przysi??gli broni?? tego, co zosta??o. Skoro magia zaczyna powraca?? do tego ??wiata, a to zagro??enie ponownie czyha, Jax w??druje po Valoranie, nios??c ostatnie ??wiat??o Icathii i poddaj??c pr??bie wszystkich wojownik??w, kt??rych spotka, aby sprawdzi??, czy s?? wystarczaj??co silni, by stan???? u jego boku...', 7, 5, 7, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Jax_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Jax.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Jayce', 'Obro??ca Jutra', 'Jayce to genialny wynalazca, kt??ry po??wi??ci?? si?? obronie Piltover i nieugi??tej s??u??bie post??powi. Dzier????c sw??j zmiennokszta??tny hextechowy m??ot, Jayce korzysta ze swej si??y, odwagi i inteligencji, by chroni?? swoje miasto. Mieszka??cy uwa??aj?? go za bohatera, ale nie podoba mu si?? to, ??e znalaz?? si?? na ??wieczniku. Mimo to, Jayce ma szczere ch??ci; nawet ci, kt??rzy zazdroszcz?? mu umiej??tno??ci, s?? wdzi??czni za to, ??e chroni Miasto Post??pu.', 8, 4, 3, 7, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Jayce_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Jayce.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Jhin', 'Wirtuoz', 'Jhin jest skrupulatnym, zbrodniczym psychopat??, kt??ry wierzy, ??e mordowanie jest sztuk??. Niegdy?? by?? wi????niem w Ionii, lecz zosta?? uwolniony przez szemranych cz??onk??w tamtejszej rady rz??dz??cej, by teraz s??u??y?? im w ich intrygach w roli zab??jcy. Jego pistolet jest mu jak p??dzel, kt??rego u??ywa do tworzenia prac pe??nych artystycznej brutalno??ci, przera??aj??c swe ofiary oraz obserwator??w. Jego makabryczny teatr sprawia mu okrutn?? przyjemno????, co czyni z niego idealnego dor??czyciela najmocniejszego z przekaz??w: przera??enia.', 10, 2, 6, 6, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Jhin_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Jhin.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Jinx', 'Wystrza??owa Wariatka', 'Jinx to maniakalna i porywcza kryminalistka z Zaun, kt??ra lubi sia?? zniszczenie bez przejmowania si?? konsekwencjami. Wyposa??ona w arsena?? morderczych broni, wywo??uje najg??o??niejsze wybuchy i najja??niejsze eksplozje, pozostawiaj??c za sob?? chaos i panik??. Jinx nienawidzi nudy i rado??nie rozsiewa pandemonium wsz??dzie, gdzie si?? uda.', 9, 2, 4, 6, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Jinx_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Jinx.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Kai''Sa', 'C??ra Pustki', 'Kai''Sa, dziewczyna porwana przez Pustk??, kiedy by??a jeszcze dzieckiem, przetrwa??a tylko dzi??ki wytrwa??o??ci i sile woli. Jej prze??ycia sprawi??y, ??e sta??a si?? zab??jcz?? ??owczyni??, cho?? dla niekt??rych jest zwiastunk?? przysz??o??ci, kt??rej nie chcieliby do??y??. Wdawszy si?? w niestabiln?? symbioz?? z ??ywym pancerzem z Pustki, w ko??cu b??dzie musia??a zdecydowa??, czy wybaczy?? ??miertelnikom, kt??rzy nazywaj?? j?? potworem, i wsp??lnie z nimi pokona?? nadchodz??c?? ciemno????... czy mo??e po prostu zapomnie??, a wtedy Pustka po??re ??wiat, kt??ry si?? od niej odwr??ci??.', 8, 5, 3, 6, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Kaisa_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Kaisa.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Kalista', 'W????cznia Zemsty', 'Kalista jest widmem przepe??nionym gniewem i poszukuj??cym odwetu, wiecznym duchem zemsty, zbrojnym koszmarem, kt??ry zosta?? przyzwany z Wysp Cienia, aby niszczy?? oszust??w i zdrajc??w. Wszyscy, kt??rzy zostali zdradzeni, mog?? wo??a?? o pomst??, lecz Kalista odpowiada jedynie tym gotowym zap??aci?? swoimi duszami. Ci, kt??rzy stan?? si?? obiektami gniewu Kalisty, powinni spisa?? sw??j testament, gdy?? ka??dy uk??ad zawarty z t?? ponur?? ??owczyni?? mo??e prowadzi?? jedynie do jej w????czni przeszywaj??cych dusze swym przenikliwym zimnem.', 8, 2, 4, 7, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Kalista_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Kalista.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Karma', 'O??wiecona', '??aden ??miertelnik nie obrazuje duchowych tradycji Ionii tak jak Karma. To uosobienie staro??ytnej duszy, kt??ra niezliczone razy powraca??a do ??ycia, nios??c wszystkie zebrane wspomnienia w ka??de z nich. Jest obdarzona moc??, kt??r?? jedynie nieliczni s?? zdolni poj????. W obliczu niedawnego kryzysu Karma czyni wszystko, co w jej mocy, by w??a??ciwie kierowa?? lud??mi, cho?? dobrze wie, ??e pok??j i harmonia zawsze maj?? wysok?? cen?? ??? zar??wno dla niej samej, jak i dla krainy, kt??ra tak wiele dla niej znaczy.', 1, 7, 8, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Karma_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Karma.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Karthus', 'Piewca ??mierci', 'Zwiastun nico??ci, Karthus, jest wiecznym duchem, n??kaj??cym swymi straszliwymi pie??niami. A s?? one jedynie wst??pem do jego przera??aj??cego wygl??du. ??ywi l??kaj?? si?? wieczno??ci nieumar??ych, ale Karthus dostrzega w ich obj??ciach jedynie czysto???? i pi??kno, doskona??e zjednoczenie ??ycia i ??mierci. Jako or??downik nieumar??ych, Karthus wy??ania si?? z Wysp Cienia, aby sprowadza?? rado???? ??mierci na ??miertelnik??w.', 2, 2, 10, 7, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Karthus_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Karthus.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Kassadin', 'W??drowiec Pustki', 'Wycinaj??c pal??ce pasma po??r??d najmroczniejszych miejsc na ??wiecie, Kassadin zrozumia??, ??e jego dni s?? policzone. Cho?? by?? obeznanym w ??wiecie przewodnikiem i poszukiwaczem przyg??d z Shurimy, wybra?? spokojne ??ycie z rodzin?? po??r??d po??udniowych plemion ??? do czasu, a?? jego osada zosta??a poch??oni??ta przez Pustk??. Poprzysi??g?? zemst??. W trudn?? podr???? zabra?? wiele magicznych artefakt??w i zakazanych wynalazk??w. Wreszcie Kassadin pod????y?? w stron?? pustkowi Icathii, gotowy stawi?? czo??a wszelakim potworom z Pustki na drodze do odnalezienia ich samozwa??czego proroka Malzahara.', 3, 5, 8, 8, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Kassadin_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Kassadin.png', 'Assassin');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Katarina', 'Z??owieszcze Ostrze', 'Stanowcza w os??dzie i zab??jcza w walce, Katarina jest noxia??sk?? zab??jczyni?? najwi??kszego kalibru. Najstarsza c??rka legendarnego genera??a Du Couteau, ws??awi??a si??  talentami do szybkiego zabijania niczego niepodejrzewaj??cych wrog??w. Jej ognisty zapa?? sprawi??, ??e wybiera dobrze strze??one cele, cz??sto ryzykuj??c ??yciem sojusznik??w. Lecz niezale??nie od zadania, Katarina nie b??dzie waha??a si?? dope??ni?? obowi??zku po??r??d wichury z??bkowanych sztylet??w.', 4, 3, 9, 8, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Katarina_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Katarina.png', 'Assassin');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Kayle', 'Sprawiedliwa', 'Kayle, c??rka targo??skiego Aspektu urodzona w punkcie kulminacyjnym Wojen Runicznych, uhonorowa??a dziedzictwo swojej matki, wznosz??c si?? na skrzyd??ach gorej??cych boskim ogniem, by walczy?? o sprawiedliwo????. Wraz ze swoj?? bli??niaczk?? Morgan?? latami by??y obro??czyniami Demacii ??? dop??ki Kayle nie rozczarowa??a si?? powtarzaj??cymi si?? potkni??ciami ??miertelnik??w i ca??kowicie opu??ci??a ich wymiar. Mimo to legendy o tym, jak kara??a nieprawych swoimi ognistymi mieczami, wci???? s?? opowiadane, a wielu wierzy, ??e pewnego dnia powr??ci...', 6, 6, 7, 7, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Kayle_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Kayle.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Kayn', '??niwiarz Cienia', 'Niemaj??cy sobie r??wnych w praktykowaniu zab??jczej magii cienia, Shieda Kayn toczy boje o swoje prawdziwe przeznaczenie ??? czyli o to, by pewnego dnia poprowadzi?? Zakon Cienia ku nowej erze ionia??skiej dominacji. Pos??uguje si?? ??yw?? broni?? Darkin??w zwan?? Rhaastem, niezra??ony tym, ??e powoli wypacza ona jego cia??o i umys??. Ta sytuacja ma tylko dwa mo??liwe rozwi??zania: albo Kayn zmusi bro?? do pos??usze??stwa... albo z??owieszcze ostrze poch??onie go ca??kowicie, doprowadzaj??c do zniszczenia Runeterry.', 10, 6, 1, 8, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Kayn_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Kayn.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Kennen', 'Serce Nawa??nicy', 'Kennen jest kim?? wi??cej ni?? b??yskawicznie szybkim str????em ionia??skiej r??wnowagi, jest jedynym yordlowym cz??onkiem zakonu Kinkou. Mimo ??e jest ma??ym i w??ochatym stworzeniem, ch??tnie stawi czo??a wszystkim zagro??eniom za pomoc?? wiruj??cej burzy shuriken??w i dzi??ki nieko??cz??cemu si?? entuzjazmowi. U boku swojego mistrza Shena, Kennen patroluje duchowy wymiar, u??ywaj??c niszcz??cej elektrycznej energii, by zabija?? wrog??w.', 6, 4, 7, 4, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Kennen_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Kennen.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Kha''Zix', '??owca Pustki', 'Pustka ro??nie, Pustka ewoluuje ??? to Kha''Zix spo??r??d jej niezliczonych twor??w jest najlepszym tego przyk??adem. Ewolucja nap??dza tego mutuj??cego potwora, stworzonego do przetrwania wszystkiego i zabijania silnych. Je??li mu si?? to nie udaje, wykszta??ca nowe, bardziej efektywne sposoby radzenia sobie z ofiarami. Cho?? z pocz??tku by?? bezmy??ln?? besti??, inteligencja Kha''Zixa rozwin????a si?? tak bardzo jak jego posta??. Teraz, to stworzenie tworzy plany polowa?? i nawet wykorzystuje pierwotny strach, jaki sieje w??r??d ofiar.', 9, 4, 3, 6, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Khazix_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Khazix.png', 'Assassin');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Kindred', 'Wieczni ??owcy', 'Pojedynczo, ale nigdy oddzielnie, Kindred reprezentuj?? bli??niacze esencje ??mierci. Strza??a Owcy oferuje szybki koniec dla tych, kt??rzy pogodzili si?? ze swoim losem. Wilk poluje za?? na tych, kt??rzy uciekaj?? przed przeznaczeniem, brutalnie pozbawiaj??c ofiary wszelkiej nadziei. Cho?? interpretacje tego, czym Kindred s??, r????ni?? si?? w ca??ej Runeterze, ka??dy ??miertelnik musi wybra?? oblicze swojej ??mierci.', 8, 2, 2, 4, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Kindred_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Kindred.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Kled', 'Swarliwy Rajtar', 'Yordle Kled to wojownik r??wnie nieustraszony, co uparty, uosabia za??art?? brawur?? Noxusu. Jest ukochan?? przez ??o??nierzy ikon??, kt??rej nie ufaj?? oficerowie, a arystokracja wr??cz nim pogardza. Liczni utrzymuj??, ??e Kled walczy?? w ka??dej kampanii prowadzonej przez legiony Noxusu, ???zdoby????? wszystkie mo??liwe tytu??y wojskowe i nigdy, ale to przenigdy nie wycofa?? si?? z walki. I cho?? wiarygodno???? tej sprawy cz??stokro?? jest co najmniej w??tpliwa, to jego legenda zawiera w sobie ziarno prawdy: szar??uj??c do bitwy na Skaarl, czyli swej nie do ko??ca godnej zaufania szkapie, Kled broni swej w??asno??ci i stara si?? jak najwi??cej zdoby??.', 8, 2, 2, 7, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Kled_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Kled.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Kog''Maw', 'Paszcza Otch??ani', 'Wypluty z gnij??cego miejsca wtargni??cia Pustki, g????boko na pustkowiach Icathii, Kog''Maw jest ciekawsk??, lecz wstr??tn?? istot?? ze zjadliw??, rozwart?? paszcz??. Ten Pomiot Pustki musi obgry???? i za??lini?? wszystko, co ma pod r??k??, by dog????bnie to zrozumie??. Cho?? nie jest z??o??liwy z natury, urzekaj??ca naiwno???? Kog''Mawa jest niebezpieczna, bo cz??sto poprzedza sza?? jedzenia ??? nie dla przetrwania, lecz dla zaspokojenia ciekawo??ci.', 8, 2, 5, 6, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/KogMaw_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/KogMaw.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('K''Sante', 'Duma Nazumah', 'Nieust??pliwy i odwa??ny K''Sante walczy z pot????nymi bestiami i bezwzgl??dnymi Wyniesionymi, by chroni?? sw??j dom, miasto Nazumah, cudown?? oaz?? po??r??d piask??w Shurimy. Po k????tni ze swoim by??ym partnerem K''Sante zdaje sobie spraw??, ??e by zosta?? wojownikiem godnym przewodzi?? swojemu ludowi, musi utemperowa?? swoje egoistyczne ambicje. Dopiero wtedy b??dzie m??g?? unikn???? stania si?? ofiar?? swojej w??asnej pychy i odnale???? m??dro???? potrzebn??, by pokona?? nikczemne stwory zagra??aj??ce jego pobratymcom.', 8, 8, 7, 9, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/KSante_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/KSante.png', 'Tank');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('LeBlanc', 'Oszustka', 'Tajemnicza nawet dla innych cz??onk??w kliki Czarnej R????y, LeBlanc jest jednym z wielu imion bladej kobiety, kt??ra manipulowa??a lud??mi i wydarzeniami od zarania Noxusu. U??ywaj??c magii, by tworzy?? swoje lustrzane kopie, ta czarodziejka mo??e pojawi?? si?? ka??demu, wsz??dzie i nawet w wielu miejscach naraz. Zawsze knuj??c tu?? poza zasi??giem wzroku, prawdziwe pobudki LeBlanc s?? tak nieprzeniknione jak jej zmienna osobowo????.', 1, 4, 10, 9, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Leblanc_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Leblanc.png', 'Assassin');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Lee Sin', '??lepy Mnich', 'Mistrz sztuk walki Ionii, Lee Sin, jest kieruj??cym si?? zasadami wojownikiem, kt??ry czerpie z esencji duszy smoka, by stawi?? czo??a wszelkim wyzwaniom. Chocia?? straci?? wzrok wiele lat temu, ten mnich-wojownik po??wi??ca swoje ??ycie, by broni?? swoj?? ojczyzn?? przed wszystkimi, kt??rzy chcieliby zak????ci?? jej spok??j. Wrogowie, kt??rzy zlekcewa???? jego oddany medytacji spos??b bycia, bole??nie przekonaj?? si?? o sile jego p??on??cych pi????ci i kopni???? z p????obrotu.', 8, 5, 3, 6, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/LeeSin_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/LeeSin.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Leona', 'Promyk Jutrzenki', 'Leona, dysponuj??ca moc?? s??o??ca, jest ??wi??t?? wojowniczk?? Solari, kt??ra stoi na stra??y G??ry Targon, wyposa??ona w Ostrze Zenitu i Paw???? Brzasku. Jej sk??ra l??ni blaskiem gwiazd, a oczy p??on?? moc?? Aspektu, kt??ry zamieszkuje jej wn??trze. Przyodziana w z??oty pancerz i nosz??ca straszne brzemi?? w postaci staro??ytnej wiedzy, Leona niesie niekt??rym o??wiecenie, a innym ??? ??mier??.', 4, 8, 3, 4, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Leona_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Leona.png', 'Tank');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Lillia', 'L??kliwy Rozkwit', 'Nie??mia??a i p??ochliwa Lillia, wr????kowa sarenka, snuje si?? po lasach Ionii. Ukrywa si?? przed ??miertelnikami, kt??rych tajemnicza natura ju?? dawno j?? urzek??a, ale i przestraszy??a. Ma nadziej?? odkry??, dlaczego ich marzenia nie trafiaj?? ju?? do ??ni??cego Drzewa. Przemierza teraz Ioni?? z magiczn?? ga????zk?? w r??ku, pr??buj??c odnale???? niespe??nione sny ludzi. Tylko wtedy Lillia b??dzie w stanie rozkwitn???? oraz pom??c innym pozby?? si?? obaw, by rozpali?? wewn??trzn?? iskr??. Iip!', 0, 2, 10, 8, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Lillia_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Lillia.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Lissandra', 'Wied??ma Lodu', 'Magia Lissandry przekszta??ca czysty potencja?? lodu w co?? mrocznego i potwornego. Moc?? jej czarnego lodu nie tylko zamra??a przeciwnik??w, ale ich nadziewa i mia??d??y. Przera??eni mieszka??cy p????nocy znaj?? j?? tylko jako ???Wied??m?? Lodu???. Prawda jest du??o bardziej z??owieszcza: Lissandra zatruwa natur?? i chce spowodowa?? epok?? lodowcow?? na ca??ym ??wiecie.', 2, 5, 8, 6, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Lissandra_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Lissandra.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Lucian', 'Kleryk Broni', 'Lucian, dawniej Stra??nik ??wiat??a, sta?? si?? ponurym ??owc?? nieumar??ych duch??w. Jest bezwzgl??dny w ??ciganiu i zabijaniu ich swoimi bli??niaczymi staro??ytnymi pistoletami. Gdy nikczemny upi??r Thresh zabi?? jego ??on??, Lucian zapragn???? zemsty. Jednak nawet po jej powrocie do ??ywych, nie jest w stanie wyzby?? si?? gniewu. Bezwzgl??dny i za??lepiony, nie cofnie si?? przed niczym, aby obroni?? ??yj??cych przed nieumar??ymi koszmarami Czarnej Mg??y.', 8, 5, 3, 6, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Lucian_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Lucian.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Lulu', 'Wr????kowa Czarodziejka', 'Yordlowa czarodziejka Lulu znana jest z tworzenia wy??nionych iluzji i niestworzonych stworze??, przemierzaj??c Runeterr?? wraz ze swoim duszkiem towarzyszem Pixem. Lulu potrafi momentalnie zniekszta??ci?? rzeczywisto????, zakrzywiaj??c materia?? ??wiata i to, co uwa??a za kajdany tego nudnego, fizycznego wymiaru. Niekt??rzy uwa??aj?? jej magi?? za nienaturaln?? w najlepszym wypadku, a za niebezpieczn?? w najgorszym. Lulu wierzy, ??e ka??dy potrzebuje troch?? zaczarowania.', 4, 5, 7, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Lulu_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Lulu.png', 'Support');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Lux', 'Pani Jasno??ci', 'Obro??czyni Korony Luxanna pochodzi z Demacii, krainy, w kt??rej do zdolno??ci magicznych podchodzi si?? z dystansem i strachem. Z powodu umiej??tno??ci w??adania ??wiat??em, dorasta??a w strachu przed tym, ??e kto?? odkryje jej zdolno??ci i j?? wygna. Musia??a trzyma?? swoj?? moc w tajemnicy, by zachowa?? stan szlachecki swojej rodziny. Niemniej jednak, optymizm i wytrwa??o???? Lux pozwoli??y jej na pogodzenie si?? ze swoim wyj??tkowym talentem, kt??rego teraz potajemnie u??ywa, s??u????c ojczy??nie.', 2, 4, 9, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Lux_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Lux.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Malphite', 'Okruch Monolitu', 'Ogromna istota z ??yj??cego kamienia, Malphite stara si?? narzuci?? b??ogos??awiony porz??dek chaotycznemu ??wiatu. Urodzony jako okruch-s??uga obeliskowi z innego ??wiata znanemu jako Monolit, u??ywa?? swojej ogromnej mocy ??ywio????w, by chroni?? i dba?? o swojego prekursora, lecz ostatecznie poni??s?? kl??sk??. Jedyny ocala??y ze zniszczenia jakie nast??pi??o, Malphite zmaga si?? z mi??kkim ludem Runeterry i jego p??ynnymi nastrojami, szukaj??c nowego zadania godnego dla siebie ??? ostatniego z rasy.', 5, 9, 7, 2, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Malphite_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Malphite.png', 'Tank');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Malzahar', 'Prorok Pustki', 'Malzahar, religijny wieszcz, kt??ry po??wi??ca si?? zr??wnaniu wszystkiego, co ??yje, szczerze wierzy, ??e nowo powsta??a Pustka jest drog?? do zbawienia Runeterry. Na pustynnych pustkowiach Shurimy pod????y?? za szeptami w swojej g??owie, kt??re przywiod??y go do pradawnej Icathii. Po??r??d zrujnowanych ziem tamtej krainy spojrza?? prosto w mroczne serce Pustki i otrzyma?? now?? moc i cel ??ycia. Odt??d uwa??a siebie za pasterza, prowadz??cego innych do zagrody... lub wypuszczaj??cego stworzenia, kt??re k????bi?? si?? pod ni??.', 2, 2, 9, 6, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Malzahar_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Malzahar.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Maokai', 'Spaczony Drzewiec', 'Maokai to olbrzymi drzewiec przepe??niony gniewem, kt??ry walczy z koszmarami z Wysp Cienia. Gdy magiczny kataklizm zniszczy?? jego dom, sta?? si?? uciele??nieniem zemsty, opieraj??c si?? nie??mierci tylko dzi??ki wodom ??ycia, kt??re w nim p??yn????y. Niegdy?? Maokai by?? spokojnym duchem natury, ale teraz walczy zawzi??cie, aby pozby?? si?? kl??twy ci??????cej na Wyspach Cienia i przywr??ci?? dawne pi??kno swojemu domowi.', 3, 8, 6, 3, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Maokai_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Maokai.png', 'Tank');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Master Yi', 'Szermierz Wuju', 'Master Yi tak d??ugo trenowa?? cia??o i umys??, ??e my??li i dzia??anie niemal sta??y si?? jedno??ci??. Mimo ??e woli u??ywa?? si??y tylko w ostateczno??ci, zwinno???? i szybko????, z jakimi pos??uguje si?? ostrzem, sprawiaj??, ??e konflikt zawsze ko??czy si?? szybko. Jako jedna z ostatnich ??ywych os??b znaj??cych ionia??sk?? sztuk?? Wuju, Master Yi po??wi??ci?? ??ycie, by piel??gnowa?? tradycje swojego ludu ??? bacznie przygl??da si?? potencjalnym nowym uczniom swoimi Siedmioma Soczewkami Przenikliwo??ci, by sprawdzi??, kt??ry z nich b??dzie najbardziej godny stania si?? adeptem Wuju.', 10, 4, 2, 4, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/MasterYi_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/MasterYi.png', 'Assassin');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Miss Fortune', '??owczyni Nagr??d', 'Pani kapitan Bilgewater, znana ze swojego wdzi??ku, lecz siej??ca strach przez swoj?? bezwzgl??dno????, Sarah Fortune jest surow?? postaci?? g??ruj??c?? nad zatwardzia??ymi kryminalistami miasta portowego. Jako dziecko by??a ??wiadkiem, jak kr??l ??upie??c??w Gangplank zamordowa?? jej rodzin?? ??? czyn, kt??ry brutalnie odp??aci??a lata p????niej, wysadzaj??c jego okr??t flagowy, kiedy Gangplank znajdowa?? si?? na jego pok??adzie. Ci, kt??rzy jej nie doceni??, spotkaj?? si?? z urzekaj??cym i nieprzewidywalnym przeciwnikiem... i pewnie z kul??, lub dwiema, w swoich trzewiach.', 8, 2, 5, 1, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/MissFortune_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/MissFortune.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Wukong', 'Ma??pi Kr??l', 'Wukong to vastaja??ski ??artowni??, kt??ry wykorzystuje si????, zwinno???? i inteligencj??, aby oszuka?? przeciwnik??w i zyska?? przewag??. Po znalezieniu przyjaciela na ca??e ??ycie w osobie wojownika znanego jako Master Yi, Wukong sta?? si?? ostatnim uczniem staro??ytnej sztuki walki znanej jako Wuju. Wukong, uzbrojony w magiczny kostur, pragnie ochroni?? Ioni?? przed zniszczeniem.', 8, 5, 2, 3, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/MonkeyKing_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/MonkeyKing.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Mordekaiser', '??elazny Upi??r', 'Dwa razy zabity i trzy razy zrodzony, Mordekaiser to okrutny wata??ka z zamierzch??ej epoki, kt??ry wykorzystuje moc nekromancji, aby p??ta?? dusze na wieczn?? s??u??b??. Niewielu ju?? pami??ta jego dawne podboje i zdaje sobie spraw?? z pe??ni jego mocy. Istniej?? jednak staro??ytne dusze, kt??re obawiaj?? si?? dnia jego nadej??cia. Dnia, w kt??rym roztoczy swe panowanie nad ??ywymi i umar??ymi.', 4, 6, 7, 4, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Mordekaiser_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Mordekaiser.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Morgana', 'Upad??a', 'Rozdarta pomi??dzy natur?? astraln?? a natur?? ??miertelniczki, Morgana zwi??za??a swoje skrzyd??a, by otworzy?? ramiona na ludzko????, i zadaje wszystkim nieszczerym i zwyrodnia??ym b??l, jaki sama odczuwa. Odrzuca prawa i tradycje, o kt??rych my??li, ??e s?? niesprawiedliwe, i walczy o prawd?? z cieni Demacii ??? nawet gdy inni pr??buj?? j?? st??amsi?? ??? rzucaj??c tarcze i ??a??cuchy z mrocznego ognia. Morgana z ca??ego serca wierzy, ??e nawet wyp??dzeni i wygnani mog?? pewnego dnia podnie???? si?? z kolan.', 1, 6, 8, 1, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Morgana_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Morgana.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Nami', 'W??adczyni Przyp??yw??w', 'Nami, nieust??pliwa, m??oda przedstawicielka Vastaj??w pochodz??cych z m??rz, by??a pierwsz?? z plemienia Maraj??w, kt??ra porzuci??a fale i zapu??ci??a si?? na suchy l??d, kiedy ich staro??ytne porozumienie z Targonianami zosta??o zerwane. Nie maj??c innego wyboru, wzi????a na swoje barki doko??czenie ??wi??tego rytua??u, kt??ry zapewni??by jej ludowi bezpiecze??stwo. Po??r??d chaosu nowej ery, Nami odwa??nie i zdeterminowanie walczy z niepewn?? przysz??o??ci??, u??ywaj??c swojego Kosturu W??adczyni Przyp??yw??w, by przywo??ywa?? pot??g?? ocean??w.', 4, 3, 7, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Nami_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Nami.png', 'Support');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Nasus', 'Kustosz Pustyni', 'Nasus jest majestatycznym, Wyniesionym bytem o g??owie szakala, wywodz??cym si?? z przedwiecznej Shurimy. Herosem, kt??rego ludzie pustyni uwa??ali za p????boga. Jego wyj??tkowa inteligencja sprawi??a, ??e by?? opiekunem wiedzy i niezr??wnanym strategiem, a jego m??dro???? prowadzi??a pradawne imperium Shurimy do wielko??ci przez ca??e stulecia. Po upadku imperium sam narzuci?? sobie wygnanie, staj??c si?? niczym wi??cej ni?? tylko legend??. Teraz, gdy antyczne miasto Shurima raz jeszcze powsta??o z piask??w pustyni, Nasus powr??ci?? i jest got??w po??wi??ci?? ca???? sw?? determinacj??, aby nie dopu??ci?? do jej ponownego upadku.', 7, 5, 6, 6, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Nasus_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Nasus.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Nautilus', 'Tytan G????bin', 'Opancerzony goliat znany jako Nautilus, samotna legenda, stara jak pierwsze pomosty postawione w Bilgewater, w????czy si?? po mrocznych wodach u wybrze??a Wysp Niebieskiego P??omienia. Nap??dzany zapomnian?? zdrad?? uderza bez ostrze??enia, wymachuj??c swoj?? ogromn?? kotwic??, by ratowa?? potrzebuj??cych, a chciwych ??ci??ga?? na dno ku zag??adzie. Podobno przychodzi po tych, kt??rzy zapominaj?? zap??aci?? ???dziesi??ciny Bilgewater??? i wci??ga ich pod tafl?? oceanu. Jest okutym w ??elazo przypomnieniem, ??e nikt nie ucieknie przed g????binami.', 4, 6, 6, 6, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Nautilus_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Nautilus.png', 'Tank');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Neeko', 'Ciekawski Kameleon', 'Neeko, pochodz??ca z dawno utraconego plemienia Vastaj??w, potrafi wtopi?? si?? w ka??dy t??um, po??yczaj??c wygl??d innych, a nawet wch??aniaj??c co?? pokroju ich stanu emocjonalnego, by w mgnieniu oka odr????ni?? wroga od przyjaciela. Nikt nie mo??e by?? nigdy pewien, gdzie ??? ani kim ??? jest Neeko, ale ci, kt??rzy chc?? j?? skrzywdzi??, szybko poznaj?? jej prawdziw?? natur?? i poczuj?? na sobie ca???? pot??g?? jej pierwotnego ducha.', 1, 1, 9, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Neeko_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Neeko.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Nidalee', 'Zwierz??ca ??owczyni', 'Wychowana w najg????bszej d??ungli, Nidalee jest mistrzowsk?? tropicielk??, kt??ra na zawo??anie potrafi przemieni?? si?? w pum??. Nie jest w pe??ni kobiet?? ani besti??. Zaciekle broni swojego terytorium przed wszystkimi intruzami za pomoc?? rozmy??lnie umieszczonych pu??apek i wprawnych rzut??w oszczepem. Unieruchamia swoj?? zdobycz, zanim skoczy na ni?? w kociej formie. Ci szcz????ciarze, kt??rzy przetrwaj??, opowiadaj?? historie o dzikiej kobiecie z wyostrzonymi zmys??ami i ostrymi pazurami...', 5, 4, 7, 8, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Nidalee_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Nidalee.png', 'Assassin');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Nilah', 'Nieokie??znana rado????', 'Nilah to ascetyczna wojowniczka z odleg??ej krainy, poszukuj??ca jak najgro??niejszych i najpot????niejszych przeciwnik??w, aby rzuca?? im wyzwania. Swoj?? pot??g?? posiad??a dzi??ki pojedynkowi z d??ugo wi??zionym demonem rado??ci, a jedyn?? emocj??, jaka jej pozosta??a, jest nieprzerwana euforia. Zap??aci??a wi??c niewielk?? cen?? za ogromn?? si????, kt??r?? teraz dysponuje. Nilah koncentruje p??ynn?? posta?? demona w ostrze o niezr??wnanej mocy, aby broni?? ??wiat przed dawno zapomnianymi, staro??ytnymi zagro??eniami.', 8, 4, 4, 10, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Nilah_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Nilah.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Nocturne', 'Wieczny Koszmar', 'Demoniczne wcielenie, stworzone z koszmar??w nawiedzaj??cych wszystkie umys??y, jest znane jako Nocturne ??? przedwieczna si??a czystego z??a. Jego forma jest p??ynnym chaosem, cieniem bez twarzy z zimnymi oczami, uzbrojonym w z??owieszczo wygl??daj??ce ostrza. Po uwolnieniu si?? z duchowego wymiaru, Nocturne zacz???? grasowa?? po ??wiecie, by ??erowa?? na rodzaju strachu, kt??ry istnieje tylko w ca??kowitej ciemno??ci.', 9, 5, 2, 4, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Nocturne_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Nocturne.png', 'Assassin');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Nunu i Willump', 'Ch??opiec i Jego Yeti', 'Dawno, dawno temu by?? sobie ch??opiec, kt??ry chcia?? dowie????, ??e jest bohaterem, zabijaj??c straszliwego potwora. Zamiast tego odkry?? jedynie, ??e ten stw??r, samotny i magiczny yeti, po prostu potrzebowa?? przyjaciela. Zbratani staro??ytn?? moc?? i wsp??ln?? mi??o??ci?? do ??nie??ek, Nunu i Willump tu??aj?? si?? teraz po Freljordzie, wcielaj??c w ??ycie zmy??lone przygody. Maj?? nadziej??, ??e znajd?? gdzie?? tam matk?? Nunu. Je??eli uda im si?? j?? uratowa??, by?? mo??e w ko??cu zostan?? bohaterami...', 4, 6, 7, 4, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Nunu_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Nunu.png', 'Tank');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Olaf', 'Berserker', 'Niepowstrzymana si??a zniszczenia, dzier????cy topory Olaf nie chce nic wi??cej poza chwalebn?? ??mierci?? w boju. Pochodzi z Lokfaru, surowego freljordzkiego p????wyspu. Kiedy?? przepowiedziano mu spokojn?? ??mier?? ??? los tch??rza i ogromna ujma po??r??d jego ludu. Nap??dzany gniewem Olaf pustoszy?? ziemie w poszukiwaniu ??mierci, zabijaj??c niezliczone ilo??ci wspania??ych wojownik??w i legendarnych potwor??w. Szuka?? przeciwnika, kt??ry m??g??by go zatrzyma??. Teraz jest brutalnym wykidaj???? Zimowego Szponu, szukaj??cym swojego kresu w zapowiadanych wielkich wojnach.', 9, 5, 3, 3, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Olaf_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Olaf.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Orianna', 'Mechaniczna Baletnica', 'Kiedy?? dziewczyna z krwi i ko??ci, Orianna jest teraz cudem techniki w ca??o??ci skonstruowanym z mechanicznych cz????ci. Po wypadku w ni??szych dzielnicach Zaun ??miertelnie zachorowa??a, a jej konaj??ce cia??o musia??o zosta?? wyj??tkowo uwa??nie zast??pione, kawa??ek po kawa??ku. Maj??c u boku niezwyk???? mosi????n?? kul??, kt??r?? zbudowa??a dla towarzystwa i ochrony, Orianna mo??e dowolnie odkrywa?? cuda Piltover i nie tylko.', 4, 3, 9, 7, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Orianna_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Orianna.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Ornn', 'Ogie?? z Wn??trza G??ry', 'Ornn to duch Freljordu, opiekun kowali i rzemie??lnik??w. Pracuje w samotno??ci w ogromnej ku??ni wykutej w magmowych jaskiniach skrytych we wn??trzu wulkanu zwanego Palenisko. Zajmuje si?? podsycaniem ognia pod kot??ami z p??ynn?? law??, by uszlachetnia?? kruszce i tworzy?? z nich przedmioty o niezr??wnanej jako??ci. Za ka??dym razem, gdy inne b??stwa ??? a szczeg??lnie Volibear ??? stawiaj?? stop?? na ziemi i wtr??caj?? si?? w ludzkie sprawy, Ornn pokazuje zapalczywym istotom, gdzie jest ich miejsce, wspomagaj??c si?? swoim zaufanym m??otem lub ognist?? pot??g?? g??r.', 5, 9, 3, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Ornn_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Ornn.png', 'Tank');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Pantheon', 'Niezniszczalna W????cznia', 'Atreus, niegdy?? oporny no??nik Aspektu Wojny, prze??y??, gdy boska moc zosta??a w nim zg??adzona, i nie ugi???? si?? pod ciosem, kt??ry zdar?? gwiazdy z niebosk??onu. Z czasem otworzy?? si?? na moc w??asnej ??miertelno??ci i wytrwa??o????, kt??ra si?? z ni?? wi????e. Teraz Atreus sprzeciwia si?? bosko??ci jako odrodzony Pantheon, a na polu bitwy jego niez??omna wola przepe??nia bro?? upad??ego Aspektu.', 9, 4, 3, 4, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Pantheon_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Pantheon.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Poppy', 'Stra??niczka M??ota', 'W krainie Runeterry nie brakuje dzielnych bohater??w, ale niewielu spo??r??d nich jest tak nieust??pliwych jak Poppy. Dzier????c legendarny m??ot Orlona, bro?? dwa razy wi??ksz?? od niej, ta zdeterminowana Yordlka sp??dzi??a ju?? wiele lat na poszukiwaniu mitycznego ???Bohatera Demacii???, kt??ry wed??ug opowie??ci jest prawowitym w??a??cicielem broni. Dop??ki to nie nast??pi, dzielnie rzuca si?? do walki, odpychaj??c wrog??w kr??lestwa ka??dym wiruj??cym uderzeniem.', 6, 7, 2, 6, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Poppy_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Poppy.png', 'Tank');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Pyke', 'Rozpruwacz z Krwawego Portu', 'Pyke, znany harpunnik z Dok??w Rzezi w Bilgewater, powinien by?? umrze?? w ??o????dku ryby giganta... ale jednak powr??ci??. Teraz nawiedza zawilgotnia??e uliczki oraz zakamarki swojego dawnego miasta i u??ywa swych nowych nadnaturalnych dar??w, by nie???? szybk?? i okrutn?? ??mier?? wszystkim, kt??rzy zbijaj?? fortun??, wykorzystuj??c innych. W ten spos??b miasto, kt??re szczyci si?? polowaniem na potwory, samo znalaz??o si?? w pozycji ofiary potwora.', 9, 3, 1, 7, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Pyke_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Pyke.png', 'Support');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Qiyana', 'Cesarzowa ??ywio????w', 'W po??o??onym w d??ungli mie??cie Ixaocan Qiyana bez skrupu????w planuje w??asn?? ??cie??k?? na tron Yun Tal. Jest ostatnia w kolejce do odziedziczenia w??adzy po rodzicach, ale mierzy si?? ze wszystkimi na swojej drodze z bezczeln?? pewno??ci?? siebie i niespotykanym wcze??niej opanowaniem magii ??ywio????w. Sama ziemia s??ucha ka??dego jej rozkazu, wi??c Qiyana postrzega siebie jako najwi??ksz?? mistrzyni?? ??ywio????w w historii Ixaocanu ??? i z tego tytu??u uwa??a, ??e zas??uguje nie tylko na miasto, ale i ca??e imperium.', 0, 2, 4, 8, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Qiyana_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Qiyana.png', 'Assassin');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Quinn', 'Skrzyd??a Demacii', 'Quinn to elitarna zwiadowczyni rycerstwa z Demacii, kt??ra wykonuje niebezpieczne misje g????boko na terytorium wroga. J?? i jej legendarnego or??a Valora ????czy wyj??tkowa, nierozerwalna wi????, dzi??ki kt??rej tworz?? tak skuteczny duet, ??e ich przeciwnicy gin??, zanim si?? zorientuj??, ??e nie walcz?? z jednym, lecz dwoma bohaterami Demacii. Zwinna i akrobatyczna, kiedy zajdzie taka potrzeba, Quinn u??ywa kuszy, a Valor oznacza nieuchwytne cele z g??ry, co czyni ich zab??jcz?? par?? na polu walki.', 9, 4, 2, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Quinn_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Quinn.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Rakan', 'Uwodziciel', 'R??wnie energiczny, co czaruj??cy, Rakan to s??ynny vastaja??ski m??ciciel i najwspanialszy tancerz bitewny w historii plemienia Lhotlan. Ludzie z wy??yn Ionii od dawna kojarz?? jego imi?? z dzikimi zabawami, nieokie??znanymi imprezami i anarchistyczn?? muzyk??. Niewielu mog??oby podejrzewa??, ??e ten pe??en energii podr????uj??cy artysta jest partnerem buntowniczki Xayah i sprzyja jej sprawie.', 2, 4, 8, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Rakan_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Rakan.png', 'Support');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Rammus', 'Pancerznik', 'Idol dla wielu, wyrzutek w oczach nielicznych, i wielka tajemnica dla wszystkich. Mowa o Rammusie, osobliwym stworzeniu, b??d??cym prawdziw?? zagadk??. Na temat pochodzenia tej skrywaj??cej swoje oblicze pod kolczast?? skorup?? istoty istnieje wiele sprzecznych teorii. Jedni nazywaj?? go p????bogiem, drudzy ??? ??wi??t?? wyroczni??, a inni zrodzonym z magii potworem. Bez wzgl??du na to, jaka jest prawda, Rammus nie zdradza nikomu swych sekret??w i nie przerywa swojej w??dr??wki przez pustyni?? Shurimy na niczyj?? pro??b??.', 4, 10, 5, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Rammus_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Rammus.png', 'Tank');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Rek''Sai', 'Furia Pustki', 'Rek''Sai to bezlitosny Pomiot Pustki, idealna drapie??niczka, kopi??ca tunele pod ziemi??, by chwyta?? i po??era?? nic niepodejrzewaj??ce ofiary. Jej nienasycony g????d odpowiada za zniszczenie ca??ych region??w niegdy?? wspania??ego imperium Shurimy ??? kupcy, handlarze, a nawet uzbrojone karawany nad??o???? setki kilometr??w drogi, by omin???? ziemie, na kt??rych poluje ona i jej potomstwo. Wszyscy wiedz??, ??e kiedy zauwa??y si?? Rek''Sai na horyzoncie, ??mier?? spod ziemi jest nieunikniona.', 8, 5, 2, 3, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/RekSai_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/RekSai.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Rell', '??elazna M??cicielka', 'Rell, produkt brutalnych eksperyment??w Czarnej R????y, to zbuntowana ??ywa bro??, kt??rej celem jest obalenie Noxusu. Jej dzieci??stwo pe??ne by??o n??dzy i okrucie??stwa ??? przetrwa??a niewyobra??alne zabiegi maj??ce na celu udoskonalenie oraz opanowanie jej magicznej kontroli nad metalem??? a?? do gwa??townej ucieczki, podczas kt??rej zabi??a wielu swoich oprawc??w. Teraz, okrzykni??ta mianem kryminalistki, bez zastanowienia napada na noxia??skich ??o??nierzy. Szuka ocala??ych z dawnej ???akademii???, broni s??abszych i jednocze??nie zadaje swoim by??ym prze??o??onym brutaln?? ??mier??.', 0, 0, 0, 0, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Rell_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Rell.png', 'Tank');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Renata Glasc', 'Chembaronessa', 'Renata Glasc powsta??a z popio????w swego rodzinnego domu. Nie mia??a niczego poza nazwiskiem i alchemicznymi badaniami swoich rodzic??w. W ci??gu kolejnych dziesi??cioleci sta??a si?? najbogatsz?? chembaroness?? w Zaun i magnatk?? biznesu, kt??ra zbudowa??a swoj?? pot??g?? dzi??ki wi??zaniu interes??w innych z w??asnymi. Dzia??aj z ni??, a nagrodom nie b??dzie ko??ca. Dzia??aj przeciwko niej, a po??a??ujesz swojej decyzji. Ostatecznie jednak ka??dy i tak przechodzi na jej stron??.', 2, 6, 9, 8, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Renata_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Renata.png', 'Support');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Renekton', 'Pustynny Rze??nik', 'Wywodz??cy si?? ze spalonych s??o??cem pusty?? Shurimy Renekton jest przera??aj??cym, Wyniesionym bytem, kt??rego nap??dza furia. Niegdy?? by?? wojownikiem ciesz??cym si?? najwi??ksz?? estym?? w ca??ym imperium i prowadzi?? armie swojego pa??stwa ku niezliczonym wiktoriom. Gdy jednak imperium upad??o, zosta?? pogrzebany pod jego piaskami i powoli, w miar?? jak zmienia?? si?? ??wiat, Renekton popad?? w szale??stwo. Teraz, odzyskawszy wolno????, jest ca??kowicie poch??oni??ty ch??ci?? odnalezienia i u??miercenia swego brata Nasusa, kt??rego w swym szale??stwie obwinia o sp??dzone w mroku stulecia.', 8, 5, 2, 3, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Renekton_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Renekton.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Rengar', '??owca', 'Rengar to dziki vastaja??ski ??owca trofe??w, kt??ry ??yje dla polowa?? na niebezpieczne stworzenia. Przemierza ??wiat w poszukiwaniu najstraszniejszych bestii, jakie mo??e znale????. Szczeg??lnie zale??y mu na ??ladach Kha''Zixa, stworzenia z Pustki, kt??re pozbawi??o go oka. Rengar nie ??ledzi ofiar ze wzgl??du na po??ywienie czy chwa????, ale dla samego pi??kna po??cigu.', 7, 4, 2, 8, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Rengar_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Rengar.png', 'Assassin');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Riven', 'Wygnaniec', 'Kiedy?? Riven by??a mistrzyni?? miecza w noxia??skim korpusie wojennym, a teraz jest wygna??cem na ziemi, kt??r?? kiedy?? chcia??a podbi??. Si??a jej przekonania i brutalna efektywno???? zapewni??y jej szybki awans i nagrod?? ??? legendarne runiczne ostrze i w??asny oddzia??. Jednak??e na froncie wojny z Ioni?? wiara Riven w ojczyzn?? zosta??a poddana pr??bie i ostatecznie z??amana. Odci??wszy si?? kompletnie od imperium, Riven szuka teraz swojego miejsca w zniszczonym ??wiecie, cho?? pojawiaj?? si?? pog??oski o tym, ??e sam Noxus zosta??... przekuty.', 8, 5, 1, 8, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Riven_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Riven.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Rumble', 'Zmechanizowany Zabijaka', 'Rumble to m??ody, temperamentny wynalazca. U??ywaj??c tylko swoich r??k i kupy z??omu, ten zadziorny Yordle zbudowa?? ogromnego mecha, wyposa??onego w arsena?? elektroharpun??w i rakiet zapalaj??cych. Rumble''owi nie przeszkadza, ??e kto?? pogardza jego tworami ze z??omowiska ??? koniec ko??c??w, to on ma ogniopluj.', 3, 6, 8, 10, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Rumble_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Rumble.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Ryze', 'Mag Run', 'Ryze jest pradawnym, nadzwyczaj zawzi??tym arcymagiem, powszechnie uwa??anym za jednego z najznamienitszych przedstawicieli tej??e profesji w ??wiecie Runeterry. I nosi na swych barkach niewyobra??alnie ci????kie brzemi??. Uzbrojony w niczym nieograniczon??, ezoteryczn?? moc i twardy charakter, niestrudzenie poszukuje Run ??wiata ??? fragment??w czystej magii, kt??ra niegdy?? uformowa??a ??wiat z nico??ci. Musi je odszuka??, nim wpadn?? w niew??a??ciwe r??ce, poniewa?? Ryze wie, jakie koszmary mog?? uwolni?? na Runeterr??.', 2, 2, 10, 7, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Ryze_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Ryze.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Samira', 'R????a Pustyni', 'Samira z niezachwian?? pewno??ci?? siebie patrzy ??mierci prosto w oczy i szuka dreszczyku emocji, gdziekolwiek zmierza. Jej dom w Shurimie zniszczono, gdy by??a jeszcze dzieckiem. Nied??ugo p????niej odkry??a swoje prawdziwe powo??anie w Noxusie, gdzie zapracowa??a na reputacj?? stylowej i nieustraszonej wojowniczki, podejmuj??cej si?? niebezpiecznych misji najwy??szego kalibru. Samira dzier??y pistolety i specjalnie zaprojektowany miecz. Nic wi??c dziwnego, ??e najlepiej radzi sobie w sytuacjach na granicy ??ycia i ??mierci, z b??yskiem i rozmachem eliminuj??c ka??dego, kto stanie jej na drodze.', 8, 5, 3, 6, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Samira_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Samira.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Sejuani', 'Gniew P????nocy', 'Sejuani jest brutaln??, surow?? zrodzon?? z lodu matk?? wojny Zimowego Szponu, jednego z najstraszniejszych plemion Freljordu. Jej ludzie tocz?? b??j o przetrwanie z ??ywio??ami, zmuszaj??c ich do naje??d??ania Noxian, Demacian i Avarosan, by prze??y?? srogie zimy. Sejuani przewodzi najniebezpieczniejszym z tych atak??w z siod??a swojego ogromnego dzika Bristle''a i u??ywa korbacza z Prawdziwego Lodu, by zamra??a?? i roztrzaskiwa?? przeciwnik??w.', 5, 7, 6, 4, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Sejuani_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Sejuani.png', 'Tank');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Senna', 'Odkupicielka', 'Senna, na kt??rej od dziecka ci????y kl??twa powoduj??ca prze??ladowanie przez nienaturaln?? Czarn?? Mg????, do????czy??a do ??wi??tego zakonu o nazwie Stra??nicy ??wiat??a i zawzi??cie stawia??a jej op??r. Umar??a jednak, a jej dusza zosta??a uwi??ziona w latarni przez okrutnego upiora, Thresha. Nie trac??c nadziei, Senna nauczy??a si?? wykorzystywa?? Mg???? i gdy wydosta??a si?? na wolno????, by??a odmieniona na zawsze. Teraz jako bro?? wykorzystuje i ciemno????, i ??wiat??o. Chce po??o??y?? kres Czarnej Mgle, zwracaj??c j?? przeciw sobie samej ??? ka??dym wystrza??em swojego reliktowego dzia??a odkupuje zagubione w niej dusze.', 7, 2, 6, 7, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Senna_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Senna.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Seraphine', 'Rozmarzona Piosenkarka', 'Seraphine, urodzona w Piltover w zau??skiej rodzinie, s??yszy dusze innych ??? ??wiat ??piewa do niej, a ona mu odpowiada. Cho?? te d??wi??ki przyt??acza??y j?? w m??odo??ci, teraz czerpie z nich inspiracj??, zamieniaj??c chaos w symfoni??. Wyst??puje w siostrzanych miastach, aby przypomnie?? mieszka??com, ??e nie s?? sami, ??e razem s?? silniejsi i ??e w jej oczach ich potencja?? jest nieograniczony.', 0, 0, 0, 0, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Seraphine_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Seraphine.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Sett', 'Szef', 'Sett, przyw??dca rozwijaj??cego si?? ionia??skiego p??????wiatka, zyska?? s??aw?? w nast??pstwie wojny z Noxusem. Mimo ??e zaczyna?? jako skromny pretendent w nielegalnych walkach w Navori, szybko zyska?? z???? s??aw??, w czym pomog??y mu jego zwierz??ca si??a oraz wytrzyma??o????. Sett wdrapa?? si?? po szczeblach hierarchii miejscowych wojownik??w a?? na sam jej szczyt, a nast??pnie zaw??adn???? aren??, na kt??rej sam kiedy?? wyst??powa??.', 8, 5, 1, 2, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Sett_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Sett.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Shaco', 'Demoniczny B??azen', 'Stworzony dawno temu jako zabawka dla samotnego ksi??cia, zaczarowana marionetka Shaco czerpie przyjemno???? z mordowania i siania zniszczenia. Spaczony przez czarn?? magi?? i utrat?? ukochanego w??a??ciciela, ta kiedy?? mi??a pacynka delektuje si?? tylko cierpieniem biednych dusz, kt??re dr??czy. Zab??jczo u??ywa zabawek i prostych sztuczek, a skutki swoich krwawych ???gierek??? uwa??a za prze??mieszne. Ci, kt??rzy us??yszeli mroczny ??miech w ciemn?? noc, mog?? czu?? si?? naznaczeni przez Demonicznego B??azna ??? b??dzie si?? nimi bawi??.', 8, 4, 6, 9, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Shaco_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Shaco.png', 'Assassin');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Shen', 'Oko Zmierzchu', 'Shen Oko Zmierzchu jest przyw??dc?? po??r??d sekretnego zakonu wojownik??w znanych jako Kinkou. Pragn??c pozosta?? wolnym od wprowadzaj??cych zam??t emocji, uprzedze?? i ego, nieustannie stara si?? pod????a?? ukryt?? ??cie??k?? ch??odnego, beznami??tnego os??du pomi??dzy ??wiatem duchowym a rzeczywistym. Shen, na kt??rego barki spad??o zadanie utrzymywania r??wnowagi pomi??dzy tymi ??wiatami, nie zawaha si?? u??y?? stalowych ostrzy, przepe??nionych tajemn?? energi?? przeciwko ka??demu, kto mu w tym przeszkodzi.', 3, 9, 3, 4, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Shen_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Shen.png', 'Tank');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Shyvana', 'P????smok', 'Shyvana to stworzenie, w kt??rego sercu p??onie magiczny od??amek runy. Chocia?? cz??sto przybiera humanoidaln?? posta??, w ka??dej chwili mo??e zmieni?? si?? w gro??nego smoka, kt??ry spopiela wrog??w ognistym oddechem. Uratowawszy koronnemu ksi??ciu Jarvanowi IV ??ycie, Shyvana s??u??y teraz w szeregach jego kr??lewskiej stra??y i niezmiennie stara si??, by nieufni Demacianie przyj??li j?? tak??, jaka jest.', 8, 6, 3, 4, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Shyvana_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Shyvana.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Singed', 'Szalony Chemik', 'Singed jest zau??skim alchemikiem o niedo??cignionej inteligencji, kt??ry po??wi??ci?? ??ycie, by poszerza?? granice wiedzy za ka??d?? cen??. Sam zap??aci?? najwy??sz?? z nich ??? oszala??. Czy w jego szale??stwie jest metoda? Jego mikstury rzadko okazuj?? si?? by?? trefne, ale wielu uwa??a, ??e Singed straci?? wszelkie poczucie cz??owiecze??stwa i pozostawia za sob?? szlak cierpienia i terroru, gdziekolwiek si?? pojawi.', 4, 8, 7, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Singed_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Singed.png', 'Tank');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Sion', 'Nieumar??y Niszczyciel', 'Bohater wojenny minionej epoki, Sion by?? czczony w Noxusie za w??asnor??czne uduszenie kr??la Demacii, lecz nie by??o mu dane popa???? w zapomnienie ??? zosta?? wskrzeszony, aby m??g?? s??u??y?? imperium nawet po ??mierci. Rze??, kt??r?? rozp??ta??, poch??on????a wszystkich niezale??nie od przynale??no??ci, co dowiod??o, ??e nie zosta??o w nim nic ludzkiego. Nawet teraz, maj??c prymitywn?? zbroj?? przykr??con?? do gnij??cego cia??a, Sion rzuca si?? w ka??dy b??j, niewiele o tym my??l??c, i pomi??dzy atakami wykonywanymi swoj?? pot????n?? siekier?? pr??buje sobie przypomnie??, jaki by?? kiedy??.', 5, 9, 3, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Sion_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Sion.png', 'Tank');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Sivir', 'Pani Wojny', 'Sivir jest znan?? poszukiwaczk?? skarb??w i przyw??dczyni?? najemnik??w, kt??ra oferuje swoje us??ugi na pustyniach Shurimy. Uzbrojona w legendarn??, zdobion?? klejnotami bro??, stoczy??a i wygra??a niezliczon?? liczb?? bitew dla tych, kt??rych sta?? na pokrycie jej wyg??rowanego honorarium. Znana ze swej nieustraszonej determinacji i niesko??czonej ambicji, z dum?? trudzi si?? odzyskiwaniem pogrzebanych skarb??w z niebezpiecznych grobowc??w Shurimy ??? rzecz jasna za cen?? sowitej nagrody. Teraz, kiedy pradawne si??y na nowo trz??s?? Shurim?? w podstawach, Sivir znalaz??a si?? w sytuacji rozdarcia mi??dzy koliduj??cymi ze sob?? ??cie??kami przeznaczenia.', 9, 3, 1, 4, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Sivir_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Sivir.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Skarner', 'Kryszta??owy Stra??nik', 'Skarner to olbrzymi kryszta??owy skorpion pochodz??cy z ukrytej doliny w Shurimie. Nale??y do staro??ytnej rasy Brackern??w, kt??ra s??ynie z wyj??tkowej m??dro??ci i g????bokiej wi??zi z ziemi??. Dusze Brackern??w s?? po????czone z pot????nymi kryszta??ami mieszcz??cymi w sobie my??li i wspomnienia ich przodk??w. Wieki temu przedstawiciele tej rasy zapadli w sen, kt??ry uchroni?? ich przed niechybn?? ??mierci?? w wyniku pot????nych magicznych zawirowa??, jednak z??owieszcze wydarzenia niedawnych dni przebudzi??y Skarnera. Jako jedyny przebudzony Brackern, Skarner stara si?? broni?? swych pobratymc??w przed wszelkimi zagro??eniami.', 7, 6, 5, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Skarner_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Skarner.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Sona', 'Wirtuozka Strun', 'Sona jest najprzedniejsz?? wirtuozk?? etwahlu w Demacii. Za pomoc?? swojego instrumentu przemawia pe??nymi wdzi??ku akordami i niesamowitymi ariami. Dzi??ki swoim dystyngowanym manierom zjedna??a sobie serca szlachty, lecz niekt??rzy podejrzewaj??, ??e jej czaruj??ce melodie emanuj?? magi??, kt??ra jest zakazana w Demacii. Cicha dla nieznajomych, jako?? rozumiana przez bliskich towarzyszy, Sona wygrywa harmonie nie tylko po to, by nie???? ukojenie rannym sojusznikom, ale i by powala?? niczego niespodziewaj??cych si?? wrog??w.', 5, 2, 8, 4, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Sona_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Sona.png', 'Support');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Soraka', 'Gwiezdne Dziecko', 'W??drowniczka z astralnych wymiar??w ponad G??r?? Targon, Soraka porzuci??a nie??miertelno???? na rzecz obrony ras ??miertelnik??w przed ich w??asnymi, bardziej brutalnymi instynktami. Przemierza ??wiat, by dzieli?? si?? cnotami wsp????czucia i lito??ci ze wszystkim napotkanymi lud??mi, lecz??c nawet tych, kt??rzy jej z??orzecz??. Pomimo ca??ego z??a, kt??re widzia??a, Soraka dalej wierzy, ??e ludzie z Runeterry wci???? nie osi??gn??li swojego potencja??u.', 2, 5, 7, 3, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Soraka_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Soraka.png', 'Support');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Swain', 'Wielki Genera?? Noxusu', 'Jericho Swain jest wizjonerskim przyw??dc?? Noxusu, ekspansjonistycznego narodu, kt??ry uznaje tylko si????. Mimo ??e podczas wojen z Ioni?? dozna?? powa??nego uszczerbku na zdrowiu, zar??wno fizycznym ??? jego lewa r??ka zosta??a odci??ta ??? jak i psychicznym, uda??o mu si?? przej???? w??adz?? nad imperium dzi??ki bezwzgl??dnej determinacji... i nowej, demonicznej d??oni. Dzi?? Swain wydaje rozkazy z pierwszej linii, maszeruj??c naprzeciw nadchodz??cej ciemno??ci, kt??r?? tylko on mo??e zobaczy?? w kr??tkich, pourywanych wizjach zbieranych przez mroczne kruki z cia?? poleg??ych wok???? niego. W wirze ofiar i tajemnic najwi??kszym misterium jest fakt, ??e prawdziwy wr??g siedzi w nim samym.', 2, 6, 9, 8, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Swain_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Swain.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Sylas', 'Wyzwolony z Kajdan', 'Wychowany w jednym z gorszych region??w Demacii, Sylas z Och??apiska sta?? si?? symbolem mrocznej strony Wielkiego Miasta. Kiedy by?? ch??opcem, jego zdolno???? do odszukiwania ukrytej magii przyku??a uwag?? s??ynnych ??owc??w mag??w, kt??rzy ostatecznie wtr??cili go do wi??zienia za obr??cenie tej mocy przeciwko nim. Wydostawszy si?? na wolno????, Sylas wiedzie ??ycie zahartowanego rewolucjonisty i u??ywa magii znajduj??cych si?? wok???? niego os??b, by niszczy?? kr??lestwo, kt??remu kiedy?? s??u??y??... a grono jego wyznawc??w z??o??one z wygnanych mag??w zdaje si?? rosn???? z dnia na dzie??.', 3, 4, 8, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Sylas_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Sylas.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Syndra', 'Mroczna W??adczyni', 'Syndra to siej??ca strach ionia??ska czarodziejka, dysponuj??ca ogromn?? moc??. Kiedy by??a dzieckiem, jej nieujarzmiona, dzika magia budzi??a niepok??j w sercach cz??onk??w starszyzny wioski. Zosta??a odes??ana, by nauczy?? si?? nad ni?? panowa??, ale z czasem odkry??a, ??e jej mentor os??abia?? jej zdolno??ci. Przekszta??caj??c poczucie zdrady i cierpienie w mroczne kule energii, Syndra poprzysi??g??a zniszczy?? wszystkich, kt??rzy cho??by spr??bowali j?? kontrolowa??.', 2, 3, 9, 8, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Syndra_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Syndra.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Tahm Kench', 'Rzeczny Kr??l', 'Demon Tahm Kench, znany pod wieloma innymi imionami, podr????uje drogami wodnymi Runeterry, karmi??c sw??j niezaspokojony g????d cierpieniem innych. Cho?? mo??e si?? wydawa?? niezwykle czaruj??cy i dumny, kroczy przez fizyczny ??wiat jak w????cz??ga w poszukiwaniu niczego niepodejrzewaj??cych ofiar. Smagni??cie jego j??zyka og??uszy nawet ci????kozbrojnego wojownika z odleg??o??ci tuzina krok??w, a trafi?? do jego burcz??cego brzucha to jakby wpa???? do otch??ani, z kt??rej niepodobna si?? wydosta??.', 3, 9, 6, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/TahmKench_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/TahmKench.png', 'Support');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Taliyah', 'Tkaczka Ska??', 'Taliyah to w??drowna czarodziejka z Shurimy, rozdarta pomi??dzy m??odzie??czym zachwytem a doros???? odpowiedzialno??ci??. Przemierzy??a prawie ca??y Valoran podczas podr????y, kt??rej celem jest nauka panowania nad jej rosn??cymi mocami, cho?? ostatnio powr??ci??a, by chroni?? swoje plemi??. Niekt??rzy odczytali jej sk??onno???? do wsp????czucia jako oznak?? s??abo??ci i gorzko zap??acili za ten b????d. Pod m??odzie??cz?? postaw?? Taliyah kryje si?? wola mog??ca przenosi?? g??ry i duch tak niez??omny, ??e a?? ziemia dr??y pod jej stopami.', 1, 7, 8, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Taliyah_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Taliyah.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Talon', 'Cie?? Ostrza', 'Talon jest no??em kryj??cym si?? w ciemno??ci, bezlitosnym zab??jc??, gotowym uderzy?? bez ostrze??enia i uciec, zanim ktokolwiek si?? zorientuje. Zdoby?? niebezpieczn?? reputacj?? na brutalnych ulicach Noxusu, gdzie zmuszony by?? walczy??, zabija?? i kra????, by prze??y??. Przygarni??ty przez s??ynn?? rodzin?? Du Couteau, korzysta teraz ze swoich zab??jczych umiej??tno??ci na rozkaz imperium, zabijaj??c wrogich dow??dc??w, kapitan??w i bohater??w... jak i wszystkich Noxian wystarczaj??co g??upich, by splami?? sw??j honor w oczach pan??w.', 9, 3, 1, 7, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Talon_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Talon.png', 'Assassin');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Taric', 'Tarcza Valoranu', 'Taric jest Aspektem Protektora, obdarzonym niezwyk???? moc?? stra??nikiem ??ycia, mi??o??ci i pi??kna na Runeterze. Znies??awiony za porzucenie obowi??zk??w i wygnany z Demacii, swojej ojczyzny, wspi???? si?? na G??r?? Targon, aby znale???? odkupienie, ale zamiast tego odkry?? wy??sze powo??anie po??r??d gwiazd. Taric Tarcza Valoranu, przepe??niony moc?? staro??ytnego Targonu, stoi na stra??y, aby chroni?? ludzi przed spaczeniem Pustki.', 4, 8, 5, 3, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Taric_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Taric.png', 'Support');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Teemo', 'Chy??y Zwiadowca', 'Nie bacz??c na najbardziej niebezpieczne przeszkody, Teemo przemierza ??wiat z nieko??cz??cym si?? entuzjazmem i rado??ci??. Jako Yordle z niezachwianym poczuciem moralno??ci, jest dumny z przestrzegania Kodeksu Harcerza Bandle, czasami do takiego stopnia, ??e nie zdaje sobie sprawy z konsekwencji jego czyn??w. Niekt??rzy m??wi??, ??e istnienie Zwiadowc??w jest w??tpliwe, lecz jedna rzecz jest pewna: z os??dem Teemo nie mo??na dyskutowa??.', 5, 3, 7, 6, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Teemo_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Teemo.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Thresh', 'Stra??nik ??a??cuch??w', 'Sadystyczny i przebieg??y Thresh jest ambitnym i niespokojnym duchem Wysp Cienia. Niegdy?? opiekun niezliczonych magicznych tajemnic, zosta?? zniszczony przez moce pot????niejsze ni?? ??ycie czy ??mier??, a teraz istnieje tylko dzi??ki swojej straszliwej inwencji tw??rczej w powolnym zadawaniu cierpienia. Ofiary Thresha cierpi?? daleko poza moment samej ??mierci, albowiem rujnuje on ich dusze, wi??????c je w swej nikczemnej latarni, by nast??pnie torturowa?? je przez ca???? wieczno????.', 5, 6, 6, 7, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Thresh_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Thresh.png', 'Support');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Tristana', 'Dumna Kanonierka', 'Inni Yordlowie wykorzystuj?? w??asn?? energi??, by by?? odkrywcami, wynalazcami lub po prostu psotnikami. Tristan?? zawsze poci??ga??y przygody wielkich wojownik??w. S??ysza??a wiele o Runeterze, jej frakcjach oraz wojnach i wierzy??a, ??e tacy jak ona te?? mog?? sta?? si?? godnymi legend. Postawiwszy pierwszy krok w tym ??wiecie, z??apa??a za swoje wierne dzia??o ??? Boomera, i teraz rzuca si?? do walki z niez??omn?? odwag?? i optymizmem.', 9, 3, 5, 4, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Tristana_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Tristana.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Trundle', 'Kr??l Trolli', 'Trundle to du??y i przebieg??y troll o prawdziwie pod??ych tendencjach, zmusi wszystko do kapitulacji ??? nawet sam Freljord. Zawzi??cie broni swojego terytorium, wi??c dopadnie ka??dego g??upca, kt??ry na nie wkroczy. Potem, z pomoc?? swojej maczugi z Prawdziwego Lodu, zamra??a przeciwnik??w do szpiku ko??ci i nabija ich na ostre, lodowe kolumny, ??miej??c si??, kiedy ich krew barwi ??nieg.', 7, 6, 2, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Trundle_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Trundle.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Tryndamere', 'Kr??l Barbarzy??c??w', 'Nap??dzany nieokie??znanym gniewem, Tryndamere kiedy?? przeszed?? przez ca??y Freljord, otwarcie wyzywaj??c do walki najlepszych wojownik??w p????nocy, by przygotowa?? si?? na nadchodz??ce czarne dni. Ten gniewny barbarzy??ca od dawien dawna chcia?? zem??ci?? si?? za ludob??jstwo dokonane na jego klanie, cho?? ostatnio znalaz?? miejsce oraz dom u boku Ashe, avarosa??skiej matki wojny, i jej plemienia. Prawie nieludzka si??a i hart ducha Tryndamere''a s?? legendarne i zapewni??y jemu i jego nowym sojusznikom niezliczone zwyci??stwa nawet w najgorszych sytuacjach.', 10, 5, 2, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Tryndamere_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Tryndamere.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Twisted Fate', 'Mistrz Kart', 'Twisted Fate to nies??awny szuler i oszust, kt??ry wszystko, co chce, zdobywa hazardem i urokiem. Zapracowa?? sobie przez to zar??wno na wrogo????, jak i podziw bogatych i g??upich. Rzadko kiedy zachowuje powag??, witaj??c ka??dy dzie?? prze??miewczym u??mieszkiem i niefrasobliwym nad??ciem. W ka??dym mo??liwym znaczeniu tego s??owa, Twisted Fate zawsze ma asa w r??kawie.', 6, 2, 6, 9, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/TwistedFate_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/TwistedFate.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Twitch', 'Szczur Zarazy', 'Zau??ski szczur zarazy z urodzenia, lecz koneser obrzydlistw z pasji, Twitch nie boi ubrudzi?? sobie ??ap. Wymierza swoj?? zasilan?? chemikaliami kusz?? w z??ocone serce Piltover i przysi??ga dowie???? wszystkim w mie??cie wy??ej, jak bardzo s?? plugawi. Zawsze szczwanie szczwany, a kiedy nie kr??ci si?? po Slumsach, pewnie tkwi po pas w ??mieciach innych ludzi, szukaj??c wyrzuconych skarb??w... i sple??nia??ych kanapek.', 9, 2, 3, 6, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Twitch_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Twitch.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Udyr', 'Duchowy W??drowca', 'Udyr, najpot????niejszy z ??yj??cych duchowych w??drowc??w, obcuje ze wszystkimi widmami Freljordu ??? czy to poprzez empatyczne zrozumienie ich potrzeb, czy te?? kierowanie i przekszta??canie ich eterycznej energii w sw??j w??asny, pierwotny styl walki. Szuka wewn??trznej r??wnowagi, aby jego umys?? nie zagubi?? si?? w??r??d innych, jednak d????y r??wnie?? do harmonii poza granicami samego siebie ??? mistyczny krajobraz Freljordu mo??e si?? rozwija?? tylko dzi??ki wzrostowi, kt??ry wynika z konfliktu i walki, a Udyr wie, ??e aby utrzyma?? pokojow?? stagnacj??, trzeba ponosi?? ofiary.', 8, 7, 4, 7, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Udyr_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Udyr.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Urgot', 'Motor Agonii', 'Dawno temu pot????ny noxia??ski kat o imieniu Urgot zosta?? zdradzony przez imperium, w kt??rego s??u??bie odebra?? tak wiele ??y??. Skuty ??elaznymi kajdanami zmuszony by?? pozna?? prawdziw?? si???? w Czelu??ci, wi??ziennej kopalni g????boko pod Zaun. Uwolniony w wyniku katastrofy, kt??ra sprowadzi??a chaos na ca??e miasto, stanowi teraz cie?? ci??????cy nad przest??pczym p??????wiatkiem. D??????c do oczyszczenia swojego nowego domu z tych, kt??rzy wed??ug niego nie zas??uguj?? na ??ycie, unosi swoje ofiary na tych samych ??a??cuchach, kt??re niegdy?? p??ta??y jego cia??o, skazuj??c je na niewyobra??alne cierpienie.', 8, 5, 3, 8, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Urgot_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Urgot.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Varus', 'Strza??a Odkupienia', 'Varus, jeden ze staro??ytnych Darkin??w, by?? ??miertelnie niebezpiecznym zab??jc??, kt??ry uwielbia?? gn??bi?? ofiary, doprowadzaj??c je do granic szale??stwa przed wyko??czeniem ich za pomoc?? strza??. Zosta?? uwi??ziony pod koniec Wielkiej Wojny Darkin??w, ale wiele wiek??w p????niej uda??o mu si?? uciec w odmienionym ciele dw??ch ionia??skich ??owc??w, kt??rzy bezwiednie go wyzwolili i zostali przekl??ci, by nie???? ??uk, kt??ry zawiera?? jego esencj??. Varus poluje teraz na tych, kt??rzy go uwi??zili, aby dokona?? na nich brutalnej zemsty, jednak??e powi??zane z nim dusze ??miertelnik??w przeciwstawiaj?? mu si?? na ka??dym kroku.', 7, 3, 4, 2, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Varus_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Varus.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Vayne', 'Nocna ??owczyni', 'Shauna Vayne, pochodz??ca z Demacii, to bezlitosna ??owczyni potwor??w, kt??ra poprzysi??g??a, ??e zniszczy demona, kt??ry wymordowa?? jej rodzin??. Uzbrojona w przymocowan?? do nadgarstka kusz??, z sercem wype??nionym ????dz?? zemsty, odnajduje szcz????cie jedynie w zabijaniu s??ug i stwor??w ciemno??ci za pomoc?? wystrzeliwanych z cienia srebrnych be??t??w.', 10, 1, 1, 8, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Vayne_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Vayne.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Veigar', 'Panicz Z??a', 'Entuzjastyczny mistrz czarnej magii, Veigar pozna?? moce, z kt??rymi niewielu ??miertelnik??w chce si?? zaznajomi??. Jako niezale??ny mieszkaniec Bandle City, chcia?? wyj???? poza granice yordlowej magii, wi??c zacz???? zajmowa?? si?? magicznymi wolumenami, kt??re pozostawa??y ukryte przez tysi??ce lat. Teraz jest upartym stworzeniem, z nieko??cz??c?? si?? fascynacj?? na punkcie tajemnic wszech??wiata. Veigar jest cz??sto niedoceniany przez innych ??? cho?? sam wierzy, ??e jest prawdziwie z??y, posiada wewn??trzny zmys?? moralno??ci, przez kt??ry inni kwestionuj?? jego pobudki.', 2, 2, 10, 7, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Veigar_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Veigar.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Vel''Koz', 'Oko Pustki', 'Nie wiadomo czy Vel''Koz by?? pierwszym Pomiotem Pustki, kt??ry pojawi?? si?? w Runeterze, ale na pewno ??aden inny Pomiot nie do??cign???? poziomu jego ch??odnego, wykalkulowanego rozumowania ??wiata. Cho?? jego pobratymcy po??eraj?? lub profanuj?? wszystko wok????, on woli analizowa?? i przygl??da?? si?? fizycznemu wymiarowi ??? oraz dziwnym, wojowniczym istotom, kt??re go zamieszkuj?? ??? szukaj??c s??abo??ci, kt??re Pustka mog??aby wykorzysta??. Lecz Vel''Koz bynajmniej nie przygl??da si?? biernie temu wszystkiemu, atakuje zagra??aj??ce mu osobniki, wystrzeliwuj??c zab??jcz?? plazm?? i przerywaj??c materia?? ??wiata.', 2, 2, 10, 8, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Velkoz_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Velkoz.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Vex', 'Ponuraczka', 'W czarnym sercu Wysp Cienia samotna Yordlka brnie przez widmow?? mg???? zadowolona ze swojej mrocznej niedoli. Vex dysponuje bezbrze??nymi pok??adami nastoletniego buntu i pot????nym cieniem, z kt??rych pomoc?? chce wykroi?? dla siebie kawa??ek mroku z dala od wstr??tnej rado??ci ??wiata ???normik??w???. Mo??e brakuje jej ambicji, ale b??yskawicznie burzy wszelkie przejawy koloru i szcz????liwo??ci oraz powstrzymuje natr??t??w swoim magicznym marazmem.', 0, 0, 0, 0, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Vex_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Vex.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Vi', 'Str???? Prawa z Piltover', 'Vi, wiod??ca niegdy?? przest??pcze ??ycie na pos??pnych ulicach Zaun, jest impulsywn??, gwa??town?? i nieustraszon?? kobiet??, niemaj??c?? zbyt wiele szacunku do przedstawicieli w??adz. Dorastaj??c w samotno??ci, do perfekcji rozwin????a instynkt przetrwania, a tak??e szorstkie poczucie humoru. Pracuj??c dla Stra??nik??w Piltover w walce o pok??j, nosi pot????ne, hextechowe r??kawice, mog??ce z r??wn?? ??atwo??ci?? przebija?? si?? przez ??ciany, jak i wbija?? rozum do g??owy przest??pcom.', 8, 5, 3, 4, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Vi_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Vi.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Viego', 'Zniszczony Kr??l', 'Viego, niegdy?? w??adca dawno utraconego kr??lestwa, zgin???? ponad tysi??c lat temu, gdy jego pr??ba przywr??cenia ??ony do ??ycia spowodowa??a magiczn?? katastrof?? znan?? jako Zrujnowanie. Przekszta??cony w pot????nego, nie??ywego upiora, kt??rego torturuje obsesyjna t??sknota za swoj?? nie??yj??c?? od wiek??w kr??low??, Viego sta?? si?? Zniszczonym Kr??lem. Kontroluje ??mierciono??ne Harrowing, przemierzaj??c Runeterr?? w poszukiwaniu czegokolwiek, co mo??e kiedy?? przywr??ci?? do ??ycia jego ukochan??, i niszcz??c wszystko na swojej drodze, poniewa?? Czarna Mg??a wylewa si?? bez ko??ca z jego okrutnego, z??amanego serca.', 6, 4, 2, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Viego_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Viego.png', 'Assassin');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Viktor', 'Zwiastun Maszyn', 'Zwiastun wielkiej nowej ery technologii, Viktor po??wi??ci?? swoje ??ycie na udoskonalanie gatunku ludzkiego. Idealista, kt??ry chce wynie???? ludzi Zaun na nowe poziomy rozumienia, wierzy, ??e tylko poddaj??c si?? wielkiej ewolucji technologii ludzko???? mo??e osi??gn???? sw??j maksymalny potencja??. Viktor, kt??rego cia??o zosta??o ulepszone dzi??ki stali i nauce, gorliwie d????y do spe??nienia swoich marze?? o ??wietlanej przysz??o??ci.', 2, 4, 10, 9, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Viktor_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Viktor.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Vladimir', 'Krwio??erczy ??niwiarz', 'Potw??r pragn??cy krwi ??miertelnik??w, Vladimir wp??ywa na sprawy Noxusu od zarania imperium. Poza nienaturalnym wyd??u??aniem swojego ??ycia, jego mistrzowskie w??adanie krwi?? pozwala mu na kontrolowanie umys????w i cia?? innych, jakby by??y jego w??asnymi. Umo??liwi??o mu to stworzenie fanatycznego kultu w??asnej osoby na krzykliwych salonach noxia??skiej arystokracji. Ta zdolno???? potrafi r??wnie?? sprawi??, ??e w najciemniejszych zau??kach jego wrogowie wykrwawiaj?? si?? na ??mier??.', 2, 6, 8, 7, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Vladimir_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Vladimir.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Volibear', 'Bezlitosny Grom', 'Ci, kt??rzy wci???? czcz?? Volibeara, uznaj?? go za uosobienie burzy. Ten niszczycielski, dziki i niewzruszony stw??r istnia??, zanim ??miertelnicy postawili stop?? we freljordzkiej tundrze i z dziko??ci?? broni krainy, kt??r?? stworzy?? wraz ze swoimi p????boskimi pobratymcami. Piel??gnuj??c w sobie g????bok?? nienawi???? do cywilizacji i s??abo??ci, jak?? ta za sob?? poci??gn????a, Volibear walczy o powr??t do dawnych zwyczaj??w ??? do czasu, kiedy kraina nie by??a okie??znana, a rozlew krwi nie by?? niczym ograniczony ??? i ochoczo stawia czo??a wszystkim swoim oponentom przy pomocy szpon??w, k????w i piorunuj??cej dominacji.', 7, 7, 4, 3, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Volibear_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Volibear.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Warwick', 'Rozkie??znany Gniew Zaun', 'Warwick to potw??r, kt??ry poluje w mrocznych zau??kach Zaun. Przeszed?? przemian?? w wyniku bolesnych eksperyment??w, a jego cia??o po????czono ze skomplikowanym systemem pomp i zbiornik??w, kt??re wype??niaj?? jego cia??o alchemicznym gniewem. Kryj??c si?? w cieniach poluje na przest??pc??w, kt??rzy terroryzuj?? mieszka??c??w miasta. Zapach krwi doprowadza go do szale??stwa. Nikt, kto j?? przelewa, nie jest w stanie przed nim uciec.', 9, 5, 3, 3, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Warwick_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Warwick.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Xayah', 'Buntowniczka', 'Niebezpieczna i dok??adna Xayah to vastaja??ska rewolucjonistka, kt??ra toczy prywatn?? wojn??, aby ocali?? sw??j lud. Wykorzystuje swoj?? szybko????, przebieg??o???? i ostre jak brzytwa ostrza, aby pozby?? si?? ka??dego, kto stanie jej na drodze. Xayah walczy u boku partnera i kochanka, Rakana, aby chroni?? swoje wymieraj??ce plemi?? i przywr??ci?? swojej rasie dawn?? chwa????.', 10, 6, 1, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Xayah_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Xayah.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Xerath', 'Wyniesiony Mag', 'Xerath jest Wyniesionym Magiem ze staro??ytnej Shurimy, istot?? o tajemnej energii, ??yj??c?? w??r??d wiruj??cych szcz??tk??w magicznego sarkofagu. Przez tysi??ce lat uwi??ziony by?? pod piaskami pustyni, lecz odrodzenie Shurimy uwolni??o go z prastarego wi??zienia. Doprowadzony do szale??stwa przez swoj?? pot??g??, chcia??by stworzy?? na sw??j wz??r cywilizacj??, kt??ra opanuje ??wiat i wyprze wszystkie inne.', 1, 3, 10, 8, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Xerath_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Xerath.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Xin Zhao', 'Seneszal Demacii', 'Xin Zhao jest stanowczym wojownikiem lojalnym panuj??cej Dynastii Promiennej Tarczy. Kiedy?? skazany na walk?? jako gladiator na noxia??skich arenach, przetrwa?? niezliczone ilo??ci pojedynk??w, a gdy zosta?? wyzwolony przez si??y Demacii, przysi??g?? wieczn?? wierno???? swoim wybawicielom. Uzbrojony w swoj?? ulubion?? w????czni?? o trzech szponach, Xin Zhao walczy teraz dla swojego przybranego kr??lestwa, zuchwale stawiaj??c czo??a ka??demu wrogowi.', 8, 6, 3, 2, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/XinZhao_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/XinZhao.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Yasuo', 'Pokutnik', 'Yasuo, Ionia??czyk o wielkiej determinacji, jest zwinnym szermierzem, kt??ry u??ywa wiatru przeciwko wrogom. Kiedy by?? dumnym m??odzie??cem, nies??usznie oskar??ono go o zamordowanie mistrza. Jako ??e nie m??g?? dowie???? swojej niewinno??ci, przysz??o mu zabi?? w??asnego brata w akcie samoobrony. Nawet po tym, jak ujawniono prawdziwego zab??jc?? jego mistrza, Yasuo wci???? nie potrafi?? wybaczy?? sobie tego, co zrobi??. Teraz w????czy si?? po ojczy??nie, maj??c u swego boku tylko wiatr, kt??ry kieruje jego ostrzem.', 8, 4, 4, 10, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Yasuo_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Yasuo.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Yone', 'Wiecznie ??ywy', 'Za ??ycia by?? Yone ??? przybranym bratem Yasuo i szanowanym uczniem w pobliskiej szkole miecza. Jednak po ??mierci z r??k brata nawiedzi??a go z??owroga istota, kt??r?? zmuszony by?? zg??adzi?? przy u??yciu jej w??asnego miecza. Teraz Yone, przekl??ty i zmuszony do noszenia na twarzy demonicznej maski, niestrudzenie poluje na wszystkie podobne stworzenia, by zrozumie??, czym si?? sta??.', 8, 4, 4, 8, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Yone_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Yone.png', 'Assassin');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Yorick', 'Pasterz Dusz', 'Yorick, ostatni ocala??y z dawno zapomnianego zakonu religijnego, jest zar??wno b??ogos??awiony, jak i przekl??ty moc?? w??adania nad nieumar??ymi. Uwi??ziony na Wyspach Cienia, jego jedynymi towarzyszami s?? gnij??ce zw??oki i wyj??ce duchy, kt??re gromadzi u swego boku. Potworne dzia??ania Yoricka skrywaj?? jednak szlachetny cel ??? chce uwolni?? sw??j dom od kl??twy Zrujnowania.', 6, 6, 4, 6, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Yorick_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Yorick.png', 'Fighter');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Yuumi', 'Magiczna Kotka', 'Yuumi, magiczna kotka z Bandle City, by??a niegdy?? chowa??cem yordlowej czarodziejki, Norry. Gdy jej pani znikn????a w tajemniczych okoliczno??ciach, Yuumi sta??a si?? Stra??niczk?? ??ywej Ksi??gi Wr??t Norry, podr????uj??c przez portale na jej stronach w poszukiwaniu swej w??a??cicielki. Pragn??c mi??o??ci, Yuumi poszukuje przyjaznych towarzyszy, kt??rzy wspomogliby j?? w podr????y, i chroni ich za pomoc?? ??wietlistych tarcz oraz swojej nieposkromionej odwagi. Podczas gdy Ksi????ka pr??buje trzyma?? si?? wyznaczonego zadania, Yuumi cz??sto oddaje si?? przyziemnym przyjemno??ciom takim jak drzemki czy jedzenie ryb. Zawsze powraca jednak do poszukiwa?? swojej przyjaci????ki.', 5, 1, 8, 2, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Yuumi_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Yuumi.png', 'Support');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Zac', 'Tajna Bro??', 'Zac powsta?? w wyniku kontaktu toksycznego szlamu z chemtechem, kt??ry nast??pnie osiad?? w jaskini w g????bi slums??w Zaun. Mimo takich narodzin Zac ewoluowa?? z prymitywnego szlamu w istot?? my??l??c??, kt??ra zamieszkuje kanalizacj?? miejsk??, co jaki?? czas wynurzaj??c si??, aby pom??c tym, kt??rzy nie daj?? sobie rady sami, albo by odbudowa?? zniszczon?? infrastruktur?? Zaun.', 3, 7, 7, 8, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Zac_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Zac.png', 'Tank');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Zed', 'W??adca Cieni', 'Ca??kowicie bezwzgl??dny i pozbawiony lito??ci, Zed jest przyw??dc?? Zakonu Cienia, czyli organizacji, kt??r?? stworzy??, kieruj??c si?? zmilitaryzowaniem sztuk walki Ionii, by wyp??dzi?? noxia??skich naje??d??c??w. Podczas wojny desperacja sprawi??a, ??e odnalaz?? sekretn?? form?? cienia ??? nikczemn?? magi?? ducha, r??wnie niebezpieczn?? i wypaczaj??c??, co pot????n??. Zed sta?? si?? mistrzem tych zakazanych technik, by niszczy?? wszystko, co mog??oby zagra??a?? jego narodowi lub nowemu zakonowi.', 9, 2, 1, 7, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Zed_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Zed.png', 'Assassin');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Zeri', 'Iskierka Zaun', 'Zeri ??? nieust??pliwa, charakterna m??oda kobieta wywodz??ca si?? z klasy robotniczej Zaun ??? korzysta ze swojej elektrycznej magii, aby ??adowa?? sam?? siebie i swoj?? niestandardow??, stworzon?? specjalnie dla niej bro??. Jej niestabilna moc odzwierciedla jej emocje, a otaczaj??ce j?? iskry obrazuj?? b??yskawicznie szybkie podej??cie do ??ycia. Zeri jest pe??na wsp????czucia wzgl??dem innych, a mi??o???? do rodziny i domu towarzyszy jej w ka??dej walce. Chocia?? jej szczere ch??ci pomocy przynosz?? czasami odwrotny skutek, Zeri wierzy w jedno: sta?? murem za swoj?? spo??eczno??ci??, a spo??eczno???? stanie murem za tob??.', 8, 5, 3, 6, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Zeri_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Zeri.png', 'Marksman');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Ziggs', 'Hextechowy Saper', 'Yordle Ziggs, mi??o??nik du??ych bomb i kr??tkich lont??w, jest chodz??cym wybuchowym kataklizmem. B??d??c asystentem wynalazcy w Piltover, sta?? si?? znudzony swoim przepe??nionym rutyn?? ??yciem, wi??c zaprzyja??ni?? si?? z szalon?? niebieskow??os?? wariatk?? z bombami zwan?? Jinx. Po szalonej nocy na mie??cie, Ziggs pos??ucha?? si?? jej i przeprowadzi?? do Zaun, gdzie teraz mo??e swobodnie zg????bia?? swoje pasje, terroryzuj??c po r??wno chembaron??w i zwyk??ych obywateli, by da?? upust swojej ????dzy wybuch??w.', 2, 4, 9, 4, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Ziggs_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Ziggs.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Zilean', 'Stra??nik Czasu', 'Kiedy?? pot????ny mag z Icathii, Zilean zacz???? niezdrowo fascynowa?? si?? up??ywem czasu, po tym jak by?? ??wiadkiem zniszcze??, jakie dokona??a Pustka na jego ojczy??nie. Nie mog??c po??wi??ci?? nawet minuty, by op??aka?? t?? katastrofaln?? strat??, przywo??a?? staro??ytn?? magi?? temporaln??, by dzi??ki niej odgadn???? wszystkie mo??liwo??ci. Stawszy si?? praktycznie nie??miertelnym, Zilean przemierza przesz??o????, tera??niejszo???? oraz przysz??o????, naginaj??c i zakrzywiaj??c przep??yw czasu. Bezustannie poszukuje tej nieuchwytnej chwili, kt??ra cofnie zegar i odwr??ci zniszczenie Icathii.', 2, 5, 8, 6, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Zilean_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Zilean.png', 'Support');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Zoe', 'Aspekt Zmierzchu', 'Jako uosobienie psotliwo??ci, wyobra??ni i zmiany, Zoe jest kosmicznym pos??a??cem Targonu, kt??ry zwiastuje wa??ne wydarzenia zmieniaj??ce ca??e ??wiaty. Sama jej obecno???? zakrzywia prawa fizyki, co czasami prowadzi do kataklizm??w, lecz nie jest to zamierzone dzia??anie. By?? mo??e wyja??nia to nonszalancj??, z jak?? Zoe traktuje swoje obowi??zki, co daje jej mn??stwo czasu na igraszki, strojenie sobie ??art??w ze ??miertelnik??w i dostarczanie sobie rozrywki na inne sposoby. Spotkanie z Zoe mo??e by?? przyjemnym i pozytywnym do??wiadczeniem, lecz zawsze kryje si?? w tym co?? wi??cej i nierzadko jest to co?? bardzo niebezpiecznego.', 1, 7, 8, 5, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Zoe_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Zoe.png', 'Mage');
INSERT INTO bohaterowie(nazwa, tytu??, krotki_opis, atak, obrona, magia, trudnosc, obraz, ikona, klasa)VALUES ('Zyra', 'Wied??ma Cierni', 'Urodzona w staro??ytnej, magicznej katastrofie, Zyra jest uosobieniem gniewu. Natura nada??a jej kszta??t powabnej hybrydy ro??liny i cz??owieka, kt??ra sieje ??ycie z ka??dym krokiem. Postrzega ??miertelnik??w Valoranu jako co?? troch?? lepszego od nawozu dla jej ziarna-potomstwa i bez problemu zabija ich swoimi ??mierciono??nymi kolcami. Cho?? jej prawdziwe zamiary pozostaj?? tajemnic??, Zyra w??druje po ??wiecie, daj??c upust swoim pierwotnym ????dzom ??? kolonizuje i wydusza ??ycie ze wszystkiego, co stanie jej na drodze.', 4, 3, 8, 7, 'http://ddragon.leagueoflegends.com/cdn/img/champion/loading/Zyra_0.jpg','http://ddragon.leagueoflegends.com/cdn/13.1.1/img/champion/Zyra.png', 'Mage');

INSERT INTO kontry(bohater, kontra) VALUES ('Aatrox', 'Malphite');
INSERT INTO kontry(bohater, kontra) VALUES ('Aatrox', 'Camille');
INSERT INTO kontry(bohater, kontra) VALUES ('Aatrox', 'Darius');
INSERT INTO kontry(bohater, kontra) VALUES ('Ahri', 'Katarina');
INSERT INTO kontry(bohater, kontra) VALUES ('Ahri', 'Veigar');
INSERT INTO kontry(bohater, kontra) VALUES ('Ahri', 'Lux');
INSERT INTO kontry(bohater, kontra) VALUES ('Akali', 'Yasuo');
INSERT INTO kontry(bohater, kontra) VALUES ('Akali', 'Diana');
INSERT INTO kontry(bohater, kontra) VALUES ('Akali', 'Galio');
INSERT INTO kontry(bohater, kontra) VALUES ('Alistar', 'Lulu');
INSERT INTO kontry(bohater, kontra) VALUES ('Alistar', 'Janna');
INSERT INTO kontry(bohater, kontra) VALUES ('Alistar', 'Senna');
INSERT INTO kontry(bohater, kontra) VALUES ('Amumu', 'Morgana');
INSERT INTO kontry(bohater, kontra) VALUES ('Amumu', 'Dr Mundo');
INSERT INTO kontry(bohater, kontra) VALUES ('Amumu', 'Volibear');
INSERT INTO kontry(bohater, kontra) VALUES ('Anivia', 'Ahri');
INSERT INTO kontry(bohater, kontra) VALUES ('Anivia', 'Vel''Koz');
INSERT INTO kontry(bohater, kontra) VALUES ('Anivia', 'Malphite');
INSERT INTO kontry(bohater, kontra) VALUES ('Annie', 'Zilean');
INSERT INTO kontry(bohater, kontra) VALUES ('Annie', 'Varus');
INSERT INTO kontry(bohater, kontra) VALUES ('Annie', 'Ahri');
INSERT INTO kontry(bohater, kontra) VALUES ('Aphelios', 'Jinx');
INSERT INTO kontry(bohater, kontra) VALUES ('Aphelios', 'Samira');
INSERT INTO kontry(bohater, kontra) VALUES ('Aphelios', 'Kai''Sa');
INSERT INTO kontry(bohater, kontra) VALUES ('Ashe', 'Draven');
INSERT INTO kontry(bohater, kontra) VALUES ('Ashe', 'Blitzcrank');
INSERT INTO kontry(bohater, kontra) VALUES ('Ashe', 'Nami');
INSERT INTO kontry(bohater, kontra) VALUES ('Aurelion Sol', 'Zed');
INSERT INTO kontry(bohater, kontra) VALUES ('Aurelion Sol', 'Fizz');
INSERT INTO kontry(bohater, kontra) VALUES ('Aurelion Sol', 'Sylas');
INSERT INTO kontry(bohater, kontra) VALUES ('Azir', 'Lux');
INSERT INTO kontry(bohater, kontra) VALUES ('Azir', 'Annie');
INSERT INTO kontry(bohater, kontra) VALUES ('Azir', 'Orianna');
INSERT INTO kontry(bohater, kontra) VALUES ('Bard', 'Senna');
INSERT INTO kontry(bohater, kontra) VALUES ('Bard', 'Blitzcrank');
INSERT INTO kontry(bohater, kontra) VALUES ('Bard', 'Vel''Koz');
INSERT INTO kontry(bohater, kontra) VALUES ('Blitzcrank', 'Alistar');
INSERT INTO kontry(bohater, kontra) VALUES ('Blitzcrank', 'Leona');
INSERT INTO kontry(bohater, kontra) VALUES ('Blitzcrank', 'Morgana');
INSERT INTO kontry(bohater, kontra) VALUES ('Brand', 'Lulu');
INSERT INTO kontry(bohater, kontra) VALUES ('Brand', 'Fizz');
INSERT INTO kontry(bohater, kontra) VALUES ('Brand', 'Morgana');
INSERT INTO kontry(bohater, kontra) VALUES ('Braum', 'Zilean');
INSERT INTO kontry(bohater, kontra) VALUES ('Braum', 'Rakan');
INSERT INTO kontry(bohater, kontra) VALUES ('Braum', 'Darius');
INSERT INTO kontry(bohater, kontra) VALUES ('Caitlyn', 'Jinx');
INSERT INTO kontry(bohater, kontra) VALUES ('Caitlyn', 'Twitch');
INSERT INTO kontry(bohater, kontra) VALUES ('Caitlyn', 'Jhin');
INSERT INTO kontry(bohater, kontra) VALUES ('Camille', 'Cho''Gath');
INSERT INTO kontry(bohater, kontra) VALUES ('Camille', 'Jax');
INSERT INTO kontry(bohater, kontra) VALUES ('Camille', 'Warwick');
INSERT INTO kontry(bohater, kontra) VALUES ('Cassiopeia', 'Yone');
INSERT INTO kontry(bohater, kontra) VALUES ('Cassiopeia', 'Katarina');
INSERT INTO kontry(bohater, kontra) VALUES ('Cassiopeia', 'Neeko');
INSERT INTO kontry(bohater, kontra) VALUES ('Cho''Gath', 'Mordekaiser');
INSERT INTO kontry(bohater, kontra) VALUES ('Cho''Gath', 'Ornn');
INSERT INTO kontry(bohater, kontra) VALUES ('Cho''Gath', 'Nocturne');
INSERT INTO kontry(bohater, kontra) VALUES ('Corki', 'Anivia');
INSERT INTO kontry(bohater, kontra) VALUES ('Corki', 'Kassadin');
INSERT INTO kontry(bohater, kontra) VALUES ('Corki', 'Jinx');
INSERT INTO kontry(bohater, kontra) VALUES ('Darius', 'Malphite');
INSERT INTO kontry(bohater, kontra) VALUES ('Darius', 'Sett');
INSERT INTO kontry(bohater, kontra) VALUES ('Darius', 'Teemo');
INSERT INTO kontry(bohater, kontra) VALUES ('Diana', 'Morgana');
INSERT INTO kontry(bohater, kontra) VALUES ('Diana', 'Yasuo');
INSERT INTO kontry(bohater, kontra) VALUES ('Diana', 'Fiddlesticks');
INSERT INTO kontry(bohater, kontra) VALUES ('Draven', 'Jinx');
INSERT INTO kontry(bohater, kontra) VALUES ('Draven', 'Jhin');
INSERT INTO kontry(bohater, kontra) VALUES ('Draven', 'Swain');
INSERT INTO kontry(bohater, kontra) VALUES ('Dr Mundo', 'Kindred');
INSERT INTO kontry(bohater, kontra) VALUES ('Dr Mundo', 'Ekko');
INSERT INTO kontry(bohater, kontra) VALUES ('Dr Mundo', 'Shen');
INSERT INTO kontry(bohater, kontra) VALUES ('Ekko', 'Kha''Zix');
INSERT INTO kontry(bohater, kontra) VALUES ('Ekko', 'Shaco');
INSERT INTO kontry(bohater, kontra) VALUES ('Ekko', 'Elise');
INSERT INTO kontry(bohater, kontra) VALUES ('Elise', 'Shaco');
INSERT INTO kontry(bohater, kontra) VALUES ('Elise', 'Fiddlesticks');
INSERT INTO kontry(bohater, kontra) VALUES ('Elise', 'Rammus');
INSERT INTO kontry(bohater, kontra) VALUES ('Evelynn', 'Nunu i Willump');
INSERT INTO kontry(bohater, kontra) VALUES ('Evelynn', 'Xin Zhao');
INSERT INTO kontry(bohater, kontra) VALUES ('Evelynn', 'Rengar');
INSERT INTO kontry(bohater, kontra) VALUES ('Ezreal', 'Jhin');
INSERT INTO kontry(bohater, kontra) VALUES ('Ezreal', 'Vayne');
INSERT INTO kontry(bohater, kontra) VALUES ('Ezreal', 'Tristana');
INSERT INTO kontry(bohater, kontra) VALUES ('Fiddlesticks', 'Zac');
INSERT INTO kontry(bohater, kontra) VALUES ('Fiddlesticks', 'Senna');
INSERT INTO kontry(bohater, kontra) VALUES ('Fiddlesticks', 'Nautilus');
INSERT INTO kontry(bohater, kontra) VALUES ('Fiora', 'Sett');
INSERT INTO kontry(bohater, kontra) VALUES ('Fiora', 'Wukong');
INSERT INTO kontry(bohater, kontra) VALUES ('Fiora', 'Malphite');
INSERT INTO kontry(bohater, kontra) VALUES ('Fizz', 'Sylas');
INSERT INTO kontry(bohater, kontra) VALUES ('Fizz', 'Kassadin');
INSERT INTO kontry(bohater, kontra) VALUES ('Fizz', 'Swain');
INSERT INTO kontry(bohater, kontra) VALUES ('Galio', 'Senna');
INSERT INTO kontry(bohater, kontra) VALUES ('Galio', 'Janna');
INSERT INTO kontry(bohater, kontra) VALUES ('Galio', 'Varus');
INSERT INTO kontry(bohater, kontra) VALUES ('Gangplank', 'Urgot');
INSERT INTO kontry(bohater, kontra) VALUES ('Gangplank', 'Sett');
INSERT INTO kontry(bohater, kontra) VALUES ('Gangplank', 'Nasus');
INSERT INTO kontry(bohater, kontra) VALUES ('Garen', 'Camille');
INSERT INTO kontry(bohater, kontra) VALUES ('Garen', 'Cho''Gath');
INSERT INTO kontry(bohater, kontra) VALUES ('Garen', 'Darius');
INSERT INTO kontry(bohater, kontra) VALUES ('Gnar', 'Urgot');
INSERT INTO kontry(bohater, kontra) VALUES ('Gnar', 'Malphite');
INSERT INTO kontry(bohater, kontra) VALUES ('Gnar', 'Camille');
INSERT INTO kontry(bohater, kontra) VALUES ('Gragas', 'Kayn');
INSERT INTO kontry(bohater, kontra) VALUES ('Gragas', 'Lee Sin');
INSERT INTO kontry(bohater, kontra) VALUES ('Gragas', 'Shaco');
INSERT INTO kontry(bohater, kontra) VALUES ('Graves', 'Kayn');
INSERT INTO kontry(bohater, kontra) VALUES ('Graves', 'Elise');
INSERT INTO kontry(bohater, kontra) VALUES ('Graves', 'Kindred');
INSERT INTO kontry(bohater, kontra) VALUES ('Gwen', 'Sett');
INSERT INTO kontry(bohater, kontra) VALUES ('Gwen', 'Urgot');
INSERT INTO kontry(bohater, kontra) VALUES ('Gwen', 'Jax');
INSERT INTO kontry(bohater, kontra) VALUES ('Hecarim', 'Shaco');
INSERT INTO kontry(bohater, kontra) VALUES ('Hecarim', 'Morgana');
INSERT INTO kontry(bohater, kontra) VALUES ('Hecarim', 'Fiddlesticks');
INSERT INTO kontry(bohater, kontra) VALUES ('Heimerdinger', 'Lux');
INSERT INTO kontry(bohater, kontra) VALUES ('Heimerdinger', 'Aatrox');
INSERT INTO kontry(bohater, kontra) VALUES ('Heimerdinger', 'Jayce');
INSERT INTO kontry(bohater, kontra) VALUES ('Illaoi', 'Shen');
INSERT INTO kontry(bohater, kontra) VALUES ('Illaoi', 'Kled');
INSERT INTO kontry(bohater, kontra) VALUES ('Illaoi', 'Garen');
INSERT INTO kontry(bohater, kontra) VALUES ('Irelia', 'Riven');
INSERT INTO kontry(bohater, kontra) VALUES ('Irelia', 'Shen');
INSERT INTO kontry(bohater, kontra) VALUES ('Irelia', 'Jax');
INSERT INTO kontry(bohater, kontra) VALUES ('Ivern', 'Nocturne');
INSERT INTO kontry(bohater, kontra) VALUES ('Ivern', 'Fiddlesticks');
INSERT INTO kontry(bohater, kontra) VALUES ('Ivern', 'Morgana');
INSERT INTO kontry(bohater, kontra) VALUES ('Janna', 'Sona');
INSERT INTO kontry(bohater, kontra) VALUES ('Janna', 'Bard');
INSERT INTO kontry(bohater, kontra) VALUES ('Janna', 'Ashe');
INSERT INTO kontry(bohater, kontra) VALUES ('Jarvan IV', 'Morgana');
INSERT INTO kontry(bohater, kontra) VALUES ('Jarvan IV', 'Fiddlesticks');
INSERT INTO kontry(bohater, kontra) VALUES ('Jarvan IV', 'Zac');
INSERT INTO kontry(bohater, kontra) VALUES ('Jax', 'Malphite');
INSERT INTO kontry(bohater, kontra) VALUES ('Jax', 'Riven');
INSERT INTO kontry(bohater, kontra) VALUES ('Jax', 'Kha''Zix');
INSERT INTO kontry(bohater, kontra) VALUES ('Jayce', 'Malphite');
INSERT INTO kontry(bohater, kontra) VALUES ('Jayce', 'Sett');
INSERT INTO kontry(bohater, kontra) VALUES ('Jayce', 'Wukong');
INSERT INTO kontry(bohater, kontra) VALUES ('Jhin', 'Vayne');
INSERT INTO kontry(bohater, kontra) VALUES ('Jhin', 'Jinx');
INSERT INTO kontry(bohater, kontra) VALUES ('Jhin', 'Tristana');
INSERT INTO kontry(bohater, kontra) VALUES ('Jinx', 'Ashe');
INSERT INTO kontry(bohater, kontra) VALUES ('Jinx', 'Yasuo');
INSERT INTO kontry(bohater, kontra) VALUES ('Jinx', 'Swain');
INSERT INTO kontry(bohater, kontra) VALUES ('Kai''Sa', 'Jinx');
INSERT INTO kontry(bohater, kontra) VALUES ('Kai''Sa', 'Vayne');
INSERT INTO kontry(bohater, kontra) VALUES ('Kai''Sa', 'Samira');
INSERT INTO kontry(bohater, kontra) VALUES ('Kalista', 'Ashe');
INSERT INTO kontry(bohater, kontra) VALUES ('Kalista', 'Jinx');
INSERT INTO kontry(bohater, kontra) VALUES ('Kalista', 'Tristana');
INSERT INTO kontry(bohater, kontra) VALUES ('Karma', 'Lulu');
INSERT INTO kontry(bohater, kontra) VALUES ('Karma', 'Rakan');
INSERT INTO kontry(bohater, kontra) VALUES ('Karma', 'Morgana');
INSERT INTO kontry(bohater, kontra) VALUES ('Karthus', 'Nocturne');
INSERT INTO kontry(bohater, kontra) VALUES ('Karthus', 'Kayn');
INSERT INTO kontry(bohater, kontra) VALUES ('Karthus', 'Vel''Koz');
INSERT INTO kontry(bohater, kontra) VALUES ('Kassadin', 'Malzahar');
INSERT INTO kontry(bohater, kontra) VALUES ('Kassadin', 'Pantheon');
INSERT INTO kontry(bohater, kontra) VALUES ('Kassadin', 'Rumble');
INSERT INTO kontry(bohater, kontra) VALUES ('Katarina', 'Galio');
INSERT INTO kontry(bohater, kontra) VALUES ('Katarina', 'Vladimir');
INSERT INTO kontry(bohater, kontra) VALUES ('Katarina', 'Yasuo');
INSERT INTO kontry(bohater, kontra) VALUES ('Kayle', 'Sett');
INSERT INTO kontry(bohater, kontra) VALUES ('Kayle', 'Wukong');
INSERT INTO kontry(bohater, kontra) VALUES ('Kayle', 'Yorick');
INSERT INTO kontry(bohater, kontra) VALUES ('Kayn', 'Volibear');
INSERT INTO kontry(bohater, kontra) VALUES ('Kayn', 'Nocturne');
INSERT INTO kontry(bohater, kontra) VALUES ('Kayn', 'Shaco');
INSERT INTO kontry(bohater, kontra) VALUES ('Kennen', 'Wukong');
INSERT INTO kontry(bohater, kontra) VALUES ('Kennen', 'Darius');
INSERT INTO kontry(bohater, kontra) VALUES ('Kennen', 'Brand');
INSERT INTO kontry(bohater, kontra) VALUES ('Kha''Zix', 'Diana');
INSERT INTO kontry(bohater, kontra) VALUES ('Kha''Zix', 'Master Yi');
INSERT INTO kontry(bohater, kontra) VALUES ('Kha''Zix', 'Volibear');
INSERT INTO kontry(bohater, kontra) VALUES ('Kindred', 'Xin Zhao');
INSERT INTO kontry(bohater, kontra) VALUES ('Kindred', 'Master Yi');
INSERT INTO kontry(bohater, kontra) VALUES ('Kindred', 'Shaco');
INSERT INTO kontry(bohater, kontra) VALUES ('Kled', 'Urgot');
INSERT INTO kontry(bohater, kontra) VALUES ('Kled', 'Volibear');
INSERT INTO kontry(bohater, kontra) VALUES ('Kled', 'Camille');
INSERT INTO kontry(bohater, kontra) VALUES ('Kog''Maw', 'Jhin');
INSERT INTO kontry(bohater, kontra) VALUES ('Kog''Maw', 'Jinx');
INSERT INTO kontry(bohater, kontra) VALUES ('Kog''Maw', 'Sivir');
INSERT INTO kontry(bohater, kontra) VALUES ('LeBlanc', 'Ahri');
INSERT INTO kontry(bohater, kontra) VALUES ('LeBlanc', 'Diana');
INSERT INTO kontry(bohater, kontra) VALUES ('LeBlanc', 'Zyra');
INSERT INTO kontry(bohater, kontra) VALUES ('Lee Sin', 'Nocturne');
INSERT INTO kontry(bohater, kontra) VALUES ('Lee Sin', 'Rek''Sai');
INSERT INTO kontry(bohater, kontra) VALUES ('Lee Sin', 'Diana');
INSERT INTO kontry(bohater, kontra) VALUES ('Leona', 'Bard');
INSERT INTO kontry(bohater, kontra) VALUES ('Leona', 'Morgana');
INSERT INTO kontry(bohater, kontra) VALUES ('Leona', 'Seraphine');
INSERT INTO kontry(bohater, kontra) VALUES ('Lillia', 'Kayn');
INSERT INTO kontry(bohater, kontra) VALUES ('Lillia', 'Hecarim');
INSERT INTO kontry(bohater, kontra) VALUES ('Lillia', 'Kha''Zix');
INSERT INTO kontry(bohater, kontra) VALUES ('Lissandra', 'Fizz');
INSERT INTO kontry(bohater, kontra) VALUES ('Lissandra', 'Veigar');
INSERT INTO kontry(bohater, kontra) VALUES ('Lissandra', 'Viktor');
INSERT INTO kontry(bohater, kontra) VALUES ('Lucian', 'Vayne');
INSERT INTO kontry(bohater, kontra) VALUES ('Lucian', 'Jinx');
INSERT INTO kontry(bohater, kontra) VALUES ('Lucian', 'Caitlyn');
INSERT INTO kontry(bohater, kontra) VALUES ('Lulu', 'Seraphine');
INSERT INTO kontry(bohater, kontra) VALUES ('Lulu', 'Morgana');
INSERT INTO kontry(bohater, kontra) VALUES ('Lulu', 'Xerath');
INSERT INTO kontry(bohater, kontra) VALUES ('Lux', 'Yuumi');
INSERT INTO kontry(bohater, kontra) VALUES ('Lux', 'Lulu');
INSERT INTO kontry(bohater, kontra) VALUES ('Lux', 'Zilean');
INSERT INTO kontry(bohater, kontra) VALUES ('Malphite', 'Sylas');
INSERT INTO kontry(bohater, kontra) VALUES ('Malphite', 'Mordekaiser');
INSERT INTO kontry(bohater, kontra) VALUES ('Malphite', 'Shen');
INSERT INTO kontry(bohater, kontra) VALUES ('Malzahar', 'Talon');
INSERT INTO kontry(bohater, kontra) VALUES ('Malzahar', 'Ahri');
INSERT INTO kontry(bohater, kontra) VALUES ('Malzahar', 'Diana');
INSERT INTO kontry(bohater, kontra) VALUES ('Maokai', 'Yuumi');
INSERT INTO kontry(bohater, kontra) VALUES ('Maokai', 'Viego');
INSERT INTO kontry(bohater, kontra) VALUES ('Maokai', 'Jarvan IV');
INSERT INTO kontry(bohater, kontra) VALUES ('Master Yi', 'Udyr');
INSERT INTO kontry(bohater, kontra) VALUES ('Master Yi', 'Rammus');
INSERT INTO kontry(bohater, kontra) VALUES ('Master Yi', 'Kayn');
INSERT INTO kontry(bohater, kontra) VALUES ('Miss Fortune', 'Jinx');
INSERT INTO kontry(bohater, kontra) VALUES ('Miss Fortune', 'Lux');
INSERT INTO kontry(bohater, kontra) VALUES ('Miss Fortune', 'Karma');
INSERT INTO kontry(bohater, kontra) VALUES ('Mordekaiser', 'Fiora');
INSERT INTO kontry(bohater, kontra) VALUES ('Mordekaiser', 'Yone');
INSERT INTO kontry(bohater, kontra) VALUES ('Mordekaiser', 'Camille');
INSERT INTO kontry(bohater, kontra) VALUES ('Morgana', 'Nami');
INSERT INTO kontry(bohater, kontra) VALUES ('Morgana', 'Seraphine');
INSERT INTO kontry(bohater, kontra) VALUES ('Morgana', 'Nidalee');
INSERT INTO kontry(bohater, kontra) VALUES ('Nami', 'Zyra');
INSERT INTO kontry(bohater, kontra) VALUES ('Nami', 'Leona');
INSERT INTO kontry(bohater, kontra) VALUES ('Nami', 'Sona');
INSERT INTO kontry(bohater, kontra) VALUES ('Nasus', 'Sylas');
INSERT INTO kontry(bohater, kontra) VALUES ('Nasus', 'Yone');
INSERT INTO kontry(bohater, kontra) VALUES ('Nasus', 'Elise');
INSERT INTO kontry(bohater, kontra) VALUES ('Nautilus', 'Leona');
INSERT INTO kontry(bohater, kontra) VALUES ('Nautilus', 'Alistar');
INSERT INTO kontry(bohater, kontra) VALUES ('Nautilus', 'Lulu');
INSERT INTO kontry(bohater, kontra) VALUES ('Neeko', 'Ahri');
INSERT INTO kontry(bohater, kontra) VALUES ('Neeko', 'Bard');
INSERT INTO kontry(bohater, kontra) VALUES ('Neeko', 'Seraphine');
INSERT INTO kontry(bohater, kontra) VALUES ('Nidalee', 'Hecarim');
INSERT INTO kontry(bohater, kontra) VALUES ('Nidalee', 'Diana');
INSERT INTO kontry(bohater, kontra) VALUES ('Nidalee', 'Kha''Zix');
INSERT INTO kontry(bohater, kontra) VALUES ('Nocturne', 'Morgana');
INSERT INTO kontry(bohater, kontra) VALUES ('Nocturne', 'Dr Mundo');
INSERT INTO kontry(bohater, kontra) VALUES ('Nocturne', 'Wukong');
INSERT INTO kontry(bohater, kontra) VALUES ('Nunu i Willump', 'Morgana');
INSERT INTO kontry(bohater, kontra) VALUES ('Nunu i Willump', 'Master Yi');
INSERT INTO kontry(bohater, kontra) VALUES ('Nunu i Willump', 'Xin Zhao');
INSERT INTO kontry(bohater, kontra) VALUES ('Olaf', 'Diana');
INSERT INTO kontry(bohater, kontra) VALUES ('Olaf', 'Volibear');
INSERT INTO kontry(bohater, kontra) VALUES ('Olaf', 'Shaco');
INSERT INTO kontry(bohater, kontra) VALUES ('Orianna', 'Katarina');
INSERT INTO kontry(bohater, kontra) VALUES ('Orianna', 'Vladimir');
INSERT INTO kontry(bohater, kontra) VALUES ('Orianna', 'Galio');
INSERT INTO kontry(bohater, kontra) VALUES ('Ornn', 'Shen');
INSERT INTO kontry(bohater, kontra) VALUES ('Ornn', 'Viego');
INSERT INTO kontry(bohater, kontra) VALUES ('Ornn', 'Trundle');
INSERT INTO kontry(bohater, kontra) VALUES ('Pantheon', 'Leona');
INSERT INTO kontry(bohater, kontra) VALUES ('Pantheon', 'Nautilus');
INSERT INTO kontry(bohater, kontra) VALUES ('Pantheon', 'Rakan');
INSERT INTO kontry(bohater, kontra) VALUES ('Poppy', 'Darius');
INSERT INTO kontry(bohater, kontra) VALUES ('Poppy', 'Diana');
INSERT INTO kontry(bohater, kontra) VALUES ('Poppy', 'Nasus');
INSERT INTO kontry(bohater, kontra) VALUES ('Pyke', 'Thresh');
INSERT INTO kontry(bohater, kontra) VALUES ('Pyke', 'Lulu');
INSERT INTO kontry(bohater, kontra) VALUES ('Pyke', 'Yuumi');
INSERT INTO kontry(bohater, kontra) VALUES ('Qiyana', 'Diana');
INSERT INTO kontry(bohater, kontra) VALUES ('Qiyana', 'Yasuo');
INSERT INTO kontry(bohater, kontra) VALUES ('Qiyana', 'Fizz');
INSERT INTO kontry(bohater, kontra) VALUES ('Quinn', 'Malphite');
INSERT INTO kontry(bohater, kontra) VALUES ('Quinn', 'Urgot');
INSERT INTO kontry(bohater, kontra) VALUES ('Quinn', 'Maokai');
INSERT INTO kontry(bohater, kontra) VALUES ('Rakan', 'Morgana');
INSERT INTO kontry(bohater, kontra) VALUES ('Rakan', 'Lux');
INSERT INTO kontry(bohater, kontra) VALUES ('Rakan', 'Zilean');
INSERT INTO kontry(bohater, kontra) VALUES ('Rammus', 'Volibear');
INSERT INTO kontry(bohater, kontra) VALUES ('Rammus', 'Amumu');
INSERT INTO kontry(bohater, kontra) VALUES ('Rammus', 'Morgana');
INSERT INTO kontry(bohater, kontra) VALUES ('Rek''Sai', 'Morgana');
INSERT INTO kontry(bohater, kontra) VALUES ('Rek''Sai', 'Volibear');
INSERT INTO kontry(bohater, kontra) VALUES ('Rek''Sai', 'Graves');
INSERT INTO kontry(bohater, kontra) VALUES ('Rell', 'Lux');
INSERT INTO kontry(bohater, kontra) VALUES ('Rell', 'Janna');
INSERT INTO kontry(bohater, kontra) VALUES ('Rell', 'Morgana');
INSERT INTO kontry(bohater, kontra) VALUES ('Renekton', 'Jax');
INSERT INTO kontry(bohater, kontra) VALUES ('Renekton', 'Cho''Gath');
INSERT INTO kontry(bohater, kontra) VALUES ('Renekton', 'Darius');
INSERT INTO kontry(bohater, kontra) VALUES ('Rengar', 'Kayn');
INSERT INTO kontry(bohater, kontra) VALUES ('Rengar', 'Rammus');
INSERT INTO kontry(bohater, kontra) VALUES ('Rengar', 'Master Yi');
INSERT INTO kontry(bohater, kontra) VALUES ('Riven', 'Darius');
INSERT INTO kontry(bohater, kontra) VALUES ('Riven', 'Viego');
INSERT INTO kontry(bohater, kontra) VALUES ('Riven', 'Cho''Gath');
INSERT INTO kontry(bohater, kontra) VALUES ('Rumble', 'Master Yi');
INSERT INTO kontry(bohater, kontra) VALUES ('Rumble', 'Kayn');
INSERT INTO kontry(bohater, kontra) VALUES ('Rumble', 'Camille');
INSERT INTO kontry(bohater, kontra) VALUES ('Ryze', 'Yone');
INSERT INTO kontry(bohater, kontra) VALUES ('Ryze', 'Vladimir');
INSERT INTO kontry(bohater, kontra) VALUES ('Ryze', 'Zed');
INSERT INTO kontry(bohater, kontra) VALUES ('Samira', 'Jinx');
INSERT INTO kontry(bohater, kontra) VALUES ('Samira', 'Ashe');
INSERT INTO kontry(bohater, kontra) VALUES ('Samira', 'Jhin');
INSERT INTO kontry(bohater, kontra) VALUES ('Sejuani', 'Morgana');
INSERT INTO kontry(bohater, kontra) VALUES ('Sejuani', 'Kha''Zix');
INSERT INTO kontry(bohater, kontra) VALUES ('Sejuani', 'Olaf');
INSERT INTO kontry(bohater, kontra) VALUES ('Senna', 'Blitzcrank');
INSERT INTO kontry(bohater, kontra) VALUES ('Senna', 'Nautilus');
INSERT INTO kontry(bohater, kontra) VALUES ('Senna', 'Leona');
INSERT INTO kontry(bohater, kontra) VALUES ('Seraphine', 'Yuumi');
INSERT INTO kontry(bohater, kontra) VALUES ('Seraphine', 'Nami');
INSERT INTO kontry(bohater, kontra) VALUES ('Seraphine', 'Yasuo');
INSERT INTO kontry(bohater, kontra) VALUES ('Sett', 'Lulu');
INSERT INTO kontry(bohater, kontra) VALUES ('Sett', 'Yorick');
INSERT INTO kontry(bohater, kontra) VALUES ('Sett', 'Ornn');
INSERT INTO kontry(bohater, kontra) VALUES ('Shaco', 'Xin Zhao');
INSERT INTO kontry(bohater, kontra) VALUES ('Shaco', 'Diana');
INSERT INTO kontry(bohater, kontra) VALUES ('Shaco', 'Morgana');
INSERT INTO kontry(bohater, kontra) VALUES ('Shen', 'Riven');
INSERT INTO kontry(bohater, kontra) VALUES ('Shen', 'Urgot');
INSERT INTO kontry(bohater, kontra) VALUES ('Shen', 'Sett');
INSERT INTO kontry(bohater, kontra) VALUES ('Shyvana', 'Nocturne');
INSERT INTO kontry(bohater, kontra) VALUES ('Shyvana', 'Olaf');
INSERT INTO kontry(bohater, kontra) VALUES ('Shyvana', 'Nunu i Willump');
INSERT INTO kontry(bohater, kontra) VALUES ('Singed', 'Darius');
INSERT INTO kontry(bohater, kontra) VALUES ('Singed', 'Aatrox');
INSERT INTO kontry(bohater, kontra) VALUES ('Singed', 'Garen');
INSERT INTO kontry(bohater, kontra) VALUES ('Sion', 'Cho''Gath');
INSERT INTO kontry(bohater, kontra) VALUES ('Sion', 'Aatrox');
INSERT INTO kontry(bohater, kontra) VALUES ('Sion', 'Sett');
INSERT INTO kontry(bohater, kontra) VALUES ('Sivir', 'Ashe');
INSERT INTO kontry(bohater, kontra) VALUES ('Sivir', 'Jinx');
INSERT INTO kontry(bohater, kontra) VALUES ('Sivir', 'Karthus');
INSERT INTO kontry(bohater, kontra) VALUES ('Skarner', 'Jarvan IV');
INSERT INTO kontry(bohater, kontra) VALUES ('Skarner', 'Hecarim');
INSERT INTO kontry(bohater, kontra) VALUES ('Skarner', 'Diana');
INSERT INTO kontry(bohater, kontra) VALUES ('Sona', 'Lulu');
INSERT INTO kontry(bohater, kontra) VALUES ('Sona', 'Senna');
INSERT INTO kontry(bohater, kontra) VALUES ('Sona', 'Leona');
INSERT INTO kontry(bohater, kontra) VALUES ('Soraka', 'Yuumi');
INSERT INTO kontry(bohater, kontra) VALUES ('Soraka', 'Sona');
INSERT INTO kontry(bohater, kontra) VALUES ('Soraka', 'Morgana');
INSERT INTO kontry(bohater, kontra) VALUES ('Swain', 'Lulu');
INSERT INTO kontry(bohater, kontra) VALUES ('Swain', 'Morgana');
INSERT INTO kontry(bohater, kontra) VALUES ('Swain', 'Karma');
INSERT INTO kontry(bohater, kontra) VALUES ('Sylas', 'Malzahar');
INSERT INTO kontry(bohater, kontra) VALUES ('Sylas', 'Urgot');
INSERT INTO kontry(bohater, kontra) VALUES ('Sylas', 'Galio');
INSERT INTO kontry(bohater, kontra) VALUES ('Syndra', 'Kassadin');
INSERT INTO kontry(bohater, kontra) VALUES ('Syndra', 'Katarina');
INSERT INTO kontry(bohater, kontra) VALUES ('Syndra', 'Vladimir');
INSERT INTO kontry(bohater, kontra) VALUES ('Tahm Kench', 'Mordekaiser');
INSERT INTO kontry(bohater, kontra) VALUES ('Tahm Kench', 'Yorick');
INSERT INTO kontry(bohater, kontra) VALUES ('Tahm Kench', 'Senna');
INSERT INTO kontry(bohater, kontra) VALUES ('Taliyah', 'Morgana');
INSERT INTO kontry(bohater, kontra) VALUES ('Taliyah', 'Diana');
INSERT INTO kontry(bohater, kontra) VALUES ('Taliyah', 'Zed');
INSERT INTO kontry(bohater, kontra) VALUES ('Talon', 'Annie');
INSERT INTO kontry(bohater, kontra) VALUES ('Talon', 'Akali');
INSERT INTO kontry(bohater, kontra) VALUES ('Talon', 'Swain');
INSERT INTO kontry(bohater, kontra) VALUES ('Taric', 'Lulu');
INSERT INTO kontry(bohater, kontra) VALUES ('Taric', 'Senna');
INSERT INTO kontry(bohater, kontra) VALUES ('Taric', 'Leona');
INSERT INTO kontry(bohater, kontra) VALUES ('Teemo', 'Malphite');
INSERT INTO kontry(bohater, kontra) VALUES ('Teemo', 'Aatrox');
INSERT INTO kontry(bohater, kontra) VALUES ('Teemo', 'Urgot');
INSERT INTO kontry(bohater, kontra) VALUES ('Thresh', 'Lulu');
INSERT INTO kontry(bohater, kontra) VALUES ('Thresh', 'Nami');
INSERT INTO kontry(bohater, kontra) VALUES ('Thresh', 'Leona');
INSERT INTO kontry(bohater, kontra) VALUES ('Tristana', 'Jinx');
INSERT INTO kontry(bohater, kontra) VALUES ('Tristana', 'Kog''Maw');
INSERT INTO kontry(bohater, kontra) VALUES ('Tristana', 'Samira');
INSERT INTO kontry(bohater, kontra) VALUES ('Trundle', 'Mordekaiser');
INSERT INTO kontry(bohater, kontra) VALUES ('Trundle', 'Volibear');
INSERT INTO kontry(bohater, kontra) VALUES ('Trundle', 'Urgot');
INSERT INTO kontry(bohater, kontra) VALUES ('Tryndamere', 'Urgot');
INSERT INTO kontry(bohater, kontra) VALUES ('Tryndamere', 'Malphite');
INSERT INTO kontry(bohater, kontra) VALUES ('Tryndamere', 'Sion');
INSERT INTO kontry(bohater, kontra) VALUES ('Twisted Fate', 'Lux');
INSERT INTO kontry(bohater, kontra) VALUES ('Twisted Fate', 'Seraphine');
INSERT INTO kontry(bohater, kontra) VALUES ('Twisted Fate', 'Vel''Koz');
INSERT INTO kontry(bohater, kontra) VALUES ('Twitch', 'Kai''Sa');
INSERT INTO kontry(bohater, kontra) VALUES ('Twitch', 'Senna');
INSERT INTO kontry(bohater, kontra) VALUES ('Twitch', 'Yasuo');
INSERT INTO kontry(bohater, kontra) VALUES ('Udyr', 'Kha''Zix');
INSERT INTO kontry(bohater, kontra) VALUES ('Udyr', 'Volibear');
INSERT INTO kontry(bohater, kontra) VALUES ('Udyr', 'Zac');
INSERT INTO kontry(bohater, kontra) VALUES ('Urgot', 'Malphite');
INSERT INTO kontry(bohater, kontra) VALUES ('Urgot', 'Sion');
INSERT INTO kontry(bohater, kontra) VALUES ('Urgot', 'Garen');
INSERT INTO kontry(bohater, kontra) VALUES ('Varus', 'Jinx');
INSERT INTO kontry(bohater, kontra) VALUES ('Varus', 'Tristana');
INSERT INTO kontry(bohater, kontra) VALUES ('Varus', 'Kog''Maw');
INSERT INTO kontry(bohater, kontra) VALUES ('Vayne', 'Jinx');
INSERT INTO kontry(bohater, kontra) VALUES ('Vayne', 'Ashe');
INSERT INTO kontry(bohater, kontra) VALUES ('Vayne', 'Kog''Maw');
INSERT INTO kontry(bohater, kontra) VALUES ('Veigar', 'Yone');
INSERT INTO kontry(bohater, kontra) VALUES ('Veigar', 'Kennen');
INSERT INTO kontry(bohater, kontra) VALUES ('Veigar', 'Malzahar');
INSERT INTO kontry(bohater, kontra) VALUES ('Vel''Koz', 'Thresh');
INSERT INTO kontry(bohater, kontra) VALUES ('Vel''Koz', 'Akali');
INSERT INTO kontry(bohater, kontra) VALUES ('Vel''Koz', 'Katarina');
INSERT INTO kontry(bohater, kontra) VALUES ('Vi', 'Hecarim');
INSERT INTO kontry(bohater, kontra) VALUES ('Vi', 'Poppy');
INSERT INTO kontry(bohater, kontra) VALUES ('Vi', 'Volibear');
INSERT INTO kontry(bohater, kontra) VALUES ('Viego', 'Nunu i Willump');
INSERT INTO kontry(bohater, kontra) VALUES ('Viego', 'Elise');
INSERT INTO kontry(bohater, kontra) VALUES ('Viego', 'Udyr');
INSERT INTO kontry(bohater, kontra) VALUES ('Viktor', 'Yone');
INSERT INTO kontry(bohater, kontra) VALUES ('Viktor', 'Vladimir');
INSERT INTO kontry(bohater, kontra) VALUES ('Viktor', 'Corki');
INSERT INTO kontry(bohater, kontra) VALUES ('Vladimir', 'Malzahar');
INSERT INTO kontry(bohater, kontra) VALUES ('Vladimir', 'Diana');
INSERT INTO kontry(bohater, kontra) VALUES ('Vladimir', 'Gnar');
INSERT INTO kontry(bohater, kontra) VALUES ('Volibear', 'Nasus');
INSERT INTO kontry(bohater, kontra) VALUES ('Volibear', 'Diana');
INSERT INTO kontry(bohater, kontra) VALUES ('Volibear', 'Ekko');
INSERT INTO kontry(bohater, kontra) VALUES ('Warwick', 'Volibear');
INSERT INTO kontry(bohater, kontra) VALUES ('Warwick', 'Ekko');
INSERT INTO kontry(bohater, kontra) VALUES ('Warwick', 'Rammus');
INSERT INTO kontry(bohater, kontra) VALUES ('Xayah', 'Jinx');
INSERT INTO kontry(bohater, kontra) VALUES ('Xayah', 'Samira');
INSERT INTO kontry(bohater, kontra) VALUES ('Xayah', 'Senna');
INSERT INTO kontry(bohater, kontra) VALUES ('Xerath', 'Leona');
INSERT INTO kontry(bohater, kontra) VALUES ('Xerath', 'Zilean');
INSERT INTO kontry(bohater, kontra) VALUES ('Xerath', 'Annie');
INSERT INTO kontry(bohater, kontra) VALUES ('Xin Zhao', 'Volibear');
INSERT INTO kontry(bohater, kontra) VALUES ('Xin Zhao', 'Hecarim');
INSERT INTO kontry(bohater, kontra) VALUES ('Xin Zhao', 'Warwick');
INSERT INTO kontry(bohater, kontra) VALUES ('Yasuo', 'Vladimir');
INSERT INTO kontry(bohater, kontra) VALUES ('Yasuo', 'Lissandra');
INSERT INTO kontry(bohater, kontra) VALUES ('Yasuo', 'Yone');
INSERT INTO kontry(bohater, kontra) VALUES ('Yone', 'Vladimir');
INSERT INTO kontry(bohater, kontra) VALUES ('Yone', 'Anivia');
INSERT INTO kontry(bohater, kontra) VALUES ('Yone', 'Ahri');
INSERT INTO kontry(bohater, kontra) VALUES ('Yorick', 'Wukong');
INSERT INTO kontry(bohater, kontra) VALUES ('Yorick', 'Cho''Gath');
INSERT INTO kontry(bohater, kontra) VALUES ('Yorick', 'Morgana');
INSERT INTO kontry(bohater, kontra) VALUES ('Yuumi', 'Lulu');
INSERT INTO kontry(bohater, kontra) VALUES ('Yuumi', 'Leona');
INSERT INTO kontry(bohater, kontra) VALUES ('Yuumi', 'Thresh');
INSERT INTO kontry(bohater, kontra) VALUES ('Zac', 'Morgana');
INSERT INTO kontry(bohater, kontra) VALUES ('Zac', 'Amumu');
INSERT INTO kontry(bohater, kontra) VALUES ('Zac', 'Nunu i Willump');
INSERT INTO kontry(bohater, kontra) VALUES ('Zed', 'Vladimir');
INSERT INTO kontry(bohater, kontra) VALUES ('Zed', 'Malzahar');
INSERT INTO kontry(bohater, kontra) VALUES ('Zed', 'Ekko');
INSERT INTO kontry(bohater, kontra) VALUES ('Ziggs', 'Malzahar');
INSERT INTO kontry(bohater, kontra) VALUES ('Ziggs', 'LeBlanc');
INSERT INTO kontry(bohater, kontra) VALUES ('Ziggs', 'Samira');
INSERT INTO kontry(bohater, kontra) VALUES ('Zilean', 'Bard');
INSERT INTO kontry(bohater, kontra) VALUES ('Zilean', 'Janna');
INSERT INTO kontry(bohater, kontra) VALUES ('Zilean', 'Jinx');
INSERT INTO kontry(bohater, kontra) VALUES ('Zoe', 'Katarina');
INSERT INTO kontry(bohater, kontra) VALUES ('Zoe', 'Ahri');
INSERT INTO kontry(bohater, kontra) VALUES ('Zoe', 'Yasuo');
INSERT INTO kontry(bohater, kontra) VALUES ('Zyra', 'Xerath');
INSERT INTO kontry(bohater, kontra) VALUES ('Zyra', 'Leona');
INSERT INTO kontry(bohater, kontra) VALUES ('Zyra', 'Rakan');

INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1001, 'Buty', '<mainText><stats><attention>25</attention> jedn. pr??dko??ci ruchu</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1001.png', 300, 210);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1004, 'Amulet Wr????ki', '<mainText><stats><attention>50%</attention> podstawowej regeneracji many</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1004.png', 250, 175);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1006, 'Koralik Odrodzenia', '<mainText><stats><attention>100%</attention> podstawowej regeneracji zdrowia</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1006.png', 300, 120);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1011, 'Pas Giganta', '<mainText><stats><attention>350 pkt.</attention> zdrowia</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1011.png', 900, 630);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1018, 'P??aszcz Zr??czno??ci', '<mainText><stats><attention>15%</attention> szansy na trafienie krytyczne</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1018.png', 600, 420);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1026, 'R????d??ka Zniszczenia', '<mainText><stats><attention>40 pkt.</attention> mocy umiej??tno??ci</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1026.png', 850, 595);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1027, 'Szafirowy Kryszta??', '<mainText><stats><attention>250 pkt.</attention> many</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1027.png', 350, 245);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1028, 'Rubinowy Kryszta??', '<mainText><stats><attention>150 pkt.</attention> zdrowia</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1028.png', 400, 280);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1029, 'Lekka Szata', '<mainText><stats><attention>15 pkt.</attention> pancerza</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1029.png', 300, 210);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1031, 'Kamizelka Kolcza', '<mainText><stats><attention>40 pkt.</attention> pancerza</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1031.png', 800, 560);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1033, 'Opo??cza Antymagiczna', '<mainText><stats><attention>25 pkt.</attention> odporno??ci na magi??</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1033.png', 450, 315);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1035, '??aron????', '<mainText><stats></stats><li><passive>Przypalenie:</passive> Zadawanie obra??e?? potworom podpala je na okre??lony czas.<li><passive>Wyzywaj??ca ??cie??ka:</passive> U??ycie Pora??enia 5 razy zu??ywa ten przedmiot i ulepsza Pora??enie do <attention>Wyzywaj??cego Pora??enia</attention>, kt??re zadaje potworom zwi??kszone obra??enia. Wyzywaj??ce Pora??enie oznacza bohater??w. W tym czasie zadajesz im przy trafieniu dodatkowe obra??enia nieuchronne i otrzymujesz od nich mniejsze obra??enia.<li><passive>??owca:</passive> Zabijanie du??ych potwor??w zapewnia dodatkowe do??wiadczenie.<li><passive>Odzyskiwanie:</passive> Regenerujesz man??, gdy znajdujesz si?? w d??ungli lub w rzece. <br><br><rules><status>Zu??ycie</status> tego przedmiotu na sta??e przyznaje wszystkie jego efekty oraz zwi??ksza obra??enia zadawane potworom przez Pora??enie. W przypadku zdobycia wi??kszej liczby szt. z??ota ze stwor??w ni?? z potwor??w z d??ungli ilo???? z??ota i do??wiadczenia zdobywanego ze stwor??w jest znacznie zmniejszona. Leczenie nie jest zmniejszone przy atakach obszarowych. Je??li bohater posiada poziom ni??szy o 2 od ??redniego poziomu bohater??w w grze, zabijanie potwor??w daje mu dodatkowe pkt. do??wiadczenia. </rules><br><br><rules>Tylko ataki i umiej??tno??ci nak??adaj?? efekt podpalenia Wyzywaj??cego Pora??enia.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1035.png', 350, 140);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1036, 'D??ugi Miecz', '<mainText><stats><attention>10 pkt.</attention> obra??e?? od ataku</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1036.png', 350, 245);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1037, 'Kilof', '<mainText><stats><attention>25 pkt.</attention> obra??e?? od ataku</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1037.png', 875, 613);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1038, 'K. W. Miecz', '<mainText><stats><attention>40 pkt.</attention> obra??e?? od ataku</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1038.png', 1300, 910);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1039, 'Gradoostrze', '<mainText><stats></stats><li><passive>Przypalenie:</passive> Zadawanie obra??e?? potworom podpala je na okre??lony czas.<li><passive>Mro????ca ??cie??ka:</passive> U??ycie Pora??enia 5 razy zu??ywa ten przedmiot i ulepsza Pora??enie do <attention>Mro????cego Pora??enia</attention>, kt??re zadaje potworom zwi??kszone obra??enia. Gdy u??ywasz Mro????cego Pora??enia na bohaterach, zadajesz im obra??enia nieuchronne i wykradasz ich pr??dko???? ruchu.<li><passive>??owca:</passive> Zabijanie du??ych potwor??w zapewnia dodatkowe pkt. do??wiadczenia.<li><passive>Odzyskiwanie:</passive> Regenerujesz man??, gdy znajdujesz si?? w d??ungli lub w rzece. <br><br><rules><status>Zu??ycie</status> tego przedmiotu na sta??e przyznaje wszystkie jego efekty oraz zwi??ksza obra??enia zadawane potworom przez Pora??enie. W przypadku zdobycia wi??kszej liczby szt. z??ota ze stwor??w ni?? z potwor??w z d??ungli ilo???? z??ota i do??wiadczenia zdobywanego ze stwor??w jest znacznie zmniejszona. Leczenie nie jest zmniejszone przy atakach obszarowych. Je??li bohater posiada poziom ni??szy o 2 od ??redniego poziomu bohater??w w grze, zabijanie potwor??w daje mu dodatkowe pkt. do??wiadczenia. </rules><br><br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1039.png', 350, 140);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1040, 'Obsydianowe Ostrze', '<mainText><stats></stats><li><passive>Przypalenie:</passive> Zadawanie obra??e?? potworom podpala je na okre??lony czas.<li><passive>Auto??cie??ka:</passive> U??ycie Pora??enia 5 razy zu??ywa ten przedmiot i ulepsza Pora??enie do Ataku-Pora??enia, zwi??kszaj??c jego obra??enia przeciwko potworom.<li><passive>??owca:</passive> Zabijanie du??ych potwor??w daje dodatkowe pkt. do??wiadczenia.<li><passive>Odzyskiwanie:</passive> Regenerujesz man??, gdy znajdujesz si?? w d??ungli lub w rzece. <br><br><rules><status>Zu??ycie</status> tego przedmiotu na sta??e przyznaje wszystkie jego efekty oraz zwi??ksza obra??enia zadawane potworom przez Pora??enie. W przypadku zdobycia wi??kszej liczby szt. z??ota ze stwor??w ni?? z potwor??w z d??ungli ilo???? z??ota i do??wiadczenia zdobywanego ze stwor??w jest znacznie zmniejszona. Leczenie nie jest zmniejszone przy atakach obszarowych. Je??li bohater posiada poziom ni??szy o 2 od ??redniego poziomu bohater??w w grze, zabijanie potwor??w daje mu dodatkowe pkt. do??wiadczenia. </rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1040.png', 350, 140);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1042, 'Sztylet', '<mainText><stats><attention>12%</attention> pr??dko??ci ataku</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1042.png', 300, 210);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1043, 'Wygi??ty ??uk', '<mainText><stats><attention>25%</attention> pr??dko??ci ataku</stats><br><li><passive>Stalowy Czubek:</passive> Ataki zadaj?? obra??enia fizyczne przy trafieniu.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1043.png', 1000, 700);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1052, 'Wzmacniaj??ca Ksi??ga', '<mainText><stats><attention>20 pkt.</attention> mocy umiej??tno??ci</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1052.png', 435, 305);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1053, 'Wampiryczny Kostur', '<mainText><stats><attention>15 pkt.</attention> obra??e?? od ataku<br><attention>7%</attention> kradzie??y ??ycia</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1053.png', 900, 630);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1054, 'Tarcza Dorana', '<mainText><stats><attention>80 pkt.</attention> zdrowia</stats><br><li><passive>Skupienie:</passive> Ataki zadaj?? dodatkowe obra??enia stworom.<li><passive>Regeneracja:</passive> Przywraca zdrowie z up??ywem czasu.<li><passive>Przetrwanie:</passive> Przywraca zdrowie po otrzymaniu obra??e?? od bohatera, du??ego potwora z d??ungli lub pot????nego potwora z d??ungli. Efektywno???? przywracania zwi??ksza si??, gdy masz ma??o zdrowia.<br><br><rules><passive>Przetrwanie</passive> jest skuteczne w 66%, gdy posiadacz tego przedmiotu jest bohaterem walcz??cym z dystansu albo gdy otrzyma obra??enia obszarowe lub roz??o??one w czasie.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1054.png', 450, 180);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1055, 'Ostrze Dorana', '<mainText><stats><attention>8 pkt.</attention> obra??e?? od ataku<br><attention>80 pkt.</attention> zdrowia</stats><br><li><passive>Wata??ka:</passive> Zyskujesz wszechwampiryzm.<br><br><rules>Wszechwampiryzm jest skuteczny w 33% w przypadku obra??e?? obszarowych i obra??e?? zadawanych przez zwierz??tka.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1055.png', 450, 180);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1056, 'Pier??cie?? Dorana', '<mainText><stats><attention>15 pkt.</attention> mocy umiej??tno??ci<br><attention>70 pkt.</attention> zdrowia</stats><br><li><passive>Skupienie:</passive> Ataki zadaj?? dodatkowe obra??enia stworom. <li><passive>Czerpanie:</passive> Co sekund?? przywraca man??. Zadawanie obra??e?? wrogiemu bohaterowi zwi??ksza t?? warto????. Je??li nie mo??esz zyska?? many, przywraca ci zdrowie. </mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1056.png', 400, 160);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1057, 'P??aszcz Negacji', '<mainText><stats><attention>50 pkt.</attention> odporno??ci na magi??</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1057.png', 900, 630);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1058, 'Absurdalnie Wielka R????d??ka', '<mainText><stats><attention>60 pkt.</attention> mocy umiej??tno??ci</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1058.png', 1250, 875);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1082, 'Tajemnicza Piecz????', '<mainText><stats><attention>15 pkt.</attention> mocy umiej??tno??ci<br><attention>40 pkt.</attention> zdrowia</stats><br><li><passive>Chwa??a:</passive> Zab??jstwo bohatera zapewnia ci nast??puj??c?? liczb?? ??adunk??w: 2, podczas gdy asysta gwarantuje ci ??adunki w liczbie: 1 (????cznie do 10 ??adunk??w). Tracisz nast??puj??c?? liczb?? ??adunk??w po ??mierci: 5.<li><passive>Postrach:</passive> Zapewnia <scaleAP>4 pkt. mocy umiej??tno??ci</scaleAP> za ka??dy ??adunek <passive>Chwa??y</passive>.<br><br><rules>Zdobyte ??adunki <passive>Chwa??y</passive> s?? zachowane pomi??dzy tym przedmiotem i <rarityLegendary>Wykradaczem Dusz Mejai</rarityLegendary>.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1082.png', 350, 140);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1083, 'Kosa', '<mainText><stats><attention>7 pkt.</attention> obra??e?? od ataku</stats><br><li>Ataki przywracaj?? zdrowie za ka??de trafienie.<li><passive>Skoszenie:</passive> Zabicie stwora w alei zapewnia dodatkowo <goldGain>1 szt.</goldGain> z??ota. Zabicie 100 stwor??w w alei zapewnia <goldGain>350 szt.</goldGain> dodatkowego z??ota oraz wy????cza <passive>Skoszenie</passive>.<br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1083.png', 450, 180);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1101, 'Szczeniak ??aroszpona', '<mainText><stats></stats><li><passive>Towarzysze d??ungli:</passive> Przyzwij <font color=''#DD2E2E''>??aroszpona</font>, by towarzyszy?? ci w d??ungli.<li><passive>Ci??cie ??aroszpona:</passive> Gdy tw??j towarzysz doro??nie, czasami nasyci tw??j nast??pny efekt zadaj??cy obra??enia, by <status>spowalnia??</status> i zadawa?? <passive>obra??enia</passive> wrogim bohaterom.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1101.png', 450, 180);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1102, 'Piskl?? Podmuszka', '<mainText><stats></stats><li><passive>Towarzysze d??ungli:</passive> Przyzwij <font color=''#38A8E8''>Podmuszka</font>, by towarzyszy?? ci w d??ungli.<li><passive>Ch??d Podmuszka:</passive> Gdy tw??j towarzysz doro??nie, zapewni <speed>pr??dko???? ruchu</speed> po wchodzeniu w zaro??la lub zabijaniu potwor??w.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1102.png', 450, 180);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1103, 'Sadzonka Mch??ciciela', '<mainText><stats></stats><li><passive>Towarzysze d??ungli:</passive> Przywo??aj <font color=''#1CA935''>Mch??ciciela</font>, by towarzyszy?? ci w d??ungli. <li><passive>Odwaga Mch??ciciela:</passive> Gdy tw??j towarzysz doro??nie, zapewni <shield>trwa???? tarcz??</shield>, kt??ra odnawia si?? po zabijaniu potwor??w lub poza walk??. Podczas gdy tarcza jest aktywna, zyskaj 20% nieust??pliwo??ci i odporno??ci na spowolnienia.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1103.png', 450, 180);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1104, 'Oko Herolda', '<mainText><stats></stats><active>U??ycie ??? Zu??yj:</active> Zniszcz Oko Herolda, by go przyzwa??. Herold zacznie si?? przemieszcza?? wzd??u?? najbli??szej alei, zadaj??c ogromne obra??enia wie??om, kt??re spotka na swojej drodze.<br><br><passive>Przeb??ysk Pustki:</passive> Zapewnia Wzmocnienie.<br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1104.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1500, 'Pociski Penetruj??ce', '', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1500.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1501, 'Fortyfikacja', '', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1501.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1502, 'Wzmocniona Zbroja', '<mainText><stats></stats><unique>UNIKALNE Bierne ??? Wzmocniony Pancerz:</unique> Zmniejsza otrzymywane obra??enia o 0% i sprawia, ??e wie??a jest niewra??liwa na obra??enia nieuchronne, kiedy w pobli??u nie ma wrogich stwor??w.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1502.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1503, 'Oko Stra??nika', '', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1503.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1504, 'Awangarda', '', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1504.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1505, 'Piorunochron', '', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1505.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1506, 'Wzmocniona Zbroja', '<mainText><stats></stats><unique>UNIKALNE Bierne ??? Wzmocniony Pancerz Wie??y w Bazie:</unique> Zmniejsza otrzymywane obra??enia o 0% i sprawia, ??e wie??a jest niewra??liwa na obra??enia nieuchronne, kiedy w pobli??u nie ma wrogich stwor??w. Wie??e w bazie posiadaj?? regeneracj?? zdrowia, ale jest ona ograniczona przez segmenty. Te segmenty znajduj?? si?? na 33%, 66% i 100% zdrowia w przypadku wie?? w bazie.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1506.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1507, 'Prze??adowanie', '', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1507.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1508, 'Skarpety Przeciwwie??owe', '', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1508.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1509, 'Werwa', '', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1509.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1510, 'Cudaczna Werwa', '', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1510.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1511, 'Mechaniczny Superpancerz', '', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1511.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1512, 'Mechaniczne Superpole Mocy', '', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1512.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1515, 'Opancerzenie Wie??y', '', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1515.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1516, 'Struktura Nagr??d', '', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1516.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1517, 'Struktura Nagr??d', '', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1517.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1518, 'Struktura Nagr??d', '', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1518.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1519, 'Struktura Nagr??d', '', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1519.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(1520, 'Prze??adowanie', '', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/1520.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(2003, 'Mikstura Zdrowia', '<mainText><stats></stats><active>U??ycie ??? Zu??yj:</active> Wypij t?? mikstur??, by przywr??ci?? <healing>120 pkt. zdrowia</healing> w ci??gu 15 sek.<br><br><rules>Mo??esz mie?? ze sob?? maksymalnie 5 Mikstur Zdrowia.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/2003.png', 50, 20);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(2010, 'Ciastko Nieustaj??cej Woli Totalbiscuita', '<mainText><stats></stats><active>U??ycie ??? Zu??yj:</active> Zjedz ciastko, by przywr??ci?? <healing>8% brakuj??cego zdrowia</healing> oraz <scaleMana>many</scaleMana> w ci??gu 5 sek. Zjedzenie lub sprzedanie ciastka na sta??e zapewni ci <scaleMana>40 pkt. maks. many</scaleMana>. </mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/2010.png', 50, 5);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(2015, 'Od??amek Kircheis', '<mainText><stats><attention>15%</attention> pr??dko??ci ataku</stats><br><li><passive>Na??adowanie:</passive> Poruszanie si?? i trafianie atakami generuje Na??adowany atak.<li><passive>Iskra:</passive> Twoje na??adowane ataki zadaj?? dodatkowe obra??enia magiczne.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/2015.png', 700, 490);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(2031, 'Odnawialna Mikstura', '<mainText><stats></stats><active>U??ycie ??? Zu??yj:</active> Zu??ywa ??adunek i przywraca <healing>100 pkt. zdrowia</healing> w ci??gu 12 sek. Przechowuje do 2 ??adunk??w, kt??re odnawiaj?? si??, ilekro?? odwiedzisz sklep.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/2031.png', 150, 60);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(2033, 'Mikstura Ska??enia', '<mainText><stats></stats><active>U??ycie ??? Zu??yj:</active> Zu??ywa ??adunek i przywraca <healing>100 pkt. zdrowia</healing> oraz <scaleMana>75 pkt. many</scaleMana> w ci??gu 12 sek. U??yte w tym czasie zadaj??ce obra??enia ataki oraz umiej??tno??ci podpalaj?? wrogich bohater??w, przez co otrzymuj?? oni <magicDamage>15 (20 pkt., je??li nie mo??esz zyska?? many) pkt. obra??e?? magicznych</magicDamage> w ci??gu 3 sek. Przechowuje do 3 ??adunk??w, kt??re odnawiaj?? si??, ilekro?? odwiedzisz sklep.<br><br><rules>Obra??enia ska??enia zmniejszaj?? si?? do 50%, gdy zostanie ono na??o??one przez obra??enia obszarowe lub roz??o??one w czasie.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/2033.png', 500, 200);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(2051, 'R??g Stra??nika', '<mainText><stats><attention>150 pkt.</attention> zdrowia</stats><br><li><passive>Regeneracja:</passive> Przywraca zdrowie z up??ywem czasu.<li><passive>Niewzruszenie: </passive> Blokuje obra??enia od atak??w i zakl???? bohater??w.<li><passive>Legendarny:</passive> Ten przedmiot zalicza si?? jako <rarityLegendary>legendarny</rarityLegendary>.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/2051.png', 950, 665);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(2052, 'Poro-Chrupki', '<mainText><stats></stats><active>U??ycie ??? Zu??yj:</active> Serwuje przepyszn?? porcj?? pobliskiemu Poro, zwi??kszaj??c jego rozmiary.<br><br><flavorText>Ta mieszanka avarosa??skich kur z wolnego wybiegu i organicznych, niemodyfikowanych freljordzkich zi???? zawiera kluczowe sk??adniki potrzebne, by tw??j Poro mrucza?? z rado??ci.<br><br>Zyski ze sprzeda??y trafi?? na cel walki z noxia??sk?? przemoc?? wobec zwierz??t. </flavorText></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/2052.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(2055, 'Totem Kontroli', '<mainText><stats></stats><active>U??ycie ??? Zu??yj:</active> Umieszcza pot????ny Totem Kontroli, kt??ry zapewnia wizj?? na pobliskim obszarze. To urz??dzenie ujawni tak??e <keywordStealth>niewidzialne</keywordStealth> pu??apki i <keywordStealth>zakamuflowanych</keywordStealth> bohater??w, a tak??e wrogie Totemy Ukrycia, kt??re dodatkowo wy????czy. <br><br><rules>Mo??esz mie?? ze sob?? do 2 Totem??w Kontroli. Totemy Kontroli nie wy????czaj?? innych Totem??w Kontroli.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/2055.png', 75, 30);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(2065, 'Pie???? Bitewna Shurelyi', '<mainText><stats><attention>40 pkt.</attention> mocy umiej??tno??ci<br><attention>200 pkt.</attention> zdrowia<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci<br><attention>100%</attention> podstawowej regeneracji many</stats><br><br><active>U??ycie ???</active> <active>Inspiracja:</active> Zapewnia pobliskim sojusznikom pr??dko???? ruchu.<li><passive>Motywacja:</passive> Wzmocnienie lub ochronienie innego sojuszniczego bohatera zapewni obu sojusznikom pr??dko???? ruchu.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Przyspieszenie umiej??tno??ci.<br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/2065.png', 2500, 1750);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(2138, 'Eliksir ??elaza', '<mainText><stats></stats><active>U??ycie ??? Zu??yj:</active> Wypij, by zyska?? <scaleHealth>300 pkt. zdrowia</scaleHealth>, 25% nieust??pliwo??ci oraz zwi??kszony rozmiar bohatera na 3 min. Gdy ten efekt jest aktywny, podczas poruszania si?? pozostawiasz ??cie??k??, kt??ra zapewnia sojusznikom <speed>15% dodatkowej pr??dko??ci ruchu</speed>.<br><br><rules>Wypicie innego eliksiru zast??pi efekt istniej??cego.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/2138.png', 500, 200);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(2139, 'Eliksir Czarnoksi??stwa', '<mainText><stats></stats><active>U??ycie ??? Zu??yj:</active> Wypij, by zyska?? <scaleAP>50 pkt. mocy umiej??tno??ci</scaleAP> oraz <scaleMana>15% regeneracji many</scaleMana> na 3 min. Gdy ten efekt jest aktywny, trafienie bohatera lub wie??y zadaje <trueDamage>25 pkt. dodatkowych obra??e?? nieuchronnych</trueDamage> (5 sek. odnowienia).<br><br><rules>Wymagany <attention>9.</attention> lub wy??szy poziom do zakupu. Efekt Eliksiru Czarnoksi??stwa zadaj??cy obra??enia nieuchronne nie ma czasu odnowienia, gdy atakujesz wie??e. Wypicie innego Eliksiru zast??pi efekt istniej??cego.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/2139.png', 500, 200);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(2140, 'Eliksir Gniewu', '<mainText><stats></stats><active>U??ycie ??? Zu??yj:</active> Wypij, by zyska?? <scaleAD>30 pkt. obra??e?? od ataku</scaleAD> oraz <lifeSteal>12% fizycznego wampiryzmu</lifeSteal> (przeciwko bohaterom) na 3 min.<br><br><rules>Wypicie innego eliksiru zast??pi efekt istniej??cego.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/2140.png', 500, 200);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(2403, 'Dematerializator Stwor??w', '<mainText><stats></stats><active>U??ycie ??? Zu??yj:</active> Zabij wybranego stwora w alei (10sek. )</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/2403.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(2419, 'Uruchamianie Stopera', '<mainText><stats></stats><li>Po 14 min. zmienia si?? w <rarityGeneric>Stoper</rarityGeneric>. Udzia??y w zab??jstwach skracaj?? ten czas o 2 min. Ten <rarityGeneric>Stoper</rarityGeneric> wnosi 250 szt. z??ota do przedmiot??w, kt??rych jest sk??adnikiem.<br><br><rules>Normalnie wnosi 750 szt. z??ota.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/2419.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(2420, 'Stoper', '<mainText><stats></stats><active>U??ycie ???</active> <active>Inercja:</active> Po jednokrotnym u??yciu zyskujesz <status>niewra??liwo????</status> i <status>nie mo??na obra?? ci?? na cel</status> przez 2.5 sek. Podczas trwania tego efektu nie mo??esz wykonywa?? ??adnych innych czynno??ci (przemienia si?? w <rarityGeneric>Zepsuty Stoper</rarityGeneric>).</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/2420.png', 750, 300);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(2421, 'Zepsuty Stoper', '<mainText><stats></stats><br><li><passive>Ujarzmiony Czas:</passive> Stoper jest zepsuty, ale wci???? mo??e zosta?? ulepszony.<br><br><rules>Po zepsuciu jednego Stopera handlarz sprzeda ci jedynie <rarityGeneric>Zepsute Stopery.</rarityGeneric></rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/2421.png', 750, 300);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(2422, 'Lekko Magiczne Obuwie', '<mainText><stats><attention>25</attention> jedn. pr??dko??ci ruchu</stats><br><li>Zapewniaj?? dodatkowo <speed>10 jedn. pr??dko??ci ruchu</speed>. Buty, kt??re powstan?? z Lekko Magicznego Obuwia, zachowaj?? dodatkow?? pr??dko???? ruchu.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/2422.png', 300, 210);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(2423, 'Stoper o Idealnym Wyczuciu Czasu', '<mainText><stats></stats><active>U??ycie ???</active> <active>Inercja:</active> Po jednokrotnym u??yciu zyskujesz <status>niewra??liwo????</status> i <status>nie mo??na obra?? ci?? na cel</status> przez 2.5 sek. Podczas trwania tego efektu nie mo??esz wykonywa?? ??adnych innych czynno??ci (przemienia si?? w <rarityGeneric>Zepsuty Stoper</rarityGeneric>).</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/2423.png', 750, 300);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(2424, 'Zepsuty Stoper', '<mainText><stats></stats><br><li><passive>Ujarzmiony Czas:</passive> Stoper jest zepsuty, ale wci???? mo??e zosta?? ulepszony.<br><br><rules>Po zepsuciu jednego Stopera handlarz sprzeda ci jedynie <rarityGeneric>Zepsute Stopery.</rarityGeneric></rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/2424.png', 750, 300);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3001, 'Zas??ona R??wno??ci', '<mainText><stats><attention>200 pkt.</attention> zdrowia<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci<br><attention>30 pkt.</attention> pancerza<br><attention>30 pkt.</attention> odporno??ci na magi??</stats><br><li><passive>Iskrzenie:</passive> Po <status>unieruchomieniu</status> bohater??w lub gdy bohater sam zostanie <status>unieruchomiony</status>, zwi??ksza obra??enia otrzymywane przez cel i wszystkich pobliskich wrogich bohater??w.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom <attention> Pancerz i odporno???? na magi??</attention></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3001.png', 2500, 1750);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3003, 'Kostur Archanio??a', '<mainText><stats><attention>80 pkt.</attention> mocy umiej??tno??ci<br><attention>500 pkt.</attention> many<br><attention>200 pkt.</attention> zdrowia<br><attention>10</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Podziw:</passive> Zyskujesz moc umiej??tno??ci r??wn?? dodatkowej manie.<li><passive>Do??adowanie Many:</passive> Traf cel umiej??tno??ci??, by poch??on???? do??adowanie i zyska?? 3 pkt. dodatkowej many. Pkt. dodatkowej many s?? podwojone, je??eli cel jest bohaterem. Zapewnia maks. 360 pkt. many, po czym przemienia si?? w <rarityLegendary>U??cisk Serafina</rarityLegendary>.<br><br><rules>Zyskujesz nowe <passive>Do??adowanie Many</passive> co 8 sek. (maks. 4).</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3003.png', 3000, 2100);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3004, 'Manamune', '<mainText><stats><attention>35 pkt.</attention> obra??e?? od ataku<br><attention>500 pkt.</attention> many<br><attention>15</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Podziw:</passive> Zyskujesz dodatkowe <scaleAD>obra??enia od ataku r??wne maksymalnej liczbie pkt. many</scaleAD>. <li><passive>Do??adowanie Many:</passive> Traf cel umiej??tno??ci?? lub atakiem, by poch??on???? do??adowanie i zyska?? <scaleMana>3 pkt. dodatkowej many</scaleMana>, podwojone, gdy cel jest bohaterem. Zapewnia maks. 360 pkt. many, po czym przemienia si?? w <rarityLegendary>Muraman??</rarityLegendary>.<br><br><rules>Zyskujesz nowe <passive>Do??adowanie Many</passive> co 8 sek. (maks. 4).</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3004.png', 2900, 2030);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3006, 'Nagolenniki Berserkera', '<mainText><stats><attention>35%</attention> pr??dko??ci ataku<br><attention>45</attention> jedn. pr??dko??ci ruchu</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3006.png', 1100, 770);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3009, 'Buty Pr??dko??ci', '<mainText><stats><attention>60</attention> jedn. pr??dko??ci ruchu</stats><br><li>Efekty spowalniaj??ce pr??dko???? ruchu s?? os??abione o 25%.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3009.png', 900, 630);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3011, 'Chemtechowy Skaziciel', '<mainText><stats><attention>60 pkt.</attention> mocy umiej??tno??ci<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci<br><attention>100%</attention> podstawowej regeneracji many</stats><br><li><passive>Gnij??ca Toksyna:</passive> Zadawanie wrogim bohaterom obra??e?? magicznych nak??ada na nich <status>G????bokie Rany o warto??ci 25%</status> na 3 sek. Uleczenie lub os??oni??cie innego sojusznika tarcz?? wzmocni was, sprawiaj??c, ??e przy nast??pnym trafieniu wroga na??o??ycie na cel <status>G????bokie Rany o warto??ci 40%</status>.<br><br><rules><status>G????bokie Rany</status> os??abiaj?? efektywno???? leczenia i regeneracji.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3011.png', 2300, 1610);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3020, 'Obuwie Maga', '<mainText><stats><attention>18 pkt.</attention> przebicia odporno??ci na magi??<br><attention>45</attention> jedn. pr??dko??ci ruchu</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3020.png', 1100, 770);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3024, 'Mro??ny Puklerz', '<mainText><stats><attention>20 pkt.</attention> pancerza<br><attention>250 pkt.</attention> many<br><attention>10</attention> jedn. przyspieszenia umiej??tno??ci</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3024.png', 900, 630);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3026, 'Anio?? Str????', '<mainText><stats><attention>45 pkt.</attention> obra??e?? od ataku<br><attention>40 pkt.</attention> pancerza</stats><br><li><passive>Zbawienie:</passive> Po otrzymaniu ??miertelnych obra??e?? przywraca <healing>50% podstawowego zdrowia</healing> i <scaleMana>30% maksymalnej many</scaleMana> po 4 sek. inercji (300 sek. odnowienia).</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3026.png', 3000, 1200);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3031, 'Ostrze Niesko??czono??ci', '<mainText><stats><attention>70 pkt.</attention> obra??e?? od ataku<br><attention>20%</attention> szansy na trafienie krytyczne</stats><br><li><passive>Perfekcja:</passive> Je??li masz co najmniej 60% szansy na trafienie krytyczne, zyskujesz 35% obra??e?? trafienia krytycznego.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3031.png', 3400, 2380);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3033, '??miertelne Przypomnienie', '<mainText><stats><attention>35 pkt.</attention> obra??e?? od ataku<br><attention>20%</attention> pr??dko??ci ataku<br><attention>20%</attention> szansy na trafienie krytyczne<br><attention>7%</attention> pr??dko??ci ruchu</stats><br><li><passive>Sepsa:</passive> Zadawanie wrogim bohaterom obra??e?? fizycznych nak??ada na nich <status>G????bokie Rany o warto??ci 25%</status> na 3 sek. Trafienie tego bohatera atakami z rz??du wzmocni efekt <status>G????bokich Ran do 40%</status> przeciwko temu bohaterowi, dop??ki efekt pozostanie aktywny.<br><br><rules><status>G????bokie Rany</status> os??abiaj?? efektywno???? leczenia i regeneracji.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3033.png', 2600, 1820);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3035, 'Ostatni Szept', '<mainText><stats><attention>20 pkt.</attention> obra??e?? od ataku<br><attention>18%</attention> przebicia pancerza</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3035.png', 1450, 1015);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3036, 'Pozdrowienia Lorda Dominika', '<mainText><stats><attention>30 pkt.</attention> obra??e?? od ataku<br><attention>20%</attention> szansy na trafienie krytyczne<br><attention>30%</attention> przebicia pancerza</stats><br><li><passive>Pogromca Olbrzym??w:</passive> Zadaje dodatkowe obra??enia fizyczne przeciwko bohaterom, kt??rzy maja wi??cej maksymalnego zdrowia od ciebie.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3036.png', 3000, 2100);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3040, 'U??cisk Serafina', '<mainText><stats><attention>80 pkt.</attention> mocy umiej??tno??ci<br><attention>860 pkt.</attention> many<br><attention>250 pkt.</attention> zdrowia<br><attention>10</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Podziw:</passive> Zyskujesz moc umiej??tno??ci zale??n?? od many.<li><passive>Linia ??ycia:</passive> Przy otrzymaniu obra??e??, kt??re zmniejszy??yby twoje zdrowie do poziomu ni??szego ni?? 30%, zyskujesz tarcz?? o wytrzyma??o??ci zale??nej od aktualnego poziomu many.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3040.png', 3000, 2100);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3041, 'Wykradacz Dusz Mejai', '<mainText><stats><attention>20 pkt.</attention> mocy umiej??tno??ci<br><attention>100 pkt.</attention> zdrowia</stats><br><li><passive>Chwa??a:</passive> Zab??jstwo bohatera zapewnia ci nast??puj??c?? liczb?? ??adunk??w: 4, podczas gdy asysta gwarantuje ci ??adunki w liczbie: 2 (????cznie do 25 ??adunk??w). Tracisz nast??puj??c?? liczb?? ??adunk??w po ??mierci: 10.<li><passive>Postrach:</passive> Zapewnia <scaleAP>5 pkt. mocy umiej??tno??ci</scaleAP> za ka??dy ??adunek <passive>Chwa??y</passive>. Zyskujesz <speed>10% pr??dko??ci ruchu</speed>, je??eli masz co najmniej 10 ??adunk??w.<br><br><rules>Zdobyte ??adunki <passive>Chwa??y</passive> s?? zachowane pomi??dzy tym przedmiotem i <rarityGeneric>Tajemnicz?? Piecz??ci??</rarityGeneric>.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3041.png', 1600, 1120);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3042, 'Muramana', '<mainText><stats><attention>35 pkt.</attention> obra??e?? od ataku<br><attention>860 pkt.</attention> many<br><attention>15</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Podziw:</passive> Zyskujesz dodatkowe obra??enia od ataku w zale??no??ci od many. <li><passive>Szok:</passive> Ataki wymierzone w bohater??w zadaj?? dodatkowe obra??enia fizyczne.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3042.png', 3000, 2100);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3044, 'Po??eracz', '<mainText><stats><attention>15 pkt.</attention> obra??e?? od ataku<br><attention>200 pkt.</attention> zdrowia</stats><br><li><passive>Solidno????:</passive> Po zadaniu bohaterowi obra??e?? fizycznych przywracasz sobie zdrowie.<br><br><rules>Efektywno???? przywracania zdrowia zmniejszona w przypadku bohater??w walcz??cych z dystansu.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3044.png', 1100, 770);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3046, 'Widmowy Tancerz', '<mainText><stats><attention>20 pkt.</attention> obra??e?? od ataku<br><attention>25%</attention> pr??dko??ci ataku<br><attention>20%</attention> szansy na trafienie krytyczne<br><attention>7%</attention> pr??dko??ci ruchu</stats><br><li><passive>Widmowy Walc:</passive> Ataki zapewniaj?? <status>przenikanie</status> i zwi??kszon??, kumuluj??c?? si?? pr??dko???? ruchu. Ponadto zaatakowanie 4 razy powoduje, ??e Widmowy Walc zapewnia r??wnie?? pr??dko???? ataku.<br><br><rules><status>Przenikanie</status> pozwala na unikanie zderzania si?? z innymi jednostkami.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3046.png', 2600, 1820);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3047, 'Pancerniaki', '<mainText><stats><attention>20 pkt.</attention> pancerza<br><attention>45</attention> jedn. pr??dko??ci ruchu</stats><br><li>Zmniejsza obra??enia otrzymywane od atak??w o 12%.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3047.png', 1100, 770);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3050, 'Konwergencja Zeke''a', '<mainText><stats><attention>250 pkt.</attention> zdrowia<br><attention>35 pkt.</attention> pancerza<br><attention>250 pkt.</attention> many<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><br><active>U??ycie ???</active> <active>Przewodnik:</active> Wyznacz <attention>Wsp??lnika</attention>.<br><li><passive>Konwergencja:</passive> Po <status>unieruchomieniu</status> wroga, ataki i umiej??tno??ci twojego <attention>Wsp??lnika</attention> zadaj?? temu wrogowi dodatkowe obra??enia.<br><br><rules>Bohater??w mo??e ????czy?? tylko jedna Konwergencja Zeke''a naraz.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3050.png', 2400, 1680);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3051, 'Ogniolubny Top??r', '<mainText><stats><attention>15 pkt.</attention> obra??e?? od ataku<br><attention>15%</attention> pr??dko??ci ataku</stats><br><li><passive>Zwinno????:</passive> Atakowanie jednostki zapewnia dodatkow?? pr??dko???? ruchu.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3051.png', 1000, 700);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3053, 'Grubosk??rno???? Steraka', '<mainText><stats><attention>400 pkt.</attention> zdrowia</stats><br><li><passive>Pazury do Chwytania:</passive> Zyskujesz premi?? r??wn?? swoim podstawowym obra??eniom od ataku jako dodatkowe obra??enia od ataku.<li><passive>Linia ??ycia:</passive> Przy otrzymaniu obra??e??, kt??re zmniejszy??yby twoje zdrowie do poziomu ni??szego ni?? 30%, zyskujesz tarcz??, kt??ra stopniowo zanika.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3053.png', 3100, 2170);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3057, 'Blask', '<mainText><stats></stats><li><passive>Czaroostrze:</passive> Tw??j nast??pny atak po u??yciu umiej??tno??ci jest wzmocniony i zadaje dodatkowe obra??enia.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3057.png', 700, 490);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3065, 'Oblicze Ducha', '<mainText><stats><attention>450 pkt.</attention> zdrowia<br><attention>50 pkt.</attention> odporno??ci na magi??<br><attention>10</attention> jedn. przyspieszenia umiej??tno??ci<br><attention>100%</attention> podstawowej regeneracji zdrowia</stats><br><li><passive>Nieograniczona ??ywotno????:</passive> Wzmacnia skuteczno???? otrzymywanego leczenia i tarcz.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3065.png', 2900, 2030);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3066, 'Skrzydlaty Ksi????ycowy Pancerz', '<mainText><stats><attention>150 pkt.</attention> zdrowia</stats><br><li><passive>Lot:</passive> Zapewnia <speed>5% pr??dko??ci ruchu</speed>.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3066.png', 800, 560);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3067, 'Rozgrzany Klejnot', '<mainText><stats><attention>200 pkt.</attention> zdrowia<br><attention>10</attention> jedn. przyspieszenia umiej??tno??ci</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3067.png', 800, 560);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3068, 'S??oneczna Egida', '<mainText><stats><attention>500 pkt.</attention> zdrowia<br><attention>50 pkt.</attention> pancerza</stats><br><li><passive>Po??oga:</passive> Zadanie lub otrzymanie obra??e?? sprawia, ??e zadajesz pobliskim wrogom <magicDamage> (15 + 1.75% dodatkowego zdrowia) pkt. obra??e?? magicznych</magicDamage> na sekund?? (zwi??kszonych o 25% przeciwko stworom) przez 3 sek. Zadawanie obra??e?? bohaterom lub pot????nym potworom za pomoc?? tego efektu zapewnia ??adunek zwi??kszaj??cy dalsze obra??enia <passive>Po??ogi</passive> o 10% na 5 sek. (maks. liczba ??adunk??w: 6).<br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3068.png', 2700, 1890);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3070, '??za Bogini', '<mainText><stats><attention>240 pkt.</attention> many</stats><br><li><passive>Skupienie:</passive> Ataki zadaj?? dodatkowe obra??enia fizyczne stworom.<li><passive>Do??adowanie Many:</passive> Traf cel umiej??tno??ci??, by poch??on???? do??adowanie i zyska?? <scaleMana>3 pkt. dodatkowej many</scaleMana>, podwojone, gdy cel jest bohaterem. Zapewnia maks. 360 pkt. many.<br><br><rules>Zyskujesz nowe <passive>Do??adowanie Many</passive> co 8 sek. (maks. 4).</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3070.png', 400, 280);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3071, 'Czarny Tasak', '<mainText><stats><attention>45 pkt.</attention> obra??e?? od ataku<br><attention>350 pkt.</attention> zdrowia<br><attention>30</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Dr????enie:</passive> Zadanie obra??e?? fizycznych bohaterowi nak??ada ??adunek redukcji pancerza.<li><passive>Sza??:</passive> Zadawanie obra??e?? fizycznych bohaterom zapewnia pr??dko???? ruchu za ka??dy na??o??ony na nich ??adunek <unique>Dr????enia</unique>.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3071.png', 3100, 2170);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3072, 'Krwiopijec', '<mainText><stats><attention>55 pkt.</attention> obra??e?? od ataku<br><attention>20%</attention> szansy na trafienie krytyczne<br><attention>18%</attention> kradzie??y ??ycia</stats><br><li><passive>Tarcza Boskiej Krwi:</passive> Kradzie?? ??ycia z atak??w mo??e przeleczy?? ci?? ponad maksymalny poziom zdrowia. Nadwy??ka zdrowia tworzy tarcz??, kt??ra zacznie si?? zmniejsza??, je??eli nie zadasz lub nie otrzymasz obra??e??.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3072.png', 3400, 2380);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3074, 'Krwio??ercza Hydra', '<mainText><stats><attention>65 pkt.</attention> obra??e?? od ataku<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci<br><attention>10%</attention> wszechwampiryzmu</stats><br><li><passive>Rozp??atanie:</passive> Ataki i umiej??tno??ci zadaj?? obra??enia fizyczne pozosta??ym pobliskim wrogom.<br><li><passive>Mi??so??erno????:</passive> Zyskujesz obra??enia od ataku za ka??de zab??jstwo stwora. Warto???? ta zostaje zwi??kszona 2 razy za zabicie bohatera, du??ego potwora lub stwora obl????niczego. ??mier?? powoduje utrat?? 60% ??adunk??w.<br><br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3074.png', 3400, 2380);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3075, 'Kolczasta Kolczuga', '<mainText><stats><attention>350 pkt.</attention> zdrowia<br><attention>60 pkt.</attention> pancerza</stats><br><li><passive>Kolce:</passive> Gdy jeste?? celem ataku, zadajesz obra??enia atakuj??cemu i nak??adasz na niego <status>G????bokie Rany</status> o warto??ci 25%, je??eli jest bohaterem. Unieruchomienie wrogich bohater??w nak??ada r??wnie?? <status>G????bokie Rany</status> o warto??ci 40%.<br><br><rules><status>G????bokie Rany</status> os??abiaj?? efektywno???? leczenia i regeneracji.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3075.png', 2700, 1890);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3076, 'Kamizelka Cierniowa', '<mainText><stats><attention>30 pkt.</attention> pancerza</stats><br><li><passive>Kolce:</passive> Gdy jeste?? celem ataku, zadajesz obra??enia atakuj??cemu i nak??adasz na niego G????bokie Rany o warto??ci 25%, je??eli jest bohaterem.<br><br><rules><status>G????bokie Rany</status> os??abiaj?? efektywno???? leczenia i regeneracji.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3076.png', 800, 560);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3077, 'Tiamat', '<mainText><stats><attention>25 pkt.</attention> obra??e?? od ataku</stats><br><li><passive>Rozp??atanie:</passive> Ataki zadaj?? obra??enia fizyczne innym pobliskim wrogom. <br><br>Rozp??atanie nie aktywuje si?? na budowlach.<br><br>Efektywno???? tego przedmiotu jest r????na w przypadku bohater??w walcz??cych w zwarciu i z dystansu.<br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3077.png', 1200, 840);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3078, 'Moc Tr??jcy', '<mainText><stats><attention>35 pkt.</attention> obra??e?? od ataku<br><attention>30%</attention> pr??dko??ci ataku<br><attention>300 pkt.</attention> zdrowia<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Potr??jne Uderzenie:</passive> Ataki zapewniaj?? pr??dko???? ruchu. Je??li cel jest bohaterem, zwi??kszasz swoje podstawowe obra??enia od ataku. Ten efekt kumuluje si??.<li><passive>Czaroostrze:</passive> Po u??yciu umiej??tno??ci nast??pny atak podstawowy jest wzmocniony i zadaje dodatkowe obra??enia.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Obra??enia od ataku, przyspieszenie umiej??tno??ci i pr??dko???? ruchu.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3078.png', 3333, 2333);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3082, 'Zbroja Stra??nika', '<mainText><stats><attention>40 pkt.</attention> pancerza</stats><br><li><passive>Twardy jak Ska??a:</passive> Zmniejsza obra??enia otrzymywane od atak??w.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3082.png', 1000, 700);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3083, 'Plemienna Zbroja', '<mainText><stats><attention>800 pkt.</attention> zdrowia<br><attention>10</attention> jedn. przyspieszenia umiej??tno??ci<br><attention>200%</attention> podstawowej regeneracji zdrowia</stats><br><li><passive>Serce Plemienia:</passive> Gdy masz co najmniej 1100 pkt. dodatkowego zdrowia, przywracasz sobie maksymalne zdrowie na sekund??, je??li tw??j bohater nie otrzyma?? obra??e?? przez ostatnie 6 sek.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3083.png', 3000, 2100);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3084, 'Stalowe Serce', '<mainText><stats><attention>800 pkt.</attention> zdrowia<br><attention>200%</attention> podstawowej regeneracji zdrowia<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Kolosalna Konsumpcja:</passive> Przygotuj pot????ny atak przeciwko bohaterowi przez 3 sek., znajduj??c si?? w promieniu 700 jedn. od niego. Na??adowany atak zadaje dodatkowe obra??enia fizyczne r??wne 125 pkt. + <scalehealth>6%</scalehealth> twojego maks. zdrowia i zapewnia ci 10% tej warto??ci w formie trwa??ego maks. zdrowia. (30 sek.) czasu odnowienia na cel.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom <attention>??1%</attention> wi??cej zdrowia i <attention>6%</attention> rozmiaru bohatera.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3084.png', 3200, 2240);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3085, 'Huragan Runaana', '<mainText><stats><attention>45%</attention> pr??dko??ci ataku<br><attention>20%</attention> szansy na trafienie krytyczne<br><attention>7%</attention> pr??dko??ci ruchu</stats><br><li><passive>Furia Wiatru:</passive> Gdy atakujesz, wystrzeliwujesz pociski w kierunku maks. 2 wrog??w w pobli??u celu. Pociski nak??adaj?? efekty przy trafieniu i mog?? trafi?? krytycznie.<br><br><rules>Przedmiot wy????cznie dla bohater??w walcz??cych z dystansu.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3085.png', 2600, 1820);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3086, 'Zapa??', '<mainText><stats><attention>18%</attention> pr??dko??ci ataku<br><attention>15%</attention> szansy na trafienie krytyczne</stats><br><li><passive>Gorliwo????:</passive> Zyskujesz <speed>7% pr??dko??ci ruchu</speed>.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3086.png', 1050, 735);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3089, 'Zab??jczy Kapelusz Rabadona', '<mainText><stats><attention>120 pkt.</attention> mocy umiej??tno??ci</stats><br><li><passive>Magiczne Dzie??o:</passive> Zwi??ksz swoj?? ca??kowit?? <scaleAP>moc umiej??tno??ci o 35%</scaleAP>.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3089.png', 3600, 2520);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3091, 'Koniec Rozumu', '<mainText><stats><attention>40 pkt.</attention> obra??e?? od ataku<br><attention>40%</attention> pr??dko??ci ataku<br><attention>40 pkt.</attention> odporno??ci na magi??</stats><br><li><passive>Bitwa:</passive> Ataki zadaj?? obra??enia magiczne przy trafieniu i zapewniaj?? pr??dko???? ruchu.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3091.png', 3100, 2170);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3094, 'Ognista Armata', '<mainText><stats><attention>35%</attention> pr??dko??ci ataku<br><attention>20%</attention> szansy na trafienie krytyczne<br><attention>7%</attention> pr??dko??ci ruchu</stats><br><li><passive>Na??adowanie:</passive> Poruszanie si?? i trafianie atakami generuje Na??adowany atak.<li><passive>Strzelec Wyborowy:</passive> Twoje na??adowane ataki zadaj?? dodatkowe obra??enia. Ponadto zasi??g twoich na??adowanych atak??w zostaje zwi??kszony.<br><br><rules>Zasi??g ataku mo??e zosta?? zwi??kszony o maks. 150 jedn.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3094.png', 2500, 1750);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3095, 'Klinga Burzy', '<mainText><stats><attention>45 pkt.</attention> obra??e?? od ataku<br><attention>15%</attention> pr??dko??ci ataku<br><attention>20%</attention> szansy na trafienie krytyczne</stats><br><li><passive>Na??adowanie:</passive> Poruszanie si?? i trafianie atakami generuje Na??adowany atak.<li><passive>Parali??:</passive> Twoje na??adowane ataki zadaj?? dodatkowe obra??enia magiczne. Ponadto na??adowane ataki spowalniaj?? wrog??w.<br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3095.png', 2700, 1890);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3100, 'Zmora Licza', '<mainText><stats><attention>75 pkt.</attention> mocy umiej??tno??ci<br><attention>15</attention> jedn. przyspieszenia umiej??tno??ci<br><attention>8%</attention> pr??dko??ci ruchu</stats><br><li><passive>Czaroostrze:</passive> Tw??j nast??pny atak po u??yciu umiej??tno??ci jest wzmocniony i zadaje dodatkowe obra??enia magiczne.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3100.png', 3000, 2100);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3102, 'Ca??un Banshee', '<mainText><stats><attention>80 pkt.</attention> mocy umiej??tno??ci<br><attention>45 pkt.</attention> odporno??ci na magi??<br><attention>10</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Uchylenie:</passive> Zapewnia tarcz?? magii, kt??ra blokuje kolejn?? umiej??tno???? wroga.<br><br><rules>Otrzymanie obra??e?? od bohater??w resetuje czas odnowienia tego przedmiotu.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3102.png', 2600, 1820);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3105, 'Egida Legionu', '<mainText><stats><attention>30 pkt.</attention> pancerza<br><attention>30 pkt.</attention> odporno??ci na magi??<br><attention>10</attention> jedn. przyspieszenia umiej??tno??ci</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3105.png', 1200, 840);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3107, 'Odkupienie', '<mainText><stats><attention>16%</attention> si??y leczenia i tarcz<br><attention>200 pkt.</attention> zdrowia<br><attention>15</attention> jedn. przyspieszenia umiej??tno??ci<br><attention>100%</attention> podstawowej regeneracji many</stats><br><br><active>U??ycie ???</active> <active>Interwencja:</active> Wybierz obszar wewn??trz. Po 2,5 sek. uderzy promie?? ??wiat??a, kt??ry przywr??ci sojusznikom zdrowie i zada obra??enia wrogim bohaterom.<br><br><rules>Przedmiot mo??e zosta?? u??yty po ??mierci. Obra??enia i leczenie s?? zmniejszone o 50%, je??li cel zosta?? niedawno obj??ty dzia??aniem innej <active>Interwencji</active>. Warto???? efekt??w zwi??kszaj??cych si?? z poziomem jest zale??na od poziomu sojusznika.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3107.png', 2300, 1610);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3108, 'Czarci Kodeks', '<mainText><stats><attention>35 pkt.</attention> mocy umiej??tno??ci<br><attention>10</attention> jedn. przyspieszenia umiej??tno??ci</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3108.png', 900, 630);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3109, 'Przysi??ga Rycerska', '<mainText><stats><attention>400 pkt.</attention> zdrowia<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci<br><attention>200%</attention> podstawowej regeneracji zdrowia</stats><br><br><active>U??ycie ???</active> <active>??lubowanie:</active> Wyznacz sojusznika, kt??ry jest <attention>Godzien</attention>.<br><li><passive>Po??wi??cenie:</passive> Gdy w pobli??u znajduje si?? tw??j <attention>Godzien</attention> sojusznik, przekierowujesz otrzymywane przez niego obra??enia na siebie i leczysz si?? o warto???? zale??n?? od obra??e?? zadawanych przez <attention>Godnego</attention> sojusznika bohaterom.<br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3109.png', 2300, 1610);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3110, 'Mro??ne Serce', '<mainText><stats><attention>90 pkt.</attention> pancerza<br><attention>400 pkt.</attention> many<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Pieszczoty Zimy:</passive> Zmniejsza <attackSpeed>pr??dko???? ataku</attackSpeed> pobliskich wrog??w.<li><passive>Twardy jak Ska??a:</passive> Zmniejsza obra??enia otrzymywane od atak??w.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3110.png', 2700, 1890);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3111, 'Obuwie Merkurego', '<mainText><stats><attention>25 pkt.</attention> odporno??ci na magi??<br><attention>45</attention> jedn. pr??dko??ci ruchu<br><attention>30%</attention> nieust??pliwo??ci</stats><br><br><rules>Nieust??pliwo???? skraca czas dzia??ania efekt??w <status>og??uszenia</status>, <status>spowolnienia</status>, <status>prowokacji</status>, <status>przestraszenia</status>, <status>uciszenia</status>, <status>o??lepienia</status>, <status>polimorfii</status> i <status>unieruchomienia</status>. Nie wp??ywa na efekty <status>wyrzucenia w powietrze</status> i <status>przygwo??d??enia</status>.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3111.png', 1100, 770);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3112, 'Kula Stra??nika', '<mainText><stats><attention>50 pkt.</attention> mocy umiej??tno??ci<br><attention>150 pkt.</attention> zdrowia</stats><br><li><passive>Regeneracja:</passive> Przywraca man?? z up??ywem czasu. Je??li nie mo??esz zyska?? many, przywraca zdrowie.<li><passive>Legendarny:</passive> Ten przedmiot zalicza si?? jako <rarityLegendary>legendarny</rarityLegendary>.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3112.png', 950, 665);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3113, 'Eteryczny Duszek', '<mainText><stats><attention>30 pkt.</attention> mocy umiej??tno??ci</stats><br><li><passive>Szybowanie:</passive> Zyskujesz <speed>5% pr??dko??ci ruchu</speed>.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3113.png', 850, 595);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3114, 'Blu??nierczy Bo??ek', '<mainText><stats><attention>50%</attention> podstawowej regeneracji many<br><attention>8%</attention> si??y leczenia i tarcz</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3114.png', 800, 560);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3115, 'Z??b Nashora', '<mainText><stats><attention>100 pkt.</attention> mocy umiej??tno??ci<br><attention>50%</attention> pr??dko??ci ataku</stats><br><li><passive>Icathia??skie Uk??szenie:</passive> Ataki zadaj?? obra??enia magiczne <OnHit>przy trafieniu</OnHit>.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3115.png', 3000, 2100);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3116, 'Kryszta??owy Kostur Rylai', '<mainText><stats><attention>75 pkt.</attention> mocy umiej??tno??ci<br><attention>400 pkt.</attention> zdrowia</stats><br><li><passive>Zmarzlina:</passive> Umiej??tno??ci zadaj??ce obra??enia <status>spowalniaj??</status> wrog??w.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3116.png', 2600, 1820);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3117, 'Buty Mobilno??ci', '<mainText><stats></stats><attention>25 jedn.</attention> pr??dko??ci ruchu <li>Gdy przebywasz poza walk?? przez co najmniej 5 sek., efekt tego przedmiotu zwi??ksza si?? do <attention>115 jedn.</attention></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3117.png', 1000, 700);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3119, 'Nadej??cie Zimy', '<mainText><stats><attention>400 pkt.</attention> zdrowia<br><attention>500 pkt.</attention> many<br><attention>15</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Podziw:</passive> Zyskujesz dodatkowe <scaleHealth>zdrowie r??wne ca??kowitej manie</scaleHealth>.<li><passive>Do??adowanie Many:</passive> Traf cel umiej??tno??ci?? lub atakiem, by zu??y?? ??adunek i zyska?? <scaleMana>3 pkt. dodatkowej many</scaleMana>. Efekt jest podwojony, je??li cel jest bohaterem. Zapewnia maks. 360 pkt. many, po czym przemienia si?? w <rarityLegendary>Wielk?? Zim??</rarityLegendary>.<br><br><rules>Zyskujesz nowe <passive>Do??adowanie Many</passive> co 8 sek. (maks. 4 ??adunk??w).</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3119.png', 2600, 1820);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3121, 'Wielka Zima', '<mainText><stats><attention>350 pkt.</attention> zdrowia<br><attention>860 pkt.</attention> many<br><attention>15</attention> jedn. przyspieszenia umiej??tno??ci</stats><li><passive>Podziw:</passive> Zyskujesz dodatkowe zdrowie w zale??no??ci od many.<li><passive>Nieprzemijalno????:</passive> <status>Unieruchomienie</status> lub <status>spowolnienie</status> wrogiego bohatera zu??ywa aktualn?? man?? i zapewnia tarcz??. Tarcza zostaje wzmocniona, je??li w pobli??u znajduje si?? wi??cej ni?? jeden wr??g.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3121.png', 2700, 1890);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3123, 'Wezwanie Kata', '<mainText><stats><attention>20 pkt.</attention> obra??e?? od ataku</stats><br><li><passive>Rozerwanie:</passive> Zadawanie bohaterom obra??e?? fizycznych nak??ada na nich <status>G????bokie Rany o warto??ci 25%</status> na 3 sek.<br><br><rules><status>G????bokie Rany</status> os??abiaj?? efektywno???? leczenia i regeneracji.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3123.png', 800, 560);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3124, 'Ostrze Gniewu Guinsoo', '<mainText><stats><attention>45%</attention> pr??dko??ci ataku<br><attention>20%</attention> szansy na trafienie krytyczne</stats><br><li><passive>Gniew:</passive> Twoja szansa na trafienie krytyczne jest zmieniana w obra??enia <OnHit>przy trafieniu</OnHit>. Zyskujesz <physicalDamage>40 pkt.</physicalDamage> obra??e?? fizycznych <OnHit>przy trafieniu</OnHit> za ka??de zmienione 20% szans na trafienie krytyczne.<li><passive>Wrz??ce Uderzenie:</passive> Ka??dy co trzeci atak dwukrotnie nak??ada efekty przy trafieniu.<br><br><rules><passive>Gniew</passive> nie mo??e korzysta?? z wi??cej ni?? 100% szans na trafienie krytyczne. Mno??niki obra??e?? trafienia krytycznego maj?? wp??yw na konwersj?? obra??e?? przy trafieniu <passive>Gniewu</passive>.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3124.png', 2600, 1820);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3133, 'M??ot Bojowy Caulfielda', '<mainText><stats><attention>25 pkt.</attention> obra??e?? od ataku<br><attention>10</attention> jedn. przyspieszenia umiej??tno??ci</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3133.png', 1100, 770);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3134, 'Z??bkowany Sztylet', '<mainText><stats><attention>30 pkt.</attention> obra??e?? od ataku</stats><br><li><passive>D??uto:</passive> Zyskujesz <scaleLethality>10 pkt. destrukcji</scaleLethality>.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3134.png', 1100, 770);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3135, 'Kostur Pustki', '<mainText><stats><attention>65 pkt.</attention> mocy umiej??tno??ci<br><attention>40%</attention> przebicia odporno??ci na magi??</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3135.png', 2800, 1960);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3139, 'Rt??ciowy Bu??at', '<mainText><stats><attention>40 pkt.</attention> obra??e?? od ataku<br><attention>20%</attention> szansy na trafienie krytyczne<br><attention>40 pkt.</attention> odporno??ci na magi??</stats><br><br><active>U??ycie ???</active> <active>??ywe Srebro:</active> Usuwa wszystkie efekty kontroli t??umu i zapewnia dodatkow?? pr??dko???? ruchu.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3139.png', 3000, 2100);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3140, 'Rt??ciowa Szarfa', '<mainText><stats><attention>30 pkt.</attention> odporno??ci na magi??</stats><br><br><active>U??ycie ???</active> <active>??ywe Srebro:</active> Usuwa wszystkie efekty kontroli t??umu (z wyj??tkiem <status>wyrzucenia w powietrze</status>).<br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3140.png', 1300, 910);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3142, 'Widmowe Ostrze Youmuu', '<mainText><stats><attention>55 pkt.</attention> obra??e?? od ataku<br><attention>18 pkt.</attention> destrukcji<br><attention>15</attention> jedn. przyspieszenia umiej??tno??ci</stats><br> <br><active>U??ycie ???</active><active>Upiorny Krok:</active> Zyskujesz pr??dko???? ruchu i przenikanie.<br><li><passive>Nawiedzenie:</passive> Zyskujesz dodatkow?? pr??dko???? ruchu poza walk??.<br><br><rules><status>Przenikanie</status> pozwala na unikanie zderzania si?? z innymi jednostkami.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3142.png', 3000, 2100);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3143, 'Omen Randuina', '<mainText><stats><attention>400 pkt.</attention> zdrowia<br><attention>60 pkt.</attention> pancerza</stats><br><br><active>U??ycie ???</active> <active>Pokora:</active> <status>Spowalnia</status> pobliskich wrog??w.<br><li><passive>Twardy jak Ska??a</passive>: Zmniejsza obra??enia zadawane przez ataki.<li><passive>Krytyczna Wytrzyma??o????</passive>: Trafienia krytyczne zadaj?? o 20% mniej obra??e?? posiadaczowi przedmiotu.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3143.png', 3000, 2100);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3145, 'Alternator Hextech', '<mainText><stats><attention>25 pkt.</attention> mocy umiej??tno??ci<br><attention>150 pkt.</attention> zdrowia</stats><br><li><passive>Wysokie Obroty:</passive> Trafienie wroga zadaje dodatkowe obra??enia.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3145.png', 1050, 735);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3152, 'Hextechowy Pas Rakietowy', '<mainText><stats><attention>90 pkt.</attention> mocy umiej??tno??ci<br><attention>6 pkt.</attention> przebicia odporno??ci na magi??<br><attention>250 pkt.</attention> zdrowia<br><attention>15</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><br><active>U??ycie ???</active><active>Ponadd??wi??kowo????:</active> Doskakujesz w wybranym kierunku, wystrzeliwuj??c ??uk magicznych pocisk??w, kt??re zadaj?? obra??enia. Nast??pnie, gdy poruszasz si?? w kierunku wrogiego bohatera, zyskujesz dodatkow?? pr??dko???? ruchu.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Przebicie odporno??ci na magi??.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3152.png', 3200, 2240);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3153, 'Ostrze Zniszczonego Kr??la', '<mainText><stats><attention>40 pkt.</attention> obra??e?? od ataku<br><attention>25%</attention> pr??dko??ci ataku<br><attention>8%</attention> kradzie??y ??ycia</stats><br><li><passive>Ostrze Mg??y:</passive> Ataki zadaj?? dodatkowe obra??enia fizyczne na podstawie aktualnego zdrowia celu. <li><passive>Syfon:</passive> Trzykrotne zaatakowanie wrogiego bohatera zadaje obra??enia magiczne i wykrada pr??dko???? ruchu.<br><br>Efektywno???? tego przedmiotu jest r????na w przypadku bohater??w walcz??cych w zwarciu i z dystansu.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3153.png', 3300, 2310);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3155, 'Poch??aniacz Urok??w', '<mainText><stats><attention>25 pkt.</attention> obra??e?? od ataku<br><attention>35 pkt.</attention> odporno??ci na magi??</stats><br><li><passive>Linia ??ycia:</passive> Przy otrzymaniu obra??e?? magicznych, kt??re zmniejszy??yby twoje zdrowie do poziomu ni??szego ni?? 30%, zyskujesz tarcz?? poch??aniaj??c?? obra??enia magiczne.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3155.png', 1300, 910);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3156, 'Paszcza Malmortiusa', '<mainText><stats><attention>55 pkt.</attention> obra??e?? od ataku<br><attention>50 pkt.</attention> odporno??ci na magi??<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Linia ??ycia:</passive> Przy otrzymaniu obra??e?? magicznych, kt??re zmniejszy??yby twoje zdrowie do poziomu ni??szego ni?? 30%, zyskujesz tarcz?? poch??aniaj??c?? obra??enia magiczne. Gdy aktywuje si?? <passive>Linia ??ycia</passive>, zyskujesz wszechwampiryzm do ko??ca walki.  </mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3156.png', 2900, 2030);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3157, 'Klepsydra Zhonyi', '<mainText><stats><attention>80 pkt.</attention> mocy umiej??tno??ci<br><attention>45 pkt.</attention> pancerza<br><attention>15</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><br><active>U??ycie ???</active> <active>Inercja:</active> Zyskujesz <status>niewra??liwo????</status> i <status>nie mo??na obra?? ci?? na cel</status> przez 2.5 sek. Podczas trwania tego efektu nie mo??esz wykonywa?? ??adnych innych czynno??ci.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3157.png', 3000, 2100);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3158, 'Ionia??skie Buty Jasno??ci Umys??u', '<mainText><stats><attention>20</attention> jedn. przyspieszenia umiej??tno??ci<br><attention>45</attention> jedn. pr??dko??ci ruchu</stats><br><li>Zyskujesz 12 jedn. przyspieszenia czar??w przywo??ywacza.<br><br><flavorText>???Przedmiot ten stworzono na cze???? zwyci??stwa Ionii nad Noxusem w starciu rewan??owym o prowincje po??udniowe, 10 grudnia 20 CLE???.</flavorText></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3158.png', 950, 665);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3161, 'W????cznia Shojin', '<mainText><stats><attention>65 pkt.</attention> obra??e?? od ataku<br><attention>300 pkt.</attention> zdrowia<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Si??a Smoka:</passive> Wszystkie twoje umiej??tno??ci poza superumiej??tno??ci?? zyskuj?? (8 (+0.08 za ka??de 100 pkt. obra??e?? od ataku) | ??6 (+0.06 za ka??de 100 pkt. obra??e?? od ataku)) jedn. przyspieszenia umiej??tno??ci, zmniejszonej do (??4 (+0.04 za ka??de 100 pkt. obra??e?? od ataku) | ??3 (+0.03 za ka??de 100 pkt. obra??e?? od ataku)) jedn. przyspieszenia umiej??tno??ci dla zakl???? unieruchamiaj??cych.<li><passive>Pal??ca Konieczno????:</passive> Zyskujesz do (0.15 | 0.1) jedn. pr??dko??ci ruchu, w zale??no??ci od brakuj??cego zdrowia (maksymalna warto????, gdy zdrowie spadnie poni??ej 33%).<br><br>Efektywno???? tego przedmiotu jest r????na w przypadku bohater??w walcz??cych w zwarciu i z dystansu.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3161.png', 3400, 2380);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3165, 'Morellonomicon', '<mainText><stats><attention>90 pkt.</attention> mocy umiej??tno??ci<br><attention>300 pkt.</attention> zdrowia</stats><br><li><passive>Choroba:</passive> Zadawanie wrogim bohaterom obra??e?? magicznych nak??ada na nich <status>G????bokie Rany o warto??ci 25%</status> na 3 sek. Je??li cel ma mniej ni?? 50% zdrowia, <status>warto???? G????bokich Ran zwi??ksza si?? do 40%</status>.<br><br><rules><status>G????bokie Rany</status> os??abiaj?? efektywno???? leczenia i regeneracji.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3165.png', 2500, 1750);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3177, 'Ostrze Stra??nika', '<mainText><stats><attention>30 pkt.</attention> obra??e?? od ataku<br><attention>150 pkt.</attention> zdrowia<br><attention>15</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Legendarny:</passive> Ten przedmiot zalicza si?? jako <rarityLegendary>legendarny</rarityLegendary>.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3177.png', 950, 665);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3179, 'Glewia Umbry', '<mainText><stats><attention>50 pkt.</attention> obra??e?? od ataku<br><attention>10 pkt.</attention> destrukcji<br><attention>15</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Zaciemnienie:</passive> Je??li ujawni ci?? wrogi totem, odkrywasz pu??apki i wy????czasz totemy wok???? siebie. Twoje ataki natychmiast niszcz?? odkryte pu??apki i zadaj?? potr??jne obra??enia totemom.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3179.png', 2300, 1610);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3181, 'Kad??ubo??amacz', '<mainText><stats><attention>50 pkt.</attention> obra??e?? od ataku<br><attention>400 pkt.</attention> zdrowia<br><attention>150%</attention> podstawowej regeneracji zdrowia</stats><br><br><li><passive>Za??oga Aborda??owa:</passive> Je??li w pobli??u nie ma sojuszniczych bohater??w, otrzymujesz <scaleArmor>pancerz</scaleArmor> oraz <scaleMR>odporno???? na magi??</scaleMR>, a ataki zadaj?? wi??ksze obra??enia wie??om. Du??e stwory znajduj??ce si?? w pobli??u zyskuj?? <scaleArmor>pancerz</scaleArmor> oraz <scaleMR>odporno???? na magi??</scaleMR> i zadaj?? wi??ksze obra??enia wie??om. <br><br><rules>Pancerz i odporno???? na magi?? otrzymywane z Za??ogi Aborda??owej zanikaj?? w ci??gu 3 sekund, je??li sojusznik podejdzie zbyt blisko.</rules><br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3181.png', 2800, 1960);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3184, 'M??ot Stra??nika', '<mainText><stats><attention>25 pkt.</attention> obra??e?? od ataku<br><attention>150 pkt.</attention> zdrowia<br><attention>7%</attention> kradzie??y ??ycia</stats><br><li><passive>Legendarny:</passive> Ten przedmiot zalicza si?? jako <rarityLegendary>legendarny</rarityLegendary>.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3184.png', 950, 665);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3190, 'Naszyjnik ??elaznych Solari', '<mainText><stats><attention>200 pkt.</attention> zdrowia<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci<br><attention>30 pkt.</attention> pancerza<br><attention>30 pkt.</attention> odporno??ci na magi??</stats><br> <br><active>U??ycie ???</active><active>Oddanie:</active> Zapewniasz pobliskim sojusznikom <shield>tarcz??</shield>, kt??ra z czasem zanika.<br><li><passive>Konsekracja:</passive> Zapewnia pobliskim sojuszniczym bohaterom pancerz i <scaleMR>odporno???? na magi??</scaleMR>. <br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Dodatkowy pancerz i odporno???? na magi?? do efektu <passive>Konsekracji</passive>.<br><br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3190.png', 2500, 1750);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3191, 'Naramiennik Poszukiwacza', '<mainText><stats><attention>30 pkt.</attention> mocy umiej??tno??ci<br><attention>15 pkt.</attention> pancerza</stats><br><li><passive>??cie??ka Wied??my:</passive> Zabicie jednostki zapewnia <scaleArmor>0.5 pkt. pancerza</scaleArmor> (maks. <scaleArmor>15 pkt.</scaleArmor>).</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3191.png', 1000, 700);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3193, 'Kamienna P??yta Gargulca', '<mainText><stats><attention>60 pkt.</attention> pancerza<br><attention>60 pkt.</attention> odporno??ci na magi??<br><attention>15</attention> jedn. przyspieszenia umiej??tno??ci</stats><br> <br><active>U??ycie ???</active><active>Niez??omno????:</active> Zyskujesz zanikaj??c?? tarcz?? i zwi??kszasz sw??j rozmiar.<br><li><passive>Umocnienie:</passive> Otrzymywanie obra??e?? od bohater??w zapewnia ??adunek <scaleArmor>dodatkowego pancerza</scaleArmor> i <scaleMR>odporno??ci na magi??</scaleMR>.<br><br><rules>Maks. 5 ??adunk??w, 1 ??adunek na bohatera.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3193.png', 3200, 2240);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3211, 'Widmowa Os??ona', '<mainText><stats><attention>250 pkt.</attention> zdrowia<br><attention>25 pkt.</attention> odporno??ci na magi??</stats><br><li><passive>Bezcielesno????:</passive> Regeneruje zdrowie po otrzymaniu obra??e?? od wrogiego bohatera.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3211.png', 1250, 875);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3222, 'B??ogos??awie??stwo Mikaela', '<mainText><stats><attention>16%</attention> si??y leczenia i tarcz<br><attention>50 pkt.</attention> odporno??ci na magi??<br><attention>15</attention> jedn. przyspieszenia umiej??tno??ci<br><attention>100%</attention> podstawowej regeneracji many</stats><br> <br><active>U??ycie ???</active><active>Oczyszczenie:</active> Regeneruje zdrowie i usuwa wszystkie efekty kontroli t??umu z sojuszniczego bohatera (poza <status>podrzuceniem</status> oraz <status>przygwo??d??eniem</status>).</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3222.png', 2300, 1610);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3330, 'Kuk??a Stracha na Wr??ble', '<mainText><stats></stats><br><active>U??ycie ??? Talizman:</active> Umieszcza kuk????, kt??ra dla wrog??w wygl??da dok??adnie jak Fiddlesticks. Gromadzi maks. 2 ??adunki.<br><br>Wrodzy bohaterowie, kt??rzy zbli???? si?? do Kuk??y, aktywuj?? j??, co sprawi, ??e uda ona wykonanie losowego dzia??ania, a nast??pnie si?? rozpadnie.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3330.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3340, 'Totem Ukrycia', '<mainText><stats></stats><active>U??ycie ??? Talizman:</active> Umieszczasz na ziemi <keywordStealth>niewidoczny</keywordStealth> dla wrog??w Totem Ukrycia, kt??ry zapewnia twojej dru??ynie wizj?? na pobliskim obszarze. Przechowuje do 2 Totem??w Ukrycia.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3340.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3363, 'Zmiana Dalekowidzenia', '<mainText><stats></stats><active>U??ycie ??? Talizman:</active> Odkrywa dany obszar oraz umieszcza widoczny, delikatny Totem w odleg??o??ci do 4000 jedn.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3363.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3364, 'Soczewka Wyroczni', '<mainText><stats></stats><active>U??ycie ??? Talizman:</active> Przeszukuje obszar dooko??a ciebie, ostrzegaj??c przed ukrytymi wrogimi jednostkami i ujawniaj??c niewidzialne pu??apki, a tak??e pobliskie wrogie Totemy Ukrycia (kt??re na kr??tki czas wy????cza).</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3364.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3400, 'Twoja Dzia??ka', '<mainText><stats></stats><active>U??ycie ??? Zu??yj:</active> Zyskujesz 0 szt. z??ota.<br><br><rules>Dodatkowe z??oto przyznawane sojusznikowi, kiedy Pyke wyko??czy wrogiego bohatera swoj?? superumiej??tno??ci??. Je??li ??aden sojusznik nie wzi???? udzia??u w zab??jstwie, Pyke zachowa dodatkow?? Dzia??k??!</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3400.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3504, 'Ognisty Trybularz', '<mainText><stats><attention>60 pkt.</attention> mocy umiej??tno??ci<br><attention>8%</attention> si??y leczenia i tarcz<br><attention>100%</attention> podstawowej regeneracji many</stats><br><li><passive>U??wi??cenie:</passive> Uleczenie lub os??oni??cie tarcz?? innego sojusznika wzmacnia zar??wno jego, jak i ciebie, zapewniaj??c wam dodatkow?? pr??dko???? ataku i obra??enia magiczne <OnHit>przy trafieniu</OnHit>. <br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3504.png', 2300, 1610);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3508, 'Z??odziej Esencji', '<mainText><stats><attention>45 pkt.</attention> obra??e?? od ataku<br><attention>20%</attention> szansy na trafienie krytyczne<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Czaroostrze:</passive> Po u??yciu umiej??tno??ci tw??j nast??pny atak zadaje dodatkowe obra??enia magiczne i regeneruje man??.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3508.png', 2800, 1960);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3513, 'Oko Herolda', '<mainText><stats></stats><active>U??ycie ??? Zu??yj:</active> Zniszcz Oko Herolda, by go przyzwa??. Herold zacznie si?? przemieszcza?? wzd??u?? najbli??szej alei, zadaj??c ogromne obra??enia wie??om, kt??re spotka na swojej drodze.<br><br><passive>Przeb??ysk Pustki:</passive> Zapewnia Wzmocnienie.<br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3513.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3599, 'Czarna W????cznia Kalisty', '<mainText><stats></stats><active>U??ycie ??? Zu??yj:</active> Nawi???? wi???? z sojusznikiem do ko??ca gry, by zosta?? Zaprzysi????onymi Sojusznikami. Przysi??ga wzmocni was, gdy znajdziecie si?? blisko siebie.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3599.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3600, 'Czarna W????cznia Kalisty', '<mainText><stats></stats><active>U??ycie ??? Zu??yj:</active> Nawi???? wi???? z sojusznikiem do ko??ca gry, by zosta?? Zaprzysi????onymi Sojusznikami. Przysi??ga wzmocni was, gdy znajdziecie si?? blisko siebie.<br><br><rules>Potrzebne do u??ycia superumiej??tno??ci <attention>Kalisty</attention>.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3600.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3742, 'Pancerz Umrzyka', '<mainText><stats><attention>300 pkt.</attention> zdrowia<br><attention>45 pkt.</attention> pancerza<br><attention>5%</attention> pr??dko??ci ruchu</stats><li><passive>Niszczyciel Statk??w:</passive> Poruszaj??c si??, zyskujesz dodatkow?? pr??dko???? ruchu. Tw??j nast??pny atak roz??aduje skumulowan?? pr??dko???? ruchu, by zada?? obra??enia. Je??li obra??enia zosta??y zadane przez bohatera walcz??cego w zwarciu przy maks. pr??dko??ci, ten atak dodatkowo <status>spowolni</status> cel.<br><br><flavorText>???Jest tylko jeden spos??b na odebranie mi tej zbroi?????? ??? Zapomniany imiennik</flavorText></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3742.png', 2900, 2030);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3748, 'Kolosalna Hydra', '<mainText><stats><attention>30 pkt.</attention> obra??e?? od ataku<br><attention>500 pkt.</attention> zdrowia</stats><br><li><passive>Kolos:</passive> Zyskujesz <scaleAD>dodatkowe obra??enia od ataku zale??ne od dodatkowego zdrowia</scaleAD>.<li><passive>Rozp??atanie:</passive> Ataki zadaj?? dodatkowe obra??enia <OnHit>przy trafieniu</OnHit>, tworz??c fal?? uderzeniow??, kt??ra zadaje obra??enia wrogom znajduj??cym si?? za celem.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3748.png', 3300, 2310);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3801, 'Kryszta??owy Karwasz', '<mainText><stats><attention>200 pkt.</attention> zdrowia<br><attention>100%</attention> podstawowej regeneracji zdrowia</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3801.png', 800, 560);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3802, 'Zaginiony Rozdzia??', '<mainText><stats><attention>40 pkt.</attention> mocy umiej??tno??ci<br><attention>300 pkt.</attention> many<br><attention>10</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>O??wiecenie:</passive> Ilekro?? zdobywasz poziom, odzyskujesz <scaleMana>20% maks. many</scaleMana> w ci??gu 3 sek.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3802.png', 1300, 910);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3803, 'Katalizator Eon??w', '<mainText><stats><attention>225 pkt.</attention> zdrowia<br><attention>300 pkt.</attention> many</stats><br><li><passive>Wieczno????:</passive> Przywraca man?? r??wn?? warto??ci 7% czystych obra??e?? otrzymanych od bohater??w oraz zdrowie r??wne 25% zu??ytej many, maks. 20 pkt. zdrowia na u??ycie, na sekund??.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3803.png', 1100, 770);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3814, 'Ostrze Nocy', '<mainText><stats><attention>50 pkt.</attention> obra??e?? od ataku<br><attention>10 pkt.</attention> destrukcji<br><attention>325 pkt.</attention> zdrowia</stats><br><li><passive>Uchylenie:</passive> Zyskujesz tarcz?? magii, kt??ra blokuje nast??pn?? umiej??tno???? wroga.<br><br><rules>Otrzymanie obra??e?? resetuje czas odnowienia tego przedmiotu.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3814.png', 2900, 2030);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3850, 'Ostrze Z??odziejki Czar??w', '<mainText><stats><attention>8 pkt.</attention> mocy umiej??tno??ci<br><attention>10 pkt.</attention> zdrowia<br><attention>50%</attention> podstawowej regeneracji many<br><attention>2 szt.</attention> z??ota co 10 sek.</stats><br><li><passive>Danina:</passive> Gdy znajdujesz si?? w pobli??u sojuszniczego bohatera, umiej??tno??ci zadaj??ce obra??enia i ataki u??yte przeciwko wrogom lub budowlom zapewniaj?? 20 szt. z??ota. Efekt mo??e wyst??pi?? do 3 razy w ci??gu 30 sek.<li><passive>Zadanie:</passive> Zdob??d?? 500 szt. z??ota przy u??yciu tego przedmiotu, by przemieni?? go w <rarityGeneric>Lodowy Kie??</rarityGeneric> i zyska?? <active>U??ycie ???</active> <active>Umieszczanie Totem??w</active>.<br><br><rules>Ten przedmiot zapewnia zmniejszon?? ilo???? z??ota ze stwor??w, je??li zabijesz ich zbyt wiele.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3850.png', 400, 160);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3851, 'Lodowy Kie??', '<mainText><stats><attention>15 pkt.</attention> mocy umiej??tno??ci<br><attention>70 pkt.</attention> zdrowia<br><attention>75%</attention> podstawowej regeneracji many<br><attention>3 szt.</attention> z??ota co 10 sek.</stats><br><br><active>U??ycie ???</active> <active>Umieszczanie Totem??w:</active> Umieszczasz na ziemi <keywordStealth>niewidoczny</keywordStealth> dla wrog??w Totem Ukrycia, kt??ry zapewnia twojej dru??ynie wizj?? na pobliskim obszarze. Przechowuje do 0 Totem??w Ukrycia, kt??re odnawiaj?? si??, ilekro?? odwiedzisz sklep. <br><br><active>U??ycie ???</active> <active>Umieszczanie Totem??w:</active> Umieszczasz na ziemi <keywordStealth>niewidoczny</keywordStealth> dla wrog??w Totem Ukrycia, kt??ry zapewnia twojej dru??ynie wizj?? na pobliskim obszarze. Przechowuje do 3 Totem??w Ukrycia, kt??re odnawiaj?? si??, ilekro?? odwiedzasz sklep. <br><br><br><br><li><passive>Danina:</passive> Gdy znajdujesz si?? w pobli??u sojuszniczego bohatera, umiej??tno??ci zadaj??ce obra??enia i ataki u??yte przeciwko bohaterom lub budowlom zapewniaj?? 20 szt. z??ota. Efekt mo??e wyst??pi?? do 3 razy w ci??gu 30 sek.<li><passive>Zadanie:</passive> Zdob??d?? 1000 szt. z??ota przy u??yciu tego przedmiotu, by przemieni?? go w <rarityLegendary>Od??amek Prawdziwego Lodu</rarityLegendary>.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3851.png', 400, 160);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3853, 'Od??amek Prawdziwego Lodu', '<mainText><stats><attention>40 pkt.</attention> mocy umiej??tno??ci<br><attention>75 pkt.</attention> zdrowia<br><attention>115%</attention> podstawowej regeneracji many<br><attention>3 szt.</attention> z??ota co 10 sek.</stats><br><br><active>U??ycie ???</active> <active>Umieszczanie Totem??w:</active> Umieszczasz na ziemi <keywordStealth>niewidoczny</keywordStealth> dla wrog??w Totem Ukrycia, kt??ry zapewnia twojej dru??ynie wizj?? na pobliskim obszarze. Przechowuje do 0 Totem??w Ukrycia, kt??re odnawiaj?? si??, ilekro?? odwiedzisz sklep. <br><br><active>U??ycie ???</active> <active>Umieszczanie Totem??w:</active> Umieszczasz na ziemi <keywordStealth>niewidoczny</keywordStealth> dla wrog??w Totem Ukrycia, kt??ry zapewnia twojej dru??ynie wizj?? na pobliskim obszarze. Przechowuje do 4 Totem??w Ukrycia, kt??re odnawiaj?? si??, ilekro?? odwiedzasz sklep. </mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3853.png', 400, 160);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3854, 'Stalowe Naramienniki', '<mainText><stats><attention>3 pkt.</attention> obra??e?? od ataku<br><attention>30 pkt.</attention> zdrowia<br><attention>25%</attention> podstawowej regeneracji zdrowia<br><attention>2 szt.</attention> z??ota co 10 sek.</stats><li><passive>??upy Wojenne:</passive> Gdy znajdujesz si?? w pobli??u sojuszniczego bohatera, twoje ataki wyka??czaj?? stwory, kt??rych poziom zdrowia w przypadku bohater??w walcz??cych w zwarciu wynosi mniej ni?? 50% (30% w przypadku bohater??w walcz??cych z dystansu) ich maks. zdrowia. Zabicie stwora przyznaje tyle samo szt. z??ota najbli??szemu sojuszniczemu bohaterowi. Te efekty odnawiaj?? si?? co 3 sek. (maks. liczba ??adunk??w: 35).<li><passive>Zadanie:</passive> Zdob??d?? 500 szt. z??ota przy u??yciu tego przedmiotu, by przemieni?? go w <rarityGeneric>Ochraniacze z Runicznej Stali</rarityGeneric> i zyska?? <active>U??ycie ???</active> <active>Umieszczanie Totem??w</active>.<br><br><rules>Ten przedmiot zapewnia zmniejszon?? ilo???? z??ota ze stwor??w, je??li zabijesz ich zbyt wiele.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3854.png', 400, 160);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3855, 'Ochraniacze z Runicznej Stali', '<mainText><stats><attention>6 pkt.</attention> obra??e?? od ataku<br><attention>100 pkt.</attention> zdrowia<br><attention>50%</attention> podstawowej regeneracji zdrowia<br><attention>3 szt.</attention> z??ota co 10 sek.</stats><br><br><active>U??ycie ???</active> <active>Umieszczanie Totem??w:</active> Umieszczasz na ziemi <keywordStealth>niewidoczny</keywordStealth> dla wrog??w Totem Ukrycia, kt??ry zapewnia twojej dru??ynie wizj?? na pobliskim obszarze. Przechowuje do 0 Totem??w Ukrycia, kt??re odnawiaj?? si??, ilekro?? odwiedzisz sklep. <br><br><active>U??ycie ???</active> <active>Umieszczanie Totem??w:</active> Umieszczasz na ziemi <keywordStealth>niewidoczny</keywordStealth> dla wrog??w Totem Ukrycia, kt??ry zapewnia twojej dru??ynie wizj?? na pobliskim obszarze. Przechowuje do 3 Totem??w Ukrycia, kt??re odnawiaj?? si??, ilekro?? odwiedzasz sklep. <br><li><passive>??upy Wojenne:</passive> Gdy znajdujesz si?? w pobli??u sojuszniczego bohatera, twoje ataki wyka??czaj?? stwory, kt??re maj?? mniej ni?? 50% maks. zdrowia. Zabicie stwora przyznaje tyle samo szt. z??ota najbli??szemu sojuszniczemu bohaterowi. Te efekty odnawiaj?? si?? co 35 sek. (maks. liczba ??adunk??w: 3).<li><passive>Zadanie:</passive> Zdob??d?? 1000 szt. z??ota przy u??yciu tego przedmiotu, by przemieni?? go w <rarityLegendary>Bastion G??ry</rarityLegendary>. </mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3855.png', 400, 160);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3857, 'Naramienniki spod Bia??ej Ska??y', '<mainText><stats><attention>15 pkt.</attention> obra??e?? od ataku<br><attention>250 pkt.</attention> zdrowia<br><attention>100%</attention> podstawowej regeneracji zdrowia<br><attention>3 szt.</attention> z??ota co 10 sek.</stats><br><br><active>U??ycie ???</active> <active>Umieszczanie Totem??w:</active> Umieszczasz na ziemi <keywordStealth>niewidoczny</keywordStealth> dla wrog??w Totem Ukrycia, kt??ry zapewnia twojej dru??ynie wizj?? na pobliskim obszarze. Przechowuje do 0 Totem??w Ukrycia, kt??re odnawiaj?? si??, ilekro?? odwiedzisz sklep. <br><br><active>U??ycie ???</active> <active>Umieszczanie Totem??w:</active> Umieszczasz na ziemi <keywordStealth>niewidoczny</keywordStealth> dla wrog??w Totem Ukrycia, kt??ry zapewnia twojej dru??ynie wizj?? na pobliskim obszarze. Przechowuje do 4 Totem??w Ukrycia, kt??re odnawiaj?? si??, ilekro?? odwiedzasz sklep. </mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3857.png', 400, 160);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3858, 'Reliktowa Tarcza', '<mainText><stats><attention>5 pkt.</attention> mocy umiej??tno??ci<br><attention>30 pkt.</attention> zdrowia<br><attention>25%</attention> podstawowej regeneracji zdrowia<br><attention>2 szt.</attention> z??ota co 10 sek.</stats><li><passive>??upy Wojenne:</passive> Gdy znajdujesz si?? w pobli??u sojuszniczego bohatera, twoje ataki wyka??czaj?? stwory, kt??rych poziom zdrowia w przypadku bohater??w walcz??cych w zwarciu wynosi mniej ni?? 50% (30% w przypadku bohater??w walcz??cych z dystansu) ich maks. zdrowia. Zabicie stwora przyznaje tyle samo szt. z??ota najbli??szemu sojuszniczemu bohaterowi. Te efekty odnawiaj?? si?? co 3 sek. (maks. liczba ??adunk??w: 35).<li><passive>Zadanie:</passive> Zdob??d?? 500 szt. z??ota przy u??yciu tego przedmiotu, by przemieni?? go w <rarityGeneric>Puklerz Targonu</rarityGeneric> i zyska?? <active>U??ycie ???</active> <active>Umieszczanie Totem??w</active>.<br><br><rules>Ten przedmiot zapewnia zmniejszon?? ilo???? z??ota ze stwor??w, je??li zabijesz ich zbyt wiele.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3858.png', 400, 160);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3859, 'Puklerz Targonu', '<mainText><stats><attention>10 pkt.</attention> mocy umiej??tno??ci<br><attention>100 pkt.</attention> zdrowia<br><attention>50%</attention> podstawowej regeneracji zdrowia<br><attention>3 szt.</attention> z??ota co 10 sek.</stats><br><br><active>U??ycie ???</active> <active>Umieszczanie Totem??w:</active> Umieszczasz na ziemi <keywordStealth>niewidoczny</keywordStealth> dla wrog??w Totem Ukrycia, kt??ry zapewnia twojej dru??ynie wizj?? na pobliskim obszarze. Przechowuje do 0 Totem??w Ukrycia, kt??re odnawiaj?? si??, ilekro?? odwiedzisz sklep. <br><br><active>U??ycie ???</active> <active>Umieszczanie Totem??w:</active> Umieszczasz na ziemi <keywordStealth>niewidoczny</keywordStealth> dla wrog??w Totem Ukrycia, kt??ry zapewnia twojej dru??ynie wizj?? na pobliskim obszarze. Przechowuje do 3 Totem??w Ukrycia, kt??re odnawiaj?? si??, ilekro?? odwiedzasz sklep. <br><li><passive>??upy Wojenne:</passive> Gdy znajdujesz si?? w pobli??u sojuszniczego bohatera, twoje ataki wyka??czaj?? stwory, kt??re maj?? mniej ni?? 50% maks. zdrowia. Zabicie stwora przyznaje tyle samo szt. z??ota najbli??szemu sojuszniczemu bohaterowi. Te efekty odnawiaj?? si?? co 35 sek. (maks. liczba ??adunk??w: 3).<li><passive>Zadanie:</passive> Zdob??d?? 1000 szt. z??ota przy u??yciu tego przedmiotu, by przemieni?? go w <rarityLegendary>Bastion G??ry</rarityLegendary>. </mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3859.png', 400, 160);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3860, 'Bastion G??ry', '<mainText><stats><attention>20 pkt.</attention> mocy umiej??tno??ci<br><attention>250 pkt.</attention> zdrowia<br><attention>100%</attention> podstawowej regeneracji zdrowia<br><attention>3 szt.</attention> z??ota co 10 sek.</stats><br><br><active>U??ycie ???</active> <active>Umieszczanie Totem??w:</active> Umieszczasz na ziemi <keywordStealth>niewidoczny</keywordStealth> dla wrog??w Totem Ukrycia, kt??ry zapewnia twojej dru??ynie wizj?? na pobliskim obszarze. Przechowuje do 0 Totem??w Ukrycia, kt??re odnawiaj?? si??, ilekro?? odwiedzisz sklep. <br><br><active>U??ycie ???</active> <active>Umieszczanie Totem??w:</active> Umieszczasz na ziemi <keywordStealth>niewidoczny</keywordStealth> dla wrog??w Totem Ukrycia, kt??ry zapewnia twojej dru??ynie wizj?? na pobliskim obszarze. Przechowuje do 4 Totem??w Ukrycia, kt??re odnawiaj?? si??, ilekro?? odwiedzasz sklep. </mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3860.png', 400, 160);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3862, 'Widmowy Sierp', '<mainText><stats><attention>5 pkt.</attention> obra??e?? od ataku<br><attention>10 pkt.</attention> zdrowia<br><attention>25%</attention> podstawowej regeneracji many<br><attention>2 szt.</attention> z??ota co 10 sek.</stats><br><li><passive>Danina:</passive> Gdy znajdujesz si?? w pobli??u sojuszniczego bohatera, umiej??tno??ci zadaj??ce obra??enia i ataki u??yte przeciwko wrogom lub budowlom zapewniaj?? 20 szt. z??ota. Efekt mo??e wyst??pi?? do 3 razy w ci??gu 30 sek.<li><passive>Zadanie:</passive> Zdob??d?? 500 szt. z??ota przy u??yciu tego przedmiotu, by przemieni?? go w <rarityGeneric>P????ksi????ycowe Ostrze Harrowing</rarityGeneric> i zyska?? <active>U??ycie ???</active> <active>Umieszczanie Totem??w</active>.<br><br><rules>Ten przedmiot zapewnia zmniejszon?? ilo???? z??ota ze stwor??w, je??li zabijesz ich zbyt wiele.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3862.png', 400, 160);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3863, 'P????ksi????ycowe Ostrze Harrowing', '<mainText><stats><attention>10 pkt.</attention> obra??e?? od ataku<br><attention>60 pkt.</attention> zdrowia<br><attention>50%</attention> podstawowej regeneracji many<br><attention>3 szt.</attention> z??ota co 10 sek.</stats><br><br><active>U??ycie ???</active> <active>Umieszczanie Totem??w:</active> Umieszczasz na ziemi <keywordStealth>niewidoczny</keywordStealth> dla wrog??w Totem Ukrycia, kt??ry zapewnia twojej dru??ynie wizj?? na pobliskim obszarze. Przechowuje do 0 Totem??w Ukrycia, kt??re odnawiaj?? si??, ilekro?? odwiedzisz sklep. <br><li><passive>Danina:</passive> Gdy znajdujesz si?? w pobli??u sojuszniczego bohatera, umiej??tno??ci zadaj??ce obra??enia i ataki u??yte przeciwko wrogom lub budowlom zapewniaj?? 20 szt. z??ota. Efekt mo??e wyst??pi?? do 3 razy w ci??gu 30 sek.<li><passive>Zadanie:</passive> Zdob??d?? 1000 szt. z??ota przy u??yciu tego przedmiotu, by przemieni?? go w <rarityLegendary>Kos?? Czarnej Mg??y</rarityLegendary> i zyska?? Umieszczanie Totem??w.<br><br><rules>Ten przedmiot zapewnia zmniejszon?? ilo???? z??ota ze stwor??w, je??li zabijesz ich zbyt wiele.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3863.png', 400, 160);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3864, 'Kosa Czarnej Mg??y', '<mainText><stats><attention>20 pkt.</attention> obra??e?? od ataku<br><attention>75 pkt.</attention> zdrowia<br><attention>100%</attention> podstawowej regeneracji many<br><attention>3 szt.</attention> z??ota co 10 sek.</stats><br><br><active>U??ycie ???</active> <active>Umieszczanie Totem??w:</active> Umieszczasz na ziemi <keywordStealth>niewidoczny</keywordStealth> dla wrog??w Totem Ukrycia, kt??ry zapewnia twojej dru??ynie wizj?? na pobliskim obszarze. Przechowuje do 0 Totem??w Ukrycia, kt??re odnawiaj?? si??, ilekro?? odwiedzisz sklep. <br><br><active>U??ycie ???</active> <active>Umieszczanie Totem??w:</active> Umieszczasz na ziemi <keywordStealth>niewidoczny</keywordStealth> dla wrog??w Totem Ukrycia, kt??ry zapewnia twojej dru??ynie wizj?? na pobliskim obszarze. Przechowuje do 4 Totem??w Ukrycia, kt??re odnawiaj?? si??, ilekro?? odwiedzasz sklep. </mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3864.png', 400, 160);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(3916, 'Kula Zag??ady', '<mainText><stats><attention>35 pkt.</attention> mocy umiej??tno??ci</stats><br><li><passive>Kl??twa:</passive> Zadawanie wrogim bohaterom obra??e?? magicznych nak??ada na nich <status>G????bokie Rany o warto??ci 25%</status> na 3 sek.<br><br><rules><status>G????bokie Rany</status> os??abiaj?? efektywno???? leczenia i regeneracji.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/3916.png', 800, 560);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(4005, 'Imperialny Mandat', '<mainText><stats><attention>40 pkt.</attention> mocy umiej??tno??ci<br><attention>200 pkt.</attention> zdrowia<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci<br><attention>100%</attention> podstawowej regeneracji many</stats><br><li><passive>Skoordynowany Ogie??:</passive> Umiej??tno??ci, kt??re <status>spowalniaj??</status> lub <status>unieruchamiaj??</status> bohatera, zadaj?? mu dodatkowe obra??enia i oznaczaj?? go. Zadane przez sojusznika obra??enia detonuj?? te oznaczenie, zadaj??c dodatkowe obra??enia i zapewniaj??c wam pr??dko???? ruchu. <br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Moc umiej??tno??ci. <br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/4005.png', 2500, 1750);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(4401, 'Si??a Natury', '<mainText><stats><attention>350 pkt.</attention> zdrowia<br><attention>70 pkt.</attention> odporno??ci na magi??<br><attention>5%</attention> pr??dko??ci ruchu</stats><br><li><passive>Poch??oni??cie:</passive> Otrzymanie <magicDamage>obra??e?? magicznych</magicDamage> od wrogiego bohatera zapewnia ??adunek <attention>Niewzruszenia</attention>. Wrogie efekty <status>unieruchamiaj??ce</status> zapewniaj?? dodatkowe ??adunki.<li><passive>Rozproszenie:</passive> Maj??c maksymaln?? liczb?? ??adunk??w <attention>Niewzruszenia</attention>, otrzymujesz mniejsze obra??enia magiczne i zyskujesz pr??dko???? ruchu.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/4401.png', 2900, 2030);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(4403, 'Z??ota Szpatu??ka', '<mainText><stats><attention>70 pkt.</attention> obra??e?? od ataku<br><attention>120 pkt.</attention> mocy umiej??tno??ci<br><attention>50%</attention> pr??dko??ci ataku<br><attention>30%</attention> szansy na trafienie krytyczne<br><attention>250 pkt.</attention> zdrowia<br><attention>30 pkt.</attention> pancerza<br><attention>30 pkt.</attention> odporno??ci na magi??<br><attention>250 pkt.</attention> many<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci<br><attention>10%</attention> pr??dko??ci ruchu<br><attention>10%</attention> kradzie??y ??ycia<br><attention>100%</attention> podstawowej regeneracji zdrowia<br><attention>100%</attention> podstawowej regeneracji many</stats><br><li><passive>Robi Co??:</passive> Stale igrasz z ogniem!</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/4403.png', 7187, 5031);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(4628, 'Skupienie Horyzontalne', '<mainText><stats><attention>100 pkt.</attention> mocy umiej??tno??ci<br><attention>150 pkt.</attention> zdrowia<br><attention>15</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Hiperstrza??:</passive> Zadanie bohaterowi obra??e?? umiej??tno??ci?? niemierzon?? z odleg??o??ci ponad 700 jedn. lub <status>spowolnienie albo unieruchomienie</status> go <keywordStealth>ujawnia</keywordStealth> cel i zwi??ksza zadawane mu przez ciebie obra??enia. <br><br><rules>Umiej??tno????, kt??ra aktywuje <passive>Hiperstrza??</passive>, r??wnie?? zadaje zwi??kszone obra??enia. Zwierz??tka i nieunieruchamiaj??ce pu??apki nie aktywuj?? tego efektu. Tylko pocz??tkowe ustawienie umiej??tno??ci tworz??cych pola aktywuje ten efekt. Odleg??o???? jest liczona od miejsca u??ycia umiej??tno??ci. </rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/4628.png', 3000, 2100);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(4629, 'Kosmiczny Impuls', '<mainText><stats><attention>65 pkt.</attention> mocy umiej??tno??ci<br><attention>200 pkt.</attention> zdrowia<br><attention>30</attention> jedn. przyspieszenia umiej??tno??ci<br><attention>5%</attention> pr??dko??ci ruchu</stats><br><li><passive>Czarowny Pl??s:</passive> Zadanie obra??e?? bohaterowi za pomoc?? nast??puj??cej liczby oddzielnych atak??w lub zakl????: 3 zapewnia dodatkow?? pr??dko???? ruchu oraz moc umiej??tno??ci a?? do zako??czenia walki z bohaterami.<br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/4629.png', 3000, 2100);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(4630, 'Klejnot Rozpadu', '<mainText><stats><attention>25 pkt.</attention> mocy umiej??tno??ci<br><attention>13%</attention> przebicia odporno??ci na magi??</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/4630.png', 1250, 875);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(4632, 'Ro??linna Bariera', '<mainText><stats><attention>20 pkt.</attention> mocy umiej??tno??ci<br><attention>25 pkt.</attention> odporno??ci na magi??</stats><br><li><passive>Adaptacyjnie:</passive> Zabicie jednostki zapewnia <scaleMR>0.3 pkt. odporno??ci na magi??</scaleMR> (maks. <scaleMR>9 pkt.</scaleMR>).<br><br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/4632.png', 1000, 700);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(4633, 'Szczelinotw??rca', '<mainText><stats><attention>70 pkt.</attention> mocy umiej??tno??ci<br><attention>300 pkt.</attention> zdrowia<br><attention>15</attention> jedn. przyspieszenia umiej??tno??ci<br><attention>7%</attention> wszechwampiryzmu</stats><br><li><passive>Spaczenie Pustki:</passive> Za ka??d?? sekund?? zadawania obra??e?? wrogim bohaterom zadajesz dodatkowe obra??enia. Przy maksymalnej warto??ci dodatkowe obra??enia zostaj?? zadane jako <trueDamage>obra??enia nieuchronne</trueDamage>. <br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Wszechwampiryzm i moc umiej??tno??ci.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/4633.png', 3200, 2240);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(4635, 'Wysysaj??ce Spojrzenie', '<mainText><stats><attention>20 pkt.</attention> mocy umiej??tno??ci<br><attention>250 pkt.</attention> zdrowia<br><attention>5%</attention> wszechwampiryzmu</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/4635.png', 1300, 910);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(4636, 'Nocny ??niwiarz', '<mainText><stats><attention>90 pkt.</attention> mocy umiej??tno??ci<br><attention>300 pkt.</attention> zdrowia<br><attention>25</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Rozerwanie Duszy:</passive> Zadawanie obra??e?? bohaterowi zadaje dodatkowe obra??enia magiczne i zapewnia ci pr??dko???? ruchu.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Przyspieszenie umiej??tno??ci.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/4636.png', 3200, 2240);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(4637, 'Demoniczny U??cisk', '<mainText><stats><attention>75 pkt.</attention> mocy umiej??tno??ci<br><attention>350 pkt.</attention> zdrowia</stats><br><li><passive>Spojrzenie Azakana:</passive> Zadawanie bohaterom obra??e?? za pomoc?? umiej??tno??ci podpala ich, przez co otrzymuj?? oni dodatkowo co sekund?? obra??enia magiczne zale??ne od ich maksymalnego zdrowia.<li><passive>Mroczny Pakt:</passive> Zyskaj <scaleHealth>dodatkowe zdrowie</scaleHealth> jako <scaleAP>moc umiej??tno??ci</scaleAP>. </mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/4637.png', 3000, 2100);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(4638, 'Czujny Kamienny Totem', '<mainText><stats><attention>150 pkt.</attention> zdrowia<br><attention>10</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Tajemna Skrytka:</passive> Ten przedmiot mo??e przechowywa?? do 3 zakupionych Totem??w Kontroli.<br><br>Po uko??czeniu <keywordMajor>misji dla wspieraj??cych</keywordMajor> i osi??gni??ciu poziomu 13. przemienia si?? w <rarityLegendary>Baczny Kamienny Totem</rarityLegendary>.<br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/4638.png', 1100, 770);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(4641, 'Pasjonuj??cy Kamienny Totem', '<mainText><stats><attention>100 pkt.</attention> zdrowia<br><attention>10</attention> jedn. przyspieszenia umiej??tno??ci</stats><li><passive>Tajemna Skrytka:</passive> Ten przedmiot mo??e przechowywa?? do 3 zakupionych Totem??w Kontroli.<li><passive>Rozkwitaj??ce Imperium:</passive> Ten przedmiot przemienia si?? w <rarityLegendary>Czujny Kamienny Totem</rarityLegendary> po umieszczeniu 15 Totem??w Ukrycia.<br><br><rules>Totemy Ukrycia s?? umieszczane przy u??yciu Talizmanu Totem??w Ukrycia i ulepszonych przedmiot??w: <attention>Unikalne: Wsparcie</attention>.</rules><br><br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/4641.png', 1200, 480);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(4642, 'Lustro ze Szk??a Bandle', '<mainText><stats><attention>20 pkt.</attention> mocy umiej??tno??ci<br><attention>10</attention> jedn. przyspieszenia umiej??tno??ci<br><attention>50%</attention> podstawowej regeneracji many</stats></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/4642.png', 950, 665);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(4643, 'Baczny Kamienny Totem', '<mainText><stats><attention>150 pkt.</attention> zdrowia<br><attention>15</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Tajemna Skrytka:</passive> Ten przedmiot mo??e przechowywa?? do 3 zakupionych Totem??w Kontroli.<li><passive>Wejrzenie:</passive> Zwi??ksza limity ustawionych Totem??w Ukrycia i Totem??w Kontroli o 1.<li><passive>B??ogos??awie??stwo Ixtal:</passive> Zapewnia premi?? do dodatkowego zdrowia, dodatkowych obra??e?? od ataku, przyspieszenia umiej??tno??ci i mocy umiej??tno??ci w wysoko??ci 12%.<br><br><rules>Pochodzi z ulepszenia <rarityLegendary>Czujnego Kamienia Widzenia</rarityLegendary>.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/4643.png', 1100, 770);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(4644, 'Korona Roztrzaskanej Kr??lowej', '<mainText><stats><attention>70 pkt.</attention> mocy umiej??tno??ci<br><attention>250 pkt.</attention> zdrowia<br><attention>600 pkt.</attention> many<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Boska Os??ona:</passive> Zapewnia <keywordMajor>Os??on??</keywordMajor>, kt??ra zmniejsza obra??enia otrzymywane od bohater??w. <keywordMajor>Os??ona</keywordMajor> utrzymuje si?? przez 1.5 sek. po otrzymaniu obra??e?? od bohater??w. <li><passive>Boski Dar:</passive> Podczas utrzymywania si?? <keywordMajor>Os??ony</keywordMajor> i przez 3 sek. po jej zniszczeniu zyskujesz dodatkow?? moc umiej??tno??ci. <br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Pr??dko???? ruchu i moc umiej??tno??ci.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/4644.png', 2800, 1960);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(4645, 'P??omie?? Cienia', '<mainText><stats><attention>100 pkt.</attention> mocy umiej??tno??ci<br><attention>200 pkt.</attention> zdrowia</stats><br><li><passive>Rozkwit ??aru:</passive> Obra??enia zadawane bohaterom zyskuj?? dodatkowe <keywordStealth>przebicie odporno??ci na magi??</keywordStealth> w zale??no??ci od <scaleHealth>aktualnego zdrowia</scaleHealth> celu. Zyskujesz maksymaln?? korzy????, je??li cel by?? ostatnio pod wp??ywem dzia??ania tarcz. </mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/4645.png', 3000, 2100);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6029, '??elazny Bicz', '<mainText><stats><attention>30 pkt.</attention> obra??e?? od ataku</stats><br><br><active>U??ycie ???</active> <active>P????ksi????yc:</active> Zadaj obra??enia przeciwnikom znajduj??cym si?? w pobli??u.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6029.png', 1100, 770);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6035, '??wit Srebrzystej', '<mainText><stats><attention>40 pkt.</attention> obra??e?? od ataku<br><attention>300 pkt.</attention> zdrowia<br><attention>40 pkt.</attention> odporno??ci na magi??</stats><br><br><active>U??ycie ???</active> <active>??ywe Srebro:</active> Usuwa wszystkie efekty kontroli t??umu; zyskujesz nieust??pliwo???? i odporno???? na spowolnienia.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6035.png', 3000, 2100);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6333, 'Taniec ??mierci', '<mainText><stats><attention>55 pkt.</attention> obra??e?? od ataku<br><attention>45 pkt.</attention> pancerza<br><attention>15</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Ignorowany B??l:</passive> Otrzymywane przez ciebie obra??enia s?? roz??o??one w czasie.<li><passive>Przeciwstawienie:</passive> Udzia??y w zab??jstwach bohater??w oczyszczaj?? pul?? obra??e?? <passive>Ignorowanego B??lu</passive> i przywracaj?? zdrowie wraz z up??ywem czasu.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6333.png', 3300, 2310);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6609, 'Chempunkowy ??a??cuchowy Miecz', '<mainText><stats><attention>55 pkt.</attention> obra??e?? od ataku<br><attention>250 pkt.</attention> zdrowia<br><attention>25</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Z??amany R??g:</passive> Zadawanie wrogim bohaterom obra??e?? fizycznych nak??ada na nich <status>G????bokie Rany o warto??ci 25%</status> na 3 sek. Je??li cel ma mniej ni?? 50% zdrowia, warto???? <status>G????bokich Ran</status> zwi??ksza si?? do 40%.<br><br><rules><status>G????bokie Rany</status> os??abiaj?? efektywno???? leczenia i regeneracji.</rules></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6609.png', 2800, 1960);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6616, 'Kostur P??yn??cej Wody', '<mainText><stats><attention>50 pkt.</attention> mocy umiej??tno??ci<br><attention>8%</attention> si??y leczenia i tarcz<br><attention>100%</attention> podstawowej regeneracji many</stats><br><li><passive>Fale:</passive> Uleczenie lub os??oni??cie innego sojusznika tarcz?? zapewnia wam dodatkow?? moc umiej??tno??ci i przyspieszenie umiej??tno??ci.<br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6616.png', 2300, 1610);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6617, 'Odnowienie Kamienia Ksi????ycowego', '<mainText><stats><attention>40 pkt.</attention> mocy umiej??tno??ci<br><attention>200 pkt.</attention> zdrowia<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci<br><attention>100%</attention> podstawowej regeneracji many</stats><br><li><passive>??aska Gwiazd:</passive> Trafianie bohater??w atakami lub umiej??tno??ciami podczas walki przywraca zdrowie najpowa??niej zranionemu sojusznikowi w pobli??u. Ka??da sekunda sp??dzona w walce z bohaterami zwi??ksza twoj?? si???? leczenia i tarcz.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom zwi??kszenie leczenia <passive>??aski Gwiazd</passive>.<br><br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6617.png', 2500, 1750);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6630, 'Ch??eptacz Posoki', '<mainText><stats><attention>55 pkt.</attention> obra??e?? od ataku<br><attention>300 pkt.</attention> zdrowia<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci<br><attention>8%</attention> wszechwampiryzmu</stats><br><br><active>U??ycie ???</active> <active>Spragnione Ci??cie:</active> Zadaje obra??enia pobliskim wrogom. Przywracasz sobie zdrowie za ka??dego trafionego bohatera.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Przyspieszenie umiej??tno??ci.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6630.png', 3300, 2310);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6631, '??amacz Falangi', '<mainText><stats><attention>50 pkt.</attention> obra??e?? od ataku<br><attention>20%</attention> pr??dko??ci ataku<br><attention>300 pkt.</attention> zdrowia<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci</stats><br> <br><active>U??ycie ???</active><active>Zatrzymuj??ce Ci??cie:</active> Zadaje obra??enia pobliskim wrogom, <status>spowalniaj??c</status> ich. Mo??e zosta?? u??yte w ruchu.<br><li><passive>Heroiczny Krok:</passive> Zadawanie obra??e?? fizycznych zapewnia pr??dko???? ruchu.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Pr??dko???? ruchu.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6631.png', 3300, 2310);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6632, 'Boski ??amacz', '<mainText><stats><attention>40 pkt.</attention> obra??e?? od ataku<br><attention>300 pkt.</attention> zdrowia<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci</stats><li><passive>Czaroostrze:</passive> Tw??j nast??pny atak po u??yciu umiej??tno??ci jest wzmocniony i zadaje dodatkowe obra??enia <OnHit>przy trafieniu</OnHit>. Je??li cel jest bohaterem, uleczysz si??.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Przebicie pancerza i przebicie odporno??ci na magi??.<br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6632.png', 3300, 2310);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6653, 'Cierpienie Liandry''ego', '<mainText><stats><attention>80 pkt.</attention> mocy umiej??tno??ci<br><attention>600 pkt.</attention> many<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Agonia:</passive> Zadaje dodatkowe obra??enia magiczne bohaterom w zale??no??ci od dodatkowego zdrowia celu.<li><passive>Udr??ka:</passive> Zadawanie obra??e?? umiej??tno??ciami podpala wrog??w na okre??lony czas.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Przyspieszenie umiej??tno??ci.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6653.png', 3200, 2240);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6655, 'Nawa??nica Luden', '<mainText><stats><attention>80 pkt.</attention> mocy umiej??tno??ci<br><attention>6 pkt.</attention> przebicia odporno??ci na magi??<br><attention>600 pkt.</attention> many<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Echo:</passive> Umiej??tno??ci zadaj??ce obra??enia zadaj?? obra??enia magiczne celowi i 3 pobliskim wrogom oraz zapewniaj?? ci pr??dko???? ruchu. Zadawanie obra??e?? bohaterom za pomoc?? umiej??tno??ci skraca czas odnowienia tego przedmiotu.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Przebicie odporno??ci na magi??. </mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6655.png', 3200, 2240);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6656, 'Wieczna Zmarzlina', '<mainText><stats><attention>70 pkt.</attention> mocy umiej??tno??ci<br><attention>250 pkt.</attention> zdrowia<br><attention>600 pkt.</attention> many<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><br><active>U??ycie ???</active> <active>Oblodzenie:</active> Zadaje obra??enia w sto??ku, <status>spowalniaj??c</status> trafionych wrog??w. Wrogowie znajduj??cy si?? w centrum sto??ka zostaj?? <status>unieruchomieni</status>.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Moc umiej??tno??ci. <br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6656.png', 2800, 1960);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6657, 'R????d??ka Wiek??w', '<mainText><stats><attention>60 pkt.</attention> mocy umiej??tno??ci<br><attention>400 pkt.</attention> zdrowia<br><attention>400 pkt.</attention> many</stats><br><br>Przedmiot co 60 sek. zyskuje 20 pkt. zdrowia, 20 pkt. many i 4 pkt. mocy umiej??tno??ci, maksymalnie 10 razy. Maksymalnie mo??na zyska?? 200 pkt. zdrowia, 200 pkt. many i 40 pkt. mocy umiej??tno??ci. Po uzyskaniu maksymalnej liczby ??adunk??w zyskujesz poziom, a wszystkie efekty Wieczno??ci zostaj?? zwi??kszone o 50%.<br><li><passive>Wieczno????:</passive> Przywraca man?? r??wn?? warto??ci 7% czystych obra??e?? otrzymanych od bohater??w oraz zdrowie r??wne 25% zu??ytej many, maks. 20 pkt. zdrowia na u??ycie, na sekund??. Za ka??de przywr??cone w ten spos??b 200 pkt. zdrowia lub many zyskujesz <speed>35% zanikaj??cej pr??dko??ci ruchu</speed> na 3 sek.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom <attention>5 jedn. przyspieszenia umiej??tno??ci.</attention></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6657.png', 2800, 1960);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6660, '??ar Bami', '<mainText><stats><attention>300 pkt.</attention> zdrowia</stats><br><li><passive>Po??oga:</passive> Zadanie lub otrzymanie obra??e?? sprawia, ??e zadajesz pobliskim wrogom obra??enia magiczne co sekund?? (kt??re zostaj?? zwi??kszone przeciwko stworom i potworom).</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6660.png', 1000, 700);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6662, 'Lodowa R??kawica', '<mainText><stats><attention>400 pkt.</attention> zdrowia<br><attention>50 pkt.</attention> pancerza<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Czaroostrze:</passive> Po u??yciu umiej??tno??ci nast??pny atak jest wzmocniony: zadaje dodatkowe obra??enia i tworzy pole lodowe na 2.5 sek. Wrogowie, kt??rzy przejd?? przez pole, zostan?? <status>spowolnieni</status>. G????wny cel zostaje os??abiony, co nak??ada na niego o 100% wi??ksze spowolnienie i zmniejsza zadawane ci przez niego obra??enia o 10% na 2.5 sek. (1.5sek. ).<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom <attention>50 pkt. zdrowia</attention>, <attention>5%</attention> nieust??pliwo??ci i <attention>5%</attention> odporno??ci na spowolnienia.<br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6662.png', 3000, 2100);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6664, 'Turbochemiczny Pojemnik', '<mainText><stats><attention>500 pkt.</attention> zdrowia<br><attention>50 pkt.</attention> odporno??ci na magi??<br><attention>10</attention> jedn. przyspieszenia umiej??tno??ci</stats><br> <br><active>U??ycie ???</active><active>Superdo??adowanie:</active> Zapewnia dodatkow?? pr??dko???? ruchu przy poruszaniu si?? w stron?? wrog??w lub wrogich wie??. Gdy znajdziesz si?? w pobli??u wroga (lub po up??ywie 4 sek.), wypuszczona zostanie fala uderzeniowa, kt??ra <status>spowolni</status> pobliskich bohater??w.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6664.png', 2800, 1960);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6665, 'Jak''Sho Zmienny', '<mainText><stats><attention>400 pkt.</attention> zdrowia<br><attention>30 pkt.</attention> pancerza<br><attention>30 pkt.</attention> odporno??ci na magi??<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Wytrzyma??o???? Dzieci Pustki:</passive> Za ka??d?? sekund?? w walce z bohaterami zyskujesz ??adunek zapewniaj??cy 2 pkt. <scaleArmor>pancerza</scaleArmor> i <scaleMR>odporno??ci na magi??</scaleMR>. Maksymalna liczba ??adunk??w: 8. Po osi??gni??ciu maksymalnej liczby ??adunk??w przedmiot zostaje wzmocniony, natychmiast czerpi??c zdrowie od pobliskich wrog??w, zadaj??c im 0 pkt. obra??e?? magicznych i lecz??c ci?? o tak?? sam?? warto????, oraz zwi??ksza tw??j dodatkowy pancerz i odporno???? na magi?? o 20% do ko??ca walki.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom <attention>5 pkt.pancerza i odporno??ci na magi??</attention>.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6665.png', 3200, 2240);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6667, '??wietlista Cnota', '<mainText><stats><attention>400 pkt.</attention> zdrowia<br><attention>30 pkt.</attention> pancerza<br><attention>30 pkt.</attention> odporno??ci na magi??<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Przewodnie ??wiat??o:</passive> Po u??yciu superumiej??tno??ci zyskujesz Transcendencj??, zwi??kszaj??c swoje maks. zdrowie o 10% na 9 sek. Podczas Transcendencji ty i twoi sojusznicy znajduj??cy si?? w zasi??gu 1200 jedn. zyskujecie 20 jedn. przyspieszenia podstawowych umiej??tno??ci i leczycie si?? o 2% swojego maks. zdrowia co 3 sek. Efekt zostaje zwi??kszony o do 100% zale??nie od brakuj??cego zdrowia bohatera (60sek. czasu odnowienia).<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom <attention>100 pkt.</attention> zdrowia.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6667.png', 3000, 2100);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6670, 'Ko??czan Po??udnia', '<mainText><stats><attention>30 pkt.</attention> obra??e?? od ataku<br><attention>15%</attention> pr??dko??ci ataku</stats><br><li><passive>Precyzja:</passive> Ataki zadaj?? dodatkowe obra??enia stworom i potworom.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6670.png', 1300, 910);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6671, 'Pot??ga Wichury', '<mainText><stats><attention>60 pkt.</attention> obra??e?? od ataku<br><attention>20%</attention> pr??dko??ci ataku<br><attention>20%</attention> szansy na trafienie krytyczne</stats><br><br><active>U??ycie ???</active> <active>Urwanie Chmury:</active> Doskakujesz w wybranym kierunku, wystrzeliwuj??c 3 pociski w stron?? wroga o najni??szym poziomie zdrowia w pobli??u miejsca docelowego. Zadaje obra??enia, kt??re zostaj?? zwi??kszone przeciwko celom o niskim poziomie zdrowia.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Pr??dko???? ruchu.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6671.png', 3400, 2380);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6672, 'Pogromca Kraken??w', '<mainText><stats><attention>65 pkt.</attention> obra??e?? od ataku<br><attention>25%</attention> pr??dko??ci ataku<br><attention>20%</attention> szansy na trafienie krytyczne</stats><br><li><passive>Powalenie:</passive> Ka??dy co trzeci atak zadaje dodatkowe obra??enia nieuchronne.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Pr??dko???? ataku.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6672.png', 3400, 2380);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6673, 'Nie??miertelny ??uklerz', '<mainText><stats><attention>50 pkt.</attention> obra??e?? od ataku<br><attention>20%</attention> pr??dko??ci ataku<br><attention>20%</attention> szansy na trafienie krytyczne<br><attention>7%</attention> kradzie??y ??ycia</stats><br><li><passive>Linia ??ycia:</passive> Po otrzymaniu obra??e??, kt??re zmniejszy??yby twoje zdrowie do poziomu ni??szego ni?? 30%, zyskujesz tarcz??. Dodatkowo zyskujesz obra??enia od ataku.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Obra??enia od ataku i zdrowie.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6673.png', 3400, 2380);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6675, 'Szybkie Ostrza Navori', '<mainText><stats><attention>60 pkt.</attention> obra??e?? od ataku<br><attention>20%</attention> szansy na trafienie krytyczne<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Transcendencja:</passive> Je??li masz co najmniej 60% szansy na trafienie krytyczne, twoje ataki skracaj?? czasy odnowienia wszystkich twoich umiej??tno??ci z wyj??tkiem superumiej??tno??ci.<li><passive>Ulotno????:</passive> Twoje umiej??tno??ci zadaj?? zwi??kszone obra??enia w zale??no??ci od szansy na trafienie krytyczne.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6675.png', 3400, 2380);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6676, 'Kolekcjoner', '<mainText><stats><attention>55 pkt.</attention> obra??e?? od ataku<br><attention>20%</attention> szansy na trafienie krytyczne<br><attention>12 pkt.</attention> destrukcji</stats><br><li><passive>??mier?? i Podatki:</passive> Zadawanie obra??e??, kt??re pozostawiaj?? wrogich bohater??w z mniejszym poziomem zdrowia ni?? 5%, zabija ich. Zab??jstwa bohater??w zapewniaj?? 25 szt. dodatkowego z??ota.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6676.png', 3000, 2100);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6677, 'Gniewon????', '<mainText><stats><attention>25%</attention> pr??dko??ci ataku</stats><br><li><passive>Gniew:</passive> Twoja szansa na trafienie krytyczne jest zmieniana w obra??enia <OnHit>przy trafieniu</OnHit>. Zyskujesz <physicalDamage>35 pkt. obra??e?? fizycznych</physicalDamage> <OnHit>przy trafieniu</OnHit> za ka??de zmienione 20% szansy na trafienie krytyczne</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6677.png', 800, 560);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6691, 'Mroczne Ostrze Draktharru', '<mainText><stats><attention>60 pkt.</attention> obra??e?? od ataku<br><attention>18 pkt.</attention> destrukcji<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Nocny Drapie??ca:</passive> Trafienie wroga zadaje dodatkowe obra??enia. Je??li obra??enia zosta??y zadane przez bohatera walcz??cego w zwarciu, ten atak dodatkowo <status>spowolni</status> cel.  Gdy zginie bohater, kt??ry otrzyma?? od ciebie obra??enia w ci??gu ostatnich 3 sek., czas odnowienia od??wie??y si?? i zyskasz <keywordStealth>niewidzialno????</keywordStealth>.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Przyspieszenie umiej??tno??ci i pr??dko???? ruchu.<br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6691.png', 3100, 2170);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6692, 'Za??mienie', '<mainText><stats><attention>60 pkt.</attention> obra??e?? od ataku<br><attention>12 pkt.</attention> destrukcji<br><attention>7%</attention> wszechwampiryzmu</stats><br><br><li><passive>Wiecznie Wschodz??cy Ksi????yc:</passive> Trafienie bohatera 2 r????nymi atakami lub umiej??tno??ciami w ci??gu 1.5 sek. zadaje dodatkowo obra??enia, zapewnia pr??dko???? ruchu oraz tarcz??.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Przebicie pancerza i pr??dko???? ruchu.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6692.png', 3100, 2170);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6693, 'Szpon Ciemnego Typa', '<mainText><stats><attention>60 pkt.</attention> obra??e?? od ataku<br><attention>18 pkt.</attention> destrukcji<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><br><active>U??ycie ???</active> <active>Piaskowe Machni??cie:</active> Doskakujesz przez wybranego wrogiego bohatera, zadaj??c mu obra??enia. Zadajesz wi??ksze obra??enia celowi.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Destrukcj?? i pr??dko???? ruchu.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6693.png', 3100, 2170);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6694, 'Uraza Seryldy', '<mainText><stats><attention>45 pkt.</attention> obra??e?? od ataku<br><attention>30%</attention> przebicia pancerza<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Przenikliwe Zimno:</passive> Umiej??tno??ci zadaj??ce obra??enia <status>spowalniaj??</status> wrog??w.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6694.png', 3200, 2240);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6695, 'W????owy Kie??', '<mainText><stats><attention>55 pkt.</attention> obra??e?? od ataku<br><attention>12 pkt.</attention> destrukcji</stats><br><li><passive>??upie??ca Tarcz:</passive> Zadawanie obra??e?? wrogim bohaterom obni??a warto???? na??o??onych na nich tarcz. Gdy zadajesz obra??enia wrogowi, kt??ry nie jest dotkni??ty efektem ??upie??cy Tarcz, obni??asz warto???? na??o??onych na niego tarcz.<br><br>Efektywno???? tego przedmiotu jest r????na w przypadku bohater??w walcz??cych w zwarciu i z dystansu.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6695.png', 2600, 1820);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(6696, 'Aksjomatyczny ??uk', '<mainText><stats><attention>55 pkt.</attention> obra??e?? od ataku<br><attention>18 pkt.</attention> destrukcji<br><attention>25</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Fluktuacja:</passive> Przywraca 20% ca??kowitego czasu odnowienia twojej superumiej??tno??ci za ka??dym razem, gdy wrogi bohater zginie w ci??gu 3 sek. od zadania mu przez ciebie obra??e??.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/6696.png', 3000, 2100);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7000, 'Szpon Piaskowej Dzier??by', '<mainText><stats><ornnBonus>75 pkt.</ornnBonus> obra??e?? od ataku<br><ornnBonus>26 pkt.</ornnBonus> destrukcji<br><ornnBonus>25 jedn.</ornnBonus> przyspieszenia umiej??tno??ci</stats><br><br><active>U??ycie ???</active> <active>Piaskowe Machni??cie:</active> Doskakujesz przez wybranego wrogiego bohatera, zadaj??c mu obra??enia. Zadajesz wi??ksze obra??enia celowi.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Destrukcj?? i pr??dko???? ruchu.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7000.png', 3100, 2170);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7001, 'Syzygium', '<mainText><stats><ornnBonus>80 pkt.</ornnBonus> obra??e?? od ataku<br><ornnBonus>20 pkt.</ornnBonus> destrukcji<br><ornnBonus>8%</ornnBonus> wszechwampiryzmu</stats><br><br><li><passive>Wiecznie Wschodz??cy Ksi????yc:</passive> Trafienie bohatera 2 r????nymi atakami lub umiej??tno??ciami w ci??gu 1.5 sek. zadaje dodatkowo obra??enia, zapewnia pr??dko???? ruchu oraz tarcz??.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Przebicie pancerza i pr??dko???? ruchu.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7001.png', 3100, 2170);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7002, 'Cieniotw??rca Draktharru', '<mainText><stats><ornnBonus>75 pkt.</ornnBonus> obra??e?? od ataku<br><ornnBonus>26 pkt.</ornnBonus> destrukcji<br><ornnBonus>25 jedn.</ornnBonus> przyspieszenia umiej??tno??ci</stats><br><li><passive>Nocny Drapie??ca:</passive> Trafienie wroga zadaje dodatkowe obra??enia. Je??li obra??enia zosta??y zadane przez bohatera walcz??cego w zwarciu, ten atak dodatkowo <status>spowolni</status> cel.  Gdy zginie bohater, kt??ry otrzyma?? od ciebie obra??enia w ci??gu ostatnich 3 sek., czas odnowienia od??wie??y si?? i zyskasz <keywordStealth>niewidzialno????</keywordStealth>.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Przyspieszenie umiej??tno??ci i pr??dko???? ruchu.<br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7002.png', 3100, 2170);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7005, 'Zamarzni??ta Pi??????', '<mainText><stats><ornnBonus>550 pkt.</ornnBonus> zdrowia<br><ornnBonus>70 pkt.</ornnBonus> pancerza<br><ornnBonus>25 jedn.</ornnBonus> przyspieszenia umiej??tno??ci</stats><br><li><passive>Czaroostrze:</passive> Po u??yciu umiej??tno??ci nast??pny atak jest wzmocniony: zadaje dodatkowe obra??enia i tworzy pole lodowe na 2.5 sek. Wrogowie, kt??rzy przejd?? przez pole, zostan?? <status>spowolnieni</status>. G????wny cel zostaje os??abiony, co nak??ada na niego o 100% wi??ksze spowolnienie i zmniejsza zadawane ci przez niego obra??enia o 10% na 2.5 sek. (1.5sek. ).<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom <attention>50 pkt. zdrowia</attention>, <attention>5%</attention> nieust??pliwo??ci i <attention>5%</attention> odporno??ci na spowolnienia.<br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7005.png', 3000, 2100);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7006, 'Tajfun', '<mainText><stats><ornnBonus>80 pkt.</ornnBonus> obra??e?? od ataku<br><ornnBonus>35%</ornnBonus> pr??dko??ci ataku<br><attention>20%</attention> szansy na trafienie krytyczne</stats><br><br><active>U??ycie ???</active> <active>Urwanie Chmury:</active> Doskakujesz w wybranym kierunku, wystrzeliwuj??c 3 pociski w stron?? wroga o najni??szym poziomie zdrowia w pobli??u miejsca docelowego. Zadaje obra??enia, kt??re zostaj?? zwi??kszone przeciwko celom o niskim poziomie zdrowia.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Pr??dko???? ruchu.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7006.png', 3400, 2380);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7007, 'Po??wi??cenie W????owej Ofiary', '<mainText><stats><ornnBonus>85 pkt.</ornnBonus> obra??e?? od ataku<br><ornnBonus>40%</ornnBonus> pr??dko??ci ataku<br><attention>20%</attention> szansy na trafienie krytyczne</stats><br><li><passive>Powalenie:</passive> Ka??dy co trzeci atak zadaje dodatkowe obra??enia nieuchronne.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Pr??dko???? ataku.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7007.png', 3400, 2380);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7008, 'Krwiochron', '<mainText><stats><ornnBonus>65 pkt.</ornnBonus> obra??e?? od ataku<br><ornnBonus>30%</ornnBonus> pr??dko??ci ataku<br><attention>20%</attention> szansy na trafienie krytyczne<br><ornnBonus>8%</ornnBonus> kradzie??y ??ycia</stats><br><li><passive>Linia ??ycia:</passive> Po otrzymaniu obra??e??, kt??re zmniejszy??yby twoje zdrowie do poziomu ni??szego ni?? 30%, zyskujesz tarcz??. Dodatkowo zyskujesz obra??enia od ataku.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Obra??enia od ataku i zdrowie.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7008.png', 3400, 2380);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7009, 'Kl??twa Icathii', '<mainText><stats><ornnBonus>90 pkt.</ornnBonus> mocy umiej??tno??ci<br><ornnBonus>450 pkt.</ornnBonus> zdrowia<br><ornnBonus>20 jedn.</ornnBonus> przyspieszenia umiej??tno??ci<br><ornnBonus>8%</ornnBonus> wszechwampiryzmu</stats><br><li><passive>Spaczenie Pustki:</passive> Za ka??d?? sekund?? zadawania obra??e?? wrogim bohaterom zadajesz dodatkowe obra??enia. Przy maksymalnej warto??ci dodatkowe obra??enia zostaj?? zadane jako <trueDamage>obra??enia nieuchronne</trueDamage>. <br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Wszechwampiryzm i moc umiej??tno??ci.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7009.png', 3200, 2240);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7010, 'Vesperia??ski Przyp??yw', '<mainText><stats><ornnBonus>120 pkt.</ornnBonus> mocy umiej??tno??ci<br><ornnBonus>400 pkt.</ornnBonus> zdrowia<br><ornnBonus>30 jedn.</ornnBonus> przyspieszenia umiej??tno??ci</stats><br><li><passive>Rozerwanie Duszy:</passive> Zadawanie obra??e?? bohaterowi zadaje dodatkowe obra??enia magiczne i zapewnia ci pr??dko???? ruchu.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Przyspieszenie umiej??tno??ci.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7010.png', 3200, 2240);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7011, 'Ulepszony Aeropak', '<mainText><stats><ornnBonus>120 pkt.</ornnBonus> mocy umiej??tno??ci<br><ornnBonus>10 pkt.</ornnBonus> przebicia odporno??ci na magi??<br><ornnBonus>350 pkt.</ornnBonus> zdrowia<br><ornnBonus>20 jedn.</ornnBonus> przyspieszenia umiej??tno??ci</stats><br><br><active>U??ycie ???</active><active>Ponadd??wi??kowo????:</active> Doskakujesz w wybranym kierunku, wystrzeliwuj??c ??uk magicznych pocisk??w, kt??re zadaj?? obra??enia. Nast??pnie, gdy poruszasz si?? w kierunku wrogiego bohatera, zyskujesz dodatkow?? pr??dko???? ruchu.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Przebicie odporno??ci na magi??.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7011.png', 3200, 2240);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7012, 'Lament Liandry''ego', '<mainText><stats><ornnBonus>110 pkt.</ornnBonus> mocy umiej??tno??ci<br><ornnBonus>800 pkt.</ornnBonus> many<br><ornnBonus>25 jedn.</ornnBonus> przyspieszenia umiej??tno??ci</stats><br><li><passive>Agonia:</passive> Zadaje dodatkowe obra??enia magiczne bohaterom w zale??no??ci od dodatkowego zdrowia celu.<li><passive>Udr??ka:</passive> Zadawanie obra??e?? umiej??tno??ciami podpala wrog??w na okre??lony czas.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Przyspieszenie umiej??tno??ci.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7012.png', 3200, 2240);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7013, 'Oko Luden', '<mainText><stats><ornnBonus>100 pkt.</ornnBonus> mocy umiej??tno??ci<br><ornnBonus>10 pkt.</ornnBonus> przebicia odporno??ci na magi??<br><ornnBonus>800 pkt.</ornnBonus> many<br><ornnBonus>25 jedn.</ornnBonus> przyspieszenia umiej??tno??ci</stats><br><li><passive>Echo:</passive> Umiej??tno??ci zadaj??ce obra??enia zadaj?? obra??enia magiczne celowi i 3 pobliskim wrogom oraz zapewniaj?? ci pr??dko???? ruchu. Zadawanie obra??e?? bohaterom za pomoc?? umiej??tno??ci skraca czas odnowienia tego przedmiotu.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Przebicie odporno??ci na magi??. </mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7013.png', 3200, 2240);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7014, 'Wieczna Zima', '<mainText><stats><ornnBonus>90 pkt.</ornnBonus> mocy umiej??tno??ci<br><ornnBonus>350 pkt.</ornnBonus> zdrowia<br><ornnBonus>800 pkt.</ornnBonus> many<br><ornnBonus>25 jedn.</ornnBonus> przyspieszenia umiej??tno??ci</stats><br><br><active>U??ycie ???</active> <active>Oblodzenie:</active> Zadaje obra??enia w sto??ku, <status>spowalniaj??c</status> trafionych wrog??w. Wrogowie znajduj??cy si?? w centrum sto??ka zostaj?? <status>unieruchomieni</status>.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Moc umiej??tno??ci. <br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7014.png', 2800, 1960);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7015, 'Nieustaj??cy G????d', '<mainText><stats><ornnBonus>70 pkt.</ornnBonus> obra??e?? od ataku<br><ornnBonus>450 pkt.</ornnBonus> zdrowia<br><ornnBonus>25 jedn.</ornnBonus> przyspieszenia umiej??tno??ci<br><ornnBonus>12%</ornnBonus> wszechwampiryzmu</stats><br><br><active>U??ycie ???</active> <active>Spragnione Ci??cie:</active> Zadaje obra??enia pobliskim wrogom. Przywracasz sobie zdrowie za ka??dego trafionego bohatera.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Przyspieszenie umiej??tno??ci.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7015.png', 3300, 2310);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7016, 'Niszczyciel Marze??', '<mainText><stats><ornnBonus>60 pkt.</ornnBonus> obra??e?? od ataku<br><ornnBonus>30%</ornnBonus> pr??dko??ci ataku<br><ornnBonus>400 pkt.</ornnBonus> zdrowia<br><ornnBonus>25 jedn.</ornnBonus> przyspieszenia umiej??tno??ci</stats><br> <br><active>U??ycie ???</active><active>Zatrzymuj??ce Ci??cie:</active> Zadaje obra??enia pobliskim wrogom, <status>spowalniaj??c</status> ich. Mo??e zosta?? u??yte w ruchu.<br><li><passive>Heroiczny Krok:</passive> Zadawanie obra??e?? fizycznych zapewnia pr??dko???? ruchu.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Pr??dko???? ruchu.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7016.png', 3300, 2310);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7017, 'Bogob??jca', '<mainText><stats><ornnBonus>60 pkt.</ornnBonus> obra??e?? od ataku<br><ornnBonus>450 pkt.</ornnBonus> zdrowia<br><ornnBonus>25 jedn.</ornnBonus> przyspieszenia umiej??tno??ci</stats><li><passive>Czaroostrze:</passive> Tw??j nast??pny atak po u??yciu umiej??tno??ci jest wzmocniony i zadaje dodatkowe obra??enia <OnHit>przy trafieniu</OnHit>. Je??li cel jest bohaterem, uleczysz si??.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Przebicie pancerza i przebicie odporno??ci na magi??.<br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7017.png', 3300, 2310);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7018, 'Moc Niesko??czono??ci', '<mainText><stats><ornnBonus>45 pkt.</ornnBonus> obra??e?? od ataku<br><ornnBonus>40%</ornnBonus> pr??dko??ci ataku<br><ornnBonus>400 pkt.</ornnBonus> zdrowia<br><ornnBonus>25 jedn.</ornnBonus> przyspieszenia umiej??tno??ci</stats><br><li><passive>Potr??jne Uderzenie:</passive> Ataki zapewniaj?? pr??dko???? ruchu. Je??li cel jest bohaterem, zwi??kszasz swoje podstawowe obra??enia od ataku. Ten efekt kumuluje si??.<li><passive>Czaroostrze:</passive> Po u??yciu umiej??tno??ci nast??pny atak podstawowy jest wzmocniony i zadaje dodatkowe obra??enia.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Obra??enia od ataku, przyspieszenie umiej??tno??ci i pr??dko???? ruchu.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7018.png', 3333, 2333);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7019, 'Relikwiarz Z??otej Jutrzenki', '<mainText><stats><ornnBonus>400 pkt.</ornnBonus> zdrowia<br><ornnBonus>25 jedn.</ornnBonus> przyspieszenia umiej??tno??ci<br><ornnBonus>40 pkt.</ornnBonus> pancerza<br><ornnBonus>40 pkt.</ornnBonus> odporno??ci na magi??</stats><br> <br><active>U??ycie ???</active><active>Oddanie:</active> Zapewniasz pobliskim sojusznikom <shield>tarcz??</shield>, kt??ra z czasem zanika.<br><li><passive>Konsekracja:</passive> Zapewnia pobliskim sojuszniczym bohaterom pancerz i <scaleMR>odporno???? na magi??</scaleMR>. <br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Dodatkowy pancerz i odporno???? na magi?? do efektu <passive>Konsekracji</passive>.<br><br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7019.png', 2500, 1750);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7020, 'Rekwiem Shurelyi', '<mainText><stats><ornnBonus>70 pkt.</ornnBonus> mocy umiej??tno??ci<br><ornnBonus>300 pkt.</ornnBonus> zdrowia<br><ornnBonus>25 jedn.</ornnBonus> przyspieszenia umiej??tno??ci<br><ornnBonus>200%</ornnBonus> podstawowej regeneracji many</stats><br><br><active>U??ycie ???</active> <active>Inspiracja:</active> Zapewnia pobliskim sojusznikom pr??dko???? ruchu.<li><passive>Motywacja:</passive> Wzmocnienie lub ochronienie innego sojuszniczego bohatera zapewni obu sojusznikom pr??dko???? ruchu.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Przyspieszenie umiej??tno??ci.<br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7020.png', 2500, 1750);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7021, 'Miotacz Gwiazd', '<mainText><stats><ornnBonus>70 pkt.</ornnBonus> mocy umiej??tno??ci<br><ornnBonus>300 pkt.</ornnBonus> zdrowia<br><ornnBonus>25 jedn.</ornnBonus> przyspieszenia umiej??tno??ci<br><ornnBonus>200%</ornnBonus> podstawowej regeneracji many</stats><br><li><passive>??aska Gwiazd:</passive> Trafianie bohater??w atakami lub umiej??tno??ciami podczas walki przywraca zdrowie najpowa??niej zranionemu sojusznikowi w pobli??u. Ka??da sekunda sp??dzona w walce z bohaterami zwi??ksza twoj?? si???? leczenia i tarcz.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom zwi??kszenie leczenia <passive>??aski Gwiazd</passive>.<br><br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7021.png', 2500, 1750);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7022, 'Siedzisko Dow??dcy', '<mainText><stats><ornnBonus>70 pkt.</ornnBonus> mocy umiej??tno??ci<br><ornnBonus>300 pkt.</ornnBonus> zdrowia<br><ornnBonus>25 jedn.</ornnBonus> przyspieszenia umiej??tno??ci<br><ornnBonus>200%</ornnBonus> podstawowej regeneracji many</stats><br><li><passive>Skoordynowany Ogie??:</passive> Umiej??tno??ci, kt??re <status>spowalniaj??</status> lub <status>unieruchamiaj??</status> bohatera, zadaj?? mu dodatkowe obra??enia i oznaczaj?? go. Zadane przez sojusznika obra??enia detonuj?? te oznaczenie, zadaj??c dodatkowe obra??enia i zapewniaj??c wam pr??dko???? ruchu. <br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Moc umiej??tno??ci. <br></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7022.png', 2500, 1750);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7023, 'R??wnonoc', '<mainText><stats><ornnBonus>400 pkt.</ornnBonus> zdrowia<br><ornnBonus>25 jedn.</ornnBonus> przyspieszenia umiej??tno??ci<br><ornnBonus>40 pkt.</ornnBonus> pancerza<br><ornnBonus>40 pkt.</ornnBonus> odporno??ci na magi??</stats><br><li><passive>Iskrzenie:</passive> Po <status>unieruchomieniu</status> bohater??w lub gdy bohater sam zostanie <status>unieruchomiony</status>, zwi??ksza obra??enia otrzymywane przez cel i wszystkich pobliskich wrogich bohater??w.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom <attention> Pancerz i odporno???? na magi??</attention></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7023.png', 2500, 1750);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7024, 'Cezura', '<mainText><stats><ornnBonus>90 pkt.</ornnBonus> mocy umiej??tno??ci<br><ornnBonus>350 pkt.</ornnBonus> zdrowia<br><ornnBonus>800 pkt.</ornnBonus> many<br><ornnBonus>25 jedn.</ornnBonus> przyspieszenia umiej??tno??ci</stats><br><li><passive>Boska Os??ona:</passive> Zapewnia <keywordMajor>Os??on??</keywordMajor>, kt??ra zmniejsza obra??enia otrzymywane od bohater??w. <keywordMajor>Os??ona</keywordMajor> utrzymuje si?? przez 1.5 sek. po otrzymaniu obra??e?? od bohater??w. <li><passive>Boski Dar:</passive> Podczas utrzymywania si?? <keywordMajor>Os??ony</keywordMajor> i przez 3 sek. po jej zniszczeniu zyskujesz dodatkow?? moc umiej??tno??ci. <br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom Pr??dko???? ruchu i moc umiej??tno??ci.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7024.png', 2800, 1960);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7025, 'Lewiatan', '<mainText><stats><ornnBonus>1050 pkt.</ornnBonus> zdrowia<br><ornnBonus>300%</ornnBonus> podstawowej regeneracji zdrowia<br><ornnBonus>25 jedn.</ornnBonus> przyspieszenia umiej??tno??ci</stats><br><li><passive>Kolosalna Konsumpcja:</passive> Przygotuj pot????ny atak przeciwko bohaterowi przez 3 sek., znajduj??c si?? w promieniu 700 jedn. od niego. Na??adowany atak zadaje dodatkowe obra??enia fizyczne r??wne 125 pkt. + <scalehealth>6%</scalehealth> twojego maks. zdrowia i zapewnia ci 10% tej warto??ci w formie trwa??ego maks. zdrowia. (30 sek.) czasu odnowienia na cel.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom <attention>??1%</attention> wi??cej zdrowia i <attention>6%</attention> rozmiaru bohatera.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7025.png', 3200, 2240);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7026, 'Nieopisany Paso??yt', '<mainText><stats><ornnBonus>550 pkt.</ornnBonus> zdrowia<br><ornnBonus>40 pkt.</ornnBonus> pancerza<br><ornnBonus>40 pkt.</ornnBonus> odporno??ci na magi??<br><ornnBonus>25 jedn.</ornnBonus> przyspieszenia umiej??tno??ci</stats><br><li><passive>Wytrzyma??o???? Dzieci Pustki:</passive> Za ka??d?? sekund?? w walce z bohaterami zyskujesz ??adunek zapewniaj??cy 2 pkt. <scaleArmor>pancerza</scaleArmor> i <scaleMR>odporno??ci na magi??</scaleMR>. Maksymalna liczba ??adunk??w: 8. Po osi??gni??ciu maksymalnej liczby ??adunk??w przedmiot zostaje wzmocniony, natychmiast czerpi??c zdrowie od pobliskich wrog??w, zadaj??c im 0 pkt. obra??e?? magicznych i lecz??c ci?? o tak?? sam?? warto????, oraz zwi??ksza tw??j dodatkowy pancerz i odporno???? na magi?? o 20% do ko??ca walki.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom <attention>5 pkt.pancerza i odporno??ci na magi??</attention>.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7026.png', 3200, 2240);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7027, 'Przedwieczny Brzask', '<mainText><stats><ornnBonus>550 pkt.</ornnBonus> zdrowia<br><ornnBonus>40 pkt.</ornnBonus> pancerza<br><ornnBonus>40 pkt.</ornnBonus> odporno??ci na magi??<br><ornnBonus>25 jedn.</ornnBonus> przyspieszenia umiej??tno??ci</stats><br><li><passive>Przewodnie ??wiat??o:</passive> Po u??yciu superumiej??tno??ci zyskujesz Transcendencj??, zwi??kszaj??c swoje maks. zdrowie o 10% na 9 sek. Podczas Transcendencji ty i twoi sojusznicy znajduj??cy si?? w zasi??gu 1200 jedn. zyskujecie 20 jedn. przyspieszenia podstawowych umiej??tno??ci i leczycie si?? o 2% swojego maks. zdrowia co 3 sek. Efekt zostaje zwi??kszony o do 100% zale??nie od brakuj??cego zdrowia bohatera (60sek. czasu odnowienia).<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom <attention>100 pkt.</attention> zdrowia.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7027.png', 3000, 2100);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7028, 'Niesko??czona Konwergencja', '<mainText><stats><ornnBonus>80 pkt.</ornnBonus> mocy umiej??tno??ci<br><ornnBonus>550 pkt.</ornnBonus> zdrowia<br><ornnBonus>550 pkt.</ornnBonus> many</stats><br><br>Przedmiot co 60 sek. zyskuje 20 pkt. zdrowia, 20 pkt. many i 4 pkt. mocy umiej??tno??ci, maksymalnie 10 razy. Maksymalnie mo??na zyska?? 200 pkt. zdrowia, 200 pkt. many i 40 pkt. mocy umiej??tno??ci. Po uzyskaniu maksymalnej liczby ??adunk??w zyskujesz poziom, a wszystkie efekty Wieczno??ci zostaj?? zwi??kszone o 50%.<br><li><passive>Wieczno????:</passive> Przywraca man?? r??wn?? warto??ci 7% czystych obra??e?? otrzymanych od bohater??w oraz zdrowie r??wne 25% zu??ytej many, maks. 20 pkt. zdrowia na u??ycie, na sekund??. Za ka??de przywr??cone w ten spos??b 200 pkt. zdrowia lub many zyskujesz <speed>35% zanikaj??cej pr??dko??ci ruchu</speed> na 3 sek.<br><br><rarityMythic>Mityczne bierne:</rarityMythic> Zapewnia wszystkim pozosta??ym <rarityLegendary>legendarnym</rarityLegendary> przedmiotom <attention>5 jedn. przyspieszenia umiej??tno??ci.</attention></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7028.png', 2800, 1960);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(7050, 'Gangplank Placeholder', '', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/7050.png', 0, 0);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(8001, '??a??cuchy Zguby', '<mainText><stats><attention>650 pkt.</attention> zdrowia<br><attention>20</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><br><active>U??ycie ???</active> <active>Przysi??ga:</active> Wybierz arcywroga, aby zacz???? kumulowa?? ??adunki Wendety (90 sek.).<br><li><passive>Wendeta:</passive> Otrzymuj mniejsze obra??enia od swojego arcywroga za ka??dy ??adunek Wendety. Z czasem otrzymujesz kolejne ??adunki, a?? osi??gniesz ich maksymaln?? liczb?? po 60 sekundach.<li><passive>Zemsta:</passive> Je??li posiadasz maksymaln?? liczb?? ??adunk??w, tw??j arcywr??g ma mniejsz?? nieust??pliwo????, gdy znajduje si?? w pobli??u ciebie.<br><br><rules>Mo??e zosta?? u??yte, gdy bohater jest martwy i ma globalny zasi??g. Po wybraniu nowego celu tracisz ??adunki. Nie mo??na u??y?? przez 15 sekund w trakcie walki przeciwko bohaterom.</rules><br><br><flavorText>???Przysi??g??a, ??e po??wi??ci swoje ??ycie, by go unicestwi?? ??? r??kawice jej wys??ucha??y???.</flavorText></mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/8001.png', 2500, 1750);
INSERT INTO przedmioty(id_przed, nazwa, statystyki, ikona, cena, wartosc_sprzedazy) VALUES(8020, 'Maska Otch??ani', '<mainText><stats><attention>500 pkt.</attention> zdrowia<br><attention>300 pkt.</attention> many<br><attention>40 pkt.</attention> odporno??ci na magi??<br><attention>10</attention> jedn. przyspieszenia umiej??tno??ci</stats><br><li><passive>Wieczno????:</passive> Przywraca man?? r??wn?? warto??ci 7% czystych obra??e?? otrzymanych od bohater??w oraz zdrowie r??wne 25% zu??ytej many, maksymalnie 20 pkt. zdrowia na u??ycie, na sekund??.<li><passive>Zatracenie:</passive> Nak??ada <status>kl??tw??</status> na pobliskich wrogich bohater??w, zmniejszaj??c ich odporno???? na magi??. Za ka??dego <status>przekl??tego</status> wroga zyskujesz odporno???? na magi??.</mainText><br>', 'http://ddragon.leagueoflegends.com/cdn/13.1.1/img/item/8020.png', 3000, 2100);

INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3158, 1001);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3006, 1001);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3009, 1001);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3020, 1001);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3047, 1001);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3111, 1001);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3117, 1001);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3114, 1004);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4642, 1004);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3109, 1006);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3801, 1006);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3075, 1011);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3084, 1011);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3083, 1011);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3116, 1011);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3143, 1011);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3748, 1011);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4637, 1011);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(8001, 1011);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3124, 1018);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6676, 1018);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3086, 1018);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3031, 1018);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3036, 1018);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3072, 1018);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3095, 1018);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3139, 1018);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3508, 1018);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6671, 1018);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6672, 1018);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6673, 1018);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6675, 1018);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3115, 1026);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3116, 1026);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6655, 1026);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3135, 1026);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3152, 1026);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3165, 1026);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4633, 1026);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4637, 1026);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6657, 1026);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3024, 1027);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3803, 1027);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3802, 1027);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6035, 1028);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6609, 1028);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(1011, 1028);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3066, 1028);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3067, 1028);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3803, 1028);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3044, 1028);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3053, 1028);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3211, 1028);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3814, 1028);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3119, 1028);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6664, 1028);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6665, 1028);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3145, 1028);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3165, 1028);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3742, 1028);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3748, 1028);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3801, 1028);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4401, 1028);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4629, 1028);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4635, 1028);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6660, 1028);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6667, 1028);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(1031, 1029);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3082, 1029);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3076, 1029);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3193, 1029);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3191, 1029);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3024, 1029);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3047, 1029);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3105, 1029);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3068, 1031);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3026, 1031);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3742, 1031);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6333, 1031);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6662, 1031);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3091, 1033);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(1057, 1033);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3193, 1033);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3105, 1033);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3211, 1033);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3111, 1033);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3140, 1033);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3155, 1033);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4632, 1033);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3071, 1036);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(1053, 1036);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3004, 1036);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3179, 1036);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3035, 1036);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3044, 1036);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3046, 1036);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3051, 1036);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3814, 1036);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3123, 1036);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3133, 1036);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3134, 1036);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3155, 1036);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6670, 1036);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6692, 1036);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6035, 1037);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3077, 1037);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3091, 1037);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6676, 1037);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3031, 1037);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3053, 1037);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3139, 1037);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3153, 1037);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6029, 1037);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3181, 1037);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6333, 1037);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6671, 1037);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6672, 1037);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6675, 1037);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6695, 1037);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3026, 1038);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3031, 1038);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3072, 1038);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3095, 1038);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3161, 1038);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4403, 1038);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(1043, 1042);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3124, 1042);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6677, 1042);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3085, 1042);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(2015, 1042);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3086, 1042);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3006, 1042);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3051, 1042);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6670, 1042);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3115, 1043);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3153, 1043);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6616, 1052);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3191, 1052);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3108, 1052);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3113, 1052);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3115, 1052);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3116, 1052);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3145, 1052);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3152, 1052);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3504, 1052);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3802, 1052);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4632, 1052);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3916, 1052);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4630, 1052);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4635, 1052);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4636, 1052);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4637, 1052);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4642, 1052);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4644, 1052);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6656, 1052);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6657, 1052);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3072, 1053);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3074, 1053);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3153, 1053);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4403, 1053);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6673, 1053);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6692, 1053);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6664, 1057);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3222, 1057);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4401, 1057);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3003, 1058);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3089, 1058);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4403, 1058);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4645, 1058);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3041, 1082);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3094, 2015);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3095, 2015);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(2033, 2031);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7020, 2065);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(2420, 2419);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3157, 2419);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3026, 2419);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3026, 2420);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3157, 2420);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3157, 2421);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3026, 2421);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3006, 2422);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3047, 2422);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3020, 2422);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3158, 2422);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3111, 2422);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3117, 2422);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3009, 2422);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3157, 2423);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3026, 2423);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3157, 2424);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3026, 2424);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7023, 3001);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3050, 3024);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3110, 3024);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3036, 3035);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6694, 3035);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3053, 3044);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3181, 3044);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3078, 3051);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6631, 3051);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3091, 3051);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3078, 3057);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3100, 3057);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3508, 3057);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6632, 3057);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6662, 3057);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3742, 3066);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4401, 3066);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3065, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(2065, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3071, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3084, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3083, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6630, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6617, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3190, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3001, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3003, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3050, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3078, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3107, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3109, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3119, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6664, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6665, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3161, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4005, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4403, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4644, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6631, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6632, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6656, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6662, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6667, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(8001, 3067);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3003, 3070);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3004, 3070);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3119, 3070);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3075, 3076);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3074, 3077);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3748, 3077);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7018, 3078);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3110, 3082);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3143, 3082);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7025, 3084);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3085, 3086);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3033, 3086);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3046, 3086);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3094, 3086);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4403, 3086);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3190, 3105);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3193, 3105);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3001, 3105);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6665, 3105);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4403, 3105);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6667, 3105);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3100, 3108);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3102, 3108);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6653, 3108);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3157, 3108);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4628, 3108);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4629, 3108);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4636, 3108);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3100, 3113);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4629, 3113);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6616, 3114);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3107, 3114);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3222, 3114);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3504, 3114);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6609, 3123);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3033, 3123);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6609, 3133);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3071, 3133);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3004, 3133);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6630, 3133);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3074, 3133);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3142, 3133);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3156, 3133);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3161, 3133);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3508, 3133);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6333, 3133);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6632, 3133);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6675, 3133);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6691, 3133);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6693, 3133);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6694, 3133);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6696, 3133);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3142, 3134);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6676, 3134);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3179, 3134);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3814, 3134);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6691, 3134);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6692, 3134);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6693, 3134);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6695, 3134);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6696, 3134);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6035, 3140);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3139, 3140);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3152, 3145);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4628, 3145);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4636, 3145);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4645, 3145);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7011, 3152);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3156, 3155);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7019, 3190);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3157, 3191);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3065, 3211);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(8020, 3211);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3084, 3801);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3083, 3801);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3109, 3801);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6655, 3802);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6653, 3802);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4644, 3802);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6656, 3802);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(8020, 3803);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6657, 3803);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3011, 3916);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3165, 3916);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7022, 4005);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3135, 4630);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3102, 4632);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7009, 4633);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4633, 4635);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7010, 4636);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4643, 4638);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(2065, 4642);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6617, 4642);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3011, 4642);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(4005, 4642);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7024, 4644);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6630, 6029);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6631, 6029);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7021, 6617);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7015, 6630);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7016, 6631);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7017, 6632);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7012, 6653);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7013, 6655);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7014, 6656);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7028, 6657);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3068, 6660);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7005, 6662);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7026, 6665);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7027, 6667);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6671, 6670);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6672, 6670);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(6673, 6670);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7006, 6671);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7007, 6672);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7008, 6673);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(3124, 6677);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7002, 6691);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7001, 6692);
INSERT INTO komponenty_przedmiotow(id_przed, id_komponentu) VALUES(7000, 6693);

INSERT INTO druzyny(id_druzyny, nazwa, opis, liga, logo, zdjecie_zawodnikow) VALUES('AST','Astralis', 'Astralis is a Danish team.', 'LEC', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/2/2e/Astralislogo_profile.png', NULL);
INSERT INTO druzyny(id_druzyny, nazwa, opis, liga, logo, zdjecie_zawodnikow) VALUES('XL','Excel Esports', 'Excel Esports is a British team. Their name was previously stylized exceL eSports and later exceL Esports.', 'LEC', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/9/91/Excel_Esportslogo_square.png', NULL);
INSERT INTO druzyny(id_druzyny, nazwa, opis, liga, logo, zdjecie_zawodnikow) VALUES('FNC','Fnatic', 'Fnatic is a professional esports organization consisting of players from around the world across a variety of games. On March 14, 2011, Fnatic entered the League of Legends scene with the acquisition of myRevenge. Fnatic is one of the strongest European teams since the early days of competitive League of Legends, having been the champion of the Riot Season 1 Championship.', 'LEC', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/f/fc/Fnaticlogo_square.png', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/7/77/FNC_2023_Winter.png');
INSERT INTO druzyny(id_druzyny, nazwa, opis, liga, logo, zdjecie_zawodnikow) VALUES('G2','G2 Esports', 'G2 Esports is a European team. They were previously known as Gamers2.', 'LEC', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/7/77/G2_Esportslogo_square.png', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/9/93/G2_2022_Spring.png');
INSERT INTO druzyny(id_druzyny, nazwa, opis, liga, logo, zdjecie_zawodnikow) VALUES('KOI','KOI', 'KOI is a Spanish team formed in December 2021, founded by former LVP caster Ibai Llanos, and FC Barcelona''s player Gerard Piqu??.', 'LEC', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/a/a5/KOI_%28Spanish_Team%29logo_square.png', NULL);
INSERT INTO druzyny(id_druzyny, nazwa, opis, liga, logo, zdjecie_zawodnikow) VALUES('MAD','MAD Lions', 'MAD Lions is a Spanish team. They were previously known as Splyce. For the LVP SLO team that went by the same name, now known as MAD Lions Madrid, see here. The organization has teams in League of Legends, Clash Royale, CS:GO, and FIFA.', 'LEC', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/e/e5/MAD_Lionslogo_profile.png', NULL);
INSERT INTO druzyny(id_druzyny, nazwa, opis, liga, logo, zdjecie_zawodnikow) VALUES('SK','SK Gaming', 'SK Gaming is a German team that has been part of the esports community since 1997. The organization entered the League of Legends scene in September 2010.', 'LEC', 'https://cdn.royaleapi.com/static/img/team/logo/sk-gaming.png', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/b/b5/SK_2022_Spring.jpg');
INSERT INTO druzyny(id_druzyny, nazwa, opis, liga, logo, zdjecie_zawodnikow) VALUES('BDS','Team BDS', 'Team BDS is a Swiss esports organization, based in Geneva. The team used to compete in the LFL but bought a spot in the LEC in June 2021.', 'LEC', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/0/06/Team_BDSlogo_profile.png', NULL);
INSERT INTO druzyny(id_druzyny, nazwa, opis, liga, logo, zdjecie_zawodnikow) VALUES('HRT','Team Heretics', 'Team Heretics is a Spanish esports organization founded in August 2016 by YouTube user Jorge ''Goorgo'' Orejudo. They first entered the League of Legends scene in January 2017.', 'LEC', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/b/bf/Team_Hereticslogo_square.png', NULL);
INSERT INTO druzyny(id_druzyny, nazwa, opis, liga, logo, zdjecie_zawodnikow) VALUES('VIT','Team Vitality', 'Team Vitality is a French team.', 'LEC', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/8/86/Team_Vitalitylogo_square.png', NULL);

INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Finn', 'Finn Wiest??l', 'Sweden', 'Top Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/9/96/XL_Finn_2022_Split_2.png', '1999-06-03', 'AST');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('113', 'Do??ukan Balc??', 'Turkey', 'Jungler', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/c/ce/KC_113_2022_Split_1.png', '2004-08-12', 'AST');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Dajor', 'Oliver Ryppa', 'Germany', 'Mid Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/e/eb/AST_Dajor_2022_Split_2.png', '2003-04-18', 'AST');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Kobbe', 'Kasper Kobberup', 'Denmark', 'Bot Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/1/1d/AST_Kobbe_2022_Split_2.png', '1996-09-21', 'AST');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('JeongHoon', 'Lee Jeong-hoon', 'South Korea', 'Support', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/f/f1/AST_JeongHoon_2022_Split_2.png', '2000-02-22', 'AST');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Odoamne', 'Andrei Pascu', 'Romania', 'Top Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/1/18/RGE_Odoamne_2022_Split_2.png', '1995-01-18', 'XL');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Xerxe', 'Andrei Dragomir', 'Romania', 'Jungler', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/1/14/AST_Xerxe_2022_Split_2.png', '1999-11-05', 'XL');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Vetheo', 'Vincent Berri??', 'France', 'Mid Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/d/d9/MSF_Vetheo_2022_Split_2.png', '2002-07-26', 'XL');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Patrik', 'Patrik J??r??', 'Czech Republic', 'Bot Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/9/92/XL_Patrik_2022_Split_2.png', '2000-04-07', 'XL');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Targamas', 'Rapha??l Crabb??', 'Belgium', 'Support', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/5/51/G2_Targamas_2022_Split_2.png', '2000-06-30', 'XL');

INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Wunder', 'Martin Nordahl Hansen', 'Denmark', 'Top Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/f/f9/FNC_Wunder_2022_Split_2.png', '1998-11-09', 'FNC');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Razork', 'Iv??n Mart??n D??az', 'Spain', 'Jungler', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/2/20/FNC_Razork_2022_Split_2.png', '2000-10-07', 'FNC');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Humanoid', 'Marek Br??zda', 'Czech Republic', 'Mid Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/9/97/FNC_Humanoid_2022_Split_2.png', '2000-03-14', 'FNC');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Rekkles', 'Carl??Martin??Erik Larsson', 'Sweden', 'Bot Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/7/70/KC_Rekkles_2022_Split_2.png', '1996-09-20', 'FNC');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Rhuckz', 'R??ben Barbosa', 'Portugal', 'Support', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/b/ba/FNTQ_Rhuckz_2022_Split_2.png', '1996-08-28', 'FNC');

INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('BrokenBlade', 'Sergen ??elik', 'German', 'Top Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/f/f4/G2_BrokenBlade_2022_Split_2.png', '2000-01-19', 'G2');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Yike', 'Martin Sundelin', 'Sweden', 'Jungler', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/8/83/LDLC_Yike_2022_Split_2.png', '2000-11-11', 'G2');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Caps', 'Rasmus Borregaard Winther', 'Denmark', 'Mid Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/8/8c/G2_caPs_2022_Split_2.png', '1999-11-17', 'G2');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Hans sama', 'Steven Liv', 'France', 'Bot Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/d/d4/TL_Hans_sama_2022_Split_2.png', '1999-09-02', 'G2');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Mikyx', 'Mihael Mehle', 'Slovenia', 'Support', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/e/ee/XL_Mikyx_2022_Split_2.png', '1998-11-02', 'G2');

INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Szygenda', 'Mathias Jensen', 'Denmark', 'Top Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/0/09/VIT.B_Szygenda_2022_Split_2.png', '2001-04-14', 'KOI');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Malrang', 'Kim Geun-seong', 'South Korea', 'Jungler', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/e/e1/RGE_Malrang_2022_Split_2.png', '2000-02-09', 'KOI');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Larssen', 'Emil Larsson', 'Sweden', 'Mid Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/9/94/RGE_Larssen_2022_Split_2.png', '2000-03-30', 'KOI');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Comp', 'Markos Stamkopoulos (???????????? ????????????????????????)', 'Greece', 'Bot Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/1/13/RGE_Comp_2022_Split_2.png', '2001-12-20', 'KOI');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Trymbi', 'Adrian Trybus', 'Poland', 'Support', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/2/21/RGE_Trymbi_2022_Split_2.png', '2000-10-20', 'KOI');

INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Chasy', 'Kim Dong-hyeon', 'South Korea', 'Top Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/f/f0/X7_Chasy_2022_Split_2.png', '2001-04-20', 'MAD');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Elyoya', 'Javier Prades Batalla', 'Spain', 'Jungler', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/0/0f/MAD_Elyoya_2022_Split_2.png', '2000-03-13', 'MAD');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Nisqy', 'Yasin Din??er', 'Belgium', 'Mid Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/6/61/MAD_Nisqy_2022_Split_2.png', '1998-07-28', 'MAD');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Carzzy', 'Maty???? Ors??g', 'Czech Republic', 'Bot Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/3/33/VIT_Carzzy_2022_Split_2.png', '2002-01-31', 'MAD');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Hylissang', 'Zdravets Iliev Galabov', 'Bulgaria', 'Support', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/0/04/FNC_Hylissang_2022_Split_2.png', '1995-04-30', 'MAD');

INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Irrelevant', 'Joel Miro Scharoll', 'Germany', 'Top Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/c/c8/MSF_Irrelevant_2022_Split_2.png', '2001-10-22', 'SK');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Markoon', 'Mark van Woensel', 'Netherlands', 'Jungler', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/2/2c/XL_Markoon_2022_Split_2.png', '2002-06-28', 'SK');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Sertuss', 'Daniel Gamani', 'Germany', 'Mid Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/2/2f/SK_Sertuss_2022_Split_2.png', '2001-12-23', 'SK');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Exakick', 'Thomas Foucou', 'France', 'Bot Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/3/39/LDLC_Exakick_2022_Split_2.png', '2003-09-28', 'SK');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Doss', 'Mads Schwartz', 'Denmark', 'Support', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/a/ac/LDLC_Doss_2022_Split_2.png', '1999-03-19', 'SK');

INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Adam', 'Adam Maanane', 'France', 'Top Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/3/30/BDS.A_Adam_2022_Split_2.png', '2001-12-30', 'BDS');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Sheo', 'Th??o Borile', 'France', 'Jungler', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/b/b8/BDS.A_Sheo_2022_Split_2.png', '2001-07-05', 'BDS');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('nuc', 'Ilias Bizriken', 'France', 'Mid Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/9/92/BDS_NUCLEARINT_2022_Split_2.png', '2002-10-17', 'BDS');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Crownie', 'Ju?? Maru??i??', 'Slovenia', 'Bot Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/9/95/BDS.A_Crownie_2022_Split_2.png', '1998-04-17', 'BDS');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Labrov', 'Labros Papoutsakis', 'Greece', 'Support', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/0/0b/VIT_Labrov_2022_Split_2.png', '2002-02-12', 'BDS');

INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Evi', 'Shunsuke Murase', 'Japan', 'Top Laner', 'Japan', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/e/ee/DFM_Evi_2022_Split_1.png', '1995-11-15', 'HRT');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Jankos', 'Marcin Jankowski', 'Poland', 'Jungler', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/3/31/G2_Jankos_2022_Split_2.png', '1995-07-23', 'HRT');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Ruby', 'Lee Sol-min', 'South Korea', 'Mid Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/e/e5/USE_Ruby_2022_Split_1.png', '1998-08-11', 'HRT');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Jackspektra', 'Jakob Gullvag Kepple', 'Norway', 'Bot Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/c/cc/HRTS_Jackspektra_2022_Split_2.png', '2000-12-05', 'HRT');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Mersa', 'Mertai Sari', 'Greece', 'Support', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/a/ab/MSF_Mersa_2022_Split_2.png', '2002-08-22', 'HRT');

INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Neon', 'Mat???? Jakub????k??', 'Slovakia', 'Bot Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/1/19/MSF_Neon_2022_Split_2.png', '1998-09-30', 'VIT');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Perkz', 'Luka Perkovi??', 'Croatia', 'Mid Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/3/33/VIT_Perkz_2022_Split_2.png', '1998-09-30', 'VIT');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Kaiser', 'Norman Kaiser', 'Germany', 'Support', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/e/e5/MAD_Kaiser_2022_Split_2.png', '1998-11-19', 'VIT');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Bo', 'Zhou Yang-Bo', 'China', 'Jungler', 'China', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/3/38/FPX_Bo_2021_Split_1.png', '2002-04-22', 'VIT');
INSERT INTO gracze_zawodowi(nick, imie_i_nazwisko, kraj, rola, rezydencja, zdjecie, data_urodzin, id_druzyny) VALUES('Photon', 'Kyeong Gyu-tae', 'South Korea', 'Top Laner', 'EMEA', 'https://static.wikia.nocookie.net/lolesports_gamepedia_en/images/9/9b/T1.C_Photon_2022_Split_1.png', '2001-11-30', 'VIT');

INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Summer', 'OFFLINE', '2022-08-14', 1, '12-6 RR', 'G2');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Summer', 'OFFLINE', '2022-08-14', 2, '12-6 RR', 'MAD');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Summer', 'OFFLINE', '2022-08-14', 3, '11-7 RR', 'KOI');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Summer', 'OFFLINE', '2022-08-14', 4, '10-8 RR', 'HRT');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Summer', 'OFFLINE', '2022-08-14', 5, '10-8 RR', 'FNC');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Summer', 'OFFLINE', '2022-08-14', 6, '9-9 RR', 'XL');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Summer', 'OFFLINE', '2022-08-14', 7, '9-9 RR', 'VIT');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Summer', 'OFFLINE', '2022-08-14', 8, '7-11 RR', 'SK');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Summer', 'OFFLINE', '2022-08-14', 9, '7-11 RR', 'AST');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Summer', 'OFFLINE', '2022-08-14', 10, '3-15 RR', 'BDS');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Spring', 'OFFLINE', '2022-03-06', 1, '14-4 RR', 'KOI');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Spring', 'OFFLINE', '2022-03-06', 2, '13-5 RR', 'FNC');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Spring', 'OFFLINE', '2022-03-06', 3, '12-6 RR', 'HRT');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Spring', 'OFFLINE', '2022-03-06', 4, '11-7 RR', 'G2');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Spring', 'OFFLINE', '2022-03-06', 5, '9-9 RR', 'XL');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Spring', 'OFFLINE', '2022-03-06', 6, '9-9 RR', 'VIT');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Spring', 'OFFLINE', '2022-03-06', 7, '8-10 RR', 'MAD');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Spring', 'OFFLINE', '2022-03-06', 8, '7-11 RR', 'SK');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Spring', 'OFFLINE', '2022-03-06', 9, '4-14 RR', 'BDS');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Spring', 'OFFLINE', '2022-03-06', 10, '3-15 RR', 'AST');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Summer Playoffs', 'OFFLINE', '2022-09-10', 1, '3-0 G2', 'KOI');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Summer Playoffs', 'OFFLINE', '2022-09-10', 2, '0-3 KOI', 'G2');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Summer Playoffs', 'OFFLINE', '2022-09-10', 3, '1-3 KOI', 'FNC');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Summer Playoffs', 'OFFLINE', '2022-09-10', 4, '1-3 FNC', 'MAD');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Summer Playoffs', 'OFFLINE', '2022-09-10', 5, '0-3 FNC', 'HRT');
INSERT INTO turnieje(nazwa_turnieju, rodzaj, data, zajete_miejsce, ostatni_wynik, id_druzyny) VALUES('LEC 2022 Summer Playoffs', 'OFFLINE', '2022-09-10', 6, '2-3 FNC', 'XL');

INSERT INTO gracze(nick, dywizja, poziom, ulubiony_bohater) VALUES ('Sloik', 'Platinum IV', 200, 'Quinn');
INSERT INTO gracze(nick, dywizja, poziom, ulubiony_bohater) VALUES ('Quavenox', 'Diamond IV', 300, 'Thresh');

INSERT INTO gry(rezultat, zabojstwa, smierci, asysty, creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 2, 3, 5, 192, 9900, '00:28:24', 13300,21,20, 'BLUE', 'Graves');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty, creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 4, 2, 128, 7000, '00:40:19', 3400,14,17, 'RED', 'Bel''Veth');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 2, 1, 163, 8500, '00:40:29', 5700,18,15, 'BLUE', 'Lee Sin');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 4, 3, 9, 263, 14500, '00:46:59', 15800,26,25, 'RED', 'Graves');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 1, 13, 158, 9800, '00:35:41', 8800,28,19, 'RED', 'Sejuani');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 4, 7, 147, 8600, '00:32:08', 8000,23,19, 'BLUE', 'Jarvan IV');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 4, 1, 111, 7000, '00:45:18', 4100,15,13, 'RED', 'Trundle');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 2, 5, 3, 188, 12200, '00:37:17', 9400,21,25, 'BLUE', 'Trundle');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 4, 1, 131, 8600, '00:25:34', 8400,21,15, 'BLUE', 'Jarvan IV');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 3, 7, 125, 8700, '00:43:20', 4400,26,25, 'RED', 'Trundle');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 3, 7, 192, 12100, '00:20:46', 8100,29,29, 'RED', 'Wukong');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 5, 2, 5, 156, 11400, '00:32:41', 6500,20,12, 'BLUE', 'Jarvan IV');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 4, 0, 8, 174, 12000, '00:30:07', 14300,27,22, 'RED', 'Wukong');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 5, 5, 14, 175, 14000, '00:20:19', 18400,38,36, 'BLUE', 'Wukong');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 4, 0, 138, 7200, '00:30:01', 3600,15,11, 'RED', 'Vi');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 5, 0, 16, 199, 12400, '00:30:01', 12700,42,40, 'BLUE', 'Nocturne');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 10, 1, 7, 187, 14500, '00:32:21', 18800,30,29, 'RED', 'Pantheon');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 1, 3, 12, 147, 9700, '00:44:43', 5300,27,25, 'BLUE', 'Jarvan IV');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 2, 13, 166, 12400, '00:36:07', 12900,31,25, 'BLUE', 'Trundle');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 5, 4, 12, 180, 12300, '00:47:55', 15200,34,37, 'RED', 'Pantheon');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 6, 3, 13, 159, 11500, '00:27:29', 8700,40,39, 'RED', 'Jarvan IV');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 4, 1, 138, 7700, '00:21:21', 6700,16,17, 'BLUE', 'Viego');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 3, 10, 165, 11500, '00:32:31', 13200,32,28, 'RED', 'Wukong');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 6, 2, 7, 226, 14800, '00:37:42', 18300,35,34, 'RED', 'Xin Zhao');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 4, 1, 3, 190, 12100, '00:29:28', 6800,23,22, 'BLUE', 'Viego');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 7, 2, 8, 204, 13900, '00:43:29', 18300,33,27, 'RED', 'Wukong');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 2, 5, 5, 140, 9000, '00:38:19', 7800,22,21, 'BLUE', 'Volibear');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 5, 2, 152, 9000, '00:24:11', 8400,15,18, 'BLUE', 'Trundle');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 2, 3, 4, 196, 11400, '00:35:04', 11500,19,13, 'RED', 'Volibear');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 6, 2, 13, 172, 12300, '00:24:34', 16200,36,32, 'RED', 'Wukong');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 3, 5, 4, 193, 11200, '00:36:01', 7600,29,32, 'BLUE', 'Vi');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 3, 12, 176, 11800, '00:20:41', 8700,29,25, 'BLUE', 'Volibear');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 4, 2, 11, 182, 11300, '00:20:31', 12300,36,30, 'BLUE', 'Diana');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 1, 1, 13, 195, 12500, '00:44:41', 17000,29,24, 'BLUE', 'Trundle');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 4, 3, 104, 5600, '00:37:53', 6700,19,17, 'BLUE', 'Nocturne');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 3, 4, 2, 145, 9600, '00:27:20', 5300,20,21, 'BLUE', 'Viego');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 5, 6, 112, 6400, '00:22:22', 3300,19,15, 'RED', 'Jarvan IV');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 2, 4, 222, 12100, '00:29:04', 9600,28,28, 'RED', 'Nocturne');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 4, 4, 2, 149, 9300, '00:23:07', 11800,27,22, 'BLUE', 'Wukong');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 3, 4, 2, 157, 8300, '00:39:45', 5200,25,21, 'BLUE', 'Graves');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 5, 4, 150, 8800, '00:40:17', 5100,19,17, 'RED', 'Poppy');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 3, 1, 182, 8000, '00:42:00', 2400,18,16, 'RED', 'Viego');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 3, 3, 172, 8500, '00:37:39', 5000,27,28, 'BLUE', 'Viego');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 10, 0, 5, 199, 12300, '00:37:38', 11900,33,28, 'RED', 'Graves');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 5, 2, 9, 194, 12000, '00:45:07', 9000,30,23, 'BLUE', 'Wukong');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 3, 7, 191, 12500, '00:44:30', 10500,30,30, 'BLUE', 'Wukong');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 8, 1, 7, 250, 15700, '00:42:25', 17700,36,29, 'RED', 'Diana');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 4, 1, 10, 146, 10300, '00:41:45', 8500,37,35, 'RED', 'Sejuani');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 4, 4, 8, 191, 12200, '00:25:15', 10900,29,29, 'BLUE', 'Wukong');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 8, 2, 11, 166, 11700, '00:25:29', 19700,35,29, 'BLUE', 'Nidalee');

INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 1);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 2);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 3);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 4);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 5);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 6);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 7);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 8);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 9);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 10);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 11);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 12);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 13);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 14);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 15);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 16);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 17);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 18);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 19);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 20);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 21);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 22);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 23);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 24);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 25);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 26);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 27);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 28);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 29);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 30);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 31);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 32);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 33);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 34);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 35);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 36);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 37);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 38);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 39);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 40);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 41);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 42);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 43);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 44);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 45);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 46);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 47);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 48);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 49);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Jankos', 50);


INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 4, 4, 1, 201, 9600, '00:23:29', 19400,21,20, 'BLUE', 'Akali');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 3, 0, 189, 8100, '00:41:42', 7700,17,10, 'RED', 'Swain');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 2, 1, 292, 11900, '00:30:45', 12900,22,23, 'BLUE', 'Azir');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 3, 3, 7, 296, 14500, '00:39:25', 9900,23,22, 'RED', 'Sylas');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 6, 1, 6, 223, 11600, '00:22:38', 16300,32,24, 'RED', 'Sylas');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 3, 5, 260, 9900, '00:21:37', 9100,19,14, 'BLUE', 'Seraphine');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 2, 2, 229, 9800, '00:37:30', 8500,21,13, 'RED', 'Ahri');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 3, 4, 368, 15800, '00:41:52', 19700,30,23, 'BLUE', 'Lissandra');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 3, 2, 282, 11100, '00:36:39', 16300,20,22, 'BLUE', 'Ahri');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 7, 1, 8, 236, 13100, '00:49:40', 25100,30,24, 'RED', 'Sylas');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 2, 6, 310, 13700, '00:42:51', 21700,21,21, 'RED', 'Varus');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 4, 1, 3, 294, 13700, '00:28:48', 12300,24,24, 'BLUE', 'Azir');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 0, 7, 240, 11700, '00:42:45', 8200,29,28, 'RED', 'Renekton');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 7, 4, 17, 373, 18900, '00:35:32', 41800,35,31, 'BLUE', 'Azir');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 2, 2, 229, 9500, '00:33:19', 9900,17,11, 'RED', 'Twisted Fate');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 12, 0, 12, 275, 15900, '00:33:41', 34800,36,26, 'BLUE', 'Ahri');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 0, 3, 14, 275, 13000, '00:24:47', 18700,30,28, 'RED', 'Lissandra');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 8, 0, 6, 272, 14500, '00:30:51', 22800,29,23, 'BLUE', 'Sylas');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 6, 1, 9, 305, 15700, '00:44:04', 21000,33,32, 'BLUE', 'Ahri');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 5, 3, 12, 265, 13700, '00:49:06', 18500,34,34, 'RED', 'Sylas');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 2, 14, 237, 11700, '00:29:38', 15800,32,32, 'RED', 'Sylas');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 6, 2, 202, 8700, '00:47:40', 16500,18,16, 'BLUE', 'Taliyah');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 1, 4, 6, 264, 12100, '00:45:03', 14200,23,19, 'RED', 'Swain');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 4, 0, 5, 391, 16900, '00:23:04', 16100,24,19, 'RED', 'Taliyah');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 4, 2, 1, 305, 13600, '00:41:08', 15700,23,19, 'BLUE', 'Taliyah');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 7, 5, 6, 328, 17300, '00:23:51', 30400,29,29, 'RED', 'Sylas');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 2, 7, 3, 271, 11200, '00:28:18', 26600,23,27, 'BLUE', 'Azir');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 1, 1, 374, 15900, '00:25:05', 22700,12,3, 'BLUE', 'Corki');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 4, 7, 5, 278, 15900, '00:24:12', 28600,32,30, 'RED', 'Zoe');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 5, 3, 17, 252, 13200, '00:48:27', 23800,39,34, 'RED', 'Swain');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 8, 6, 4, 301, 15100, '00:26:03', 31100,28,26, 'BLUE', 'Ahri');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 9, 1, 7, 345, 17000, '00:47:27', 27100,32,25, 'BLUE', 'Ahri');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 4, 3, 7, 241, 12000, '00:39:58', 11300,28,25, 'BLUE', 'Yasuo');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 6, 2, 4, 262, 14500, '00:33:21', 34400,27,27, 'BLUE', 'Zoe');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 6, 2, 133, 6000, '00:22:36', 9400,18,17, 'BLUE', 'Zoe');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 3, 5, 2, 270, 12100, '00:30:38', 12200,16,14, 'BLUE', 'Ahri');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 3, 4, 2, 152, 7400, '00:27:50', 5000,24,26, 'RED', 'Galio');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 5, 4, 263, 13500, '00:26:56', 10400,31,35, 'RED', 'Gwen');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 4, 1, 214, 8800, '00:42:36', 8400,15,9, 'BLUE', 'Anivia');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 2, 3, 1, 156, 7700, '00:48:47', 6500,26,28, 'BLUE', 'LeBlanc');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 2, 3, 2, 359, 15300, '00:33:46', 11700,18,12, 'RED', 'Corki');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 2, 5, 3, 195, 9100, '00:49:56', 12800,18,21, 'RED', 'LeBlanc');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 2, 3, 225, 10000, '00:32:48', 10600,21,16, 'BLUE', 'LeBlanc');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 9, 2, 8, 215, 12400, '00:41:29', 17900,38,36, 'RED', 'Ahri');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 4, 2, 9, 311, 15900, '00:31:17', 18400,37,31, 'BLUE', 'LeBlanc');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 6, 1, 12, 245, 14900, '00:45:59', 20000,42,35, 'BLUE', 'Zoe');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 4, 2, 9, 359, 17600, '00:30:47', 18400,25,26, 'RED', 'Yasuo');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 7, 0, 7, 229, 13400, '00:20:32', 16500,26,25, 'RED', 'Gwen');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 6, 2, 5, 320, 15200, '00:43:30', 32600,32,25, 'BLUE', 'Sylas');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 1, 3, 16, 150, 10400, '00:43:27', 11200,30,25, 'BLUE', 'Twisted Fate');

INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 51);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 52);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 53);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 54);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 55);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 56);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 57);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 58);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 59);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 60);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 61);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 62);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 63);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 64);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 65);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 66);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 67);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 68);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 69);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 70);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 71);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 72);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 73);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 74);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 75);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 76);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 77);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 78);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 79);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 80);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 81);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 82);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 83);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 84);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 85);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 86);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 87);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 88);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 89);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 90);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 91);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 92);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 93);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 94);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 95);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 96);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 97);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 98);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 99);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Caps', 100);

INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 3, 3, 186, 8900, '00:48:36', 14000,16,12, 'BLUE', 'Maokai');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 2, 5, 214, 9700, '00:20:37', 12600,21,20, 'BLUE', 'Maokai');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 4, 1, 227, 9800, '00:41:38', 13300,15,18, 'RED', 'Renekton');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 2, 5, 1, 184, 8800, '00:35:08', 12700,13,15, 'RED', 'Gnar');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 4, 2, 189, 8000, '00:48:34', 8000,15,15, 'RED', 'Gnar');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 2, 6, 1, 234, 10500, '00:47:38', 11600,15,12, 'RED', 'Rumble');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 4, 4, 7, 256, 12700, '00:42:16', 22700,21,22, 'BLUE', 'Gnar');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 1, 11, 237, 12000, '00:31:58', 13100,28,28, 'BLUE', 'Maokai');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 2, 5, 289, 14100, '00:40:21', 14200,24,19, 'RED', 'Ornn');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 0, 14, 215, 12900, '00:46:57', 24800,35,26, 'BLUE', 'Maokai');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 1, 1, 3, 232, 11300, '00:42:16', 11300,14,11, 'BLUE', 'Aatrox');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 4, 1, 10, 334, 17500, '00:43:20', 19600,33,26, 'RED', 'Renekton');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 4, 1, 10, 237, 12600, '00:24:26', 14400,26,25, 'RED', 'Ornn');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 1, 13, 268, 14100, '00:34:44', 14900,38,36, 'RED', 'Renekton');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 1, 8, 283, 13800, '00:41:15', 13000,30,28, 'BLUE', 'Ornn');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 4, 0, 4, 292, 15500, '00:30:32', 15100,23,22, 'BLUE', 'Renekton');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 3, 1, 236, 9900, '00:27:50', 12700,16,17, 'BLUE', 'Aatrox');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 4, 4, 184, 7400, '00:40:15', 9300,29,23, 'BLUE', 'Ornn');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 4, 4, 321, 13600, '00:43:04', 12600,16,13, 'BLUE', 'Renekton');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 4, 4, 237, 9800, '00:44:23', 9100,23,23, 'RED', 'Renekton');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 4, 6, 271, 15800, '00:47:55', 21100,24,24, 'RED', 'Gnar');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 2, 10, 178, 10100, '00:30:52', 11000,28,22, 'BLUE', 'Ornn');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 3, 2, 253, 10100, '00:25:30', 8200,19,21, 'RED', 'Renekton');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 6, 2, 6, 290, 15200, '00:49:29', 12800,28,26, 'RED', 'Renekton');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 5, 4, 297, 13400, '00:48:18', 11400,20,18, 'BLUE', 'Renekton');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 1, 12, 249, 11800, '00:35:30', 10300,35,33, 'RED', 'Ornn');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 5, 3, 260, 11500, '00:46:28', 21500,20,19, 'BLUE', 'Gwen');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 0, 12, 280, 14500, '00:40:49', 19400,31,21, 'BLUE', 'Renekton');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 2, 1, 0, 258, 11800, '00:47:40', 13600,20,15, 'RED', 'Ornn');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 1, 3, 323, 14100, '00:41:26', 16700,24,17, 'BLUE', 'Gwen');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 6, 3, 244, 10500, '00:34:33', 12100,23,26, 'RED', 'Gnar');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 6, 4, 7, 369, 19600, '00:31:51', 29500,33,33, 'BLUE', 'Gwen');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 4, 1, 296, 13400, '00:39:37', 18100,16,15, 'BLUE', 'Gnar');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 4, 2, 6, 363, 19200, '00:31:26', 37600,26,24, 'RED', 'Gangplank');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 0, 11, 284, 13400, '00:39:20', 16600,27,17, 'RED', 'Gnar');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 1, 0, 6, 279, 12600, '00:43:28', 10100,25,18, 'BLUE', 'Gwen');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 1, 6, 236, 12600, '00:35:41', 20300,22,20, 'BLUE', 'Zac');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 2, 7, 302, 15900, '00:40:08', 18800,24,16, 'RED', 'Gangplank');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 4, 2, 6, 284, 15000, '00:37:00', 24900,29,29, 'BLUE', 'Gnar');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 9, 1, 5, 331, 19500, '00:43:46', 27000,29,21, 'RED', 'Gangplank');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 0, 4, 4, 258, 12600, '00:34:30', 18900,24,19, 'RED', 'Gangplank');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 5, 2, 176, 7800, '00:24:44', 9800,19,15, 'RED', 'Ornn');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 2, 3, 251, 10600, '00:43:57', 12500,26,22, 'BLUE', 'Ornn');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 5, 4, 296, 14800, '00:27:43', 26100,26,30, 'RED', 'Jayce');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 5, 5, 285, 13200, '00:37:43', 18200,19,14, 'BLUE', 'Gwen');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 3, 4, 4, 249, 12000, '00:47:25', 20200,23,19, 'BLUE', 'Rumble');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 0, 6, 183, 9800, '00:29:21', 11400,23,15, 'RED', 'Gnar');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 1, 0, 11, 181, 9200, '00:45:14', 8700,32,31, 'RED', 'Ornn');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 4, 13, 246, 12600, '00:29:50', 22000,31,32, 'RED', 'Jayce');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 4, 5, 1, 254, 12000, '00:30:57', 13200,20,19, 'BLUE', 'Gnar');

INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 101);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 102);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 103);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 104);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 105);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 106);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 107);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 108);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 109);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 110);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 111);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 112);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 113);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 114);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 115);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 116);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 117);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 118);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 119);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 120);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 121);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 122);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 123);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 124);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 125);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 126);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 127);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 128);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 129);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 130);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 131);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 132);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 133);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 134);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 135);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 136);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 137);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 138);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 139);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 140);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 141);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 142);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 143);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 144);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 145);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 146);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 147);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 148);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 149);
INSERT INTO graczezawodowi_gry(gracze_zawodowi_nick, gry_id_meczu) VALUES('Odoamne', 150);
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 2, 5, 4, 325, 15400, '00:42:51', 22500,26,29, 'BLUE', 'Viktor');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 3, 0, 236, 9300, '00:47:20', 9000,13,8, 'RED', 'Akali');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 5, 1, 252, 12700, '00:34:12', 21800,19,14, 'BLUE', 'Azir');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 4, 5, 2, 406, 19100, '00:37:37', 43900,23,27, 'RED', 'Viktor');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 6, 1, 4, 306, 15000, '00:22:41', 26000,28,28, 'BLUE', 'Azir');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 3, 11, 205, 10900, '00:34:07', 19800,31,30, 'RED', 'Azir');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 7, 3, 5, 284, 14600, '00:31:17', 20200,27,26, 'RED', 'Ryze');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 0, 3, 6, 293, 14300, '00:45:51', 17900,27,21, 'BLUE', 'Ryze');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 2, 5, 6, 263, 13200, '00:45:09', 19900,22,21, 'BLUE', 'Galio');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 7, 3, 7, 193, 11100, '00:23:55', 20300,34,27, 'RED', 'Akali');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 2, 6, 329, 16600, '00:26:37', 26300,29,25, 'RED', 'Akali');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 3, 7, 326, 15800, '00:32:42', 24400,28,24, 'BLUE', 'Viktor');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 6, 3, 15, 208, 12600, '00:36:25', 30100,36,30, 'RED', 'Viktor');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 1, 3, 5, 156, 8500, '00:47:49', 10000,25,21, 'BLUE', 'Sylas');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 6, 3, 1, 182, 11400, '00:47:05', 13600,23,22, 'BLUE', 'Sylas');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 0, 1, 9, 200, 9000, '00:40:49', 7000,24,22, 'RED', 'Lissandra');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 4, 0, 202, 9100, '00:24:01', 11600,13,15, 'RED', 'Akali');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 7, 1, 7, 169, 9700, '00:27:57', 12700,33,32, 'BLUE', 'Akali');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 2, 2, 273, 11800, '00:38:09', 6400,16,16, 'RED', 'Ahri');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 5, 0, 216, 8600, '00:41:39', 8000,16,12, 'BLUE', 'Renekton');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 2, 4, 4, 315, 14100, '00:45:40', 13100,26,25, 'BLUE', 'Ahri');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 1, 1, 6, 338, 15300, '00:39:06', 7300,30,25, 'BLUE', 'Galio');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 3, 3, 258, 12100, '00:33:58', 13800,22,18, 'BLUE', 'Azir');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 4, 6, 326, 13400, '00:27:34', 16000,28,26, 'RED', 'Lissandra');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 4, 2, 7, 203, 10600, '00:44:08', 11700,26,25, 'RED', 'Sylas');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 5, 1, 7, 235, 11800, '00:44:30', 19800,34,33, 'BLUE', 'Azir');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 3, 10, 233, 12800, '00:24:57', 23200,34,32, 'RED', 'Ahri');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 6, 0, 9, 306, 14900, '00:29:57', 21800,29,25, 'BLUE', 'Ahri');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 4, 4, 165, 7600, '00:34:10', 9800,25,22, 'BLUE', 'Swain');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 2, 2, 2, 284, 12500, '00:20:01', 17100,26,27, 'RED', 'Azir');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 2, 15, 308, 15700, '00:40:22', 23800,41,42, 'BLUE', 'Azir');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 5, 1, 293, 13000, '00:45:31', 20000,21,21, 'RED', 'Azir');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 5, 1, 7, 286, 15200, '00:41:44', 26900,27,20, 'RED', 'Azir');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 2, 7, 277, 12900, '00:30:47', 17800,28,21, 'RED', 'Taliyah');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 1, 12, 304, 14000, '00:22:43', 11600,33,29, 'BLUE', 'Galio');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 2, 2, 215, 9200, '00:36:31', 15300,14,12, 'BLUE', 'Azir');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 1, 5, 254, 12100, '00:26:34', 10200,21,12, 'BLUE', 'Twisted Fate');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 1, 2, 11, 293, 13300, '00:24:51', 19400,27,26, 'BLUE', 'Orianna');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 2, 3, 4, 234, 10700, '00:37:52', 9500,21,17, 'RED', 'Galio');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 1, 4, 251, 11500, '00:26:47', 7300,19,19, 'BLUE', 'Galio');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 2, 13, 255, 13100, '00:22:53', 14100,31,25, 'RED', 'Galio');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 5, 2, 4, 298, 14700, '00:25:08', 21600,23,19, 'BLUE', 'Sylas');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 2, 3, 1, 312, 13400, '00:37:11', 16500,23,19, 'RED', 'Azir');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 1, 7, 375, 17400, '00:46:44', 20900,23,14, 'BLUE', 'Taliyah');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 2, 4, 307, 14700, '00:22:57', 13000,26,23, 'BLUE', 'Taliyah');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 3, 1, 269, 10800, '00:27:36', 12000,16,9, 'BLUE', 'Lissandra');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 5, 1, 7, 311, 15900, '00:20:37', 28900,29,21, 'RED', 'Azir');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 1, 10, 229, 10500, '00:40:06', 18200,26,19, 'RED', 'Seraphine');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 1, 3, 344, 17000, '00:43:15', 21700,21,19, 'BLUE', 'Corki');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 1, 3, 344, 17000, '00:43:15', 21700,17,17, 'BLUE', 'Corki');

INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 151);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 152);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 153);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 154);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 155);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 156);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 157);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 158);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 159);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 160);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 161);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 162);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 163);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 164);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 165);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 166);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 167);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 168);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 169);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 170);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 171);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 172);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 173);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 174);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 175);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 176);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 177);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 178);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 179);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 180);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 181);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 182);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 183);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 184);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 185);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 186);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 187);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 188);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 189);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 190);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 191);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 192);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 193);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 194);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 195);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 196);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 197);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 198);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 199);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Sloik', 200);
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 4, 4, 3, 292, 15600, '00:46:45', 27500,25,26, 'BLUE', 'Gwen');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 2, 1, 237, 11300, '00:35:59', 10300,18,16, 'RED', 'Fiora');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 1, 7, 150, 10800, '00:39:31', 15800,24,18, 'BLUE', 'Gragas');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 3, 5, 5, 328, 16300, '00:22:53', 20800,22,22, 'RED', 'Aatrox');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 4, 1, 5, 274, 14200, '00:28:47', 18700,28,26, 'BLUE', 'Yone');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 4, 1, 16, 147, 9100, '00:44:39', 12600,33,31, 'RED', 'Gragas');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 4, 5, 13, 211, 15200, '00:31:04', 30000,32,28, 'RED', 'Gangplank');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 6, 3, 6, 290, 15100, '00:28:26', 20200,28,21, 'BLUE', 'Yone');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 2, 5, 6, 288, 13900, '00:47:08', 13700,23,23, 'BLUE', 'Camille');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 8, 4, 7, 220, 13100, '00:21:52', 20700,29,32, 'RED', 'Yone');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 0, 8, 10, 318, 15300, '00:30:21', 30500,28,26, 'RED', 'Jayce');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 5, 2, 7, 336, 18300, '00:35:19', 21600,28,24, 'BLUE', 'Camille');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 10, 2, 4, 266, 16100, '00:23:38', 28900,29,21, 'RED', 'Gangplank');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 5, 5, 189, 10300, '00:38:30', 18800,27,27, 'BLUE', 'Jayce');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 3, 3, 266, 12800, '00:37:49', 20000,20,19, 'BLUE', 'Yone');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 1, 9, 218, 11600, '00:20:52', 16900,28,20, 'RED', 'Aatrox');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 4, 5, 200, 10300, '00:40:34', 10400,21,21, 'RED', 'Jax');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 4, 1, 7, 179, 10300, '00:49:54', 14100,31,27, 'BLUE', 'Fiora');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 5, 1, 233, 10700, '00:20:22', 12700,16,13, 'RED', 'Mordekaiser');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 3, 2, 207, 8100, '00:47:06', 14300,18,19, 'BLUE', 'Gnar');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 4, 4, 256, 11500, '00:34:33', 8800,17,19, 'BLUE', 'Ornn');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 0, 5, 322, 15500, '00:46:11', 10500,23,18, 'BLUE', 'Gnar');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 4, 5, 1, 263, 13000, '00:47:12', 11800,22,24, 'BLUE', 'Camille');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 5, 1, 0, 338, 15200, '00:27:32', 14900,20,15, 'RED', 'Aatrox');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 1, 6, 211, 11800, '00:32:40', 16400,23,21, 'RED', 'Gnar');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 1, 5, 12, 161, 8500, '00:39:20', 15900,23,21, 'BLUE', 'Ornn');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 4, 1, 10, 221, 12700, '00:37:28', 17000,29,20, 'RED', 'Gragas');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 2, 12, 244, 11700, '00:29:01', 15800,25,25, 'BLUE', 'Ornn');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 2, 5, 2, 145, 7800, '00:21:14', 14500,18,13, 'BLUE', 'Sejuani');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 5, 5, 159, 8200, '00:49:36', 11800,18,13, 'RED', 'Sejuani');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 5, 10, 174, 10700, '00:45:04', 14700,24,19, 'BLUE', 'Zac');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 6, 1, 266, 12000, '00:44:05', 18900,15,16, 'RED', 'Renekton');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 1, 2, 5, 237, 10900, '00:26:31', 9000,22,16, 'RED', 'Camille');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 1, 0, 17, 206, 11000, '00:30:04', 15400,31,30, 'RED', 'Sejuani');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 8, 1, 6, 325, 16300, '00:30:53', 22200,36,34, 'BLUE', 'Akali');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 5, 1, 160, 7000, '00:34:46', 8000,17,16, 'BLUE', 'Ornn');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 3, 1, 312, 12600, '00:35:58', 12800,18,19, 'BLUE', 'Gwen');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 4, 8, 175, 10300, '00:47:39', 12800,33,27, 'BLUE', 'Ornn');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 1, 5, 3, 275, 14000, '00:35:54', 20000,20,17, 'RED', 'Gnar');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 5, 1, 4, 276, 15000, '00:23:35', 18900,24,24, 'BLUE', 'Gnar');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 10, 0, 4, 338, 21100, '00:28:37', 35100,27,22, 'RED', 'Gangplank');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 3, 7, 251, 13900, '00:33:38', 16000,31,25, 'BLUE', 'Gnar');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 3, 2, 272, 12500, '00:30:31', 14400,17,15, 'RED', 'Gwen');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 3, 6, 160, 11100, '00:35:51', 12200,22,20, 'BLUE', 'Gragas');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 3, 1, 8, 221, 12400, '00:47:37', 16400,31,26, 'BLUE', 'Ornn');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('LOSE', 0, 5, 2, 268, 12600, '00:49:52', 16400,23,25, 'BLUE', 'Gnar');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 2, 2, 8, 310, 15700, '00:23:27', 25000,22,20, 'RED', 'Gangplank');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 5, 0, 5, 264, 13000, '00:37:58', 22000,28,27, 'RED', 'Gnar');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 1, 1, 2, 275, 11600, '00:30:09', 10600,18,17, 'BLUE', 'Gwen');
INSERT INTO gry(rezultat, zabojstwa, smierci, asysty,creep_score, zdobyte_zloto, czas_gry, zadane_obrazenia,zabojstwa_druzyny,zgony_druzyny, strona, bohaterowie_nazwa)VALUES ('WIN', 1, 1, 2, 275, 11600, '00:30:09', 10600,15,12, 'BLUE', 'Gwen');

INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 201);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 202);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 203);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 204);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 205);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 206);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 207);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 208);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 209);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 210);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 211);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 212);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 213);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 214);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 215);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 216);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 217);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 218);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 219);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 220);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 221);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 222);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 223);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 224);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 225);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 226);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 227);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 228);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 229);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 230);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 231);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 232);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 233);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 234);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 235);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 236);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 237);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 238);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 239);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 240);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 241);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 242);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 243);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 244);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 245);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 246);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 247);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 248);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 249);
INSERT INTO gracze_gry(gracze_nick, gry_id_meczu) VALUES('Quavenox', 250);

INSERT INTO dane_logowania(nick, haslo, rola) VALUES('Quavenox', 'admin', 'Administrator');
INSERT INTO dane_logowania(nick, haslo, rola) VALUES('Sloik', 'user', 'User');

EXEC dodaj_przedmiot_do_gry 1, 'Widmowe Ostrze Youmuu'
EXEC dodaj_przedmiot_do_gry 1, 'Taniec ??mierci'
EXEC dodaj_przedmiot_do_gry 1, 'Kostur P??yn??cej Wody'
EXEC dodaj_przedmiot_do_gry 1, 'Widmowy Tancerz'
EXEC dodaj_przedmiot_do_gry 1, 'Widmowy Sierp'
EXEC dodaj_przedmiot_do_gry 1, 'Alternator Hextech'
EXEC dodaj_przedmiot_do_gry 2, 'Pot??ga Wichury'
EXEC dodaj_przedmiot_do_gry 2, 'Omen Randuina'
EXEC dodaj_przedmiot_do_gry 2, 'Od??amek Prawdziwego Lodu'
EXEC dodaj_przedmiot_do_gry 2, 'R??wnonoc'
EXEC dodaj_przedmiot_do_gry 2, 'Krwio??ercza Hydra'
EXEC dodaj_przedmiot_do_gry 2, 'Szpon Piaskowej Dzier??by'
EXEC dodaj_przedmiot_do_gry 3, 'Wieczna Zmarzlina'
EXEC dodaj_przedmiot_do_gry 3, 'Szpon Ciemnego Typa'
EXEC dodaj_przedmiot_do_gry 3, 'Kolczasta Kolczuga'
EXEC dodaj_przedmiot_do_gry 3, 'Cieniotw??rca Draktharru'
EXEC dodaj_przedmiot_do_gry 3, 'Wielka Zima'
EXEC dodaj_przedmiot_do_gry 3, 'Manamune'
EXEC dodaj_przedmiot_do_gry 4, 'Ko??czan Po??udnia'
EXEC dodaj_przedmiot_do_gry 4, 'Przysi??ga Rycerska'
EXEC dodaj_przedmiot_do_gry 4, 'Wieczna Zima'
EXEC dodaj_przedmiot_do_gry 4, 'Maska Otch??ani'
EXEC dodaj_przedmiot_do_gry 4, 'Ogniolubny Top??r'
EXEC dodaj_przedmiot_do_gry 4, 'Widmowa Os??ona'
EXEC dodaj_przedmiot_do_gry 5, 'Blu??nierczy Bo??ek'
EXEC dodaj_przedmiot_do_gry 5, 'Zamarzni??ta Pi??????'
EXEC dodaj_przedmiot_do_gry 5, 'Baczny Kamienny Totem'
EXEC dodaj_przedmiot_do_gry 5, 'Kostur Archanio??a'
EXEC dodaj_przedmiot_do_gry 5, 'Kamizelka Cierniowa'
EXEC dodaj_przedmiot_do_gry 5, 'Ostrze Nocy'
EXEC dodaj_przedmiot_do_gry 6, 'Wieczna Zima'
EXEC dodaj_przedmiot_do_gry 6, 'Skupienie Horyzontalne'
EXEC dodaj_przedmiot_do_gry 6, 'Ostrze Gniewu Guinsoo'
EXEC dodaj_przedmiot_do_gry 6, 'Blu??nierczy Bo??ek'
EXEC dodaj_przedmiot_do_gry 6, '??miertelne Przypomnienie'
EXEC dodaj_przedmiot_do_gry 6, 'Demoniczny U??cisk'
EXEC dodaj_przedmiot_do_gry 7, 'Eteryczny Duszek'
EXEC dodaj_przedmiot_do_gry 7, 'Z??odziej Esencji'
EXEC dodaj_przedmiot_do_gry 7, '??ar Bami'
EXEC dodaj_przedmiot_do_gry 7, 'Kolekcjoner'
EXEC dodaj_przedmiot_do_gry 7, 'Odkupienie'
EXEC dodaj_przedmiot_do_gry 7, 'Klepsydra Zhonyi'
EXEC dodaj_przedmiot_do_gry 8, 'Po??eracz'
EXEC dodaj_przedmiot_do_gry 8, 'Zbroja Stra??nika'
EXEC dodaj_przedmiot_do_gry 8, 'Baczny Kamienny Totem'
EXEC dodaj_przedmiot_do_gry 8, 'Ulepszony Aeropak'
EXEC dodaj_przedmiot_do_gry 8, 'Tiamat'
EXEC dodaj_przedmiot_do_gry 8, 'Pancerz Umrzyka'
EXEC dodaj_przedmiot_do_gry 9, 'Krwiochron'
EXEC dodaj_przedmiot_do_gry 9, 'Niesko??czona Konwergencja'
EXEC dodaj_przedmiot_do_gry 9, 'Lament Liandry''ego'
EXEC dodaj_przedmiot_do_gry 9, 'Boski ??amacz'
EXEC dodaj_przedmiot_do_gry 9, 'Ognisty Trybularz'
EXEC dodaj_przedmiot_do_gry 9, 'Lament Liandry''ego'
EXEC dodaj_przedmiot_do_gry 10, 'Kamizelka Cierniowa'
EXEC dodaj_przedmiot_do_gry 10, 'Wykradacz Dusz Mejai'
EXEC dodaj_przedmiot_do_gry 10, 'Pancerniaki'
EXEC dodaj_przedmiot_do_gry 10, 'Skrzydlaty Ksi????ycowy Pancerz'
EXEC dodaj_przedmiot_do_gry 10, 'Widmowy Tancerz'
EXEC dodaj_przedmiot_do_gry 10, 'B??ogos??awie??stwo Mikaela'
EXEC dodaj_przedmiot_do_gry 11, 'Ca??un Banshee'
EXEC dodaj_przedmiot_do_gry 11, 'Klinga Burzy'
EXEC dodaj_przedmiot_do_gry 11, 'Nie??miertelny ??uklerz'
EXEC dodaj_przedmiot_do_gry 11, 'Jak''Sho Zmienny'
EXEC dodaj_przedmiot_do_gry 11, 'Ostrze Z??odziejki Czar??w'
EXEC dodaj_przedmiot_do_gry 11, 'Kuk??a Stracha na Wr??ble'
EXEC dodaj_przedmiot_do_gry 12, 'Wysysaj??ce Spojrzenie'
EXEC dodaj_przedmiot_do_gry 12, 'R????d??ka Wiek??w'
EXEC dodaj_przedmiot_do_gry 12, 'Lustro ze Szk??a Bandle'
EXEC dodaj_przedmiot_do_gry 12, 'Blask'
EXEC dodaj_przedmiot_do_gry 12, 'Klejnot Rozpadu'
EXEC dodaj_przedmiot_do_gry 12, 'Nawa??nica Luden'
EXEC dodaj_przedmiot_do_gry 13, 'Jak''Sho Zmienny'
EXEC dodaj_przedmiot_do_gry 13, 'Widmowa Os??ona'
EXEC dodaj_przedmiot_do_gry 13, 'Odkupienie'
EXEC dodaj_przedmiot_do_gry 13, 'Kamienna P??yta Gargulca'
EXEC dodaj_przedmiot_do_gry 13, 'Moc Niesko??czono??ci'
EXEC dodaj_przedmiot_do_gry 13, 'Cezura'
EXEC dodaj_przedmiot_do_gry 14, 'Puklerz Targonu'
EXEC dodaj_przedmiot_do_gry 14, 'Poch??aniacz Urok??w'
EXEC dodaj_przedmiot_do_gry 14, 'Plemienna Zbroja'
EXEC dodaj_przedmiot_do_gry 14, 'M??ot Bojowy Caulfielda'
EXEC dodaj_przedmiot_do_gry 14, 'Aksjomatyczny ??uk'
EXEC dodaj_przedmiot_do_gry 14, 'Widmowa Os??ona'
EXEC dodaj_przedmiot_do_gry 15, 'Ko??czan Po??udnia'
EXEC dodaj_przedmiot_do_gry 15, 'P????ksi????ycowe Ostrze Harrowing'
EXEC dodaj_przedmiot_do_gry 15, 'Koniec Rozumu'
EXEC dodaj_przedmiot_do_gry 15, 'Huragan Runaana'
EXEC dodaj_przedmiot_do_gry 15, 'Pogromca Kraken??w'
EXEC dodaj_przedmiot_do_gry 15, 'Chempunkowy ??a??cuchowy Miecz'
EXEC dodaj_przedmiot_do_gry 16, 'Gniewon????'
EXEC dodaj_przedmiot_do_gry 16, 'Skrzydlaty Ksi????ycowy Pancerz'
EXEC dodaj_przedmiot_do_gry 16, 'Niszczyciel Marze??'
EXEC dodaj_przedmiot_do_gry 16, 'Tiamat'
EXEC dodaj_przedmiot_do_gry 16, 'B??ogos??awie??stwo Mikaela'
EXEC dodaj_przedmiot_do_gry 16, 'Kula Stra??nika'
EXEC dodaj_przedmiot_do_gry 17, 'Twoja Dzia??ka'
EXEC dodaj_przedmiot_do_gry 17, 'Miotacz Gwiazd'
EXEC dodaj_przedmiot_do_gry 17, 'Klinga Burzy'
EXEC dodaj_przedmiot_do_gry 17, 'Konwergencja Zeke''a'
EXEC dodaj_przedmiot_do_gry 17, 'Cieniotw??rca Draktharru'
EXEC dodaj_przedmiot_do_gry 17, 'Krwiopijec'
EXEC dodaj_przedmiot_do_gry 18, 'Baczny Kamienny Totem'
EXEC dodaj_przedmiot_do_gry 18, 'Lament Liandry''ego'
EXEC dodaj_przedmiot_do_gry 18, '??miertelne Przypomnienie'
EXEC dodaj_przedmiot_do_gry 18, 'Kosa Czarnej Mg??y'
EXEC dodaj_przedmiot_do_gry 18, 'Obuwie Merkurego'
EXEC dodaj_przedmiot_do_gry 18, 'Zaginiony Rozdzia??'
EXEC dodaj_przedmiot_do_gry 19, 'Konwergencja Zeke''a'
EXEC dodaj_przedmiot_do_gry 19, 'Ochraniacze z Runicznej Stali'
EXEC dodaj_przedmiot_do_gry 19, 'Kryszta??owy Kostur Rylai'
EXEC dodaj_przedmiot_do_gry 19, 'Nie??miertelny ??uklerz'
EXEC dodaj_przedmiot_do_gry 19, 'Muramana'
EXEC dodaj_przedmiot_do_gry 19, 'Mro??ne Serce'
EXEC dodaj_przedmiot_do_gry 20, 'Huragan Runaana'
EXEC dodaj_przedmiot_do_gry 20, 'Kostur Pustki'
EXEC dodaj_przedmiot_do_gry 20, 'Od??amek Prawdziwego Lodu'
EXEC dodaj_przedmiot_do_gry 20, 'Ogniolubny Top??r'
EXEC dodaj_przedmiot_do_gry 20, 'Przysi??ga Rycerska'
EXEC dodaj_przedmiot_do_gry 20, 'Huragan Runaana'
EXEC dodaj_przedmiot_do_gry 21, 'Ochraniacze z Runicznej Stali'
EXEC dodaj_przedmiot_do_gry 21, 'Ognisty Trybularz'
EXEC dodaj_przedmiot_do_gry 21, 'Kamizelka Cierniowa'
EXEC dodaj_przedmiot_do_gry 21, 'Obuwie Merkurego'
EXEC dodaj_przedmiot_do_gry 21, 'Lodowa R??kawica'
EXEC dodaj_przedmiot_do_gry 21, 'Ostrze Niesko??czono??ci'
EXEC dodaj_przedmiot_do_gry 22, 'Maska Otch??ani'
EXEC dodaj_przedmiot_do_gry 22, 'M??ot Stra??nika'
EXEC dodaj_przedmiot_do_gry 22, 'Kamizelka Cierniowa'
EXEC dodaj_przedmiot_do_gry 22, 'Zamarzni??ta Pi??????'
EXEC dodaj_przedmiot_do_gry 22, 'Anio?? Str????'
EXEC dodaj_przedmiot_do_gry 22, 'Przedwieczny Brzask'
EXEC dodaj_przedmiot_do_gry 23, 'Czarny Tasak'
EXEC dodaj_przedmiot_do_gry 23, 'Kryszta??owy Karwasz'
EXEC dodaj_przedmiot_do_gry 23, 'Zas??ona R??wno??ci'
EXEC dodaj_przedmiot_do_gry 23, 'Zbroja Stra??nika'
EXEC dodaj_przedmiot_do_gry 23, '??wietlista Cnota'
EXEC dodaj_przedmiot_do_gry 23, 'M??ot Stra??nika'
EXEC dodaj_przedmiot_do_gry 24, 'Ostrze Stra??nika'
EXEC dodaj_przedmiot_do_gry 24, 'Konwergencja Zeke''a'
EXEC dodaj_przedmiot_do_gry 24, 'Czarci Kodeks'
EXEC dodaj_przedmiot_do_gry 24, 'Wieczna Zima'
EXEC dodaj_przedmiot_do_gry 24, 'Kamienna P??yta Gargulca'
EXEC dodaj_przedmiot_do_gry 24, 'Klepsydra Zhonyi'
EXEC dodaj_przedmiot_do_gry 25, 'Zab??jczy Kapelusz Rabadona'
EXEC dodaj_przedmiot_do_gry 25, 'Ogniolubny Top??r'
EXEC dodaj_przedmiot_do_gry 25, 'Krwiopijec'
EXEC dodaj_przedmiot_do_gry 25, 'Nieustaj??cy G????d'
EXEC dodaj_przedmiot_do_gry 25, 'Kryszta??owy Karwasz'
EXEC dodaj_przedmiot_do_gry 25, 'Kostur Archanio??a'
EXEC dodaj_przedmiot_do_gry 26, 'Przedwieczny Brzask'
EXEC dodaj_przedmiot_do_gry 26, 'Pogromca Kraken??w'
EXEC dodaj_przedmiot_do_gry 26, 'Przysi??ga Rycerska'
EXEC dodaj_przedmiot_do_gry 26, 'Eteryczny Duszek'
EXEC dodaj_przedmiot_do_gry 26, 'Ostrze Gniewu Guinsoo'
EXEC dodaj_przedmiot_do_gry 26, 'Szybkie Ostrza Navori'
EXEC dodaj_przedmiot_do_gry 27, 'Gangplank Placeholder'
EXEC dodaj_przedmiot_do_gry 27, 'Czarna W????cznia Kalisty'
EXEC dodaj_przedmiot_do_gry 27, 'Przedwieczny Brzask'
EXEC dodaj_przedmiot_do_gry 27, 'Naramienniki spod Bia??ej Ska??y'
EXEC dodaj_przedmiot_do_gry 27, 'Kostur P??yn??cej Wody'
EXEC dodaj_przedmiot_do_gry 27, 'Hextechowy Pas Rakietowy'
EXEC dodaj_przedmiot_do_gry 28, 'Za??mienie'
EXEC dodaj_przedmiot_do_gry 28, 'Nieustaj??cy G????d'
EXEC dodaj_przedmiot_do_gry 28, 'Nie??miertelny ??uklerz'
EXEC dodaj_przedmiot_do_gry 28, 'Baczny Kamienny Totem'
EXEC dodaj_przedmiot_do_gry 28, 'Jak''Sho Zmienny'
EXEC dodaj_przedmiot_do_gry 28, 'Oblicze Ducha'
EXEC dodaj_przedmiot_do_gry 29, 'Rekwiem Shurelyi'
EXEC dodaj_przedmiot_do_gry 29, 'Naszyjnik ??elaznych Solari'
EXEC dodaj_przedmiot_do_gry 29, 'Ostrze Z??odziejki Czar??w'
EXEC dodaj_przedmiot_do_gry 29, 'Si??a Natury'
EXEC dodaj_przedmiot_do_gry 29, 'Aksjomatyczny ??uk'
EXEC dodaj_przedmiot_do_gry 29, 'Tiamat'
EXEC dodaj_przedmiot_do_gry 30, 'Ko??czan Po??udnia'
EXEC dodaj_przedmiot_do_gry 30, 'Nagolenniki Berserkera'
EXEC dodaj_przedmiot_do_gry 30, 'Kolosalna Hydra'
EXEC dodaj_przedmiot_do_gry 30, 'Ognisty Trybularz'
EXEC dodaj_przedmiot_do_gry 30, 'Kula Stra??nika'
EXEC dodaj_przedmiot_do_gry 30, 'Kryszta??owy Kostur Rylai'
EXEC dodaj_przedmiot_do_gry 31, 'Tiamat'
EXEC dodaj_przedmiot_do_gry 31, 'Blu??nierczy Bo??ek'
EXEC dodaj_przedmiot_do_gry 31, 'Widmowy Sierp'
EXEC dodaj_przedmiot_do_gry 31, 'Zab??jczy Kapelusz Rabadona'
EXEC dodaj_przedmiot_do_gry 31, 'Zapa??'
EXEC dodaj_przedmiot_do_gry 31, 'Kula Zag??ady'
EXEC dodaj_przedmiot_do_gry 32, 'Z??ota Szpatu??ka'
EXEC dodaj_przedmiot_do_gry 32, 'Lodowa R??kawica'
EXEC dodaj_przedmiot_do_gry 32, 'Mro??ny Puklerz'
EXEC dodaj_przedmiot_do_gry 32, 'Rozgrzany Klejnot'
EXEC dodaj_przedmiot_do_gry 32, 'Zamarzni??ta Pi??????'
EXEC dodaj_przedmiot_do_gry 32, 'W????owy Kie??'
EXEC dodaj_przedmiot_do_gry 33, 'Kamizelka Cierniowa'
EXEC dodaj_przedmiot_do_gry 33, 'Krwiochron'
EXEC dodaj_przedmiot_do_gry 33, 'Nieustaj??cy G????d'
EXEC dodaj_przedmiot_do_gry 33, 'Odkupienie'
EXEC dodaj_przedmiot_do_gry 33, 'Tajfun'
EXEC dodaj_przedmiot_do_gry 33, 'Oblicze Ducha'
EXEC dodaj_przedmiot_do_gry 34, 'Naramiennik Poszukiwacza'
EXEC dodaj_przedmiot_do_gry 34, 'Ch??eptacz Posoki'
EXEC dodaj_przedmiot_do_gry 34, 'Taniec ??mierci'
EXEC dodaj_przedmiot_do_gry 34, 'Oblicze Ducha'
EXEC dodaj_przedmiot_do_gry 34, 'Ochraniacze z Runicznej Stali'
EXEC dodaj_przedmiot_do_gry 34, 'Czarci Kodeks'
EXEC dodaj_przedmiot_do_gry 35, 'Kula Stra??nika'
EXEC dodaj_przedmiot_do_gry 35, 'Paszcza Malmortiusa'
EXEC dodaj_przedmiot_do_gry 35, 'Wysysaj??ce Spojrzenie'
EXEC dodaj_przedmiot_do_gry 35, 'Czarny Tasak'
EXEC dodaj_przedmiot_do_gry 35, 'Za??mienie'
EXEC dodaj_przedmiot_do_gry 35, 'W????owy Kie??'
EXEC dodaj_przedmiot_do_gry 36, 'Tajfun'
EXEC dodaj_przedmiot_do_gry 36, 'Omen Randuina'
EXEC dodaj_przedmiot_do_gry 36, 'Zmiana Dalekowidzenia'
EXEC dodaj_przedmiot_do_gry 36, 'S??oneczna Egida'
EXEC dodaj_przedmiot_do_gry 36, 'Gangplank Placeholder'
EXEC dodaj_przedmiot_do_gry 36, 'Po??eracz'
EXEC dodaj_przedmiot_do_gry 37, 'Przysi??ga Rycerska'
EXEC dodaj_przedmiot_do_gry 37, 'Miotacz Gwiazd'
EXEC dodaj_przedmiot_do_gry 37, 'Niesko??czona Konwergencja'
EXEC dodaj_przedmiot_do_gry 37, 'Cierpienie Liandry''ego'
EXEC dodaj_przedmiot_do_gry 37, 'Ostrze Stra??nika'
EXEC dodaj_przedmiot_do_gry 37, 'Ch??eptacz Posoki'
EXEC dodaj_przedmiot_do_gry 38, 'Lewiatan'
EXEC dodaj_przedmiot_do_gry 38, 'Moc Niesko??czono??ci'
EXEC dodaj_przedmiot_do_gry 38, 'Tajfun'
EXEC dodaj_przedmiot_do_gry 38, 'M??ot Stra??nika'
EXEC dodaj_przedmiot_do_gry 38, 'Czarna W????cznia Kalisty'
EXEC dodaj_przedmiot_do_gry 38, 'M??ot Stra??nika'
EXEC dodaj_przedmiot_do_gry 39, '??miertelne Przypomnienie'
EXEC dodaj_przedmiot_do_gry 39, 'W????owy Kie??'
EXEC dodaj_przedmiot_do_gry 39, 'Czarna W????cznia Kalisty'
EXEC dodaj_przedmiot_do_gry 39, 'Od??amek Prawdziwego Lodu'
EXEC dodaj_przedmiot_do_gry 39, 'Ch??eptacz Posoki'
EXEC dodaj_przedmiot_do_gry 39, 'Zamarzni??ta Pi??????'
EXEC dodaj_przedmiot_do_gry 40, 'Pogromca Kraken??w'
EXEC dodaj_przedmiot_do_gry 40, 'Wykradacz Dusz Mejai'
EXEC dodaj_przedmiot_do_gry 40, 'Z??bkowany Sztylet'
EXEC dodaj_przedmiot_do_gry 40, 'Ulepszony Aeropak'
EXEC dodaj_przedmiot_do_gry 40, '??wietlista Cnota'
EXEC dodaj_przedmiot_do_gry 40, 'Szczelinotw??rca'
EXEC dodaj_przedmiot_do_gry 41, 'Cieniotw??rca Draktharru'
EXEC dodaj_przedmiot_do_gry 41, 'Baczny Kamienny Totem'
EXEC dodaj_przedmiot_do_gry 41, 'Grubosk??rno???? Steraka'
EXEC dodaj_przedmiot_do_gry 41, 'Klejnot Rozpadu'
EXEC dodaj_przedmiot_do_gry 41, 'Przysi??ga Rycerska'
EXEC dodaj_przedmiot_do_gry 41, 'W????cznia Shojin'
EXEC dodaj_przedmiot_do_gry 42, 'Twoja Dzia??ka'
EXEC dodaj_przedmiot_do_gry 42, 'Kad??ubo??amacz'
EXEC dodaj_przedmiot_do_gry 42, 'Obuwie Maga'
EXEC dodaj_przedmiot_do_gry 42, 'Ochraniacze z Runicznej Stali'
EXEC dodaj_przedmiot_do_gry 42, 'Ostrze Gniewu Guinsoo'
EXEC dodaj_przedmiot_do_gry 42, 'P????ksi????ycowe Ostrze Harrowing'
EXEC dodaj_przedmiot_do_gry 43, 'Klejnot Rozpadu'
EXEC dodaj_przedmiot_do_gry 43, 'Czarny Tasak'
EXEC dodaj_przedmiot_do_gry 43, 'Ch??eptacz Posoki'
EXEC dodaj_przedmiot_do_gry 43, 'Blu??nierczy Bo??ek'
EXEC dodaj_przedmiot_do_gry 43, 'Ognisty Trybularz'
EXEC dodaj_przedmiot_do_gry 43, 'Imperialny Mandat'
EXEC dodaj_przedmiot_do_gry 44, 'Czarny Tasak'
EXEC dodaj_przedmiot_do_gry 44, 'Kad??ubo??amacz'
EXEC dodaj_przedmiot_do_gry 44, 'Czarna W????cznia Kalisty'
EXEC dodaj_przedmiot_do_gry 44, 'Uraza Seryldy'
EXEC dodaj_przedmiot_do_gry 44, 'Szpon Piaskowej Dzier??by'
EXEC dodaj_przedmiot_do_gry 44, 'Katalizator Eon??w'
EXEC dodaj_przedmiot_do_gry 45, 'Z??odziej Esencji'
EXEC dodaj_przedmiot_do_gry 45, 'Widmowy Tancerz'
EXEC dodaj_przedmiot_do_gry 45, 'B??ogos??awie??stwo Mikaela'
EXEC dodaj_przedmiot_do_gry 45, 'Stalowe Naramienniki'
EXEC dodaj_przedmiot_do_gry 45, 'Grubosk??rno???? Steraka'
EXEC dodaj_przedmiot_do_gry 45, 'U??cisk Serafina'
EXEC dodaj_przedmiot_do_gry 46, 'Szpon Piaskowej Dzier??by'
EXEC dodaj_przedmiot_do_gry 46, 'Kolekcjoner'
EXEC dodaj_przedmiot_do_gry 46, 'Ko??czan Po??udnia'
EXEC dodaj_przedmiot_do_gry 46, 'Rekwiem Shurelyi'
EXEC dodaj_przedmiot_do_gry 46, 'Pasjonuj??cy Kamienny Totem'
EXEC dodaj_przedmiot_do_gry 46, 'M??ot Bojowy Caulfielda'
EXEC dodaj_przedmiot_do_gry 47, 'Nieopisany Paso??yt'
EXEC dodaj_przedmiot_do_gry 47, 'Widmowy Tancerz'
EXEC dodaj_przedmiot_do_gry 47, 'Kula Stra??nika'
EXEC dodaj_przedmiot_do_gry 47, 'Kamienna P??yta Gargulca'
EXEC dodaj_przedmiot_do_gry 47, 'Kostur P??yn??cej Wody'
EXEC dodaj_przedmiot_do_gry 47, 'Totem Ukrycia'
EXEC dodaj_przedmiot_do_gry 48, 'Ostrze Zniszczonego Kr??la'
EXEC dodaj_przedmiot_do_gry 48, 'Po??wi??cenie W????owej Ofiary'
EXEC dodaj_przedmiot_do_gry 48, 'W????owy Kie??'
EXEC dodaj_przedmiot_do_gry 48, 'Soczewka Wyroczni'
EXEC dodaj_przedmiot_do_gry 48, 'Kula Zag??ady'
EXEC dodaj_przedmiot_do_gry 48, 'Kolosalna Hydra'
EXEC dodaj_przedmiot_do_gry 49, 'Pasjonuj??cy Kamienny Totem'
EXEC dodaj_przedmiot_do_gry 49, 'Zmiana Dalekowidzenia'
EXEC dodaj_przedmiot_do_gry 49, 'Ochraniacze z Runicznej Stali'
EXEC dodaj_przedmiot_do_gry 49, 'Klejnot Rozpadu'
EXEC dodaj_przedmiot_do_gry 49, 'Ognista Armata'
EXEC dodaj_przedmiot_do_gry 49, 'Ulepszony Aeropak'
EXEC dodaj_przedmiot_do_gry 50, 'Anio?? Str????'
EXEC dodaj_przedmiot_do_gry 50, 'Huragan Runaana'
EXEC dodaj_przedmiot_do_gry 50, 'Ostrze Gniewu Guinsoo'
EXEC dodaj_przedmiot_do_gry 50, 'Z??ota Szpatu??ka'
EXEC dodaj_przedmiot_do_gry 50, 'Za??mienie'
EXEC dodaj_przedmiot_do_gry 50, 'Oko Luden'
EXEC dodaj_przedmiot_do_gry 51, 'Huragan Runaana'
EXEC dodaj_przedmiot_do_gry 51, 'W????owy Kie??'
EXEC dodaj_przedmiot_do_gry 51, 'Zas??ona R??wno??ci'
EXEC dodaj_przedmiot_do_gry 51, 'Ostrze Zniszczonego Kr??la'
EXEC dodaj_przedmiot_do_gry 51, 'Gangplank Placeholder'
EXEC dodaj_przedmiot_do_gry 51, 'Naramienniki spod Bia??ej Ska??y'
EXEC dodaj_przedmiot_do_gry 52, 'Naszyjnik ??elaznych Solari'
EXEC dodaj_przedmiot_do_gry 52, 'Po??wi??cenie W????owej Ofiary'
EXEC dodaj_przedmiot_do_gry 52, 'Nieustaj??cy G????d'
EXEC dodaj_przedmiot_do_gry 52, 'Odkupienie'
EXEC dodaj_przedmiot_do_gry 52, 'R??wnonoc'
EXEC dodaj_przedmiot_do_gry 52, 'Ch??eptacz Posoki'
EXEC dodaj_przedmiot_do_gry 53, 'Uraza Seryldy'
EXEC dodaj_przedmiot_do_gry 53, 'Katalizator Eon??w'
EXEC dodaj_przedmiot_do_gry 53, 'Mroczne Ostrze Draktharru'
EXEC dodaj_przedmiot_do_gry 53, 'Poch??aniacz Urok??w'
EXEC dodaj_przedmiot_do_gry 53, 'Demoniczny U??cisk'
EXEC dodaj_przedmiot_do_gry 53, 'Totem Ukrycia'
EXEC dodaj_przedmiot_do_gry 54, 'Alternator Hextech'
EXEC dodaj_przedmiot_do_gry 54, 'Klepsydra Zhonyi'
EXEC dodaj_przedmiot_do_gry 54, 'Zab??jczy Kapelusz Rabadona'
EXEC dodaj_przedmiot_do_gry 54, 'Kolekcjoner'
EXEC dodaj_przedmiot_do_gry 54, 'Ko??czan Po??udnia'
EXEC dodaj_przedmiot_do_gry 54, 'Stalowe Serce'
EXEC dodaj_przedmiot_do_gry 55, 'Turbochemiczny Pojemnik'
EXEC dodaj_przedmiot_do_gry 55, 'Kryszta??owy Karwasz'
EXEC dodaj_przedmiot_do_gry 55, 'Lodowa R??kawica'
EXEC dodaj_przedmiot_do_gry 55, 'Szpon Piaskowej Dzier??by'
EXEC dodaj_przedmiot_do_gry 55, 'B??ogos??awie??stwo Mikaela'
EXEC dodaj_przedmiot_do_gry 55, '??ar Bami'
EXEC dodaj_przedmiot_do_gry 56, 'Oko Luden'
EXEC dodaj_przedmiot_do_gry 56, 'Buty Mobilno??ci'
EXEC dodaj_przedmiot_do_gry 56, 'Zab??jczy Kapelusz Rabadona'
EXEC dodaj_przedmiot_do_gry 56, 'Ostatni Szept'
EXEC dodaj_przedmiot_do_gry 56, 'Buty Pr??dko??ci'
EXEC dodaj_przedmiot_do_gry 56, 'Nocny ??niwiarz'
EXEC dodaj_przedmiot_do_gry 57, 'Totem Ukrycia'
EXEC dodaj_przedmiot_do_gry 57, 'Buty Pr??dko??ci'
EXEC dodaj_przedmiot_do_gry 57, 'Kolosalna Hydra'
EXEC dodaj_przedmiot_do_gry 57, 'Tajfun'
EXEC dodaj_przedmiot_do_gry 57, '??wit Srebrzystej'
EXEC dodaj_przedmiot_do_gry 57, '??amacz Falangi'
EXEC dodaj_przedmiot_do_gry 58, 'W????cznia Shojin'
EXEC dodaj_przedmiot_do_gry 58, 'Manamune'
EXEC dodaj_przedmiot_do_gry 58, 'Czarny Tasak'
EXEC dodaj_przedmiot_do_gry 58, 'Grubosk??rno???? Steraka'
EXEC dodaj_przedmiot_do_gry 58, 'Puklerz Targonu'
EXEC dodaj_przedmiot_do_gry 58, 'Widmowy Sierp'
EXEC dodaj_przedmiot_do_gry 59, 'Pozdrowienia Lorda Dominika'
EXEC dodaj_przedmiot_do_gry 59, 'Klejnot Rozpadu'
EXEC dodaj_przedmiot_do_gry 59, 'Demoniczny U??cisk'
EXEC dodaj_przedmiot_do_gry 59, 'Kl??twa Icathii'
EXEC dodaj_przedmiot_do_gry 59, 'Ognista Armata'
EXEC dodaj_przedmiot_do_gry 59, 'Nadej??cie Zimy'
EXEC dodaj_przedmiot_do_gry 60, '??wietlista Cnota'
EXEC dodaj_przedmiot_do_gry 60, 'Oblicze Ducha'
EXEC dodaj_przedmiot_do_gry 60, 'Muramana'
EXEC dodaj_przedmiot_do_gry 60, 'Z??bkowany Sztylet'
EXEC dodaj_przedmiot_do_gry 60, 'Mro??ne Serce'
EXEC dodaj_przedmiot_do_gry 60, 'W????cznia Shojin'
EXEC dodaj_przedmiot_do_gry 61, 'Kryszta??owy Karwasz'
EXEC dodaj_przedmiot_do_gry 61, 'Cieniotw??rca Draktharru'
EXEC dodaj_przedmiot_do_gry 61, 'M??ot Stra??nika'
EXEC dodaj_przedmiot_do_gry 61, 'Szczelinotw??rca'
EXEC dodaj_przedmiot_do_gry 61, 'Ostrze Niesko??czono??ci'
EXEC dodaj_przedmiot_do_gry 61, 'Nawa??nica Luden'
EXEC dodaj_przedmiot_do_gry 62, 'Nocny ??niwiarz'
EXEC dodaj_przedmiot_do_gry 62, 'Vesperia??ski Przyp??yw'
EXEC dodaj_przedmiot_do_gry 62, 'Szpon Piaskowej Dzier??by'
EXEC dodaj_przedmiot_do_gry 62, 'Ostrze Niesko??czono??ci'
EXEC dodaj_przedmiot_do_gry 62, 'Gangplank Placeholder'
EXEC dodaj_przedmiot_do_gry 62, 'Naszyjnik ??elaznych Solari'
EXEC dodaj_przedmiot_do_gry 63, 'Huragan Runaana'
EXEC dodaj_przedmiot_do_gry 63, 'Soczewka Wyroczni'
EXEC dodaj_przedmiot_do_gry 63, 'Kuk??a Stracha na Wr??ble'
EXEC dodaj_przedmiot_do_gry 63, 'Wezwanie Kata'
EXEC dodaj_przedmiot_do_gry 63, 'Skupienie Horyzontalne'
EXEC dodaj_przedmiot_do_gry 63, 'Kula Zag??ady'
EXEC dodaj_przedmiot_do_gry 64, 'Nieustaj??cy G????d'
EXEC dodaj_przedmiot_do_gry 64, 'Ostatni Szept'
EXEC dodaj_przedmiot_do_gry 64, 'Blu??nierczy Bo??ek'
EXEC dodaj_przedmiot_do_gry 64, 'Maska Otch??ani'
EXEC dodaj_przedmiot_do_gry 64, 'R??wnonoc'
EXEC dodaj_przedmiot_do_gry 64, 'Z??bkowany Sztylet'
EXEC dodaj_przedmiot_do_gry 65, 'Moc Tr??jcy'
EXEC dodaj_przedmiot_do_gry 65, 'Kolosalna Hydra'
EXEC dodaj_przedmiot_do_gry 65, 'Odnowienie Kamienia Ksi????ycowego'
EXEC dodaj_przedmiot_do_gry 65, 'Totem Ukrycia'
EXEC dodaj_przedmiot_do_gry 65, 'Lodowa R??kawica'
EXEC dodaj_przedmiot_do_gry 65, 'Cierpienie Liandry''ego'
EXEC dodaj_przedmiot_do_gry 66, '??wit Srebrzystej'
EXEC dodaj_przedmiot_do_gry 66, 'Mro??ny Puklerz'
EXEC dodaj_przedmiot_do_gry 66, 'Nadej??cie Zimy'
EXEC dodaj_przedmiot_do_gry 66, 'Lodowy Kie??'
EXEC dodaj_przedmiot_do_gry 66, 'Koniec Rozumu'
EXEC dodaj_przedmiot_do_gry 66, 'Krwiopijec'
EXEC dodaj_przedmiot_do_gry 67, 'Ostrze Stra??nika'
EXEC dodaj_przedmiot_do_gry 67, '??amacz Falangi'
EXEC dodaj_przedmiot_do_gry 67, 'Szpon Ciemnego Typa'
EXEC dodaj_przedmiot_do_gry 67, '??elazny Bicz'
EXEC dodaj_przedmiot_do_gry 67, 'Paszcza Malmortiusa'
EXEC dodaj_przedmiot_do_gry 67, 'Chemtechowy Skaziciel'
EXEC dodaj_przedmiot_do_gry 68, 'Zas??ona R??wno??ci'
EXEC dodaj_przedmiot_do_gry 68, 'Nadej??cie Zimy'
EXEC dodaj_przedmiot_do_gry 68, 'Puklerz Targonu'
EXEC dodaj_przedmiot_do_gry 68, 'Aksjomatyczny ??uk'
EXEC dodaj_przedmiot_do_gry 68, 'Kula Stra??nika'
EXEC dodaj_przedmiot_do_gry 68, 'Czujny Kamienny Totem'
EXEC dodaj_przedmiot_do_gry 69, 'Lustro ze Szk??a Bandle'
EXEC dodaj_przedmiot_do_gry 69, 'Uraza Seryldy'
EXEC dodaj_przedmiot_do_gry 69, 'Ostrze Z??odziejki Czar??w'
EXEC dodaj_przedmiot_do_gry 69, 'Egida Legionu'
EXEC dodaj_przedmiot_do_gry 69, '??amacz Falangi'
EXEC dodaj_przedmiot_do_gry 69, 'R????d??ka Wiek??w'
EXEC dodaj_przedmiot_do_gry 70, 'Pancerniaki'
EXEC dodaj_przedmiot_do_gry 70, 'Od??amek Prawdziwego Lodu'
EXEC dodaj_przedmiot_do_gry 70, 'Wieczna Zmarzlina'
EXEC dodaj_przedmiot_do_gry 70, 'Moc Niesko??czono??ci'
EXEC dodaj_przedmiot_do_gry 70, 'Obuwie Maga'
EXEC dodaj_przedmiot_do_gry 70, 'Naramiennik Poszukiwacza'
EXEC dodaj_przedmiot_do_gry 71, 'Anio?? Str????'
EXEC dodaj_przedmiot_do_gry 71, 'Szpon Ciemnego Typa'
EXEC dodaj_przedmiot_do_gry 71, 'Naszyjnik ??elaznych Solari'
EXEC dodaj_przedmiot_do_gry 71, 'M??ot Stra??nika'
EXEC dodaj_przedmiot_do_gry 71, 'Ostrze Niesko??czono??ci'
EXEC dodaj_przedmiot_do_gry 71, 'Grubosk??rno???? Steraka'
EXEC dodaj_przedmiot_do_gry 72, 'Kula Zag??ady'
EXEC dodaj_przedmiot_do_gry 72, 'Wieczna Zmarzlina'
EXEC dodaj_przedmiot_do_gry 72, 'Zaginiony Rozdzia??'
EXEC dodaj_przedmiot_do_gry 72, 'Kl??twa Icathii'
EXEC dodaj_przedmiot_do_gry 72, 'Z??b Nashora'
EXEC dodaj_przedmiot_do_gry 72, 'Krwiochron'
EXEC dodaj_przedmiot_do_gry 73, 'Totem Ukrycia'
EXEC dodaj_przedmiot_do_gry 73, 'Wysysaj??ce Spojrzenie'
EXEC dodaj_przedmiot_do_gry 73, 'Kryszta??owy Kostur Rylai'
EXEC dodaj_przedmiot_do_gry 73, 'Wezwanie Kata'
EXEC dodaj_przedmiot_do_gry 73, 'Cezura'
EXEC dodaj_przedmiot_do_gry 73, 'Muramana'
EXEC dodaj_przedmiot_do_gry 74, 'Huragan Runaana'
EXEC dodaj_przedmiot_do_gry 74, 'Ko??czan Po??udnia'
EXEC dodaj_przedmiot_do_gry 74, 'Omen Randuina'
EXEC dodaj_przedmiot_do_gry 74, 'Widmowy Tancerz'
EXEC dodaj_przedmiot_do_gry 74, 'Naramiennik Poszukiwacza'
EXEC dodaj_przedmiot_do_gry 74, 'R??wnonoc'
EXEC dodaj_przedmiot_do_gry 75, 'Ca??un Banshee'
EXEC dodaj_przedmiot_do_gry 75, 'Zbroja Stra??nika'
EXEC dodaj_przedmiot_do_gry 75, 'Totem Ukrycia'
EXEC dodaj_przedmiot_do_gry 75, '??elazny Bicz'
EXEC dodaj_przedmiot_do_gry 75, 'Reliktowa Tarcza'
EXEC dodaj_przedmiot_do_gry 75, 'Buty Mobilno??ci'
EXEC dodaj_przedmiot_do_gry 76, 'Nie??miertelny ??uklerz'
EXEC dodaj_przedmiot_do_gry 76, 'Klinga Burzy'
EXEC dodaj_przedmiot_do_gry 76, 'Plemienna Zbroja'
EXEC dodaj_przedmiot_do_gry 76, 'Baczny Kamienny Totem'
EXEC dodaj_przedmiot_do_gry 76, 'Szpon Piaskowej Dzier??by'
EXEC dodaj_przedmiot_do_gry 76, 'Siedzisko Dow??dcy'
EXEC dodaj_przedmiot_do_gry 77, 'Czarna W????cznia Kalisty'
EXEC dodaj_przedmiot_do_gry 77, 'Kolosalna Hydra'
EXEC dodaj_przedmiot_do_gry 77, 'Nadej??cie Zimy'
EXEC dodaj_przedmiot_do_gry 77, 'Pancerz Umrzyka'
EXEC dodaj_przedmiot_do_gry 77, 'Twoja Dzia??ka'
EXEC dodaj_przedmiot_do_gry 77, 'Stalowe Naramienniki'
EXEC dodaj_przedmiot_do_gry 78, 'Rt??ciowy Bu??at'
EXEC dodaj_przedmiot_do_gry 78, 'Ostrze Gniewu Guinsoo'
EXEC dodaj_przedmiot_do_gry 78, 'Kostur Pustki'
EXEC dodaj_przedmiot_do_gry 78, 'Ca??un Banshee'
EXEC dodaj_przedmiot_do_gry 78, 'Bastion G??ry'
EXEC dodaj_przedmiot_do_gry 78, 'Stalowe Naramienniki'
EXEC dodaj_przedmiot_do_gry 79, 'Pasjonuj??cy Kamienny Totem'
EXEC dodaj_przedmiot_do_gry 79, 'Anio?? Str????'
EXEC dodaj_przedmiot_do_gry 79, 'Szczelinotw??rca'
EXEC dodaj_przedmiot_do_gry 79, 'Zmora Licza'
EXEC dodaj_przedmiot_do_gry 79, 'Z??odziej Esencji'
EXEC dodaj_przedmiot_do_gry 79, 'Tiamat'
EXEC dodaj_przedmiot_do_gry 80, 'Alternator Hextech'
EXEC dodaj_przedmiot_do_gry 80, 'Naszyjnik ??elaznych Solari'
EXEC dodaj_przedmiot_do_gry 80, 'Klejnot Rozpadu'
EXEC dodaj_przedmiot_do_gry 80, 'Obuwie Maga'
EXEC dodaj_przedmiot_do_gry 80, 'Alternator Hextech'
EXEC dodaj_przedmiot_do_gry 80, 'Wieczna Zima'
EXEC dodaj_przedmiot_do_gry 81, '??wietlista Cnota'
EXEC dodaj_przedmiot_do_gry 81, 'Stalowe Serce'
EXEC dodaj_przedmiot_do_gry 81, 'Kad??ubo??amacz'
EXEC dodaj_przedmiot_do_gry 81, 'Moc Niesko??czono??ci'
EXEC dodaj_przedmiot_do_gry 81, 'Chempunkowy ??a??cuchowy Miecz'
EXEC dodaj_przedmiot_do_gry 81, 'Ostrze Zniszczonego Kr??la'
EXEC dodaj_przedmiot_do_gry 82, 'Wezwanie Kata'
EXEC dodaj_przedmiot_do_gry 82, 'Oko Herolda'
EXEC dodaj_przedmiot_do_gry 82, 'Zab??jczy Kapelusz Rabadona'
EXEC dodaj_przedmiot_do_gry 82, 'Grubosk??rno???? Steraka'
EXEC dodaj_przedmiot_do_gry 82, 'Nieustaj??cy G????d'
EXEC dodaj_przedmiot_do_gry 82, 'Totem Ukrycia'
EXEC dodaj_przedmiot_do_gry 83, 'Lodowa R??kawica'
EXEC dodaj_przedmiot_do_gry 83, 'Widmowe Ostrze Youmuu'
EXEC dodaj_przedmiot_do_gry 83, 'Kula Stra??nika'
EXEC dodaj_przedmiot_do_gry 83, 'Nie??miertelny ??uklerz'
EXEC dodaj_przedmiot_do_gry 83, 'Ogniolubny Top??r'
EXEC dodaj_przedmiot_do_gry 83, 'Zmora Licza'
EXEC dodaj_przedmiot_do_gry 84, 'Ostatni Szept'
EXEC dodaj_przedmiot_do_gry 84, 'Nieustaj??cy G????d'
EXEC dodaj_przedmiot_do_gry 84, 'Paszcza Malmortiusa'
EXEC dodaj_przedmiot_do_gry 84, '??amacz Falangi'
EXEC dodaj_przedmiot_do_gry 84, 'Ca??un Banshee'
EXEC dodaj_przedmiot_do_gry 84, 'Nie??miertelny ??uklerz'
EXEC dodaj_przedmiot_do_gry 85, 'Nagolenniki Berserkera'
EXEC dodaj_przedmiot_do_gry 85, 'Morellonomicon'
EXEC dodaj_przedmiot_do_gry 85, 'Rt??ciowy Bu??at'
EXEC dodaj_przedmiot_do_gry 85, 'Po??wi??cenie W????owej Ofiary'
EXEC dodaj_przedmiot_do_gry 85, 'M??ot Bojowy Caulfielda'
EXEC dodaj_przedmiot_do_gry 85, 'Kostur Archanio??a'
EXEC dodaj_przedmiot_do_gry 86, 'Stalowe Naramienniki'
EXEC dodaj_przedmiot_do_gry 86, 'U??cisk Serafina'
EXEC dodaj_przedmiot_do_gry 86, 'Kostur Pustki'
EXEC dodaj_przedmiot_do_gry 86, 'Nagolenniki Berserkera'
EXEC dodaj_przedmiot_do_gry 86, 'Z??b Nashora'
EXEC dodaj_przedmiot_do_gry 86, 'Mroczne Ostrze Draktharru'
EXEC dodaj_przedmiot_do_gry 87, 'Niesko??czona Konwergencja'
EXEC dodaj_przedmiot_do_gry 87, 'Szczelinotw??rca'
EXEC dodaj_przedmiot_do_gry 87, '??elazny Bicz'
EXEC dodaj_przedmiot_do_gry 87, 'Szpon Ciemnego Typa'
EXEC dodaj_przedmiot_do_gry 87, 'Paszcza Malmortiusa'
EXEC dodaj_przedmiot_do_gry 87, 'Czarna W????cznia Kalisty'
EXEC dodaj_przedmiot_do_gry 88, 'Si??a Natury'
EXEC dodaj_przedmiot_do_gry 88, 'Huragan Runaana'
EXEC dodaj_przedmiot_do_gry 88, 'Ulepszony Aeropak'
EXEC dodaj_przedmiot_do_gry 88, 'Tajfun'
EXEC dodaj_przedmiot_do_gry 88, 'Kostur Pustki'
EXEC dodaj_przedmiot_do_gry 88, 'Krwio??ercza Hydra'
EXEC dodaj_przedmiot_do_gry 89, 'Konwergencja Zeke''a'
EXEC dodaj_przedmiot_do_gry 89, 'M??ot Stra??nika'
EXEC dodaj_przedmiot_do_gry 89, 'Ostatni Szept'
EXEC dodaj_przedmiot_do_gry 89, 'Twoja Dzia??ka'
EXEC dodaj_przedmiot_do_gry 89, 'Moc Niesko??czono??ci'
EXEC dodaj_przedmiot_do_gry 89, 'M??ot Stra??nika'
EXEC dodaj_przedmiot_do_gry 90, 'Ro??linna Bariera'
EXEC dodaj_przedmiot_do_gry 90, 'Morellonomicon'
EXEC dodaj_przedmiot_do_gry 90, 'Poch??aniacz Urok??w'
EXEC dodaj_przedmiot_do_gry 90, 'Szczelinotw??rca'
EXEC dodaj_przedmiot_do_gry 90, 'Czarna W????cznia Kalisty'
EXEC dodaj_przedmiot_do_gry 90, 'Kosa Czarnej Mg??y'
EXEC dodaj_przedmiot_do_gry 91, 'Skrzydlaty Ksi????ycowy Pancerz'
EXEC dodaj_przedmiot_do_gry 91, 'Imperialny Mandat'
EXEC dodaj_przedmiot_do_gry 91, 'R????d??ka Wiek??w'
EXEC dodaj_przedmiot_do_gry 91, 'Taniec ??mierci'
EXEC dodaj_przedmiot_do_gry 91, 'Od??amek Prawdziwego Lodu'
EXEC dodaj_przedmiot_do_gry 91, 'Turbochemiczny Pojemnik'
EXEC dodaj_przedmiot_do_gry 92, 'Stalowe Serce'
EXEC dodaj_przedmiot_do_gry 92, 'Ko??czan Po??udnia'
EXEC dodaj_przedmiot_do_gry 92, 'P??omie?? Cienia'
EXEC dodaj_przedmiot_do_gry 92, 'Widmowy Tancerz'
EXEC dodaj_przedmiot_do_gry 92, 'Mro??ny Puklerz'
EXEC dodaj_przedmiot_do_gry 92, 'Tiamat'
EXEC dodaj_przedmiot_do_gry 93, 'Naramiennik Poszukiwacza'
EXEC dodaj_przedmiot_do_gry 93, 'Jak''Sho Zmienny'
EXEC dodaj_przedmiot_do_gry 93, 'Gangplank Placeholder'
EXEC dodaj_przedmiot_do_gry 93, '??wietlista Cnota'
EXEC dodaj_przedmiot_do_gry 93, 'Od??amek Prawdziwego Lodu'
EXEC dodaj_przedmiot_do_gry 93, 'Zab??jczy Kapelusz Rabadona'
EXEC dodaj_przedmiot_do_gry 94, 'Nie??miertelny ??uklerz'
EXEC dodaj_przedmiot_do_gry 94, 'Lustro ze Szk??a Bandle'
EXEC dodaj_przedmiot_do_gry 94, 'Naszyjnik ??elaznych Solari'
EXEC dodaj_przedmiot_do_gry 94, 'Obuwie Maga'
EXEC dodaj_przedmiot_do_gry 94, 'Reliktowa Tarcza'
EXEC dodaj_przedmiot_do_gry 94, 'B??ogos??awie??stwo Mikaela'
EXEC dodaj_przedmiot_do_gry 95, 'Krwio??ercza Hydra'
EXEC dodaj_przedmiot_do_gry 95, 'Soczewka Wyroczni'
EXEC dodaj_przedmiot_do_gry 95, 'Ochraniacze z Runicznej Stali'
EXEC dodaj_przedmiot_do_gry 95, 'Grubosk??rno???? Steraka'
EXEC dodaj_przedmiot_do_gry 95, 'Pot??ga Wichury'
EXEC dodaj_przedmiot_do_gry 95, 'Kryszta??owy Kostur Rylai'
EXEC dodaj_przedmiot_do_gry 96, 'Puklerz Targonu'
EXEC dodaj_przedmiot_do_gry 96, 'Vesperia??ski Przyp??yw'
EXEC dodaj_przedmiot_do_gry 96, 'Korona Roztrzaskanej Kr??lowej'
EXEC dodaj_przedmiot_do_gry 96, 'Demoniczny U??cisk'
EXEC dodaj_przedmiot_do_gry 96, 'Koniec Rozumu'
EXEC dodaj_przedmiot_do_gry 96, 'Czarny Tasak'
EXEC dodaj_przedmiot_do_gry 97, 'Pot??ga Wichury'
EXEC dodaj_przedmiot_do_gry 97, 'Kryszta??owy Karwasz'
EXEC dodaj_przedmiot_do_gry 97, 'Wielka Zima'
EXEC dodaj_przedmiot_do_gry 97, 'Szczelinotw??rca'
EXEC dodaj_przedmiot_do_gry 97, 'Obuwie Merkurego'
EXEC dodaj_przedmiot_do_gry 97, 'Niszczyciel Marze??'
EXEC dodaj_przedmiot_do_gry 98, 'Blask'
EXEC dodaj_przedmiot_do_gry 98, 'Skupienie Horyzontalne'
EXEC dodaj_przedmiot_do_gry 98, 'Ostatni Szept'
EXEC dodaj_przedmiot_do_gry 98, 'Czarny Tasak'
EXEC dodaj_przedmiot_do_gry 98, 'Stalowe Serce'
EXEC dodaj_przedmiot_do_gry 98, 'Bogob??jca'
EXEC dodaj_przedmiot_do_gry 99, 'Muramana'
EXEC dodaj_przedmiot_do_gry 99, 'Turbochemiczny Pojemnik'
EXEC dodaj_przedmiot_do_gry 99, 'Reliktowa Tarcza'
EXEC dodaj_przedmiot_do_gry 99, 'Nagolenniki Berserkera'
EXEC dodaj_przedmiot_do_gry 99, 'Kosa Czarnej Mg??y'
EXEC dodaj_przedmiot_do_gry 99, 'Ostrze Nocy'
EXEC dodaj_przedmiot_do_gry 100, '??wit Srebrzystej'
EXEC dodaj_przedmiot_do_gry 100, 'Przedwieczny Brzask'
EXEC dodaj_przedmiot_do_gry 100, 'Czarna W????cznia Kalisty'
EXEC dodaj_przedmiot_do_gry 100, 'Szybkie Ostrza Navori'
EXEC dodaj_przedmiot_do_gry 100, 'Odnowienie Kamienia Ksi????ycowego'
EXEC dodaj_przedmiot_do_gry 100, 'Baczny Kamienny Totem'
EXEC dodaj_przedmiot_do_gry 101, 'Ochraniacze z Runicznej Stali'
EXEC dodaj_przedmiot_do_gry 101, 'Reliktowa Tarcza'
EXEC dodaj_przedmiot_do_gry 101, 'Skrzydlaty Ksi????ycowy Pancerz'
EXEC dodaj_przedmiot_do_gry 101, 'Kamizelka Cierniowa'
EXEC dodaj_przedmiot_do_gry 101, 'Siedzisko Dow??dcy'
EXEC dodaj_przedmiot_do_gry 101, 'Reliktowa Tarcza'
EXEC dodaj_przedmiot_do_gry 102, 'Czujny Kamienny Totem'
EXEC dodaj_przedmiot_do_gry 102, 'Zapa??'
EXEC dodaj_przedmiot_do_gry 102, 'Kad??ubo??amacz'
EXEC dodaj_przedmiot_do_gry 102, 'Z??bkowany Sztylet'
EXEC dodaj_przedmiot_do_gry 102, 'Kryszta??owy Kostur Rylai'
EXEC dodaj_przedmiot_do_gry 102, 'Kryszta??owy Karwasz'
EXEC dodaj_przedmiot_do_gry 103, 'Kryszta??owy Kostur Rylai'
EXEC dodaj_przedmiot_do_gry 103, 'Zaginiony Rozdzia??'
EXEC dodaj_przedmiot_do_gry 103, 'Czarna W????cznia Kalisty'
EXEC dodaj_przedmiot_do_gry 103, 'Naramienniki spod Bia??ej Ska??y'
EXEC dodaj_przedmiot_do_gry 103, 'Rekwiem Shurelyi'
EXEC dodaj_przedmiot_do_gry 103, 'P????ksi????ycowe Ostrze Harrowing'
EXEC dodaj_przedmiot_do_gry 104, 'Kamienna P??yta Gargulca'
EXEC dodaj_przedmiot_do_gry 104, 'R????d??ka Wiek??w'
EXEC dodaj_przedmiot_do_gry 104, 'Klinga Burzy'
EXEC dodaj_przedmiot_do_gry 104, 'Nagolenniki Berserkera'
EXEC dodaj_przedmiot_do_gry 104, 'Ch??eptacz Posoki'
EXEC dodaj_przedmiot_do_gry 104, 'Zmora Licza'
EXEC dodaj_przedmiot_do_gry 105, 'Glewia Umbry'
EXEC dodaj_przedmiot_do_gry 105, 'Szpon Piaskowej Dzier??by'
EXEC dodaj_przedmiot_do_gry 105, 'Moc Niesko??czono??ci'
EXEC dodaj_przedmiot_do_gry 105, 'Mro??ne Serce'
EXEC dodaj_przedmiot_do_gry 105, 'Ostrze Z??odziejki Czar??w'
EXEC dodaj_przedmiot_do_gry 105, 'Rozgrzany Klejnot'
EXEC dodaj_przedmiot_do_gry 106, 'Kosa Czarnej Mg??y'
EXEC dodaj_przedmiot_do_gry 106, 'Maska Otch??ani'
EXEC dodaj_przedmiot_do_gry 106, 'Lustro ze Szk??a Bandle'
EXEC dodaj_przedmiot_do_gry 106, '??wietlista Cnota'
EXEC dodaj_przedmiot_do_gry 106, 'Skupienie Horyzontalne'
EXEC dodaj_przedmiot_do_gry 106, 'Widmowa Os??ona'
EXEC dodaj_przedmiot_do_gry 107, 'Przysi??ga Rycerska'
EXEC dodaj_przedmiot_do_gry 107, 'Ochraniacze z Runicznej Stali'
EXEC dodaj_przedmiot_do_gry 107, 'Lodowa R??kawica'
EXEC dodaj_przedmiot_do_gry 107, 'Lewiatan'
EXEC dodaj_przedmiot_do_gry 107, 'Cezura'
EXEC dodaj_przedmiot_do_gry 107, 'Szybkie Ostrza Navori'
EXEC dodaj_przedmiot_do_gry 108, 'Gniewon????'
EXEC dodaj_przedmiot_do_gry 108, 'Kamienna P??yta Gargulca'
EXEC dodaj_przedmiot_do_gry 108, 'Twoja Dzia??ka'
EXEC dodaj_przedmiot_do_gry 108, 'Ostrze Zniszczonego Kr??la'
EXEC dodaj_przedmiot_do_gry 108, 'Lodowy Kie??'
EXEC dodaj_przedmiot_do_gry 108, 'Alternator Hextech'
EXEC dodaj_przedmiot_do_gry 109, 'Krwio??ercza Hydra'
EXEC dodaj_przedmiot_do_gry 109, 'Skrzydlaty Ksi????ycowy Pancerz'
EXEC dodaj_przedmiot_do_gry 109, 'Eteryczny Duszek'
EXEC dodaj_przedmiot_do_gry 109, 'Pasjonuj??cy Kamienny Totem'
EXEC dodaj_przedmiot_do_gry 109, 'Ro??linna Bariera'
EXEC dodaj_przedmiot_do_gry 109, 'Przysi??ga Rycerska'
EXEC dodaj_przedmiot_do_gry 110, 'Lustro ze Szk??a Bandle'
EXEC dodaj_przedmiot_do_gry 110, 'Oko Herolda'
EXEC dodaj_przedmiot_do_gry 110, 'Mroczne Ostrze Draktharru'
EXEC dodaj_przedmiot_do_gry 110, 'Krwiochron'
EXEC dodaj_przedmiot_do_gry 110, 'Zbroja Stra??nika'
EXEC dodaj_przedmiot_do_gry 110, 'Zamarzni??ta Pi??????'
EXEC dodaj_przedmiot_do_gry 111, 'Vesperia??ski Przyp??yw'
EXEC dodaj_przedmiot_do_gry 111, 'Zapa??'
EXEC dodaj_przedmiot_do_gry 111, 'Ostrze Gniewu Guinsoo'
EXEC dodaj_przedmiot_do_gry 111, 'Kula Stra??nika'
EXEC dodaj_przedmiot_do_gry 111, 'Niszczyciel Marze??'
EXEC dodaj_przedmiot_do_gry 111, 'Relikwiarz Z??otej Jutrzenki'
EXEC dodaj_przedmiot_do_gry 112, 'Kula Stra??nika'
EXEC dodaj_przedmiot_do_gry 112, 'Cieniotw??rca Draktharru'
EXEC dodaj_przedmiot_do_gry 112, 'Ostatni Szept'
EXEC dodaj_przedmiot_do_gry 112, 'Po??eracz'
EXEC dodaj_przedmiot_do_gry 112, 'Widmowy Sierp'
EXEC dodaj_przedmiot_do_gry 112, 'Z??bkowany Sztylet'
EXEC dodaj_przedmiot_do_gry 113, 'Omen Randuina'
EXEC dodaj_przedmiot_do_gry 113, '??ar Bami'
EXEC dodaj_przedmiot_do_gry 113, 'Zbroja Stra??nika'
EXEC dodaj_przedmiot_do_gry 113, 'Lodowy Kie??'
EXEC dodaj_przedmiot_do_gry 113, 'W????owy Kie??'
EXEC dodaj_przedmiot_do_gry 113, 'Rt??ciowy Bu??at'
EXEC dodaj_przedmiot_do_gry 114, 'Maska Otch??ani'
EXEC dodaj_przedmiot_do_gry 114, 'Puklerz Targonu'
EXEC dodaj_przedmiot_do_gry 114, 'Eteryczny Duszek'
EXEC dodaj_przedmiot_do_gry 114, 'Buty Mobilno??ci'
EXEC dodaj_przedmiot_do_gry 114, 'Cezura'
EXEC dodaj_przedmiot_do_gry 114, 'Skrzydlaty Ksi????ycowy Pancerz'
EXEC dodaj_przedmiot_do_gry 115, 'Kostur Archanio??a'
EXEC dodaj_przedmiot_do_gry 115, '??a??cuchy Zguby'
EXEC dodaj_przedmiot_do_gry 115, 'Rt??ciowy Bu??at'
EXEC dodaj_przedmiot_do_gry 115, 'Obuwie Maga'
EXEC dodaj_przedmiot_do_gry 115, 'Wezwanie Kata'
EXEC dodaj_przedmiot_do_gry 115, 'Muramana'
EXEC dodaj_przedmiot_do_gry 116, 'Nocny ??niwiarz'
EXEC dodaj_przedmiot_do_gry 116, 'Wielka Zima'
EXEC dodaj_przedmiot_do_gry 116, '??ar Bami'
EXEC dodaj_przedmiot_do_gry 116, '??wit Srebrzystej'
EXEC dodaj_przedmiot_do_gry 116, 'Relikwiarz Z??otej Jutrzenki'
EXEC dodaj_przedmiot_do_gry 116, 'Wieczna Zima'
EXEC dodaj_przedmiot_do_gry 117, 'Puklerz Targonu'
EXEC dodaj_przedmiot_do_gry 117, 'Miotacz Gwiazd'
EXEC dodaj_przedmiot_do_gry 117, 'Nie??miertelny ??uklerz'
EXEC dodaj_przedmiot_do_gry 117, 'Naramiennik Poszukiwacza'
EXEC dodaj_przedmiot_do_gry 117, 'Kl??twa Icathii'
EXEC dodaj_przedmiot_do_gry 117, 'Blu??nierczy Bo??ek'
EXEC dodaj_przedmiot_do_gry 118, 'Ostrze Nocy'
EXEC dodaj_przedmiot_do_gry 118, 'M??ot Stra??nika'
EXEC dodaj_przedmiot_do_gry 118, 'Klinga Burzy'
EXEC dodaj_przedmiot_do_gry 118, 'Grubosk??rno???? Steraka'
EXEC dodaj_przedmiot_do_gry 118, 'Pogromca Kraken??w'
EXEC dodaj_przedmiot_do_gry 118, 'Zmiana Dalekowidzenia'
EXEC dodaj_przedmiot_do_gry 119, 'Kolekcjoner'
EXEC dodaj_przedmiot_do_gry 119, 'Gniewon????'
EXEC dodaj_przedmiot_do_gry 119, 'Pancerniaki'
EXEC dodaj_przedmiot_do_gry 119, '??elazny Bicz'
EXEC dodaj_przedmiot_do_gry 119, '??za Bogini'
EXEC dodaj_przedmiot_do_gry 119, 'Z??ota Szpatu??ka'
EXEC dodaj_przedmiot_do_gry 120, 'Zbroja Stra??nika'
EXEC dodaj_przedmiot_do_gry 120, 'Aksjomatyczny ??uk'
EXEC dodaj_przedmiot_do_gry 120, 'Lodowa R??kawica'
EXEC dodaj_przedmiot_do_gry 120, 'Nieopisany Paso??yt'
EXEC dodaj_przedmiot_do_gry 120, 'Stalowe Serce'
EXEC dodaj_przedmiot_do_gry 120, 'Rt??ciowy Bu??at'
EXEC dodaj_przedmiot_do_gry 121, 'Szczelinotw??rca'
EXEC dodaj_przedmiot_do_gry 121, 'Manamune'
EXEC dodaj_przedmiot_do_gry 121, 'Kryszta??owy Karwasz'
EXEC dodaj_przedmiot_do_gry 121, 'Aksjomatyczny ??uk'
EXEC dodaj_przedmiot_do_gry 121, 'R????d??ka Wiek??w'
EXEC dodaj_przedmiot_do_gry 121, 'Ostrze Stra??nika'
EXEC dodaj_przedmiot_do_gry 122, 'Krwio??ercza Hydra'
EXEC dodaj_przedmiot_do_gry 122, 'Buty Mobilno??ci'
EXEC dodaj_przedmiot_do_gry 122, 'Cierpienie Liandry''ego'
EXEC dodaj_przedmiot_do_gry 122, 'Widmowa Os??ona'
EXEC dodaj_przedmiot_do_gry 122, 'Katalizator Eon??w'
EXEC dodaj_przedmiot_do_gry 122, 'Poch??aniacz Urok??w'
EXEC dodaj_przedmiot_do_gry 123, 'Krwio??ercza Hydra'
EXEC dodaj_przedmiot_do_gry 123, 'Stalowe Serce'
EXEC dodaj_przedmiot_do_gry 123, 'Pancerniaki'
EXEC dodaj_przedmiot_do_gry 123, 'Morellonomicon'
EXEC dodaj_przedmiot_do_gry 123, 'Zas??ona R??wno??ci'
EXEC dodaj_przedmiot_do_gry 123, 'Boski ??amacz'
EXEC dodaj_przedmiot_do_gry 124, 'Wielka Zima'
EXEC dodaj_przedmiot_do_gry 124, 'Plemienna Zbroja'
EXEC dodaj_przedmiot_do_gry 124, '??wietlista Cnota'
EXEC dodaj_przedmiot_do_gry 124, 'Ch??eptacz Posoki'
EXEC dodaj_przedmiot_do_gry 124, 'Siedzisko Dow??dcy'
EXEC dodaj_przedmiot_do_gry 124, 'Czarna W????cznia Kalisty'
EXEC dodaj_przedmiot_do_gry 125, 'Moc Tr??jcy'
EXEC dodaj_przedmiot_do_gry 125, 'Lewiatan'
EXEC dodaj_przedmiot_do_gry 125, 'B??ogos??awie??stwo Mikaela'
EXEC dodaj_przedmiot_do_gry 125, 'Z??ota Szpatu??ka'
EXEC dodaj_przedmiot_do_gry 125, 'M??ot Bojowy Caulfielda'
EXEC dodaj_przedmiot_do_gry 125, 'Kula Zag??ady'
EXEC dodaj_przedmiot_do_gry 126, 'Ostrze Niesko??czono??ci'
EXEC dodaj_przedmiot_do_gry 126, 'Huragan Runaana'
EXEC dodaj_przedmiot_do_gry 126, '??miertelne Przypomnienie'
EXEC dodaj_przedmiot_do_gry 126, '??miertelne Przypomnienie'
EXEC dodaj_przedmiot_do_gry 126, 'Rt??ciowa Szarfa'
EXEC dodaj_przedmiot_do_gry 126, 'M??ot Bojowy Caulfielda'
EXEC dodaj_przedmiot_do_gry 127, 'Turbochemiczny Pojemnik'
EXEC dodaj_przedmiot_do_gry 127, 'Kl??twa Icathii'
EXEC dodaj_przedmiot_do_gry 127, 'Lodowy Kie??'
EXEC dodaj_przedmiot_do_gry 127, 'B??ogos??awie??stwo Mikaela'
EXEC dodaj_przedmiot_do_gry 127, 'Ognisty Trybularz'
EXEC dodaj_przedmiot_do_gry 127, 'Kosmiczny Impuls'
EXEC dodaj_przedmiot_do_gry 128, 'Nagolenniki Berserkera'
EXEC dodaj_przedmiot_do_gry 128, 'Kostur Archanio??a'
EXEC dodaj_przedmiot_do_gry 128, 'Wieczna Zima'
EXEC dodaj_przedmiot_do_gry 128, 'Buty Mobilno??ci'
EXEC dodaj_przedmiot_do_gry 128, 'Przysi??ga Rycerska'
EXEC dodaj_przedmiot_do_gry 128, 'Nocny ??niwiarz'
EXEC dodaj_przedmiot_do_gry 129, 'Niszczyciel Marze??'
EXEC dodaj_przedmiot_do_gry 129, 'Rozgrzany Klejnot'
EXEC dodaj_przedmiot_do_gry 129, 'Zab??jczy Kapelusz Rabadona'
EXEC dodaj_przedmiot_do_gry 129, 'Moc Niesko??czono??ci'
EXEC dodaj_przedmiot_do_gry 129, 'Taniec ??mierci'
EXEC dodaj_przedmiot_do_gry 129, 'Gniewon????'
EXEC dodaj_przedmiot_do_gry 130, 'Rt??ciowa Szarfa'
EXEC dodaj_przedmiot_do_gry 130, 'Krwiochron'
EXEC dodaj_przedmiot_do_gry 130, 'Konwergencja Zeke''a'
EXEC dodaj_przedmiot_do_gry 130, 'B??ogos??awie??stwo Mikaela'
EXEC dodaj_przedmiot_do_gry 130, 'Szpon Ciemnego Typa'
EXEC dodaj_przedmiot_do_gry 130, 'Pancerz Umrzyka'
EXEC dodaj_przedmiot_do_gry 131, 'Kolczasta Kolczuga'
EXEC dodaj_przedmiot_do_gry 131, 'Wieczna Zmarzlina'
EXEC dodaj_przedmiot_do_gry 131, 'Wieczna Zmarzlina'
EXEC dodaj_przedmiot_do_gry 131, 'Nawa??nica Luden'
EXEC dodaj_przedmiot_do_gry 131, 'Z??ota Szpatu??ka'
EXEC dodaj_przedmiot_do_gry 131, 'Krwiochron'
EXEC dodaj_przedmiot_do_gry 132, '??za Bogini'
EXEC dodaj_przedmiot_do_gry 132, 'Kostur Pustki'
EXEC dodaj_przedmiot_do_gry 132, 'Blu??nierczy Bo??ek'
EXEC dodaj_przedmiot_do_gry 132, 'Nadej??cie Zimy'
EXEC dodaj_przedmiot_do_gry 132, 'Muramana'
EXEC dodaj_przedmiot_do_gry 132, 'Cezura'
EXEC dodaj_przedmiot_do_gry 133, 'Pozdrowienia Lorda Dominika'
EXEC dodaj_przedmiot_do_gry 133, 'Ostrze Nocy'
EXEC dodaj_przedmiot_do_gry 133, 'Muramana'
EXEC dodaj_przedmiot_do_gry 133, 'Stalowe Naramienniki'
EXEC dodaj_przedmiot_do_gry 133, 'Skrzydlaty Ksi????ycowy Pancerz'
EXEC dodaj_przedmiot_do_gry 133, 'Nawa??nica Luden'
EXEC dodaj_przedmiot_do_gry 134, 'Lament Liandry''ego'
EXEC dodaj_przedmiot_do_gry 134, 'Ko??czan Po??udnia'
EXEC dodaj_przedmiot_do_gry 134, 'Rt??ciowa Szarfa'
EXEC dodaj_przedmiot_do_gry 134, 'Oblicze Ducha'
EXEC dodaj_przedmiot_do_gry 134, 'Egida Legionu'
EXEC dodaj_przedmiot_do_gry 134, 'Kosmiczny Impuls'
EXEC dodaj_przedmiot_do_gry 135, 'Klejnot Rozpadu'
EXEC dodaj_przedmiot_do_gry 135, 'Relikwiarz Z??otej Jutrzenki'
EXEC dodaj_przedmiot_do_gry 135, 'Szybkie Ostrza Navori'
EXEC dodaj_przedmiot_do_gry 135, 'S??oneczna Egida'
EXEC dodaj_przedmiot_do_gry 135, 'Ko??czan Po??udnia'
EXEC dodaj_przedmiot_do_gry 135, 'Odkupienie'
EXEC dodaj_przedmiot_do_gry 136, 'Mro??ne Serce'
EXEC dodaj_przedmiot_do_gry 136, 'Klejnot Rozpadu'
EXEC dodaj_przedmiot_do_gry 136, 'Omen Randuina'
EXEC dodaj_przedmiot_do_gry 136, 'Kamienna P??yta Gargulca'
EXEC dodaj_przedmiot_do_gry 136, 'Oko Herolda'
EXEC dodaj_przedmiot_do_gry 136, 'Cezura'
EXEC dodaj_przedmiot_do_gry 137, 'Obuwie Maga'
EXEC dodaj_przedmiot_do_gry 137, 'Pogromca Kraken??w'
EXEC dodaj_przedmiot_do_gry 137, 'Kuk??a Stracha na Wr??ble'
EXEC dodaj_przedmiot_do_gry 137, 'Nieopisany Paso??yt'
EXEC dodaj_przedmiot_do_gry 137, 'Ostrze Nocy'
EXEC dodaj_przedmiot_do_gry 137, 'Z??b Nashora'
EXEC dodaj_przedmiot_do_gry 138, '??miertelne Przypomnienie'
EXEC dodaj_przedmiot_do_gry 138, 'Ognisty Trybularz'
EXEC dodaj_przedmiot_do_gry 138, 'Demoniczny U??cisk'
EXEC dodaj_przedmiot_do_gry 138, 'Twoja Dzia??ka'
EXEC dodaj_przedmiot_do_gry 138, 'Nieopisany Paso??yt'
EXEC dodaj_przedmiot_do_gry 138, 'Wielka Zima'
EXEC dodaj_przedmiot_do_gry 139, 'Grubosk??rno???? Steraka'
EXEC dodaj_przedmiot_do_gry 139, '??wietlista Cnota'
EXEC dodaj_przedmiot_do_gry 139, 'Kryszta??owy Kostur Rylai'
EXEC dodaj_przedmiot_do_gry 139, 'Blask'
EXEC dodaj_przedmiot_do_gry 139, 'Nawa??nica Luden'
EXEC dodaj_przedmiot_do_gry 139, 'Rt??ciowa Szarfa'
EXEC dodaj_przedmiot_do_gry 140, 'Kad??ubo??amacz'
EXEC dodaj_przedmiot_do_gry 140, 'Puklerz Targonu'
EXEC dodaj_przedmiot_do_gry 140, 'Naramienniki spod Bia??ej Ska??y'
EXEC dodaj_przedmiot_do_gry 140, 'Ulepszony Aeropak'
EXEC dodaj_przedmiot_do_gry 140, 'Widmowe Ostrze Youmuu'
EXEC dodaj_przedmiot_do_gry 140, 'Mro??ne Serce'
EXEC dodaj_przedmiot_do_gry 141, 'Katalizator Eon??w'
EXEC dodaj_przedmiot_do_gry 141, 'Ionia??skie Buty Jasno??ci Umys??u'
EXEC dodaj_przedmiot_do_gry 141, 'Turbochemiczny Pojemnik'
EXEC dodaj_przedmiot_do_gry 141, 'Moc Niesko??czono??ci'
EXEC dodaj_przedmiot_do_gry 141, 'Zmiana Dalekowidzenia'
EXEC dodaj_przedmiot_do_gry 141, 'Krwio??ercza Hydra'
EXEC dodaj_przedmiot_do_gry 142, 'Naszyjnik ??elaznych Solari'
EXEC dodaj_przedmiot_do_gry 142, 'Szpon Ciemnego Typa'
EXEC dodaj_przedmiot_do_gry 142, 'Skupienie Horyzontalne'
EXEC dodaj_przedmiot_do_gry 142, 'W????owy Kie??'
EXEC dodaj_przedmiot_do_gry 142, 'Szybkie Ostrza Navori'
EXEC dodaj_przedmiot_do_gry 142, 'Pozdrowienia Lorda Dominika'
EXEC dodaj_przedmiot_do_gry 143, 'Ch??eptacz Posoki'
EXEC dodaj_przedmiot_do_gry 143, 'Ch??eptacz Posoki'
EXEC dodaj_przedmiot_do_gry 143, 'Wieczna Zima'
EXEC dodaj_przedmiot_do_gry 143, 'Czarny Tasak'
EXEC dodaj_przedmiot_do_gry 143, 'U??cisk Serafina'
EXEC dodaj_przedmiot_do_gry 143, 'Muramana'
EXEC dodaj_przedmiot_do_gry 144, 'Zab??jczy Kapelusz Rabadona'
EXEC dodaj_przedmiot_do_gry 144, 'Buty Pr??dko??ci'
EXEC dodaj_przedmiot_do_gry 144, 'Jak''Sho Zmienny'
EXEC dodaj_przedmiot_do_gry 144, '??amacz Falangi'
EXEC dodaj_przedmiot_do_gry 144, 'Tiamat'
EXEC dodaj_przedmiot_do_gry 144, 'Z??ota Szpatu??ka'
EXEC dodaj_przedmiot_do_gry 145, 'Gniewon????'
EXEC dodaj_przedmiot_do_gry 145, 'Czujny Kamienny Totem'
EXEC dodaj_przedmiot_do_gry 145, 'Ogniolubny Top??r'
EXEC dodaj_przedmiot_do_gry 145, 'Soczewka Wyroczni'
EXEC dodaj_przedmiot_do_gry 145, 'Czujny Kamienny Totem'
EXEC dodaj_przedmiot_do_gry 145, 'Ostrze Gniewu Guinsoo'
EXEC dodaj_przedmiot_do_gry 146, 'Kl??twa Icathii'
EXEC dodaj_przedmiot_do_gry 146, 'Pozdrowienia Lorda Dominika'
EXEC dodaj_przedmiot_do_gry 146, 'Moc Tr??jcy'
EXEC dodaj_przedmiot_do_gry 146, 'Koniec Rozumu'
EXEC dodaj_przedmiot_do_gry 146, 'Zmora Licza'
EXEC dodaj_przedmiot_do_gry 146, 'Imperialny Mandat'
EXEC dodaj_przedmiot_do_gry 147, 'Tiamat'
EXEC dodaj_przedmiot_do_gry 147, 'Relikwiarz Z??otej Jutrzenki'
EXEC dodaj_przedmiot_do_gry 147, 'Z??b Nashora'
EXEC dodaj_przedmiot_do_gry 147, 'Naszyjnik ??elaznych Solari'
EXEC dodaj_przedmiot_do_gry 147, 'Niesko??czona Konwergencja'
EXEC dodaj_przedmiot_do_gry 147, 'Ognista Armata'
EXEC dodaj_przedmiot_do_gry 148, 'Od??amek Prawdziwego Lodu'
EXEC dodaj_przedmiot_do_gry 148, 'Zmiana Dalekowidzenia'
EXEC dodaj_przedmiot_do_gry 148, 'Taniec ??mierci'
EXEC dodaj_przedmiot_do_gry 148, 'Lodowy Kie??'
EXEC dodaj_przedmiot_do_gry 148, 'Wykradacz Dusz Mejai'
EXEC dodaj_przedmiot_do_gry 148, 'Plemienna Zbroja'
EXEC dodaj_przedmiot_do_gry 149, 'Naszyjnik ??elaznych Solari'
EXEC dodaj_przedmiot_do_gry 149, 'Przysi??ga Rycerska'
EXEC dodaj_przedmiot_do_gry 149, 'Tajfun'
EXEC dodaj_przedmiot_do_gry 149, 'Ostrze Zniszczonego Kr??la'
EXEC dodaj_przedmiot_do_gry 149, 'Naramiennik Poszukiwacza'
EXEC dodaj_przedmiot_do_gry 149, 'Po??wi??cenie W????owej Ofiary'
EXEC dodaj_przedmiot_do_gry 150, 'Zab??jczy Kapelusz Rabadona'
EXEC dodaj_przedmiot_do_gry 150, 'Kolczasta Kolczuga'
EXEC dodaj_przedmiot_do_gry 150, 'Odkupienie'
EXEC dodaj_przedmiot_do_gry 150, 'Stalowe Serce'
EXEC dodaj_przedmiot_do_gry 150, 'Po??wi??cenie W????owej Ofiary'
EXEC dodaj_przedmiot_do_gry 150, 'Pancerniaki'
EXEC dodaj_przedmiot_do_gry 151, 'Blask'
EXEC dodaj_przedmiot_do_gry 151, 'Soczewka Wyroczni'
EXEC dodaj_przedmiot_do_gry 151, 'Eteryczny Duszek'
EXEC dodaj_przedmiot_do_gry 151, 'Wieczna Zima'
EXEC dodaj_przedmiot_do_gry 151, 'Nadej??cie Zimy'
EXEC dodaj_przedmiot_do_gry 151, 'Demoniczny U??cisk'
EXEC dodaj_przedmiot_do_gry 152, 'Syzygium'
EXEC dodaj_przedmiot_do_gry 152, 'Klejnot Rozpadu'
EXEC dodaj_przedmiot_do_gry 152, 'Cezura'
EXEC dodaj_przedmiot_do_gry 152, 'Czujny Kamienny Totem'
EXEC dodaj_przedmiot_do_gry 152, 'U??cisk Serafina'
EXEC dodaj_przedmiot_do_gry 152, 'Hextechowy Pas Rakietowy'
EXEC dodaj_przedmiot_do_gry 153, 'Buty Pr??dko??ci'
EXEC dodaj_przedmiot_do_gry 153, 'Przysi??ga Rycerska'
EXEC dodaj_przedmiot_do_gry 153, 'Zaginiony Rozdzia??'
EXEC dodaj_przedmiot_do_gry 153, 'Plemienna Zbroja'
EXEC dodaj_przedmiot_do_gry 153, 'Nie??miertelny ??uklerz'
EXEC dodaj_przedmiot_do_gry 153, 'B??ogos??awie??stwo Mikaela'
EXEC dodaj_przedmiot_do_gry 154, 'Zamarzni??ta Pi??????'
EXEC dodaj_przedmiot_do_gry 154, 'Pogromca Kraken??w'
EXEC dodaj_przedmiot_do_gry 154, 'Ulepszony Aeropak'
EXEC dodaj_przedmiot_do_gry 154, 'Oblicze Ducha'
EXEC dodaj_przedmiot_do_gry 154, 'Kad??ubo??amacz'
EXEC dodaj_przedmiot_do_gry 154, 'Szpon Ciemnego Typa'
EXEC dodaj_przedmiot_do_gry 155, 'Blask'
EXEC dodaj_przedmiot_do_gry 155, '??ar Bami'
EXEC dodaj_przedmiot_do_gry 155, 'Kosmiczny Impuls'
EXEC dodaj_przedmiot_do_gry 155, '??miertelne Przypomnienie'
EXEC dodaj_przedmiot_do_gry 155, '??wietlista Cnota'
EXEC dodaj_przedmiot_do_gry 155, 'Ko??czan Po??udnia'
EXEC dodaj_przedmiot_do_gry 156, 'Si??a Natury'
EXEC dodaj_przedmiot_do_gry 156, 'P????ksi????ycowe Ostrze Harrowing'
EXEC dodaj_przedmiot_do_gry 156, 'Klejnot Rozpadu'
EXEC dodaj_przedmiot_do_gry 156, 'Nagolenniki Berserkera'
EXEC dodaj_przedmiot_do_gry 156, 'Zaginiony Rozdzia??'
EXEC dodaj_przedmiot_do_gry 156, 'Buty Mobilno??ci'
EXEC dodaj_przedmiot_do_gry 157, 'Skupienie Horyzontalne'
EXEC dodaj_przedmiot_do_gry 157, 'Z??b Nashora'
EXEC dodaj_przedmiot_do_gry 157, 'Ostrze Stra??nika'
EXEC dodaj_przedmiot_do_gry 157, 'Ko??czan Po??udnia'
EXEC dodaj_przedmiot_do_gry 157, 'Za??mienie'
EXEC dodaj_przedmiot_do_gry 157, 'Ro??linna Bariera'
EXEC dodaj_przedmiot_do_gry 158, 'Pancerz Umrzyka'
EXEC dodaj_przedmiot_do_gry 158, 'Uraza Seryldy'
EXEC dodaj_przedmiot_do_gry 158, 'Naramiennik Poszukiwacza'
EXEC dodaj_przedmiot_do_gry 158, 'Wieczna Zima'
EXEC dodaj_przedmiot_do_gry 158, 'Cieniotw??rca Draktharru'
EXEC dodaj_przedmiot_do_gry 158, 'Czarci Kodeks'
EXEC dodaj_przedmiot_do_gry 159, 'Ko??czan Po??udnia'
EXEC dodaj_przedmiot_do_gry 159, 'Pot??ga Wichury'
EXEC dodaj_przedmiot_do_gry 159, 'Baczny Kamienny Totem'
EXEC dodaj_przedmiot_do_gry 159, 'Tiamat'
EXEC dodaj_przedmiot_do_gry 159, 'Relikwiarz Z??otej Jutrzenki'
EXEC dodaj_przedmiot_do_gry 159, 'Soczewka Wyroczni'
EXEC dodaj_przedmiot_do_gry 160, 'Kostur Pustki'
EXEC dodaj_przedmiot_do_gry 160, '??za Bogini'
EXEC dodaj_przedmiot_do_gry 160, 'Baczny Kamienny Totem'
EXEC dodaj_przedmiot_do_gry 160, 'Moc Tr??jcy'
EXEC dodaj_przedmiot_do_gry 160, 'Soczewka Wyroczni'
EXEC dodaj_przedmiot_do_gry 160, 'Kamizelka Cierniowa'
EXEC dodaj_przedmiot_do_gry 161, 'Egida Legionu'
EXEC dodaj_przedmiot_do_gry 161, 'Szpon Ciemnego Typa'
EXEC dodaj_przedmiot_do_gry 161, 'Alternator Hextech'
EXEC dodaj_przedmiot_do_gry 161, 'M??ot Bojowy Caulfielda'
EXEC dodaj_przedmiot_do_gry 161, 'P??omie?? Cienia'
EXEC dodaj_przedmiot_do_gry 161, 'Rt??ciowy Bu??at'
EXEC dodaj_przedmiot_do_gry 162, 'Czujny Kamienny Totem'
EXEC dodaj_przedmiot_do_gry 162, 'Krwio??ercza Hydra'
EXEC dodaj_przedmiot_do_gry 162, 'Nocny ??niwiarz'
EXEC dodaj_przedmiot_do_gry 162, 'Kolekcjoner'
EXEC dodaj_przedmiot_do_gry 162, 'Obuwie Merkurego'
EXEC dodaj_przedmiot_do_gry 162, 'Ko??czan Po??udnia'
EXEC dodaj_przedmiot_do_gry 163, 'Tajfun'
EXEC dodaj_przedmiot_do_gry 163, 'Maska Otch??ani'
EXEC dodaj_przedmiot_do_gry 163, 'Kostur P??yn??cej Wody'
EXEC dodaj_przedmiot_do_gry 163, 'Niesko??czona Konwergencja'
EXEC dodaj_przedmiot_do_gry 163, 'Ogniolubny Top??r'
EXEC dodaj_przedmiot_do_gry 163, 'Rozgrzany Klejnot'
EXEC dodaj_przedmiot_do_gry 164, 'Oko Luden'
EXEC dodaj_przedmiot_do_gry 164, 'Widmowy Tancerz'
EXEC dodaj_przedmiot_do_gry 164, 'Kosa Czarnej Mg??y'
EXEC dodaj_przedmiot_do_gry 164, 'Z??b Nashora'
EXEC dodaj_przedmiot_do_gry 164, 'Demoniczny U??cisk'
EXEC dodaj_przedmiot_do_gry 164, 'Zmora Licza'
EXEC dodaj_przedmiot_do_gry 165, 'Krwiopijec'
EXEC dodaj_przedmiot_do_gry 165, 'Oko Herolda'
EXEC dodaj_przedmiot_do_gry 165, 'Ostrze Z??odziejki Czar??w'
EXEC dodaj_przedmiot_do_gry 165, 'Poch??aniacz Urok??w'
EXEC dodaj_przedmiot_do_gry 165, 'Wielka Zima'
EXEC dodaj_przedmiot_do_gry 165, 'Skupienie Horyzontalne'
EXEC dodaj_przedmiot_do_gry 166, 'Lewiatan'
EXEC dodaj_przedmiot_do_gry 166, 'Ko??czan Po??udnia'
EXEC dodaj_przedmiot_do_gry 166, 'Za??mienie'
EXEC dodaj_przedmiot_do_gry 166, 'Ostrze Niesko??czono??ci'
EXEC dodaj_przedmiot_do_gry 166, 'Kosa Czarnej Mg??y'
EXEC dodaj_przedmiot_do_gry 166, 'Pot??ga Wichury'
EXEC dodaj_przedmiot_do_gry 167, 'Alternator Hextech'
EXEC dodaj_przedmiot_do_gry 167, 'Ionia??skie Buty Jasno??ci Umys??u'
EXEC dodaj_przedmiot_do_gry 167, 'Kolczasta Kolczuga'
EXEC dodaj_przedmiot_do_gry 167, 'Za??mienie'
EXEC dodaj_przedmiot_do_gry 167, 'Gniewon????'
EXEC dodaj_przedmiot_do_gry 167, 'Bogob??jca'
EXEC dodaj_przedmiot_do_gry 168, 'Kuk??a Stracha na Wr??ble'
EXEC dodaj_przedmiot_do_gry 168, 'Mroczne Ostrze Draktharru'
EXEC dodaj_przedmiot_do_gry 168, 'Ognista Armata'
EXEC dodaj_przedmiot_do_gry 168, 'Krwiopijec'
EXEC dodaj_przedmiot_do_gry 168, 'U??cisk Serafina'
EXEC dodaj_przedmiot_do_gry 168, 'Kamizelka Cierniowa'
EXEC dodaj_przedmiot_do_gry 169, 'Imperialny Mandat'
EXEC dodaj_przedmiot_do_gry 169, 'Tiamat'
EXEC dodaj_przedmiot_do_gry 169, 'Mro??ne Serce'
EXEC dodaj_przedmiot_do_gry 169, 'Nadej??cie Zimy'
EXEC dodaj_przedmiot_do_gry 169, 'Taniec ??mierci'
EXEC dodaj_przedmiot_do_gry 169, 'Demoniczny U??cisk'
EXEC dodaj_przedmiot_do_gry 170, 'P????ksi????ycowe Ostrze Harrowing'
EXEC dodaj_przedmiot_do_gry 170, 'Zmora Licza'
EXEC dodaj_przedmiot_do_gry 170, 'Kl??twa Icathii'
EXEC dodaj_przedmiot_do_gry 170, 'Czarna W????cznia Kalisty'
EXEC dodaj_przedmiot_do_gry 170, 'Rt??ciowy Bu??at'
EXEC dodaj_przedmiot_do_gry 170, 'Nocny ??niwiarz'
EXEC dodaj_przedmiot_do_gry 171, 'Poch??aniacz Urok??w'
EXEC dodaj_przedmiot_do_gry 171, 'Nawa??nica Luden'
EXEC dodaj_przedmiot_do_gry 171, 'Kolekcjoner'
EXEC dodaj_przedmiot_do_gry 171, 'Siedzisko Dow??dcy'
EXEC dodaj_przedmiot_do_gry 171, 'Niszczyciel Marze??'
EXEC dodaj_przedmiot_do_gry 171, 'Konwergencja Zeke''a'
EXEC dodaj_przedmiot_do_gry 172, 'Konwergencja Zeke''a'
EXEC dodaj_przedmiot_do_gry 172, 'Turbochemiczny Pojemnik'
EXEC dodaj_przedmiot_do_gry 172, 'Nie??miertelny ??uklerz'
EXEC dodaj_przedmiot_do_gry 172, 'Ro??linna Bariera'
EXEC dodaj_przedmiot_do_gry 172, 'Moc Niesko??czono??ci'
EXEC dodaj_przedmiot_do_gry 172, 'Nadej??cie Zimy'
EXEC dodaj_przedmiot_do_gry 173, 'Tajfun'
EXEC dodaj_przedmiot_do_gry 173, 'Plemienna Zbroja'
EXEC dodaj_przedmiot_do_gry 173, 'Demoniczny U??cisk'
EXEC dodaj_przedmiot_do_gry 173, 'Naramiennik Poszukiwacza'
EXEC dodaj_przedmiot_do_gry 173, 'Lewiatan'
EXEC dodaj_przedmiot_do_gry 173, 'Ostrze Gniewu Guinsoo'
EXEC dodaj_przedmiot_do_gry 174, '??amacz Falangi'
EXEC dodaj_przedmiot_do_gry 174, 'Imperialny Mandat'
EXEC dodaj_przedmiot_do_gry 174, 'Czarna W????cznia Kalisty'
EXEC dodaj_przedmiot_do_gry 174, 'Korona Roztrzaskanej Kr??lowej'
EXEC dodaj_przedmiot_do_gry 174, 'Klinga Burzy'
EXEC dodaj_przedmiot_do_gry 174, 'Demoniczny U??cisk'
EXEC dodaj_przedmiot_do_gry 175, 'Reliktowa Tarcza'
EXEC dodaj_przedmiot_do_gry 175, 'Chempunkowy ??a??cuchowy Miecz'
EXEC dodaj_przedmiot_do_gry 175, 'Bastion G??ry'
EXEC dodaj_przedmiot_do_gry 175, 'Pot??ga Wichury'
EXEC dodaj_przedmiot_do_gry 175, 'Twoja Dzia??ka'
EXEC dodaj_przedmiot_do_gry 175, 'Widmowa Os??ona'
EXEC dodaj_przedmiot_do_gry 176, 'Kryszta??owy Karwasz'
EXEC dodaj_przedmiot_do_gry 176, 'Wykradacz Dusz Mejai'
EXEC dodaj_przedmiot_do_gry 176, 'Zas??ona R??wno??ci'
EXEC dodaj_przedmiot_do_gry 176, 'Od??amek Prawdziwego Lodu'
EXEC dodaj_przedmiot_do_gry 176, 'Paszcza Malmortiusa'
EXEC dodaj_przedmiot_do_gry 176, 'Buty Mobilno??ci'
EXEC dodaj_przedmiot_do_gry 177, 'Uraza Seryldy'
EXEC dodaj_przedmiot_do_gry 177, 'Z??bkowany Sztylet'
EXEC dodaj_przedmiot_do_gry 177, 'Odnowienie Kamienia Ksi????ycowego'
EXEC dodaj_przedmiot_do_gry 177, '??wit Srebrzystej'
EXEC dodaj_przedmiot_do_gry 177, 'Ochraniacze z Runicznej Stali'
EXEC dodaj_przedmiot_do_gry 177, 'Obuwie Maga'
EXEC dodaj_przedmiot_do_gry 178, 'Pancerniaki'
EXEC dodaj_przedmiot_do_gry 178, 'Naramienniki spod Bia??ej Ska??y'
EXEC dodaj_przedmiot_do_gry 178, 'Czarna W????cznia Kalisty'
EXEC dodaj_przedmiot_do_gry 178, 'Blask'
EXEC dodaj_przedmiot_do_gry 178, 'Klinga Burzy'
EXEC dodaj_przedmiot_do_gry 178, 'Moc Niesko??czono??ci'
EXEC dodaj_przedmiot_do_gry 179, '??a??cuchy Zguby'
EXEC dodaj_przedmiot_do_gry 179, 'Po??eracz'
EXEC dodaj_przedmiot_do_gry 179, 'Demoniczny U??cisk'
EXEC dodaj_przedmiot_do_gry 179, 'Zbroja Stra??nika'
EXEC dodaj_przedmiot_do_gry 179, 'Morellonomicon'
EXEC dodaj_przedmiot_do_gry 179, '??za Bogini'
EXEC dodaj_przedmiot_do_gry 180, 'Oko Herolda'
EXEC dodaj_przedmiot_do_gry 180, 'Kula Zag??ady'
EXEC dodaj_przedmiot_do_gry 180, 'Aksjomatyczny ??uk'
EXEC dodaj_przedmiot_do_gry 180, 'Kuk??a Stracha na Wr??ble'
EXEC dodaj_przedmiot_do_gry 180, 'Czarna W????cznia Kalisty'
EXEC dodaj_przedmiot_do_gry 180, 'Paszcza Malmortiusa'
EXEC dodaj_przedmiot_do_gry 181, 'Uraza Seryldy'
EXEC dodaj_przedmiot_do_gry 181, 'Nadej??cie Zimy'
EXEC dodaj_przedmiot_do_gry 181, 'Pancerniaki'
EXEC dodaj_przedmiot_do_gry 181, 'Puklerz Targonu'
EXEC dodaj_przedmiot_do_gry 181, 'Widmowy Sierp'
EXEC dodaj_przedmiot_do_gry 181, 'Maska Otch??ani'
EXEC dodaj_przedmiot_do_gry 182, 'Rozgrzany Klejnot'
EXEC dodaj_przedmiot_do_gry 182, 'Naszyjnik ??elaznych Solari'
EXEC dodaj_przedmiot_do_gry 182, 'Aksjomatyczny ??uk'
EXEC dodaj_przedmiot_do_gry 182, 'Przysi??ga Rycerska'
EXEC dodaj_przedmiot_do_gry 182, 'Wielka Zima'
EXEC dodaj_przedmiot_do_gry 182, 'Kolczasta Kolczuga'
EXEC dodaj_przedmiot_do_gry 183, 'Tiamat'
EXEC dodaj_przedmiot_do_gry 183, 'Relikwiarz Z??otej Jutrzenki'
EXEC dodaj_przedmiot_do_gry 183, 'Pancerniaki'
EXEC dodaj_przedmiot_do_gry 183, 'Zas??ona R??wno??ci'
EXEC dodaj_przedmiot_do_gry 183, '??amacz Falangi'
EXEC dodaj_przedmiot_do_gry 183, 'Korona Roztrzaskanej Kr??lowej'
EXEC dodaj_przedmiot_do_gry 184, 'Bogob??jca'
EXEC dodaj_przedmiot_do_gry 184, 'Naramiennik Poszukiwacza'
EXEC dodaj_przedmiot_do_gry 184, 'Kl??twa Icathii'
EXEC dodaj_przedmiot_do_gry 184, 'Ognista Armata'
EXEC dodaj_przedmiot_do_gry 184, 'Krwio??ercza Hydra'
EXEC dodaj_przedmiot_do_gry 184, 'Wysysaj??ce Spojrzenie'
EXEC dodaj_przedmiot_do_gry 185, 'Lodowy Kie??'
EXEC dodaj_przedmiot_do_gry 185, 'Taniec ??mierci'
EXEC dodaj_przedmiot_do_gry 185, 'Bastion G??ry'
EXEC dodaj_przedmiot_do_gry 185, 'Odkupienie'
EXEC dodaj_przedmiot_do_gry 185, 'Mro??ne Serce'
EXEC dodaj_przedmiot_do_gry 185, 'Po??eracz'
EXEC dodaj_przedmiot_do_gry 186, 'Nie??miertelny ??uklerz'
EXEC dodaj_przedmiot_do_gry 186, 'Rt??ciowa Szarfa'
EXEC dodaj_przedmiot_do_gry 186, 'Zab??jczy Kapelusz Rabadona'
EXEC dodaj_przedmiot_do_gry 186, 'Z??b Nashora'
EXEC dodaj_przedmiot_do_gry 186, 'Nocny ??niwiarz'
EXEC dodaj_przedmiot_do_gry 186, 'Koniec Rozumu'
EXEC dodaj_przedmiot_do_gry 187, 'Czarna W????cznia Kalisty'
EXEC dodaj_przedmiot_do_gry 187, 'Koniec Rozumu'
EXEC dodaj_przedmiot_do_gry 187, 'Szpon Ciemnego Typa'
EXEC dodaj_przedmiot_do_gry 187, 'Odnowienie Kamienia Ksi????ycowego'
EXEC dodaj_przedmiot_do_gry 187, 'Ionia??skie Buty Jasno??ci Umys??u'
EXEC dodaj_przedmiot_do_gry 187, 'Klejnot Rozpadu'
EXEC dodaj_przedmiot_do_gry 188, 'Gniewon????'
EXEC dodaj_przedmiot_do_gry 188, 'Skupienie Horyzontalne'
EXEC dodaj_przedmiot_do_gry 188, 'Stalowe Naramienniki'
EXEC dodaj_przedmiot_do_gry 188, 'Kostur P??yn??cej Wody'
EXEC dodaj_przedmiot_do_gry 188, 'Ognista Armata'
EXEC dodaj_przedmiot_do_gry 188, 'Wykradacz Dusz Mejai'
EXEC dodaj_przedmiot_do_gry 189, 'Widmowy Tancerz'
EXEC dodaj_przedmiot_do_gry 189, 'Przysi??ga Rycerska'
EXEC dodaj_przedmiot_do_gry 189, 'Gniewon????'
EXEC dodaj_przedmiot_do_gry 189, 'Kula Zag??ady'
EXEC dodaj_przedmiot_do_gry 189, '??wit Srebrzystej'
EXEC dodaj_przedmiot_do_gry 189, 'Widmowe Ostrze Youmuu'
EXEC dodaj_przedmiot_do_gry 190, 'Za??mienie'
EXEC dodaj_przedmiot_do_gry 190, 'Grubosk??rno???? Steraka'
EXEC dodaj_przedmiot_do_gry 190, 'Za??mienie'
EXEC dodaj_przedmiot_do_gry 190, 'M??ot Stra??nika'
EXEC dodaj_przedmiot_do_gry 190, 'Po??wi??cenie W????owej Ofiary'
EXEC dodaj_przedmiot_do_gry 190, 'Konwergencja Zeke''a'
EXEC dodaj_przedmiot_do_gry 191, 'Po??wi??cenie W????owej Ofiary'
EXEC dodaj_przedmiot_do_gry 191, '??wit Srebrzystej'
EXEC dodaj_przedmiot_do_gry 191, 'Imperialny Mandat'
EXEC dodaj_przedmiot_do_gry 191, 'Wykradacz Dusz Mejai'
EXEC dodaj_przedmiot_do_gry 191, 'Zab??jczy Kapelusz Rabadona'
EXEC dodaj_przedmiot_do_gry 191, 'Glewia Umbry'
EXEC dodaj_przedmiot_do_gry 192, 'Cezura'
EXEC dodaj_przedmiot_do_gry 192, 'Rt??ciowa Szarfa'
EXEC dodaj_przedmiot_do_gry 192, 'Czarci Kodeks'
EXEC dodaj_przedmiot_do_gry 192, 'Ostrze Zniszczonego Kr??la'
EXEC dodaj_przedmiot_do_gry 192, 'Totem Ukrycia'
EXEC dodaj_przedmiot_do_gry 192, 'Korona Roztrzaskanej Kr??lowej'
EXEC dodaj_przedmiot_do_gry 193, 'Ostrze Stra??nika'
EXEC dodaj_przedmiot_do_gry 193, 'Cierpienie Liandry''ego'
EXEC dodaj_przedmiot_do_gry 193, 'Relikwiarz Z??otej Jutrzenki'
EXEC dodaj_przedmiot_do_gry 193, 'Za??mienie'
EXEC dodaj_przedmiot_do_gry 193, 'Szczelinotw??rca'
EXEC dodaj_przedmiot_do_gry 193, 'Cieniotw??rca Draktharru'
EXEC dodaj_przedmiot_do_gry 194, 'Czujny Kamienny Totem'
EXEC dodaj_przedmiot_do_gry 194, 'Czarci Kodeks'
EXEC dodaj_przedmiot_do_gry 194, 'Bogob??jca'
EXEC dodaj_przedmiot_do_gry 194, 'Demoniczny U??cisk'
EXEC dodaj_przedmiot_do_gry 194, 'Syzygium'
EXEC dodaj_przedmiot_do_gry 194, 'R????d??ka Wiek??w'
EXEC dodaj_przedmiot_do_gry 195, 'Kula Stra??nika'
EXEC dodaj_przedmiot_do_gry 195, 'Niesko??czona Konwergencja'
EXEC dodaj_przedmiot_do_gry 195, 'R????d??ka Wiek??w'
EXEC dodaj_przedmiot_do_gry 195, 'Obuwie Merkurego'
EXEC dodaj_przedmiot_do_gry 195, 'Alternator Hextech'
EXEC dodaj_przedmiot_do_gry 195, 'Kolczasta Kolczuga'
EXEC dodaj_przedmiot_do_gry 196, 'S??oneczna Egida'
EXEC dodaj_przedmiot_do_gry 196, 'Omen Randuina'
EXEC dodaj_przedmiot_do_gry 196, 'W????owy Kie??'
EXEC dodaj_przedmiot_do_gry 196, 'Niesko??czona Konwergencja'
EXEC dodaj_przedmiot_do_gry 196, '??wietlista Cnota'
EXEC dodaj_przedmiot_do_gry 196, 'R??wnonoc'
EXEC dodaj_przedmiot_do_gry 197, 'Niesko??czona Konwergencja'
EXEC dodaj_przedmiot_do_gry 197, 'Ostrze Stra??nika'
EXEC dodaj_przedmiot_do_gry 197, 'Czarna W????cznia Kalisty'
EXEC dodaj_przedmiot_do_gry 197, 'Oko Luden'
EXEC dodaj_przedmiot_do_gry 197, 'Wezwanie Kata'
EXEC dodaj_przedmiot_do_gry 197, 'Wykradacz Dusz Mejai'
EXEC dodaj_przedmiot_do_gry 198, '??a??cuchy Zguby'
EXEC dodaj_przedmiot_do_gry 198, 'Wezwanie Kata'
EXEC dodaj_przedmiot_do_gry 198, 'Naramienniki spod Bia??ej Ska??y'
EXEC dodaj_przedmiot_do_gry 198, '??elazny Bicz'
EXEC dodaj_przedmiot_do_gry 198, 'Baczny Kamienny Totem'
EXEC dodaj_przedmiot_do_gry 198, 'Oblicze Ducha'
EXEC dodaj_przedmiot_do_gry 199, 'Niesko??czona Konwergencja'
EXEC dodaj_przedmiot_do_gry 199, 'Pozdrowienia Lorda Dominika'
EXEC dodaj_przedmiot_do_gry 199, 'Krwiochron'
EXEC dodaj_przedmiot_do_gry 199, 'Oko Luden'
EXEC dodaj_przedmiot_do_gry 199, 'Uraza Seryldy'
EXEC dodaj_przedmiot_do_gry 199, 'Z??bkowany Sztylet'
EXEC dodaj_przedmiot_do_gry 200, 'Rekwiem Shurelyi'
EXEC dodaj_przedmiot_do_gry 200, 'W????owy Kie??'
EXEC dodaj_przedmiot_do_gry 200, 'Katalizator Eon??w'
EXEC dodaj_przedmiot_do_gry 200, '??wit Srebrzystej'
EXEC dodaj_przedmiot_do_gry 200, 'Totem Ukrycia'
EXEC dodaj_przedmiot_do_gry 200, 'Rt??ciowa Szarfa'
EXEC dodaj_przedmiot_do_gry 201, 'Nieustaj??cy G????d'
EXEC dodaj_przedmiot_do_gry 201, 'Korona Roztrzaskanej Kr??lowej'
EXEC dodaj_przedmiot_do_gry 201, 'Za??mienie'
EXEC dodaj_przedmiot_do_gry 201, 'P??omie?? Cienia'
EXEC dodaj_przedmiot_do_gry 201, 'Vesperia??ski Przyp??yw'
EXEC dodaj_przedmiot_do_gry 201, 'Lodowa R??kawica'
EXEC dodaj_przedmiot_do_gry 202, 'Kostur Archanio??a'
EXEC dodaj_przedmiot_do_gry 202, 'Po??eracz'
EXEC dodaj_przedmiot_do_gry 202, 'Kryszta??owy Karwasz'
EXEC dodaj_przedmiot_do_gry 202, 'M??ot Stra??nika'
EXEC dodaj_przedmiot_do_gry 202, 'Anio?? Str????'
EXEC dodaj_przedmiot_do_gry 202, 'Pot??ga Wichury'
EXEC dodaj_przedmiot_do_gry 203, 'Maska Otch??ani'
EXEC dodaj_przedmiot_do_gry 203, 'Pancerniaki'
EXEC dodaj_przedmiot_do_gry 203, 'Z??odziej Esencji'
EXEC dodaj_przedmiot_do_gry 203, 'M??ot Stra??nika'
EXEC dodaj_przedmiot_do_gry 203, 'Boski ??amacz'
EXEC dodaj_przedmiot_do_gry 203, 'Z??b Nashora'
EXEC dodaj_przedmiot_do_gry 204, 'Imperialny Mandat'
EXEC dodaj_przedmiot_do_gry 204, 'Ognisty Trybularz'
EXEC dodaj_przedmiot_do_gry 204, 'Ostrze Stra??nika'
EXEC dodaj_przedmiot_do_gry 204, 'Ch??eptacz Posoki'
EXEC dodaj_przedmiot_do_gry 204, 'Miotacz Gwiazd'
EXEC dodaj_przedmiot_do_gry 204, 'Mro??ne Serce'
EXEC dodaj_przedmiot_do_gry 205, 'Gangplank Placeholder'
EXEC dodaj_przedmiot_do_gry 205, 'Naramienniki spod Bia??ej Ska??y'
EXEC dodaj_przedmiot_do_gry 205, 'Relikwiarz Z??otej Jutrzenki'
EXEC dodaj_przedmiot_do_gry 205, 'Niszczyciel Marze??'
EXEC dodaj_przedmiot_do_gry 205, 'Z??b Nashora'
EXEC dodaj_przedmiot_do_gry 205, 'Z??bkowany Sztylet'
EXEC dodaj_przedmiot_do_gry 206, 'Zab??jczy Kapelusz Rabadona'
EXEC dodaj_przedmiot_do_gry 206, 'Kamienna P??yta Gargulca'
EXEC dodaj_przedmiot_do_gry 206, 'Kula Stra??nika'
EXEC dodaj_przedmiot_do_gry 206, 'Z??bkowany Sztylet'
EXEC dodaj_przedmiot_do_gry 206, 'Uraza Seryldy'
EXEC dodaj_przedmiot_do_gry 206, 'Lustro ze Szk??a Bandle'
EXEC dodaj_przedmiot_do_gry 207, 'Ionia??skie Buty Jasno??ci Umys??u'
EXEC dodaj_przedmiot_do_gry 207, 'Krwiochron'
EXEC dodaj_przedmiot_do_gry 207, 'Wykradacz Dusz Mejai'
EXEC dodaj_przedmiot_do_gry 207, '??wit Srebrzystej'
EXEC dodaj_przedmiot_do_gry 207, 'Wielka Zima'
EXEC dodaj_przedmiot_do_gry 207, 'Odnowienie Kamienia Ksi????ycowego'
EXEC dodaj_przedmiot_do_gry 208, '??za Bogini'
EXEC dodaj_przedmiot_do_gry 208, 'Ca??un Banshee'
EXEC dodaj_przedmiot_do_gry 208, 'Krwiopijec'
EXEC dodaj_przedmiot_do_gry 208, 'Ostatni Szept'
EXEC dodaj_przedmiot_do_gry 208, 'M??ot Bojowy Caulfielda'
EXEC dodaj_przedmiot_do_gry 208, 'Koniec Rozumu'
EXEC dodaj_przedmiot_do_gry 209, '??wit Srebrzystej'
EXEC dodaj_przedmiot_do_gry 209, 'Kad??ubo??amacz'
EXEC dodaj_przedmiot_do_gry 209, 'Szybkie Ostrza Navori'
EXEC dodaj_przedmiot_do_gry 209, 'Rt??ciowa Szarfa'
EXEC dodaj_przedmiot_do_gry 209, 'Huragan Runaana'
EXEC dodaj_przedmiot_do_gry 209, 'Odnowienie Kamienia Ksi????ycowego'
EXEC dodaj_przedmiot_do_gry 210, 'Boski ??amacz'
EXEC dodaj_przedmiot_do_gry 210, 'W????cznia Shojin'
EXEC dodaj_przedmiot_do_gry 210, 'Blu??nierczy Bo??ek'
EXEC dodaj_przedmiot_do_gry 210, 'Ostrze Niesko??czono??ci'
EXEC dodaj_przedmiot_do_gry 210, 'Stalowe Serce'
EXEC dodaj_przedmiot_do_gry 210, 'Pogromca Kraken??w'
EXEC dodaj_przedmiot_do_gry 211, 'Twoja Dzia??ka'
EXEC dodaj_przedmiot_do_gry 211, 'Szczelinotw??rca'
EXEC dodaj_przedmiot_do_gry 211, 'R??wnonoc'
EXEC dodaj_przedmiot_do_gry 211, 'Lustro ze Szk??a Bandle'
EXEC dodaj_przedmiot_do_gry 211, 'Plemienna Zbroja'
EXEC dodaj_przedmiot_do_gry 211, 'Ochraniacze z Runicznej Stali'
EXEC dodaj_przedmiot_do_gry 212, 'Krwiopijec'
EXEC dodaj_przedmiot_do_gry 212, 'Cezura'
EXEC dodaj_przedmiot_do_gry 212, 'Zmora Licza'
EXEC dodaj_przedmiot_do_gry 212, 'Ionia??skie Buty Jasno??ci Umys??u'
EXEC dodaj_przedmiot_do_gry 212, 'Odnowienie Kamienia Ksi????ycowego'
EXEC dodaj_przedmiot_do_gry 212, 'Ogniolubny Top??r'
EXEC dodaj_przedmiot_do_gry 213, 'Pasjonuj??cy Kamienny Totem'
EXEC dodaj_przedmiot_do_gry 213, 'Vesperia??ski Przyp??yw'
EXEC dodaj_przedmiot_do_gry 213, 'Po??wi??cenie W????owej Ofiary'
EXEC dodaj_przedmiot_do_gry 213, 'Rt??ciowa Szarfa'
EXEC dodaj_przedmiot_do_gry 213, 'Buty Mobilno??ci'
EXEC dodaj_przedmiot_do_gry 213, 'Ulepszony Aeropak'
EXEC dodaj_przedmiot_do_gry 214, 'Katalizator Eon??w'
EXEC dodaj_przedmiot_do_gry 214, 'Czarny Tasak'
EXEC dodaj_przedmiot_do_gry 214, 'Po??eracz'
EXEC dodaj_przedmiot_do_gry 214, 'Lodowy Kie??'
EXEC dodaj_przedmiot_do_gry 214, 'P????ksi????ycowe Ostrze Harrowing'
EXEC dodaj_przedmiot_do_gry 214, 'Totem Ukrycia'
EXEC dodaj_przedmiot_do_gry 215, 'Za??mienie'
EXEC dodaj_przedmiot_do_gry 215, 'Wezwanie Kata'
EXEC dodaj_przedmiot_do_gry 215, 'Odkupienie'
EXEC dodaj_przedmiot_do_gry 215, 'Buty Pr??dko??ci'
EXEC dodaj_przedmiot_do_gry 215, 'Widmowe Ostrze Youmuu'
EXEC dodaj_przedmiot_do_gry 215, 'B??ogos??awie??stwo Mikaela'
EXEC dodaj_przedmiot_do_gry 216, 'Rozgrzany Klejnot'
EXEC dodaj_przedmiot_do_gry 216, 'Mro??ne Serce'
EXEC dodaj_przedmiot_do_gry 216, 'Kosa Czarnej Mg??y'
EXEC dodaj_przedmiot_do_gry 216, 'Z??odziej Esencji'
EXEC dodaj_przedmiot_do_gry 216, 'Kostur P??yn??cej Wody'
EXEC dodaj_przedmiot_do_gry 216, 'Rekwiem Shurelyi'
EXEC dodaj_przedmiot_do_gry 217, 'Cieniotw??rca Draktharru'
EXEC dodaj_przedmiot_do_gry 217, 'Przysi??ga Rycerska'
EXEC dodaj_przedmiot_do_gry 217, 'Skupienie Horyzontalne'
EXEC dodaj_przedmiot_do_gry 217, 'Kl??twa Icathii'
EXEC dodaj_przedmiot_do_gry 217, 'Wezwanie Kata'
EXEC dodaj_przedmiot_do_gry 217, 'Ulepszony Aeropak'
EXEC dodaj_przedmiot_do_gry 218, 'Ionia??skie Buty Jasno??ci Umys??u'
EXEC dodaj_przedmiot_do_gry 218, 'Krwio??ercza Hydra'
EXEC dodaj_przedmiot_do_gry 218, 'Ochraniacze z Runicznej Stali'
EXEC dodaj_przedmiot_do_gry 218, 'Ostrze Niesko??czono??ci'
EXEC dodaj_przedmiot_do_gry 218, 'Chempunkowy ??a??cuchowy Miecz'
EXEC dodaj_przedmiot_do_gry 218, 'Ulepszony Aeropak'
EXEC dodaj_przedmiot_do_gry 219, 'Stalowe Naramienniki'
EXEC dodaj_przedmiot_do_gry 219, 'Szybkie Ostrza Navori'
EXEC dodaj_przedmiot_do_gry 219, 'Klejnot Rozpadu'
EXEC dodaj_przedmiot_do_gry 219, 'Zmiana Dalekowidzenia'
EXEC dodaj_przedmiot_do_gry 219, 'Zmiana Dalekowidzenia'
EXEC dodaj_przedmiot_do_gry 219, 'Nagolenniki Berserkera'
EXEC dodaj_przedmiot_do_gry 220, '??wietlista Cnota'
EXEC dodaj_przedmiot_do_gry 220, 'Czarna W????cznia Kalisty'
EXEC dodaj_przedmiot_do_gry 220, 'Z??b Nashora'
EXEC dodaj_przedmiot_do_gry 220, 'Kostur P??yn??cej Wody'
EXEC dodaj_przedmiot_do_gry 220, 'Kamienna P??yta Gargulca'
EXEC dodaj_przedmiot_do_gry 220, 'Pancerniaki'
EXEC dodaj_przedmiot_do_gry 221, 'Pancerz Umrzyka'
EXEC dodaj_przedmiot_do_gry 221, 'Z??odziej Esencji'
EXEC dodaj_przedmiot_do_gry 221, 'M??ot Bojowy Caulfielda'
EXEC dodaj_przedmiot_do_gry 221, 'Anio?? Str????'
EXEC dodaj_przedmiot_do_gry 221, 'Ostrze Stra??nika'
EXEC dodaj_przedmiot_do_gry 221, 'Ostrze Nocy'
EXEC dodaj_przedmiot_do_gry 222, 'Widmowy Tancerz'
EXEC dodaj_przedmiot_do_gry 222, 'Ostrze Nocy'
EXEC dodaj_przedmiot_do_gry 222, 'Kl??twa Icathii'
EXEC dodaj_przedmiot_do_gry 222, 'Oblicze Ducha'
EXEC dodaj_przedmiot_do_gry 222, 'Ch??eptacz Posoki'
EXEC dodaj_przedmiot_do_gry 222, 'Reliktowa Tarcza'
EXEC dodaj_przedmiot_do_gry 223, 'Zab??jczy Kapelusz Rabadona'
EXEC dodaj_przedmiot_do_gry 223, 'R??wnonoc'
EXEC dodaj_przedmiot_do_gry 223, 'Rekwiem Shurelyi'
EXEC dodaj_przedmiot_do_gry 223, 'Ostatni Szept'
EXEC dodaj_przedmiot_do_gry 223, 'Maska Otch??ani'
EXEC dodaj_przedmiot_do_gry 223, 'W????cznia Shojin'
EXEC dodaj_przedmiot_do_gry 224, 'Tiamat'
EXEC dodaj_przedmiot_do_gry 224, 'Obuwie Merkurego'
EXEC dodaj_przedmiot_do_gry 224, 'M??ot Bojowy Caulfielda'
EXEC dodaj_przedmiot_do_gry 224, 'Kolczasta Kolczuga'
EXEC dodaj_przedmiot_do_gry 224, 'Blask'
EXEC dodaj_przedmiot_do_gry 224, 'Czarny Tasak'
EXEC dodaj_przedmiot_do_gry 225, 'Lodowy Kie??'
EXEC dodaj_przedmiot_do_gry 225, 'Szpon Piaskowej Dzier??by'
EXEC dodaj_przedmiot_do_gry 225, 'Ostrze Nocy'
EXEC dodaj_przedmiot_do_gry 225, 'Zbroja Stra??nika'
EXEC dodaj_przedmiot_do_gry 225, 'Cierpienie Liandry''ego'
EXEC dodaj_przedmiot_do_gry 225, 'Kolosalna Hydra'
EXEC dodaj_przedmiot_do_gry 226, 'Kosa Czarnej Mg??y'
EXEC dodaj_przedmiot_do_gry 226, 'Zmora Licza'
EXEC dodaj_przedmiot_do_gry 226, 'W????owy Kie??'
EXEC dodaj_przedmiot_do_gry 226, 'Kolekcjoner'
EXEC dodaj_przedmiot_do_gry 226, 'Egida Legionu'
EXEC dodaj_przedmiot_do_gry 226, 'Kostur Archanio??a'
EXEC dodaj_przedmiot_do_gry 227, 'Czarna W????cznia Kalisty'
EXEC dodaj_przedmiot_do_gry 227, 'P????ksi????ycowe Ostrze Harrowing'
EXEC dodaj_przedmiot_do_gry 227, 'Moc Tr??jcy'
EXEC dodaj_przedmiot_do_gry 227, 'Stalowe Naramienniki'
EXEC dodaj_przedmiot_do_gry 227, 'Gangplank Placeholder'
EXEC dodaj_przedmiot_do_gry 227, 'Kryszta??owy Kostur Rylai'
EXEC dodaj_przedmiot_do_gry 228, 'Chemtechowy Skaziciel'
EXEC dodaj_przedmiot_do_gry 228, 'Szybkie Ostrza Navori'
EXEC dodaj_przedmiot_do_gry 228, 'Niesko??czona Konwergencja'
EXEC dodaj_przedmiot_do_gry 228, 'Rozgrzany Klejnot'
EXEC dodaj_przedmiot_do_gry 228, 'Czarny Tasak'
EXEC dodaj_przedmiot_do_gry 228, 'Nie??miertelny ??uklerz'
EXEC dodaj_przedmiot_do_gry 229, 'Krwio??ercza Hydra'
EXEC dodaj_przedmiot_do_gry 229, 'Blu??nierczy Bo??ek'
EXEC dodaj_przedmiot_do_gry 229, 'Wysysaj??ce Spojrzenie'
EXEC dodaj_przedmiot_do_gry 229, 'Nawa??nica Luden'
EXEC dodaj_przedmiot_do_gry 229, 'Kostur P??yn??cej Wody'
EXEC dodaj_przedmiot_do_gry 229, 'Boski ??amacz'
EXEC dodaj_przedmiot_do_gry 230, 'Klejnot Rozpadu'
EXEC dodaj_przedmiot_do_gry 230, 'Boski ??amacz'
EXEC dodaj_przedmiot_do_gry 230, 'Zaginiony Rozdzia??'
EXEC dodaj_przedmiot_do_gry 230, 'Moc Tr??jcy'
EXEC dodaj_przedmiot_do_gry 230, 'Kosmiczny Impuls'
EXEC dodaj_przedmiot_do_gry 230, 'Muramana'
EXEC dodaj_przedmiot_do_gry 231, '??ar Bami'
EXEC dodaj_przedmiot_do_gry 231, 'Blask'
EXEC dodaj_przedmiot_do_gry 231, 'Czarci Kodeks'
EXEC dodaj_przedmiot_do_gry 231, 'Jak''Sho Zmienny'
EXEC dodaj_przedmiot_do_gry 231, 'R????d??ka Wiek??w'
EXEC dodaj_przedmiot_do_gry 231, 'Czarna W????cznia Kalisty'
EXEC dodaj_przedmiot_do_gry 232, 'Cezura'
EXEC dodaj_przedmiot_do_gry 232, 'Za??mienie'
EXEC dodaj_przedmiot_do_gry 232, 'Szczelinotw??rca'
EXEC dodaj_przedmiot_do_gry 232, 'Zaginiony Rozdzia??'
EXEC dodaj_przedmiot_do_gry 232, 'Wieczna Zmarzlina'
EXEC dodaj_przedmiot_do_gry 232, 'Niszczyciel Marze??'
EXEC dodaj_przedmiot_do_gry 233, 'Widmowa Os??ona'
EXEC dodaj_przedmiot_do_gry 233, 'Zbroja Stra??nika'
EXEC dodaj_przedmiot_do_gry 233, 'Pot??ga Wichury'
EXEC dodaj_przedmiot_do_gry 233, 'R??wnonoc'
EXEC dodaj_przedmiot_do_gry 233, 'Poch??aniacz Urok??w'
EXEC dodaj_przedmiot_do_gry 233, '??amacz Falangi'
EXEC dodaj_przedmiot_do_gry 234, 'Blask'
EXEC dodaj_przedmiot_do_gry 234, 'Ostrze Z??odziejki Czar??w'
EXEC dodaj_przedmiot_do_gry 234, 'Cieniotw??rca Draktharru'
EXEC dodaj_przedmiot_do_gry 234, 'Skupienie Horyzontalne'
EXEC dodaj_przedmiot_do_gry 234, 'Relikwiarz Z??otej Jutrzenki'
EXEC dodaj_przedmiot_do_gry 234, 'Klepsydra Zhonyi'
EXEC dodaj_przedmiot_do_gry 235, 'Ostrze Nocy'
EXEC dodaj_przedmiot_do_gry 235, 'Katalizator Eon??w'
EXEC dodaj_przedmiot_do_gry 235, 'Z??bkowany Sztylet'
EXEC dodaj_przedmiot_do_gry 235, 'Muramana'
EXEC dodaj_przedmiot_do_gry 235, 'Szpon Ciemnego Typa'
EXEC dodaj_przedmiot_do_gry 235, 'Przedwieczny Brzask'
EXEC dodaj_przedmiot_do_gry 236, 'Kuk??a Stracha na Wr??ble'
EXEC dodaj_przedmiot_do_gry 236, 'Pancerz Umrzyka'
EXEC dodaj_przedmiot_do_gry 236, 'Odkupienie'
EXEC dodaj_przedmiot_do_gry 236, 'Przysi??ga Rycerska'
EXEC dodaj_przedmiot_do_gry 236, 'Rekwiem Shurelyi'
EXEC dodaj_przedmiot_do_gry 236, 'Buty Mobilno??ci'
EXEC dodaj_przedmiot_do_gry 237, 'Stalowe Naramienniki'
EXEC dodaj_przedmiot_do_gry 237, 'Nieopisany Paso??yt'
EXEC dodaj_przedmiot_do_gry 237, 'Po??wi??cenie W????owej Ofiary'
EXEC dodaj_przedmiot_do_gry 237, 'R????d??ka Wiek??w'
EXEC dodaj_przedmiot_do_gry 237, 'Widmowa Os??ona'
EXEC dodaj_przedmiot_do_gry 237, 'Rt??ciowy Bu??at'
EXEC dodaj_przedmiot_do_gry 238, 'Pancerniaki'
EXEC dodaj_przedmiot_do_gry 238, '??amacz Falangi'
EXEC dodaj_przedmiot_do_gry 238, 'Chempunkowy ??a??cuchowy Miecz'
EXEC dodaj_przedmiot_do_gry 238, 'Morellonomicon'
EXEC dodaj_przedmiot_do_gry 238, 'Tiamat'
EXEC dodaj_przedmiot_do_gry 238, 'Zbroja Stra??nika'
EXEC dodaj_przedmiot_do_gry 239, 'Zaginiony Rozdzia??'
EXEC dodaj_przedmiot_do_gry 239, 'Czujny Kamienny Totem'
EXEC dodaj_przedmiot_do_gry 239, 'Puklerz Targonu'
EXEC dodaj_przedmiot_do_gry 239, 'Lewiatan'
EXEC dodaj_przedmiot_do_gry 239, 'Puklerz Targonu'
EXEC dodaj_przedmiot_do_gry 239, 'Kolczasta Kolczuga'
EXEC dodaj_przedmiot_do_gry 240, 'Cierpienie Liandry''ego'
EXEC dodaj_przedmiot_do_gry 240, 'Relikwiarz Z??otej Jutrzenki'
EXEC dodaj_przedmiot_do_gry 240, 'Turbochemiczny Pojemnik'
EXEC dodaj_przedmiot_do_gry 240, 'Koniec Rozumu'
EXEC dodaj_przedmiot_do_gry 240, 'Korona Roztrzaskanej Kr??lowej'
EXEC dodaj_przedmiot_do_gry 240, 'Szpon Ciemnego Typa'
EXEC dodaj_przedmiot_do_gry 241, 'Szczelinotw??rca'
EXEC dodaj_przedmiot_do_gry 241, 'Nadej??cie Zimy'
EXEC dodaj_przedmiot_do_gry 241, 'Katalizator Eon??w'
EXEC dodaj_przedmiot_do_gry 241, 'Ogniolubny Top??r'
EXEC dodaj_przedmiot_do_gry 241, 'B??ogos??awie??stwo Mikaela'
EXEC dodaj_przedmiot_do_gry 241, '??amacz Falangi'
EXEC dodaj_przedmiot_do_gry 242, 'Wieczna Zmarzlina'
EXEC dodaj_przedmiot_do_gry 242, 'Mro??ne Serce'
EXEC dodaj_przedmiot_do_gry 242, 'Si??a Natury'
EXEC dodaj_przedmiot_do_gry 242, 'B??ogos??awie??stwo Mikaela'
EXEC dodaj_przedmiot_do_gry 242, 'Mro??ny Puklerz'
EXEC dodaj_przedmiot_do_gry 242, 'Bastion G??ry'
EXEC dodaj_przedmiot_do_gry 243, 'Nie??miertelny ??uklerz'
EXEC dodaj_przedmiot_do_gry 243, 'Z??bkowany Sztylet'
EXEC dodaj_przedmiot_do_gry 243, 'Szpon Piaskowej Dzier??by'
EXEC dodaj_przedmiot_do_gry 243, 'Gniewon????'
EXEC dodaj_przedmiot_do_gry 243, 'Rt??ciowa Szarfa'
EXEC dodaj_przedmiot_do_gry 243, 'Z??ota Szpatu??ka'
EXEC dodaj_przedmiot_do_gry 244, 'Kolosalna Hydra'
EXEC dodaj_przedmiot_do_gry 244, '??a??cuchy Zguby'
EXEC dodaj_przedmiot_do_gry 244, 'Kamienna P??yta Gargulca'
EXEC dodaj_przedmiot_do_gry 244, 'Ostrze Zniszczonego Kr??la'
EXEC dodaj_przedmiot_do_gry 244, '??miertelne Przypomnienie'
EXEC dodaj_przedmiot_do_gry 244, 'Koniec Rozumu'
EXEC dodaj_przedmiot_do_gry 245, 'Czarci Kodeks'
EXEC dodaj_przedmiot_do_gry 245, 'Katalizator Eon??w'
EXEC dodaj_przedmiot_do_gry 245, 'Cezura'
EXEC dodaj_przedmiot_do_gry 245, 'Gniewon????'
EXEC dodaj_przedmiot_do_gry 245, 'Lewiatan'
EXEC dodaj_przedmiot_do_gry 245, 'Pozdrowienia Lorda Dominika'
EXEC dodaj_przedmiot_do_gry 246, 'Mro??ny Puklerz'
EXEC dodaj_przedmiot_do_gry 246, 'Ostrze Zniszczonego Kr??la'
EXEC dodaj_przedmiot_do_gry 246, 'Kostur P??yn??cej Wody'
EXEC dodaj_przedmiot_do_gry 246, '??amacz Falangi'
EXEC dodaj_przedmiot_do_gry 246, 'Czujny Kamienny Totem'
EXEC dodaj_przedmiot_do_gry 246, 'Kuk??a Stracha na Wr??ble'
EXEC dodaj_przedmiot_do_gry 247, 'Wielka Zima'
EXEC dodaj_przedmiot_do_gry 247, 'Obuwie Merkurego'
EXEC dodaj_przedmiot_do_gry 247, 'W????cznia Shojin'
EXEC dodaj_przedmiot_do_gry 247, 'Kl??twa Icathii'
EXEC dodaj_przedmiot_do_gry 247, 'Lewiatan'
EXEC dodaj_przedmiot_do_gry 247, 'Anio?? Str????'
EXEC dodaj_przedmiot_do_gry 248, 'Pot??ga Wichury'
EXEC dodaj_przedmiot_do_gry 248, 'Ro??linna Bariera'
EXEC dodaj_przedmiot_do_gry 248, 'Zas??ona R??wno??ci'
EXEC dodaj_przedmiot_do_gry 248, 'Ognista Armata'
EXEC dodaj_przedmiot_do_gry 248, 'Turbochemiczny Pojemnik'
EXEC dodaj_przedmiot_do_gry 248, 'Egida Legionu'
EXEC dodaj_przedmiot_do_gry 249, 'Katalizator Eon??w'
EXEC dodaj_przedmiot_do_gry 249, 'Morellonomicon'
EXEC dodaj_przedmiot_do_gry 249, 'Zbroja Stra??nika'
EXEC dodaj_przedmiot_do_gry 249, 'Obuwie Merkurego'
EXEC dodaj_przedmiot_do_gry 249, 'Czarny Tasak'
EXEC dodaj_przedmiot_do_gry 249, 'Nocny ??niwiarz'
EXEC dodaj_przedmiot_do_gry 250, 'Rekwiem Shurelyi'
EXEC dodaj_przedmiot_do_gry 250, 'Naramienniki spod Bia??ej Ska??y'
EXEC dodaj_przedmiot_do_gry 250, 'Wieczna Zmarzlina'
EXEC dodaj_przedmiot_do_gry 250, 'Zmiana Dalekowidzenia'
EXEC dodaj_przedmiot_do_gry 250, 'Moc Niesko??czono??ci'
EXEC dodaj_przedmiot_do_gry 250, 'Krwiochron'
