(define-module (btv rust)
  #:use-module (gnu packages)
  #:use-module (gnu packages readline)
  #:use-module (guix packages)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix utils)
  #:use-module (guix git-download)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages gdb))


(define rust-1.68 (@@ (gnu packages rust) rust-1.68))
(define rust-bootstrapped-package (@@ (gnu packages rust) rust-bootstrapped-package))

(define rust-1.69
  (let ((p (rust-bootstrapped-package
            rust-1.68 "1.69.0" "03zn7kx5bi5mdfsqfccj4h8gd6abm7spj0kjsfxwlv5dcwc9f1gv")))
    (package
      (inherit p)
      (source
       (origin
         (inherit (package-source p))
         (snippet
          '(begin
             (for-each delete-file-recursively
                       '("src/llvm-project"
                         "vendor/tikv-jemalloc-sys/jemalloc"))
             ;; Also remove the bundled (mostly Windows) libraries.
             (for-each delete-file
                       (find-files "vendor" ".*\\.(a|dll|exe|lib)$")))))))))

(define rust-1.70
  (rust-bootstrapped-package
   rust-1.69 "1.70.0" "0z6j7d0ni0rmfznv0w3mrf882m11kyh51g2bxkj40l3s1c0axgxj"))

(define (mk-public-rust base-rust)
  (package
    (inherit base-rust)
    (outputs (cons "rustfmt" (package-outputs base-rust)))
    (arguments
     (substitute-keyword-arguments (package-arguments base-rust)
       ((#:tests? _ #f)
        (not (%current-target-system)))
       ((#:phases phases)
        `(modify-phases ,phases
           (add-after 'unpack 'relax-gdb-auto-load-safe-path
             ;; Allow GDB to load binaries from any location, otherwise the
             ;; gdbinfo tests fail.  This is only useful when testing with a
             ;; GDB version newer than 8.2.
             (lambda _
               (setenv "HOME" (getcwd))
               (with-output-to-file (string-append (getenv "HOME") "/.gdbinit")
                 (lambda _
                   (format #t "set auto-load safe-path /~%")))
               ;; Do not launch gdb with '-nx' which causes it to not execute
               ;; any init file.
               (substitute* "src/tools/compiletest/src/runtest.rs"
                 (("\"-nx\".as_ref\\(\\), ")
                  ""))))
           (add-after 'unpack 'patch-cargo-env-shebang
             (lambda _
               (substitute* '("src/tools/cargo/tests/testsuite/build.rs"
                              "src/tools/cargo/tests/testsuite/fix.rs")
                 ;; The cargo *_wrapper tests set RUSTC.*WRAPPER environment
                 ;; variable which points to /usr/bin/env.  Since it's not a
                 ;; shebang, it needs to be manually patched.
                 (("/usr/bin/env")
                  (which "env")))))
           (add-after 'unpack 'disable-tests-requiring-git
             (lambda _
               (substitute* "src/tools/cargo/tests/testsuite/new.rs"
                 (("fn author_prefers_cargo")
                  "#[ignore]\nfn author_prefers_cargo")
                 (("fn finds_author_git")
                  "#[ignore]\nfn finds_author_git")
                 (("fn finds_local_author_git")
                  "#[ignore]\nfn finds_local_author_git"))))
           (add-after 'unpack 'disable-tests-requiring-mercurial
             (lambda _
               (substitute*
                   "src/tools/cargo/tests/testsuite/init/simple_hg_ignore_exists/mod.rs"
                 (("fn simple_hg_ignore_exists")
                  "#[ignore]\nfn simple_hg_ignore_exists"))
               (substitute*
                   "src/tools/cargo/tests/testsuite/init/mercurial_autodetect/mod.rs"
                 (("fn mercurial_autodetect")
                  "#[ignore]\nfn mercurial_autodetect"))))
           (add-after 'unpack 'disable-tests-broken-on-aarch64
             (lambda _
               (with-directory-excursion "src/tools/cargo/tests/testsuite/"
                 (substitute* "build_script_extra_link_arg.rs"
                   (("^fn build_script_extra_link_arg_bin_single" m)
                    (string-append "#[ignore]\n" m)))
                 (substitute* "build_script.rs"
                   (("^fn env_test" m)
                    (string-append "#[ignore]\n" m)))
                 (substitute* "collisions.rs"
                   (("^fn collision_doc_profile_split" m)
                    (string-append "#[ignore]\n" m)))
                 (substitute* "concurrent.rs"
                   (("^fn no_deadlock_with_git_dependencies" m)
                    (string-append "#[ignore]\n" m)))
                 (substitute* "features2.rs"
                   (("^fn dep_with_optional_host_deps_activated" m)
                    (string-append "#[ignore]\n" m))))))
           (add-after 'unpack 'patch-command-exec-tests
             ;; This test suite includes some tests that the stdlib's
             ;; `Command` execution properly handles in situations where
             ;; the environment or PATH variable are empty, but this fails
             ;; since we don't have `echo` available at its usual FHS
             ;; location.
             (lambda _
               (substitute* (match (find-files "." "^command-exec.rs$")
                              ((file) file))
                 (("Command::new\\(\"echo\"\\)")
                  (format #f "Command::new(~s)" (which "echo"))))))
           (add-after 'unpack 'patch-command-uid-gid-test
             (lambda _
               (substitute* (match (find-files "." "^command-uid-gid.rs$")
                              ((file) file))
                 (("/bin/sh")
                  (which "sh")))))
           ;; (add-after 'unpack 'skip-shebang-tests
           ;;   ;; This test make sure that the parser behaves properly when a
           ;;   ;; source file starts with a shebang. Unfortunately, the
           ;;   ;; patch-shebangs phase changes the meaning of these edge-cases.
           ;;   ;; We skip the test since it's drastically unlikely Guix's
           ;;   ;; packaging will introduce a bug here.
           ;;   (lambda _
           ;;     (delete-file "src/test/ui/parser/shebang/sneaky-attrib.rs")))
           (add-after 'unpack 'patch-process-tests
             (lambda* (#:key inputs #:allow-other-keys)
               (let ((bash (assoc-ref inputs "bash")))
                 (substitute* "library/std/src/process/tests.rs"
                   (("\"/bin/sh\"")
                    (string-append "\"" bash "/bin/sh\"")))
                 ;; The three tests which are known to fail upstream on QEMU
                 ;; emulation on aarch64 and riscv64 also fail on x86_64 in Guix's
                 ;; build system. Skip them on all builds.
                 (substitute* "library/std/src/sys/unix/process/process_common/tests.rs"
                   (("target_arch = \"arm\",") "target_os = \"linux\",")))))
           (add-after 'unpack 'disable-interrupt-tests
             (lambda _
               ;; This test hangs in the build container; disable it.
               (substitute* (match (find-files "." "^freshness.rs$")
                              ((file) file))
                 (("fn linking_interrupted")
                  "#[ignore]\nfn linking_interrupted"))
               ;; Likewise for the ctrl_c_kills_everyone test.
               (substitute* (match (find-files "." "^death.rs$")
                              ((file) file))
                 (("fn ctrl_c_kills_everyone")
                  "#[ignore]\nfn ctrl_c_kills_everyone"))))
           (add-after 'configure 'add-gdb-to-config
             (lambda* (#:key inputs #:allow-other-keys)
               (let ((gdb (assoc-ref inputs "gdb")))
                 (substitute* "config.toml"
                   (("^python =.*" all)
                    (string-append all
                                   "gdb = \"" gdb "/bin/gdb\"\n"))))))
           (replace 'build
             ;; Phase overridden to also build rustfmt.
             (lambda* (#:key parallel-build? #:allow-other-keys)
               (let ((job-spec (string-append
                                "-j" (if parallel-build?
                                         (number->string (parallel-job-count))
                                         "1"))))
                 (invoke "./x.py" job-spec "build"
                         "library/std" ;rustc
                         "src/tools/cargo"
                         "src/tools/rustfmt"))))
           (replace 'check
             ;; Phase overridden to also test rustfmt.
             (lambda* (#:key tests? parallel-build? #:allow-other-keys)
               (when tests?
                 (let ((job-spec (string-append
                                  "-j" (if parallel-build?
                                           (number->string (parallel-job-count))
                                           "1"))))
                   (invoke "./x.py" job-spec "test" "-vv"
                           "library/std"
                           "src/tools/cargo"
                           "src/tools/rustfmt")))))
           (replace 'install
             ;; Phase overridden to also install rustfmt.
             (lambda* (#:key outputs #:allow-other-keys)
               (invoke "./x.py" "install")
               (substitute* "config.toml"
                 ;; Adjust the prefix to the 'cargo' output.
                 (("prefix = \"[^\"]*\"")
                  (format #f "prefix = ~s" (assoc-ref outputs "cargo"))))
               (invoke "./x.py" "install" "cargo")
               (substitute* "config.toml"
                 ;; Adjust the prefix to the 'rustfmt' output.
                 (("prefix = \"[^\"]*\"")
                  (format #f "prefix = ~s" (assoc-ref outputs "rustfmt"))))
               (invoke "./x.py" "install" "rustfmt")))))))
    ;; Add test inputs.
    (native-inputs (cons* `("gdb" ,gdb/pinned)
                          `("procps" ,procps)
                          (package-native-inputs base-rust)))))

(define-public rust-next
  (let ((p (mk-public-rust rust-1.69)))
    (package
      (inherit p)
      (arguments
       (substitute-keyword-arguments (package-arguments p)
         ((#:validate-runpath? _) #f)
         ((#:phases phases)
          `(modify-phases ,phases
             (replace 'disable-tests-requiring-mercurial
               (lambda _
                 (substitute*
                   "src/tools/cargo/tests/testsuite/init/simple_hg_ignore_exists/mod.rs"
                   (("fn case")
                    "#[ignore]\nfn case"))
                 (substitute*
                   "src/tools/cargo/tests/testsuite/init/mercurial_autodetect/mod.rs"
                   (("fn case")
                    "#[ignore]\nfn case")))))))))))
