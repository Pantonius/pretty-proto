{ pkgs ? import <nixpkgs> {} }:
let 
    tex = (pkgs.texlive.combine) {
        inherit (pkgs.texlive) scheme-basic
        dvisvgm dvipng
        wrapfig amsmath ulem hyperref capt-of
        a4wide lastpage csquotes sectsty;
    };
in 
pkgs.mkShell {
    nativeBuildInputs = [
        tex
        pkgs.just
    ];
    shellHook = ''
        echo "use 'just compile NAME' to compile the protocol"
        echo "use 'just sign NAME' if your signature is stored in sigs/mysignature.png (symlinking is ok)"
    '';
}

