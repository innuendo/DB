/*
 * Prosty skrypt tworzący bazę danych na potrzeby mojego projektu
 * firmy przewozowej -- i tak, tak wiem, że dynamiczny SQL jest wolny,
 * ale baza będzie dość niewielka w sumie, więc na razie wystarczy ;]
 */
BEGIN
   FOR cur_rec IN 
   (SELECT object_name, object_type FROM user_objects
    WHERE object_type IN
     ('TABLE', 'PACKAGE', 'PROCEDURE', 'FUNCTION') AND
    object_name IN ('PACZKA', 'USLUGA', 'KLIENT', 'TARYFA','REGION',
                    'PRZEWOZ_OSOB', 'PRACOWNIK', 'TERMINAL', 'ZLECENIE', 'KURIER'))
   LOOP
      BEGIN
         IF cur_rec.object_type = 'TABLE' THEN EXECUTE IMMEDIATE
                              'DROP ' || cur_rec.object_type|| ' "'
                              || cur_rec.object_name|| '" CASCADE CONSTRAINTS';
         ELSE EXECUTE IMMEDIATE 'DROP ' || cur_rec.object_type || ' "'
                                || cur_rec.object_name || '"';
         END IF;
      EXCEPTION
         WHEN OTHERS THEN
            DBMS_OUTPUT.put_line ( 'ERROR: DROP ' || cur_rec.object_type
                                    || ' "' || cur_rec.object_name || '"');
      END;
   END LOOP;
END;
/

CREATE TABLE Klient (
    id NUMBER PRIMARY KEY,
    nazwa VARCHAR2(20) NOT NULL,
    numer_budynku NUMBER NOT NULL 
    CONSTRAINT sprawdz_numer_budynku CHECK(numer_budynku > 0),
    numer_lokalu NUMBER,
    kod_pocztowy VARCHAR2(20) NOT NULL,
    miejscowosc VARCHAR2(20) NOT NULL,
    ulica VARCHAR2(20) NOT NULL,
    nazwa_skrocona VARCHAR2(20),
    nip VARCHAR2(20) NOT NULL
);


CREATE TABLE Zlecenie (
    numer VARCHAR2(20) PRIMARY KEY,
    zlecenie_stale CHAR(1) NOT NULL CHECK(zlecenie_stale IN ('Y','N')),
    data_przyjecia DATE NOT NULL,
    koszt_laczny NUMBER NOT NULL,
    forma_platnosci VARCHAR2(20),
    termin_platnosci DATE NOT NULL,
    id_nadawcy NUMBER NOT NULL,
    data_platnosci DATE,
    CONSTRAINT NADAWCA_FK FOREIGN KEY (id_nadawcy) REFERENCES Klient (id)
);


CREATE TABLE Pracownik (
    id NUMBER PRIMARY KEY,
    skrot CHAR(2),
    imie VARCHAR2(20) NOT NULL,
    nazwisko VARCHAR2(20) NOT NULL
);


CREATE TABLE Usluga (
    id NUMBER PRIMARY KEY,
    koszt NUMBER NOT NULL CONSTRAINT koszt CHECK(koszt > 0),
    numer_listu VARCHAR2(20) NOT NULL,
    potwierdzenie CHAR(1) NOT NULL CHECK(potwierdzenie IN ('Y','N'))
    ilosc_transportow NUMBER NOT NULL
    CONSTRAINT sprawdz_transporty CHECK(ilosc_transportow > 0),
    stawka_vat NUMBER NOT NULL,
    id_zlecenia VARCHAR2(20) NOT NULL,
    id_odbiorcy NUMBER NOT NULL,
    id_pracownika NUMBER NOT NULL,
    CONSTRAINT ZLECENIE_FK FOREIGN KEY (id_zlecenia) REFERENCES Zlecenie (numer),
    CONSTRAINT ODBIORCA_FK FOREIGN KEY (id_odbiorcy) REFERENCES Klient (id),
    CONSTRAINT PRACOWNIK_FK FOREIGN KEY (id_pracownika) REFERENCES Pracownik (id)
);


CREATE TABLE Przewoz_osob (
    id NUMBER PRIMARY KEY,
    ilosc NUMBER NOT NULL
    CONSTRAINT sprawdz_ilosc_osob CHECK (ilosc > 0),
    dystans NUMBER NOT NULL
    CONSTRAINT sprawdz_dystans CHECK(dystans > 0),
    id_uslugi NUMBER NOT NULL,
    CONSTRAINT Usluga_FK FOREIGN KEY (id_uslugi) REFERENCES Usluga (id)
);


CREATE TABLE Terminal (
    id NUMBER PRIMARY KEY,
    zwrot CHAR(1) CONSTRAINT sprawdz_zwrot CHECK(zwrot IN ('Y','N')),
    id_uslugi NUMBER NOT NULL,
    CONSTRAINT Usluga1_FK FOREIGN KEY (id_uslugi) REFERENCES Usluga (id)
);


