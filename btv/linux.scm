(define-module (btv linux)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system cmake)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages)
  #:use-module (nongnu packages linux)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages python)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages elf)
  #:use-module (guix gexp)
)

(define-public libbpf-1.1.0
  (package
    (inherit libbpf)
    (version "1.1.0")
    (source
     (origin
       (method git-fetch)
       (uri (git-reference
             (url "https://github.com/libbpf/libbpf")
             (commit (string-append "v" version))))
       (file-name (git-file-name (package-name libbpf) version))
       (sha256
        (base32
         "0rh8828cridphkmynb3nhdcd8l37i11885kmnp2hilk81lh7myzy"))))))
(define-public dwarves
  (package
    (name "dwarves")
    (version "1.24")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://github.com/acmel/dwarves")
                    (commit (string-append "v" version))))
              (file-name (git-file-name name version))
              (sha256
               (base32 "132ln21xj2xhpj3zzpisl18r189jdz0gn6j5rddz2ifp6zlq2vkx"))))
    (build-system cmake-build-system)
    (arguments (list #:tests? #f
                     #:configure-flags #~(list "-DLIBBPF_EMBEDDED=OFF" "-D__LIB=lib" ;; wtf???
                                               )))
    (inputs (list pkg-config zlib libbpf-1.1.0 linux-libre-headers-6.6 ;; uhh??
                  elfutils))
    (home-page "XXX")
    (synopsis "XXX")
    (description "XXX")
    (license license:gpl2)))

(define-public linux-with-bpf
  (let ((configured
         (corrupt-linux linux-libre-with-bpf                 
                        #:configs (cons* "CONFIG_BPF_JIT=y" "CONFIG_DEBUG_INFO=y" "CONFIG_DEBUG_INFO_DWARF4=y" "CONFIG_DEBUG_INFO_BTF=y" (nonguix-extra-linux-options linux-libre-with-bpf)))))
    (package
      (inherit configured)
      (inputs (modify-inputs (package-inputs configured)
                (prepend (@ (gnu packages compression) zlib) python dwarves))))))
