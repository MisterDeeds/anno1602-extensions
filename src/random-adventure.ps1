<#
.SYNOPSIS
  Random adventure generator for Anno 1602 History Edition: builds a fresh, fair scenario from a seed
  and a difficulty ("Abenteuer <seed> <difficulty>" / "Adventure <seed> <difficulty>", e.g. "Abenteuer 4711 Fordernd"),
  or the adventure of the day ("Tagesabenteuer <yyyy-MM-dd>" / "Daily Adventure <yyyy-MM-dd>").

.DESCRIPTION
  Uses the same chapter builder as the campaigns (src\build-scenarios.ps1, loaded as a library):
  endless-game template, mirrored layout, the patcher's island planner for the big version
  (1000 x 700, up to 50 islands), free starting point for the ships, mission and text.
  The generator picks from a deterministic random generator (Park-Miller, seeded from -Seed):
    map       template layout 0-2, mirroring, one of three kinds: classic (some islands one class
              bigger), archipelago (26-30 small islands) or continents (a few huge islands);
              island size of the big version (Normal/Large/Huge)
    world     ore, gold, treasures, crops (matched to the mission), native villages, starting gold
              for you and the rivals, pirates, rivals' strength (the game's difficulty 0-3)
    ships     start cargo (rich on Easy, sometimes lean on Hard), extra ships where the mission needs them
    mission   one main goal (towns, realm of many settlements, trade, monopoly, conquest) plus add-ons
              (balance, trade balance, goods in stock, total residents, a town), scaled to the
              difficulty; only goal types and value ranges that the campaigns already use
    text      title, a short story from text blocks, the goals, the helmsman's advice (German and English)
  Same seed + same difficulty = the same scenario in both languages; the file is byte-identical on
  every run. The seed and difficulty are stored in SZENE_GAMEID (0x53000000 + difficulty << 20 + seed),
  so tests\check-scenarios.ps1 -Reproduce can regenerate the file and compare it.

  Daily adventure (-Daily): the seed comes from the date (the same adventure for everyone on that day, see
  Get-DailySeed), the difficulty is Average unless -Difficulty is given; only the name and the first line of the
  mission text differ from "Abenteuer <seed>".

  Library use: dot-source with -Library to get the building blocks (text blocks, goal texts, map rules, the
  random generator) without building anything; src\scenario-designer.ps1 does this. As with build-scenarios.ps1,
  the parameters land in the caller's scope, so pass -Language, -OutFolder and -GamePath.

.PARAMETER Seed
  0 to 999999; default: a random seed (printed).
.PARAMETER Difficulty
  Easy, Average (default), Demanding or Hard (Einfach, Durchschnittlich, Fordernd, Schwer).
.PARAMETER Daily
  Build the daily adventure of today (local date) or of -Date.
.PARAMETER Date
  With -Daily: the day as yyyy-MM-dd (default: today), e.g. to rebuild an older daily adventure.
.PARAMETER Language
  de or en (default: German on a German Windows, English otherwise; $env:ANNO_EXTENSIONS_LANG).
.PARAMETER OutFolder
  Output folder (default src\scenarios).
.PARAMETER Install
  Also copy the file to Documents\Anno 1602 History Edition\Own Scenarios.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\src\random-adventure.ps1 -Seed 4711 -Difficulty Demanding -Install
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\src\random-adventure.ps1 -Daily -Install
#>
param(
    [ValidateRange(-1, 999999)][int]$Seed = -1,
    [ValidateSet('Easy', 'Average', 'Demanding', 'Hard')][string]$Difficulty = 'Average',
    [switch]$Daily,
    [string]$Date,
    [ValidateSet('', 'de', 'en')][string]$Language = '',
    [string]$OutFolder,
    [switch]$Install,
    [string]$GamePath,
    [switch]$Library
)
$ErrorActionPreference = 'Stop'
$AdvLibraryOnly = [bool]$Library
# The builder's parameters land in this scope: keep our own values and pass the shared ones through.
$AdvSeed = $Seed; $AdvLevelName = $Difficulty; $AdvInstall = [bool]$Install; $AdvDay = $null
if (-not $AdvLibraryOnly) {
    if ($Daily) {
        if ($Seed -ge 0) { throw '-Daily takes its seed from the date; do not give -Seed as well.' }
        $AdvDay = if ($Date) { [datetime]::ParseExact($Date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture) } else { (Get-Date).Date }
    }
    elseif ($Date) { throw '-Date only works together with -Daily.' }
}
. (Join-Path $PSScriptRoot 'build-scenarios.ps1') -Library -GamePath $GamePath -Language $Language -OutFolder $OutFolder
$AdvLevel = @{ Easy = 0; Average = 1; Demanding = 2; Hard = 3 }[$AdvLevelName]

# --- Deterministic random numbers (Park-Miller minimal standard, 31 bits) ------------------------
function Reset-AdvRandom([int]$attempt, [int]$seed) {
    $script:AdvState = [long](([long]$seed * 2654435761 + [long]$attempt * 40503 + 1013904223) % 2147483647)
    if ($script:AdvState -le 0) { $script:AdvState += 2147483646 }
    for ($i = 0; $i -lt 4; $i++) { $null = Get-AdvInt 2 }
}
function Get-AdvInt([int]$n) { $script:AdvState = ($script:AdvState * 48271) % 2147483647; [int](($script:AdvState -shr 4) % $n) }
function Get-AdvPick($list) { $list[(Get-AdvInt $list.Count)] }
function Test-AdvChance([int]$percent) { (Get-AdvInt 100) -lt $percent }
# Weighted choice: @(@(item, weight), ...)
function Get-AdvWeighted($pairs) {
    $total = 0; foreach ($p in $pairs) { $total += $p[1] }
    $r = Get-AdvInt $total
    foreach ($p in $pairs) { if ($r -lt $p[1]) { return $p[0] }; $r -= $p[1] }
}
function Get-AdvShuffled($list) {
    $a = [System.Collections.ArrayList]@($list)
    for ($i = $a.Count - 1; $i -gt 0; $i--) { $j = Get-AdvInt ($i + 1); $tmp = $a[$i]; $a[$i] = $a[$j]; $a[$j] = $tmp }
    , $a.ToArray()
}
# Seed of the daily adventure: the date yyyyMMdd through a multiplicative hash (Knuth), the high bits of the
# 32-bit result, below 1,000,000. Integer arithmetic only, so every PC gets the same seed for the same day.
function Get-DailySeed([datetime]$day) {
    $ymd = [long]$day.ToString('yyyyMMdd', [Globalization.CultureInfo]::InvariantCulture)
    [int](((($ymd * 2654435761) % 4294967296) -shr 12) % 1000000)
}

