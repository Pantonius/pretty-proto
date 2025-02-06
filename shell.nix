{ pkgs ? import <nixpkgs> {} }:
let 
    tex = (pkgs.texlive.combine) {
        inherit (pkgs.texlive) scheme-medium
        dvisvgm dvipng
        wrapfig amsmath ulem hyperref capt-of
        xelatex-dev
        a4wide lastpage csquotes sectsty xcolor;
    };
in 
pkgs.mkShell {
    nativeBuildInputs = [
        tex
        pkgs.just
        pkgs.jq
        pkgs.pandoc
        pkgs.ubuntu_font_family
    ];
    shellHook = ''
        export XDG_CACHE_HOME="$(mktemp -d)"
        echo "use 'just compile NAME' to compile the protocol"
        echo "use 'just sign NAME' if your signature is stored in sigs/mysignature.png (symlinking is ok)"
    '';
}

