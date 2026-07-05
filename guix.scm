(use-modules
  (gnu packages boost)
  (gnu packages pkg-config)
  (gnu packages tls)
  (guix build-system cmake)
  (guix gexp)
  (guix licenses)
  (guix packages))

(package
  (name "clambback")
  (version "1.0.0-alpha.2")
  (source (local-file "." "clambback-checkout" #:recursive? #t))
  (build-system cmake-build-system)
  (arguments
   (list
    #:configure-flags
    #~(list "-DENABLE_MYSQL=OFF" "-DSYSTEMD_SERVICE=OFF")))
  (native-inputs
   (list pkg-config))
  (inputs
   (list boost openssl))
  (home-page "https://github.com/JohnThre/clambback")
  (synopsis "C++ network service with TLS transport support")
  (description "clambback is a small C++ network service with TLS transport support.")
  (license gpl3+))
