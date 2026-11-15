Anno 1602 History Edition - Erweiterungen
==========================================

Installieren (auch auf einem anderen PC)
  1. Anno 1602 History Edition ueber Ubisoft Connect installieren (eigenes Ubisoft-Konto).
  2. Windows-Taste druecken, "powershell" tippen, Enter. Diese Zeile einfuegen und Enter:
       irm https://raw.githubusercontent.com/MisterDeeds/anno1602-extensions/main/get.ps1 | iex
     Sie laedt die neuste Version, installiert alles und oeffnet den Starter.
     (Ohne PowerShell: das ZIP der neusten Version von GitHub entpacken und "install.cmd"
     doppelklicken.)
  3. Starten ueber "Anno 1602 - Erweiterungen" im Startmenue oder auf dem Desktop
     (auf einem Windows in anderer Sprache heisst die Verknuepfung "Anno 1602 - Extensions").
  Aktualisieren: geht von selbst. Gibt es eine neue Version, installiert der Starter sie beim
  naechsten Start und oeffnet sich wieder (Haekchen "Automatisch aktualisieren"; ohne Haekchen
  erscheint der Knopf "Jetzt aktualisieren"). Einstellungen, Logbuch und Spielstaende bleiben.
  Die Zeile oben nochmals ausfuehren geht auch.
  Entfernen: Windows-Einstellungen -> Apps -> "Anno 1602 - Erweiterungen" -> Deinstallieren.
  Spiel und Spielstaende bleiben; die Szenarien der Erweiterungen (auch Tagesabenteuer und
  deine selbst gebauten Szenarien) und der Ordner mit deinen Einstellungen und dem Logbuch
  werden entfernt.
  Spielstaende mitnehmen: den Ordner Dokumente\Anno 1602 History Edition\Savegame auf den
  anderen PC an dieselbe Stelle kopieren (vorher dort einmal das Spiel starten).
  Die Erweiterungen enthalten keine Spieldateien; das Spiel selbst kommt immer aus Ubisoft
  Connect. Keine Administratorrechte noetig, nichts im Spielordner wird veraendert.

Spielen
  Das Fenster hat drei Registerkarten:
  "Neues Spiel"    Optionen waehlen, dann "Mit Erweiterungen spielen".
                   Im Spiel ein neues Endlosspiel beginnen (oder ein Szenario, siehe unten).
  "Weiterspielen"  Deine Spielstaende mit den Einstellungen, mit denen sie entstanden sind.
                   Einen auswaehlen, "Mit diesen Einstellungen spielen" klicken und im Spiel
                   "Spiel laden" waehlen. So wird eine grosse Welt immer mit der richtigen
                   Groesse und denselben Optionen geladen.
  "Abenteuer"      Deine Kampagnen und Herausforderungen mit Fortschritt, dazu die
                   Zufallsabenteuer, das Tagesabenteuer, "Eigenes Szenario bauen ..." und
                   das Kaestchen "Kapitel nacheinander freischalten" (siehe unten).
  "Original starten" startet das Spiel ohne Aenderungen (z. B. fuer alte Spielstaende).
  "Logbuch oeffnen" oeffnet das Logbuch-Fenster (siehe unten).
  Das Fenster ist auf einem deutschen Windows deutsch, sonst englisch.

