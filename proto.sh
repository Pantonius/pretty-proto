#!/bin/bash

scriptname=$0
function usage {
    echo "Usage: $scriptname [OPTIONS] [FILES]"
    echo "Compile a protocol from a markdown file"
    echo "If no input file is set, the script will take input from stdin"
    echo
    echo "Options:"
    echo "  -h, --help                Show this help message and exit"
    echo "  -d, --download            Download the protocol from sharelatex"
    echo "  -k, --keep                Keep the downloaded markdown protocol"
    echo "  -e, --email               The email to use for downloading the protocol"
    echo "  -p, --password            The password to use for downloading the protocol"
    echo "  -D, --domain              The domain of the sharelatex server"
    echo "  -P, --project             The project id of the protocol on sharelatex"
    echo "  -f, --filename            The filename of the protocol on sharelatex"
    echo "  -c, --chair-signature     Add the chair signature to the protocol"
    echo "  -p, --protocol-signature  Add the protocolant signature to the protocol"
    echo "  -s, --show                Show the compiled pdf"
}

# The input file may be the first argument
if [ -f $1 ]; then
    inputfile=$1
    shift
fi


# Set default values
tmpdir=$(mktemp -d)
chmod 700 $tmpdir

sigdir="./sigs"
show=false

## for sharelatex download
download=false
keep=false
domain="https://sharelatex.physik.uni-konstanz.de"
email="fachschaft.informatik@uni-konstanz.de"
password=""
project="5a058e9d1731df007b5aa1fd"
filename="protokoll.tex"
zip="$tmpdir/protocol.zip"
cookie="$tmpdir/cookies.txt"

# Go through all remaining arguments
while [ "$#" -gt 0 ]; do
    case $1 in
        -h|--help) usage; exit 0 ;;
        -d|--download) download=true;;
        -k|--keep) keep=true;;
        -e|--email) email=$2; shift ;;
        -p|--password) password=$2; shift ;;
        -D|--domain) domain=$2; shift ;;
        -P|--project) project=$2; shift ;;
        -f|--filename) filename=$2; shift ;;
        -c|--chair-signature) chairsig="$sigdir/$2.png"; shift ;;
        -p|--protocol-signature) protsig="$sigdir/$2.png"; shift ;;
        -s|--show) show=true;;
        -*) echo "Unknown parameter passed: $1"; exit 1 ;;
        *)
            # if inputfile is not set yet and the argument is a file, set inputfile to the argument
            if [ -z "$inputfile" ] && [ -f $1 ]; then
                inputfile=$1
            else
                echo "Unknown parameter passed: $1"
                echo
                usage
                exit 1
            fi
    esac
    shift
done

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

# If no input file is set and stdin is empty
if [ -z "$inputfile" ] && [ -t 0 ]; then
    echo "No input set"
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

# If protocolant is set...
if [ -n "$protsig" ]; then
    # Check if the protocolant signature exists
    if [ ! -f $protsig ]; then
        echo "Protocolant signature not found: $protsig"
        exit 1
    fi
    
    # add the protocolant signature to the proper place
    echo Adding protocolant signature: $protsig
    sed -ri "/^Unterschrift der Sitzungsleitung/,/hline/{/^...$/d;/hline/s#^#\\\\includegraphics[width=3cm]{$protsig}\\\\vspace{-1em}#}" "$tmpfile"
fi

# compile to pdf
echo Compiling to $pdf

pandoc $tmpfile \
    -f markdown \
    --template=./tex/template.latex \
    --include-in-header=./tex/style.latex \
    -V header:"$(echo $name | sed -E 's/[_\.]/\ /g' | sed -E 's/-/\./g')" \
    -V mainfont="Ubuntu" \
    -V colorlinks:true \
    -V linkcolor:darkbluk \
    -V urlcolor:darkbluk \
    -V toccolor:black \
    -V toc-title:"Tagesordnung" \
    -t pdf \
    --pdf-engine=xelatex \
    -o $pdf

# show the pdf if the -s flag is set
if [ -n "$show" ]; then
    xdg-open $pdf
fi

# cleanup
rm -r $tmpdir
