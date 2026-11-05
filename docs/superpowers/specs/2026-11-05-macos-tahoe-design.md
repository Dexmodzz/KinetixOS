# Tema "macos-tahoe" - design

Data: 2026-11-05. Branch: `codex/macos-tahoe-theme`.

## Intento

Un tema KinetixOS che renda il desktop il piu' simile possibile a macOS 26
Tahoe: barra in alto traslucida con nome dell'app in grassetto, dock centrato
in basso con icone e puntini delle app aperte, finestre con angoli arrotondati
e ombre morbide, blur dietro barra e dock. Il tema si sceglie dal menu temi
esistente (Impostazioni > Aspetto) e si toglie scegliendo un altro tema, senza
lasciare tracce.

## Decisioni dell'utente

- La barra in alto e' il pannello **Quickshell** esistente, non la barra
  nativa di dwm (che resta disattivata come oggi).
- Anche il **dock e' in Quickshell**, non un programma C separato.
- Niente barre o dock esterni pronti (polybar, eww, plank, ...).
- Nessun pacchetto installato senza approvazione esplicita.
- Gli altri temi non vanno toccati se non strettamente necessario; backup di
  ogni file di configurazione utente modificato.

## Obiettivi

1. Nuovo tema `[theme.macos-tahoe]` + profilo `[style.tahoe]` in
   `config/themes.toml`, con la stessa forma degli altri temi.
2. Layout della barra "macos" in Quickshell, attivato da un token di stile.
3. Dock Quickshell attivato da un token di stile.
4. dwm riserva lo spazio del dock in basso senza confonderlo con la barra.
5. Picom: blur dual_kawase dietro barra e dock, angoli e ombre da stile.
6. GTK3/GTK4: base adw-gtk3 / libadwaita rifinita con CSS del tema.
7. Launcher in stile Spotlight e notifiche in stile macOS tramite token.

## Non-obiettivi

- Menu applicazione globale (File, Modifica, ...): in X11/dwm le app non
  esportano i menu in modo uniforme; la barra mostra solo il nome dell'app.
- Riprodurre asset Apple protetti (wallpaper ufficiali, icone Apple, font SF).
- Supporto Wayland.

## Anti-obiettivi (fallimento anche se "funziona")

- Un altro tema che cambia aspetto o comportamento dopo questa modifica.
- Quickshell che consuma CPU a riposo (timer, polling) per colpa del dock.
- Finestre tiled coperte dalla barra o dal dock.
- Pannello in alto che perde la riserva di spazio quando appare il dock.

## Specifica visiva (PROVVISORIA)

Lo screenshot di riferimento non e' ancora stato fornito. I valori qui sotto
vengono dall'aspetto standard di macOS 26 Tahoe e vanno confermati o corretti
appena arriva lo screenshot (Fase 2). Variante: scura (da confermare).

| Elemento | Valore |
|---|---|
| Barra: altezza | 30 px, a tutta larghezza, nessun margine |
| Barra: sfondo | `#1C1C1E` al 35% di opacita' + blur (Tahoe e' quasi trasparente) |
| Barra: testo | `#F5F5F7`; nome app peso 700, resto 500; 13-14 px |
| Barra sinistra | glifo logo, nome app attiva in grassetto, tag come puntini piccoli |
| Barra destra | rete, volume, batteria, centro di controllo, data "gio 5 nov 14:32" |
| Dock: forma | pillola centrata, raggio 22 px, margine inferiore 8 px |
| Dock: sfondo | `#2C2C2E` al 45% + blur + bordo interno `#FFFFFF` al 15% |
| Dock: icone | 48 px, spaziatura 8 px, ingrandimento fino a 72 px al passaggio |
| Dock: indicatore | puntino 4 px `#F5F5F7` sotto le app aperte |
| Finestre | raggio 12 px, bordo dwm 0, gap 10 px |
| Ombre | raggio 30, opacita' 40%, offset y 12 |
| Accento | `#0A84FF` (blu di sistema scuro) |
| Popup/launcher | raggio 16 px, sfondo `#1E1E20` al 80% + blur |
| Font | Inter se approvato, altrimenti Noto Sans (installato) |

## Come e' costruito

### 1. Tema e stile (`config/themes.toml`)

