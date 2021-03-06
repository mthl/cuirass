;;;; guix.scm -- Guix package definition
;;; Copyright © 2016 Jan Nieuwenhuizen <janneke@gnu.org>
;;; Copyright © 2016, 2017 Mathieu Lirzin <mthl@gnu.org>
;;;
;;; This file is part of Cuirass.
;;;
;;; Cuirass is free software: you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation, either version 3 of the License, or
;;; (at your option) any later version.
;;;
;;; Cuirass is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with Cuirass.  If not, see <http://www.gnu.org/licenses/>.

(use-modules (ice-9 popen)
             (ice-9 rdelim)
             (gnu)
             (guix)
             (srfi srfi-1))

(define (keep-cuirass-file? file stat)
  ;; Return #t if FILE in Cuirass repository must be kept, #f otherwise. FILE
  ;; is an absolute file name and STAT is the result of 'lstat' applied to
  ;; FILE.
  (not (or (any (λ (str) (string-contains file str))
                '(".git" "autom4te" "Makefile.in" ".go" ".log"
                  "stamp-vti" ".dirstamp"))
           (any (λ (str) (string-suffix? str file))
                '("trs""configure" "Makefile" "config.status" "pre-inst-env"
                  "aclocal.m4" "bin/cuirass" "bin/evaluate" "config.cache"
                  "guix.scm")))))

(define %aux-dir
  (current-source-directory))

(define %srcdir
  (dirname %aux-dir))

(define (git-version-gen)
  ;; Return a string containing Cuirass version number.
  (let* ((cmd  "git-version-gen .tarball-version")
         (port (open-input-pipe (string-append %aux-dir "/" cmd)))
         (str  (read-line port)))
    (close-pipe port)
    str))

(define (spec+package-list spec)
  (list spec (specification->package spec)))

(package
  (inherit (specification->package "cuirass"))
  (version (git-version-gen))
  (source (local-file %srcdir #:recursive? #t
                      #:select? keep-cuirass-file?))
  (arguments
   '(#:phases
     (modify-phases %standard-phases
       (add-after 'unpack 'disable-repo-tests
         ;; Disable tests that use a connection to the Guix daemon.
         (λ _
           (substitute* "Makefile.am"
             (("tests/repo.scm \\\\") "\\"))
           #t))
       (add-before 'configure 'bootstrap
         (λ _ (zero? (system* "sh" "bootstrap"))))
       (add-after 'install 'wrap-program
         (lambda* (#:key inputs outputs #:allow-other-keys)
           ;; Wrap the 'cuirass' command to refer to the right modules.
           (let* ((out    (assoc-ref outputs "out"))
                  (json   (assoc-ref inputs "guile-json"))
                  (sqlite (assoc-ref inputs "guile-sqlite3"))
                  (guix   (assoc-ref inputs "guix"))
                  (mods   (string-append json "/share/guile/site/2.0:"
                                         sqlite "/share/guile/site/2.0:"
                                         guix "/share/guile/site/2.0")))
             (wrap-program (string-append out "/bin/cuirass")
               `("GUILE_LOAD_PATH" ":" prefix (,mods))
               `("GUILE_LOAD_COMPILED_PATH" ":" prefix (,mods)))))))))
  (inputs
   (map spec+package-list
        '("guile@2.0"
          "guile-json"
          "guile-sqlite3"
          "guix")))
  (native-inputs
   (map spec+package-list
        '("autoconf"
          "automake"
          "bash"
          "pkg-config"
          "texinfo"))))
