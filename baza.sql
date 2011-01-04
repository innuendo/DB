/*
 * Prosty skrypt tworzący bazę danych na potrzeby mojego projektu
 * firmy przewozowej
 */
BEGIN
   FOR cur_rec IN 
   (SELECT object_name, object_type FROM user_objects
    WHERE object_type IN
     ('TABLE', 'VIEW', 'PACKAGE', 'PROCEDURE', 'FUNCTION','SEQUENCE') AND
    object_name IN ('PACZKA', 'USLUGA', 'KLIENT', 'TARYFA','REGION',
                    'PRZEWOZ_OSOB', 'PRACOWNIK', 'TERMINAL', 'ZLECENIE'))
   LOOP
      BEGIN
         IF cur_rec.object_type = 'TABLE'
         THEN
            EXECUTE IMMEDIATE    'DROP '
                              || cur_rec.object_type
                              || ' "'
                              || cur_rec.object_name
                              || '" CASCADE CONSTRAINTS';
         ELSE
            EXECUTE IMMEDIATE    'DROP '
                              || cur_rec.object_type
                              || ' "'
                              || cur_rec.object_name
                              || '"';
         END IF;
      EXCEPTION
         WHEN OTHERS
         THEN
            DBMS_OUTPUT.put_line (   'FAILED: DROP '
                                  || cur_rec.object_type
                                  || ' "'
                                  || cur_rec.object_name
                                  || '"'
                                 );
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
    zlecenie_stale CHAR(1) NULL CHECK(zlecenie_stale IN ('Y','N')),
    data_przyjecia DATE NOT NULL,
    koszt_laczny NUMBER NOT NULL,
    forma_platnosci VARCHAR2(20) NOT NULL,
    termin_platnosci DATE NOT NULL,
    id_nadawcy NUMBER NOT NULL,
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
    typ_uslugi VARCHAR2(20) NOT NULL,
    potwierdzenie NUMBER NOT NULL,
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
/*
CREATE OR REPLACE TRIGGER uaktualnijKosztCalkowity
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
DECLARE
    nowy  Usluga.koszt%TYPE;
    stary Usluga.koszt%TYPE;
BEGIN
    nowy = :NEW.koszt;
    stary = :OLD.koszt;
    UPDATE Zlecenie SET 
    Zlecenie.koszt_laczny = Zlecenie.koszt_laczny + nowy - stary
    WHERE Zlecenie.numer = :NEW.id_zlecenia;
END;
/ 

CREATE FUNCTION ulubieniKlienci(ile NUMBER) RETURN NUMBER IS

BEGIN

END;
/*/