- `[theme.macos-tahoe]`: colori dwm, terminale, token `shell_*`, `dark_mode`,
  `gtk_theme = "adw-gtk3-dark"`, `style = "tahoe"`.
- `[style.tahoe]`: i token esistenti (raggi, gap, borderpx, bar_height, font,
  ombre) piu' i nuovi token sotto.
- La copia utente `~/.config/kinetixos/themes.toml` riceve il tema tramite
  `dwm-settings-theme merge-shipped`, dopo un backup.

### 2. Nuovi token di stile

Aggiunti a `style_schema` in `scripts/dwm-settings-appearance` e a
`Theme.applyStyle()`. Il default di ognuno riproduce l'aspetto attuale, quindi
gli altri temi non cambiano.

| Token | Tipo | Default | tahoe |
|---|---|---|---|
| `bar_layout` | enum `default`/`macos` | `default` | `macos` |
| `bar_opacity` | int 0-100 | 100 | 35 |
| `dock` | bool | false | true |
| `dock_icon_size` | int 24-96 | 48 | 48 |
| `dock_magnify` | int 100-200 (%) | 100 | 150 |
| `dock_radius` | int 0-64 | 0 | 22 |
| `dock_opacity` | int 0-100 | 100 | 45 |
| `dock_apps` | lista di desktop ID | vuota | Alacritty, thunar, com.brave.Origin, ... |
| `blur` | bool | false | true |