# --- Text building blocks (German / English; German umlauts in Windows-1252) --------------------
$LevelText = @(@{ de = 'Einfach'; en = 'Easy' }, @{ de = 'Durchschnittlich'; en = 'Average' }, @{ de = 'Fordernd'; en = 'Demanding' }, @{ de = 'Schwer'; en = 'Hard' })
$StageText = @{ de = @('Pioniere', 'Siedler', 'Bürger', 'Kaufleute', 'Aristokraten'); en = @('pioneers', 'settlers', 'citizens', 'merchants', 'aristocrats') }
$GoodText = @{
    3 = @{ de = 'Gold'; en = 'gold' }; 12 = @{ de = 'Musketen'; en = 'muskets' }; 13 = @{ de = 'Kanonen'; en = 'cannons' }
    15 = @{ de = 'Tabakwaren'; en = 'tobacco goods' }; 16 = @{ de = 'Gewürze'; en = 'spices' }; 17 = @{ de = 'Kakao'; en = 'cocoa' }
    18 = @{ de = 'Alkohol'; en = 'liquor' }; 19 = @{ de = 'Stoffe'; en = 'cloth' }; 20 = @{ de = 'Kleidung'; en = 'clothes' }
    21 = @{ de = 'Schmuck'; en = 'jewellery' }; 24 = @{ de = 'Ziegel'; en = 'bricks' }
}
# Crops for monopolies: mission code, SZENE fertility key, texts.
$Crops = @(
    @{ Res = 0x2F; Plant = 'Spices'; de = 'Gewürze'; deDat = 'Gewürzen'; deMono = 'das Gewürzmonopol'; deGrow = 'Gewürze wachsen'; en = 'spices'; enMono = 'the spice monopoly'; enGrow = 'spices grow' }
    @{ Res = 0x2E; Plant = 'Tobacco'; de = 'Tabak'; deDat = 'Tabak'; deMono = 'das Tabakmonopol'; deGrow = 'Tabak wächst'; en = 'tobacco'; enMono = 'the tobacco monopoly'; enGrow = 'tobacco grows' }
    @{ Res = 0x33; Plant = 'Cocoa'; de = 'Kakao'; deDat = 'Kakao'; deMono = 'das Kakaomonopol'; deGrow = 'Kakao wächst'; en = 'cocoa'; enMono = 'the cocoa monopoly'; enGrow = 'cocoa grows' }
    @{ Res = 0x30; Plant = 'Sugar'; de = 'Zuckerrohr'; deDat = 'Zucker'; deMono = 'das Zuckermonopol'; deGrow = 'Zuckerrohr wächst'; en = 'sugar cane'; enMono = 'the sugar monopoly'; enGrow = 'sugar cane grows' }
    @{ Res = 0x32; Plant = 'Wine'; de = 'Wein'; deDat = 'Wein'; deMono = 'das Weinmonopol'; deGrow = 'Wein wächst'; en = 'wine'; enMono = 'the wine monopoly'; enGrow = 'wine grows' }
)
$Places = @('Caldera', 'Esmeralda', 'Tortuna', 'Belmar', 'Navarra', 'Valmora', 'Corvina', 'Altamar', 'Mirabel', 'Aurelia', 'Solvento', 'Marisol',
    'Coralina', 'Montaro', 'Rocabella', 'Zefiria', 'Ambra', 'Leandra', 'Brisante', 'Velamar', 'Santa Lucera', 'Porto Cielo', 'Tierra Alta', 'Oriana')
$Houses = @('Grimaldi', 'Mortimer', 'Delacroix', 'Montalban', 'Blackwood', 'Lindqvist', 'Vanderberg', 'Castellane', 'Ashford', 'Dunmore', 'Moreau', 'Ravensworth')
$TraderNames = @(@{ de = 'Seestern'; en = 'Sea Star' }, @{ de = 'Albatros'; en = 'Albatross' }, @{ de = 'Nordwind'; en = 'North Wind' }, @{ de = 'Merkur'; en = 'Mercury' }, @{ de = 'Hoffnung'; en = 'Hope' }, @{ de = 'Fortuna'; en = 'Fortuna' })
$WarshipNames = @(@{ de = 'Seewolf'; en = 'Sea Wolf' }, @{ de = 'Greif'; en = 'Griffin' }, @{ de = 'Donnerkeil'; en = 'Thunderbolt' }, @{ de = 'Wehrhaft'; en = 'Stalwart' }, @{ de = 'Sturmvogel'; en = 'Storm Petrel' }, @{ de = 'Hai'; en = 'Shark' })

# de/en pair, optionally with {0}, {1} ... formatted in both languages.
function New-AdvText([string]$de, [string]$en) { @{ de = $de; en = $en } }
function Join-AdvNames($names, [string]$lang) {
    $q = @($names | ForEach-Object { '"' + $_[$lang] + '"' })
    if ($q.Count -le 1) { return $q -join '' }
    ($q[0..($q.Count - 2)] -join ', ') + $(if ($lang -eq 'de') { ' und ' } else { ' and ' }) + $q[-1]
}

