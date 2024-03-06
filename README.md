# Pretty Proto
Pretty Proto soll auf möglich einfache Art und Weise ein schönes Protokoll für die Fachschaftssitzungen der Fachschaft Informatik generieren. Es basiert stark auf dem [Sharelatex Downloader](https://gitlab.inf.uni-konstanz.de/dominik.fidas/sharelatex-downloader), der bisher benutzt wurde.

## Usage
Im Folgenden werden drei Varianten präsentiert, wie man das Skript benutzen kann. Allgemein stehen einem noch folgende Flaggen zur Verfügung:

`-s, --show` ruft gleich nach der Kompilierung des Protokolls den PDF Viewer des Systems auf, um die Protokolldatei anzuzeigen  
`-c, --chair-signature` definiert den Namen der Sitzungsleitung, sodass die entsprechende Datei aus dem `sigs` Ordner in das Unterschrifsfeld eingefügt wird  
`-p, --protocol-signature` definiert den Namen der protokollierenden Person, sodass die entsprechende Datei aus dem `sigs` Ordner in das Unterschriftsfeld eingefügt wird

Und wie immer auch

`-h, --help`, um eine Kurzhilfe anzuzeigen

### Sharelatex Downloader
Wie auch bei der vorherigen Version des Protokoll Skripts, lässt sich das Protokoll direkt von Sharelatex herunterladen und kompilieren:

```pretty-proto -d -p <password>```

`-d, --download` signalisiert dem Skript, dass er das Protokoll von Sharelatex herunterladen soll.  
`-p, --password` setzt das Passwort, das zu verwenden ist.  

Ansonsten lassen sich die Standardwerte des Skripts benutzen. Falls man trotzdem alles definieren möchte gibt es noch folgende Flags:
`-D, --domain` setzt die Domain des Sharelatex Servers (*default*: `https://sharelatex.physik.uni-konstanz.de`)  
`-P, --project` setzt die ProjectID des Sharelatex Projektes in dem sich das Protokoll befindet  
`-f, --filename` setzt den Namen der Protokolldatei im Sharelatex Projekt (*default*: `protokoll.tex`)  
`-e, --email` setzt die Email mit der man sich auf dem Sharelatex Server anmelden möchte (*default*: `fachschaft.informatik@uni-konstanz.de`)  

### Markdown File
Falls das Protokoll bereits lokal als Markdown-Datei existiert, lässt sich das Skript wie folgt benutzen:

```pretty-proto protokoll.md```

### stdin
Aus Spaß habe ich auch die Möglichkeit eingebaut, dass man den Markdown-Code in das Skript reinpipet. Ich weiß nicht welchen Nutzen das haben könnte, aber es ist da:

```cat protokoll.md | pretty-proto```
