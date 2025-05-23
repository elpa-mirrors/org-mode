;;; test-ob-shell.el  -*- lexical-binding: t; -*-

;; Copyright (c) 2010-2014, 2019 Eric Schulte
;; Authors: Eric Schulte

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.


;;; Comment:

;; See testing/README for how to run tests.


;;; Requirements:

(require 'ob-core)
(require 'org-macs)

(unless (featurep 'ob-shell)
  (signal 'missing-test-dependency '("Support for Shell code blocks")))

(org-test-for-executable "sh")


;;; Code:
(ert-deftest test-ob-shell/dont-insert-spaces-on-expanded-bodies ()
  "Expanded shell bodies should not start with a blank line unless
the body of the tangled block does."
  (should-not (string-match "^[\n\r][\t ]*[\n\r]"
                            (org-babel-expand-body:generic "echo 2" '())))
  (should (string-match "^[\n\r][\t ]*[\n\r]"
                        (org-babel-expand-body:generic "\n\necho 2" '()))))

(ert-deftest test-ob-shell/dont-error-on-empty-results ()
  "Empty results should not cause a Lisp error."
  (should (null (org-babel-execute:sh "" nil))))

(ert-deftest test-ob-shell/dont-error-on-babel-error ()
  "Errors within Babel execution should not cause Lisp errors."
  (if (should (null (org-babel-execute:sh "ls NoSuchFileOrDirectory.txt" nil)))
      (kill-buffer org-babel-error-buffer-name)))

(ert-deftest test-ob-shell/session-single-return-returns-string ()
  "Sessions with a single result should return a string."
  (let* ((session-name "test-ob-shell/session-evaluation-single-return-returns-string")
         (kill-buffer-query-functions nil)
         (result (org-babel-execute:sh
                  (format "echo %s" session-name)
                  `((:session . ,session-name)))))
    (should result)
    (if (should (string= session-name result))
        (kill-buffer session-name))))

(ert-deftest test-ob-shell/session-multiple-returns-returns-list ()
  "Sessions with multiple results should return a list."
  (let* ((session-name "test-ob-shell/session-multiple-returns-returns-list")
         (kill-buffer-query-functions nil)
         (result (org-babel-execute:sh
                  "echo 1; echo 2"
                  `((:session . ,session-name)))))
    (should result)
    (should (listp result))
    (if (should (equal '((1) (2)) result))
        (kill-buffer session-name))))

(ert-deftest test-ob-shell/session-async-valid-header-arg-values ()
  "Test that session runs asynchronously for certain :async values."
  (let ((session-name "test-ob-shell/session-async-valid-header-arg-values")
        (kill-buffer-query-functions nil))
    (dolist (arg-val '("t" ""))
     (org-test-with-temp-text
         (concat "#+begin_src sh :session " session-name " :async " arg-val "
echo 1<point>
#+end_src")
       (if (should
            (string-match
             org-uuid-regexp
             (org-trim (org-babel-execute-src-block))))
           (kill-buffer session-name))))))

(ert-deftest test-ob-shell/session-async-inserts-uuid-before-results-are-returned ()
  "Test that a uuid placeholder is inserted before results are inserted."
  (let ((session-name "test-ob-shell/session-async-inserts-uuid-before-results-are-returned")
        (kill-buffer-query-functions nil))
    (org-test-with-temp-text
        (concat "#+begin_src sh :session " session-name " :async t
echo 1<point>
#+end_src")
      (if (should
           (string-match
            org-uuid-regexp
            (org-trim (org-babel-execute-src-block))))
          (kill-buffer session-name)))))

(ert-deftest test-ob-shell/session-async-evaluation ()
  "Test the async evaluation process."
  (let* ((session-name "test-ob-shell/session-async-evaluation")
         (kill-buffer-query-functions nil)
         (start-time (current-time))
         (wait-time (time-add start-time 3))
         uuid-placeholder)
    (org-test-with-temp-text
        (concat "#+begin_src sh :session " session-name " :async t
echo 1
echo 2<point>
#+end_src")
      (setq uuid-placeholder (org-trim (org-babel-execute-src-block)))
      (catch 'too-long
        (while (string-match uuid-placeholder (buffer-string))
          (progn
            (sleep-for 0.01)
            (when (time-less-p wait-time (current-time))
              (throw 'too-long (ert-fail "Took too long to get result from callback"))))))
    (search-forward "#+results")
    (beginning-of-line 2)
    (if (should (string= ": 1\n: 2\n" (buffer-substring-no-properties (point) (point-max))))
          (kill-buffer session-name)))))

(ert-deftest test-ob-shell/session-async-results ()
  "Test that async evaluation removes prompt from results."
  (let* ((session-name "test-ob-shell/session-async-results")
         (kill-buffer-query-functions nil)
         (start-time (current-time))
         (wait-time (time-add start-time 3))
         uuid-placeholder)
    (org-test-with-temp-text
     (concat "#+begin_src sh :session " session-name " :async t
# print message
echo \"hello world\"<point>
#+end_src")
     (setq uuid-placeholder (org-trim (org-babel-execute-src-block)))
     (catch 'too-long
       (while (string-match uuid-placeholder (buffer-string))
         (progn
           (sleep-for 0.01)
           (when (time-less-p wait-time (current-time))
             (throw 'too-long (ert-fail "Took too long to get result from callback"))))))
     (search-forward "#+results")
     (beginning-of-line 2)
     (if (should (string= ": hello world\n" (buffer-substring-no-properties (point) (point-max))))
         (kill-buffer session-name)))))

(ert-deftest test-ob-shell/generic-uses-no-arrays ()
  "Test generic serialization of array into a single string."
  (org-test-with-temp-text
      " #+NAME: sample_array
| one   |
| two   |
| three |

#+begin_src sh :exports results :results output :var array=sample_array
echo ${array}
<point>
#+end_src"
    (should (equal "one two three" (org-trim (org-babel-execute-src-block))))))

(ert-deftest test-ob-shell/bash-uses-arrays ()
  "Bash sees named array as a simple indexed array.

In this test, we check that the returned value is indeed only the
first item of the array, as opposed to the generic serialiation
that will return all elements of the array as a single string."
  (org-test-with-temp-text
      "#+NAME: sample_array
| one   |
| two   |
| three |

#+begin_src bash :exports results :results output :var array=sample_array
echo ${array}
<point>
#+end_src"
    (skip-unless (executable-find "bash"))
    (should (equal "one" (org-trim (org-babel-execute-src-block))))))

(ert-deftest test-ob-shell/generic-uses-no-assoc-arrays-simple-map ()
  "Generic shell: no special handing for key-value mapping table

No associative arrays for generic.  The shell will see all values
as a single string."
  (org-test-with-temp-text
      "#+NAME: sample_mapping_table
| first  | one   |
| second | two   |
| third  | three |

#+begin_src sh :exports results :results output :var table=sample_mapping_table
echo ${table}
<point>
#+end_src"
    (should
     (equal "first one second two third three"
            (org-trim (org-babel-execute-src-block))))))

(ert-deftest test-ob-shell/generic-uses-no-assoc-arrays-3-columns ()
  "Associative array tests (more than 2 columns)

No associative arrays for generic.  The shell will see all values
as a single string."
  (org-test-with-temp-text
      "#+NAME: sample_big_table
| bread     |  2 | kg |
| spaghetti | 20 | cm |
| milk      | 50 | dl |

#+begin_src sh :exports results :results output :var table=sample_big_table
echo ${table}
<point>
#+end_src"
    (should
     (equal "bread 2 kg spaghetti 20 cm milk 50 dl"
            (org-trim (org-babel-execute-src-block))))))

(ert-deftest test-ob-shell/bash-uses-assoc-arrays ()
  "Bash shell: support for associative arrays

Bash will see a table that contains the first column as the
'index' of the associative array, and the second column as the
value. "
  (skip-unless
   ;; Old GPLv2 BASH in macOSX does not support associative arrays.
   (if-let* ((bash (executable-find "bash")))
       (eq 0 (process-file bash nil nil nil "-c" "declare -A assoc_array"))))
  (org-test-with-temp-text
      "#+NAME: sample_mapping_table
| first  | one   |
| second | two   |
| third  | three |

#+begin_src bash :exports :results output results :var table=sample_mapping_table
echo ${table[second]}
<point>
#+end_src "
    (should
     (equal "two"
            (org-trim (org-babel-execute-src-block))))))

(ert-deftest test-ob-shell/bash-uses-assoc-arrays-with-lists ()
  "Bash shell: support for associative arrays with lists

Bash will see an associative array that contains each row as a single
string. Bash cannot handle lists in associative arrays."
  (skip-unless
   ;; Old GPLv2 BASH in macOSX does not support associative arrays.
   (if-let* ((bash (executable-find "bash")))
       (eq 0 (process-file bash nil nil nil "-c" "declare -A assoc_array"))))
  (org-test-with-temp-text
      "#+NAME: sample_big_table
| bread     |  2 | kg |
| spaghetti | 20 | cm |
| milk      | 50 | dl |

#+begin_src bash :exports results :results output :var table=sample_big_table
echo ${table[spaghetti]}
<point>
#+end_src"
    (should
     (equal "20 cm"
            (org-trim (org-babel-execute-src-block))))))

(ert-deftest test-ob-shell/simple-list ()
  "Test list variables."
  ;; bash: a list is turned into an array
  (should
   (equal "2"
          (org-test-with-temp-text
              "#+BEGIN_SRC bash :results output :var l='(1 2)
               echo ${l[1]}
               #+END_SRC"
            (org-trim (org-babel-execute-src-block)))))

  ;; sh: a list is a string containing all values
  (should
   (equal "1 2"
          (org-test-with-temp-text
              "#+BEGIN_SRC sh :results output :var l='(1 2)
               echo ${l}
               #+END_SRC"
            (org-trim (org-babel-execute-src-block))))))

(ert-deftest test-ob-shell/cmdline ()
  "Test :cmdline header argument."
  (should
   (equal "2"
          (org-test-with-temp-text
              "#+begin_src bash :results output :cmdline 1 2 3
              printf \"%s\n\" \"$2\"
              #+end_src"
            (org-trim (org-babel-execute-src-block)))))
  (should
   (equal "2 3"
          (org-test-with-temp-text
              "#+begin_src bash :results output :cmdline 1 \"2 3\"
              printf \"%s\n\" \"$2\"
              #+end_src"
            (org-trim (org-babel-execute-src-block)))))
  (should
   (equal "1 2 3"
          (org-test-with-temp-text
              "#+begin_src bash :results output :cmdline \"\\\"1 2 3\\\"\"
              printf \"%s\n\" \"$1\"
              #+end_src"
            (org-trim (org-babel-execute-src-block)))))
  (should
   (equal "1"
          (org-test-with-temp-text
              "#+begin_src bash :results output :cmdline 1
              printf \"%s\n\" \"$1\"
              #+end_src"
            (org-trim (org-babel-execute-src-block))))))

(ert-deftest test-ob-shell/ensure-shebang-in-script-files ()
  "Bug <https://orgmode.org/list/87a5j6y1zk.fsf@localhost>."
  (skip-unless (executable-find "dash"))
  (should
   ;; dash does not initialize $RANDOM, unlike bash.
   (equal "This must be empty in dash:"
          (org-test-with-temp-text
              "#+begin_src dash :results output :cmdline 1 2 3
              echo This must be empty in dash: \"$RANDOM\"
              #+end_src"
            (org-trim (org-babel-execute-src-block))))))

(ert-deftest test-ob-shell/remote-with-stdin-or-cmdline ()
  "Test :stdin and :cmdline with a remote directory."
  ;; We assume `default-directory' is a local directory.
  (skip-unless (not (memq system-type '(ms-dos windows-nt))))
  (org-test-with-tramp-remote-dir remote-dir
      (dolist (spec `( ()
                       (:dir ,remote-dir)
                       (:dir ,remote-dir :cmdline t)
                       (:dir ,remote-dir :stdin   t)
                       (:dir ,remote-dir :cmdline t :shebang t)
                       (:dir ,remote-dir :stdin   t :shebang t)
                       (:dir ,remote-dir :cmdline t :stdin t :shebang t)
                       (:cmdline t)
                       (:stdin   t)
                       (:cmdline t :shebang t)
                       (:stdin   t :shebang t)
                       (:cmdline t :stdin t :shebang t)))
        (let ((default-directory (or (plist-get spec :dir) default-directory))
              (org-confirm-babel-evaluate nil)
              (params-line "")
              (who-line "  export who=tramp")
              (args-line "  echo ARGS: --verbose 23 71"))
          (when-let* ((dir (plist-get spec :dir)))
            (setq params-line (concat params-line " " ":dir " dir)))
          (when (plist-get spec :stdin)
            (setq who-line "  read -r who")
            (setq params-line (concat params-line " :stdin input")))
          (when (plist-get spec :cmdline)
            (setq args-line "  echo \"ARGS: $*\"")
            (setq params-line (concat params-line " :cmdline \"--verbose 23 71\"")))
          (when (plist-get spec :shebang)
            (setq params-line (concat params-line " :shebang \"#!/bin/sh\"")))
          (let* ((result (org-test-with-temp-text
                             (mapconcat #'identity
                                        (list "#+name: input"
                                              "tramp"
                                              ""
                                              (concat "<point>"
                                                      "#+begin_src sh :results output " params-line)
                                              args-line
                                              who-line
                                              "  echo \"hello $who from $(pwd)/\""
                                              "#+end_src")
                                        "\n")
                           (org-trim (org-babel-execute-src-block))))
                 (expected (concat "ARGS: --verbose 23 71"
                                   "\nhello tramp from " (file-local-name default-directory))))
            (if (should (equal result expected))
              ;; FIXME: Fails with non-local exit on Emacs 26.
              (when (version<= "27" emacs-version)
                (kill-matching-buffers (format "\\*tramp/mock\\s-%s\\*" system-name) t t))))))))

(ert-deftest test-ob-shell/results-table ()
  "Test :results table."
  (should
   (equal '(("I \"want\" it all"))
          (org-test-with-temp-text
              "#+BEGIN_SRC sh :results table
               echo 'I \"want\" it all'
               #+END_SRC"
            (org-babel-execute-src-block)))))

(ert-deftest test-ob-shell/results-list ()
  "Test :results list."
  (org-test-with-temp-text
      "#+BEGIN_SRC sh :results list
echo 1
echo 2
echo 3
#+END_SRC"
    (should
     (equal '((1) (2) (3))
            (org-babel-execute-src-block)))
    (search-forward "#+results")
    (beginning-of-line 2)
    (should
     (equal
      "- 1\n- 2\n- 3\n"
      (buffer-substring-no-properties (point) (point-max))))))


;;; Standard output

(ert-deftest test-ob-shell/standard-output-after-success ()
  "Test standard output after exiting with a zero code."
  (should (= 1
             (org-babel-execute:sh
              "echo 1" nil))))

(ert-deftest test-ob-shell/standard-output-after-failure ()
  "Test standard output after exiting with a non-zero code."
  (if
      (should (= 1
                 (org-babel-execute:sh
                  "echo 1; exit 2" nil)))
      (kill-buffer org-babel-error-buffer-name)))


;;; Standard error

(ert-deftest test-ob-shell/error-output-after-success ()
  "Test that standard error shows in the error buffer, alongside
the exit code, after exiting with a zero code."
  (if
      (should
       (string= "1
[ Babel evaluation exited with code 0 ]"
                (progn (org-babel-eval-wipe-error-buffer)
                       (org-babel-execute:sh
                        "echo 1 >&2" nil)
                       (with-current-buffer org-babel-error-buffer-name
                         (buffer-string)))))
      (kill-buffer org-babel-error-buffer-name)))

(ert-deftest test-ob-shell/error-output-after-failure ()
  "Test that standard error shows in the error buffer, alongside
the exit code, after exiting with a non-zero code."
  (if
      (should
       (string= "1
[ Babel evaluation exited with code 2 ]"
                (progn (org-babel-eval-wipe-error-buffer)
                       (org-babel-execute:sh
                        "echo 1 >&2; exit 2" nil)
                       (with-current-buffer org-babel-error-buffer-name
                         (buffer-string)))))
      (kill-buffer org-babel-error-buffer-name)))

(ert-deftest test-ob-shell/error-output-after-failure-multiple ()
  "Test that multiple standard error strings show in the error
buffer, alongside multiple exit codes."
  (if
      (should
       (string= "1
[ Babel evaluation exited with code 2 ]
3
[ Babel evaluation exited with code 4 ]"
                (progn (org-babel-eval-wipe-error-buffer)
                       (org-babel-execute:sh
                        "echo 1 >&2; exit 2" nil)
                       (org-babel-execute:sh
                        "echo 3 >&2; exit 4" nil)
                       (with-current-buffer org-babel-error-buffer-name
                         (buffer-string)))))
      (kill-buffer org-babel-error-buffer-name)))


;;; Exit codes

(ert-deftest test-ob-shell/exit-code ()
  "Test that the exit code shows in the error buffer after exiting
with a non-zero return code."
  (if
      (should
       (string= "[ Babel evaluation exited with code 1 ]"
                (progn (org-babel-eval-wipe-error-buffer)
                       (org-babel-execute:sh
                        "exit 1" nil)
                       (with-current-buffer org-babel-error-buffer-name
                         (buffer-string)))))
      (kill-buffer org-babel-error-buffer-name)))

(ert-deftest test-ob-shell/exit-code-multiple ()
  "Test that multiple exit codes show in the error buffer after
exiting with a non-zero return code multiple times."
  (if
      (should
       (string= "[ Babel evaluation exited with code 1 ]
[ Babel evaluation exited with code 2 ]"
                (progn (org-babel-eval-wipe-error-buffer)
                       (org-babel-execute:sh
                        "exit 1" nil)
                       (org-babel-execute:sh
                        "exit 2" nil)
                       (with-current-buffer org-babel-error-buffer-name
                         (buffer-string)))))
      (kill-buffer org-babel-error-buffer-name)))

(provide 'test-ob-shell)

;;; test-ob-shell.el ends here
