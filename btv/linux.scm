(define-module (btv linux)
  #:use-module (guix packages)
  #:use-module (guix git-download)
  #:use-module (guix build-system cmake)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages)
  ;; #:use-module (nongnu packages linux)
  #:use-module (gnu packages cpio)
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

(define %bpf-extra-linux-options
  `(;; Needed for probes
    ("CONFIG_UPROBE_EVENTS" . #t)
    ("CONFIG_KPROBE_EVENTS" . #t)
    ;; kheaders module also helpful for tracing
    ("CONFIG_IKHEADERS" . #t)
    ("CONFIG_BPF" . #t)
    ("CONFIG_BPF_SYSCALL" . #t)
    ("CONFIG_BPF_JIT_ALWAYS_ON" . #t)
    ;; optional, for tc filters
    ("CONFIG_NET_CLS_BPF" . m)
    ;; optional, for tc actions
    ("CONFIG_NET_ACT_BPF" . m)
    ("CONFIG_BPF_JIT" . #t)
    ;; for Linux kernel versions 4.1 through 4.6
    ;; ("CONFIG_HAVE_BPF_JIT" . y)
    ;; for Linux kernel versions 4.7 and later
    ("CONFIG_HAVE_EBPF_JIT" . #t)
    ;; optional, for kprobes
    ("CONFIG_BPF_EVENTS" . #t)
    ;; kheaders module
    ("CONFIG_IKHEADERS" . #t)
    ;; BTF debug info, requires `pahole' from `dwarves' package
    ("CONFIG_DEBUG_INFO=y" . #t)
    ("CONFIG_DEBUG_INFO_DWARF4" . #t)
    ("CONFIG_DEBUG_INFO_BTF" . #t)))

(define-public linux-libre-with-bpf
  (let ((base-linux-libre
         ((@@ (gnu packages linux) make-linux-libre*)
          linux-libre-6.6-version
          linux-libre-6.6-gnu-revision
          linux-libre-6.6-source
          '("x86_64-linux" "i686-linux" "armhf-linux"
            "aarch64-linux" "powerpc64le-linux" "riscv64-linux")
          #:extra-version "bpf"
          #:configuration-file (@@ (gnu packages linux) kernel-config)
          #:extra-options
          (append %bpf-extra-linux-options
                  (@@ (gnu packages linux) %default-extra-linux-options)))))
    (package
      (inherit base-linux-libre)
      (inputs (modify-inputs (package-inputs base-linux-libre)
                (prepend cpio
                         (@ (gnu packages compression) zlib) python dwarves)))
      (synopsis "Linux-libre with BPF support")
      (description "This package provides GNU Linux-Libre with support
for @acronym{BPF, the Berkeley Packet Filter}."))))