Was geaendert wird (nur im Arbeitsspeicher, keine Spieldatei wird veraendert):
  Kartengroesse        bis 2000 x 1400 Felder (Original 500 x 350)
  Inseln               bis 50 Inseln ueber die ganze Karte verteilt (das Maximum des Spiels)
  Inselgroesse         Gross / Riesig: viel mehr grosse Inseln (bis 10 der groessten, 100 x 90)
  Rohstoffe            Mehr: Erz, Gold, Fruchtbarkeit und Schaetze passend zur Inselzahl; Viele: doppelt
  Ureinwohner          Mehr / Viele: 4 + 4 bzw. 7 + 7 Doerfer statt 2 + 2 (Nord + Sued)
  Fruchtbarkeit        "Jede Pflanze auf jeder Insel": in neuen Endlosspielen traegt jede Insel
                       mit fruchtbarem Land alle sechs Pflanzen (nicht in den Szenarien)
  Freie Haendler       Mehr / Viele: doppelt bzw. dreimal so viele Haendlerschiffe (hoechstens 24)
  Computergegner       Immer wie "Schwer": die drei Gegner ruesten und bauen aus wie auf der
                       hoechsten Stufe, auch wenn du leichter spielst (Naturereignisse bleiben)
  Piraten              wie Schwierigkeit / greifen immer an / stark / keine
  Piratenflotte        Gross / Riesig: bis 8 bzw. 12 Piratenschiffe statt 4 (nur wenn Piraten angreifen)
  Katastrophen         Keine: kein Feuer, keine Pest, Duerre oder Vulkan. Haeufiger: Feuer und
                       Pest doppelt so wahrscheinlich, Duerre doppelt so oft geprueft
  Ereignisse           Selten / Haeufig: zufaellige Ereignisse waehrend des Spiels (siehe
                       "Ereignisse" unten)
  Gold der Gegner      Startgold der drei Computergegner
  Dein Startgold       Startgold bei neuen Spielen
  Einwohner je Haus    x1,5 bis x5 (Original 2/6/15/25/40, bei x5 bis 200)
  Produktionstempo     x1,5 bis x3 fuer alle Betriebe
  Lager je Ware        x2 bis x5
  Baukosten            x0,75, halb, ein Viertel oder gratis: Gold, Werkzeug, Holz und Ziegel
                       jedes Gebaeudes (auch beim Aufstieg der Haeuser und fuer die Gegner)
  Betriebskosten       x0,75, halb, ein Viertel oder keine (Gebaeude; Schiffe und Soldaten
                       kosten weiter)
  Steuereinnahmen      x1,5 bis x3 (der Steuersatz-Regler wirkt wie bisher; auch fuer die Gegner)
  Einflussradius       x1,5 oder x2 fuer Kontor, Markt und die oeffentlichen Bauten (Kapelle,
                       Kirche, Kathedrale, Wirtshaus, Arzt, Badehaus, Theater, Schule,
                       Hochschule, Feuerwehr, Galgen)
  Erz- und Goldminen   Unerschoepflich: Vorkommen gehen nie zu Ende
  Schiffstempo         x1,5 bis x3
  Laderaum             x1,5 bis x3 fuer die baubaren Schiffe
  Turbo (Taste F7)     8-, 12- oder 16-fache Geschwindigkeit (F5 = normal, F6 = 2-fach).
                       Gemessen: 16-fach haelt exakt, bei rund der Haelfte eines Prozessorkerns.
  Baukosten, Betriebskosten, Steuereinnahmen, Einflussradius, Fruchtbarkeit, Minen und
  Katastrophen wurden am 12. November 2026 im laufenden Spiel geprueft. Die Ereignisse (neu in
  Version 3.0.0) sind im laufenden Spiel mit verkuerztem Abstand getestet, die beiden
  Steuer-Ereignisse nur ohne Spiel.

  Knopf "Alles gross": stellt mit einem Klick alles gross ein (1000 x 700, riesige Inseln,
  viele Rohstoffe, 7 + 7 Ureinwohnerdoerfer, dreimal so viele Haendler, Gegner wie "Schwer" mit
  60 000 Gold, Piraten greifen an mit doppelter Flotte, Einwohner x5, Lager x5, Laderaum x3,
  Produktion und Schiffe x2, Turbo 16-fach, dein Gold 50 000). Einzelne Felder kannst du danach
  noch aendern.

  Knopf "Fuer Kampagnen": grosse Karte (1000 x 700, mehr Inseln) und Turbo 16-fach, alles andere
  wie im Original. So sind die Kampagnen so schwer wie vorgesehen, und das Startgold kommt aus dem
  Szenario.

  Knopf "Riesenwelt": die Riesenwelt 2000 x 1400 fuer die Kampagne "Das Weltreich" und die
  Riesen-Herausforderungen (siehe "Riesenwelt" weiter unten), Schiffe x2 fuer die langen Reisen,
  Turbo 16-fach, alles andere wie im Szenario vorgesehen.

  Knopf "Gemuetlich": in Ruhe bauen (1000 x 700, grosse Inseln, viele Rohstoffe, jede Pflanze
  ueberall, unerschoepfliche Minen, Bau- und Betriebskosten halbiert, Steuern x2, Radius x1,5,
  keine Piraten, keine Katastrophen, dein Gold 100 000, Einwohner x2, Produktion x2, Lager x3,
  Turbo 16-fach). Gedacht fuer das Endlosspiel: In einem Szenario ersetzen die 100 000 Gold
  dessen Gold.

  Knopf "Harte Probe": Gegner wie "Schwer" mit 100 000 Gold, starke Piraten mit einer Flotte
  von bis zu 12 Schiffen, mehr Katastrophen, 4 + 4 Ureinwohnerdoerfer, mehr Rohstoffe,
  Turbo 16-fach.

  Knopf "Alles auf Standard": 1000 x 700 mit mehr Inseln und mehr Rohstoffen, alles andere wie
  im Original.
  Jeder Knopf stellt "Ereignisse" auf "Aus" - wer Ereignisse will, waehlt danach "Selten" oder
  "Haeufig".

