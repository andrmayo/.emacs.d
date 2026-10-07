;;; sly-config.el --- Common Lisp (Sly) config -*- lexical-binding: t; -*-

(use-package sly
  :init
  (setq inferior-lisp-program "sbcl")
  (setq sly-lisp-implementations
        '((sbcl ("sbcl") :coding-system utf-8-unix)
          (qlot ("qlot" "exec" "ros" "run") :coding-system utf-8-unix)))
  :hook (lisp-mode . sly-editing-mode))

;; use the CL-aware indenter (sly-cl-indent.el, loaded by the default
;; `sly-fancy' contrib) rather than the generic `lisp-indent-function', which
;; treats unknown macros as function calls and over-indents them.  It only
;; installs itself when a style is set, and `sly-common-lisp-style-default'
;; is nil, so set it here; with a live connection sly-indentation also
;; learns macro indentation from the running image.
(add-hook 'lisp-mode-hook
          (lambda ()
            (require 'sly-cl-indent "lib/sly-cl-indent")
            (setq-local lisp-indent-function #'sly-common-lisp-indent-function)))

;; when the debugger (sly-db) opens on a runtime error, jump to and
;; briefly flash the erroring frame's source location automatically,
;; rather than requiring a manual `v' press on the frame
(add-hook 'sly-db-hook
          (lambda ()
            (ignore-errors (sly-db-show-frame-source 0))))

;; completion popup with TAB/S-TAB cycling; sly-mrepl's own TAB handler
;; automatically prefers `company-complete' over plain `completion-at-point'
;; once company-mode is active (see `sly-mrepl-indent-and-complete-symbol')
(use-package company
  :ensure t
  :config
  (setq company-idle-delay 0)
  (global-company-mode))

(use-package company-box
  :ensure t
  :hook (company-mode . company-box-mode))

;; the sly inferior-lisp buffer is comint-mode, which evil defaults to
;; insert state (`evil-insert-state-modes'); it's a startup/log buffer,
;; not somewhere you type, so start it in normal state instead
(add-hook 'sly-inferior-process-start-hook
          (lambda () (evil-normal-state)))

;; Roswell's prebuilt sbcl-bin ships no Lisp source and has the build
;; dir (/tmp/sbcl) baked into its source paths, so M-. / gd on CL and
;; SBCL-internal symbols open nonexistent files.  Keep a matching
;; source checkout under ~/.local/share and point SBCL at it.
(defvar sly-sbcl-source-root (expand-file-name "~/.local/share/")
  "Directory holding per-version SBCL source checkouts (sbcl-VERSION/).")

(defvar sly-ros-sbcl-version nil
  "Cached version of the SBCL that `ros run' uses, e.g. \"2.6.8\".")

(defun sly-ros-sbcl-version ()
  "Return the plain x.y.z version of the SBCL `ros run' uses, or nil."
  (or sly-ros-sbcl-version
      (setq sly-ros-sbcl-version
            (ignore-errors
              (with-temp-buffer
                (call-process "ros" nil t nil "run" "--" "--noinform"
                              "--non-interactive" "--eval"
                              "(princ (lisp-implementation-version))")
                (goto-char (point-min))
                (when (re-search-forward "[0-9]+\\.[0-9]+\\.[0-9]+" nil t)
                  (match-string 0)))))))

(defun sly-sbcl-source-dir ()
  "Return the SBCL source dir matching ros's SBCL, cloning it if missing.
Returns nil (after a message) if the version or the clone is unavailable."
  (let ((version (sly-ros-sbcl-version)))
    (when version
      (let ((dir (expand-file-name (concat "sbcl-" version "/")
                                   sly-sbcl-source-root)))
        (unless (file-exists-p (expand-file-name "src/code/package.lisp" dir))
          (message "Cloning SBCL %s source into %s ..." version dir)
          (when (file-directory-p dir)
            (delete-directory dir t))
          (make-directory sly-sbcl-source-root t)
          (unless (zerop (call-process
                          "git" nil nil nil "clone" "--quiet" "--depth" "1"
                          "--branch" (concat "sbcl-" version)
                          "https://github.com/sbcl/sbcl" dir))
            (message "Failed to clone SBCL %s source; gd on CL symbols won't work"
                     version)
            (when (file-directory-p dir)
              (delete-directory dir t))))
        (and (file-exists-p (expand-file-name "src/code/package.lisp" dir))
             dir)))))

(defun sly-qlot-program-args ()
  "Args for `qlot', pointing SBCL's source location at a matching checkout."
  (let ((dir (sly-sbcl-source-dir)))
    (append '("exec" "ros" "run")
            (when dir
              (list "--" "--eval"
                    (format "(sb-ext:set-sbcl-source-location #p%S)" dir))))))

;; the `qlot' entry of `sly-lisp-implementations' (used by C-u M-x sly)
;; is refreshed just before the implementation is chosen
(defun sly-refresh-qlot-implementation (&rest _)
  (when current-prefix-arg
    (setf (alist-get 'qlot sly-lisp-implementations)
          (list (cons "qlot" (sly-qlot-program-args))
                :coding-system 'utf-8-unix))))
(advice-add 'sly :before #'sly-refresh-qlot-implementation)

(defun sly-qlot-system-name (root)
  "Guess the ASDF system to load for the qlot project at ROOT.
Prefers an .asd file matching ROOT's own directory name (e.g.
sae-cl/sae-cl.asd); falls back to any .asd file found in ROOT."
  (let* ((dirname (file-name-nondirectory (directory-file-name root)))
         (preferred (expand-file-name (concat dirname ".asd") root)))
    (if (file-exists-p preferred)
        dirname
      (let ((any-asd (car (directory-files root nil "\\.asd\\'"))))
        (unless any-asd
          (user-error "No .asd file found in %s" root))
        (file-name-sans-extension any-asd)))))

(defun sly-kill-compile-buffers ()
  "Kill all Sly compiler-notes/compilation-log buffers."
  (interactive)
  (let ((name (sly-buffer-name :compilation)))
    (dolist (buf (buffer-list))
      (when (string-prefix-p name (buffer-name buf))
        (kill-buffer buf)))))

(local-leader-def "wc" 'sly-kill-compile-buffers)

(defun sly-read-connection-name ()
  "Prompt for a non-empty Sly connection name."
  (let ((name (read-string "Name for new Sly connection: ")))
    (when (string-empty-p name)
      (user-error "Name must not be empty"))
    name))

(defun sly-start-qlot (mode &optional name)
  "Start a qlot-backed Sly connection in `session-root'.
MODE is `plain' (qlot only), `deps' (load the system's declared
dependencies, not the system) or `load' (quickload the system).
NAME, a string, names the connection; it defaults to \"qlot\"."
  (let* ((root (session-root))
         (sys-name (sly-qlot-system-name root))
         (system (intern (concat ":" sys-name))))
    ;; call `sly-start' directly (rather than `(sly 'qlot)') so
    ;; :directory always `cd's the inferior-lisp buffer, even if that
    ;; buffer is being reused from a previous, differently-rooted
    ;; invocation.
    (sly-start
     :program "qlot"
     :program-args (sly-qlot-program-args)
     :coding-system 'utf-8-unix
     :directory root
     :name (if name (intern name) 'qlot)
     :init-function
     (pcase mode
       ('plain nil)
       ;; qlot only configures the local quicklisp env; it doesn't
       ;; load the project itself
       ('load
        (lambda ()
          (sly-eval-async
           `(ql:quickload ,system)
           ;; only after quickload actually completes: sync the REPL's
           ;; *own* package via Sly's own mechanism (a raw `in-package'
           ;; sent through sly-eval-async only affects that one
           ;; throwaway call's dynamic extent, not the persistent REPL)
           (lambda (_result)
             (sly-mrepl-sync sys-name)))))
       ;; load only the system's declared dependencies, not the system
       ;; itself
       ('deps
        (lambda ()
          ;; fully package-qualified, and using mapc/lambda rather than
          ;; dolist, since an unqualified `dep' loop variable was
          ;; colliding with something already defined in the loaded
          ;; dependency tree
          (sly-eval-async
           `(cl:mapc
             (cl:lambda (%dep%)
               (quicklisp-client:quickload
                (cl:cond ((cl:and (cl:consp %dep%) (cl:eq (cl:car %dep%) :version))
                          (cl:second %dep%))
                         ((cl:and (cl:consp %dep%) (cl:eq (cl:car %dep%) :feature))
                          (cl:third %dep%))
                         ((cl:consp %dep%) (cl:car %dep%))
                         (cl:t %dep%))))
             (asdf:component-sideway-dependencies
              (asdf:find-system ,system)))
           nil "CL-USER")))))))

