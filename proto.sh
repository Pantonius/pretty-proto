#!/bin/bash

scriptpath=$(dirname $(realpath $0))
scriptname=$0

# ensure dependencies are installed
## pandoc
if ! command -v pandoc &> /dev/null; then
    echo "pandoc could not be found. Please install pandoc."
    exit 1
fi

## xelatex
if ! command -v xelatex &> /dev/null; then
    echo "xelatex could not be found. Please install xelatex."
    exit 1
fi

## git
if ! command -v git &> /dev/null; then
    echo "git could not be found. Please install git."
    exit 1
fi

## jq
if ! command -v jq &> /dev/null; then
    echo "jq could not be found. Please install jq if you want the \pegel command to work"
fi

## Ubuntu Font
if ! fc-list | grep -q "Ubuntu"; then
    echo "Ubuntu font could not be found. Please install the Ubuntu font."
    exit 1
fi

# OPTS_SPEC is a string that describes the command-line options for the script, based on the requirements of git rev-parse --parseopt.
OPTS_SPEC="\
${scriptname} [<options>] [--] [<inputfile>]

Pretty Proto - Compile a protocol from a markdown file

inputfile   The markdown file to compile (if the download flag isn't set). If not provided, input is taken from stdin instead.
--
h,help        show this help

S,sharelatex  download the protocol from sharelatex
H,hedgedoc    download the protocol from hedgedoc
k,keep        keep the downloaded markdown protocol
e,email=      the email to use for downloading the protocol from sharelatex
p,password=   the password to use for downloading the protocol from sharelatex
D,domain=     the domain of the sharelatex or hedgedoc instance
P,project=    the project id of the protocol on sharelatex
f,filename=   the filename of the protocol on sharelatex
I,id=         the id of the protocol on hedgedoc
c,chair=      add the signature of the chair to the
t,transcript= add the signature of the transcript writer to the protocol
s,show        show the compiled pdf"

# Create tmpdir
tmpdir=$(mktemp -d)
chmod 700 $tmpdir

# Set default values
sigdir="$scriptpath/sigs"               # The directory containing the signatures
sigline="$scriptpath/tex/sigline.tex" # The signature line to add to the protocol
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

# pretty.conf is a file with a pretty proto configuration
if [ -f pretty.conf ]; then
    # read the configuration file
    echo "Reading configuration file pretty.conf..."

    # source the configuration file
    source ./pretty.conf
fi


# Function to parse the arguments via git rev-parse --parseopt
# Based on https://www.lucas-viana.com/posts/bash-argparse/#a-fully-functional-copypaste-example
parse_args() {
    set_args="$(echo "$OPTS_SPEC" | git rev-parse --parseopt -- "$@" || echo exit $?)"

    eval "$set_args"
    
    while (( $# > 2 )); do
        opt=$1
        shift
        case "$opt" in
            -S|--sharelatex) download=true; sharelatex=true ;;
            -H|--hedgedoc) download=true; hedgedoc=true ;;
            -k|--keep) keep=true ;;
            -e|--email) email=$1; shift ;;
            -p|--password) password=$1; shift ;;
            -D|--domain) domain=$1; shift ;;
            -P|--project) project=$1; shift ;;
            -f|--filename) filename=$1; shift ;;
            -I|--id) id=$1; shift ;;
            -c|--chair) chairsig="$sigdir/$1.png"; shift ;;
            -t|--transcript) transsig="$sigdir/$1.png"; shift ;;
            -s|--show) show=true ;;
        esac
    done

    inputfile="$2"
}

parse_frontmatter() {
    # extract key value pairs
    while read -r line; do
        key=$(echo $line | cut -d: -f1 | tr -d '[:space:]')
	value=$(echo $line | cut -d: -f2- | sed -r 's/^\s*"?([^"]*)"?$/\1/')
        case $key in
            title) name=$value ;;
            font) font=$value ;;
            logo) logo=$value ;;
            tocTitle) tocTitle=$value ;;
            tocSubtitle) tocSubtitle=$value ;;
            intro) intro=$value ;;
            outro) outro=$value ;;
	    sigline) sigline=$value ;;
        esac
    done <<< $(echo "$1" | sed -n '2,$p')
}

# Parse the arguments
parse_args "$@"