Ereignisse (Option "Ereignisse" in der Gruppe "Gegner und Gefahren": Aus / Selten / Haeufig)
  Waehrend das Spiel laeuft, loest das Werkzeugfenster zufaellige Ereignisse aus: bei "Selten"
  etwa alle 3 Spielstunden, bei "Haeufig" etwa jede Spielstunde. Sie beginnen erst, wenn du
  eine eigene Stadt hast, und richten sich nach der Spieluhr: Im angehaltenen Spiel gibt es
  keine, der Turbo beschleunigt sie. Das Werkzeugfenster (das schwarze Fenster) muss offen
  bleiben. Die Ereignisse:
    Ein Goenner              +2 000 bis +10 000 Gold (je weiter deine Einwohner aufgestiegen
                             sind, desto mehr)
    Brand im Kontor          -5 % deines Goldes (nur ab 2 000 Gold)
    Geschenk eines Haendlers 10 bis 30 t Werkzeug, Holz, Ziegel oder Nahrung in deine groesste
                             Stadt (so viel ihr Lager fasst)
    Steuersegen              Steuern x1,5 fuer eine Spielstunde
    Steuerflaute             Steuern x0,75 fuer eine Spielstunde
    Erntesegen               alle Felder und Betriebe arbeiten eine Spielstunde lang x1,5 so
                             schnell
    Sumpffieber              alle Felder und Betriebe arbeiten eine Spielstunde lang x0,75 so
                             schnell
  Steuern und Produktion gelten fuer alle im Spiel gleich: Die Gegner gewinnen oder verlieren
  mit. Gold und Waren sind echte Aenderungen und werden mit dem Spiel gespeichert. Ein Steuer-
  oder Produktions-Ereignis endet nach einer Spielstunde, wenn ein anderes Spiel geladen oder
  begonnen wird, wenn das Spiel endet oder wenn das Werkzeugfenster schliesst - die Werte sind
  dann genau wie vorher. Jedes Ereignis erscheint im Logbuch.

Logbuch
  Ein kleines Fenster neben dem Spiel ("Logbuch oeffnen" im Startfenster oder das Kaestchen
  "Logbuch mit dem Spiel oeffnen"). Es LIEST nur den Arbeitsspeicher des Spiels und veraendert
  nichts. Es hat zwei Registerkarten:
  "Spiel":
    - deine Auftragsziele mit laufenden Fortschrittsbalken (gruen = erfuellt); im Wettlauf,
      wie nahe die Gegner sind, mit Zeitlimit die verbleibende Zeit,
    - Gold, Bilanz und Handelsbilanz, deine Staedte, Einwohner je Stufe, Schiffe,
    - die besten Staedte der Gegner,
    - die Ereignisse dieser Partie mit ihrer Wirkung (gruen = gut, rot = schlecht),
    - nach einer Partie eine Karte "Letzte Partie": Ergebnis, Spielzeit, hoechste
      Einwohnerzahl, meistes Gold, Staedte, hoechste Stufe und die Erfolge dieser Partie,
    - 53 Erfolge, z. B. "Land in Sicht" (erste Stadt), "Metropole" (2 500 Einwohner in einer
      Stadt), "Millionaer", "Volle Fahrt voraus" (Turbo), "Saga vollendet" (alle Kapitel
      einer Kampagne gewonnen), "Hattrick" (drei Siege in Folge), "Stammgast" (zehn Partien).
  "Verlauf":
    - vier Kurven: Gold, Einwohner je Stufe, Bilanz, Staedte und Schiffe - ein Punkt je
      Spielminute; mit der Maus auf eine Kurve zeigen, um die Werte zu sehen,
    - die Liste deiner gespielten Partien; ein Klick zeigt die Kurven und die Karte dieser
      Partie.
  Ein Klick auf eine Abschnittsueberschrift klappt den Abschnitt zu. "Im Vordergrund" haelt das
  Fenster ueber dem Spiel, "Kompakt" macht es klein. Im Fenstermodus spielen oder das Logbuch
  auf einen zweiten Bildschirm legen. Das Logbuch darf vor, waehrend und nach dem Spiel laufen;
  es verbindet sich von selbst.
  Erfolge, beendete Auftraege und gespielte Partien stehen in
  %APPDATA%\Anno1602-Extensions\logbook.json, die Kurven der 30 neuesten Partien im Ordner
  "history" daneben. Daraus zeigt die Registerkarte "Abenteuer", welche Kapitel du gewonnen
  hast - also das Logbuch offen haben, waehrend du ein Kapitel spielst.

