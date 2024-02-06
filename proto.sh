#!/bin/bash

scriptname=$0
function usage {
    echo "Usage: $scriptname [OPTIONS] [FILES]"
    echo "Compile a protocol from a markdown file"
    ehco "If no input file is set, the script will take input from stdin"
    echo
    echo "Options:"
    echo "  -h, --help                Show this help message and exit"
    echo "  -c, --chair-signature     Add the chair signature to the protocol"
    echo "  -p, --protocol-signature  Add the protocolant signature to the protocol"
    echo "  -s, --show                Show the compiled pdf"
}

# The input file may be the first argument
if [ -f $1 ]; then
    inputfile=$1
    shift
fi


sigdir="./sigs"

# Go through all remaining arguments
while [ "$#" -gt 0 ]; do
    case $1 in
        -h|--help) usage; exit 0 ;;
        -c|--chair-signature) chairsig="$sigdir/$2.png"; shift ;;
        -p|--protocol-signature) protsig="$sigdir/$2.png"; shift ;;
        -s|--show) show=true; shift ;;
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

# If no input file is set and stdin is empty
if [ -z "$inputfile" ] && [ -t 0 ]; then
    echo "No input set"
    exit 1
fi

# tmpfile is a working copy of the input file
tmpfile=$(mktemp)
if [ -n "$inputfile" ]; then
    cp $inputfile $tmpfile
else
    # take from stdin
    echo "Taking input from stdin..."
    cat > $tmpfile
    inputfile="stdin"
fi

# Try to find the name of the protocol
name=$(grep -E ".?Az\." $tmpfile | sed -E 's/.*Az\.\s*(.*Protokoll).*/\1/')
if [ -z "$name" ]; then
    name=${inputfile%.*}
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
rm $tmpfile