# If the download and sharelatex flags are set, download the protocol from sharelatex
if [ "$download" = true ] && [ "$sharelatex" = true ]; then
    # set the domain if not set
    if [ -z "$domain" ]; then
        domain=$sl_domain
    fi

    # Fetching csrf token from login page and saving it to csrf variable
    echo "Fetching login page..."
    curl -s -c $cookie "$domain/login" |
        sed -rn 's/^.*<input name="_csrf" type="hidden" value="([^"]+)".*$/\1/p' > $tmpdir/csrf.txt
    csrf=$(cat $tmpdir/csrf.txt)

    # Logging into sharelatex
    echo "Logging into sharelatex..."
    curl "$domain/login" -s -b $cookie -c $cookie -H "Referer: $domain/login" \
        -d "_csrf=$csrf" -d "email=$email" -d "password=$password"

    # Download the project zip
    echo -e "\nDownloading protocol..."
    curl -s -b $cookie -c $cookie -o $zip $domain/project/$project/download/zip

    # Unzip the project
    echo -e "\nUnzipping protocol..."
    unzip -q "$zip" "$filename" -d "$tmpdir"

    inputfile=$tmpdir/$filename
fi

# If the download and hedgedoc flags are set, download the protocol from hedgedoc
if [ "$download" = true ] && [ "$hedgedoc" = true ]; then
    # set the domain if not set
    if [ -z "$domain" ]; then
        domain=$hd_domain
    fi

    url="$domain/$id/download"

    # Download the protocol from hedgedoc
    echo -e "\nDownloading protocol from $url..."
    curl -s -o $tmpdir/protocol.md $url

    inputfile=$tmpdir/protocol.md
fi

# If inputfile is not set and no stdin is provided, show usage
if [ -z "$inputfile" ] && [ -t 0 ]; then
    echo "No input file provided and no stdin provided."
    exit 1
fi

# Create a working copy of the input file
tmpfile="$tmpdir/$inputfile"
if [ -n "$inputfile" ]; then
    # if inputfile is already within the tmpdir, leave it
    if [ "${inputfile:0:${#tmpdir}}" = "$tmpdir" ]; then
        tmpfile=$inputfile
    else
        # if inputfile is not within the tmpdir, copy it
        echo "Creating working copy of $inputfile..."
        cp $inputfile $tmpfile
    fi
else
    # take from stdin
    echo "Taking input from stdin..."
    tmpfile="$tmpdir/stdin"
    cat > $tmpfile
    inputfile="stdin"
fi

# Parse frontmatter
frontmatter=$(sed -n '/^---$/,/^---$/p' $tmpfile)
if [ -n "$frontmatter" ]; then
    echo "Parsing frontmatter..."

    # parse
    parse_frontmatter "$frontmatter"

    # remove frontmatter from the file
    sed -i '/^---$/,/^---$/d' $tmpfile
fi

# If the name is not set (by the frontmatter), try to find it in the text
if [ -z "$name" ]; then
    # Try to find the name of the protocol
    name=$(grep -E ".?Az\." $tmpfile | sed -E 's/.*Az\.\s*(.*Protokoll).*/\1/')
    if [ -z "$name" ]; then
        echo "Could not figure out the name of the protocol."
        name="protocol"
    fi
fi

# If the download and keep flags are set, keep the markdown file
if [ "$download" = true ] && [ "$keep" = true ]; then
    echo "Keeping the markdown file..."
    cp $tmpfile $name.md
fi

# Set the output file names
pdf="$name.pdf"
latex="$name.tex"

# Determine if sigline is already in markdown (for legacy reasons)
tmpfile_content=$(cat $tmpfile)
sigline_content=""