Kampagnen und Herausforderungen (49 eigene Szenarien mit Geschichte und Auftrag)
  Im Spiel: Einzelspieler -> Neues Spiel -> in der Liste ganz nach unten zu "Eigene Szenarien".
  Ist der Auftrag erfuellt, endet das Szenario mit der Bewertung.
  Die Szenarien werden in der Sprache von Windows installiert: deutsch auf einem deutschen
  Windows, englisch sonst.
  Noch nicht im Spiel auf die Balance geprueft (mit * markiert): die Kampagnen "Die Sturmsee"
  (November 2026), "Die Neue Welt" und "Die Handelsliga" (neu in Version 3.0.0), "Das
  Weltreich" (neu in Version 3.1.0) und die Herausforderungen Archipel, Kontinente,
  Handelsflotte, Seemacht, die sechs von Kolonialherr bis Die Frist des Koenigs und die
  Riesen-Herausforderungen Sieben Meere und Die Weltumsegelung. Ihre Schwierigkeit ist in Anlehnung an die
  gemessenen Kapitel ausgelegt.

  Kampagne "Die Smaragdinseln" (der Reihe nach spielen):
    1 Landung           Stadt mit 250 Einwohnern (150 Siedler), Bilanz im Plus        Einfach
    2 Gewuerzfieber     Gewuerzmonopol (jede Gewuerzinsel besitzen), 500 Einw./250 Buerger
                                                                                     Durchschnittlich
    3 Zwei Kolonien     800 Einw./300 Kaufleute und 500 Einw./250 Buerger, Bilanz +300 Durchschnittlich
    4 Schwarze Segel    1000 Einw./500 Kaufleute, 20 t Kanonen und 40 t Musketen,
                        Piraten greifen an; Start mit kleinem Kriegsschiff              Fordernd
    5 Der Eroberer      alle drei Rivalen besiegen, Piraten greifen an;
                        Start mit grossem Kriegsschiff                                  Fordernd
    6 Krone der Inseln  3 Staedte, die groesste mit 2500 Einw./1200 Aristokraten,
                        Bilanz +1000, Piraten; Start mit grossem Handelsschiff          Schwer

  Kampagne "Wettlauf der Haeuser": Die drei Rivalen haben DENSELBEN Auftrag. Wer ihn zuerst
  erfuellt, gewinnt - ist ein Rivale schneller, ist das Szenario verloren.
    1 Erster Hafen      300 Einw./150 Siedler                                           Einfach
    2 Buergerstolz      700 Einw./350 Buerger und zweite Stadt 200/100 Siedler          Durchschnittlich
    3 Kaufmannsrepublik 1000 Einw./400 Kaufleute, Piraten                               Fordernd
    4 Die Krone         1500 Einw./600 Aristokraten, Bilanz +500, Piraten               Schwer
  Gemessen (Rivalen ohne Zutun des Spielers, grosse Karte, Piraten nur gesichtet, normale
  Spielzeit): Kapitel 3 gewinnt der schnellste Rivale nach rund 8 Stunden, Kapitel 4 nach rund
  20 Stunden. Die Zeit zaehlt im Spiel, nicht vor dem Bildschirm: Mit Turbo laufen auch die
  Rivalen schneller.
  Tipp: Die Piraten versenken ein Schiff, das lange untaetig auf See liegt. Ohne Schiff und ohne
  Stadt ist die Partie verloren - also frueh siedeln.

  Kampagne "Die Sturmsee" (der Reihe nach spielen) *:
  Ein Sturm zerstreut deinen Konvoi; du baust die Kolonie neu auf, gewinnst den Handel der
  Sturmsee, wehrst Piraten und das verraeterische Haus Valcourt ab und einst am Ende die Inseln.
    1 Schiffbruch       Stadt mit 200 Einw./100 Siedler und eine zweite Siedlung auf einer
                        anderen Insel, Bilanz im Plus; nur 10 000 Gold und ein halb
                        leeres Schiff (20 t Werkzeug, 12 t Holz, 8 t Nahrung)           Durchschnittlich
    2 Tabak und Kakao   Tabakmonopol UND Kakaomonopol, 600 Einw./300 Buerger;
                        die Rivalen spielen wie auf Fordernd                            Durchschnittlich
    3 Der Freihafen     Handelsbilanz +400, 40 t Tabakwaren und 40 t Kakao im Lager;
                        ein grosses Handelsschiff mit Stoffen und Alkohol zum Verkaufen Fordernd
    4 Die Rote Flagge   mindestens 3 Siedlungen, JEDE mit 300 Einw./100 Buerger, Piraten
                        greifen an; zwei kleine Kriegsschiffe und 10 t Kanonen fuer
                        Wachtuerme                                                      Fordernd
    5 Verrat            das Haus Valcourt besiegen (Rivale 2, reich, Flaggschiff
                        "Valcourts Stolz"; die anderen beiden Rivalen duerfen bleiben),
                        1000 Einw./400 Kaufleute; Rivalen wie auf Schwer; ein grosses
                        und ein kleines Kriegsschiff                                    Fordernd
    6 Das Goldene       2000 Einw./800 Aristokraten und 1200 Einw./500 Kaufleute,
      Zeitalter         zusammen 4000, 40 t Schmuck, Bilanz +800, Piraten; ein grosses
                        Handelsschiff mit Baumaterial und ein grosses Kriegsschiff      Schwer

  Kampagne "Die Neue Welt" (der Reihe nach spielen) *:
  Eine Expedition der Krone landet an einer Kueste, die auf keiner Karte steht, voller
  Ureinwohnerdoerfer (bis 5 + 5, auf der grossen Karte 7 + 7); du erkundest das Land, lebst in
  Frieden mit seinen Voelkern, schickst eine Schatzflotte heim, stellst das Haus Valdoro und
  wirst erster Vizekoenig.
    1 Die Ueberfahrt    Stadt mit 300 Einw./150 Siedler, mindestens 3 Siedlungen, Bilanz
                        im Plus; ein kleines Handelsschiff ("Kundschafter") mit Werkzeug
                        und Holz fuer einen zweiten Stuetzpunkt                         Einfach
    2 Zucker und Rum    Zuckermonopol (jede Insel besitzen, auf der Zuckerrohr waechst),
                        40 t Alkohol im Lager, 500 Einw./200 Buerger                    Durchschnittlich
    3 Land der vielen   wenige riesige Inseln mit vielen Ureinwohnerdoerfern: 800 Einw./
      Voelker           300 Kaufleute, mindestens 4 Siedlungen, JEDE mit 200 Einw./
                        80 Siedler; die Rivalen spielen wie auf Fordernd                Durchschnittlich
    4 Die Schatzflotte  60 t Gewuerze und 40 t Gold im Lager, Handelsbilanz +300, Piraten
                        greifen an; ein grosses Handelsschiff mit Baumaterial und ein
                        kleines Kriegsschiff                                            Fordernd
    5 Der Konquistador  das Haus Valdoro besiegen (Rivale 3, 70 000 Gold, Flaggschiff
                        "Valdoros Zorn"; die anderen beiden Rivalen duerfen bleiben),
                        mindestens 4 Siedlungen, zusammen 2500 Einwohner; Rivalen wie auf
                        Schwer; ein grosses und ein kleines Kriegsschiff                Fordernd
    6 Der Vizekoenig    2000 Einw./800 Aristokraten, 1200 Einw./500 Kaufleute und
                        600 Einw./250 Buerger, mindestens 6 Siedlungen, Bilanz +800,
                        Piraten; ein grosses Handelsschiff mit Baumaterial und ein
                        grosses Kriegsschiff                                            Schwer

  Kampagne "Die Handelsliga" (der Reihe nach spielen) *:
  Als juengster Faktor der Liga der Sieben Staedte baust du jenseits des Ozeans ihren Handel
  auf - mit Kontobuechern statt Kanonen: Waren, Handelsbilanz und Gewinn in jedem Kapitel. Die
  Rivalen spielen hoechstens wie auf Fordernd.
    1 Das erste Kontor  Stadt mit 250 Einw./120 Siedler, 30 t Stoffe im Lager,
                        Handelsbilanz +100                                              Einfach
    2 Markttag          500 Einw./200 Buerger, 40 t Tabakwaren und 40 t Gewuerze im Lager
                        (zwei Klimazonen); ein kleines Handelsschiff                    Durchschnittlich
    3 Das Kontornetz    viele kleine Inseln: mindestens 6 Siedlungen, JEDE mit 150 Einw./
                        60 Siedler, Handelsbilanz +200; mehr Ladung und ein kleines
                        Handelsschiff                                                   Durchschnittlich
    4 Das               Baumwollmonopol, 50 t Kleidung im Lager, Handelsbilanz +300,
      Baumwollkartell   Piraten greifen an; ein kleines Kriegsschiff                    Fordernd
    5 Die Bank der Liga 1200 Einw./600 Kaufleute, Bilanz +500, Handelsbilanz +400       Fordernd
    6 Der Fuerst der    2000 Einw./700 Aristokraten, 50 t Schmuck im Lager,
      Kaufleute         Handelsbilanz +500, Bilanz +800, Piraten; ein grosses
                        Handelsschiff mit Baumaterial und ein grosses Kriegsschiff      Schwer

  Kampagne "Das Weltreich" (der Reihe nach spielen; fuer die Riesenwelt gebaut) *:
  Fuenf Inselreiche, getrennt durch Wochen auf offener See: Von der Kronsee im Nordwesten aus
  greifst du nach dem Nebelmeer, den Gewuerzinseln und der Korallensee, besiegst das Haus Morvan
  und baust das erste Weltreich auf.
    1 Die grosse Fahrt  Stadt mit 500 Einw./250 Siedler, mindestens 3 Siedlungen, zusammen
                        900 Einwohner; ein grosses Handelsschiff mit Werkzeug, Holz und
                        Nahrung                                                         Einfach
    2 Das Nebelmeer     50 t Stoffe und 40 t Tabakwaren im Lager, 800 Einw./300 Buerger,
                        mindestens 4 Siedlungen                                         Durchschnittlich
    3 Die Gewuerzroute  60 t Gewuerze im Lager, Handelsbilanz +250, 1200 Einw./400 Kauf-
                        leute, Piraten greifen an; ein grosses Handelsschiff und ein
                        kleines Kriegsschiff                                            Durchschnittlich
    4 Die Korallensee   Baumwollmonopol UND Kakaomonopol, mindestens 5 Siedlungen mit
                        zusammen 3000 Einwohnern, Piraten greifen an                    Fordernd
    5 Krieg der Kronen  das Haus Morvan besiegen (Rivale 2, 80 000 Gold, Flaggschiff
                        "Eiserne Faust"; die beiden anderen duerfen bleiben), mindestens
                        5 Siedlungen, zusammen 4000 Einwohner; Rivalen wie auf Schwer;
                        ein grosses und ein kleines Kriegsschiff                        Fordernd
    6 Das Weltreich     3000 Einw./1200 Aristokraten, 2000 Einw./800 Kaufleute und
                        1200 Einw./500 Buerger, mindestens 7 Siedlungen, zusammen 8000,
                        Bilanz +1500, Piraten; ein grosses Handelsschiff mit Baumaterial
                        und ein grosses Kriegsschiff                                    Schwer

  Herausforderungen (einzeln):
    Inselreich          8 eigene Siedlungen mit zusammen 3000 Einwohnern
    Handelsimperium     50 t Schmuck und 80 t Kleidung im Lager, Handelsbilanz +300
    Goldrausch          60 t Gold und 40 t Schmuck im Lager, Piraten; Start mit kleinem Kriegsschiff
    Archipel *          Dutzende kleiner Inseln: mindestens 10 Siedlungen, JEDE mit
                        100 Einw./40 Siedler (auch ein Kontor ohne Haeuser zaehlt als
                        Siedlung); mehr Ladung und ein kleines Handelsschiff
    Kontinente *        wenige riesige Inseln: 1500 Einw./400 Aristokraten, zusammen 3000,
                        Bilanz +300
    Handelsflotte *     4 Siedlungen, 60 t Gewuerze und 60 t Kakao im Lager; nur 15 000 Gold,
                        aber zwei grosse Handelsschiffe voller Waren und ein kleines Kriegsschiff
    Seemacht *          alle drei Rivalen besiegen; sie sind arm (10 000 Gold), du hast
                        60 000 Gold, zwei grosse und ein kleines Kriegsschiff
    Kolonialherr *      Weinmonopol (Norden) UND Kakaomonopol (Sueden), mindestens
                        4 Siedlungen, JEDE mit 250 Einw./80 Buerger
    Monopolist *        Gewuerzmonopol UND Tabakmonopol, Handelsbilanz +400; reiche Rivalen
                        wie auf Schwer; Start mit grossem Kriegsschiff
    Ruhige See *        keine Piraten, aber karge Inseln und reiche Rivalen wie auf Schwer:
                        1200 Einw./500 Kaufleute, zusammen 2500, Bilanz +300
    Habenichts *        nur 8000 Gold und 15 t Werkzeug, 10 t Holz, 5 t Nahrung: 600 Einw./
                        250 Buerger, Bilanz +200; Rivalen wie auf Fordernd
    Gegen die Uhr *     500 Einw./250 Siedler - ZEITLIMIT 3 Stunden
    Die Frist des       1000 Einw./400 Buerger, Bilanz +300 - ZEITLIMIT 6 Stunden; Piraten
      Koenigs *         greifen an; Start mit kleinem Kriegsschiff
    Sieben Meere *      (Riesenwelt) mindestens 7 Siedlungen, JEDE mit 300 Einw./120 Siedler,
                        zusammen 4000, Bilanz +300, Piraten
    Die Welt-           (Riesenwelt) Weinmonopol (Norden) UND Gewuerzmonopol (Sueden),
      umsegelung *      Handelsbilanz +400, Piraten greifen an

  Riesenwelt: Das Spiel kennt hoechstens 50 Inseln (10 der groessten Sorte). Die Riesenwelt-
  Karten von "Das Weltreich", Sieben Meere und Die Weltumsegelung fassen sie deshalb zu fuenf
  Inselreichen mit offenem Meer dazwischen zusammen - die Kronsee im Nordwesten (dort starten
  alle Schiffe), das Nebelmeer im Nordosten, die Mittelsee, die Korallensee im Suedwesten und
  die Gewuerzinseln im Suedosten. Vor dem Spielen den Knopf "Riesenwelt" waehlen (Karte
  2000 x 1400). Bei einer kleineren Karte gilt die Fassung fuer 1000 x 700 oder die klassische.

  Zeitlimits: "Gegen die Uhr", "Die Frist des Koenigs" und selbst gebaute Szenarien koennen
  eines haben. Laeuft die Zeit ab, ist der Auftrag verloren.
    - Das Zeitlimit gilt nur mit den Erweiterungen: Das Werkzeug setzt es bei jedem Start und
      bei jedem Laden eines Spielstands. Mit "Original starten" hat dasselbe Szenario keines.
    - Solange ein Zeitlimit gesetzt ist, zeigt das Spiel unten links seine eigene Uhr: die
      verstrichene Spielzeit als Minuten:Sekunden. "180:00" ist das Ende eines Zeitlimits von
      3 Stunden, "360:00" das eines von 6 Stunden.
    - Das Logbuch zeigt die verbleibende Zeit, z. B. "Zeitlimit: noch 2 h 44 min (Uhr 15:03
      von 180:00)".
    - Es zaehlt die Spielzeit: Eine Pause haelt die Uhr an, der Turbo laesst sie schneller
      laufen (und gewinnt keine Zeit). Bei normalem Tempo dauert eine Stunde auf dieser Uhr
      rund 66 Minuten.

  Kapitel nacheinander freischalten (Kaestchen auf der Registerkarte "Abenteuer", anfangs aus):
  Dann stehen in der Liste des Spiels von jeder Kampagne nur die Kapitel bis zum ersten, das du
  noch nicht gewonnen hast. Die spaeteren zeigt das Startfenster grau mit einem Schloss
  ("gesperrt - zuerst Kapitel 2 gewinnen"). Nach einem Sieg legt das Startfenster beim
  naechsten Start das naechste Kapitel dazu ("neu freigeschaltet"). Die Siege zeichnet das
  Logbuch auf - also das Logbuch offen haben, waehrend du ein Kapitel spielst. Ohne Haekchen
  ist wieder jedes Kapitel in der Liste des Spiels. Herausforderungen und Abenteuer sind nie
  gesperrt.

  Zufallsabenteuer (Registerkarte "Abenteuer"): Schwierigkeit waehlen (Einfach,
  Durchschnittlich, Fordernd, Schwer), freiwillig eine Nummer von 0 bis 999999 eingeben und
  "Abenteuer wuerfeln" klicken. Das Szenario "Abenteuer <Nummer> <Schwierigkeit>" (zum
  Beispiel "Abenteuer 4711 Fordernd") erscheint unter "Eigene Szenarien".
  Jedes Abenteuer hat eine eigene Inselwelt (klassisch, ein Archipel kleiner Inseln oder
  wenige riesige Kontinente) und ein Hauptziel - Staedte, ein Inselreich aus vielen
  Siedlungen, Handel, ein Monopol oder Eroberung - dazu Zusatzziele, die mit der
  Schwierigkeit wachsen. Startgold, Piraten, Staerke der Rivalen und deine Startladung richten
  sich ebenfalls nach der Schwierigkeit.
  Dieselbe Nummer mit derselben Schwierigkeit ergibt immer dasselbe Abenteuer: So kannst du
  eine Karte nochmals spielen oder die Nummer einem Freund geben. Dieselbe Nummer mit einer
  anderen Schwierigkeit ist ein eigenes Abenteuer.

  Tagesabenteuer (Knopf "Tagesabenteuer" neben "Abenteuer wuerfeln"): ein Abenteuer pro Tag,
  immer Durchschnittlich und an diesem Datum fuer alle gleich - "Tagesabenteuer 2026-11-15"
  unter "Eigene Szenarien". Die frueheren bleiben in der Liste.

  Eigenes Szenario bauen ("Eigenes Szenario bauen ..." auf der Registerkarte "Abenteuer"): ein
  Fenster, in dem du dir einen Auftrag selbst zusammenstellst.
    Szenario   Name (bis 40 Zeichen), Karte (Klassisch, Archipel oder Kontinente),
               Kartennummer ("Neue Karte" wuerfelt eine andere; dieselbe Nummer ergibt immer
               dieselbe Karte), Schwierigkeit und auf Wunsch "auch fuer die Riesenwelt
               2000 x 1400" (eine dritte Karte mit fuenf Inselreichen)
    Welt       dein Startgold, Gold und Staerke der Gegner (Zoegerlich bis Stark), Piraten
               (nur gesichtet oder greifen an), Ureinwohner, Rohstoffe, Startladung
               (Standard, Reichlich, Knapp, Schiffbruch), bis 3 weitere Handels- oder
               Kriegsschiffe
    Auftrag    beliebige Ziele: bis 3 Staedte (Einwohner, davon so viele einer Stufe oder
               hoeher), jede Siedlung mindestens ..., Anzahl Siedlungen, Einwohner
               insgesamt, Bilanz, Handelsbilanz, bis 2 Waren im Lager, bis 2 Monopole,
               Gegner 1, 2 oder 3 besiegen - und auf Wunsch ein Zeitlimit von 1 bis 50
               Spielstunden
    Geschichte passend zu Karte und Auftrag geschrieben; aendere sie nach Lust und Laune
               oder hol dir mit "Neue Geschichte" eine andere
  Die Vorschau zeigt den Auftragstext genau so, wie ihn das Spiel zeigt, dazu die kleine und
  die grosse Karte. Fehler stehen rot da (dann laesst sich nichts bauen), Hinweise orange.
  "Szenario erstellen" legt es als "Eigenes - <Name>" unter "Eigene Szenarien" ab, und das
  Startfenster waehlt es in seiner Liste aus. Dein letzter Entwurf bleibt gespeichert.

  Grosse Karten: Jedes Szenario (auch die Zufalls- und Tagesabenteuer und deine eigenen) hat
  zwei Fassungen. Mit "Original starten" gilt die klassische Karte (500 x 350, meist
  17-20 Inseln). Mit "Mit Erweiterungen spielen", Kartengroesse 1000 x 700 (oder groesser) und
  "Mehr Inseln" gilt die grosse Fassung: bis 50 Inseln, mehr Rohstoffe und Ureinwohner.
  Gegner-, Piraten-, Einwohner-, Lager-, Turbo-, Ereignis- und die Wirtschafts-Optionen wirken
  auch hier, "Jede Pflanze auf jeder Insel" nicht (sie wuerde die Monopol-Auftraege brechen).
  Die Gold-Optionen ersetzen das Startgold des Szenarios; fuer die vorgesehene Balance
  "Wie Schwierigkeit" waehlen (oder den Knopf "Fuer Kampagnen").
  Die Dateien liegen in Dokumente\Anno 1602 History Edition\Own Scenarios.

  Mehr als 3 Computergegner gibt es nicht: Das Spiel hat fest 4 Spielerplaetze (du + 3), dazu
  Haendler, Piraten und Ureinwohner auf festen Plaetzen, 4 Flaggenfarben und ein festes
  Spielstandformat. Die Gegner werden stattdessen staerker.

