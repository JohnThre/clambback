# Contributing

Changes should keep the project small, portable, and package-manager friendly. clambback targets **Rocky Linux** and **macOS** only; do not add Windows-, Android-, or other-distro-specific code or packaging.

Before submitting changes, build with CMake and run the smoke tests where the required local tools are available.

## Release Pipeline

Tagged pushes (`v*`) trigger `.github/workflows/release.yml`, which builds, signs, and publishes packages for both supported platforms. The Rocky Linux job runs first (inside a `rockylinux:9` container) and creates the GitHub Release; the macOS job waits for it (`needs: package-rocky`) and only uploads its own signed asset, avoiding a race to create the release.

```mermaid
flowchart TD
    T[Tag push v*] --> R[package-rocky]
    R --> R1[dnf install deps]
    R1 --> R2[build + ctest]
    R2 --> R3[cpack TGZ+RPM]
    R3 --> R4[gpg sign assets]
    R4 --> R5[gh release create/upload]
    R5 -->|needs| M[package-macos]
    M --> M1[brew install deps]
    M1 --> M2[build + ctest]
    M2 --> M3[cpack TGZ]
    M3 --> M4[gpg sign asset]
    M4 --> M5[gh release upload --clobber]
```
