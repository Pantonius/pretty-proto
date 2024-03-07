#!/bin/bash

scriptpath=$(dirname $(realpath $0))
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
    echo "  -c, --chair               Add the signature of the chair to the protocol"
    echo "  -t, --transcript          Add the signature of the transcript writer to the protocol"
    echo "  -s, --show                Show the compiled pdf"

    echo "Configuration:"
    echo "  The script will look for a file called pretty.conf in the current directory"
    echo "  The file should contain a pretty proto configuration"
    echo "  The configuration file may contain the following variables:"
    echo "    sigdir: The directory containing the signatures"
    echo "    logo: The logo to use for the protocol"
    echo "    toc-title: The title of the table of contents"
}

# The input file may be the first argument
if [ -f $1 ]; then
    inputfile=$1
    shift
fi


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

# pretty.conf is a file with a pretty proto configuration
if [ -f pretty.conf ]; then
    # read the configuration file
    source pretty.conf
fi

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
        -c|--chair) chairsig="$sigdir/$2.png"; shift ;;
        -t|--transcript) transsig="$sigdir/$2.png"; shift ;;
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

# LEGACY HANDLING
# Remove front matter -- it fucks up the pandoc conversion
# TODO: find out what is responsible for that / decide if we want to ignore the frontmatter
echo "Removing front matter..."
sed -i '/^---$/,/^...$/d' $tmpfile

# if sigline is already in the MD file, don't add anything

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
