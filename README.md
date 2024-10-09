# Pretty Proto
Pretty Proto soll auf möglich einfache Art und Weise ein schönes Protokoll für die Fachschaftssitzungen der Fachschaft Informatik generieren. Es basiert stark auf dem [Sharelatex Downloader](https://gitlab.inf.uni-konstanz.de/dominik.fidas/sharelatex-downloader), der bisher benutzt wurde.

## Prerequisites
- [Pandoc](https://pandoc.org/), um Markdown in eine PDF zu konvertieren
- [XeLaTeX](https://www.overleaf.com/learn/latex/XeLaTeX), um das PDF zu kompilieren
- [Ubuntu Font](https://design.ubuntu.com/font/), weil Anton sich dafür als Standardfont entschieden hat

## Usage
Im Folgenden werden drei Varianten präsentiert, wie man das Skript benutzen kann. Allgemein stehen einem noch folgende Flaggen zur Verfügung:

`-s, --show` ruft gleich nach der Kompilierung des Protokolls den PDF Viewer des Systems auf, um die Protokolldatei anzuzeigen  
`-c, --chair` definiert den Namen der Sitzungsleitung, sodass die entsprechende Datei aus dem `sigs` Ordner in das Unterschrifsfeld eingefügt wird  
`-t, --transcript` definiert den Namen der protokollierenden Person, sodass die entsprechende Datei aus dem `sigs` Ordner in das Unterschriftsfeld eingefügt wird

Und wie immer auch

`-h, --help`, um eine Kurzhilfe anzuzeigen

Insgesamt lassen sich Optionen, die kein Argument nehmen auch zusammenfassen:
```sh
pretty-proto -dks
# ist das selbe wie
pretty-proto -d -k -s
```

### Downloader
Es gibt in Pretty Proto zwei Quellen von denen Markdown-Dateien heruntergeladen werden können, um direkt kompiliert zu werden: Sharelatex und HedgeDoc.

Allgemein gibt es dabei die Möglichkeit die Markdown-Datei abzuspeicher (standardmäßig wird sie nur temporär gespeichert und nach Beendigung des Skripts gelöscht):

    `-k, --keep` signalisert dem Skript, dass es die heruntergeladene Markdown-Datei speichern soll  

#### Sharelatex
Wie auch bei der vorherigen Version des Protokoll Skripts, lässt sich das Protokoll direkt von Sharelatex herunterladen und kompilieren:

```pretty-proto -d -p <password>```

`-S, --sharelatex` signalisiert dem Skript, dass er das Protokoll von Sharelatex herunterladen soll.  
`-p, --password` setzt das Passwort, das zu verwenden ist.  

Ansonsten lassen sich die Standardwerte des Skripts benutzen. Falls man trotzdem alles definieren möchte gibt es noch folgende Flags:

`-D, --domain` setzt die Domain des Sharelatex Servers (*default*: `https://sharelatex.physik.uni-konstanz.de`)  
`-P, --project` setzt die ProjectID des Sharelatex Projektes in dem sich das Protokoll befindet  
`-f, --filename` setzt den Namen der Protokolldatei im Sharelatex Projekt (*default*: `protokoll.tex`)  
`-e, --email` setzt die Email mit der man sich auf dem Sharelatex Server anmelden möchte (*default*: `fachschaft.informatik@uni-konstanz.de`)  

#### HedgeDoc Downloader
Neu dazu gekommen ist die Möglichkeit, Markdown-Dateien von HedgeDoc herunterzuladen und zu kompilieren:

```pretty-proto -H -I <id>```

`-H, --hedgedoc` signalisiert dem Skript, dass es das Protokoll von HedgeDoc herunterladen soll.  
`-I, --id` setzt die ID des HedgeDoc Dokuments, das heruntergeladen werden soll.

Ansonsten lässt sich auch hier zumindest ein Standardwert umdefinieren:

`-D, --domain` setzt die Domain der HedgeDoc Instanz (*default*: `https://md.cityofdogs.dev`)

### Markdown File
Falls das Protokoll bereits lokal als Markdown-Datei existiert, lässt sich das Skript wie folgt benutzen:

```pretty-proto protokoll.md```

### stdin
Aus Spaß habe ich auch die Möglichkeit eingebaut, dass man den Markdown-Code in das Skript reinpipet. Ich weiß nicht welchen Nutzen das haben könnte, aber es ist da:

```cat protokoll.md | pretty-proto```

### Pretty Config
Um kontextsensitiv die Standardwerte des Skripts zu ändern, gibt es die Möglichkeit eine `pretty.conf` Datei im selben Verzeichnis wie die Ausführung des Skripts zu erstellen. Diese Datei wird nach dem Start des Skripts über `source` eingelesen und überschreibt somit die Standardwerte von pretty-proto. Im folgenden die (möglicherweise veralteten) Standardwerte:
```sh
# Set default values
sigdir="$scriptpath/sigs"               # The directory containing the signatures
sigline="$scriptpath/tex/sigline.latex" # The signature line to add to the protocol
font="Ubuntu"                           # The font to use for the protocol
logo="$scriptpath/tex/logo.png"         # The logo to use for the protocol
tocTitle="Tagesordnung"                 # The title of the table of contents
tocSubtitle=""                          # The subtitle of the table of contents
show=false                              # Show the compiled pdf
intro=""                                # The introduction to the protocol
outro=""                                # The outro to the protocol

## DOWNLOAD
download=false
keep=false
domain=

## for sharelatex download
sharelatex=false
sl_domain="https://sharelatex.physik.uni-konstanz.de"
email="fachschaft.informatik@uni-konstanz.de"
password=""
project="5a058e9d1731df007b5aa1fd"
filename="protokoll.tex"
zip="$tmpdir/protocol.zip"
cookie="$tmpdir/cookies.txt"

## for hedgedoc download
hedgedoc=false
hd_domain="https://md.cityofdogs.dev"
id=
```