# Story: opening per map kind ({0} = place), motive per main goal, twists, the helmsman's advice, closing line.
$AdvOpenings = @{
    Classic     = @((New-AdvText 'Gouverneur, vor Euch liegen die Inseln von {0}: grüne Küsten, dichte Wälder und Buchten, in denen noch nie ein Anker gefallen ist.' 'Governor, before you lie the isles of {0}: green coasts, dense forests and bays where no anchor has ever dropped.'),
        (New-AdvText 'Gouverneur, auf den Seekarten der Kompanie sind die Inseln von {0} nur weisse Flecken - nun liegen sie vor Euch.' "Governor, on the company's sea charts the isles of {0} are blank spots - now they lie before you."),
        (New-AdvText 'Gouverneur, nach langer Überfahrt kommen die Inseln von {0} in Sicht: grosse und kleine Inseln, so weit das Fernrohr reicht.' 'Governor, after a long voyage the isles of {0} come into view: large and small islands as far as the telescope reaches.'))
    Archipelago = @((New-AdvText 'Gouverneur, die Inseln von {0} sind zahlreich wie Sterne und klein wie Taschentücher - keine trägt mehr als eine bescheidene Stadt.' 'Governor, the isles of {0} are as numerous as the stars and as small as handkerchiefs - none carries more than a modest town.'),
        (New-AdvText 'Gouverneur, vor Euch liegt das Inselgewirr von {0}: Dutzende kleiner Inseln, getrennt von schmalen Wasserstrassen.' 'Governor, before you lies the maze of {0}: dozens of small islands, separated by narrow straits.'))
    Continents  = @((New-AdvText 'Gouverneur, bei {0} ragen nur eine Handvoll gewaltiger Inseln aus dem Meer - Land genug für Metropolen, aber nicht genug für vier Häuser.' 'Governor, near {0} only a handful of mighty islands rise from the sea - land enough for great cities, but not enough for four houses.'),
        (New-AdvText 'Gouverneur, die Inseln von {0} sind so gross, dass man sie für Festland halten könnte. Wer die besten Küsten zuerst besetzt, hat gewonnen.' 'Governor, the isles of {0} are so large that one could take them for the mainland. Whoever occupies the best coasts first has the advantage.'))
}
$AdvMotives = @{
    Towns = @((New-AdvText 'Die Handelskompanie will hier eine Stadt sehen, die den Häfen der Alten Welt ebenbürtig ist.' 'The trading company wants to see a town here that rivals the ports of the Old World.'),
        (New-AdvText 'Der König verlangt eine Kolonie, auf die er stolz sein kann - und er ist nicht leicht zu beeindrucken.' 'The King demands a colony he can be proud of - and he is not easily impressed.'))
    Realm = @((New-AdvText 'Die Krone will ihre Flagge auf möglichst vielen Inseln wehen sehen.' 'The Crown wants to see its flag flying on as many islands as possible.'),
        (New-AdvText 'Die Kompanie zahlt für jede Insel, auf der ihr Wappen weht.' 'The company pays for every island on which its coat of arms flies.'))
    Trade = @((New-AdvText 'Die Kaufleute von Antwerpen wollen volle Lagerhäuser sehen - und eine Kasse, die klingelt.' 'The merchants of Antwerp want to see full storehouses - and a till that rings.'),
        (New-AdvText 'Die Kompanie hat Schulden. Sie braucht Waren und Gewinne, keine Paläste.' 'The company is in debt. It needs goods and profits, not palaces.'))
}
# Monopoly motive: the crops of the mission ($Crops entries).
function Get-AdvMonopolyMotive($crops) {
    $cropsDe = ($crops | ForEach-Object { $_.deDat }) -join ' und '; $cropsEn = ($crops | ForEach-Object { $_.en }) -join ' and '
    New-AdvText ('Die Kompanie will den Handel mit {0} beherrschen - und auf diesen Inseln wächst, was Europa begehrt.' -f $cropsDe) ('The company wants to control the trade in {0} - and these islands grow what Europe craves.' -f $cropsEn)
}
# Conquest motive: no house names = all three rivals, otherwise the one or two houses to defeat.
function Get-AdvConquestMotive($houses) {
    $hn = @($houses)
    if ($hn.Count -eq 0) { New-AdvText 'Alle drei Rivalen haben sich gegen Euch verbündet. Die Zeit der Verhandlungen ist vorbei.' 'All three rivals have allied against you. The time for negotiations is over.' }
    elseif ($hn.Count -eq 1) { New-AdvText ('Das Haus {0} hat Eure Handelsposten überfallen und Eure Schiffe versenkt. Die Kompanie verlangt Vergeltung.' -f $hn[0]) ('House {0} has raided your trading posts and sunk your ships. The company demands retribution.' -f $hn[0]) }
    else { New-AdvText ('Die Häuser {0} und {1} haben sich gegen Euch verbündet. Die Zeit der Verhandlungen ist vorbei.' -f $hn[0], $hn[1]) ('The houses of {0} and {1} have allied against you. The time for negotiations is over.' -f $hn[0], $hn[1]) }
}
$AdvMainHints = @{
    Towns    = @((New-AdvText 'Eine grosse Stadt braucht viele Waren. Sichert Euch früh eine zweite Insel mit anderem Klima und richtet Handelsrouten ein.' 'A big town needs many goods. Secure a second island with a different climate early and set up trade routes.'),
        (New-AdvText 'Achtet auf die Bedürfnisse Eurer Einwohner: Nur wer zufrieden ist, steigt auf. Märkte, Kapellen und Wirtshäuser zahlen sich aus.' 'Mind the needs of your residents: only the content move up. Marketplaces, chapels and taverns pay off.'))
    Realm    = @(New-AdvText 'Kleine Inseln sind billig zu besiedeln, aber jede Siedlung braucht einen eigenen Marktplatz und Waren. Ein zweites Schiff hilft beim Verteilen.' 'Small islands are cheap to settle, but every settlement needs its own marketplace and goods. A second ship helps with the distribution.')
    Trade    = @(New-AdvText 'Stellt im Kontor ein, was Ihr verkaufen wollt, kauft nur, was Ihr wirklich braucht, und baut Lager aus, damit nichts verloren geht.' 'Set in the warehouse what you want to sell, buy only what you really need, and expand your storage so that nothing is lost.')
    Monopoly = @(New-AdvText 'Erkundet früh mit dem Schiff, welche Inseln die begehrten Pflanzen tragen (Fruchtbarkeit im Inselinfo). Dörfer der Ureinwohner stören ein Monopol nicht, Siedlungen der Rivalen schon.' 'Explore early by ship to find out which islands bear the coveted crops (fertility in the island info). Native villages do not spoil a monopoly, rival settlements do.')
    Conquest = @(New-AdvText 'Ein Krieg wird mit Gold gewonnen. Baut zuerst eine starke Wirtschaft, dann Burgen, Kasernen und eine Flotte.' 'A war is won with gold. First build a strong economy, then castles, barracks and a fleet.')
}
$AdvTwists = @{
    Pirates      = New-AdvText 'Piraten kreuzen in diesen Gewässern und kapern jedes schwach bewaffnete Schiff.' 'Pirates cruise these waters and seize every poorly armed ship.'
    StrongRivals = New-AdvText 'Eure Rivalen sind entschlossen und gut ausgerüstet.' 'Your rivals are determined and well equipped.'
    WeakRivals   = New-AdvText 'Eure Rivalen sind zögerlich - nutzt den Vorsprung.' 'Your rivals are hesitant - make the most of your lead.'
    Natives      = New-AdvText 'Auf vielen Inseln leben Ureinwohner - lasst sie in Frieden, dann lassen sie Euch in Frieden.' 'Natives live on many islands - leave them in peace and they will leave you in peace.'
    RichCargo    = New-AdvText 'Die Kompanie hat Euch reichlich Werkzeug und Holz mitgegeben.' 'The company has given you plenty of tools and wood.'
    LeanCargo    = New-AdvText 'Ein Sturm hat einen Teil Eurer Ladung gekostet.' 'A storm has cost you part of your cargo.'
}
$AdvHints = @{
    Tools   = New-AdvText 'Werkzeug ist knapp: Stellt es im Kontor auf Einkauf, die freien Händler bringen es Euch.' 'Tools are scarce: set them to "buy" in the warehouse, the free traders will bring them to you.'
    Pirates = New-AdvText 'Lasst Eure Handelsschiffe nicht unbegleitet fahren.' 'Do not let your trading ships sail unescorted.'
    Ore     = New-AdvText 'Kanonen und Musketen brauchen Eisen, und Eisen braucht Erz: Sichert Euch früh eine Erzinsel.' 'Cannons and muskets need iron, and iron needs ore: secure an ore island early.'
    Gold    = New-AdvText 'Gold gibt es nur in wenigen Bergen. Wer die Goldminen zuerst besetzt, hat gewonnen.' 'There is gold in only a few mountains. Whoever occupies the gold mines first has the advantage.'
}
$AdvClosings = @((New-AdvText 'Viel Glück, Gouverneur!' 'Good luck, Governor!'), (New-AdvText 'Möge der Wind Euch gewogen sein!' 'May the wind be kind to you!'), (New-AdvText 'Die Kompanie zählt auf Euch.' 'The company is counting on you.'))
# Extra ships of the human player: list of names (@{ de; en }).
function Get-AdvFleetTwist($names) {
    $n = @($names).Count
    New-AdvText ($(if ($n -eq 1) { 'Mit Euch segelt ein weiteres Schiff: {0}.' } else { 'Mit Euch segeln {1} weitere Schiffe: {0}.' }) -f (Join-AdvNames $names 'de'), @('', 'ein', 'zwei', 'drei')[$n]) ($(if ($n -eq 1) { 'One more ship sails with you: {0}.' } else { '{1} more ships sail with you: {0}.' }) -f (Join-AdvNames $names 'en'), @('', 'One', 'Two', 'Three')[$n])
}