CREATE TABLE Paczka (
    id NUMBER PRIMARY KEY,
    masa NUMBER NOT NULL CONSTRAINT sprawdz_mase CHECK(masa > 0),
    gabaryt CHAR(1) 
    CONSTRAINT sprawdz_gabaryt CHECK(gabaryt IN ('Y','N')),
    id_uslugi NUMBER NOT NULL,
    CONSTRAINT Usluga2_FK FOREIGN KEY (id_uslugi) REFERENCES Usluga (id)
);


CREATE TABLE Region (
    id NUMBER PRIMARY KEY,
    stawka_podstawowa NUMBER NOT NULL 
    CONSTRAINT sprawdz_podstawowa_stawke CHECK(stawka_podstawowa >= 0),
    stawka_gabaryt NUMBER NOT NULL 
    CONSTRAINT sprawdz_gabarytowa_stawke CHECK(stawka_gabaryt >= 0),
    nazwa_skrocona VARCHAR2(20)
);


CREATE TABLE Taryfa (
    wsp_pory NUMBER NOT NULL,
    wsp_dnia NUMBER NOT NULL,
    CONSTRAINT PK PRIMARY KEY (wsp_pory, wsp_dnia)
);

CREATE OR REPLACE TRIGGER zwiekszKosztCalkowity
AFTER INSERT ON Usluga FOR EACH ROW
BEGIN
    UPDATE Zlecenie SET 
    Zlecenie.koszt_laczny = Zlecenie.koszt_laczny + :new.koszt
    WHERE Zlecenie.numer = :new.id_zlecenia;
END;
/

CREATE OR REPLACE TRIGGER uaktualnijKosztCalkowity
AFTER UPDATE ON Usluga
FOR EACH ROW
BEGIN
    UPDATE Zlecenie SET 
    Zlecenie.koszt_laczny = Zlecenie.koszt_laczny + :new.koszt - :old.koszt
    WHERE Zlecenie.numer = :NEW.id_zlecenia;
END;
/ 


CREATE OR REPLACE PACKAGE kurier AS
    TYPE klient_refcur IS REF CURSOR RETURN klient%ROWTYPE;
    
    PROCEDURE zalegajacyZPlatnoscia(klient_cur IN OUT klient_refcur);
    FUNCTION lacznyDochodZaOkres(data1 DATE, data2 DATE) RETURN NUMBER;
    PROCEDURE znajdzKlienta(nazwa_ IN VARCHAR2, miejscowosc_ IN VARCHAR2,
                            ulica_ IN VARCHAR2, klient_cur IN OUT klient_refcur);
    
    PROCEDURE dodajUsluge(id IN NUMBER, koszt IN NUMBER, numer_listu IN VARCHAR2(20),
                          typ_uslugi IN VARCHAR2(20), potwierdzenie IN NUMBER,
                          ilosc_transportow IN NUMBER, stawka_vat IN NUMBER,
                          id_odbiorcy IN NUMBER, id_pracownika NUMBER,
                          numer_zlecenia IN VARCHAR, nadawca NUMBER DEFAULT NULL);
                          
    PROCEDURE usunTowar(id_kasowanego NUMBER, nazwa_tabeli VARCHAR2, z_usuwalne CHAR(1));
    PROCEDURE usunZlecenie(numer_kasowanego VARCHAR2);
    
END kurier;
/

CREATE OR REPLACE PACKAGE BODY kurier AS
-----------------------------------------------------------------------------------------
    PROCEDURE znajdzKlienta(nazwa_ IN VARCHAR2, miejscowosc_ IN VARCHAR2,
                            ulica_ IN VARCHAR2, klient_cur IN OUT klient_refcur) IS
    BEGIN
        OPEN klient_cur FOR SELECT * FROM Klient 
        WHERE SUBSTR(UPPER(nazwa), 1, LENGTH(nazwa_)) = UPPER(nazwa_)
            OR SUBSTR(UPPER(miejscowosc), 1, LENGTH(miejscowosc_)) = UPPER(miejscowosc_)
            OR SUBSTR(UPPER(ulica), 1, LENGTH(ulica_)) = UPPER(ulica_);
END;
-----------------------------------------------------------------------------------------
    PROCEDURE zalegajacyZPlatnoscia(klient_cur IN OUT klient_refcur)
    DECLARE
        dzis DATE;
    BEGIN
        SELECT sysdate INTO dzis FROM dual;
        OPEN klient_cur FOR SELECT k.id, k.nazwa, k.numer_budynku, k.numer_lokalu,
                                   k.kod_pocztowy, k.miejscowosc, k.ulica, k.nazwa_skrocona, 
                                   k.nip  
                            FROM Klient k LEFT JOIN Zlecenie z ON k.id = z.id_nadawcy
                            WHERE z.data_platnosci < dzis;