Nota: con `bar_layout = macos` il pulsante logo mostra il glifo Nerd Font
U+F179 (logo Apple, gia' installato con MesloLGS Nerd Font). E' un marchio:
va bene per uso personale; nel repo e' solo un carattere nel codice QML
del layout macos, non un asset aggiunto.

### 3. Barra (Quickshell `panel/`)

- `DwmPanel.qml` riceve una proprieta' `macLayout` (da `Theme.styleBarLayout`)
  e, solo quando e' vera, cambia cosa mostra: niente orologio centrale,
  niente `RunningAppsArea`, data/ora a destra, sfondo a tutta larghezza con
  `bar_opacity`. Con `default` ogni binding valuta come oggi. Riusa i
  componenti esistenti: `LogoButton` (apre il
  launcher/menu sessione come oggi), titolo da `DwmState`, `WorkspaceButton` in
  forma di puntino, `TrayArea`, i widget rete/volume/batteria esistenti e
  `ClockModel` (ha gia' `ddd d MMM` e `HH:mm`; serve la sola combinazione
  "gio 5 nov 14:32" in locale di sistema).
- Click sulle icone di destra: aprono gli stessi popup/centro di controllo di
  oggi.

### 4. Dock (nuovo modulo Quickshell `dock/`)

- `Dock.qml`: un solo `PanelWindow` sul monitor focalizzato (regola AGENTS.md:
  niente `Variants` per schermo), ancorato in basso, caricato solo se lo stile
  ha `dock = true` (il `Loader` lo distrugge quando si cambia tema).
- `exclusiveZone` = altezza del dock a riposo; la finestra e' alta quanto
  l'icona ingrandita, cosi' l'ingrandimento non sposta le finestre tiled.
- App preferite da `dock_apps`, risolte con `DesktopEntries` di Quickshell.
- App aperte: `DwmState.runningApps` (coppie `windowId`/`appClass`, gia'
  in streaming da `dwm-quickshell-state watch` e usate da
  `RunningAppsArea.qml`); il match finestra-app confronta `appClass` con
  `StartupWMClass` o con l'id del desktop file. App aperte non preferite
  compaiono dopo un separatore, come su macOS.
- Click: se l'app ha una finestra, `DwmState.focusWindow(windowId)`;
  altrimenti avvio tramite l'helper `dwm-quickshell-launcher`
  (`Commands.launcherHelperCommand`), lo stesso usato dal launcher.
- Nel layout `macos` la barra non mostra `RunningAppsArea` (lo fa il dock).
- Ingrandimento: animazione QML sulla distanza del mouse, attiva solo con il
  mouse sopra il dock; nessun timer a riposo.

### 5. dwm: spazio per il dock (C)

Oggi `isaltbar()`/`updatealtbar()` trattano QUALSIASI finestra dock larga come
la barra del monitor (una sola per monitor). Un dock in basso sostituirebbe il
pannello in alto. Modifica minima:

- `Monitor` guadagna `dockwin` e `dockh`.
- In `updatealtbar()` (e nella scansione in `scanaltbars`), una finestra dock
  nella meta' inferiore del monitor diventa `dockwin`; la meta' superiore resta
  `barwin` come oggi.
- `dockh` = valore bottom di `_NET_WM_STRUT_PARTIAL` (o `_NET_WM_STRUT`) se
  presente, altrimenti l'altezza della finestra.
- `updatebarpos()` sottrae `dockh` da `m->wh`; unmap/destroy azzerano
  `dockwin`/`dockh` e chiamano `arrange()`.
- Perche' strut e non un gap fisso: il dock dichiara da solo lo spazio, dwm
  non deve conoscere il tema, e senza dock (tutti gli altri temi) il codice
  non cambia niente.

### 6. Picom

- `picom_style_args`/`dwm-settings-picom apply-theme-style` estesi con un
  argomento opzionale per il blur: se lo stile ha `blur = true`, il blocco
  marcato del tema aggiunge `blur-method = "dual_kawase"`, `blur-strength`,
  `blur-background = true` limitato alla classe Quickshell, e una regola che
  disattiva il blur sulle normali finestre. Senza blur il blocco e' identico a
  oggi. Picom 13 col backend glx (gia' in uso) supporta dual_kawase.

### 7. GTK

- GTK3: `adw-gtk3-dark` (gia' installato, il piu' vicino a Tahoe tra quelli
  presenti).
- GTK4/libadwaita: `~/.config/gtk-4.0/gtk.css` con accento `#0A84FF` e raggi;
  GTK3 `~/.config/gtk-3.0/gtk.css` equivalente. Scritti da `theme-apply.sh`
  dentro un blocco marcato, solo per temi con stile tahoe; gli altri temi
  rimuovono il blocco. Backup del file prima della prima scrittura.

### 8. Launcher e notifiche

- Launcher in stile Spotlight e notifiche in stile macOS ottenuti con i token
  (raggi, opacita', posizione), non con codice separato. dmenu, rofi e dunst
  non sono installati e non servono.

### 9. Wallpaper

- Un wallpaper originale (sfumatura blu/viola/arancio da tramonto sul lago)
  generato con ImageMagick (installato) e applicato tramite
  `dwm-settings-wallpaper`. Nessun wallpaper Apple.

## Pacchetti

Nessuno necessario. Proposte facoltative, solo se approvate:

- `rsms-inter-fonts`: Inter, il font libero piu' vicino a SF Pro.
- MacTahoe-gtk-theme / icone: piu' fedeli ma esterni a Fedora; da valutare.

## Verifica

- `scripts/run-tests make clean all` e `scripts/run-tests` (gate completo),
  senza warning.
- `scripts/quickshell-qmllint` sui file QML cambiati; shellcheck + shfmt.
- Test Xvfb: un dock in basso non sostituisce `barwin`; `wh` ridotto di
  `dockh`; rimuovendo il dock tutto torna come prima.
- Sessione reale: applicare il tema dal menu, screenshot con `maim`,
  confronto con lo screenshot di riferimento; ciclo correzioni.
- CPU di Quickshell a riposo con il dock visibile (campione con `ps`/`top`).
- Thunar (GTK3) e File Roller (GTK4/libadwaita) usano il tema.
- Passaggio a `moderno-morbido` e ritorno a `macos-tahoe`: barra, dock,
  picom, GTK tornano corretti.

## Lasciato a chi implementa

- Divisione in commit e PR (proposta: 1. dwm dock/strut, 2. token + barra +
  dock Quickshell, 3. tema, picom, GTK, wallpaper).
- Dettagli di layout QML entro la specifica visiva.

## Scelte mie (da controllare)

- Variante scura e i valori della tabella visiva, in attesa dello screenshot.
- Strut in dwm invece di un gap fisso in basso.
- Glifo Apple come valore di stile, non come asset.
- Wallpaper generato, non scaricato.
- Lavoro solo in locale sul branch: push e PR solo dopo il tuo ok.
