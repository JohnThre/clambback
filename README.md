<p align="center">
  <img src="assets/brand/clambback-squircle.svg" alt="clambback app icon" width="160">
</p>

<h1 align="center">clambback</h1>

<p align="center">
  <strong>Configurable TLS transport service.</strong>
</p>

<p align="center">
  <a href="https://clambcloud.com">clambcloud.com</a> · <a href="https://swiphtgroup.com">swiphtgroup.com</a>
</p>

<p align="center">
  <a href="https://nowpayments.io/donation?api_key=4f798f1e-c93e-456e-8067-b03b200790cd" target="_blank" rel="noreferrer noopener">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://nowpayments.io/images/embeds/donation-button-white.svg">
      <img src="https://nowpayments.io/images/embeds/donation-button-black.svg" alt="Cryptocurrency &amp; Bitcoin donation button by NOWPayments">
    </picture>
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

## Support

If clambback is useful to you, you can support its development:

- [Liberapay](https://en.liberapay.com/jpfchang/)
- [Ko-fi](https://ko-fi.com/jpfchang)
- [IssueHunt](https://oss.issuehunt.io/u/johnthre)
- [NOWPayments](https://nowpayments.io/donation?api_key=4f798f1e-c93e-456e-8067-b03b200790cd) (cryptocurrency)
