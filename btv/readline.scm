(define-module (btv readline)
  #:use-module (gnu packages)
  #:use-module (gnu packages readline)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix utils)
  #:use-module (guix git-download))



(define-public readline-devel
  (package (inherit readline)
    (name "readline-devel")
    (version "9.0-devel")
    (source (origin
              (method git-fetch)
              (uri (git-reference
                    (url "https://git.savannah.gnu.org/git/readline.git")
                    (commit "9f177ebb2be58e07a4e437e4b885411ae2017114")))
              (sha256
               (base32
                "1lqpz844gkbw573z80syr2wn90fv9i62q7ydc29y7a02c35dahvn"))
              ))))