(defun sly-load-project (&optional force)
  "Load the current qlot project into the running Sly connection.
Uses `ql:quickload', so ASDF recompiles and reloads only the files that
changed since the last load (and anything depending on them).  With
prefix arg FORCE, reload every file of the project (dependencies are
left alone).  If there is no connection yet, start a qlot one that
autoloads the project, as \\ql does."
  (interactive "P")
  (if (not (sly-current-connection))
      (sly-start-qlot 'load)
    (let* ((sys-name (sly-qlot-system-name (session-root)))
           (system (intern (concat ":" sys-name))))
      (sly-message "%s %s ..." (if force "Reloading all of" "Loading") sys-name)
      (sly-eval-async
       (if force
           `(cl:progn (asdf:load-system ,system :force '(,system))
                      ,system)
         `(ql:quickload ,system))
       (lambda (_result)
         (sly-mrepl-sync sys-name)
         (sly-message "%s loaded" sys-name))))))

(defun sly-reload-project ()
  "Force-reload every file of the current project into the Sly connection."
  (interactive)
  (sly-load-project t))

(defun sly-start-named (name)
  "Start a new Sly connection (inferior Lisp + REPL) called NAME.
Always starts a fresh process, even if a connection already exists;
Sly appends <N> if NAME is already taken."
  (interactive "sName for new Sly connection: ")
  (when (string-empty-p name)
    (user-error "Name must not be empty"))
  (sly-start :program inferior-lisp-program
             :coding-system 'utf-8-unix
             :directory (if (fboundp 'session-root) (session-root) default-directory)
             :name (intern name)))

(defun sly-rename-connection (conn new-name)
  "Rename Sly connection CONN to NEW-NAME, along with its buffers.
Interactively, prompt for the connection and the new name."
  (interactive
   (let* ((conn (sly-prompt-for-connection "Rename connection: "))
          (old (sly-connection-name conn)))
     (list conn (read-string (format "New name for %s: " old) nil nil old))))
  (let ((old (sly-connection-name conn))
        (new (sly-generate-connection-name new-name)))
    (when (string-empty-p new-name)
      (user-error "Name must not be empty"))
    (unless (equal old new-name)
      ;; process-put directly: `setf' on the accessor needs sly loaded at
      ;; macroexpansion time, which isn't true when init.el is evaluated
      (process-put conn 'sly-connection-name new)
      ;; buffer names embed the connection name as " for NAME" followed by
      ;; either " (handle)*" or "*"; rewrite every such Sly buffer
      (let ((from (concat " for " old))
            (case-fold-search nil))
        (dolist (buf (buffer-list))
          (let ((bname (buffer-name buf)))
            (when (and (string-match-p "\\` ?\\*sly-" bname)
                       (string-match (concat (regexp-quote from)
                                             "\\(?: (\\|\\*\\'\\)")
                                     bname))
              (with-current-buffer buf
                (sly--trampling-rename-buffer
                 (concat (substring bname 0 (match-beginning 0))
                         " for " new
                         (substring bname (+ (match-beginning 0)
                                             (length from))))))))))
      (force-mode-line-update t)
      (sly-message "Connection renamed: %s -> %s" old new))))