# --- Goal texts: one bullet of "Your orders" each (the numbers exactly as in the mission) ---------
# Town goal $g (@{ Residents; Stage; OfWhich }) as town number $k (1-3).
function Get-AdvTownBullet($g, [int]$k) {
    $prefixDe = if ($k -eq 1) { 'Eine Stadt' } elseif ($k -eq 2) { 'Eine zweite Stadt' } else { 'Eine dritte Stadt' }
    $prefixEn = if ($k -eq 1) { 'A town' } elseif ($k -eq 2) { 'A second town' } else { 'A third town' }
    $hiDe = if ($g.Stage -lt 4) { ' oder höher' } else { '' }; $hiEn = if ($g.Stage -lt 4) { ' or higher' } else { '' }
    New-AdvText ('{0} mit mindestens {1} Einwohnern, davon {2} {3}{4}.' -f $prefixDe, $g.Residents, $g.OfWhich, $StageText.de[$g.Stage], $hiDe) ('{0} with at least {1} residents, {2} of them {3}{4}.' -f $prefixEn, $g.Residents, $g.OfWhich, $StageText.en[$g.Stage], $hiEn)
}
# Number of settlements; $warehouseNote: "(one warehouse each)" (without an "every settlement" goal).
function Get-AdvTownCountBullet([int]$n, [bool]$warehouseNote) {
    if ($warehouseNote) { New-AdvText ('Gründet mindestens {0} eigene Siedlungen (je ein Kontor).' -f $n) ('Found at least {0} settlements of your own (one warehouse each).' -f $n) }
    else { New-AdvText ('Gründet mindestens {0} eigene Siedlungen.' -f $n) ('Found at least {0} settlements of your own.' -f $n) }
}
function Get-AdvAllTownsBullet($g) {
    New-AdvText ('JEDE Eurer Siedlungen braucht mindestens {0} Einwohner, davon {1} {2} oder höher. Auch ein Kontor ohne Häuser zählt als Siedlung!' -f $g.Residents, $g.OfWhich, $StageText.de[$g.Stage]) ('EVERY one of your settlements needs at least {0} residents, {1} of them {2} or higher. Even a warehouse without houses counts as a settlement!' -f $g.Residents, $g.OfWhich, $StageText.en[$g.Stage])
}
function Get-AdvTotalBullet([int]$total) {
    New-AdvText ('Alle Eure Siedlungen zusammen sollen mindestens {0} Einwohner haben.' -f $total) ('All your settlements together shall have at least {0} residents.' -f $total)
}
# Goods in stock: one or two entries @{ Good; Tons }.
function Get-AdvGoodsBullet($goods) {
    $list = @($goods)
    if ($list.Count -eq 1) {
        $g = $list[0]
        New-AdvText ('Lagert mindestens {0} Tonnen {1} in Euren Kontoren.' -f $g.Tons, $GoodText[$g.Good].de) ('Store at least {0} tons of {1} in your warehouses.' -f $g.Tons, $GoodText[$g.Good].en)
    }
    else {
        $g = $list[0]; $h = $list[1]
        New-AdvText ('Lagert mindestens {0} Tonnen {1} und {2} Tonnen {3} in Euren Kontoren.' -f $g.Tons, $GoodText[$g.Good].de, $h.Tons, $GoodText[$h.Good].de) ('Store at least {0} tons of {1} and {2} tons of {3} in your warehouses.' -f $g.Tons, $GoodText[$g.Good].en, $h.Tons, $GoodText[$h.Good].en)
    }
}
function Get-AdvTradeBalanceBullet([int]$tb) {
    New-AdvText ('Erreicht eine Handelsbilanz von mindestens +{0} Talern: Eure Verkäufe müssen Eure Einkäufe übersteigen.' -f $tb) ('Reach a trade balance of at least +{0} talers: your sales must exceed your purchases.' -f $tb)
}
function Get-AdvBalanceBullet([int]$balance) {
    if ($balance -eq 0) { New-AdvText 'Haltet die Bilanz Eurer Kolonie im Plus.' 'Keep the balance of your colony in the black.' } else { New-AdvText ('Eine Bilanz von mindestens +{0} Talern.' -f $balance) ('A balance of at least +{0} talers.' -f $balance) }
}
# Monopoly of one crop ($Crops entry).
function Get-AdvMonopolyBullet($c) {
    New-AdvText ('Sichert Euch {0}: eine eigene Siedlung auf JEDER Insel, auf der {1}, und keine fremde dort.' -f $c.deMono, $c.deGrow) ('Secure {0}: a settlement of your own on EVERY island where {1}, and no foreign one there.' -f $c.enMono, $c.enGrow)
}
# Defeat: no house names = all three rivals, otherwise the one or two houses (their flagships carry the house name).
function Get-AdvDefeatBullet($houses) {
    $hn = @($houses)
    $defeatedDe = 'Ein Rivale gilt als besiegt, wenn er keine Siedlung und kein Schiff mehr besitzt.'; $defeatedEn = 'A rival counts as defeated when he owns no settlement and no ship any more.'
    if ($hn.Count -eq 0) { New-AdvText "Besiegt alle drei Rivalen. $defeatedDe" "Defeat all three rivals. $defeatedEn" }
    elseif ($hn.Count -eq 1) { New-AdvText ('Besiegt das Haus {0} - Ihr erkennt es an seinem Flaggschiff, der "{0}". {1}' -f $hn[0], $defeatedDe) ('Defeat House {0} - you will know it by its flagship, the "{0}". {1}' -f $hn[0], $defeatedEn) }
    else { New-AdvText ('Besiegt die Häuser {0} und {1} (Flaggschiffe "{0}" und "{1}"). {2}' -f $hn[0], $hn[1], $defeatedDe) ('Defeat the houses of {0} and {1} (flagships "{0}" and "{1}"). {2}' -f $hn[0], $hn[1], $defeatedEn) }
}
# Note below the orders when only some rivals must be defeated (1 or 2 targets), otherwise $null.
function Get-AdvDefeatNote([int]$targets) {
    if ($targets -eq 2) { New-AdvText 'Den dritten Rivalen müsst Ihr nicht besiegen.' 'You do not have to defeat the third rival.' }
    elseif ($targets -eq 1) { New-AdvText 'Die beiden anderen Rivalen müsst Ihr nicht besiegen.' 'You do not have to defeat the other two rivals.' }
}

