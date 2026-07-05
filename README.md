<p align="center">
  <img src="assets/brand/clambback-official-logo.png" alt="clambback official logo" width="520">
</p>

<p align="center">
  <strong>Configurable TLS transport service.</strong>
</p>

<p align="center">
  <a href="https://nowpayments.io/donation?api_key=************************************" target="_blank" rel="noreferrer noopener">
    <img src="https://nowpayments.io/images/embeds/donation-button-black.svg" alt="Crypto donation button by NOWPayments">
  </a>
</p>

## Install

Supported platforms: **Rocky Linux** and **macOS**.

### Rocky Linux

```sh
curl -fsSL https://raw.githubusercontent.com/JohnThre/clambback/main/scripts/install-rocky.sh | bash
```

Builds the latest release from source and installs it as a native RPM via `dnf`, avoiding the glibc/Boost ABI mismatch of the prebuilt release RPM (built on a newer Ubuntu toolchain). See `scripts/install-rocky.sh` for options.

### macOS

Download the signed `.tar.gz` from the [latest release](https://github.com/JohnThre/clambback/releases), or build from source:

```sh
brew install boost openssl@3
git clone https://github.com/JohnThre/clambback.git
cd clambback
cmake -S . -B build -DCMAKE_PREFIX_PATH="$(brew --prefix boost);$(brew --prefix openssl@3)"
cmake --build build --parallel
```