(local-leader-def
  :keymaps 'lisp-mode-map
  "R" (list :def 'sly-rename-connection :which-key "rename sly connection"))

(defun sly-toggle-compilation-window ()
  "Toggle a bottom-docked window showing Sly's compiler notes.
The buffer is `compilation-mode', so RET jumps to a note's source
location and `compilation-next-error'/`-previous-error' (bound via
`evil-collection-compile' to gj/gk and TAB/S-TAB) cycle through them,
similar to a quickfix or trouble.nvim-style diagnostics list."
  (interactive)
  (let* ((name (sly-buffer-name :compilation))
         (buf (get-buffer name))
         (win (and buf (get-buffer-window buf t))))
    (cond
     (win (delete-window win))
     ((not buf) (sly-message "No compilation notes yet -- compile something first."))
     (t (display-buffer
         buf
         '((display-buffer-reuse-window display-buffer-in-side-window)
           (side . bottom)
           (window-height . 0.25)
           (dedicated . t)))))))

;; sly-next-note/sly-previous-note (M-n/M-p by default) already echo
;; the note's message when jumping to it -- these just give leader-key
;; aliases for the same thing
(local-leader-def
  :keymaps 'lisp-mode-map
  "nn" (list :def 'sly-next-note :which-key "next compiler note (M-n)")
  "np" (list :def 'sly-previous-note :which-key "previous compiler note (M-p)"))

(leader-def
  :keymaps 'lisp-mode-map
  "xx" 'sly-toggle-compilation-window)

(local-leader-def
  :keymaps 'lisp-mode-map
  "q" '(:ignore t :which-key "qlot")
  "c" '(:ignore t :which-key "compile/eval")
  "r" (list :def (lambda () (interactive)
                   (let ((current-prefix-arg '-))
                     (call-interactively #'sly)))
            :which-key "start sly (choose implementation)")
  "ql" (list :def (lambda () (interactive) (sly-start-qlot 'load))
             :which-key "start sly (qlot, autoload project)")
  "qr" (list :def 'sly-load-project
             :which-key "load/update project in running sly (changed files only)")
  "qR" (list :def 'sly-reload-project
             :which-key "force-reload all project files in running sly")
  "qq" (list :def (lambda () (interactive) (sly-start-qlot 'plain))
             :which-key "start sly (qlot only, no autoload)")
  "qd" (list :def (lambda () (interactive) (sly-start-qlot 'deps))
             :which-key "start sly (deps only, no project)")
  ;; same as \q*, but prompting for the connection's name
  "N" '(:ignore t :which-key "new named sly connection")
  "Nl" (list :def (lambda () (interactive) (sly-start-qlot 'load (sly-read-connection-name)))
             :which-key "named sly (qlot, autoload project)")
  "Nq" (list :def (lambda () (interactive) (sly-start-qlot 'plain (sly-read-connection-name)))
             :which-key "named sly (qlot only, no autoload)")
  "Nd" (list :def (lambda () (interactive) (sly-start-qlot 'deps (sly-read-connection-name)))
             :which-key "named sly (deps only, no project)")
  "Ns" (list :def 'sly-start-named :which-key "named sly (plain sbcl)")
  ;; mirror the letters from Sly's own C-c/C-x/M-x bindings
  "cc" (list :def 'sly-compile-defun :which-key "compile+eval defun (C-c C-c)")
  "cr" (list :def 'sly-eval-region :which-key "eval region (C-c C-r)")
  "ck" (list :def 'sly-compile-and-load-file :which-key "compile+load file (C-c C-k)")
  "cl" (list :def 'sly-load-file :which-key "load file (C-c C-l)")
  "mx" (list :def 'sly-eval-defun :which-key "eval defun (C-M-x)")
  "xe" (list :def 'sly-eval-last-expression :which-key "eval last expression (C-x C-e)")
  ;; sly-stickers: mirror the letters from C-c C-s <x>
  "s" '(:ignore t :which-key "stickers")
  "ss" (list :def 'sly-stickers-dwim :which-key "toggle sticker at point (C-c C-s C-s)")
  "sd" (list :def 'sly-stickers-clear-defun-stickers :which-key "clear stickers in defun (C-c C-s C-d)")
  "sk" (list :def 'sly-stickers-clear-buffer-stickers :which-key "clear stickers in buffer (C-c C-s C-k)")
  "sS" (list :def 'sly-stickers-fetch :which-key "fetch sticker recordings (C-c C-s S)")
  "sF" (list :def 'sly-stickers-forget :which-key "forget sticker recordings (C-c C-s F)")
  "sr" (list :def 'sly-stickers-replay :which-key "replay sticker recordings (C-c C-s C-r)"))


;; warn on Common Lisp lines over 100 columns: a vertical guide line,
;; plus highlighting on the actual overlong portion of any line that
;; already crosses it
(add-hook 'lisp-mode-hook
          (lambda ()
            (setq-local fill-column 100)
            (setq-local whitespace-line-column 100)
            (setq-local whitespace-style '(face lines-tail))
            (display-fill-column-indicator-mode 1)
            (whitespace-mode 1)))

(provide 'sly-config)
