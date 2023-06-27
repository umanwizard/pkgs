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
                    (commit "e5554d06e0abb52a6d56bba0e9f155aa02643274")))
              (sha256
               (base32
                "0z69h5almagnc7jm9zqkgnx1wsq9zdwaaf6awrr0h2hrhbfwrld6"))
              (patches (search-patches "readline-include-order.patch"))
              (patch-flags '("-p1"))
              ))))