# Story paragraph: opening (with the place), motive, twists.
function Get-AdvStory([string]$lang, $opening, [string]$place, $motive, $twists) {
    (@(($opening[$lang] -f $place), $motive[$lang]) + @($twists | ForEach-Object { $_[$lang] })) -join ' '
}
# Mission text as the game shows it: title line, difficulty, story, orders (bullets), an optional note,
# the helmsman's advice and the closing line. Lines end with LF only.
function Format-AdvText([string]$lang, [string]$title, [int]$level, [string]$story, $bullets, $note, $advice, $closing) {
    $lines = @($title, ($(if ($lang -eq 'de') { 'Schwierigkeit: ' } else { 'Difficulty: ' }) + $LevelText[$level][$lang]))
    if ($story) { $lines += '', $story }
    $lines += '', $(if ($lang -eq 'de') { 'Euer Auftrag:' } else { 'Your orders:' })
    $lines += @($bullets | ForEach-Object { '- ' + $_[$lang] })
    if ($note) { $lines += '', $note[$lang] }
    $lines += '', (($(if ($lang -eq 'de') { 'Rat des Steuermanns: ' } else { "The helmsman's advice: " })) + (@($advice | ForEach-Object { $_[$lang] }) -join ' ')), '', $closing[$lang]
    ($lines -join "`n") + "`n"
}

# --- Map rules (same for the generator and the scenario designer) --------------------------------
# Template layout, mirroring and the island rules of the map kind. Archipelago: at most class med (50 x 52),
# because the computer rivals need such an island (with only lit/mit islands they drop out at the start).
function Set-AdvMap($sc, [string]$mapKind) {
    $sc.Layout = Get-AdvInt 3
    $mirror = Get-AdvPick @(@($true, $false), @($false, $true), @($true, $true))
    $sc.MirrorX = $mirror[0]; $sc.MirrorY = $mirror[1]
    switch ($mapKind) {
        'Classic' { $sc.Enlarge = 1 + (Get-AdvInt 4); $sc.BigIslandSize = Get-AdvPick @('Normal', 'Large', 'Huge') }
        'Archipelago' { $sc.MaxClass = 2; $sc.AddIslands = 26 + (Get-AdvInt 5); $sc.BigIslandSize = 'Normal' }
        'Continents' { $sc.Continents = @{ Lar = 4 + (Get-AdvInt 2); Big = 3 + (Get-AdvInt 2); Small = 2 + (Get-AdvInt 2) }; $sc.BigIslandSize = Get-AdvPick @('Large', 'Huge') }
    }
}
# Crops on enough islands for the goods of the mission (an existing amount stays).
function Add-AdvCropsForGoods($amounts, $goods) {
    foreach ($good in $goods) {
        switch ($good) {
            16 { if (-not $amounts.Contains('Spices')) { $amounts.Spices = 3 } }
            17 { if (-not $amounts.Contains('Cocoa')) { $amounts.Cocoa = 3 } }
            15 { if (-not $amounts.Contains('Tobacco')) { $amounts.Tobacco = 3 } }
            18 { if (-not $amounts.Contains('Sugar')) { $amounts.Sugar = 3 }; if (-not $amounts.Contains('Wine')) { $amounts.Wine = 3 } }
        }
    }
}
# Islands of class med (50 x 52) or bigger in the small map and in the big version of a built scenario file;
# the computer rivals need at least 4 (the same rule as tests\check-scenarios.ps1).
function Get-AdvRivalIslandCounts([string]$path) {
    $s = (Get-Section (Read-Scenario $path) 'SZENE').Data
    foreach ($o0 in @(0) + $(if ($s.Length -ge 2360 -and [Text.Encoding]::ASCII.GetString($s, 0x494, 4) -eq 'GROS') { @(0x4A4) } else { @() })) {
        $n = [BitConverter]::ToInt32($s, $o0 + 0x64); $k = 0
        for ($i = 0; $i -lt $n; $i++) { if ($s[$o0 + 0x174 + 16 * $i + 1] -ge 2) { $k++ } }
        $k
    }
}

