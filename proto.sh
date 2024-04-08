#!/bin/bash

scriptpath=$(dirname $(realpath $0))
scriptname=$0

# OPTS_SPEC is a string that describes the command-line options for the script, based on the requirements of git rev-parse --parseopt.
OPTS_SPEC="\
${scriptname} [<options>] [--] [<inputfile>]

Pretty Proto - Compile a protocol from a markdown file

inputfile   The markdown file to compile (if the download flag isn't set). If not provided, input is taken from stdin instead.
--
h,help        show this help

d,download    download the protocol from sharelatex
k,keep        keep the downloaded markdown protocol
e,email=      the email to use for downloading the protocol
p,password=   the password to use for downloading the protocol
D,domain=     the domain of the sharelatex server
P,project=    the project id of the protocol on sharelatex
f,filename=   the filename of the protocol on sharelatex
c,chair=      add the signature of the chair to the
t,transcript= add the signature of the transcript writer to the protocol
s,show        show the compiled pdf"

# Create tmpdir
tmpdir=$(mktemp -d)
chmod 700 $tmpdir

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

## for sharelatex download
domain="https://sharelatex.physik.uni-konstanz.de"
email="fachschaft.informatik@uni-konstanz.de"
password=""
project="5a058e9d1731df007b5aa1fd"
filename="protokoll.tex"
zip="$tmpdir/protocol.zip"
cookie="$tmpdir/cookies.txt"

# pretty.conf is a file with a pretty proto configuration
if [ -f pretty.conf ]; then
    # read the configuration file
    source pretty.conf
fi

set_args=

# Function to parse the arguments via git rev-parse --parseopt
# Based on https://www.lucas-viana.com/posts/bash-argparse/#a-fully-functional-copypaste-example
parse_args() {
    set_args="$(echo "$OPTS_SPEC" | git rev-parse --parseopt -- "$@" || echo exit $?)"

    eval "$set_args"
    
    while (( $# > 2 )); do
        opt=$1
        shift
        case "$opt" in
            -d|--download) download=true ;;
            -k|--keep) keep=true ;;
            -e|--email) email=$1; shift ;;
            -p|--password) password=$1; shift ;;
            -D|--domain) domain=$1; shift ;;
            -P|--project) project=$1; shift ;;
            -f|--filename) filename=$1; shift ;;
            -c|--chair) chairsig="$sigdir/$1.png"; shift ;;
            -t|--transcript) transsig="$sigdir/$1.png"; shift ;;
            -s|--show) show=true ;;
        esac
    done

    inputfile=$2 # FIXME: no idea why it's $2 and not $1, but it works
}

# Parse the arguments
parse_args "$@"

# If the download flag is set, download the protocol
if [ "$download" = true ]; then
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

# If inputfile is not set and no stdin is provided, show usage
if [ -z "$inputfile" ] && [ -t 0 ]; then
    echo "No input file provided and no stdin provided."
    exit 1
fi

echo "Input file: $inputfile"

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

# LEGACY HANDLING
# Remove front matter -- it fucks up the pandoc conversion
# TODO: find out what is responsible for that / decide if we want to ignore the frontmatter
echo "Removing front matter..."
sed -i '/^---$/,/^...$/d' $tmpfile

# Try to find the name of the protocol
name=$(grep -E ".?Az\." $tmpfile | sed -E 's/.*Az\.\s*(.*Protokoll).*/\1/')
if [ -z "$name" ]; then
    name=${inputfile%.*}
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
sigline_content=$(cat $sigline)

if [[ $tmpfile_content == *"$sigline_content"* ]]; then
    echo "Markdown already includes signature lines..."
else
    echo "Adding signature lines..."
    cat $sigline >> $tmpfile
fi

# If chair signature is set...
if [ -n "$chairsig" ]; then
    # Check if the chair signature exists
    if [ ! -f $chairsig ]; then
        echo "Chair signature not found: $chairsig"
        exit 1
    fi
    
    # add the chair signature to the proper place
    echo Adding chair signature: $chairsig
    sed -ri "/^\\\\begin\\{tabular\\}\\{ll\\}$/,/hline/{/^...$/d;/hline/s#^#\\\\includegraphics[width=3cm]{$chairsig}\\\\vspace{-1em}#}" "$tmpfile"
fi

# If trancscript writer is set...
if [ -n "$transsig" ]; then
    # Check if the transcript writer signature exists
    if [ ! -f $transsig ]; then
        echo "Protocolant signature not found: $transsig"
        exit 1
    fi
    
    # add the transcript writer signature to the proper place
    echo Adding transcript writer signature: $transsig
    sed -ri "/^Unterschrift der Sitzungsleitung/,/hline/{/^...$/d;/hline/s#^#\\\\includegraphics[width=3cm]{$transsig}\\\\vspace{-1em}#}" "$tmpfile"
fi

# compile to pdf
echo Compiling to $pdf

pandoc $tmpfile \
    -f markdown \
    --template=$scriptpath/tex/template.latex \
    --include-in-header=$scriptpath/tex/style.latex \
    -V logo:$logo \
    -V header:"$(echo $name | sed -E 's/[_]/\\_/g')" \
    -V mainfont="$font" \
    -V colorlinks:true \
    -V linkcolor:darkbluk \
    -V urlcolor:darkbluk \
    -V toccolor:black \
    -V toc-title:"$tocTitle" \
    -V toc-subtitle:"$tocSubtitle" \
    -V toc-depth:1 \
    -t pdf \
    --pdf-engine=xelatex \
    -o $pdf

# show the pdf if the -s flag is set
if [ "$show" = true ]; then
    echo "Opening $pdf..."
    xdg-open $pdf
fi

# cleanup
rm -r $tmpdir