Wichtig:
  - Spielstaende aus der grossen Welt nur mit den Erweiterungen und derselben Kartengroesse
    laden - am einfachsten ueber die Registerkarte "Weiterspielen". Der Spielstand selbst
    speichert die Groesse nicht.
  - Das schwarze Fenster bleibt offen, bis das Spiel beendet ist. Danach wird ein
    automatischer Spielstand ("Spiel fortsetzen") aus der grossen Welt umbenannt, damit
    ihn das Spiel ohne Erweiterungen nicht laedt, und die Optionen jedes in dieser Sitzung
    gespeicherten Spielstands werden fuer "Weiterspielen" gemerkt. Das Fenster nicht vorher
    schliessen. Danach schliesst es sich von selbst; offen bleibt es nur bei einem Fehler.
  - Auch die Ereignisse brauchen das schwarze Fenster: Es loest sie aus und stellt Steuern und
    Produktion danach zurueck. Wird es geschlossen, endet ein laufendes Ereignis; das Spiel
    laeuft weiter.
  - Vor jedem Start werden die Spielstaende gesichert (Dokumente\Anno 1602 History Edition\
    Savegame-Backup-<Datum>), aber nur, wenn sich etwas geaendert hat. Die erste und die
    fuenf neuesten Sicherungen bleiben, aeltere wandern in den Papierkorb.
  - Nur fuer das Einzelspiel und nur fuer die Ubisoft-Connect-Version. Nach einem Update des
    Spiels passt das Werkzeug nicht mehr und bricht ab, ohne etwas zu aendern.

Dateien (im Ordner %LOCALAPPDATA%\Programs\Anno1602-Extensions):
  launcher.ps1          das Fenster
  anno-patcher.ps1      das Werkzeug (auch direkt nutzbar, Optionen siehe Kopf der Datei)
  logbook.ps1           das Logbuch-Fenster
  random-adventure.ps1  der Zufallsabenteuer-Generator (auch fuer das Tagesabenteuer)
  scenario-designer.ps1 das Fenster zum Bauen eigener Szenarien
  build-scenarios.ps1   baut die Szenarien (fuer Installer, Generator und eigene Szenarien)
  scenario-lib.ps1      liest und schreibt Szenario-Dateien
  README.de.txt         diese Anleitung
  README.txt            diese Anleitung auf Englisch
  FINDINGS.md           technische Beschreibung aller Fundstellen im Spielcode (Englisch)
  Deine Einstellungen, die Optionen der Spielstaende, das Logbuch mit den Kurven deiner
  Partien, die Ereignisse und dein letzter Entwurf: %APPDATA%\Anno1602-Extensions