# replace \pegel with the water level of the Bodensee
if [[ $tmpfile_content == *\\pegel* ]]; then
    # api to get the water level
    api_url="https://www.pegelonline.wsv.de/webservices/rest-api/v2/stations/KONSTANZ/W/"
    # if the name of the protocol was set without date, use the current water level
    if [[ "$name" == protocol ]]; then
        pegel="[$(curl -s "${api_url}currentmeasurement.json" | jq -r '.value')cm](https://www.bodenseee.net/pegel/)"
    else
        # get the date from the name
        prefix="SFS_Informatik."
        suffix=".Protokoll"
        date="$(echo "$name" | sed -e "s/^$prefix//" -e "s/$suffix$//")T"
        # get the closing time of the conference 
        time=$(grep -E "geschlossen" $tmpfile | grep -o -E "[0-9]{2}:[0-9]{2}")
        # if time is not set, use 17:00
        if [ -z "$time" ]; then
            time="17:00:00+02:00"
        else
            #round time to the last 15minutes
            hours=${time:0:2}
            minutes=${time:3:2}
	    minutes=$(sed -r 's/0*([0-9]*)/\1/' <<< $minutes)
            minutes=$((minutes - minutes % 15))
            time="$hours:$minutes:00+02:00"
        fi
        # ge the waterlevel for the date and time of the conference
        pegel="[$(curl -s "${api_url}measurements.json?start=$date$time" | jq -r '.[0].value')cm](https://www.bodenseee.net/pegel/)"
    fi
    # replace \pegel with the current water level in tmpfile
    echo "${tmpfile_content/\\pegel/$pegel}" > $tmpfile
fi


if [ -f "$sigline" ]; then
    sigline_content=$(cat $sigline)
fi


if [[ $tmpfile_content == *"$sigline_content"* ]]; then
    echo "Markdown already includes signature lines..."
elif [ -z "$sigline" ]; then # if no sigline tex is specified, assume that none is wanted
    echo "No signature line specified..."
else
    echo "Adding signature line..."
    cat $sigline >> $tmpfile
fi

# If chair signature is set...
if [ -n "$chairsig" ]; then
    # Check if the chair signature exists
    if [ ! -f $chairsig ]; then
        echo "Chair signature not found: $chairsig"
        exit 1
    else
        # add the chair signature to the proper place
        echo Adding chair signature: $chairsig
        sed -ri "/^\\\\begin\\{tabular\\}\\{ll\\}$/,/hline/{/^...$/d;/hline/s#^#\\\\includegraphics[width=3cm]{$chairsig}\\\\vspace{-1em}#}" "$tmpfile"
    fi
fi

# If trancscript writer is set...
if [ -n "$transsig" ]; then
    # Check if the transcript writer signature exists
    if [ ! -f $transsig ]; then
        echo "Protocolant signature not found: $transsig"
        exit 1
    else
        # add the transcript writer signature to the proper place
        echo Adding transcript writer signature: $transsig
        sed -ri "/^Unterschrift der Sitzungsleitung/,/hline/{/^...$/d;/hline/s#^#\\\\includegraphics[width=3cm]{$transsig}\\\\vspace{-1em}#}" "$tmpfile"
    fi
fi

# compile to pdf
echo Compiling to $pdf

# pandoc "$tmpfile" \
#     -f markdown \
#     --template="$scriptpath/tex/template.tex" \
#     --include-in-header="$scriptpath/tex/style.tex" \
#     -V logo:"$logo" \
#     -V header:"$(echo $name | sed -E 's/[_]/\\_/g')" \
#     -V mainfont="$font" \
#     -V colorlinks:true \
#     -V linkcolor:darkbluk \
#     -V urlcolor:darkbluk \
#     -V toccolor:black \
#     -V toc-title:"$tocTitle" \
#     -V toc-subtitle:"$tocSubtitle" \
#     -V toc-depth:1 \
#     -t latex \
#     -o "test.tex"

sed -E "s/([^#]) TOP ([0-9]):/\1 TOP \\\\phantom{0}\2:/g" "$tmpfile" > "$tmpdir/sed-pad-top-numbers"

pandoc "$tmpdir/sed-pad-top-numbers" \
    -f markdown \
    --template="$scriptpath/tex/template.tex" \
    --include-in-header="$scriptpath/tex/style.tex" \
    -V logo:"$logo" \
    -V header:"$(echo $name | sed -E 's/[_]/\\_/g')" \
    -V mainfont="$font" \
    -V colorlinks:true \
    -V linkcolor:darkbluk \
    -V urlcolor:darkbluk \
    -V toccolor:black \
    -V toc-title:"$tocTitle" \
    -V toc-subtitle:"$tocSubtitle" \
    -V toc-depth:1 \
    -V lang:de \
    -V csquotes:true \
    -t pdf \
    --pdf-engine=xelatex \
    -o "$pdf"

# show the pdf if the -s flag is set
if [ "$show" = true ]; then
    echo "Opening $pdf..."
    xdg-open "$pdf"
fi

# cleanup
rm -r $tmpdir