END;
-----------------------------------------------------------------------------------------
    FUNCTION lacznyDochodNettoZaOkres(data1 DATE, data2 DATE) RETURN NUMBER IS
    DECLARE
        res NUMBER;
        dummy NUMBER;
        CURSOR koszt_cur IS
            SELECT koszt_laczny FROM zlecenie 
            WHERE data_przyjecia BETWEEN data1 AND data2 
            AND data_platnosci IS NOT NULL;
    BEGIN 
        LOOP
             FETCH koszt_cur INTO dummy;
             EXIT WHEN koszt_cur%NOTFOUND;
             res := res + dummy;
        END LOOP;
        RETURN res;
    END lacznyDochodZaOkres;
-----------------------------------------------------------------------------------------    
    PROCEDURE dodajUsluge(id_ IN NUMBER, koszt_ IN NUMBER, numer_listu_ IN VARCHAR2(20),
                          typ_uslugi_ IN VARCHAR2(20), potwierdzenie_ IN NUMBER,
                          ilosc_transportow_ IN NUMBER, stawka_vat_ IN NUMBER,
                          id_odbiorcy_ IN NUMBER, id_pracownika_ NUMBER, 
                          numer_zlecenia IN VARCHAR, nadawca NUMBER DEFAULT NULL) IS
    DECLARE
        czy_jest Zlecenie.numer%TYPE;
        teraz DATE;
    BEGIN
    -- prosty wrapper, który dodaje usluge i jesli nie ma zlecenia do ktorego sie
    -- odwoluje to je tworzy (o ile nadawca jest podany)
        SELECT sysdate INTO teraz FROM dual;
        SELECT COUNT(*) INTO czy_jest FROM Zlecenie WHERE numer = numer_zlecenia;
        IF czy_jest = 0 AND nadawca IS NOT NULL THEN
            INSERT INTO Zlecenie VALUES (numer_zlecenia, teraz, 0, 'przelew',
                                         teraz + 14, nadawca);
        END IF;
        INSERT INTO Usluga VALUES (id_, koszt_, numer_listu_, typ_uslugi_, potwierdzenie_,
                                   ilosc_transportow_, stawka_vat_, numer_zlecenia,
                                id_odbiorcy_, id_pracownika_);
    END;
-----------------------------------------------------------------------------------------    
    PROCEDURE usunTowar(id_kasowanego NUMBER, nazwa_tabeli VARCHAR2, z_usuwalne CHAR(1))
    IS
    DECLARE
        id_uslugi_ Usluga.id%TYPE;
        id_zlecenia_ Zleceni.numer%TYPE;
        ile_uslug_w_zleceniu NUMBER;
    BEGIN
    --prosty wrapper usuwajacy 'towar' czyli Paczke, Terminal lub PrzewozOsob
        EXECUTE IMMEDIATE
            'SELECT id_uslugi FROM ' || nazwa_tabeli
            || ' WHERE id = id_kasowanego' INTO id_uslugi_;
        SELECT id_zlecenia INTO id_zlecenia FROM Usluga WHERE id = id_uslugi_;
        DELETE FROM Usluga WHERE id = id_uslugi;
        EXECUTE IMMEDIATE
            'DELETE FROM ' || nazwa_tabeli ||' WHERE id = id_kasowanego';
        SELECT COUNT(*) INTO  ile_uslug_w_zleceniu 
            FROM Usluga WHERE id_zlecenia = id_zlecenia_;
        IF (ile_uslug_w_zleceniu < 1 AND z_usuwalne = 'Y') THEN
            DELETE FROM Zlecenie WHERE numer = id_zlecenia_;
        END IF;
    END usunTowar;
-----------------------------------------------------------------------------------------
    PROCEDURE usunZlecenie(numer_kasowanego VARCHAR2) IS
    BEGIN
    --niszczy zlecenie i wszystkei wchodzace w jego sklad uslugi
        FOR id_uslugi_ IN 
            (SELECT id FROM Usluga WHERE id_zlecenia = numer_kasowanego) LOOP
            DELETE FROM Terminal WHERE id_uslugi = id_uslugi_;
            DELETE FROM Paczka WHERE id_uslugi = id_uslugi_;
            DELETE FROM PrzewozOsob WHERE id_uslugi = id_uslugi_;
        END LOOP;
        DELETE FROM Zlecenie WHERE numer = numer_kasowanego;
    END usunZlecenie;
-----------------------------------------------------------------------------------------
    /*PROCEDURE usunTerminal(id_kasowanego NUMBER) IS
    DECLARE
        id_uslugi_ NUMBER;
        id_zlecenia_ VARCHAR2;
        ile_uslug_w_zleceniu NUMBER;
    BEGIN
        SELECT id_uslugi INTO id_uslugi_ FROM Terminal WHERE id = id_kasowanego;
        SELECT id_zlecenia INTO id_zlecenia FROM Usluga WHERE id = id_uslugi_;
        DELETE FROM Usluga WHERE id = id_uslugi;
        DELETE FROM Terminal WHERE id = id_kasowanego;
        SELECT COUNT(*) INTO  ile_uslug_w_zleceniu FROM Usluga WHERE id_zlecenia = id_zlecenia_;
        IF (ile_uslug_w_zleceniu < 1) THEN
            DELETE FROM Zlecenie WHERE numer = id_zlecenia_;
        END IF;
    END usunTerminal;*/

END kurier;