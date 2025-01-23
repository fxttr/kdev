{
  description = "Linux development environment";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";

    code-nix = {
      url = "github:fxttr/code-nix";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        extensions.follows = "nix-vscode-extensions";
      };
    };
  };

  outputs =
    { self
    , nixpkgs
    , ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      runGdb = pkgs.writeShellScriptBin "rungdb" ''
        ${pkgs.gdb}/bin/gdb \
                -ex "file ''${SRC_DIR}/vmlinux" \
                -ex "source ''${SRC_DIR}/scripts/gdb/vmlinux-gdb.py" \
                -ex "target remote localhost:1234"
      '';

      code = inputs.code-nix.packages.${pkgs.system}.default;

      devShell =
        let
          nativeBuildInputs = with pkgs;
            [
              (code {
                profiles = {
                  nix.enable = true;
                  c.enable = true;
                };
              })

              nixpkgs-fmt
              runGdb
              wget
              qemu
              guestfs-tools
              libguestfs-with-appliance
              pkg-config
              ripgrep
              socat

              # We build with LLVM
              clang-tools
              llvmPackages.clang
              lld
              llvmPackages.libllvm
              llvmPackages.bintools

              (python3.withPackages (ps: with ps; [
                GitPython
                ply
              ]))

              codespell
              gitFull

              # static analysis
              flawfinder
              cppcheck
              sparse
            ]
            ++ pkgs.linuxPackages_latest.kernel.nativeBuildInputs;
        in
        pkgs.mkShell {
          inherit nativeBuildInputs;

          NIX_HARDENING_ENABLE = "";
          LLVM = "1";

          # This is a hack on NixOS. A recent commit broke my whole env. >_>
          KCPPFLAGS = "-Qunused-arguments -Wno-unused-command-line-argument";
          KCFLAGS = "-Qunused-arguments -Wno-unused-command-line-argument";
          KAFLAGS = "-Qunused-arguments -Wno-unused-command-line-argument";
          LDFLAGS_MODULE = "-Qunused-arguments -Wno-unused-command-line-argument";
          HOSTCFLAGS = "-Qunused-arguments -Wno-unused-command-line-argument";
          HOSTLDLIBS = "-Qunused-arguments -Wno-unused-command-line-argument";
          USERCFLAGS = "-Qunused-arguments -Wno-unused-command-line-argument";
          USERLDFLAGS = "-Qunused-arguments -Wno-unused-command-line-argument";
        };
    in
    {
      devShells.${system}.default = devShell;
    };
}