# --- One adventure (a failed build, e.g. no free starting point, retries with the next attempt) -----
function New-Adventure([int]$attempt) {
    Reset-AdvRandom $attempt $AdvSeed
    $lv = $AdvLevel
    $mission = @{}; $bullets = New-Object System.Collections.Generic.List[object]; $hints = New-Object System.Collections.Generic.List[object]
    $amounts = [ordered]@{}; $bigAmounts = [ordered]@{}; $fleet = New-Object System.Collections.Generic.List[object]; $rivals = @()
    $goodsUsed = New-Object System.Collections.Generic.List[int]; $towns = New-Object System.Collections.Generic.List[object]

    # Main goal and map kind.
    $primary = Get-AdvWeighted @(@('Towns', (@(40, 30, 25, 25)[$lv])), @('Realm', (@(25, 20, 20, 15)[$lv])), @('Trade', (@(20, 20, 20, 20)[$lv])), @('Monopoly', (@(15, 15, 15, 15)[$lv])), @('Conquest', (@(0, 15, 20, 25)[$lv])))
    $mapKind = switch ($primary) {
        'Towns' { Get-AdvWeighted @(@('Classic', 65), @('Continents', 35)) }   # archipelago islands (max. 50 x 52) are too small for a big town
        'Realm' { Get-AdvWeighted @(@('Classic', 50), @('Archipelago', 50)) }
        'Trade' { Get-AdvWeighted @(@('Classic', 70), @('Continents', 30)) }
        'Monopoly' { Get-AdvWeighted @(@('Classic', 60), @('Archipelago', 25), @('Continents', 15)) }
        'Conquest' { Get-AdvWeighted @(@('Classic', 70), @('Continents', 30)) }
    }
    $sc = @{ Number = 0; GameId = 0x53000000 + ($lv -shl 20) + $AdvSeed; Difficulty = $lv }
    Set-AdvMap $sc $mapKind
    $sc.BigVillages = 4 + (Get-AdvInt 3)
    $sc.VillagesNorth = 1 + (Get-AdvInt 4); $sc.VillagesSouth = 1 + (Get-AdvInt 4)
    $amounts.OreSmall = 4 + (Get-AdvInt 3); $amounts.OreLarge = 7 + (Get-AdvInt 4); $amounts.Gold = 2 + (Get-AdvInt 2); $amounts.Treasure = 4 + (Get-AdvInt 9)
    $sc.Gold = @(45000, 35000, 30000, 25000)[$lv] + ((Get-AdvInt 5) - 2) * 2500
    $sc.RivalGold = @(15000, 25000, 35000, 45000)[$lv] + ((Get-AdvInt 5) - 2) * 2500
    $sc.AI = switch ($lv) { 0 { Get-AdvInt 2 } 1 { 1 + (Get-AdvInt 2) } 2 { 2 + (Get-AdvInt 2) } 3 { 3 } }
    $sc.Pirates = Test-AdvChance (@(0, 35, 70, 100)[$lv])

    # Helpers that add one goal each (mission keys + bullet text in both languages).
    $addTown = {
        param($g)
        $towns.Add($g); $mission.Towns = $towns.ToArray()
        $bullets.Add((Get-AdvTownBullet $g $towns.Count))
    }
    $addGoods = {
        param([int]$good, [int]$tons)
        $goodsUsed.Add($good); $mission["Goods$($goodsUsed.Count)"] = @{ Good = $good; Tons = $tons }
        if ($good -in 12, 13) { $script:advNeedOre = $true }
        if ($good -in 3, 21) { $script:advNeedGold = $true }
    }
    $goodsBullet = { if ($goodsUsed.Count -in 1, 2) { $bullets.Add((Get-AdvGoodsBullet @(1..$goodsUsed.Count | ForEach-Object { $mission["Goods$_"] }))) } }
    $script:advNeedOre = $false; $script:advNeedGold = $false
    $tierB = @(18, 15, 16, 17)
    $noMines = ($mapKind -eq 'Archipelago')   # small islands: ore and gold mountains are not certain

    # --- Main goal -------------------------------------------------------------------------------
    $motive = $null; $mainHint = $null; $monoCrops = @(); $targets = @()
    switch ($primary) {
        'Towns' {
            $t1 = switch ($lv) {
                0 { $r = Get-AdvPick @(250, 300, 350, 400); @{ Residents = $r; Stage = 1; OfWhich = $r / 2 } }
                1 { Get-AdvPick @(@{ Residents = 500; Stage = 2; OfWhich = 250 }, @{ Residents = 600; Stage = 2; OfWhich = 300 }, @{ Residents = 700; Stage = 2; OfWhich = 350 }, @{ Residents = 800; Stage = 2; OfWhich = 350 }) }
                2 { Get-AdvPick @(@{ Residents = 800; Stage = 3; OfWhich = 300 }, @{ Residents = 900; Stage = 3; OfWhich = 350 }, @{ Residents = 1000; Stage = 3; OfWhich = 400 }, @{ Residents = 1200; Stage = 3; OfWhich = 500 }) }
                3 { Get-AdvPick @(@{ Residents = 1500; Stage = 4; OfWhich = 500 }, @{ Residents = 1500; Stage = 4; OfWhich = 600 }, @{ Residents = 2000; Stage = 4; OfWhich = 800 }, @{ Residents = 2500; Stage = 4; OfWhich = 1000 }) }
            }
            & $addTown $t1
            $second = switch ($lv) { 0 { $false } 1 { Test-AdvChance 50 } 2 { Test-AdvChance 70 } 3 { $true } }
            if ($second) {
                $t2 = switch ($lv) {
                    1 { Get-AdvPick @(@{ Residents = 250; Stage = 1; OfWhich = 120 }, @{ Residents = 300; Stage = 1; OfWhich = 150 }) }
                    2 { Get-AdvPick @(@{ Residents = 400; Stage = 2; OfWhich = 200 }, @{ Residents = 500; Stage = 2; OfWhich = 250 }, @{ Residents = 600; Stage = 2; OfWhich = 300 }) }
                    3 { Get-AdvPick @(@{ Residents = 800; Stage = 3; OfWhich = 300 }, @{ Residents = 1000; Stage = 3; OfWhich = 400 }, @{ Residents = 1200; Stage = 3; OfWhich = 500 }) }
                }
                & $addTown $t2
                if ($lv -eq 3 -and (Test-AdvChance 40)) { & $addTown (Get-AdvPick @(@{ Residents = 500; Stage = 2; OfWhich = 250 }, @{ Residents = 600; Stage = 2; OfWhich = 300 })) }
            }
            $motive = Get-AdvPick $AdvMotives.Towns
            $mainHint = Get-AdvPick $AdvMainHints.Towns
        }
        'Realm' {
            $allTowns = ($lv -ge 2 -and (Test-AdvChance 50))
            if ($allTowns) {
                $n = if ($lv -eq 2) { 5 } else { 6 }
                $g = if ($lv -eq 2) { @{ Residents = 150; Stage = 1; OfWhich = 60 } } else { @{ Residents = 250; Stage = 2; OfWhich = 80 } }
                $mission.TownCount = $n; $mission.AllTowns = $g
                $bullets.Add((Get-AdvTownCountBullet $n $false))
                $bullets.Add((Get-AdvAllTownsBullet $g))
            }
            else {
                $n = switch ($lv) { 0 { 3 } 1 { Get-AdvPick @(4, 5) } 2 { 6 } 3 { 8 } }
                $total = switch ($lv) { 0 { Get-AdvPick @(600, 700, 800) } 1 { Get-AdvPick @(1200, 1400, 1600) } 2 { Get-AdvPick @(2000, 2500) } 3 { Get-AdvPick @(3000, 3500) } }
                $mission.TownCount = $n; $mission.TotalResidents = $total
                $bullets.Add((Get-AdvTownCountBullet $n $true))
                $bullets.Add((Get-AdvTotalBullet $total))
            }
            if ($lv -le 1) { $fleet.Add(@{ Type = 21; Name = $null; Cargo = @(@{ Good = 'Tools'; Tons = 30 }, @{ Good = 'Wood'; Tons = 40 }) }) }
            $sc.Gold += 5000
            $motive = Get-AdvPick $AdvMotives.Realm
            $mainHint = $AdvMainHints.Realm[0]
        }
        'Trade' {
            switch ($lv) {
                0 { & $addGoods 24 30; & $addGoods 19 30; $tb = 100 }
                1 { $pair = Get-AdvShuffled $tierB; & $addGoods $pair[0] 40; & $addGoods $pair[1] 40; $tb = 200 }
                2 {
                    $c = Get-AdvPick @(@(20, 50), @(13, 20), @(12, 40)); & $addGoods $c[0] $c[1]
                    & $addGoods (Get-AdvPick $tierB) 40; $tb = 300
                }
                3 { & $addGoods 21 50; $c = Get-AdvPick @(@(20, 80), @(3, 60)); & $addGoods $c[0] $c[1]; $tb = Get-AdvPick @(300, 400) }
            }
            & $goodsBullet
            $mission.TradeBalance = $tb
            $bullets.Add((Get-AdvTradeBalanceBullet $tb))
            if ($lv -le 1) { $fleet.Add(@{ Type = 23; Name = $null; Cargo = @(@{ Good = 'Tools'; Tons = 30 }, @{ Good = 'Wood'; Tons = 30 }) }) }
            $motive = Get-AdvPick $AdvMotives.Trade
            $mainHint = $AdvMainHints.Trade[0]
        }
        'Monopoly' {
            $count = if ($lv -ge 2) { 2 } else { 1 }
            $monoCrops = @((Get-AdvShuffled $Crops)[0..($count - 1)])
            for ($k = 0; $k -lt $count; $k++) {
                $c = $monoCrops[$k]
                $mission["Monopoly$($k + 1)"] = @{ Resource = $c.Res; Islands = 1 }
                $amounts[$c.Plant] = $(if ($lv -eq 2) { 1 } else { 2 }); $bigAmounts[$c.Plant] = $amounts[$c.Plant] + 1
                $bullets.Add((Get-AdvMonopolyBullet $c))
            }
            $t = switch ($lv) { 0 { @{ Residents = 300; Stage = 1; OfWhich = 150 } } 1 { @{ Residents = 500; Stage = 2; OfWhich = 250 } } 2 { @{ Residents = 600; Stage = 2; OfWhich = 300 } } 3 { @{ Residents = 1000; Stage = 3; OfWhich = 400 } } }
            & $addTown $t
            $motive = Get-AdvMonopolyMotive $monoCrops
            $mainHint = $AdvMainHints.Monopoly[0]
        }
        'Conquest' {
            $script:advNeedOre = $true
            $names = Get-AdvShuffled $Houses
            $mode = switch ($lv) { 1 { 'OneWeak' } 2 { Get-AdvPick @('Two', 'OneStrong') } 3 { 'All' } }
            switch ($mode) {
                'OneWeak' { $targets = @(1 + (Get-AdvInt 3)) }
                'OneStrong' { $targets = @(1 + (Get-AdvInt 3)) }
                'Two' { $targets = @((Get-AdvShuffled @(1, 2, 3))[0..1] | Sort-Object) }
                'All' { $targets = @(1, 2, 3) }
            }
            $mission.Defeat = $targets
            if ($mode -eq 'All') {
                $bullets.Add((Get-AdvDefeatBullet @()))
                $motive = Get-AdvConquestMotive @()
                $fleet.Add(@{ Type = 27; Name = $null }); $fleet.Add(@{ Type = 25; Name = $null })
                $sc.Gold += 15000
            }
            else {
                $hn = @(); for ($k = 0; $k -lt $targets.Count; $k++) {
                    $h = $names[$k]; $hn += $h
                    $rv = @{ Player = $targets[$k]; Name = @{ de = "Haus $h"; en = "House $h" }; Ship = $h }
                    if ($mode -eq 'OneWeak') { $rv.Gold = 10000 } elseif ($mode -eq 'OneStrong') { $rv.Gold = 60000 }
                    $rivals += $rv
                }
                $bullets.Add((Get-AdvDefeatBullet $hn))
                $motive = Get-AdvConquestMotive $hn
                $fleet.Add(@{ Type = $(if ($lv -ge 2) { 27 } else { 25 }); Name = $null })
                $sc.Gold += 10000
                if ($lv -eq 1) { $sc.Pirates = $false }
            }
            switch ($mode) {
                'OneWeak' { & $addTown @{ Residents = 400; Stage = 1; OfWhich = 200 } }
                'OneStrong' { & $addTown @{ Residents = 800; Stage = 3; OfWhich = 300 } }
            }
            $mainHint = $AdvMainHints.Conquest[0]
        }
    }

    # --- Add-ons ---------------------------------------------------------------------------------
    $addOns = switch ($lv) { 0 { 0 } 1 { 1 } 2 { 1 + (Get-AdvInt 2) } 3 { 2 } }
    if ($primary -eq 'Conquest' -or ($primary -eq 'Monopoly' -and $lv -ge 2)) { $addOns = [math]::Max(0, $addOns - 1) }
    $candidates = @('Balance')
    if ($primary -ne 'Conquest' -and $primary -ne 'Trade') { $candidates += 'TradeBalance' }
    if ($primary -ne 'Trade' -and $goodsUsed.Count -eq 0) { $candidates += 'Goods' }
    if ($primary -eq 'Towns' -and $towns.Count -ge 2 -and $lv -ge 2) { $candidates += 'TotalResidents' }
    if ($towns.Count -eq 0) { $candidates += 'Town' }
    $chosen = @((Get-AdvShuffled $candidates) | Select-Object -First $addOns)
    $balance = $null
    foreach ($c in $chosen) {
        switch ($c) {
            'Balance' { $balance = switch ($lv) { 0 { 0 } 1 { Get-AdvPick @(100, 200, 300) } 2 { Get-AdvPick @(300, 400, 500) } 3 { Get-AdvPick @(500, 750, 1000) } } }
            'TradeBalance' {
                $tb = switch ($lv) { 0 { 100 } 1 { Get-AdvPick @(150, 200, 250) } 2 { Get-AdvPick @(250, 300, 350) } 3 { Get-AdvPick @(300, 400, 500) } }
                $mission.TradeBalance = $tb
                $bullets.Add((Get-AdvTradeBalanceBullet $tb))
            }
            'Goods' {
                $g = if ($primary -eq 'Conquest') { Get-AdvPick @(@(13, 20), @(12, 30)) }
                elseif ($primary -eq 'Monopoly') { @(@{ 0x2F = 16; 0x2E = 15; 0x33 = 17; 0x30 = 18; 0x32 = 18 }[$monoCrops[0].Res], (Get-AdvPick @(30, 40))) }
                elseif ($lv -eq 0) { Get-AdvPick @(@(24, 30), @(19, 30)) }
                elseif ($lv -eq 1 -or $noMines) { @((Get-AdvPick $tierB), (Get-AdvPick @(30, 40))) }
                elseif ($lv -eq 2) { Get-AdvPick @(@(20, 40), @(13, 20), @(12, 30)) }
                else { Get-AdvPick @(@(21, 40), @(3, 50)) }
                if ($noMines -and $g[0] -in 3, 12, 13, 21) { $g = @(16, 40) }
                & $addGoods $g[0] $g[1]; & $goodsBullet
            }
            'TotalResidents' {
                $sum = 0; foreach ($t in $towns) { $sum += $t.Residents }
                $total = $sum + $(if ($lv -eq 2) { Get-AdvPick @(400, 500, 600) } else { Get-AdvPick @(600, 800, 1000) })
                $mission.TotalResidents = $total
                $bullets.Add((Get-AdvTotalBullet $total))
            }
            'Town' {
                & $addTown $(switch ($lv) { 0 { @{ Residents = 200; Stage = 1; OfWhich = 100 } } 1 { @{ Residents = 300; Stage = 1; OfWhich = 150 } } 2 { @{ Residents = 500; Stage = 2; OfWhich = 250 } } 3 { @{ Residents = 800; Stage = 3; OfWhich = 300 } } })
            }
        }
    }
    if ($null -eq $balance -and $lv -eq 0 -and ($primary -in @('Towns', 'Monopoly')) -and (Test-AdvChance 50)) { $balance = 0 }
    if ($null -ne $balance) {
        $mission.Balance = $balance
        $bullets.Add((Get-AdvBalanceBullet $balance))
    }

    # --- World to match the mission ----------------------------------------------------------------
    if ($script:advNeedOre) { $amounts.OreSmall = [math]::Max($amounts.OreSmall, 6); $amounts.OreLarge = [math]::Max($amounts.OreLarge, 9) }
    if ($script:advNeedGold) { $amounts.Gold = [math]::Max($amounts.Gold, 3) }
    Add-AdvCropsForGoods $amounts $goodsUsed
    # Start cargo: rich on Easy (unless a goal good would be fulfilled by unloading it), lean on some Hard maps.
    $cargoNote = $null
    if ($lv -eq 0) {
        $sc.Cargo = @(@{ Good = 'Tools'; Tons = 50 }, @{ Good = 'Wood'; Tons = 50 }, @{ Good = $(if ($goodsUsed -contains 24) { 'Food' } else { 'Bricks' }); Tons = 20 }, @{ Good = 'Food'; Tons = 20 })
        if ($goodsUsed -contains 24) { $sc.Cargo = @($sc.Cargo[0], $sc.Cargo[1], @{ Good = 'Food'; Tons = 30 }) }
        $cargoNote = $AdvTwists.RichCargo
    }
    elseif ($lv -eq 3 -and (Test-AdvChance 50)) {
        $sc.Cargo = @(@{ Good = 'Tools'; Tons = 30 }, @{ Good = 'Wood'; Tons = 20 }, @{ Good = 'Food'; Tons = 10 })
        $cargoNote = $AdvTwists.LeanCargo
        $hints.Add($AdvHints.Tools)
    }
    $hasWarship = @($fleet | Where-Object { $_.Type -ge 25 }).Count -gt 0
    if ($sc.Pirates -and -not $hasWarship -and $lv -ge 2 -and (Test-AdvChance 50)) { $fleet.Add(@{ Type = 25; Name = $null }); $hasWarship = $true }
    # Names for the extra ships (distinct, from the lists).
    $tn = Get-AdvShuffled $TraderNames; $wn = Get-AdvShuffled $WarshipNames; $ti = 0; $wi = 0
    foreach ($s in $fleet) { if ($s.Type -ge 25) { $s.Name = $wn[$wi]; $wi++ } else { $s.Name = $tn[$ti]; $ti++ } }

    # --- Text --------------------------------------------------------------------------------------
    $place = Get-AdvPick $Places
    $opening = Get-AdvPick $AdvOpenings[$mapKind]
    $twists = New-Object System.Collections.Generic.List[object]
    if ($sc.Pirates) { $twists.Add($AdvTwists.Pirates) }
    $extra = @()
    if ($sc.AI -ge 3) { $extra += , $AdvTwists.StrongRivals }
    elseif ($sc.AI -eq 0) { $extra += , $AdvTwists.WeakRivals }
    if ($sc.VillagesNorth + $sc.VillagesSouth -ge 6) { $extra += , $AdvTwists.Natives }
    if ($cargoNote) { $extra += , $cargoNote }
    foreach ($e in @((Get-AdvShuffled $extra) | Select-Object -First 2)) { $twists.Add($e) }
    if ($fleet.Count) { $twists.Add((Get-AdvFleetTwist @($fleet | ForEach-Object { $_.Name }))) }
    if ($sc.Pirates) { $hints.Add($AdvHints.Pirates) }
    if ($goodsUsed | Where-Object { $_ -in 12, 13 }) { $hints.Add($AdvHints.Ore) }
    elseif ($goodsUsed | Where-Object { $_ -in 3, 21 }) { $hints.Add($AdvHints.Gold) }
    $closing = Get-AdvPick $AdvClosings

    $advice = @($mainHint) + @($hints | Select-Object -First 2)
    $text = @{}
    foreach ($lang in 'de', 'en') {
        $title = if ($AdvDay) {
            if ($lang -eq 'de') { 'TAGESABENTEUER {0}: Die Inseln von {1}' -f $AdvDay.ToString('dd.MM.yyyy', [Globalization.CultureInfo]::InvariantCulture), $place }
            else { 'DAILY ADVENTURE {0}: The Isles of {1}' -f $AdvDay.ToString('d MMMM yyyy', [Globalization.CultureInfo]::InvariantCulture), $place }
        }
        else { $(if ($lang -eq 'de') { 'ABENTEUER {0}: Die Inseln von {1}' } else { 'ADVENTURE {0}: The Isles of {1}' }) -f $AdvSeed, $place }
        $story = Get-AdvStory $lang $opening $place $motive $twists
        $text[$lang] = Format-AdvText $lang $title $lv $story $bullets (Get-AdvDefeatNote $(if ($mission.Defeat) { @($targets).Count } else { 0 })) $advice $closing
    }

    # The difficulty is part of the name, so the same number with another difficulty is a scenario of its own.
    # The daily adventure is called after its day (its difficulty is in the game id only).
    $sc.Title = if ($AdvDay) { $iso = $AdvDay.ToString('yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture); @{ de = "Tagesabenteuer $iso"; en = "Daily Adventure $iso" } }
    else { @{ de = "Abenteuer $AdvSeed $($LevelText[$lv].de)"; en = "Adventure $AdvSeed $($LevelText[$lv].en)" } }
    $sc.Text = $text
    $sc.Mission = $mission
    $sc.Amounts = $amounts
    if ($bigAmounts.Count) { $sc.BigAmounts = $bigAmounts }
    if ($fleet.Count) { $sc.Fleet = $fleet.ToArray() }
    if ($rivals.Count) { $sc.Rivals = $rivals }
    @{ Scenario = $sc; Primary = $primary; MapKind = $mapKind; Bullets = $bullets }
}

if ($AdvLibraryOnly) { return }

if ($AdvDay) { $AdvSeed = Get-DailySeed $AdvDay }
elseif ($AdvSeed -lt 0) { $AdvSeed = Get-Random -Minimum 1 -Maximum 1000000 }
$result = $null
for ($attempt = 0; $attempt -lt 5 -and -not $result; $attempt++) {
    $adv = New-Adventure $attempt
    try { $result = Build-Scenario $adv.Scenario }
    catch { if ($attempt -ge 4) { throw }; Write-Verbose "Attempt $attempt failed: $($_.Exception.Message)" }
}
'{0}: {1}' -f (Get-Localized $adv.Scenario.Title), $result.Path
'  {0}, main goal {1}: {2}' -f $adv.MapKind, $adv.Primary, $result.Summary
if ($AdvDay) { '  daily adventure of {0:yyyy-MM-dd}: seed {1}, difficulty {2}' -f $AdvDay, $AdvSeed, $AdvLevelName }
foreach ($b in $adv.Bullets) { '  - ' + $b[$Language] }
if ($AdvInstall) {
    $own = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'Anno 1602 History Edition\Own Scenarios'
    New-Item -ItemType Directory -Force -Path $own | Out-Null
    Copy-Item -LiteralPath $result.Path -Destination $own -Force
    "Installed to: $own"
}
